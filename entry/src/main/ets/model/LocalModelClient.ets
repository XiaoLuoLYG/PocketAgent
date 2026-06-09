import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { LocalModelSettings } from './LocalModelSettings';
import {
  A2uiCallResult,
  A2uiEnvelope,
  A2uiMessage,
  A2uiSurfaceState,
  defaultA2uiCapabilities,
  emptyA2uiSurface
} from './A2uiTypes';
import { parseA2uiJsonl, parseA2uiJsonlChunk } from './A2uiParser';
import { A2uiSurfaceStore } from './A2uiSurfaceStore';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

interface OpenAiRequestBody {
  model: string;
  stream: boolean;
  temperature: number;
  messages: OpenAiMessage[];
}

interface OpenAiMessage {
  role: string;
  content: string;
}

interface OpenAiDelta {
  content?: string;
  reasoning_content?: string;
}

interface OpenAiStreamChoice {
  delta?: OpenAiDelta;
  message?: OpenAiChoiceMessage;
}

interface OpenAiStreamResponse {
  choices: OpenAiStreamChoice[];
}

interface OpenAiChoiceMessage {
  role: string;
  content: string;
}

interface OpenAiChoice {
  index: number;
  message: OpenAiChoiceMessage;
}

interface OpenAiResponseBody {
  choices: OpenAiChoice[];
}

interface LocalModelHeaders {
  'Content-Type': string;
  'Accept': string;
  'Authorization'?: string;
}

export type A2uiSurfaceCallback = (surface: A2uiSurfaceState, raw: string) => void;

export interface ModelThinkChunk {
  think: string;
  content: string;
  inThink: boolean;
  tagRemainder: string;
}

const SYSTEM_PROMPT: string =
  '你是 AIPhone 的本地模型。你可以先用 <think>...</think> 输出模型思考流；think 结束后必须输出 A2UI v0.9.1 JSONL，不要 Markdown，不要代码块，不要自然语言前后缀。' +
  'A2UI 正文每一行都是一个 JSON envelope，只能使用 createSurface, updateComponents, updateDataModel, deleteSurface 四种消息。' +
  '第一行必须 createSurface，字段包含 surfaceId, root, title, intent, status, sendDataModel。' +
  '组件使用 flat component map，通过 SurfaceRoot.child 或 Column/Row.children 组成邻接树。' +
  '优先使用 AIPhone catalog 组件：SurfaceRoot, Column, Row, Text, ActionBar, ErrorNotice, ThinkingStream, TrainOptions, FlightBoard, FoodChoices, InfoRows；不要输出 ConfirmPanel。' +
  '组件字段只能使用 id, component, child, children, title, text, body, status, tone, variant, dataPath, actions。' +
  'actions 必须是 [{"id":"稳定英文 id","label":"短按钮文案","prompt":"点击后发送给模型的完整中文指令","variant":"primary|secondary|danger"}]。' +
  '数据必须通过 updateDataModel 写入 JSON Pointer 路径，组件用 dataPath 读取，不要把大量结果直接塞进 body。' +
  '出行/高铁用 TrainOptions，航班用 FlightBoard，餐饮/外卖用 FoodChoices，思考态用 ThinkingStream。' +
  '普通寒暄也必须输出 A2UI：createSurface 后用 Text 或 InfoRows 渲染回复。' +
  '需要实时查询航班、火车票、附近餐饮或外卖时，先生成 ThinkingStream，并通过 updateDataModel 写入 /toolRequest。' +
  '/toolRequest 的值必须是 {"toolId":"train.search|flight.search|food.search","prompt":"原始中文请求","actionId":"model_tool_request"}。' +
  '写入 /toolRequest 后不要编造实时班次、库存、价格、地点或配送状态，等待客户端调用工具。' +
  '订票、下单、支付、抢票不能自动执行；如果用户要求交易，只用简短 Text 或 ErrorNotice 告知需要用户自行确认，不要展示 demo 说明。' +
  '示例，用户说“你好”时输出：' +
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface_model","root":"root","title":"AIPhone","intent":"general","status":"ready","sendDataModel":true}}' + '\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"hello","title":"AIPhone","status":"ready"},{"id":"hello","component":"Text","text":"你好，我在。你可以让我查询高铁、航班或附近餐饮。","status":"ready"}]}}' + '\n' +
  '示例，用户要查高铁时输出：' +
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface_model","root":"root","title":"正在准备查询","intent":"travel","status":"calling_tool","sendDataModel":true}}' + '\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"thinking","title":"正在准备查询","status":"calling_tool"},{"id":"thinking","component":"ThinkingStream","title":"AIPhone 正在处理","body":"正在把请求交给工具","status":"calling_tool","dataPath":"/thoughts","actions":[]}]}}' + '\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","path":"/thoughts","value":["正在识别出行约束","正在准备调用查询工具","正在等待工具返回"]}}' + '\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","path":"/toolRequest","value":{"toolId":"train.search","prompt":"帮我查询明天北京到上海高铁票","actionId":"model_tool_request"}}}' + '\n' +
  '旧 aiphone.ui.v1 或 aiphone.ui.v2 格式不再受支持，绝不能输出。' +
  '客户端能力如下：' + JSON.stringify(defaultA2uiCapabilities()) + '。';

