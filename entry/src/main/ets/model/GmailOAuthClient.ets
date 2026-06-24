import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import util from '@ohos.util';
import { CredentialStore } from './DynamicCredentialStore';

export const GMAIL_ACCESS_TOKEN_REF: string = 'gmail:mcp_oauth';
export const GMAIL_REFRESH_TOKEN_REF: string = 'gmail:mcp_refresh';
export const GMAIL_TOKEN_SET_REF: string = 'gmail:mcp_tokens';
export const GMAIL_PENDING_OAUTH_REF: string = 'gmail:mcp_pending_oauth';
export const GMAIL_DEFAULT_REDIRECT_URI: string = 'com.example.aiphonedemo:/oauth/google';
export const GMAIL_MCP_RESOURCE: string = 'https://gmailmcp.googleapis.com/mcp';
export const GMAIL_OAUTH_SCOPES: string = 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose';

const GOOGLE_OAUTH_AUTH_URL: string = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_OAUTH_TOKEN_URL: string = 'https://oauth2.googleapis.com/token';
const TOKEN_EXPIRY_SKEW_MS: number = 60000;

export interface GmailOAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  resource: string;
}

export interface GmailOAuthAuthorizeParams {
  clientId: string;
  redirectUri: string;
  state: string;
  codeChallenge: string;
  resource: string;
}

export interface GmailOAuthRedirectResult {
  ok: boolean;
  code: string;
  state: string;
  error: string;
}

export interface GmailOAuthPending {
  state: string;
  codeVerifier: string;
  createdAtMs: number;
}

export interface GoogleOAuthTokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  scope?: string;
  error?: string;
  error_description?: string;
}

export interface GmailOAuthTokenSet {
  accessToken: string;
  refreshToken: string;
  expiresAtMs: number;
  tokenType: string;
  scope: string;
}

export class GmailSearchThreadsArgs {
  query: string;
  pageSize: number;

  constructor(query: string, pageSize: number) {
    this.query = query;
    this.pageSize = pageSize;
  }
}

export class GmailGetThreadArgs {
  threadId: string;
  messageFormat: string;

  constructor(threadId: string, messageFormat: string) {
    this.threadId = threadId;
    this.messageFormat = messageFormat;
  }
}

export class GmailCreateDraftArgs {
  to: string[];
  subject: string;
  body: string;

  constructor(to: string[], subject: string, body: string) {
    this.to = to;
    this.subject = subject;
    this.body = body;
  }
}

type QueryValueMap = Record<string, string>;

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function numberOf(value: number | undefined, fallback: number): number {
  if (value === undefined || value <= 0) {
    return fallback;
  }
  return value;
}

function urlEncode(value: string): string {
  return encodeURIComponent(value);
}

function urlDecode(value: string): string {
  return decodeURIComponent(value.replace(/\+/g, ' '));
}

function appendFormPair(parts: string[], key: string, value: string): void {
  if (value.length === 0) {
    return;
  }
  parts.push(urlEncode(key) + '=' + urlEncode(value));
}

function parseQuery(query: string): QueryValueMap {
  const values: QueryValueMap = {};
  if (query.length === 0) {
    return values;
  }
  const pairs = query.split('&');
  for (let index = 0; index < pairs.length; index++) {
    const pair = pairs[index];
    if (pair.length === 0) {
      continue;
    }
    const eq = pair.indexOf('=');
    const key = eq < 0 ? pair : pair.substring(0, eq);
    const value = eq < 0 ? '' : pair.substring(eq + 1);
    values[urlDecode(key)] = urlDecode(value);
  }
  return values;
}

function queryStringFromUri(uri: string): string {
  const queryStart = uri.indexOf('?');
  if (queryStart < 0) {
    return '';
  }
  const hashStart = uri.indexOf('#', queryStart + 1);
  if (hashStart < 0) {
    return uri.substring(queryStart + 1);
  }
  return uri.substring(queryStart + 1, hashStart);
}

function bytesToBase64Url(bytes: Uint8Array): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const triple = (first << 16) | (second << 8) | third;
    result += alphabet.charAt((triple >> 18) & 0x3f);
    result += alphabet.charAt((triple >> 12) & 0x3f);
    result += index + 1 < bytes.length ? alphabet.charAt((triple >> 6) & 0x3f) : '=';
    result += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
  }
  return result.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function utf8Bytes(value: string): Uint8Array {
  return new util.TextEncoder().encodeInto(value);
}

export function gmailPkceChallengeS256(codeVerifier: string): string {
  const digest = cryptoFramework.createMd('SHA256');
  digest.updateSync({ data: utf8Bytes(codeVerifier) });
  return bytesToBase64Url(digest.digestSync().data);
}

