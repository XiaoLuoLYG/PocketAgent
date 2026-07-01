import { describe, it, expect } from '@ohos/hypium';
import {
  emptySocialHub,
  normalizeSocialHubConnection,
  normalizeSocialHubDraft,
  normalizeSocialHubItem
} from '../main/ets/model/SocialHubTypes';

export default function socialHubTypesTest() {
  describe('socialHubTypes', () => {
    it('normalizes X posts without inventing missing text', 0, () => {
      const item = normalizeSocialHubItem({
        id: 'x-1',
        platform: 'twitter',
        kind: 'post',
        author: 'Ada',
        handle: '@ada',
        text: 'shipping notes',
        url: 'https://x.com/ada/status/1'
      });
      const emptyText = normalizeSocialHubItem({ platform: 'x', kind: 'post' });

      expect(item.platform).assertEqual('x');
      expect(item.kind).assertEqual('post');
      expect(item.text).assertEqual('shipping notes');
      expect(emptyText.text).assertEqual('');
    });

    it('normalizes Slack messages', 0, () => {
      const item = normalizeSocialHubItem({
        id: 'slack-1',
        platform: 'slack',
        kind: 'message',
        author: 'Lin',
        text: 'standup moved',
        channel: '#core'
      });

      expect(item.platform).assertEqual('slack');
      expect(item.kind).assertEqual('message');
      expect(item.channel).assertEqual('#core');
      expect(item.text).assertEqual('standup moved');
    });

    it('normalizes WeCom messages from aliases', 0, () => {
      const item = normalizeSocialHubItem({
        id: 'wecom-1',
        platform: '企业微信',
        kind: 'message',
        author: 'Qi',
        text: '请看审批'
      });
      const connection = normalizeSocialHubConnection({
        platform: 'wework',
        status: 'needs_auth',
        displayName: '企业微信'
      });

      expect(item.platform).assertEqual('wecom');
      expect(item.kind).assertEqual('message');
      expect(connection.platform).assertEqual('wecom');
      expect(connection.status).assertEqual('needs_auth');
    });

    it('keeps drafts local and unsent', 0, () => {
      const draft = normalizeSocialHubDraft({
        itemId: 'slack-1',
        platform: 'slack',
        text: 'Will reply later',
        status: 'draft',
        sent: true
      });

      expect(draft.platform).assertEqual('slack');
      expect(draft.status).assertEqual('draft');
      expect(draft.text).assertEqual('Will reply later');
      expect(draft.localOnly).assertTrue();
      expect(draft.sent).assertFalse();
    });

    it('allows connection auth to remain unresolved', 0, () => {
      const hub = emptySocialHub();
      const connection = normalizeSocialHubConnection({
        platform: 'x',
        status: 'needs_auth',
        message: 'OAuth required'
      });

      expect(hub.items.length).assertEqual(0);
      expect(connection.status).assertEqual('needs_auth');
      expect(connection.message).assertEqual('OAuth required');
    });
  });
}
