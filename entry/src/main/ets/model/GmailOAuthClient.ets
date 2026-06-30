import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { CredentialStore } from './DynamicCredentialStore';
import { aiLogInfo } from './AiphoneLogger';
import { utf8Bytes } from './Utf8Bytes';
import {
  buildGoogleOAuthAuthorizationUrl,
  buildGoogleRefreshTokenBody,
  buildGoogleTokenExchangeBody,
  GoogleOAuthConfig,
  parseGoogleOAuthRedirect
} from './GoogleOAuthClient';

export const GMAIL_ACCESS_TOKEN_REF: string = 'gmail:mcp_oauth';
export const GMAIL_REFRESH_TOKEN_REF: string = 'gmail:mcp_refresh';
export const GMAIL_TOKEN_SET_REF: string = 'gmail:mcp_tokens';
export const GMAIL_PENDING_OAUTH_REF: string = 'gmail:mcp_pending_oauth';
export const GMAIL_DEFAULT_REDIRECT_URI: string = 'com.example.aiphonedemo:/oauth/google';
export const GMAIL_MCP_RESOURCE: string = 'https://gmailmcp.googleapis.com/mcp';
export const GMAIL_OAUTH_SCOPES: string = 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose';
export const GOOGLE_CLOUD_OAUTH_SCOPES: string = GMAIL_OAUTH_SCOPES + ' https://www.googleapis.com/auth/calendar.events';

const GOOGLE_OAUTH_AUTH_URL: string = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_OAUTH_TOKEN_URL: string = 'https://oauth2.googleapis.com/token';
const TOKEN_EXPIRY_SKEW_MS: number = 60000;

export interface GmailOAuthConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  resource: string;
  scopes?: string;
}

export interface GmailOAuthAuthorizeParams {
  clientId: string;
  redirectUri: string;
  state: string;
  codeChallenge: string;
  resource: string;
  scopes?: string;
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
  threadId: string;
  replyMode: string;
  inReplyTo: string;
  references: string;

  constructor(to: string[], subject: string, body: string, threadId: string = '', replyMode: string = '', inReplyTo: string = '', references: string = '') {
    this.to = to;
    this.subject = subject;
    this.body = body;
    this.threadId = threadId;
    this.replyMode = replyMode;
    this.inReplyTo = inReplyTo;
    this.references = references;
  }
}

type GmailArgRecord = Record<string, Object | string | number | boolean | null | undefined>;

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

function gmailArgRecord(args: Object | null): GmailArgRecord {
  if (args === null) {
    return JSON.parse('{}') as GmailArgRecord;
  }
  return args as GmailArgRecord;
}

function stringArg(args: GmailArgRecord, key: string): string {
  return textOf(args[key]);
}

function stringArrayArg(args: GmailArgRecord, key: string): string[] {
  const value = args[key];
  if (typeof value === 'string') {
    const text = value.trim();
    return text.length > 0 ? [text] : [];
  }
  if (!Array.isArray(value)) {
    return [];
  }
  const values = value as string[];
  const result: string[] = [];
  for (let index = 0; index < values.length; index++) {
    const text = textOf(values[index]).trim();
    if (text.length > 0) {
      result.push(text);
    }
  }
  return result;
}

function pageSizeArg(args: GmailArgRecord): number {
  const value = args['pageSize'];
  if (typeof value !== 'number' || value <= 0) {
    return 10;
  }
  return value > 10 ? 10 : value;
}

function charCount(value: string, target: string): number {
  let count = 0;
  for (let index = 0; index < value.length; index++) {
    if (value.charAt(index) === target) {
      count++;
    }
  }
  return count;
}

function previousNonSpaceChar(value: string, startIndex: number): string {
  for (let index = startIndex; index >= 0; index--) {
    const current = value.charAt(index);
    if (current !== ' ' && current !== '\t' && current !== '\n' && current !== '\r') {
      return current;
    }
  }
  return '';
}

function nextNonSpaceChar(value: string, startIndex: number): string {
  for (let index = startIndex; index < value.length; index++) {
    const current = value.charAt(index);
    if (current !== ' ' && current !== '\t' && current !== '\n' && current !== '\r') {
      return current;
    }
  }
  return '';
}

function removeDanglingQuoteAfterClosedGroup(query: string): string {
  if (charCount(query, '"') % 2 === 0) {
    return query;
  }
  for (let index = 0; index < query.length; index++) {
    if (query.charAt(index) === '"' &&
      previousNonSpaceChar(query, index - 1) === '}' &&
      (nextNonSpaceChar(query, index + 1) === '-' || nextNonSpaceChar(query, index + 1).length === 0)) {
      return query.substring(0, index) + query.substring(index + 1);
    }
  }
  return query;
}

