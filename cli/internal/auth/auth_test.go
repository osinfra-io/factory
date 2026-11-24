package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"path/filepath"
	"testing"
	"time"

	"github.com/osinfra-io/factory/cli/internal/config"
)

func newServer(t *testing.T) *httptest.Server {
	t.Helper()

	var srv *httptest.Server

	mux := http.NewServeMux()
	mux.HandleFunc("/.well-known/openid-configuration", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"authorization_endpoint":"` + srv.URL + `/authorize","token_endpoint":"` + srv.URL + `/token"}`))
	})
	mux.HandleFunc("/token", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()

		switch {
		case r.Form.Get("grant_type") == "refresh_token":
			_, _ = w.Write([]byte(`{"access_token":"refreshed","expires_in":3600}`))
		case r.Form.Get("code") == "good" && r.Form.Get("code_verifier") != "":
			_, _ = w.Write([]byte(`{"access_token":"at","refresh_token":"rt","expires_in":3600}`))
		default:
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"error":"invalid_grant"}`))
		}
	})

	srv = httptest.NewServer(mux)
	t.Cleanup(srv.Close)

	return srv
}

func TestLoginExchangesCodeAndCachesToken(t *testing.T) {
	srv := newServer(t)
	path := filepath.Join(t.TempDir(), "tokens", "x.json")
	a := New(config.OIDC{Issuer: srv.URL, ClientID: "c"}, http.DefaultTransport, path)

	err := a.Login(context.Background(), func(authURL string) {
		u, err := url.Parse(authURL)
		if err != nil || u.Query().Get("code_challenge_method") != "S256" {
			t.Errorf("bad auth URL %q: %v", authURL, err)
			return
		}

		cb := u.Query().Get("redirect_uri") + "?code=good&state=" + u.Query().Get("state")

		go func() {
			res, err := http.Get(cb) //nolint:noctx
			if err == nil {
				_ = res.Body.Close()
			}
		}()
	})
	if err != nil {
		t.Fatal(err)
	}

	tok, err := New(config.OIDC{Issuer: srv.URL, ClientID: "c"}, http.DefaultTransport, path).AccessToken(context.Background())
	if err != nil || tok != "at" {
		t.Fatalf("token = %q, err = %v", tok, err)
	}
}

func TestLoginRejectsStateMismatch(t *testing.T) {
	srv := newServer(t)
	a := New(config.OIDC{Issuer: srv.URL, ClientID: "c"}, http.DefaultTransport, filepath.Join(t.TempDir(), "x.json"))

	err := a.Login(context.Background(), func(authURL string) {
		u, _ := url.Parse(authURL)

		go func() {
			res, err := http.Get(u.Query().Get("redirect_uri") + "?code=good&state=wrong") //nolint:noctx
			if err == nil {
				_ = res.Body.Close()
			}
		}()
	})
	if err == nil {
		t.Fatal("expected state mismatch error")
	}
}

func TestAccessTokenRefreshesExpired(t *testing.T) {
	srv := newServer(t)
	path := filepath.Join(t.TempDir(), "x.json")
	a := New(config.OIDC{Issuer: srv.URL, ClientID: "c"}, http.DefaultTransport, path)

	if err := a.save(Token{AccessToken: "old", RefreshToken: "rt", Expiry: time.Now().Add(-time.Hour)}); err != nil {
		t.Fatal(err)
	}

	tok, err := a.AccessToken(context.Background())
	if err != nil || tok != "refreshed" {
		t.Fatalf("token = %q, err = %v", tok, err)
	}

	if a.token.RefreshToken != "rt" {
		t.Fatal("refresh token should be kept when the server omits a new one")
	}
}

func TestAccessTokenWithoutLogin(t *testing.T) {
	a := New(config.OIDC{}, http.DefaultTransport, filepath.Join(t.TempDir(), "none.json"))
	if _, err := a.AccessToken(context.Background()); err == nil {
		t.Fatal("expected error")
	}
}

func TestAPITokenExchangesForFloor(t *testing.T) {
	var gotClient, gotAssertion string

	var srv *httptest.Server

	mux := http.NewServeMux()
	mux.HandleFunc("/.well-known/openid-configuration", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"authorization_endpoint":"` + srv.URL + `/a","token_endpoint":"` + srv.URL + `/token"}`))
	})
	mux.HandleFunc("/token", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		gotClient, gotAssertion = r.Form.Get("client_id"), r.Form.Get("client_assertion")
		_, _ = w.Write([]byte(`{"access_token":"floor-token","expires_in":600}`))
	})

	srv = httptest.NewServer(mux)
	defer srv.Close()

	a := New(config.OIDC{Issuer: srv.URL, ClientID: "c", ExchangeClientID: "floor-client"}, http.DefaultTransport, filepath.Join(t.TempDir(), "x.json"))
	if err := a.save(Token{AccessToken: "login", Expiry: time.Now().Add(time.Hour)}); err != nil {
		t.Fatal(err)
	}

	tok, err := a.APIToken(context.Background())
	if err != nil || tok != "floor-token" {
		t.Fatalf("token = %q, err = %v", tok, err)
	}

	if gotClient != "floor-client" || gotAssertion != "login" {
		t.Fatalf("client = %q, assertion = %q", gotClient, gotAssertion)
	}
}