function truncateDebugText(text: string): string {
  const maxLength = 12000;
  if (text.length <= maxLength) {
    return text;
  }
  return text.substring(0, maxLength) + '...<truncated ' + text.length.toString() + ' chars>';
}

function logSnippet(text: string): string {
  const cleaned = text.replace(/\r/g, '\\r').replace(/\n/g, '\\n');
  if (cleaned.length <= 420) {
    return cleaned;
  }
  return cleaned.substring(0, 420) + '...<truncated>';
}

export function buildChatCompletionsUrl(baseUrl: string): string {
  let cleaned = baseUrl.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  if (cleaned.endsWith('/v1/chat/completions')) {
    return cleaned;
  }
  if (cleaned.endsWith('/chat/completions')) {
    return cleaned;
  }
  if (cleaned.endsWith('/v1')) {
    return cleaned + '/chat/completions';
  }
  return cleaned + '/v1/chat/completions';
}

function createHeaders(settings: LocalModelSettings): LocalModelHeaders {
  if (settings.apiKey.trim().length > 0) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/a2ui+json, application/json',
      'Authorization': 'Bearer ' + settings.apiKey.trim()
    };
  }
  return {
    'Content-Type': 'application/json',
    'Accept': 'text/event-stream, application/a2ui+json, application/json'
  };
}

function isLocalBaseUrl(baseUrl: string): boolean {
  const value = baseUrl.toLowerCase();
  return value.indexOf('127.0.0.1') >= 0 || value.indexOf('localhost') >= 0;
}

function toOpenAiMessages(history: A2uiMessage[], prompt: string): OpenAiMessage[] {
  const messages: OpenAiMessage[] = [];
  messages.push({
    role: 'system',
    content: SYSTEM_PROMPT
  });
  history.forEach((message: A2uiMessage) => {
    if (message.role === 'user' || message.role === 'assistant') {
      messages.push({
        role: message.role,
        content: message.content
      });
    }
  });
  messages.push({
    role: 'user',
    content: prompt
  });
  return messages;
}

function extractAssistantContent(responseText: string): string {
  const parsed = JSON.parse(responseText) as OpenAiResponseBody;
  if (parsed.choices.length === 0) {
    return '';
  }
  return parsed.choices[0].message.content;
}

function inferRootComponentId(envelope: A2uiEnvelope): string {
  if (envelope.updateComponents === undefined || envelope.updateComponents === null) {
    return 'root';
  }
  for (let index = 0; index < envelope.updateComponents.components.length; index++) {
    const component = envelope.updateComponents.components[index];
    if (component.component === 'SurfaceRoot') {
      return component.id;
    }
  }
  return 'root';
}

function inferSurfaceTitle(envelope: A2uiEnvelope): string {
  if (envelope.updateComponents === undefined || envelope.updateComponents === null) {
    return 'AIPhone';
  }
  for (let index = 0; index < envelope.updateComponents.components.length; index++) {
    const component = envelope.updateComponents.components[index];
    if (component.component === 'SurfaceRoot' && component.title !== undefined && component.title.length > 0) {
      return component.title;
    }
  }
  return 'AIPhone';
}

