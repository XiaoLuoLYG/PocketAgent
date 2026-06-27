import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import {
  GmailCreateDraftArgs,
  GmailGetThreadArgs,
  GmailSearchThreadsArgs,
  gmailMcpArgsForPrompt
} from './GmailOAuthClient';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const GMAIL_API_BASE_URL: string = 'https://gmail.googleapis.com/gmail/v1/users/me';

interface GoogleApiError {
  code?: number;
  message?: string;
  status?: string;
}

interface GoogleApiErrorPayload {
  error?: GoogleApiError;
}

interface GmailThreadListItem {
  id?: string;
  snippet?: string;
}

interface GmailThreadsListResponse {
  threads?: GmailThreadListItem[];
  nextPageToken?: string;
  resultSizeEstimate?: number;
}

interface GmailHeader {
  name?: string;
  value?: string;
}

interface GmailMessagePayload {
  headers?: GmailHeader[];
}

interface GmailMessage {
  id?: string;
  threadId?: string;
  labelIds?: string[];
  snippet?: string;
  internalDate?: string;
  payload?: GmailMessagePayload;
}

interface GmailThread {
  id?: string;
  historyId?: string;
  messages?: GmailMessage[];
}

interface GmailDraftResponse {
  id?: string;
  message?: GmailMessage;
}

interface GmailDraftCreateMessage {
  raw: string;
  threadId?: string;
}

interface GmailDraftCreateRequest {
  message: GmailDraftCreateMessage;
}

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

function decodeGmailText(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'");
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

function encodeParam(value: string): string {
  return encodeURIComponent(value);
}

function urlWithParams(baseUrl: string, params: string[][]): string {
  const pairs: string[] = [];
  params.forEach((pair: string[]) => {
    if (pair.length < 2 || pair[1].length === 0) {
      return;
    }
    pairs.push(encodeParam(pair[0]) + '=' + encodeParam(pair[1]));
  });
  return pairs.length === 0 ? baseUrl : baseUrl + '?' + pairs.join('&');
}

function bearerHeaders(accessToken: string): Record<string, string> {
  return {
    'Authorization': 'Bearer ' + accessToken,
    'Accept': 'application/json'
  };
}

function requestMethodName(method: http.RequestMethod): string {
  if (method === http.RequestMethod.POST) {
    return 'POST';
  }
  if (method === http.RequestMethod.GET) {
    return 'GET';
  }
  return method.toString();
}

function gmailApiPath(url: string): string {
  let path = url;
  if (path.startsWith(GMAIL_API_BASE_URL)) {
    path = path.substring(GMAIL_API_BASE_URL.length);
  }
  const queryIndex = path.indexOf('?');
  return queryIndex >= 0 ? path.substring(0, queryIndex) : path;
}

function describeRequestError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  if (typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  const json = JSON.stringify(error);
  return json.length > 0 && json !== '{}' ? json : String(error);
}

async function requestJson(
  method: http.RequestMethod,
  url: string,
  accessToken: string,
  body: Object | null
): Promise<Object> {
  const request = http.createHttp();
  const methodName = requestMethodName(method);
  const path = gmailApiPath(url);
  try {
    const headers = bearerHeaders(accessToken);
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    aiLogInfo('[AIPhone][GmailApiHttpStart] method=' + methodName +
      ' path=' + path +
      ' bodyChars=' + (body === null ? '0' : JSON.stringify(body).length.toString()));
    const response = await request.request(url, options);
    const text = responseText(response.result);
    aiLogInfo('[AIPhone][GmailApiHttpEnd] method=' + methodName +
      ' path=' + path +
      ' code=' + response.responseCode.toString() +
      ' chars=' + text.length.toString());
    const payload = text.length > 0 ? JSON.parse(text) as Object : new Object();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const errorPayload = payload as GoogleApiErrorPayload;
      const message = errorPayload.error === undefined ? '' : textOf(errorPayload.error.message);
      const status = errorPayload.error === undefined ? '' : textOf(errorPayload.error.status);
      throw new Error(message.length > 0 ? message : (status.length > 0 ? status : 'HTTP ' + response.responseCode.toString()));
    }
    return payload;
  } catch (error) {
    const message = describeRequestError(error);
    aiLogError('[AIPhone][GmailApiHttpError] method=' + methodName +
      ' path=' + path +
      ' error=' + message.substring(0, 220));
    throw new Error(message);
  } finally {
    request.destroy();
  }
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

function firstHeader(message: GmailMessage, headerName: string): string {
  if (message.payload === undefined || !Array.isArray(message.payload.headers)) {
    return '';
  }
  const target = headerName.toLowerCase();
  for (let index = 0; index < message.payload.headers.length; index++) {
    const header = message.payload.headers[index];
    if (textOf(header.name).toLowerCase() === target) {
      return textOf(header.value);
    }
  }
  return '';
}

function lastMessage(thread: GmailThread): GmailMessage {
  if (Array.isArray(thread.messages) && thread.messages.length > 0) {
    return thread.messages[thread.messages.length - 1];
  }
  return {};
}

function firstMessage(thread: GmailThread): GmailMessage {
  if (Array.isArray(thread.messages) && thread.messages.length > 0) {
    return thread.messages[0];
  }
  return {};
}

function labelsText(message: GmailMessage): string {
  if (!Array.isArray(message.labelIds) || message.labelIds.length === 0) {
    return '';
  }
  return message.labelIds.join(', ');
}

function messageCount(thread: GmailThread): number {
  return Array.isArray(thread.messages) ? thread.messages.length : 0;
}

function threadResult(thread: GmailThread): DynamicGenericToolResult {
  const newest = lastMessage(thread);
  const first = firstMessage(thread);
  const subject = firstHeader(first, 'Subject').length > 0 ? decodeGmailText(firstHeader(first, 'Subject')) : '(no subject)';
  const from = decodeGmailText(firstHeader(newest, 'From'));
  const date = decodeGmailText(firstHeader(newest, 'Date'));
  const snippet = decodeGmailText(textOf(newest.snippet).length > 0 ? textOf(newest.snippet) : textOf(first.snippet));
  const rows: A2uiLabelValueData[] = [
    { label: 'From', value: from.length > 0 ? from : 'Unknown sender' },
    { label: 'Date', value: date.length > 0 ? date : textOf(newest.internalDate) },
    { label: 'Messages', value: messageCount(thread).toString() },
    { label: 'Thread ID', value: textOf(thread.id) }
  ];
  const labels = labelsText(newest);
  if (labels.length > 0) {
    rows.push({ label: 'Labels', value: labels });
  }
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: subject.substring(0, 120),
    status: 'success',
    summary: snippet.length > 0 ? snippet.substring(0, 240) : 'Gmail thread retrieved.',
    rows: rows,
    rawPreview: 'threadId=' + textOf(thread.id) + ' subject=' + subject.substring(0, 160)
  };
}

