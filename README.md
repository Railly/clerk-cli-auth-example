# clerk-cli-auth

Reference implementation of the OAuth 2.0 Authorization Code + PKCE localhost-callback flow for adding [Clerk](https://clerk.com) authentication to command-line tools. Runtime-agnostic TypeScript, ~300 lines, tested.

**Status:** example / prototype. Fork it, copy it, or file-link it — there is no published package yet.

## Usage

```ts
import { ClerkCliAuth } from "@clerk/cli-auth";

const auth = new ClerkCliAuth({
	clientId: process.env.CLERK_OAUTH_CLIENT_ID!,
	issuer: process.env.CLERK_ISSUER!,   // e.g. https://clerk.myapp.com
	scopes: ["profile", "email", "openid", "offline_access"],
	storage: "keychain",
	keychainService: "my-cli",
});

const { tokens, user } = await auth.login();
console.log(`Hello ${user.email}`);

const token = await auth.getAccessToken(); // auto-refreshes if expired
await auth.logout();
```

## Flow

1. Generate PKCE code_verifier + code_challenge (S256) and CSRF state.
2. Start an ephemeral HTTP listener on `127.0.0.1:0`.
3. Open the user's browser to `{issuer}/oauth/authorize?client_id=...&code_challenge=...&redirect_uri=http://127.0.0.1:{port}/callback&state=...`.
4. User signs in via Clerk's hosted OAuth UI.
5. Clerk redirects to the ephemeral listener with `?code=...&state=...`.
6. SDK validates state, exchanges code for tokens at `{issuer}/oauth/token`.
7. Tokens stored in OS keychain (`@napi-rs/keyring`) with a file fallback.

## Development

```bash
bun install
bun run typecheck
bun test
bun run build
```

## Local testing with the demo consumer

See `../clerk-cli-auth-demo/` for a clean consumer repo that links this package via `file:`. Run `./scripts/local-test.sh` once OAuth App is provisioned.

## Provisioning an OAuth App against a Clerk dev instance

You need an OAuth Application registered with your Clerk dev instance. The `scripts/provision-oauth-app.sh` helper wraps the `clerk` CLI for that; see [`scripts/README.md`](./scripts/README.md). Never commit secrets to git.

```bash
scripts/provision-oauth-app.sh --apply --instance <ins_...>
```

The script prints `CLERK_OAUTH_CLIENT_ID` and `CLERK_ISSUER` exports that you feed to the SDK via `process.env`.
