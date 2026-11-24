// Package auth signs the CLI in through authentik using the OAuth2
// authorization code grant with PKCE, so the human identity is their Google account.
package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/osinfra-io/factory/cli/internal/config"
)

// Token is the cached result of a login.
type Token struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken string    `json:"refreshToken,omitempty"`
	Expiry       time.Time `json:"expiry"`
}

// Valid reports whether the access token is usable for at least a minute.
func (t Token) Valid() bool {
	return t.AccessToken != "" && time.Until(t.Expiry) > time.Minute
}

type discovery struct {
	AuthorizationEndpoint string `json:"authorization_endpoint"`
	TokenEndpoint         string `json:"token_endpoint"`
}

type tokenResponse struct {
	AccessToken      string `json:"access_token"`
	RefreshToken     string `json:"refresh_token"`
	ExpiresIn        int    `json:"expires_in"`
	Error            string `json:"error"`
	ErrorDescription string `json:"error_description"`
}

// Authenticator logs in and refreshes tokens for one environment.
type Authenticator struct {
	oidc  config.OIDC
	http  *http.Client
	path  string
	mu    sync.Mutex
	token Token

	exchanged Token
}

// New returns an Authenticator caching tokens at tokenPath.
func New(oidc config.OIDC, rt http.RoundTripper, tokenPath string) *Authenticator {
	return &Authenticator{
		oidc: oidc,
		http: &http.Client{Transport: rt, Timeout: 30 * time.Second},
		path: tokenPath,
	}
}

// TokenPath returns the cache location for an environment.
func TokenPath(env string) (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(dir, "factory", "tokens", env+".json"), nil
}

// Login signs in with the authorization code flow and PKCE on a loopback
// redirect. prompt is called with the URL to open in a browser.
func (a *Authenticator) Login(ctx context.Context, prompt func(authURL string)) error {
	d, err := a.discover(ctx)
	if err != nil {
		return err
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer func() { _ = ln.Close() }()

	redirect := fmt.Sprintf("http://%s/callback", ln.Addr())
	verifier := random(32)
	state := random(16)
	sum := sha256.Sum256([]byte(verifier))

	q := url.Values{
		"client_id":             {a.oidc.ClientID},
		"response_type":         {"code"},
		"redirect_uri":          {redirect},
		"scope":                 {"openid email profile offline_access"},
		"state":                 {state},
		"code_challenge":        {base64.RawURLEncoding.EncodeToString(sum[:])},
		"code_challenge_method": {"S256"},
	}

	type result struct {
		code string
		err  error
	}

	results := make(chan result, 1)
	srv := &http.Server{ReadHeaderTimeout: 10 * time.Second, Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/callback" {
			http.NotFound(w, r)
			return
		}

		res := result{code: r.URL.Query().Get("code")}

		switch {
		case r.URL.Query().Get("state") != state:
			res.err = errors.New("sign-in state mismatch")
		case r.URL.Query().Get("error") != "":
			res.err = fmt.Errorf("sign-in failed: %s", r.URL.Query().Get("error"))
		case res.code == "":
			res.err = errors.New("sign-in returned no code")
		}

		if res.err != nil {
			http.Error(w, res.err.Error(), http.StatusBadRequest)
		} else {
			_, _ = w.Write([]byte("Signed in. You can close this tab and return to the terminal."))
		}

		select {
		case results <- res:
		default:
		}
	})}

	go func() { _ = srv.Serve(ln) }()

	defer func() { _ = srv.Close() }()

	prompt(d.AuthorizationEndpoint + "?" + q.Encode())

	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	var res result

	select {
	case res = <-results:
	case <-ctx.Done():
		return errors.New("login timed out")
	}

	if res.err != nil {
		return res.err
	}

	tok, err := a.exchange(ctx, d.TokenEndpoint, url.Values{
		"client_id":     {a.oidc.ClientID},
		"grant_type":    {"authorization_code"},
		"code":          {res.code},
		"redirect_uri":  {redirect},
		"code_verifier": {verifier},
	})
	if err != nil {
		return err
	}

	return a.save(tok)
}

func random(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)

	return base64.RawURLEncoding.EncodeToString(b)
}

// AccessToken returns a valid access token, refreshing it when needed.
func (a *Authenticator) AccessToken(ctx context.Context) (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.token.AccessToken == "" {
		raw, err := os.ReadFile(a.path)
		if err != nil {
			return "", errors.New("not signed in; run `factory login`")
		}

		if err := json.Unmarshal(raw, &a.token); err != nil {
			return "", fmt.Errorf("reading cached token: %w", err)
		}
	}

	if a.token.Valid() {
		return a.token.AccessToken, nil
	}

	if a.token.RefreshToken == "" {
		return "", errors.New("session expired; run `factory login`")
	}

	d, err := a.discover(ctx)
	if err != nil {
		return "", err
	}

	tok, err := a.exchange(ctx, d.TokenEndpoint, url.Values{
		"client_id":     {a.oidc.ClientID},
		"grant_type":    {"refresh_token"},
		"refresh_token": {a.token.RefreshToken},
	})
	if err != nil {
		return "", fmt.Errorf("session expired; run `factory login`: %w", err)
	}

	if tok.RefreshToken == "" {
		tok.RefreshToken = a.token.RefreshToken
	}

	if err := a.saveLocked(tok); err != nil {
		return "", err
	}

	return a.token.AccessToken, nil
}

