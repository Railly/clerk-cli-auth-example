# @clerk/cli-auth (local prototype)

OAuth 2.0 Authorization Code + PKCE flow for CLIs that want to authenticate users via Clerk. Wraps the same pattern that `~/Clerk/cli` already uses internally, extracted into a reusable, runtime-agnostic TypeScript SDK.

**Status:** local prototype. No publish, no remote push. See `05_Areas/clerk/cli-auth-sdk/00-proposal.md` in the vault for the full AIE-819 proposal.

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

## Provisioning an OAuth App (local only)

Use Hunter's `clerk` CLI (PLAPI) against his Clerk dev instance. Never push real credentials to git.

```bash
# from ~/Clerk/cli
clerk platform oauth-apps create \
	--name "cli-auth local test" \
	--redirect-uri "http://127.0.0.1:*/callback" \
	--pkce-required
```

(If wildcard-port redirect is not yet supported by clerk_go, register a fixed port and pass `callbackPort` in config.)