function applyImplicitModelSurface(store: A2uiSurfaceStore, envelope: A2uiEnvelope): void {
  if (envelope.updateComponents === undefined || envelope.updateComponents === null) {
    return;
  }
  if (store.getSurface().surfaceId === envelope.updateComponents.surfaceId) {
    return;
  }
  store.apply({
    version: 'v0.9.1',
    createSurface: {
      surfaceId: envelope.updateComponents.surfaceId,
      root: inferRootComponentId(envelope),
      title: inferSurfaceTitle(envelope),
      intent: 'general',
      status: 'ready',
      sendDataModel: true
    }
  });
  aiLogInfo('[AIPhone][ModelImplicitSurface] surfaceId=' + envelope.updateComponents.surfaceId);
}

function applyEnvelopes(store: A2uiSurfaceStore, envelopes: A2uiEnvelope[], allowImplicitModelSurface: boolean = false): string {
  let error = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    if (allowImplicitModelSurface) {
      applyImplicitModelSurface(store, envelope);
    }
    const result = store.apply(envelope);
    if (!result.ok && error.length === 0) {
      error = result.error;
    }
  });
  return error;
}

function startsWithIgnoreCase(text: string, index: number, token: string): boolean {
  if (index + token.length > text.length) {
    return false;
  }
  return text.substring(index, index + token.length).toLowerCase() === token;
}

function isPartialThinkTag(text: string, index: number): boolean {
  const tail = text.substring(index).toLowerCase();
  if (tail.length === 0) {
    return false;
  }
  return '<think>'.startsWith(tail) || '</think>'.startsWith(tail);
}

export function splitModelThinkFromContent(chunk: string, inThink: boolean = false, tagRemainder: string = ''): ModelThinkChunk {
  const text = tagRemainder + chunk;
  let think = '';
  let content = '';
  let stillInThink = inThink;
  let nextTagRemainder = '';
  let index = 0;

  while (index < text.length) {
    if (text.charAt(index) === '<') {
      if (startsWithIgnoreCase(text, index, '<think>')) {
        stillInThink = true;
        index += '<think>'.length;
        continue;
      }
      if (startsWithIgnoreCase(text, index, '</think>')) {
        stillInThink = false;
        index += '</think>'.length;
        continue;
      }
      if (isPartialThinkTag(text, index)) {
        nextTagRemainder = text.substring(index);
        break;
      }
    }

    if (stillInThink) {
      think += text.charAt(index);
    } else {
      content += text.charAt(index);
    }
    index += 1;
  }

  return {
    think,
    content,
    inThink: stillInThink,
    tagRemainder: nextTagRemainder
  };
}

function visibleModelContent(content: string): string {
  return splitModelThinkFromContent(content, false, '').content;
}

function endsWithThinkingBoundary(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return true;
  }
  const last = trimmed.charAt(trimmed.length - 1);
  return last === '。' || last === '！' || last === '？' || last === '!' || last === '?' || last === ';' || last === '；';
}

function splitThinkingSegments(text: string): string[] {
  const normalized = text.replace(/\r/g, '\n');
  const segments: string[] = [];
  let current = '';
  for (let index = 0; index < normalized.length; index++) {
    const char = normalized.charAt(index);
    if (char === '\n') {
      if (current.trim().length > 0) {
        segments.push(current.trim());
      }
      current = '';
      continue;
    }
    current += char;
    if (endsWithThinkingBoundary(current) || current.length >= 82) {
      if (current.trim().length > 0) {
        segments.push(current.trim());
      }
      current = '';
    }
  }
  if (current.trim().length > 0) {
    segments.push(current.trim());
  }
  return segments;
}

