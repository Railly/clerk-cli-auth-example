// PLACEHOLDER — Codex Agent A implements this.
// Required exports:
//   exchangeCodeForTokens(params) → POST {issuer}/oauth/token with grant_type=authorization_code
//   refreshAccessToken(params)    → POST {issuer}/oauth/token with grant_type=refresh_token
//   fetchUserInfo(params)         → GET  {issuer}/oauth/userinfo with Bearer access_token
//
// Use `fetch` (Node 18+). Return TokenSet / UserInfo shapes from ../types.

import type { TokenSet, UserInfo } from "../types.js";

export interface ExchangeParams {
	issuer: string;
	clientId: string;
	code: string;
	codeVerifier: string;
	redirectUri: string;
}

export interface RefreshParams {
	issuer: string;
	clientId: string;
	refreshToken: string;
	scopes?: string[];
}

export interface UserInfoParams {
	issuer: string;
	accessToken: string;
}

export async function exchangeCodeForTokens(_params: ExchangeParams): Promise<TokenSet> {
	throw new Error("token-exchange.exchangeCodeForTokens not implemented");
}

export async function refreshAccessToken(_params: RefreshParams): Promise<TokenSet> {
	throw new Error("token-exchange.refreshAccessToken not implemented");
}

export async function fetchUserInfo(_params: UserInfoParams): Promise<UserInfo> {
	throw new Error("token-exchange.fetchUserInfo not implemented");
}
