// PLACEHOLDER — Codex Agent A implements this.
// Required export: `startAuthServer(options)` — spawns an ephemeral HTTP server on 127.0.0.1
// (port 0 = random, or options.port if set). Returns { port, redirectUri, waitForCallback, close }.
//
// waitForCallback() resolves with { code, state } when the browser hits /callback,
// validates state matches expected, and rejects on timeout/mismatch.
//
// Implementation guidance: use `node:http`, not Bun.serve. The server must:
// - Only accept one request, then close cleanly.
// - Respond with a friendly HTML "You can close this tab" page.
// - Reject if state mismatch or if error query param present.

export interface AuthServerOptions {
	expectedState: string;
	port?: number;
	timeoutMs?: number;
	successHtml?: string;
	errorHtml?: string;
}

export interface AuthServerHandle {
	port: number;
	redirectUri: string;
	waitForCallback(): Promise<{ code: string; state: string }>;
	close(): void;
}

export function startAuthServer(_options: AuthServerOptions): Promise<AuthServerHandle> {
	throw new Error("auth-server.startAuthServer not implemented");
}
