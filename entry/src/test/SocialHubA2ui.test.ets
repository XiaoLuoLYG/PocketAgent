import { describe, it, expect } from '@ohos/hypium';
import { resolveData } from '../main/ets/model/A2uiData';
import { parseA2uiJsonl } from '../main/ets/model/A2uiParser';
import { A2uiSurfaceStore } from '../main/ets/model/A2uiSurfaceStore';
import { SocialHubConnectionData, SocialHubDraftData, SocialHubItemData } from '../main/ets/model/SocialHubTypes';
import { socialHubDraftA2ui, socialHubFeedA2ui } from '../main/ets/model/SocialHubA2ui';

function applyJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    expect(store.apply(envelope).error).assertEqual('');
  });
  return store;
}

export default function socialHubA2uiTest() {
  describe('socialHubA2ui', () => {
    it('renders feed into SocialHub data paths', 0, () => {
      const items: SocialHubItemData[] = [{
        id: 'x-1',
        platform: 'x',
        kind: 'post',
        author: 'OpenAI',
        handle: '@openai',
        text: 'Hello',
        timestamp: '2026-07-01T01:00:00.000Z',
        url: 'https://x.com/openai/status/1',
        channel: '',
        threadId: '',
        unread: false
      }];
      const connections: SocialHubConnectionData[] = [{
        platform: 'slack',
        status: 'needs_auth',
        displayName: 'Slack',
        accountId: '',
        message: 'Slack OAuth required'
      }];
      const store = applyJsonl(socialHubFeedA2ui('surface_social_hub', items, connections));
      const parsedItems = resolveData(store.getSurface(), '/socialHub/items') as SocialHubItemData[];
      const selected = resolveData(store.getSurface(), '/socialHub/selected') as SocialHubItemData;
      const parsedConnections = resolveData(store.getSurface(), '/socialHub/connections') as SocialHubConnectionData[];

      expect(store.getSurface().intent).assertEqual('social');
      expect(store.getSurface().components[1].component).assertEqual('SocialHub');
      expect(parsedItems.length).assertEqual(1);
      expect(parsedItems[0].text).assertEqual('Hello');
      expect(selected.id).assertEqual('x-1');
      expect(parsedConnections[0].message).assertEqual('Slack OAuth required');
    });

    it('renders drafts as local unsent SocialHub state', 0, () => {
      const draft: SocialHubDraftData = {
        itemId: 'x-1',
        platform: 'x',
        text: 'Thanks for sharing.',
        status: 'draft',
        error: '',
        localOnly: true,
        sent: false
      };
      const jsonl = socialHubDraftA2ui('surface_social_hub', draft);
      const store = applyJsonl(jsonl);
      const parsedDraft = resolveData(store.getSurface(), '/socialHub/draft') as SocialHubDraftData;

      expect(parsedDraft.text).assertEqual('Thanks for sharing.');
      expect(parsedDraft.localOnly).assertTrue();
      expect(parsedDraft.sent).assertFalse();
    });
  });
}