function noResultsResult(query: string, estimate: number): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.list',
    title: '没有找到匹配邮件',
    status: 'success',
    summary: 'Gmail API 查询成功，但当前账号没有匹配这条搜索条件的邮件。',
    rows: [
      { label: 'Query', value: query },
      { label: 'Result size', value: estimate.toString() }
    ],
    rawPreview: 'query=' + query + ' resultSize=' + estimate.toString()
  };
}

function searchSummaryResult(query: string, returned: number, estimate: number): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.list',
    title: 'Gmail 搜索条件',
    status: 'success',
    summary: '已使用真实 Gmail API 搜索邮件线程；下面展示匹配结果。',
    rows: [
      { label: 'Query', value: query },
      { label: 'Returned threads', value: returned.toString() },
      { label: 'Result size', value: estimate.toString() }
    ],
    rawPreview: 'query=' + query + ' returned=' + returned.toString() + ' resultSize=' + estimate.toString()
  };
}

function errorResult(toolName: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: toolName,
    title: 'Gmail API 调用失败',
    status: 'error',
    summary: message.substring(0, 240),
    rows: [
      { label: 'Tool', value: toolName },
      { label: 'Error', value: message.substring(0, 160) }
    ],
    rawPreview: 'error=' + message.substring(0, 320)
  };
}

async function getThread(accessToken: string, threadId: string): Promise<GmailThread> {
  const url = urlWithParams(GMAIL_API_BASE_URL + '/threads/' + encodeParam(threadId), [
    ['format', 'metadata'],
    ['metadataHeaders', 'Subject'],
    ['metadataHeaders', 'From'],
    ['metadataHeaders', 'Date']
  ]);
  return await requestJson(http.RequestMethod.GET, url, accessToken, null) as GmailThread;
}

