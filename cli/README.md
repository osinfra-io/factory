# factory CLI

Terminal UI for managing Factory through Floor, built with Go and Bubble Tea.

```bash
cd cli
go run ./cmd/factory --env local
```

The first release lists Floor workspaces, shows the planned changes of the selected pending plan, and approves or rejects it after an explicit confirmation. Approving starts a cloud apply.

The UI has workspace cards on the left and a pane with `Changes`, `Details`, `Diff` (when the workspace has commits) and `Dependencies` tabs on the right. The mouse works everywhere: click a card, a card action, a tab, a footer hint or a resource (click again, or press `esc`, to collapse its full attribute changes), and scroll with the wheel. With nothing selected the pane is an overview of what the factory is doing: health counts and an overall progress bar, what needs you (approvals, failures), what is applying now and for how long, what is waiting and on what, one progress row per namespace (applied count, the dependency stage it has reached, anything awaiting, failed or waiting) and recent activity. Press `enter` or click a namespace to list what is left in it (failed first, then awaiting approval, applying and waiting, each with what it is waiting on), walk it with `↑/↓` and open a workspace with `enter`; finished workspaces fold into a count. The header warns when a runner token is expired or about to be (read from the bootstrap secret in each namespace), and the left list shows full cards only for workspaces that need you (awaiting approval, applying or failed) and one line each for the healthy ones below. Keys: `↑/↓` select, `esc` goes back (workspace → overview), `ctrl+d`/`ctrl+u` scroll, `a` approve, `r` reject, `space` select a plan (or click its dot) and `m` select all, then `a` (or `A`) to approve the selected plans together (each is re-read and hash-checked, and plans that delete resources are left for one-at-a-time approval; the pane then lists every plan live until it is applied, and `esc` closes it), `tab` switch tabs, `e` expand or collapse every change like a full plan, `d` details (which also lists the commits and files an apply would bring in, read from the local Factory checkout when it has them; the `Diff` tab (or `c`) shows the full code diff, or click a file for just that file, `esc` goes back), `t` dependency tree (click a workspace in it to jump there; `esc` or `tab` goes back), `pgup/pgdn` scroll, `p` pending/all, `R` refresh, `T` renews expiring runner tokens by running `bootstrap/seed/prepare.sh` for their environments (local Docker Desktop only, from a Factory checkout), `E` (or click the environment name in the header) opens an environment dropdown when several are configured, `q` quit.

Approval is only enabled once the plan has been read and shown. Just before approving, the plan is re-read and the approval is refused if its hash changed. A plan that deletes or replaces resources needs `D` instead of `y`.

Errors wrap to the terminal width; use `[` and `]` to scroll an error that exceeds the available space. Press `M` to release mouse capture and select text using the terminal, then press `M` again to restore mouse controls.

The sidebar groups workspaces by namespace. Click a namespace heading to fold or expand it, or press `N` to toggle the namespace of the current workspace.

## Environments

Environments live in `~/.config/factory/config.json` (override with `--config`). `local` defaults to `https://floor.localhost/mcp`.

```json
{
  "environments": {
    "local-visitor": {
      "url": "https://floor.localhost/mcp",
      "caFile": "tests/integration/istio/.work/gateway-localhost.crt",
      "username": "floor-visitor",
      "kubeContext": "docker-desktop",
      "passwordFile": "tests/integration/floor/.work/auth/visitor-token"
    }
  }
}
```

`username` and `passwordFile` use an authentik app password, which is read-only unless the user is in the approver group. `kubeContext` is where plan contents are read, with your own kubeconfig, exactly as `bootstrap/seed/review.sh` does; Floor never has access to Secrets. Environments without a `kubeContext` can list workspaces but cannot approve.

## Signing in with Google

Environments without `username` sign in through authentik, where you choose Google. Run `factory login --env local` and open the printed URL in your browser (authorization code flow with PKCE, redirecting to a loopback port). Tokens are cached under the user config dir (`factory/tokens/`, mode 0600) and refreshed automatically.

```json
"local": {
  "url": "https://floor.localhost/mcp",
  "caFile": "/path/to/gateway-localhost.crt",
  "kubeContext": "docker-desktop",
  "oidc": {
    "issuer": "https://authentik.localhost/application/o/factory-cli/",
    "clientId": "factory-cli",
    "exchangeClientId": "<floor proxy provider client id>"
  }
}
```

The issuer is the `cli_issuer_url` output of the authentik config module, enabled by `cli_oidc_browser_keys`. The outpost only accepts tokens issued to Floor's own proxy provider, so after login the CLI exchanges its token for one (authentik JWT federation); `exchangeClientId` comes from the `cli_exchange_client_ids` output. Your Google account must be in the approver group to approve. Plan review for remote environments is a planned follow-up.
