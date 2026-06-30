import {
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiSummaryData
} from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { MailProviderStatus, MailThreadResult } from './MailToolTypes';

const GENERIC_RESULTS_PATH: string = '/genericToolResults';
const SUMMARY_PATH: string = '/summary';

interface MailReplyDraftActionArgs {
  provider: string;
  accountLabel: string;
  threadId: string;
  messageId: string;
  to: string[];
  subject: string;
  replyMode: string;
  contextSummary: string;
}

function jsonLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelope) + '\n';
}

function createSurfaceLine(surfaceId: string, title: string, status: string): string {
  return jsonLine({
    version: A2UI_VERSION,
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: title,
      intent: 'mail',
      status: status
    }
  });
}

function rootComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'mail_results',
    title: title,
    status: status
  };
}

function resultsComponent(title: string, status: string): A2uiComponent {
  return {
    id: 'mail_results',
    component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
    title: title,
    dataPath: GENERIC_RESULTS_PATH,
    status: status
  };
}

function componentsLine(surfaceId: string, title: string, status: string): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateComponents: {
      surfaceId: surfaceId,
      components: [rootComponent(title, status), resultsComponent(title, status)]
    }
  });
}

function dataLine(surfaceId: string, path: string, value: A2uiGenericToolResultData[] | A2uiSummaryData): string {
  return jsonLine({
    version: A2UI_VERSION,
    updateDataModel: {
      surfaceId: surfaceId,
      path: path,
      value: value
    }
  });
}

function providerLabel(provider: string): string {
  if (provider === 'qq') {
    return 'QQ Mail';
  }
  if (provider === 'gmail') {
    return 'Gmail';
  }
  return provider.length > 0 ? provider : 'Mail';
}

function dateMs(value: string): number {
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function rowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function emailFromHeader(value: string): string {
  const trimmed = value.trim();
  const left = trimmed.indexOf('<');
  const right = trimmed.indexOf('>');
  if (left >= 0 && right > left) {
    return trimmed.substring(left + 1, right).trim();
  }
  return trimmed;
}

function threadResult(thread: MailThreadResult): A2uiGenericToolResultData {
  return {
    sourceTag: providerLabel(thread.provider),
    toolName: 'mail.thread',
    title: thread.subject.length > 0 ? thread.subject : '(no subject)',
    status: 'success',
    summary: thread.snippet,
    rows: [
      { label: 'Provider', value: thread.provider },
      { label: 'Source', value: providerLabel(thread.provider) },
      { label: 'Account', value: thread.accountLabel },
      { label: 'Thread ID', value: thread.threadId },
      { label: 'Message ID', value: thread.messageId },
      { label: 'From', value: thread.from },
      { label: 'To', value: thread.to.join(', ') },
      { label: 'Received', value: thread.receivedAt },
      { label: 'Important', value: thread.important ? 'Yes' : 'No' },
      { label: 'Unread', value: thread.unread ? 'Yes' : 'No' }
    ],
    rawPreview: JSON.stringify({
      provider: thread.provider,
      threadId: thread.threadId,
      messageId: thread.messageId,
      source: providerLabel(thread.provider)
    })
  };
}

function statusResult(status: MailProviderStatus): A2uiGenericToolResultData {
  return {
    sourceTag: providerLabel(status.provider),
    toolName: 'mail.provider.status',
    title: status.title,
    status: status.status,
    summary: status.message,
    rows: [
      { label: 'Provider', value: status.provider },
      { label: 'Source', value: providerLabel(status.provider) },
      { label: 'Status', value: status.status }
    ],
    rawPreview: status.message
  };
}

export function mailResultsA2ui(surfaceId: string, toolId: string, threads: MailThreadResult[], statuses: MailProviderStatus[]): string {
  const sorted = threads.slice().sort((left: MailThreadResult, right: MailThreadResult) => dateMs(right.receivedAt) - dateMs(left.receivedAt));
  const results: A2uiGenericToolResultData[] = [];
  statuses.forEach((status: MailProviderStatus) => results.push(statusResult(status)));
  sorted.forEach((thread: MailThreadResult) => results.push(threadResult(thread)));
  const count = results.length;
  const title = '邮箱';
  const summary: A2uiSummaryData = {
    text: count.toString() + (count === 1 ? ' mail result returned for review.' : ' mail results returned for review.'),
    toolName: toolId,
    dataLabel: GENERIC_RESULTS_PATH,
    count: count
  };
  return createSurfaceLine(surfaceId, title, 'ready') +
    componentsLine(surfaceId, title, 'ready') +
    dataLine(surfaceId, GENERIC_RESULTS_PATH, results) +
    dataLine(surfaceId, SUMMARY_PATH, summary);
}

export function mailResultsFromDynamicA2ui(
  surfaceId: string,
  toolId: string,
  results: DynamicGenericToolResult[],
  title: string = '邮箱'
): string {
  const mapped: A2uiGenericToolResultData[] = [];
  results.forEach((result: DynamicGenericToolResult) => {
    mapped.push({
      sourceTag: result.sourceTag,
      toolName: result.toolName,
      title: result.title,
      status: result.status,
      summary: result.summary,
      rows: result.rows,
      rawPreview: ''
    });
  });
  const summary: A2uiSummaryData = {
    text: mapped.length.toString() + ' mail results returned for review.',
    toolName: toolId,
    dataLabel: GENERIC_RESULTS_PATH,
    count: mapped.length
  };
  return createSurfaceLine(surfaceId, title, 'ready') +
    componentsLine(surfaceId, title, 'ready') +
    dataLine(surfaceId, GENERIC_RESULTS_PATH, mapped) +
    dataLine(surfaceId, SUMMARY_PATH, summary);
}

export function mailDraftPreviewA2ui(surfaceId: string, result: DynamicGenericToolResult): string {
  return mailResultsFromDynamicA2ui(surfaceId, 'mail.draft.create', [result], 'Mail Draft Preview');
}

export function mailReplyDraftAction(result: A2uiGenericToolResultData): A2uiAction | null {
  if (result.status !== 'success' || result.toolName !== 'mail.thread') {
    return null;
  }
  const provider = rowValue(result, 'Provider');
  const messageId = rowValue(result, 'Message ID');
  const threadId = rowValue(result, 'Thread ID');
  const from = rowValue(result, 'From');
  if (provider.length === 0 || messageId.length === 0 || from.length === 0) {
    return null;
  }
  const email = emailFromHeader(from);
  if (email.length === 0) {
    return null;
  }
  const subject = result.title.indexOf('Re:') === 0 ? result.title : 'Re: ' + result.title;
  const args: MailReplyDraftActionArgs = {
    provider: provider,
    accountLabel: rowValue(result, 'Account'),
    threadId: threadId,
    messageId: messageId,
    to: [email],
    subject: subject,
    replyMode: 'reply',
    contextSummary: result.summary
  };
  return {
    id: 'mail.ai.reply.draft',
    label: 'AI 回复草稿',
    prompt: 'Action ID: mail.ai.reply.draft。请基于真实邮件生成一封简短、礼貌、可审核的回复草稿。只选择 mail.draft.create，不要发送，不要编造事实。/toolRequest.args 必须保留 provider、messageId、threadId、to、subject、replyMode，并由你撰写 args.body。Structured action args JSON: ' + JSON.stringify(args),
    variant: 'primary',
    kind: 'prompt',
    args: args
  };
}