function gmailSearchQueryFromArgs(args: GmailArgRecord): string {
  let query = stringArg(args, 'query').trim();
  if (query.length === 0) {
    query = 'newer_than:30d';
  }
  query = removeDanglingQuoteAfterClosedGroup(query);
  if (query.indexOf('-in:draft') < 0) {
    query += ' -in:draft';
  }
  return query;
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

const SHA256_K: number[] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

function rotateRight32(value: number, bits: number): number {
  return (value >>> bits) | (value << (32 - bits));
}

function sha256Bytes(data: Uint8Array): Uint8Array {
  const bytes: number[] = [];
  for (let index = 0; index < data.length; index++) {
    bytes.push(data[index]);
  }
  const bitLength = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) {
    bytes.push(0);
  }
  for (let shift = 56; shift >= 0; shift -= 8) {
    bytes.push(Math.floor(bitLength / Math.pow(2, shift)) & 0xff);
  }

  const hash: number[] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  const words: number[] = new Array<number>(64);
  for (let chunk = 0; chunk < bytes.length; chunk += 64) {
    for (let index = 0; index < 16; index++) {
      const offset = chunk + index * 4;
      words[index] = ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
    }
    for (let index = 16; index < 64; index++) {
      const s0 = rotateRight32(words[index - 15], 7) ^ rotateRight32(words[index - 15], 18) ^ (words[index - 15] >>> 3);
      const s1 = rotateRight32(words[index - 2], 17) ^ rotateRight32(words[index - 2], 19) ^ (words[index - 2] >>> 10);
      words[index] = (words[index - 16] + s0 + words[index - 7] + s1) >>> 0;
    }
    let a = hash[0];
    let b = hash[1];
    let c = hash[2];
    let d = hash[3];
    let e = hash[4];
    let f = hash[5];
    let g = hash[6];
    let h = hash[7];
    for (let index = 0; index < 64; index++) {
      const s1 = rotateRight32(e, 6) ^ rotateRight32(e, 11) ^ rotateRight32(e, 25);
      const ch = (e & f) ^ (~e & g);
      const temp1 = (h + s1 + ch + SHA256_K[index] + words[index]) >>> 0;
      const s0 = rotateRight32(a, 2) ^ rotateRight32(a, 13) ^ rotateRight32(a, 22);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (s0 + maj) >>> 0;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) >>> 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) >>> 0;
    }
    hash[0] = (hash[0] + a) >>> 0;
    hash[1] = (hash[1] + b) >>> 0;
    hash[2] = (hash[2] + c) >>> 0;
    hash[3] = (hash[3] + d) >>> 0;
    hash[4] = (hash[4] + e) >>> 0;
    hash[5] = (hash[5] + f) >>> 0;
    hash[6] = (hash[6] + g) >>> 0;
    hash[7] = (hash[7] + h) >>> 0;
  }

  const digest: number[] = [];
  hash.forEach((word: number) => {
    digest.push((word >>> 24) & 0xff, (word >>> 16) & 0xff, (word >>> 8) & 0xff, word & 0xff);
  });
  return new Uint8Array(digest);
}

export function gmailPkceChallengeS256(codeVerifier: string): string {
  return bytesToBase64Url(sha256Bytes(utf8Bytes(codeVerifier)));
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
  const scopes = params.scopes === undefined || params.scopes.trim().length === 0 ? GMAIL_OAUTH_SCOPES : params.scopes;
  return buildGoogleOAuthAuthorizationUrl({
    authUrl: GOOGLE_OAUTH_AUTH_URL,
    clientId: params.clientId,
    redirectUri: params.redirectUri,
    state: params.state,
    codeChallenge: params.codeChallenge,
    scopes: scopes,
    resource: params.resource
  });
}

export function parseGmailOAuthRedirect(uri: string): GmailOAuthRedirectResult {
  return parseGoogleOAuthRedirect(uri) as GmailOAuthRedirectResult;
}

export function buildGmailTokenExchangeBody(config: GmailOAuthConfig, code: string, codeVerifier: string): string {
  const googleConfig: GoogleOAuthConfig = {
    clientId: config.clientId,
    clientSecret: config.clientSecret,
    redirectUri: config.redirectUri,
    resource: config.resource
  };
  return buildGoogleTokenExchangeBody(googleConfig, code, codeVerifier);
}