func (a *Authenticator) save(t Token) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	return a.saveLocked(t)
}

func (a *Authenticator) saveLocked(t Token) error {
	a.token = t

	if err := os.MkdirAll(filepath.Dir(a.path), 0o700); err != nil {
		return err
	}

	raw, err := json.Marshal(t)
	if err != nil {
		return err
	}

	return os.WriteFile(a.path, raw, 0o600)
}

func (a *Authenticator) discover(ctx context.Context) (discovery, error) {
	var d discovery

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimSuffix(a.oidc.Issuer, "/")+"/.well-known/openid-configuration", nil)
	if err != nil {
		return d, err
	}

	res, err := a.http.Do(req)
	if err != nil {
		return d, fmt.Errorf("oidc discovery: %w", err)
	}
	defer func() { _ = res.Body.Close() }()

	if res.StatusCode != http.StatusOK {
		return d, fmt.Errorf("oidc discovery: %s", res.Status)
	}

	if err := json.NewDecoder(res.Body).Decode(&d); err != nil {
		return d, fmt.Errorf("oidc discovery: %w", err)
	}

	if d.AuthorizationEndpoint == "" || d.TokenEndpoint == "" {
		return d, errors.New("issuer discovery is missing the authorization or token endpoint")
	}

	return d, nil
}

type oauthError struct{ code, desc string }

func (e *oauthError) Error() string {
	if e.desc != "" {
		return e.code + ": " + e.desc
	}

	return e.code
}

func (a *Authenticator) exchange(ctx context.Context, endpoint string, form url.Values) (Token, error) {
	var r tokenResponse
	if err := a.post(ctx, endpoint, form, &r); err != nil {
		return Token{}, err
	}

	if r.Error != "" {
		return Token{}, &oauthError{code: r.Error, desc: r.ErrorDescription}
	}

	return Token{
		AccessToken:  r.AccessToken,
		RefreshToken: r.RefreshToken,
		Expiry:       time.Now().Add(time.Duration(r.ExpiresIn) * time.Second),
	}, nil
}

// post decodes the JSON body regardless of status so OAuth errors such as
// authorization_pending reach the caller.
func (a *Authenticator) post(ctx context.Context, endpoint string, form url.Values, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := a.http.Do(req)
	if err != nil {
		return err
	}
	defer func() { _ = res.Body.Close() }()

	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return err
	}

	if err := json.Unmarshal(body, out); err != nil {
		return fmt.Errorf("unexpected response (%s)", res.Status)
	}

	return nil
}

// APIToken returns the token presented to Floor. When the environment sets
// ExchangeClientID, the login token is exchanged for one issued to Floor's
// provider (authentik JWT federation); the result is cached until it expires.
func (a *Authenticator) APIToken(ctx context.Context) (string, error) {
	login, err := a.AccessToken(ctx)
	if err != nil {
		return "", err
	}

	if a.oidc.ExchangeClientID == "" {
		return login, nil
	}

	a.mu.Lock()
	defer a.mu.Unlock()

	if a.exchanged.Valid() {
		return a.exchanged.AccessToken, nil
	}

	d, err := a.discover(ctx)
	if err != nil {
		return "", err
	}

	tok, err := a.exchange(ctx, d.TokenEndpoint, url.Values{
		"client_id":             {a.oidc.ExchangeClientID},
		"grant_type":            {"client_credentials"},
		"client_assertion_type": {"urn:ietf:params:oauth:client-assertion-type:jwt-bearer"},
		"client_assertion":      {login},
		"scope":                 {"openid email profile"},
	})
	if err != nil {
		return "", fmt.Errorf("exchanging token for floor: %w", err)
	}

	a.exchanged = tok

	return tok.AccessToken, nil
}

// Bearer adds the Floor API token to every request.
type Bearer struct {
	Auth *Authenticator
	Next http.RoundTripper
}

// RoundTrip implements http.RoundTripper.
func (b Bearer) RoundTrip(r *http.Request) (*http.Response, error) {
	tok, err := b.Auth.APIToken(r.Context())
	if err != nil {
		return nil, err
	}

	r = r.Clone(r.Context())
	r.Header.Set("Authorization", "Bearer "+tok)

	return b.Next.RoundTrip(r)
}
