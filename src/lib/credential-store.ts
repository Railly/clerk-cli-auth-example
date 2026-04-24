// PLACEHOLDER — Codex Agent A implements this.
// Required export: `createCredentialStore(kind, options)` returning a CredentialStore.
//
// - "keychain": use @napi-rs/keyring (already in package.json).
//               Service = options.keychainService || "clerk-cli-auth".
//               Account = `{environment}:{key}` for namespacing.
// - "file":     JSON blob at ~/.config/clerk-cli-auth/{environment}.json with chmod 600.
// - "memory":   in-process Map, for testing.
//
// Keychain should fall back to file with a console.warn if @napi-rs/keyring init throws.

import type { CredentialStore, StorageKind } from "../types.js";

export interface CreateStoreOptions {
	keychainService?: string;
	environment?: string;
	filePath?: string;
}

export function createCredentialStore(
	_kind: StorageKind,
	_options?: CreateStoreOptions,
): CredentialStore {
	throw new Error("credential-store.createCredentialStore not implemented");
}
