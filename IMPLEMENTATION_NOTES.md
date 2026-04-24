# Implementation Notes

## Done

- Implemented OAuth 2.0 Authorization Code + PKCE S256 helpers using `node:crypto`.
- Implemented the localhost callback server with `node:http` on `127.0.0.1`, including state validation, timeout rejection, and explicit close handling.
- Implemented token exchange, refresh, and userinfo fetch against `{issuer}/oauth/token` and `{issuer}/oauth/userinfo` using global `fetch`.
- Implemented credential stores for memory, file, and keychain-with-file-fallback using `@napi-rs/keyring`.
- Implemented `ClerkCliAuth` orchestration: config normalization, login, token refresh, whoami cache, logout, and stored token parsing.
- Added tsup config so builds emit the package contract files: `dist/index.cjs`, `dist/index.mjs`, and `dist/index.d.ts`.

## Decisions

- The verifier is `base64url(randomBytes(32))`, which yields the required 43-character RFC 7636-compatible verifier.
- The file credential store writes a single JSON object and serializes operations through a per-store promise queue to avoid lost updates under concurrent calls.
- Keychain loading is lazy. If keyring initialization or an operation fails, the store logs a warning and uses the file fallback.
- The default browser opener prints the URL before attempting a platform opener. Tests inject `openBrowser` and do not open a real browser.
- `getAccessToken()` returns `null` for expired tokens without a refresh token, and refreshes when the token is within 30 seconds of expiry.

## Test Coverage Snapshot

- `tests/pkce.test.ts`: verifier length and charset, RFC S256 vector, state uniqueness.
- `tests/auth-server.test.ts`: successful callback, state mismatch rejection, timeout rejection.
- `tests/credential-store.test.ts`: memory round-trip, file chmod 600, concurrent file set/get.
- `tests/clerk-cli-auth.test.ts`: end-to-end login against local stub OAuth endpoints with injected browser callback.

## Verification

- `bun run typecheck` passes.
- `bun test` passes.
- `bun run test` passes.
- `bun run lint` passes.
- `bun run build` passes and emits `dist/index.cjs`, `dist/index.mjs`, and `dist/index.d.ts`.

## Known Gaps

- This is still a local prototype. It does not implement token revocation on logout.
- The keychain path is covered structurally through implementation, but automated tests use memory and file stores to avoid OS credential-manager prompts or platform-specific behavior.

## Integration Testing

Local integration testing is driven by the scripts in `scripts/`. Provisioning and teardown are dry-run by default; pass `--apply` only when intentionally mutating Hunter's Clerk dev instance.

Recipe:

1. Build the SDK with `bun run build` so `dist/index.mjs` exists.
2. Dry-run the OAuth Application create with `scripts/provision-oauth-app.sh --instance <instance_id>`.
3. Create it with `scripts/provision-oauth-app.sh --apply --instance <instance_id>`.
4. Save the printed `CLERK_OAUTH_CLIENT_ID` and `CLERK_ISSUER` exports to `~/.clerk-cli-auth-demo.env`.
5. Validate local prerequisites with `scripts/local-test.sh --check`.
6. Run `scripts/local-test.sh` and follow the printed manual demo commands from the demo repo.
7. Delete the test OAuth Application with `scripts/teardown-oauth-app.sh --client-id <client_id> --apply --instance <instance_id>`.

Hunter's manual go/no-go checkpoints:

- `bun run demo-cli login` opens the browser and completes consent.
- Login prints `Logged in as <email>`.
- `bun run demo-cli whoami` returns the same email.
- `bun run demo-cli logout` prints `Logged out.`
- A subsequent `whoami` should no longer report an authenticated user.
