# Implementation Notes

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