function appendThinkingText(existing: string[], text: string): string[] {
  const segments = splitThinkingSegments(text);
  const next = existing.slice();
  segments.forEach((segment: string) => {
    if (segment.length === 0) {
      return;
    }
    if (next.length === 0) {
      next.push(segment);
      return;
    }
    const lastIndex = next.length - 1;
    if (!endsWithThinkingBoundary(next[lastIndex]) && next[lastIndex].length + segment.length <= 96) {
      next[lastIndex] = next[lastIndex] + segment;
    } else {
      next.push(segment);
    }
  });
  if (next.length > 8) {
    return next.slice(next.length - 8);
  }
  return next;
}

function shouldDisplayPlainModelThinking(content: string, extractionRemainder: string, envelopeCount: number): boolean {
  if (envelopeCount > 0 || extractionRemainder.trim().length > 0) {
    return false;
  }
  const trimmed = content.trim();
  if (trimmed.length === 0) {
    return false;
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('```')) {
    return false;
  }
  return true;
}

function showModelThinking(store: A2uiSurfaceStore, rawResponse: string, onSurface: A2uiSurfaceCallback, thoughts: string[]): void {
  if (store.getSurface().sequence === 0) {
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_model_thinking',
        root: 'root',
        title: '模型正在思考',
        intent: 'general',
        status: 'thinking',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_model_thinking',
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'thinking',
            title: '模型正在思考',
            status: 'thinking'
          },
          {
            id: 'thinking',
            component: 'ThinkingStream',
            title: '模型正在思考',
            body: '正在读取模型思考流',
            status: 'thinking',
            dataPath: '/thoughts',
            actions: []
          }
        ]
      }
    });
  }
  store.apply({
    version: 'v0.9.1',
    updateDataModel: {
      surfaceId: 'surface_model_thinking',
      path: '/thoughts',
      value: thoughts.length > 0 ? thoughts : ['等待模型响应']
    }
  });
  onSurface(store.getSurface(), rawResponse);
}

function parseSseContent(chunk: string): string {
  const lines = chunk.split('\n');
  let content = '';
  lines.forEach((line: string) => {
    const trimmed = line.trim();
    if (!trimmed.startsWith('data:')) {
      return;
    }
    const payload = trimmed.substring(5).trim();
    if (payload === '[DONE]' || payload.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(payload) as OpenAiStreamResponse;
      if (parsed.choices.length > 0 && parsed.choices[0].delta !== undefined && parsed.choices[0].delta?.content !== undefined) {
        content += parsed.choices[0].delta?.content;
      } else if (parsed.choices.length > 0 && parsed.choices[0].message !== undefined && parsed.choices[0].message?.content !== undefined) {
        content += parsed.choices[0].message?.content;
      }
    } catch (_error) {
      content += payload;
    }
  });
  return content;
}

export function parseSseReasoningContent(chunk: string): string {
  const lines = chunk.split('\n');
  let content = '';
  lines.forEach((line: string) => {
    const trimmed = line.trim();
    if (!trimmed.startsWith('data:')) {
      return;
    }
    const payload = trimmed.substring(5).trim();
    if (payload === '[DONE]' || payload.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(payload) as OpenAiStreamResponse;
      if (parsed.choices.length > 0 && parsed.choices[0].delta !== undefined && parsed.choices[0].delta?.reasoning_content !== undefined) {
        const reasoning = parsed.choices[0].delta?.reasoning_content as string;
        content += reasoning;
      }
    } catch (_error) {
      return;
    }
  });
  return content;
}

function parseSseReasoningLength(chunk: string): number {
  return parseSseReasoningContent(chunk).length;
}

interface ModelA2uiChunk {
  jsonl: string;
  remainder: string;
}

function isModelNoiseLine(line: string): boolean {
  const trimmed = line.trim();
  if (trimmed.length === 0) {
    return true;
  }
  if (trimmed === '```' || trimmed === '```json' || trimmed === '```jsonl') {
    return true;
  }
  if (trimmed.startsWith('<think') || trimmed.startsWith('</think')) {
    return true;
  }
  return !trimmed.startsWith('{');
}

