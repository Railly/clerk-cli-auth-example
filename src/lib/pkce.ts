// PLACEHOLDER — Codex Agent A implements this.
// Required exports:
//   generateCodeVerifier(): string   // 43-char high-entropy base64url string (RFC 7636 §4.1)
//   generateCodeChallenge(verifier: string): Promise<string>  // SHA-256 of verifier, base64url (S256)
//   generateState(): string          // opaque CSRF token (32+ bytes, base64url)
//
// Implementation guidance: use `node:crypto` (randomBytes + createHash), no external deps.

export function generateCodeVerifier(): string {
	throw new Error("pkce.generateCodeVerifier not implemented");
}

export async function generateCodeChallenge(_verifier: string): Promise<string> {
	throw new Error("pkce.generateCodeChallenge not implemented");
}

export function generateState(): string {
	throw new Error("pkce.generateState not implemented");
}