export function createGmailOAuthPending(nowMs: number = Date.now()): GmailOAuthPending {
  const state = util.generateRandomUUID(true).replace(/-/g, '');
  const verifier = util.generateRandomUUID(true).replace(/-/g, '') + util.generateRandomUUID(true).replace(/-/g, '');
  return {
    state: state,
    codeVerifier: verifier,
    createdAtMs: nowMs
  };
}

export function buildGmailOAuthAuthorizationUrl(params: GmailOAuthAuthorizeParams): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', params.clientId.trim());
  appendFormPair(parts, 'redirect_uri', params.redirectUri.trim());
  appendFormPair(parts, 'response_type', 'code');
  appendFormPair(parts, 'scope', GMAIL_OAUTH_SCOPES);
  appendFormPair(parts, 'access_type', 'offline');
  appendFormPair(parts, 'prompt', 'consent');
  appendFormPair(parts, 'include_granted_scopes', 'true');
  appendFormPair(parts, 'resource', params.resource.trim());
  appendFormPair(parts, 'state', params.state.trim());
  appendFormPair(parts, 'code_challenge', params.codeChallenge.trim());
  appendFormPair(parts, 'code_challenge_method', 'S256');
  return GOOGLE_OAUTH_AUTH_URL + '?' + parts.join('&');
}

export function parseGmailOAuthRedirect(uri: string): GmailOAuthRedirectResult {
  const values = parseQuery(queryStringFromUri(uri));
  const error = values.error === undefined ? '' : values.error;
  if (error.length > 0) {
    return { ok: false, code: '', state: values.state === undefined ? '' : values.state, error: error };
  }
  const code = values.code === undefined ? '' : values.code;
  if (code.length === 0) {
    return { ok: false, code: '', state: values.state === undefined ? '' : values.state, error: 'missing_code' };
  }
  return { ok: true, code: code, state: values.state === undefined ? '' : values.state, error: '' };
}

export function buildGmailTokenExchangeBody(config: GmailOAuthConfig, code: string, codeVerifier: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId);
  appendFormPair(parts, 'client_secret', config.clientSecret);
  appendFormPair(parts, 'code', code);
  appendFormPair(parts, 'code_verifier', codeVerifier);
  appendFormPair(parts, 'redirect_uri', config.redirectUri);
  appendFormPair(parts, 'grant_type', 'authorization_code');
  appendFormPair(parts, 'resource', config.resource);
  return parts.join('&');
}

export function buildGmailRefreshTokenBody(config: GmailOAuthConfig, refreshToken: string): string {
  const parts: string[] = [];
  appendFormPair(parts, 'client_id', config.clientId);
  appendFormPair(parts, 'client_secret', config.clientSecret);
  appendFormPair(parts, 'refresh_token', refreshToken);
  appendFormPair(parts, 'grant_type', 'refresh_token');
  appendFormPair(parts, 'resource', config.resource);
  return parts.join('&');
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

async function postGoogleTokenForm(body: string): Promise<GoogleOAuthTokenResponse> {
  const request = http.createHttp();
  try {
    const response = await request.request(GOOGLE_OAUTH_TOKEN_URL, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      extraData: body,
      connectTimeout: 10000,
      readTimeout: 20000
    });
    const text = responseText(response.result);
    const payload = JSON.parse(text) as GoogleOAuthTokenResponse;
    if (response.responseCode < 200 || response.responseCode >= 300 || textOf(payload.error).length > 0) {
      const message = textOf(payload.error_description).length > 0 ? textOf(payload.error_description) : textOf(payload.error);
      throw new Error(message.length > 0 ? message : 'Google OAuth token exchange failed');
    }
    return payload;
  } finally {
    request.destroy();
  }
}

export async function exchangeGmailOAuthCode(
  config: GmailOAuthConfig,
  code: string,
  codeVerifier: string
): Promise<GoogleOAuthTokenResponse> {
  return postGoogleTokenForm(buildGmailTokenExchangeBody(config, code, codeVerifier));
}

export async function refreshGmailOAuthAccessToken(
  config: GmailOAuthConfig,
  refreshToken: string
): Promise<GoogleOAuthTokenResponse> {
  return postGoogleTokenForm(buildGmailRefreshTokenBody(config, refreshToken));
}

export async function loadGmailOAuthTokenSet(store: CredentialStore): Promise<GmailOAuthTokenSet | null> {
  const raw = await store.get(GMAIL_TOKEN_SET_REF);
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as GmailOAuthTokenSet;
  } catch (_error) {
    return null;
  }
}

export function isGmailAccessTokenFresh(token: GmailOAuthTokenSet, nowMs: number = Date.now()): boolean {
  return token.accessToken.length > 0 && nowMs + TOKEN_EXPIRY_SKEW_MS < token.expiresAtMs;
}