export function extractA2uiJsonlFromModelChunk(chunk: string, previousRemainder: string = ''): ModelA2uiChunk {
  const text = previousRemainder + chunk;
  let jsonl = '';
  let current = '';
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = 0; index < text.length; index++) {
    const char = text.charAt(index);
    const startsNewEnvelope = text.substring(index, index + 10) === '{"version"';
    if (depth > 0 && startsNewEnvelope && current.trim().length > 0 &&
      (!inString || current.indexOf('\n') >= 0 || current.indexOf('\r') >= 0)) {
      current = '';
      depth = 0;
      inString = false;
      escaped = false;
    }

    if (depth === 0) {
      if (char === '{') {
        current = char;
        depth = 1;
        inString = false;
        escaped = false;
      }
      continue;
    }

    current += char;
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === '\\') {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) {
      continue;
    }
    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        const candidate = current.trim().replace(/\r/g, '').replace(/\n/g, '');
        if (!isModelNoiseLine(candidate)) {
          jsonl += candidate + '\n';
        }
        current = '';
      }
    }
  }
  return {
    jsonl: jsonl,
    remainder: depth > 0 ? current : ''
  };
}

function parseFullA2ui(content: string, store: A2uiSurfaceStore): string {
  const visibleContent = visibleModelContent(content);
  const source = visibleContent.length > 0 ? visibleContent : content;
  const extracted = extractA2uiJsonlFromModelChunk(source.endsWith('\n') ? source : source + '\n');
  if (extracted.jsonl.trim().length === 0) {
    const error = '模型未输出 A2UI JSONL';
    store.applyError('A2UI 解析失败', error);
    return error;
  }
  const parsed = parseA2uiJsonl(extracted.jsonl);
  if (parsed.error.length > 0) {
    store.applyError('A2UI 解析失败', parsed.error);
    return parsed.error;
  }
  return applyEnvelopes(store, parsed.envelopes);
}

async function callNonStreamingModel(settings: LocalModelSettings, body: OpenAiRequestBody, requestDebug: string): Promise<A2uiCallResult> {
  const request = http.createHttp();
  const endpoint = buildChatCompletionsUrl(settings.baseUrl);
  const store = new A2uiSurfaceStore();
  let rawResponse = '';
  let assistantDebug = '';

  try {
    const response = await request.request(endpoint, {
      method: http.RequestMethod.POST,
      header: createHeaders(settings),
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 60000
    });

    rawResponse = response.result as string;
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const error = 'HTTP ' + response.responseCode.toString() + ': ' + rawResponse;
      store.applyError('模型调用失败', error);
      return {
        ok: false,
        raw: rawResponse,
        error: error,
        requestDebug: requestDebug,
        assistantDebug: assistantDebug,
        surface: store.getSurface()
      };
    }

    assistantDebug = extractAssistantContent(rawResponse);
    const parseError = parseFullA2ui(assistantDebug, store);
    return {
      ok: parseError.length === 0,
      raw: rawResponse,
      error: parseError,
      requestDebug: requestDebug,
      assistantDebug: assistantDebug,
      surface: store.getSurface()
    };
  } catch (error) {
    const message = JSON.stringify(error);
    store.applyError('模型调用异常', message);
    return {
      ok: false,
      raw: rawResponse,
      error: message,
      requestDebug: requestDebug,
      assistantDebug: assistantDebug,
      surface: store.getSurface()
    };
  } finally {
    request.destroy();
  }
}

