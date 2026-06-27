import { describe, it, expect } from '@ohos/hypium';
import { parseA2uiJsonl } from '../main/ets/model/A2uiParser';
import { A2uiSurfaceStore } from '../main/ets/model/A2uiSurfaceStore';
import { A2uiGenericToolResultData } from '../main/ets/model/A2uiTypes';
import { componentById, dynamicToolConnect, genericToolResults } from '../main/ets/model/A2uiData';
import {
  gmailAuthRequiredA2ui,
  gmailBlockedSendA2ui,
  gmailDraftPreviewA2ui,
  gmailOpenDraftAction,
  gmailOpenWebA2ui,
  gmailReplyDraftAction,
  gmailThreadResultsA2ui
} from '../main/ets/model/GmailToolA2ui';
import { DynamicGenericToolResult } from '../main/ets/model/DynamicToolTypes';

function surfaceFromJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();

  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    store.apply(envelope);
  });
  return store;
}

function genericResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail Preview',
    toolName: 'gmail.mail.search',
    title: 'Project launch notes',
    status: 'success',
    summary: 'From a***@example.com: Alice shared a snippet.',
    rows: [{ label: 'From', value: 'a***@example.com' }],
    rawPreview: '{"id":"thread_fixture_1","body":"FULL BODY SHOULD NOT LEAK"}'
  };
}

function draftResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail Draft · Local preview',
    toolName: 'gmail.draft.create',
    title: 'Re: Project launch notes',
    status: 'draft',
    summary: 'Draft prepared for review. It has not been sent.',
    rows: [{ label: 'Status', value: 'ready_to_apply' }],
    rawPreview: '{"status":"ready_to_apply"}'
  };
}

function gmailApiThreadResult(): A2uiGenericToolResultData {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: 'Project launch notes',
    status: 'success',
    summary: 'Alice asked for a quick confirmation before Friday.',
    rows: [
      { label: 'Thread ID', value: 'thread-123' },
      { label: 'From', value: 'Alice Example <alice@example.com>' },
      { label: 'Date', value: 'Fri, 26 Jun 2026 09:30:00 +0800' }
    ],
    rawPreview: '{"id":"thread-123"}'
  };
}

function gmailApiDraftResult(): A2uiGenericToolResultData {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.drafts.create',
    title: 'Re: Project launch notes',
    status: 'success',
    summary: 'Draft created for review.',
    rows: [
      { label: 'Thread ID', value: 'thread-123' },
      { label: 'From', value: 'Alice Example <alice@example.com>' }
    ],
    rawPreview: '{"id":"draft-123"}'
  };
}

function rowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  expect(false).assertTrue();
  return '';
}