export async function saveGmailOAuthTokenSet(
  store: CredentialStore,
  response: GoogleOAuthTokenResponse,
  nowMs: number = Date.now()
): Promise<GmailOAuthTokenSet> {
  const accessToken = textOf(response.access_token);
  if (accessToken.length === 0) {
    throw new Error('Google OAuth response did not include an access token');
  }
  const existing = await loadGmailOAuthTokenSet(store);
  const refreshToken = textOf(response.refresh_token).length > 0 ? textOf(response.refresh_token) :
    (existing === null ? await store.get(GMAIL_REFRESH_TOKEN_REF) : existing.refreshToken);
  const expiresIn = numberOf(response.expires_in, 3600);
  const token: GmailOAuthTokenSet = {
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAtMs: nowMs + expiresIn * 1000 - TOKEN_EXPIRY_SKEW_MS,
    tokenType: textOf(response.token_type).length > 0 ? textOf(response.token_type) : 'Bearer',
    scope: textOf(response.scope)
  };
  await store.put(GMAIL_TOKEN_SET_REF, JSON.stringify(token));
  await store.put(GMAIL_ACCESS_TOKEN_REF, token.accessToken);
  if (token.refreshToken.length > 0) {
    await store.put(GMAIL_REFRESH_TOKEN_REF, token.refreshToken);
  }
  return token;
}

export async function saveGmailOAuthPending(store: CredentialStore, pending: GmailOAuthPending): Promise<void> {
  await store.put(GMAIL_PENDING_OAUTH_REF, JSON.stringify(pending));
}

export async function loadGmailOAuthPending(store: CredentialStore): Promise<GmailOAuthPending | null> {
  const raw = await store.get(GMAIL_PENDING_OAUTH_REF);
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as GmailOAuthPending;
  } catch (_error) {
    return null;
  }
}

export async function consumeGmailOAuthPending(store: CredentialStore): Promise<GmailOAuthPending | null> {
  const pending = await loadGmailOAuthPending(store);
  await store.remove(GMAIL_PENDING_OAUTH_REF);
  return pending;
}

export async function handleGmailOAuthRedirect(
  store: CredentialStore,
  config: GmailOAuthConfig,
  uri: string,
  nowMs: number = Date.now()
): Promise<GmailOAuthTokenSet> {
  const redirect = parseGmailOAuthRedirect(uri);
  if (!redirect.ok) {
    throw new Error(redirect.error.length > 0 ? redirect.error : 'Gmail OAuth callback failed');
  }
  const pending = await consumeGmailOAuthPending(store);
  if (pending === null || pending.state !== redirect.state) {
    throw new Error('Gmail OAuth state did not match');
  }
  const response = await exchangeGmailOAuthCode(config, redirect.code, pending.codeVerifier);
  return saveGmailOAuthTokenSet(store, response, nowMs);
}

export function gmailMcpToolNameForToolId(toolId: string): string {
  if (toolId === 'gmail.mail.search') {
    return 'search_threads';
  }
  if (toolId === 'gmail.thread.read') {
    return 'get_thread';
  }
  if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
    return 'create_draft';
  }
  return '';
}

function firstEmail(text: string): string {
  const match = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.exec(text);
  return match === null ? '' : match[0];
}

function textAfterSay(prompt: string): string {
  const marker = prompt.indexOf('说');
  if (marker >= 0 && marker < prompt.length - 1) {
    return prompt.substring(marker + 1).trim();
  }
  return prompt.trim();
}

function gmailSearchQuery(prompt: string): string {
  const parts: string[] = [];
  if (/重要|important/i.test(prompt)) {
    parts.push('is:important');
  }
  if (/未读|unread/i.test(prompt)) {
    parts.push('is:unread');
  }
  if (/收件箱|inbox/i.test(prompt)) {
    parts.push('in:inbox');
  }
  if (parts.length === 0 || /最新|最近|latest|recent/i.test(prompt)) {
    parts.push('newer_than:30d');
  }
  parts.push('-in:draft');
  return parts.join(' ');
}

export function gmailMcpArgsForPrompt(toolId: string, prompt: string): Object {
  if (toolId === 'gmail.mail.search') {
    return new GmailSearchThreadsArgs(gmailSearchQuery(prompt), 10);
  }
  if (toolId === 'gmail.thread.read') {
    return new GmailGetThreadArgs(prompt.trim(), 'FULL_CONTENT');
  }
  if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
    const recipient = firstEmail(prompt);
    const body = textAfterSay(prompt);
    return new GmailCreateDraftArgs(recipient.length > 0 ? [recipient] : [], 'Gmail draft from AIPhone', body.length > 0 ? body : prompt);
  }
  return new Object();
}