export function buildGmailRefreshTokenBody(config: GmailOAuthConfig, refreshToken: string): string {
  const googleConfig: GoogleOAuthConfig = {
    clientId: config.clientId,
    clientSecret: config.clientSecret,
    redirectUri: config.redirectUri,
    resource: config.resource
  };
  return buildGoogleRefreshTokenBody(googleConfig, refreshToken);
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

function tokenResponseSummary(response: GoogleOAuthTokenResponse): string {
  return 'accessChars=' + textOf(response.access_token).length.toString() +
    ' refreshChars=' + textOf(response.refresh_token).length.toString() +
    ' expiresIn=' + numberOf(response.expires_in, 0).toString() +
    ' tokenType=' + textOf(response.token_type) +
    ' scopeChars=' + textOf(response.scope).length.toString();
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
    aiLogInfo('[AIPhone][GmailOAuthTokenHttp] code=' + response.responseCode.toString() +
      ' responseChars=' + text.length.toString() +
      ' hasOAuthError=' + (textOf(payload.error).length > 0 ? 'true' : 'false'));
    if (response.responseCode < 200 || response.responseCode >= 300 || textOf(payload.error).length > 0) {
      const message = textOf(payload.error_description).length > 0 ? textOf(payload.error_description) : textOf(payload.error);
      aiLogInfo('[AIPhone][GmailOAuthTokenError] code=' + response.responseCode.toString() +
        ' oauthError=' + textOf(payload.error) +
        ' descriptionChars=' + textOf(payload.error_description).length.toString());
      throw new Error(message.length > 0 ? message : 'Google OAuth token exchange failed');
    }
    aiLogInfo('[AIPhone][GmailOAuthTokenOk] ' + tokenResponseSummary(payload));
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
  aiLogInfo('[AIPhone][GmailOAuthTokenSaveStart] ' + tokenResponseSummary(response) +
    ' existingTokenSet=' + (existing === null ? 'false' : 'true') +
    ' persistedRefreshChars=' + refreshToken.length.toString());
  const expiresIn = numberOf(response.expires_in, 3600);
  const responseScope = textOf(response.scope);
  const token: GmailOAuthTokenSet = {
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAtMs: nowMs + expiresIn * 1000 - TOKEN_EXPIRY_SKEW_MS,
    tokenType: textOf(response.token_type).length > 0 ? textOf(response.token_type) : 'Bearer',
    scope: responseScope.length > 0 ? responseScope : (existing === null ? '' : existing.scope)
  };
  await store.put(GMAIL_TOKEN_SET_REF, JSON.stringify(token));
  await store.put(GMAIL_ACCESS_TOKEN_REF, token.accessToken);
  if (token.refreshToken.length > 0) {
    await store.put(GMAIL_REFRESH_TOKEN_REF, token.refreshToken);
  }
  aiLogInfo('[AIPhone][GmailOAuthTokenSaved] tokenSetChars=' + JSON.stringify(token).length.toString() +
    ' accessChars=' + token.accessToken.length.toString() +
    ' refreshChars=' + token.refreshToken.length.toString());
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
  aiLogInfo('[AIPhone][GmailOAuthRedirectParsed] ok=' + (redirect.ok ? 'true' : 'false') +
    ' codeChars=' + redirect.code.length.toString() +
    ' stateChars=' + redirect.state.length.toString() +
    ' error=' + redirect.error);
  if (!redirect.ok) {
    throw new Error(redirect.error.length > 0 ? redirect.error : 'Gmail OAuth callback failed');
  }
  const pending = await consumeGmailOAuthPending(store);
  aiLogInfo('[AIPhone][GmailOAuthPendingLoaded] found=' + (pending === null ? 'false' : 'true') +
    ' stateMatch=' + (pending !== null && pending.state === redirect.state ? 'true' : 'false') +
    ' ageMs=' + (pending === null ? '0' : (nowMs - pending.createdAtMs).toString()));
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

export function gmailMcpArgsForPrompt(toolId: string, prompt: string, args: Object | null = null): Object {
  const record = gmailArgRecord(args);
  if (toolId === 'gmail.mail.search') {
    return new GmailSearchThreadsArgs(gmailSearchQueryFromArgs(record), pageSizeArg(record));
  }
  if (toolId === 'gmail.thread.read') {
    const threadId = stringArg(record, 'threadId').trim();
    return new GmailGetThreadArgs(threadId.length > 0 ? threadId : prompt.trim(), 'FULL_CONTENT');
  }
  if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
    return new GmailCreateDraftArgs(
      stringArrayArg(record, 'to'),
      stringArg(record, 'subject'),
      stringArg(record, 'body'),
      stringArg(record, 'threadId').trim(),
      stringArg(record, 'replyMode').trim()
    );
  }
  return new Object();
}
