import { describe, it, expect } from '@ohos/hypium';
import {
  buildQqDraftMime,
  decodeMimeWords,
  ImapTransport,
  parseImapEnvelopeList,
  pickDraftMailbox,
  QqMailImapClient
} from '../main/ets/model/QqMailImapClient';

class FakeSearchTransport implements ImapTransport {
  events: string[] = [];

  async connect(host: string, port: number): Promise<void> {
    this.events.push('connect:' + host + ':' + port.toString());
  }

  async send(line: string): Promise<void> {
    this.events.push('send:' + line);
  }

  async readUntil(tag: string): Promise<string[]> {
    this.events.push('read:' + tag);
    if (tag === '*') {
      return ['* OK QQMail XMIMAP4Server ready'];
    }
    if (tag === 'a1') {
      return ['a1 OK LOGIN completed'];
    }
    if (tag === 'a2') {
      return ['a2 OK SELECT completed'];
    }
    if (tag === 'a3') {
      return ['* SEARCH 7', 'a3 OK SEARCH completed'];
    }
    if (tag === 'a4') {
      return [
        '* 7 FETCH (UID 777 ENVELOPE ("Tue, 30 Jun 2026 09:00:00 +0800" "loopy QQ Subject" (("Alice" NIL "alice" "example.com")) NIL NIL NIL NIL NIL NIL "<msg-777@example.com>") FLAGS (\\\\Seen))',
        'a4 OK FETCH completed'
      ];
    }
    return [tag + ' OK'];
  }

  async close(): Promise<void> {
    this.events.push('close');
  }
}

export default function qqMailImapClientTest() {
  describe('qqMailImapClient', () => {
    it('decodes simple MIME encoded words', 0, () => {
      expect(decodeMimeWords('=?UTF-8?B?5rWL6K+V?=')).assertEqual('测试');
      expect(decodeMimeWords('=?utf-8?B?5rWL6K+V?=')).assertEqual('测试');
      expect(decodeMimeWords('Project Update')).assertEqual('Project Update');
    });

    it('picks a drafts mailbox from common QQ folder names', 0, () => {
      expect(pickDraftMailbox(['INBOX', 'Sent Messages', 'Drafts'], '')).assertEqual('Drafts');
      expect(pickDraftMailbox(['INBOX', '&g0l6P3ux-'], '')).assertEqual('&g0l6P3ux-');
      expect(pickDraftMailbox(['INBOX'], 'MyDrafts')).assertEqual('MyDrafts');
    });

    it('parses minimal IMAP envelope responses into mail threads', 0, () => {
      const parsed = parseImapEnvelopeList([
        '* 7 FETCH (UID 777 ENVELOPE ("Tue, 30 Jun 2026 09:00:00 +0800" "QQ Subject" (("Alice" NIL "alice" "example.com")) NIL NIL (("Me" NIL "me" "qq.com")) NIL NIL NIL "<msg-777@example.com>") FLAGS (\\\\Seen))'
      ], 'q***@qq.com');

      expect(parsed.length).assertEqual(1);
      expect(parsed[0].provider).assertEqual('qq');
      expect(parsed[0].messageId).assertEqual('777');
      expect(parsed[0].subject).assertEqual('QQ Subject');
      expect(parsed[0].from).assertEqual('Alice <alice@example.com>');
      expect(parsed[0].receivedAt).assertEqual('2026-06-30T09:00:00.000+08:00');
    });

    it('waits for the IMAP greeting before sending QQ login', 0, async () => {
      const fake = new FakeSearchTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      const rows = await client.search({
        query: '',
        pageSize: 1,
        providers: ['qq'],
        intentSummary: ''
      });

      expect(fake.events[0]).assertEqual('connect:imap.qq.com:993');
      expect(fake.events[1]).assertEqual('read:*');
      expect(fake.events[2].indexOf('send:a1 LOGIN')).assertEqual(0);
      expect(fake.events[fake.events.length - 1]).assertEqual('close');
      expect(rows.length).assertEqual(1);
      expect(rows[0].provider).assertEqual('qq');
    });

    it('uses newer_than and keyword as a scoped IMAP search instead of scanning all mail', 0, async () => {
      const fake = new FakeSearchTransport();
      const client = new QqMailImapClient({
        address: 'me@qq.com',
        authCode: 'auth-code',
        imapHost: 'imap.qq.com',
        imapPort: 993,
        draftsMailbox: ''
      }, () => fake);

      await client.search({
        query: 'newer_than:30d loopy',
        pageSize: 1,
        providers: ['qq'],
        intentSummary: ''
      });

      const search = fake.events.filter((event: string) => event.indexOf('send:a3 UID SEARCH') === 0)[0];
      expect(search.indexOf('send:a3 UID SEARCH SINCE ')).assertEqual(0);
      expect(search.indexOf('TEXT "loopy"')).assertLarger(-1);
      expect(search.indexOf('ALL')).assertEqual(-1);
    });

    it('builds a reply draft MIME message without claiming send', 0, () => {
      const mime = buildQqDraftMime({
        provider: 'qq',
        accountLabel: 'q***@qq.com',
        threadId: '',
        messageId: '<msg-777@example.com>',
        to: ['alice@example.com'],
        subject: 'Re: QQ Subject',
        body: 'Thanks for the update.',
        replyMode: 'reply',
        contextSummary: 'Alice asked for a quick confirmation.'
      }, 'me@qq.com');

      expect(mime.indexOf('To: alice@example.com')).assertLarger(-1);
      expect(mime.indexOf('Subject: Re: QQ Subject')).assertLarger(-1);
      expect(mime.indexOf('In-Reply-To: <msg-777@example.com>')).assertLarger(-1);
      expect(mime.indexOf('Thanks for the update.')).assertLarger(-1);
    });
  });
}
