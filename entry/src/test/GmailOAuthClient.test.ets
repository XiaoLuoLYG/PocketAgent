import { describe, it, expect } from '@ohos/hypium';
import { MemoryCredentialStore } from '../main/ets/model/DynamicCredentialStore';
import {
  GMAIL_ACCESS_TOKEN_REF,
  GMAIL_REFRESH_TOKEN_REF,
  buildGmailOAuthAuthorizationUrl,
  buildGmailRefreshTokenBody,
  buildGmailTokenExchangeBody,
  gmailMcpArgsForPrompt,
  gmailMcpToolNameForToolId,
  gmailPkceChallengeS256,
  isGmailAccessTokenFresh,
  loadGmailOAuthTokenSet,
  parseGmailOAuthRedirect,
  saveGmailOAuthTokenSet
} from '../main/ets/model/GmailOAuthClient';

export default function gmailOAuthClientTest() {
  describe('gmailOAuthClient', () => {
    it('builds Google OAuth URLs with PKCE and the Gmail MCP scopes', 0, () => {
      const url = buildGmailOAuthAuthorizationUrl({
        clientId: 'client-123.apps.googleusercontent.com',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        state: 'state-123',
        codeChallenge: 'challenge-456',
        resource: 'https://gmailmcp.googleapis.com/mcp'
      });

      expect(url.indexOf('https://accounts.google.com/o/oauth2/v2/auth?')).assertEqual(0);
      expect(url.indexOf('client_id=client-123.apps.googleusercontent.com')).assertLarger(-1);
      expect(url.indexOf('redirect_uri=com.example.aiphonedemo%3A%2Foauth%2Fgoogle')).assertLarger(-1);
      expect(url.indexOf('scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.readonly%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.compose')).assertLarger(-1);
      expect(url.indexOf('state=state-123')).assertLarger(-1);
      expect(url.indexOf('code_challenge=challenge-456')).assertLarger(-1);
      expect(url.indexOf('code_challenge_method=S256')).assertLarger(-1);
      expect(url.indexOf('access_type=offline')).assertLarger(-1);
      expect(url.indexOf('resource=https%3A%2F%2Fgmailmcp.googleapis.com%2Fmcp')).assertLarger(-1);
    });

    it('generates the RFC 7636 S256 PKCE challenge', 0, () => {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(gmailPkceChallengeS256(verifier)).assertEqual('E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    });

    it('parses OAuth redirect results and rejects missing codes', 0, () => {
      const success = parseGmailOAuthRedirect('com.example.aiphonedemo:/oauth/google?code=auth-code&state=state-123&scope=gmail');
      const denied = parseGmailOAuthRedirect('com.example.aiphonedemo:/oauth/google?error=access_denied&state=state-123');

      expect(success.ok).assertTrue();
      expect(success.code).assertEqual('auth-code');
      expect(success.state).assertEqual('state-123');
      expect(denied.ok).assertFalse();
      expect(denied.error).assertEqual('access_denied');
    });

    it('builds token exchange and refresh request bodies without leaking unrelated fields', 0, () => {
      const exchange = buildGmailTokenExchangeBody({
        clientId: 'client-123',
        clientSecret: 'secret-456',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        resource: 'https://gmailmcp.googleapis.com/mcp'
      }, 'auth-code', 'verifier-789');
      const refresh = buildGmailRefreshTokenBody({
        clientId: 'client-123',
        clientSecret: '',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        resource: 'https://gmailmcp.googleapis.com/mcp'
      }, 'refresh-token');

      expect(exchange.indexOf('grant_type=authorization_code')).assertLarger(-1);
      expect(exchange.indexOf('code=auth-code')).assertLarger(-1);
      expect(exchange.indexOf('code_verifier=verifier-789')).assertLarger(-1);
      expect(exchange.indexOf('client_secret=secret-456')).assertLarger(-1);
      expect(exchange.indexOf('resource=https%3A%2F%2Fgmailmcp.googleapis.com%2Fmcp')).assertLarger(-1);
      expect(refresh.indexOf('grant_type=refresh_token')).assertLarger(-1);
      expect(refresh.indexOf('refresh_token=refresh-token')).assertLarger(-1);
      expect(refresh.indexOf('resource=https%3A%2F%2Fgmailmcp.googleapis.com%2Fmcp')).assertLarger(-1);
      expect(refresh.indexOf('client_secret=')).assertEqual(-1);
    });

    it('persists access and refresh tokens for next launch reuse', 0, async () => {
      const store = new MemoryCredentialStore();
      await saveGmailOAuthTokenSet(store, {
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/gmail.readonly'
      }, 1000);

      const token = await loadGmailOAuthTokenSet(store);
      expect(await store.get(GMAIL_ACCESS_TOKEN_REF)).assertEqual('access-token');
      expect(await store.get(GMAIL_REFRESH_TOKEN_REF)).assertEqual('refresh-token');
      expect(token !== null).assertTrue();
      if (token !== null) {
        expect(token.accessToken).assertEqual('access-token');
        expect(token.refreshToken).assertEqual('refresh-token');
        expect(isGmailAccessTokenFresh(token, 1000 + 3000 * 1000)).assertTrue();
        expect(isGmailAccessTokenFresh(token, 1000 + 3600 * 1000)).assertFalse();
      }
    });

    it('maps app Gmail tool ids to official Gmail MCP tools and safe arguments', 0, () => {
      expect(gmailMcpToolNameForToolId('gmail.mail.search')).assertEqual('search_threads');
      expect(gmailMcpToolNameForToolId('gmail.thread.read')).assertEqual('get_thread');
      expect(gmailMcpToolNameForToolId('gmail.draft.create')).assertEqual('create_draft');

      const searchArgs = gmailMcpArgsForPrompt('gmail.mail.search', '帮我看 Gmail 里最新的重要邮件');
      const draftArgs = gmailMcpArgsForPrompt('gmail.draft.create', '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了');
      expect(JSON.stringify(searchArgs).indexOf('is:important')).assertLarger(-1);
      expect(JSON.stringify(searchArgs).indexOf('pageSize')).assertLarger(-1);
      expect(JSON.stringify(draftArgs).indexOf('alice@example.com')).assertLarger(-1);
      expect(JSON.stringify(draftArgs).indexOf('我收到了')).assertLarger(-1);
    });
  });
}
