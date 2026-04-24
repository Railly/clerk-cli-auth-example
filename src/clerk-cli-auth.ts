import type {
	ClerkCliAuthConfig,
	CredentialStore,
	LoginResult,
	TokenSet,
	UserInfo,
} from "./types.js";
import { ClerkCliAuthError } from "./types.js";

/**
 * NOTE FOR CODEX AGENT A:
 * This is the SKELETON. Fill in each method with real implementations
 * that compose the helpers in ./lib/pkce.ts, ./lib/auth-server.ts,
 * ./lib/token-exchange.ts, and ./lib/credential-store.ts.
 *
 * Keep the class signatures exactly as declared here — the demo consumer
 * (agent B) imports against these types.
 */
export class ClerkCliAuth {
	private readonly config: Required<Omit<ClerkCliAuthConfig, "openBrowser" | "storage">> & {
		storage: CredentialStore;
		openBrowser?: (url: string) => Promise<void>;
	};

	constructor(config: ClerkCliAuthConfig) {
		if (!config.clientId) throw new ClerkCliAuthError("config", "clientId is required");
		if (!config.issuer) throw new ClerkCliAuthError("config", "issuer is required");
		// Concrete init happens in implementation — placeholder assignment to satisfy TS.
		this.config = {} as typeof this.config;
		void config;
	}

	async login(): Promise<LoginResult> {
		throw new ClerkCliAuthError("not_implemented", "ClerkCliAuth.login() not yet implemented");
	}

	async getAccessToken(): Promise<string | null> {
		throw new ClerkCliAuthError(
			"not_implemented",
			"ClerkCliAuth.getAccessToken() not yet implemented",
		);
	}

	async whoami(): Promise<UserInfo | null> {
		throw new ClerkCliAuthError("not_implemented", "ClerkCliAuth.whoami() not yet implemented");
	}

	async logout(): Promise<void> {
		throw new ClerkCliAuthError("not_implemented", "ClerkCliAuth.logout() not yet implemented");
	}

	async getTokenSet(): Promise<TokenSet | null> {
		throw new ClerkCliAuthError(
			"not_implemented",
			"ClerkCliAuth.getTokenSet() not yet implemented",
		);
	}
}