async function callStreamingModel(settings: LocalModelSettings, body: OpenAiRequestBody, requestDebug: string, onSurface: A2uiSurfaceCallback): Promise<A2uiCallResult> {
  const request = http.createHttp();
  const endpoint = buildChatCompletionsUrl(settings.baseUrl);
  const store = new A2uiSurfaceStore();
  const decoder = util.TextDecoder.create('utf-8');
  let rawResponse = '';
  let assistantDebug = '';
  let assistantA2uiContent = '';
  let jsonlRemainder = '';
  let extractionRemainder = '';
  let sseRemainder = '';
  let streamError = '';
  let reasoningLength = 0;
  let contentChunkCount = 0;
  let envelopeCount = 0;
  let thinkInProgress = false;
  let thinkTagRemainder = '';
  let modelThoughts: string[] = [];
  let streamEndResolve: () => void = () => {};
  const streamEnd = new Promise<void>((resolve: () => void) => {
    streamEndResolve = resolve;
  });

  request.on('dataReceive', (data: ArrayBuffer) => {
    const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
    rawResponse += chunk;
    const combined = sseRemainder + chunk;
    const lines = combined.split('\n');
    sseRemainder = combined.endsWith('\n') ? '' : lines[lines.length - 1];
    const complete = combined.endsWith('\n') ? combined : lines.slice(0, lines.length - 1).join('\n') + '\n';
    const reasoningContent = parseSseReasoningContent(complete);
    if (reasoningContent.length > 0) {
      reasoningLength += reasoningContent.length;
      modelThoughts = appendThinkingText(modelThoughts, reasoningContent);
      aiLogInfo('[AIPhone][ModelThinkChunk] reasoningChars=' + reasoningContent.length.toString() + ' total=' + reasoningLength.toString() + ' snippet=' + logSnippet(reasoningContent));
      if (envelopeCount === 0) {
        showModelThinking(store, rawResponse, onSurface, modelThoughts);
      }
    }
    const content = parseSseContent(complete);
    if (content.length === 0) {
      return;
    }
    assistantDebug += content;
    contentChunkCount += 1;
    aiLogInfo('[AIPhone][ModelContentChunk] chunk=' + contentChunkCount.toString() + ' chars=' + content.length.toString() + ' snippet=' + logSnippet(content));
    const split = splitModelThinkFromContent(content, thinkInProgress, thinkTagRemainder);
    thinkInProgress = split.inThink;
    thinkTagRemainder = split.tagRemainder;
    if (split.think.length > 0) {
      modelThoughts = appendThinkingText(modelThoughts, split.think);
      aiLogInfo('[AIPhone][ModelThinkTagChunk] chars=' + split.think.length.toString() + ' inThink=' + (thinkInProgress ? 'true' : 'false') + ' snippet=' + logSnippet(split.think));
      if (envelopeCount === 0) {
        showModelThinking(store, rawResponse, onSurface, modelThoughts);
      }
    }
    if (split.content.length === 0) {
      aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=0 thinkOnly=true tagRemainder=' + thinkTagRemainder.length.toString());
      return;
    }
    assistantA2uiContent += split.content;
    const extracted = extractA2uiJsonlFromModelChunk(split.content, extractionRemainder);
    extractionRemainder = extracted.remainder;
    if (extracted.jsonl.length === 0) {
      aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=0 remainder=' + extractionRemainder.length.toString() + ' remainderSnippet=' + logSnippet(extractionRemainder));
      if (shouldDisplayPlainModelThinking(split.content, extractionRemainder, envelopeCount)) {
        modelThoughts = appendThinkingText(modelThoughts, split.content);
        aiLogInfo('[AIPhone][ModelPlainThinkChunk] chars=' + split.content.length.toString() + ' snippet=' + logSnippet(split.content));
        showModelThinking(store, rawResponse, onSurface, modelThoughts);
      } else if (envelopeCount === 0 && modelThoughts.length === 0) {
        showModelThinking(store, rawResponse, onSurface, modelThoughts);
      }
      return;
    }
    aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=' + extracted.jsonl.length.toString() + ' remainder=' + extractionRemainder.length.toString() + ' jsonlSnippet=' + logSnippet(extracted.jsonl));
    const parsed = parseA2uiJsonlChunk(extracted.jsonl, jsonlRemainder);
    jsonlRemainder = parsed.remainder;
    if (parsed.error.length > 0) {
      streamError = parsed.error;
      aiLogError('[AIPhone][ModelA2UIParseError] ' + parsed.error + ' assistantSnippet=' + logSnippet(assistantDebug));
      store.applyError('A2UI 流解析失败', parsed.error);
      onSurface(store.getSurface(), rawResponse);
      return;
    }
    envelopeCount += parsed.envelopes.length;
    if (parsed.envelopes.length > 0) {
      aiLogInfo('[AIPhone][ModelA2UIEnvelopes] count=' + parsed.envelopes.length.toString() + ' total=' + envelopeCount.toString());
    }
    const applyError = applyEnvelopes(store, parsed.envelopes, true);
    if (applyError.length > 0) {
      streamError = applyError;
      aiLogError('[AIPhone][ModelA2UIApplyError] ' + applyError);
    }
    onSurface(store.getSurface(), rawResponse);
  });
  request.on('dataEnd', () => {
    streamEndResolve();
  });

  try {
    showModelThinking(store, rawResponse, onSurface, modelThoughts);
    const responseCode = await request.requestInStream(endpoint, {
      method: http.RequestMethod.POST,
      header: createHeaders(settings),
      extraData: JSON.stringify(body),
      connectTimeout: 10000,
      readTimeout: 60000
    });
    aiLogInfo('[AIPhone][ModelStreamResponse] code=' + responseCode.toString());
    await streamEnd;
    aiLogInfo('[AIPhone][ModelStreamEnd] rawChars=' + rawResponse.length.toString() + ' assistantChars=' + assistantDebug.length.toString() + ' envelopes=' + envelopeCount.toString() + ' reasoningChars=' + reasoningLength.toString() + ' assistantSnippet=' + logSnippet(assistantDebug));

    if (responseCode < 200 || responseCode >= 300) {
      const error = 'HTTP ' + responseCode.toString() + ': ' + rawResponse;
      store.applyError('模型调用失败', error);
      return {
        ok: false,
        raw: rawResponse,
        error: error,
        requestDebug: requestDebug,
        assistantDebug: assistantDebug,
        surface: store.getSurface()
      };
    }

    if (extractionRemainder.trim().length > 0 && streamError.length === 0) {
      const extracted = extractA2uiJsonlFromModelChunk('\n', extractionRemainder);
      extractionRemainder = extracted.remainder;
      const parsed = parseA2uiJsonlChunk(extracted.jsonl, jsonlRemainder);
      jsonlRemainder = parsed.remainder;
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes, true);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (jsonlRemainder.trim().length > 0 && streamError.length === 0) {
      const parsed = parseA2uiJsonlChunk('\n', jsonlRemainder);
      jsonlRemainder = parsed.remainder;
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes, true);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (store.getSurface().components.length === 0 && assistantA2uiContent.length > 0 && streamError.length === 0) {
      streamError = parseFullA2ui(assistantA2uiContent, store);
    }

    if (streamError.length > 0) {
      store.applyError('A2UI 流解析失败', streamError);
    }
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: assistantDebug,
      surface: store.getSurface()
    };
  } catch (error) {
    const message = JSON.stringify(error);
    store.applyError('模型流式调用异常', message);
    return {
      ok: false,
      raw: rawResponse,
      error: message,
      requestDebug: requestDebug,
      assistantDebug: assistantDebug,
      surface: store.getSurface()
    };
  } finally {
    request.destroy();
  }
}

export async function callLocalModel(settings: LocalModelSettings, prompt: string, history: A2uiMessage[], onSurface: A2uiSurfaceCallback): Promise<A2uiCallResult> {
  const messages = toOpenAiMessages(history, prompt);
  const shouldStream = isLocalBaseUrl(settings.baseUrl);
  const body: OpenAiRequestBody = {
    model: settings.model,
    stream: shouldStream,
    temperature: 0.2,
    messages: messages
  };
  const requestDebug = JSON.stringify({
    endpoint: buildChatCompletionsUrl(settings.baseUrl),
    provider: settings.provider,
    model: settings.model,
    stream: body.stream,
    temperature: body.temperature,
    messages: messages
  });
  aiLogInfo('[AIPhone][A2UIModelRequest] ' + truncateDebugText(requestDebug));

  if (shouldStream) {
    return callStreamingModel(settings, body, requestDebug, onSurface);
  }
  return callNonStreamingModel(settings, body, requestDebug);
}

export function emptyA2uiModelResult(error: string): A2uiCallResult {
  return {
    ok: false,
    raw: '',
    error: error,
    requestDebug: '',
    assistantDebug: '',
    surface: emptyA2uiSurface()
  };
}