export default function gmailToolA2uiTest() {
  describe('gmailToolA2ui', () => {
    it('renders Gmail auth as a connect card instead of fake mailbox data', 0, () => {
      const store = surfaceFromJsonl(gmailAuthRequiredA2ui(
        'gmail_auth',
        'gmail.mail.search',
        '需要登录 Gmail 后才能读取收件箱。'
      ));
      const surface = store.getSurface();
      const connect = componentById(surface, 'gmail_connect');
      const auth = dynamicToolConnect(surface);

      expect(surface.intent).assertEqual('gmail');
      expect(surface.status).assertEqual('needs_input');
      expect(connect !== null).assertTrue();
      if (connect !== null) {
        expect(connect.component).assertEqual('ToolConnectCard');
        expect(connect.dataPath).assertEqual('/dynamicToolConnect');
      }
      expect(auth.toolId).assertEqual('gmail.mail.search');
      expect(auth.manifestId).assertEqual('google.gmail');
      expect(auth.displayName).assertEqual('Gmail');
      expect(auth.sourceUrl).assertEqual('https://gmailmcp.googleapis.com/mcp/v1');
      expect(auth.credentialName).assertEqual('Google Workspace MCP OAuth');
      expect(auth.credentialRef).assertEqual('');
      expect(auth.actions[0].id).assertEqual('gmail.authorize');
      expect(auth.actions[0].label).assertEqual('授权 Gmail');
      expect(auth.actions[0].kind).assertEqual('client');
      expect(auth.actions[0].prompt).assertEqual('https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server');
      expect(auth.actions[1].id).assertEqual('gmail.open.web');
      expect(auth.actions[1].kind).assertEqual('client');
      expect(auth.actions[1].variant).assertEqual('secondary');
      expect(auth.actions[1].prompt).assertEqual('https://mail.google.com/mail/u/0/#inbox');
    });

    it('renders Gmail rows through GenericToolResults without leaking bodies', 0, () => {
      const store = surfaceFromJsonl(gmailThreadResultsA2ui('gmail_results', 'gmail.mail.search', [genericResult()]));
      const surface = store.getSurface();
      const component = componentById(surface, 'gmail_results');
      const rendered = genericToolResults(surface);

      expect(component !== null).assertTrue();
      if (component !== null) {
        expect(component.component).assertEqual('GenericToolResults');
        expect(component.dataPath).assertEqual('/genericToolResults');
      }
      expect(rendered.length).assertEqual(1);
      expect(rendered[0].title).assertEqual('Project launch notes');
      expect(rendered[0].rawPreview.indexOf('FULL BODY SHOULD NOT LEAK')).assertEqual(-1);
      expect(store.getSurface().dataModelJson.indexOf('FULL BODY SHOULD NOT LEAK')).assertEqual(-1);
    });

    it('renders drafts and blocked send without claiming send success', 0, () => {
      const draftStore = surfaceFromJsonl(gmailDraftPreviewA2ui('gmail_draft', draftResult()));
      const draft = genericToolResults(draftStore.getSurface())[0];
      expect(draft.status).assertEqual('draft');
      expect(draft.summary.indexOf('has not been sent')).assertLarger(-1);
      expect(rowValue(draft, 'Status')).assertEqual('ready_to_apply');

      const blockedStore = surfaceFromJsonl(gmailBlockedSendA2ui('gmail_blocked', 'gmail.message.send'));
      const blocked = genericToolResults(blockedStore.getSurface())[0];
      expect(blocked.title).assertEqual('UnsafeActionBlocked');
      expect(blocked.status).assertEqual('blocked');
      expect(blocked.summary.indexOf('不会自动发送 Gmail')).assertLarger(-1);
    });

    it('renders Gmail Web as a needs-user system intent row', 0, () => {
      const url = 'https://mail.google.com/mail/u/0/#inbox/thread_fixture_1';
      const store = surfaceFromJsonl(gmailOpenWebA2ui('gmail_web', url));
      const component = componentById(store.getSurface(), 'gmail_results');
      const rendered = genericToolResults(store.getSurface())[0];

      expect(component !== null).assertTrue();
      if (component !== null) {
        expect(component.actions !== undefined).assertTrue();
        if (component.actions !== undefined) {
          expect(component.actions.length).assertEqual(1);
          expect(component.actions[0].id).assertEqual('gmail.open.web');
          expect(component.actions[0].kind).assertEqual('client');
          expect(component.actions[0].prompt).assertEqual(url);
        }
      }
      expect(rendered.sourceTag).assertEqual('System intent');
      expect(rendered.toolName).assertEqual('gmail.open.web');
      expect(rendered.status).assertEqual('needs_user');
      expect(rowValue(rendered, 'URL')).assertEqual(url);
    });

    it('builds a per-thread AI reply draft action from real Gmail rows', 0, () => {
      const action = gmailReplyDraftAction(gmailApiThreadResult());

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('gmail.ai.reply.draft');
        expect(action.label).assertEqual('AI 回复草稿');
        expect(action.kind).assertEqual('prompt');
        expect(action.variant).assertEqual('primary');
        expect(action.prompt.indexOf('thread-123')).assertLarger(-1);
        expect(action.prompt.indexOf('alice@example.com')).assertLarger(-1);
        expect(action.prompt.indexOf('Alice asked for a quick confirmation before Friday.')).assertLarger(-1);
        expect(action.prompt.indexOf('gmail.draft.create')).assertLarger(-1);
        expect(action.prompt.indexOf('gmail.ai.reply.draft')).assertLarger(-1);
        expect(action.prompt.indexOf('args.body')).assertLarger(-1);
        expect(action.args === undefined).assertFalse();
        expect(JSON.stringify(action.args).indexOf('thread-123')).assertLarger(-1);
        expect(JSON.stringify(action.args).indexOf('alice@example.com')).assertLarger(-1);
        expect(JSON.stringify(action.args).indexOf('"replyMode":"reply"')).assertLarger(-1);
      }
      expect(gmailReplyDraftAction(gmailApiDraftResult()) === null).assertTrue();
    });

    it('adds Gmail jump action for MCP draft results too', 0, () => {
      const mcpDraft: A2uiGenericToolResultData = {
        sourceTag: 'Gmail',
        toolName: 'create_draft',
        title: 'MCP draft',
        status: 'success',
        summary: 'Draft created.',
        rows: [{ label: 'Draft ID', value: 'draft-123' }],
        rawPreview: ''
      };
      const action = gmailOpenDraftAction(mcpDraft);

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('gmail.open.web');
        expect(action.label).assertEqual('跳转到Gmail');
      }
    });
  });
}