async function searchThreads(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.mail.search', prompt, args) as GmailSearchThreadsArgs;
  const pageSize = gmailArgs.pageSize > 0 ? Math.min(gmailArgs.pageSize, 10) : 10;
  const url = urlWithParams(GMAIL_API_BASE_URL + '/threads', [
    ['q', gmailArgs.query],
    ['maxResults', pageSize.toString()],
    ['includeSpamTrash', 'false']
  ]);
  const listed = await requestJson(http.RequestMethod.GET, url, accessToken, null) as GmailThreadsListResponse;
  const items = Array.isArray(listed.threads) ? listed.threads : [];
  if (items.length === 0) {
    return [noResultsResult(gmailArgs.query, listed.resultSizeEstimate === undefined ? 0 : listed.resultSizeEstimate)];
  }
  const tasks: Promise<GmailThread>[] = [];
  for (let index = 0; index < items.length && index < pageSize; index++) {
    const threadId = textOf(items[index].id);
    if (threadId.length === 0) {
      continue;
    }
    tasks.push(getThread(accessToken, threadId));
  }
  const results: DynamicGenericToolResult[] = [];
  const threads = await Promise.all(tasks);
  for (let index = 0; index < threads.length; index++) {
    results.push(threadResult(threads[index]));
  }
  const estimate = listed.resultSizeEstimate === undefined ? results.length : listed.resultSizeEstimate;
  return results.length > 0 ? [searchSummaryResult(gmailArgs.query, results.length, estimate)].concat(results) :
    [noResultsResult(gmailArgs.query, estimate)];
}

async function readThread(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.thread.read', prompt, args) as GmailGetThreadArgs;
  const threadId = gmailArgs.threadId.trim();
  if (threadId.length === 0) {
    return [errorResult('users.threads.get', 'Missing Gmail thread ID.')];
  }
  return [threadResult(await getThread(accessToken, threadId))];
}

function rfc2822Message(args: GmailCreateDraftArgs): string {
  const to = args.to.join(', ');
  const headers: string[] = [
    'To: ' + to,
    'Subject: ' + args.subject
  ];
  if (args.inReplyTo.trim().length > 0) {
    headers.push('In-Reply-To: ' + args.inReplyTo.trim());
  }
  if (args.references.trim().length > 0) {
    headers.push('References: ' + args.references.trim());
  }
  headers.push('MIME-Version: 1.0');
  headers.push('Content-Type: text/plain; charset=UTF-8');
  return headers.join('\r\n') +
    '\r\n\r\n' +
    args.body + '\r\n';
}

async function createDraft(accessToken: string, prompt: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  const gmailArgs = gmailMcpArgsForPrompt('gmail.draft.create', prompt, args) as GmailCreateDraftArgs;
  if (gmailArgs.to.length === 0) {
    return [errorResult('users.drafts.create', 'Missing recipient email address.')];
  }
  if (gmailArgs.body.trim().length === 0) {
    return [errorResult('users.drafts.create', 'Missing email body.')];
  }
  const threadId = gmailArgs.threadId.trim();
  const raw = bytesToBase64Url(utf8Bytes(rfc2822Message(gmailArgs)));
  const draftBody: GmailDraftCreateRequest = {
    message: {
      raw: raw
    }
  };
  if (threadId.length > 0) {
    draftBody.message.threadId = threadId;
  }
  const created = await requestJson(http.RequestMethod.POST, GMAIL_API_BASE_URL + '/drafts', accessToken, draftBody) as GmailDraftResponse;
  const draftId = textOf(created.id);
  const messageId = created.message === undefined ? '' : textOf(created.message.id);
  const resultThreadId = threadId.length > 0 ? threadId : (created.message === undefined ? '' : textOf(created.message.threadId));
  const rows: A2uiLabelValueData[] = [
    { label: 'To', value: gmailArgs.to.join(', ') },
    { label: 'Subject', value: gmailArgs.subject },
    { label: 'Draft ID', value: draftId },
    { label: 'Message ID', value: messageId }
  ];
  if (resultThreadId.length > 0) {
    rows.push({ label: 'Thread ID', value: resultThreadId });
  }
  return [{
    sourceTag: 'Gmail API',
    toolName: 'users.drafts.create',
    title: 'Gmail 草稿已创建',
    status: 'success',
    summary: '已在真实 Gmail 账号中创建草稿；尚未发送。',
    rows: rows,
    rawPreview: 'draftId=' + draftId + ' messageId=' + messageId + (resultThreadId.length > 0 ? ' threadId=' + resultThreadId : '')
  }];
}

export async function callGmailApiTool(toolId: string, prompt: string, accessToken: string, args: Object | null = null): Promise<DynamicGenericToolResult[]> {
  try {
    if (toolId === 'gmail.mail.search') {
      return await searchThreads(accessToken, prompt, args);
    }
    if (toolId === 'gmail.thread.read') {
      return await readThread(accessToken, prompt, args);
    }
    if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
      return await createDraft(accessToken, prompt, args);
    }
    return [errorResult(toolId, 'Unsupported Gmail API tool.')];
  } catch (error) {
    return [errorResult(toolId, error instanceof Error ? error.message : JSON.stringify(error))];
  }
}
