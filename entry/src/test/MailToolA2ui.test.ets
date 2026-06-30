import { describe, it, expect } from '@ohos/hypium';
import { genericToolResults } from '../main/ets/model/A2uiData';
import { parseA2uiJsonl } from '../main/ets/model/A2uiParser';
import { A2uiSurfaceStore } from '../main/ets/model/A2uiSurfaceStore';
import { mailReplyDraftAction, mailResultsA2ui } from '../main/ets/model/MailToolA2ui';
import { MailProviderStatus, MailThreadResult } from '../main/ets/model/MailToolTypes';

function surfaceFromJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => store.apply(envelope));
  return store;
}

function thread(provider: string, receivedAt: string, subject: string): MailThreadResult {
  return {
    provider: provider,
    accountLabel: provider === 'gmail' ? 'g***@gmail.com' : 'q***@qq.com',
    threadId: provider + '-thread',
    messageId: provider + '-message',
    subject: subject,
    from: 'Alice Example <alice@example.com>',
    to: ['me@example.com'],
    participants: ['alice@example.com', 'me@example.com'],
    snippet: 'Short real snippet',
    receivedAt: receivedAt,
    unread: false,
    important: true,
    sourceUrl: '',
    rawProviderRef: provider + '-ref'
  };
}

export default function mailToolA2uiTest() {
  describe('mailToolA2ui', () => {
    it('renders mixed Gmail and QQ rows sorted by received time', 0, () => {
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('gmail', '2026-06-29T08:00:00+08:00', 'Older Gmail'),
        thread('qq', '2026-06-30T09:00:00+08:00', 'Newer QQ')
      ], []));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[0].sourceTag).assertEqual('QQ Mail');
      expect(rows[0].title).assertEqual('Newer QQ');
      expect(rows[1].sourceTag).assertEqual('Gmail');
      expect(rows[1].title).assertEqual('Older Gmail');
      expect(store.getSurface().dataModelJson.indexOf('Short real snippet')).assertLarger(-1);
      expect(store.getSurface().dataModelJson.indexOf('raw body')).assertEqual(-1);
    });

    it('keeps provider status cards before long mail result lists', 0, () => {
      const status: MailProviderStatus = {
        provider: 'gmail',
        status: 'error',
        title: 'Gmail 调用失败',
        message: 'Gmail API timeout'
      };
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], [status]));
      const rows = genericToolResults(store.getSurface());

      expect(rows.length).assertEqual(2);
      expect(rows[0].sourceTag).assertEqual('Gmail');
      expect(rows[0].toolName).assertEqual('mail.provider.status');
      expect(rows[1].sourceTag).assertEqual('QQ Mail');
      expect(rows[1].toolName).assertEqual('mail.thread');
    });

    it('builds provider-aware reply draft actions', 0, () => {
      const store = surfaceFromJsonl(mailResultsA2ui('mail_surface', 'mail.search', [
        thread('qq', '2026-06-30T09:00:00+08:00', 'QQ thread')
      ], []));
      const action = mailReplyDraftAction(genericToolResults(store.getSurface())[0]);

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('mail.ai.reply.draft');
        expect(action.label).assertEqual('AI 回复草稿');
        expect(action.prompt.indexOf('mail.draft.create')).assertLarger(-1);
        expect(action.prompt.indexOf('"provider":"qq"')).assertLarger(-1);
        expect(action.prompt.indexOf('"messageId":"qq-message"')).assertLarger(-1);
      }
    });
  });
}
