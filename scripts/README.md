# Local integration scripts

These scripts are for Hunter's local `@clerk/cli-auth` prototype testing. They use Hunter's internal Clerk CLI from `/Users/raillyhugo/Clerk/cli` and the demo consumer at `/Users/raillyhugo/Programming/railly/clerk-cli-auth-demo`.

All backend-mutating scripts default to dry-run. Pass `--apply` to create or delete anything in Clerk.

## `provision-oauth-app.sh`

Creates a public, PKCE-required OAuth Application for the demo CLI.

Flags:

- `--name "<app name>"`: OAuth Application name. Default: `cli-auth-local-test`.
- `--redirect-uri "<uri>"`: redirect URI. Default: `http://127.0.0.1:0/callback`.
- `--instance <id>`: optional instance id or `dev`, `development`, `prod`, `production`. If omitted, the script selects the single development instance from `clerk apps list --json`; if more than one exists, pass the full instance id.
- `--apply`: perform the create. Without this flag, the script only prints commands and payloads.

Example:

```bash
scripts/provision-oauth-app.sh
scripts/provision-oauth-app.sh --apply --instance ins_...
```

On success, it prints:

```bash
export CLERK_OAUTH_CLIENT_ID="..."
export CLERK_ISSUER="..."
```

Save those values for the demo:

```bash
cat > ~/.clerk-cli-auth-demo.env <<'ENV'
export CLERK_OAUTH_CLIENT_ID="..."
export CLERK_ISSUER="..."
ENV
```

## `teardown-oauth-app.sh`

Deletes the test OAuth Application. It resolves the BAPI `oauth_application_id` by `client_id` or by exact name match.

Flags:

- `--client-id <id>`: lookup by OAuth `client_id`.
- `--name "<app name>"`: lookup by exact OAuth Application name. Default: `cli-auth-local-test`.
- `--instance <id>`: optional instance id or environment alias, same behavior as provisioning.
- `--apply`: perform the delete. Without this flag, the script only prints commands.

Examples:

```bash
scripts/teardown-oauth-app.sh --client-id oap_...
scripts/teardown-oauth-app.sh --name "cli-auth-local-test" --apply --instance ins_...
```

## `local-test.sh`

Checks prerequisites and prints the manual demo steps. It never runs the demo CLI because the browser approval is manual.

Flags:

- `--check`: validate prerequisites only. Does not prompt or print the manual test recipe.

Checks:

- `bun` and `node` are available.
- SDK repo exists.
- demo consumer repo exists.
- Hunter's internal Clerk CLI source exists.
- Hunter's Clerk CLI is authenticated.
- SDK is built at `dist/index.mjs`.
- `~/.clerk-cli-auth-demo.env` exists with `CLERK_OAUTH_CLIENT_ID` and `CLERK_ISSUER`.

Run:

```bash
scripts/local-test.sh --check
scripts/local-test.sh
```

## End-to-end recipe

1. Build the SDK if needed:

   ```bash
   bun run build
   ```

2. Dry-run provisioning:

   ```bash
   scripts/provision-oauth-app.sh --instance ins_...
   ```

3. Create the OAuth Application:

   ```bash
   scripts/provision-oauth-app.sh --apply --instance ins_...
   ```

4. Save the printed exports:

   ```bash
   cat > ~/.clerk-cli-auth-demo.env <<'ENV'
   export CLERK_OAUTH_CLIENT_ID="..."
   export CLERK_ISSUER="..."
   ENV
   ```

5. Validate local prerequisites:

   ```bash
   scripts/local-test.sh --check
   ```

6. Print and follow the manual demo flow:

   ```bash
   scripts/local-test.sh
   ```

7. In the demo repo terminal:

   ```bash
   cd ../clerk-cli-auth-demo
   bun run demo-cli login
   bun run demo-cli whoami
   bun run demo-cli logout
   ```

8. Cleanup when finished:

   ```bash
   scripts/teardown-oauth-app.sh --client-id "..." --apply --instance ins_...
   ```

## Troubleshooting

### Keychain is locked

Hunter's internal CLI stores OAuth credentials in the macOS keychain. Unlock the login keychain, then rerun:

```bash
bun run --cwd /Users/raillyhugo/Clerk/cli/packages/cli-core src/cli.ts --mode agent whoami
```

### Redirect URI wildcard port is rejected

The default redirect URI is `http://127.0.0.1:0/callback` so the local auth server can bind an available port. If Clerk rejects port `0`, pick a fixed free port and pass it explicitly:

```bash
scripts/provision-oauth-app.sh --redirect-uri "http://127.0.0.1:8787/callback" --apply --instance ins_...
```

Then configure the demo to use the same fixed callback port if the prototype exposes that setting.

### Clerk CLI is not authenticated

Run Hunter's CLI login flow:

```bash
bun run --cwd /Users/raillyhugo/Clerk/cli/packages/cli-core src/cli.ts auth login
```

Then verify:

```bash
bun run --cwd /Users/raillyhugo/Clerk/cli/packages/cli-core src/cli.ts --mode agent whoami
```
