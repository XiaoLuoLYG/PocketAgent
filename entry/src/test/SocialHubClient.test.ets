import { describe, it, expect } from '@ohos/hypium';
import { parseSocialHubDraftPayload, parseSocialHubFeedPayload, socialHubBridgeDraftError, socialHubBridgeHeaders, socialHubBridgeUnavailableFeed, socialHubXPostResult } from '../main/ets/model/SocialHubClient';

export default function socialHubClientTest() {
  describe('socialHubClient', () => {
    it('parses bridge feed payloads without renaming current SocialHub fields', 0, () => {
      const result = parseSocialHubFeedPayload('{"items":[{"id":"slack-1","platform":"slack","kind":"message","author":"Ada","handle":"@ada","text":"standup moved","timestamp":"2026-07-01T01:00:00.000Z","channel":"#core","threadId":"t-1","unread":true}],"connections":[{"platform":"x","status":"needs_auth","message":"OAuth required"}]}');

      expect(result.items.length).assertEqual(1);
      expect(result.items[0].channel).assertEqual('#core');
      expect(result.items[0].unread).assertTrue();
      expect(result.connections[0].platform).assertEqual('x');
      expect(result.connections[0].message).assertEqual('OAuth required');
    });

    it('parses draft payloads as local-only and unsent', 0, () => {
      const draft = parseSocialHubDraftPayload('{"draft":{"itemId":"x-1","platform":"x","text":"Thanks","status":"draft","sent":true}}');

      expect(draft.itemId).assertEqual('x-1');
      expect(draft.status).assertEqual('draft');
      expect(draft.localOnly).assertTrue();
      expect(draft.sent).assertFalse();
    });

    it('filters X post results away from private social feed rows', 0, () => {
      const filtered = socialHubXPostResult(parseSocialHubFeedPayload('{"items":[{"id":"x-1","platform":"x","kind":"post","text":"public post"},{"id":"x-2","platform":"x","kind":"message","text":"not public post"},{"id":"slack-1","platform":"slack","kind":"message","text":"private slack"},{"id":"wecom-1","platform":"wecom","kind":"message","text":"private wecom"}],"connections":[{"platform":"x","status":"connected","message":"X connected"},{"platform":"slack","status":"connected","message":"Slack connected"},{"platform":"wecom","status":"connected","message":"WeCom connected"}]}'));

      expect(filtered.items.length).assertEqual(1);
      expect(filtered.items[0].id).assertEqual('x-1');
      expect(filtered.connections.length).assertEqual(1);
      expect(filtered.connections[0].platform).assertEqual('x');
    });

    it('fails closed when the bridge is missing', 0, () => {
      const feed = socialHubBridgeUnavailableFeed('connect ECONNREFUSED');
      const draft = socialHubBridgeDraftError('x-1', 'x', 'connect ECONNREFUSED');

      expect(feed.items.length).assertEqual(0);
      expect(feed.connections.length).assertEqual(3);
      expect(feed.connections[0].status).assertEqual('error');
      expect(feed.connections[0].message.indexOf('connect ECONNREFUSED')).assertLarger(-1);
      expect(draft.itemId).assertEqual('x-1');
      expect(draft.status).assertEqual('error');
      expect(draft.localOnly).assertTrue();
      expect(draft.sent).assertFalse();
    });

    it('adds the gateway API key header only when configured', 0, () => {
      const missing = socialHubBridgeHeaders('');
      const present = socialHubBridgeHeaders(' secret ');

      expect(Object.keys(missing).indexOf('X-API-Key')).assertEqual(-1);
      expect(present['X-API-Key']).assertEqual('secret');
      expect(present['Accept']).assertEqual('application/json');
    });
  });
}
