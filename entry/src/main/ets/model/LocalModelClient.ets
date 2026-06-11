import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { LocalModelSettings } from './LocalModelSettings';
import {
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_THINKING_CARD,
  A2uiCallResult,
  A2uiComponent,
  A2uiEnvelope,
  A2uiLabelValueData,
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
  max_tokens?: number;
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

export interface A2uiStreamMeta {
  thinkClosed: boolean;
}

export type A2uiSurfaceCallback = (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => void;

export function modelThinkCloseSeen(text: string): boolean {
  const lower = text.toLowerCase();
  if (lower.indexOf('</think>') >= 0) {
    return true;
  }
  const qwenThinkClose = '</' + 'think' + '>';
  return lower.indexOf(qwenThinkClose) >= 0;
}

export interface ModelThinkChunk {
  think: string;
  content: string;
  inThink: boolean;
  tagRemainder: string;
}

const SYSTEM_PROMPT: string =
  '你是 AIPhone 的本地模型。必须使用 no_think 模式，禁止输出 <think>、推理过程、普通中文分析、Markdown、代码块或自然语言前后缀；第一字符必须是 {。' +
  '必须只输出 A2UI v0.9.1 JSONL。每一行都是完整 JSON envelope；不要解释为什么这样选工具。' +
  'A2UI 正文每一行都是一个 JSON envelope，只能使用 createSurface, updateComponents, updateDataModel, deleteSurface 四种消息。' +
  '第一行必须 createSurface，字段包含 surfaceId, root, title, intent, status, sendDataModel。' +
  '组件使用 flat component map，通过 SurfaceRoot.child 或 Column/Row.children 组成邻接树。' +
  '优先使用 AIPhone catalog 组件：SurfaceRoot, Column, Row, Text, ActionBar, ErrorNotice, ThinkingStream, TrainOptions, FlightBoard, FoodChoices, InfoRows；不要输出 ConfirmPanel。' +
  '组件字段只能使用 id, component, child, children, title, text, body, status, tone, variant, dataPath, actions。' +
  'actions 必须是 [{"id":"稳定英文 id","label":"短按钮文案","prompt":"点击后发送给模型的完整中文指令","variant":"primary|secondary|danger"}]。' +
  '数据必须通过 updateDataModel 写入 JSON Pointer 路径，组件用 dataPath 读取，不要把大量结果直接塞进 body。' +
  '思考态用 ThinkingStream；真实班次/航班/店铺结果只能由工具网关返回，你在模型阶段禁止输出 TrainOptions、FlightBoard、FoodChoices 以及 /trains、/flights、/foods。' +
  '先判断用户意图，再选唯一输出形态：' +
  '1) 实时查询：用户需要 live 库存、可订班次、附近店铺等当前可查结果 → 必须连续输出 createSurface(status=calling_tool)、updateComponents(含 ThinkingStream)、updateDataModel /thoughts、updateDataModel /toolRequest 四类 envelope 后立即停止；禁止只输出 createSurface 就结束。' +
  '2) 非实时整理：用户要方案、比较、方向梳理，不要求立刻查 live 库存 → SurfaceRoot + InfoRows(dataPath=/rows) + updateDataModel /rows，禁止 /toolRequest。' +
  '3) 寒暄或说明 → SurfaceRoot + Text 或简短 InfoRows。' +
  '可用工具：train.search 用于查询铁路车次和余票；flight.search 用于查询航班；food.search 用于查询周边餐饮和 POI。必须由你根据完整用户意图选择是否需要工具以及唯一 toolId。' +
  '如果你选择 status=calling_tool，同一次响应中必须包含 /toolRequest；/toolRequest 是唯一合法路径，禁止 /toolRequests；值必须是 {"toolId":"train.search|flight.search|food.search","prompt":"原始中文请求","actionId":"model_tool_request"}。' +
  '整理类 /rows 的 value 必须是 [{"label":"...","value":"..."}]；只写用户已给信息与下一步确认项，不要编造精确班次、价格、耗时、库存、营业状态。' +
  '订票、下单、支付、抢票不能自动执行；交易请求只用 Text 或 ErrorNotice 告知需用户自行确认。' +
  '示例 A，寒暄：' +
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface_model","root":"root","title":"AIPhone","intent":"general","status":"ready","sendDataModel":true}}' + '\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"hello","title":"AIPhone","status":"ready"},{"id":"hello","component":"Text","text":"你好，我在。你可以让我查询高铁、航班或附近餐饮。","status":"ready"}]}}' + '\n' +
  '示例 B，实时查高铁（到 /toolRequest 结束）：' +
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface_model","root":"root","title":"正在准备查询","intent":"travel","status":"calling_tool","sendDataModel":true}}' + '\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"thinking","title":"正在准备查询","status":"calling_tool"},{"id":"thinking","component":"ThinkingStream","title":"AIPhone 正在处理","body":"正在把请求交给工具","status":"calling_tool","dataPath":"/thoughts","actions":[]}]}}' + '\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","path":"/thoughts","value":["正在识别出行约束","正在准备调用查询工具","正在等待工具返回"]}}' + '\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","path":"/toolRequest","value":{"toolId":"train.search","prompt":"帮我查询明天北京到上海高铁票","actionId":"model_tool_request"}}}' + '\n' +
  '示例 C，非实时整理出行选项：' +
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface_model","root":"root","title":"出行选项整理","intent":"travel","status":"ready","sendDataModel":true}}' + '\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"plan","title":"出行选项整理","status":"ready"},{"id":"plan","component":"InfoRows","title":"可查方向","dataPath":"/rows","status":"ready","actions":[]}]}}' + '\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","path":"/rows","value":[{"label":"高铁","value":"可进一步查询具体班次与余票"},{"label":"航班","value":"可进一步查询具体航班与票价"},{"label":"下一步","value":"告诉我出发日期后可发起实时查询"}]}}' + '\n' +
  '旧 aiphone.ui.v1 或 aiphone.ui.v2 格式不再受支持，绝不能输出。' +
  '客户端能力如下：' + JSON.stringify(defaultA2uiCapabilities()) + '。';

export function resolveSystemPrompt(_prompt: string = ''): string {
  return SYSTEM_PROMPT;
}

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

function describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
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
  if (json.length > 0 && json !== '{}') {
    return json;
  }
  return String(error);
}

function isLocalModelConnectionFailure(settings: LocalModelSettings, message: string): boolean {
  if (!isLocalBaseUrl(settings.baseUrl)) {
    return false;
  }
  const lower = message.toLowerCase();
  return lower.indexOf('failed to connect') >= 0 ||
    lower.indexOf('couldn') >= 0 ||
    lower.indexOf('connection refused') >= 0 ||
    lower.indexOf('curl code 7') >= 0 ||
    lower.indexOf('curl_code":7') >= 0 ||
    lower.indexOf('os_errno":111') >= 0 ||
    lower.indexOf('2300007') >= 0;
}

function modelTransportErrorTitle(settings: LocalModelSettings, message: string, fallbackTitle: string): string {
  if (isLocalModelConnectionFailure(settings, message)) {
    return '本地模型服务不可用';
  }
  return fallbackTitle;
}

function describeModelTransportError(settings: LocalModelSettings, endpoint: string, error: Error | Object | string | number | boolean | null | undefined): string {
  const message = describeThrown(error);
  if (isLocalModelConnectionFailure(settings, message)) {
    return message + '。请求地址=' + endpoint + '。这表示设备本机 127.0.0.1:11434 没有可用模型服务监听；不是 Mac tool-gateway，也不是 12306/飞常准/高德 key 异常。';
  }
  if (message.length > 0) {
    return message;
  }
  return 'unknown model transport error';
}

function shouldRetryLocalModelTransport(settings: LocalModelSettings, result: A2uiCallResult): boolean {
  return !result.ok && isLocalModelConnectionFailure(settings, result.error);
}

function waitBeforeLocalModelRetry(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, 1500);
  });
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

function toOpenAiMessages(history: A2uiMessage[], prompt: string, systemPrompt: string): OpenAiMessage[] {
  const messages: OpenAiMessage[] = [];
  messages.push({
    role: 'system',
    content: systemPrompt
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

const THINK_TAG_OPEN: string = '<' + 'think' + '>';
const THINK_TAG_CLOSE: string = '</' + 'think' + '>';
const THINK_OPEN_TAGS: string[] = [THINK_TAG_OPEN, '<think>'];
const THINK_CLOSE_TAGS: string[] = [THINK_TAG_CLOSE, '</think>'];

function isThinkOpenTag(text: string, index: number): boolean {
  for (let tagIndex = 0; tagIndex < THINK_OPEN_TAGS.length; tagIndex++) {
    if (startsWithIgnoreCase(text, index, THINK_OPEN_TAGS[tagIndex])) {
      return true;
    }
  }
  return false;
}

function thinkOpenTagLength(text: string, index: number): number {
  for (let tagIndex = 0; tagIndex < THINK_OPEN_TAGS.length; tagIndex++) {
    const token = THINK_OPEN_TAGS[tagIndex];
    if (startsWithIgnoreCase(text, index, token)) {
      return token.length;
    }
  }
  return 0;
}

function isThinkCloseTag(text: string, index: number): boolean {
  for (let tagIndex = 0; tagIndex < THINK_CLOSE_TAGS.length; tagIndex++) {
    if (startsWithIgnoreCase(text, index, THINK_CLOSE_TAGS[tagIndex])) {
      return true;
    }
  }
  return false;
}

function thinkCloseTagLength(text: string, index: number): number {
  for (let tagIndex = 0; tagIndex < THINK_CLOSE_TAGS.length; tagIndex++) {
    const token = THINK_CLOSE_TAGS[tagIndex];
    if (startsWithIgnoreCase(text, index, token)) {
      return token.length;
    }
  }
  return 0;
}

function isPartialThinkTag(text: string, index: number): boolean {
  const tail = text.substring(index).toLowerCase();
  if (tail.length === 0) {
    return false;
  }
  for (let tagIndex = 0; tagIndex < THINK_OPEN_TAGS.length; tagIndex++) {
    const token = THINK_OPEN_TAGS[tagIndex];
    if (token.startsWith(tail) || ('</' + token.substring(1)).startsWith(tail)) {
      return true;
    }
  }
  for (let tagIndex = 0; tagIndex < THINK_CLOSE_TAGS.length; tagIndex++) {
    const token = THINK_CLOSE_TAGS[tagIndex];
    if (token.startsWith(tail)) {
      return true;
    }
  }
  return false;
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
      if (isThinkOpenTag(text, index)) {
        stillInThink = true;
        index += thinkOpenTagLength(text, index);
        continue;
      }
      if (isThinkCloseTag(text, index)) {
        stillInThink = false;
        index += thinkCloseTagLength(text, index);
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

export function normalizeAssistantDebugDisplay(text: string): string {
  const closeToken = '</think>';
  const openToken = '<think>';
  const closeIndex = text.indexOf(closeToken);
  if (closeIndex < 0 || text.indexOf(openToken) >= 0) {
    return text;
  }
  return openToken + text.substring(0, closeIndex) + text.substring(closeIndex);
}

function shouldOpenReasoningInAssistantDebug(assistantDebug: string, thinkInProgress: boolean, tagRemainder: string): boolean {
  if (thinkInProgress || tagRemainder.length > 0) {
    return false;
  }
  return assistantDebug.indexOf('<think>') < 0;
}

function finalizeAssistantDebug(text: string, reasoningOpen: boolean): string {
  let normalized = normalizeAssistantDebugDisplay(text);
  if (reasoningOpen && normalized.indexOf('</think>') < 0) {
    normalized += '</think>';
  }
  return normalized;
}

function visibleModelContent(content: string): string {
  return splitModelThinkFromContent(content, false, '').content;
}

const THINKING_PLACEHOLDER: string = '等待模型响应';

export function appendThinkingStream(existing: string[], text: string): string[] {
  if (text.length === 0) {
    return existing;
  }
  const next = existing.slice();
  if (next.length === 0 || (next.length === 1 && next[0] === THINKING_PLACEHOLDER)) {
    return [text];
  }
  next[next.length - 1] = next[next.length - 1] + text;
  return next;
}

function shouldDisplayPlainModelThinking(content: string, extractionRemainder: string, envelopeCount: number): boolean {
  if (envelopeCount > 0) {
    return false;
  }
  const trimmed = content.trim();
  if (trimmed.length === 0) {
    return false;
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('```')) {
    return false;
  }
  const remainder = extractionRemainder.trim();
  if (remainder.startsWith('{') || remainder.startsWith('```')) {
    return false;
  }
  return true;
}

const MODEL_THINKING_COMPONENT_ID: string = 'model_thinking_card';
const MODEL_THINKING_SURFACE_ID: string = 'surface_model_thinking';

function hasThinkingCardComponent(surface: A2uiSurfaceState): boolean {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].component === A2UI_COMPONENT_THINKING_CARD) {
      return true;
    }
  }
  return false;
}

function thinkingCardComponent(): A2uiComponent {
  return {
    id: MODEL_THINKING_COMPONENT_ID,
    component: A2UI_COMPONENT_THINKING_CARD,
    title: '正在理解你的请求',
    body: '思考流写入中',
    status: 'thinking',
    dataPath: '/thoughts',
    actions: []
  };
}

function shouldBootstrapThinkingSurface(surface: A2uiSurfaceState): boolean {
  if (surface.surfaceId === 'surface_model') {
    return false;
  }
  return surface.surfaceId.length === 0
    || surface.surfaceId === 'surface_seed'
    || surface.surfaceId === 'surface_main';
}

function ensureThinkingBootstrapSurface(store: A2uiSurfaceStore): void {
  let surface = store.getSurface();
  if (surface.surfaceId !== MODEL_THINKING_SURFACE_ID) {
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: MODEL_THINKING_SURFACE_ID,
        root: 'root',
        title: '正在理解你的请求',
        intent: 'general',
        status: 'thinking',
        sendDataModel: true
      }
    });
    surface = store.getSurface();
  } else if (surface.components.length === 0) {
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: MODEL_THINKING_SURFACE_ID,
        root: 'root',
        title: '正在理解你的请求',
        intent: 'general',
        status: 'thinking',
        sendDataModel: true
      }
    });
    surface = store.getSurface();
  }
  if (!hasThinkingCardComponent(surface)) {
    const card = thinkingCardComponent();
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: MODEL_THINKING_SURFACE_ID,
        components: [
          {
            id: 'root',
            component: A2UI_COMPONENT_SURFACE_ROOT,
            child: MODEL_THINKING_COMPONENT_ID,
            title: '正在理解你的请求',
            status: 'thinking'
          },
          card
        ]
      }
    });
  }
}

function showModelThinking(store: A2uiSurfaceStore, rawResponse: string, onSurface: A2uiSurfaceCallback, thoughts: string[], thinkClosed: boolean = false): void {
  const surface = store.getSurface();
  if (shouldBootstrapThinkingSurface(surface)) {
    ensureThinkingBootstrapSurface(store);
  }
  const activeSurfaceId = store.getSurface().surfaceId;
  store.apply({
    version: 'v0.9.1',
    updateDataModel: {
      surfaceId: activeSurfaceId,
      path: '/thoughts',
      value: thoughts.length > 0 ? thoughts : [THINKING_PLACEHOLDER]
    }
  });
  const meta: A2uiStreamMeta = { thinkClosed: thinkClosed };
  onSurface(store.getSurface(), rawResponse, meta);
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
      return;
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

interface A2uiEnvelopeProbe {
  createSurface?: Object | string | null;
  updateComponents?: Object | null;
  updateDataModel?: Object | null;
  deleteSurface?: Object | null;
}

interface CompactInfoRowsProbe {
  title?: Object | string | number | boolean | null;
  dataPath?: Object | string | number | boolean | null;
  value?: Object[];
  rows?: Object[];
  items?: Object[];
}

interface CompactComponentsProbe {
  InfoRows?: CompactInfoRowsProbe;
}

interface CompactDataModelProbe {
  rows?: Object[];
  items?: Object[];
  columns?: Object[];
  value?: Object | string | number | boolean | null;
  values?: Object | string | number | boolean | null;
}

interface ActionStyleModelProbe {
  action?: Object | string | number | boolean | null;
  components?: CompactComponentsProbe | OperationComponentProbe[] | null;
  dataPaths?: CompactDataModelProbe;
  path?: Object | string | number | boolean | null;
  value?: Object[];
  rows?: Object[];
  columns?: Object[];
}

interface OperationStyleModelProbe {
  operation?: Object | string | number | boolean | null;
  surface?: OperationSurfaceProbe;
}

interface OperationSurfaceProbe {
  name?: Object | string | number | boolean | null;
  components?: OperationComponentProbe[];
}

interface OperationComponentProbe {
  type?: Object | string | number | boolean | null;
  dataPath?: Object | string | number | boolean | null;
  value?: Object[];
  rows?: Object[];
  items?: Object[];
  columns?: Object[];
  components?: OperationComponentProbe[];
}

interface UpdatesStyleModelProbe {
  title?: Object | string | number | boolean | null;
  updates?: UpdatePatchProbe[];
}

interface UpdatePatchProbe {
  path?: Object | string | number | boolean | null;
  value?: Object | string | number | boolean | null;
  rows?: Object[];
  items?: Object[];
  columns?: Object[];
}

interface CompactRowProbe {
  label?: Object | string | number | boolean | null;
  value?: Object | string | number | boolean | null;
  title?: Object | string | number | boolean | null;
  subtitle?: Object | string | number | boolean | null;
  direction?: Object | string | number | boolean | null;
  type?: Object | string | number | boolean | null;
  status?: Object | string | number | boolean | null;
  note?: Object | string | number | boolean | null;
}

function compactTextOf(value: Object | string | number | boolean | null | undefined): string {
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

function compactJoinRowParts(first: string, second: string, third: string): string {
  let value = '';
  if (first.length > 0) {
    value = first;
  }
  if (second.length > 0) {
    value = value.length > 0 ? value + ' · ' + second : second;
  }
  if (third.length > 0) {
    value = value.length > 0 ? value + ' · ' + third : third;
  }
  return value;
}

function compactLabelRowsFromObjects(value: Object[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  value.forEach((item: Object, index: number) => {
    const record = item as CompactRowProbe;
    const labelSource = compactTextOf(record.label);
    const titleSource = compactTextOf(record.title);
    const typeSource = compactTextOf(record.type);
    const directionSource = compactTextOf(record.direction);
    const valueSource = compactTextOf(record.value);
    const subtitleSource = compactTextOf(record.subtitle);
    const statusSource = compactTextOf(record.status);
    const noteSource = compactTextOf(record.note);
    const label = labelSource.length > 0 ? labelSource :
      (titleSource.length > 0 ? titleSource :
      (typeSource.length > 0 ? typeSource :
      (directionSource.length > 0 ? directionSource : '信息 ' + (index + 1).toString())));
    const valueText = valueSource.length > 0 ? valueSource :
      (subtitleSource.length > 0 ? subtitleSource : compactJoinRowParts(directionSource, statusSource, noteSource));
    const normalizedValue = valueText.length > 0 ? valueText : compactTextOf(item);
    if (shouldKeepModelGeneratedRow(label, normalizedValue)) {
      rows.push({
        label: label,
        value: normalizedValue
      });
    }
  });
  return rows;
}

function shouldKeepModelGeneratedRow(label: string, value: string): boolean {
  const text = label + ' ' + value;
  if (text.indexOf('出发时间') >= 0 || text.indexOf('到达时间') >= 0 || text.indexOf('预计时长') >= 0) {
    return false;
  }
  if (text.indexOf('票价') >= 0 || text.indexOf('价格') >= 0 || text.indexOf('¥') >= 0 || text.indexOf('￥') >= 0) {
    return false;
  }
  if (text.indexOf('[') >= 0 || text.indexOf(']') >= 0 || text.indexOf('车次') >= 0 || text.indexOf('航班号') >= 0) {
    return false;
  }
  if (text.indexOf('车站') >= 0 || text.indexOf('机场') >= 0 || text.indexOf('小时') >= 0 || text.indexOf('分钟') >= 0 || text.indexOf('最快') >= 0 || text.indexOf('飞行时间') >= 0) {
    return false;
  }
  if (/\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b/.test(text) || /\b\d{4}年\d{1,2}月\d{1,2}日\b/.test(text)) {
    return false;
  }
  if (text.indexOf(':00') >= 0 || text.indexOf(':30') >= 0 || text.indexOf('h/') >= 0 || text.indexOf('h') >= 0) {
    return false;
  }
  return true;
}

function candidateMessageCount(parsed: A2uiEnvelopeProbe): number {
  return (parsed.createSurface !== undefined && parsed.createSurface !== null ? 1 : 0) +
    (parsed.updateComponents !== undefined && parsed.updateComponents !== null ? 1 : 0) +
    (parsed.updateDataModel !== undefined && parsed.updateDataModel !== null ? 1 : 0) +
    (parsed.deleteSurface !== undefined && parsed.deleteSurface !== null ? 1 : 0);
}

function rowsFromOperationComponents(components: OperationComponentProbe[] | undefined): Object[] {
  if (components === undefined || components === null) {
    return [];
  }
  for (let index = 0; index < components.length; index++) {
    const component = components[index];
    if (Array.isArray(component.rows)) {
      return component.rows as Object[];
    }
    if (Array.isArray(component.columns)) {
      return component.columns as Object[];
    }
    if (Array.isArray(component.value)) {
      return component.value as Object[];
    }
    if (Array.isArray(component.items)) {
      return component.items as Object[];
    }
    const nested = rowsFromOperationComponents(component.components);
    if (nested.length > 0) {
      return nested;
    }
  }
  return [];
}

function compactInfoRowsFromComponents(components: CompactComponentsProbe | null | undefined): CompactInfoRowsProbe | null {
  if (components === undefined || components === null) {
    return null;
  }
  if (components.InfoRows === undefined || components.InfoRows === null) {
    return null;
  }
  return components.InfoRows;
}

function rowsFromPatchValue(value: Object | string | number | boolean | null | undefined): Object[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value as Object[];
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(trimmed) as Object;
      return rowsFromPatchValue(parsed);
    } catch (_error) {
      return [];
    }
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return [];
  }
  const dataModel = value as CompactDataModelProbe;
  if (Array.isArray(dataModel.rows)) {
    return dataModel.rows as Object[];
  }
  return [];
}

function patchTargetsRows(patch: UpdatePatchProbe): boolean {
  const path = compactTextOf(patch.path);
  return path.length === 0 || path === '/rows' || path.indexOf('rows') >= 0;
}

function rowsFromUpdates(updates: UpdatePatchProbe[] | undefined): Object[] {
  if (updates === undefined || updates === null) {
    return [];
  }
  for (let index = 0; index < updates.length; index++) {
    const patch = updates[index];
    if (!patchTargetsRows(patch)) {
      continue;
    }
    if (Array.isArray(patch.rows)) {
      return patch.rows as Object[];
    }
    if (Array.isArray(patch.columns)) {
      return patch.columns as Object[];
    }
    if (Array.isArray(patch.items)) {
      return patch.items as Object[];
    }
    const valueRows = rowsFromPatchValue(patch.value);
    if (valueRows.length > 0) {
      return valueRows;
    }
  }
  return [];
}

function compactRowsFromCandidate(parsed: A2uiEnvelopeProbe): Object[] {
  const operationStyle = parsed as OperationStyleModelProbe;
  if (operationStyle.surface !== undefined && operationStyle.surface !== null) {
    const operationRows = rowsFromOperationComponents(operationStyle.surface.components);
    if (operationRows.length > 0) {
      return operationRows;
    }
  }
  const actionStyle = parsed as ActionStyleModelProbe;
  if (Array.isArray(actionStyle.value)) {
    return actionStyle.value as Object[];
  }
  if (Array.isArray(actionStyle.rows)) {
    return actionStyle.rows as Object[];
  }
  if (Array.isArray(actionStyle.columns)) {
    return actionStyle.columns as Object[];
  }
  if (actionStyle.dataPaths !== undefined && actionStyle.dataPaths !== null) {
    if (Array.isArray(actionStyle.dataPaths.rows)) {
      return actionStyle.dataPaths.rows as Object[];
    }
  }
  if (actionStyle.components !== undefined && actionStyle.components !== null) {
    if (Array.isArray(actionStyle.components)) {
      const operationRows = rowsFromOperationComponents(actionStyle.components);
      if (operationRows.length > 0) {
        return operationRows;
      }
    } else {
      const infoRows = compactInfoRowsFromComponents(actionStyle.components);
      if (infoRows !== null) {
        if (Array.isArray(infoRows.value)) {
          return infoRows.value as Object[];
        }
        if (Array.isArray(infoRows.rows)) {
          return infoRows.rows as Object[];
        }
        if (Array.isArray(infoRows.items)) {
          return infoRows.items as Object[];
        }
      }
    }
  }
  const updatesStyle = parsed as UpdatesStyleModelProbe;
  const updateRows = rowsFromUpdates(updatesStyle.updates);
  if (updateRows.length > 0) {
    return updateRows;
  }
  if (parsed.updateDataModel !== undefined && parsed.updateDataModel !== null) {
    const dataModel = parsed.updateDataModel as CompactDataModelProbe;
    if (Array.isArray(dataModel.rows)) {
      return dataModel.rows as Object[];
    }
    if (Array.isArray(dataModel.columns)) {
      return dataModel.columns as Object[];
    }
    if (Array.isArray(dataModel.items)) {
      return dataModel.items as Object[];
    }
    const valueRows = rowsFromPatchValue(dataModel.value);
    if (valueRows.length > 0) {
      return valueRows;
    }
    const valuesRows = rowsFromPatchValue(dataModel.values);
    if (valuesRows.length > 0) {
      return valuesRows;
    }
  }
  if (parsed.updateComponents !== undefined && parsed.updateComponents !== null) {
    const components = parsed.updateComponents as CompactComponentsProbe;
    if (components.InfoRows !== undefined && components.InfoRows !== null) {
      if (Array.isArray(components.InfoRows.value)) {
        return components.InfoRows.value as Object[];
      }
      if (Array.isArray(components.InfoRows.rows)) {
        return components.InfoRows.rows as Object[];
      }
      if (Array.isArray(components.InfoRows.items)) {
        return components.InfoRows.items as Object[];
      }
    }
  }
  return [];
}

function compactInfoRowsTitle(parsed: A2uiEnvelopeProbe): string {
  const operationStyle = parsed as OperationStyleModelProbe;
  if (operationStyle.surface !== undefined && operationStyle.surface !== null &&
    operationStyle.surface.name !== undefined && operationStyle.surface.name !== null) {
    const surfaceName = operationStyle.surface.name;
    if (typeof surfaceName === 'string') {
      return surfaceName.length > 0 ? surfaceName : '整理结果';
    }
    return JSON.stringify(surfaceName);
  }
  const actionStyle = parsed as ActionStyleModelProbe;
  if (actionStyle.components !== undefined && actionStyle.components !== null && !Array.isArray(actionStyle.components)) {
    const actionInfoRows = compactInfoRowsFromComponents(actionStyle.components);
    if (actionInfoRows !== null && actionInfoRows.title !== undefined && actionInfoRows.title !== null) {
      const actionTitle = actionInfoRows.title;
      if (typeof actionTitle === 'string') {
        return actionTitle.length > 0 ? actionTitle : '整理结果';
      }
      return JSON.stringify(actionTitle);
    }
  }
  const updatesStyle = parsed as UpdatesStyleModelProbe;
  const updatesTitle = compactTextOf(updatesStyle.title);
  if (updatesTitle.length > 0) {
    return updatesTitle;
  }
  if (parsed.updateComponents === undefined || parsed.updateComponents === null) {
    return '整理结果';
  }
  const components = parsed.updateComponents as CompactComponentsProbe;
  const infoRows = compactInfoRowsFromComponents(components);
  if (infoRows === null) {
    return '整理结果';
  }
  const title = infoRows.title;
  if (title === undefined || title === null) {
    return '整理结果';
  }
  if (typeof title === 'string') {
    return title.length > 0 ? title : '整理结果';
  }
  return JSON.stringify(title);
}

function compactModelCandidateToA2uiJsonl(parsed: A2uiEnvelopeProbe): string {
  const rows = compactLabelRowsFromObjects(compactRowsFromCandidate(parsed));
  if (rows.length === 0) {
    return '';
  }
  return compactLabelRowsToA2uiJsonl(rows, compactInfoRowsTitle(parsed));
}

function compactLabelRowsToA2uiJsonl(rows: A2uiLabelValueData[], title: string): string {
  if (rows.length === 0) {
    return '';
  }
  const surfaceId = 'surface_model';
  const createSurface: A2uiEnvelope = {
    version: 'v0.9.1',
    createSurface: {
      surfaceId: surfaceId,
      root: 'root',
      title: title,
      intent: 'general',
      status: 'ready',
      sendDataModel: true
    }
  };
  const updateComponents: A2uiEnvelope = {
    version: 'v0.9.1',
    updateComponents: {
      surfaceId: surfaceId,
      components: [
        {
          id: 'root',
          component: 'SurfaceRoot',
          child: 'rows',
          title: title,
          status: 'ready'
        },
        {
          id: 'rows',
          component: 'InfoRows',
          title: title,
          dataPath: '/rows',
          status: 'ready',
          actions: []
        }
      ]
    }
  };
  const updateDataModel: A2uiEnvelope = {
    version: 'v0.9.1',
    updateDataModel: {
      surfaceId: surfaceId,
      path: '/rows',
      value: rows
    }
  };
  return JSON.stringify(createSurface) + '\n' + JSON.stringify(updateComponents) + '\n' + JSON.stringify(updateDataModel) + '\n';
}

function extractJsonStringAfter(text: string, marker: string, startIndex: number): ExtractedString {
  const markerIndex = text.indexOf(marker, startIndex);
  if (markerIndex < 0) {
    return { value: '', nextIndex: -1 };
  }
  const colonIndex = text.indexOf(':', markerIndex + marker.length);
  if (colonIndex < 0) {
    return { value: '', nextIndex: -1 };
  }
  const quoteStart = text.indexOf('"', colonIndex + 1);
  if (quoteStart < 0) {
    return { value: '', nextIndex: -1 };
  }
  let index = quoteStart + 1;
  let value = '';
  let escaped = false;
  while (index < text.length) {
    const char = text.charAt(index);
    if (escaped) {
      value += char;
      escaped = false;
    } else if (char === '\\') {
      escaped = true;
    } else if (char === '"') {
      return { value: value, nextIndex: index + 1 };
    } else {
      value += char;
    }
    index += 1;
  }
  return { value: '', nextIndex: -1 };
}

interface ExtractedString {
  value: string;
  nextIndex: number;
}

function compactLabelRowsFromMalformedText(candidate: string): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  let index = 0;
  while (index >= 0 && index < candidate.length) {
    const label = extractJsonStringAfter(candidate, '"label"', index);
    if (label.nextIndex < 0) {
      break;
    }
    const value = extractJsonStringAfter(candidate, '"value"', label.nextIndex);
    if (value.nextIndex < 0) {
      break;
    }
    rows.push({
      label: label.value,
      value: value.value
    });
    index = value.nextIndex;
  }
  return rows;
}

function normalizeModelEnvelopeCandidate(candidate: string): string {
  try {
    const normalizedCandidate = candidate.split('"/rows":').join('"rows":');
    const parsed = JSON.parse(normalizedCandidate) as A2uiEnvelopeProbe;
    const messageCount = candidateMessageCount(parsed);
    if (messageCount === 1 && normalizedCandidate.indexOf('"version"') >= 0) {
      return candidate + '\n';
    }
    const normalized = compactModelCandidateToA2uiJsonl(parsed);
    if (normalized.length > 0) {
      return normalized;
    }
    return compactLabelRowsToA2uiJsonl(compactLabelRowsFromMalformedText(candidate), '整理结果');
  } catch (_error) {
    return compactLabelRowsToA2uiJsonl(compactLabelRowsFromMalformedText(candidate), '整理结果');
  }
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
          jsonl += normalizeModelEnvelopeCandidate(candidate);
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

    assistantDebug = normalizeAssistantDebugDisplay(extractAssistantContent(rawResponse));
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
    const message = describeModelTransportError(settings, endpoint, error);
    aiLogError('[AIPhone][ModelException] endpoint=' + endpoint + ' error=' + logSnippet(message) +
      ' rawChars=' + rawResponse.length.toString() + ' assistantChars=' + assistantDebug.length.toString());
    store.applyError(modelTransportErrorTitle(settings, message, '模型调用异常'), message);
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
  let reasoningOpenInAssistantDebug = false;
  let modelThoughts: string[] = [];
  let thinkClosed = false;
  let streamEndResolve: () => void = () => {};
  let streamEnded = false;

  const markThinkClosed = (content: string, wasInThink: boolean, nowInThink: boolean): void => {
    if (thinkClosed) {
      return;
    }
    if (modelThinkCloseSeen(content) || (wasInThink && !nowInThink)) {
      thinkClosed = true;
      aiLogInfo('[AIPhone][ModelThinkClosed] detected=true');
    }
  };
  const finishStream = (): void => {
    if (!streamEnded) {
      streamEnded = true;
      streamEndResolve();
    }
  };
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
      modelThoughts = appendThinkingStream(modelThoughts, reasoningContent);
      if (shouldOpenReasoningInAssistantDebug(assistantDebug, thinkInProgress, thinkTagRemainder)) {
        assistantDebug += '<think>';
        reasoningOpenInAssistantDebug = true;
      }
      assistantDebug += reasoningContent;
      aiLogInfo('[AIPhone][ModelThinkChunk] reasoningChars=' + reasoningContent.length.toString() + ' total=' + reasoningLength.toString() + ' snippet=' + logSnippet(reasoningContent));
      showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
    }
    const content = parseSseContent(complete);
    if (content.length === 0) {
      return;
    }
    assistantDebug += content;
    if (modelThinkCloseSeen(content)) {
      reasoningOpenInAssistantDebug = false;
    }
    contentChunkCount += 1;
    aiLogInfo('[AIPhone][ModelContentChunk] chunk=' + contentChunkCount.toString() + ' chars=' + content.length.toString() + ' snippet=' + logSnippet(content));
    const wasInThink = thinkInProgress;
    const split = splitModelThinkFromContent(content, thinkInProgress, thinkTagRemainder);
    thinkInProgress = split.inThink;
    thinkTagRemainder = split.tagRemainder;
    markThinkClosed(content, wasInThink, thinkInProgress);
    if (split.think.length > 0) {
      modelThoughts = appendThinkingStream(modelThoughts, split.think);
      aiLogInfo('[AIPhone][ModelThinkTagChunk] chars=' + split.think.length.toString() + ' inThink=' + (thinkInProgress ? 'true' : 'false') + ' snippet=' + logSnippet(split.think));
      showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
    }
    if (split.content.length === 0) {
      aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=0 thinkOnly=true tagRemainder=' + thinkTagRemainder.length.toString());
      if (thinkClosed) {
        showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
      }
      return;
    }
    assistantA2uiContent += split.content;
    const extracted = extractA2uiJsonlFromModelChunk(split.content, extractionRemainder);
    extractionRemainder = extracted.remainder;
    if (extracted.jsonl.length === 0) {
      aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=0 remainder=' + extractionRemainder.length.toString() + ' remainderSnippet=' + logSnippet(extractionRemainder));
      if (shouldDisplayPlainModelThinking(split.content, extractionRemainder, envelopeCount)) {
        modelThoughts = appendThinkingStream(modelThoughts, split.content);
        aiLogInfo('[AIPhone][ModelPlainThinkChunk] chars=' + split.content.length.toString() + ' snippet=' + logSnippet(split.content));
        showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
      } else if (envelopeCount === 0 && modelThoughts.length === 0) {
        showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
      }
      return;
    }
    aiLogInfo('[AIPhone][ModelA2UIExtract] jsonlChars=' + extracted.jsonl.length.toString() + ' remainder=' + extractionRemainder.length.toString() + ' jsonlSnippet=' + logSnippet(extracted.jsonl));
    const parsed = parseA2uiJsonlChunk(extracted.jsonl, jsonlRemainder);
    jsonlRemainder = parsed.remainder;
    if (parsed.error.length > 0) {
      streamError = parsed.error;
      aiLogError('[AIPhone][ModelA2UIParseError] ' + parsed.error + ' assistantSnippet=' + logSnippet(assistantDebug));
    } else {
      envelopeCount += parsed.envelopes.length;
      if (parsed.envelopes.length > 0) {
        aiLogInfo('[AIPhone][ModelA2UIEnvelopes] count=' + parsed.envelopes.length.toString() + ' total=' + envelopeCount.toString());
      }
      const applyError = applyEnvelopes(store, parsed.envelopes, true);
      if (applyError.length > 0) {
        streamError = applyError;
        aiLogError('[AIPhone][ModelA2UIApplyError] ' + applyError);
      }
      showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
    }
  });
  request.on('dataEnd', () => {
    finishStream();
  });

  try {
    showModelThinking(store, rawResponse, onSurface, modelThoughts, thinkClosed);
    const responseCode = await request.requestInStream(endpoint, {
      method: http.RequestMethod.POST,
      header: createHeaders(settings),
      extraData: JSON.stringify(body),
      connectTimeout: 10000,
      readTimeout: 60000
    });
    aiLogInfo('[AIPhone][ModelStreamResponse] code=' + responseCode.toString());
    finishStream();
    await streamEnd;
    aiLogInfo('[AIPhone][ModelStreamEnd] rawChars=' + rawResponse.length.toString() + ' assistantChars=' + assistantDebug.length.toString() + ' envelopes=' + envelopeCount.toString() + ' reasoningChars=' + reasoningLength.toString() + ' assistantSnippet=' + logSnippet(assistantDebug));
    // #region agent log
    aiLogInfo('[Debug65c5d6][H-PARSE] envelopes=' + envelopeCount.toString() +
      ' extractionRemainder=' + extractionRemainder.length.toString() +
      ' components=' + store.getSurface().components.length.toString() +
      ' dataChars=' + store.getSurface().dataModelJson.length.toString());
    // #endregion

    if (responseCode < 200 || responseCode >= 300) {
      const error = 'HTTP ' + responseCode.toString() + ': ' + rawResponse;
      store.applyError('模型调用失败', error);
      return {
        ok: false,
        raw: rawResponse,
        error: error,
        requestDebug: requestDebug,
        assistantDebug: finalizeAssistantDebug(assistantDebug, reasoningOpenInAssistantDebug),
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

    if ((store.getSurface().components.length === 0 || envelopeCount === 0) && assistantA2uiContent.length > 0 && streamError.length === 0) {
      streamError = parseFullA2ui(assistantA2uiContent, store);
    }

    if (streamError.length > 0) {
      if (envelopeCount === 0) {
        store.applyError('A2UI 流解析失败', streamError);
      }
    }
    const finalizedAssistantDebug = finalizeAssistantDebug(assistantDebug, reasoningOpenInAssistantDebug);
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: finalizedAssistantDebug,
      surface: store.getSurface()
    };
  } catch (error) {
    const message = describeModelTransportError(settings, endpoint, error);
    aiLogError('[AIPhone][ModelStreamException] endpoint=' + endpoint + ' error=' + logSnippet(message) +
      ' rawChars=' + rawResponse.length.toString() + ' assistantChars=' + assistantDebug.length.toString());
    store.applyError(modelTransportErrorTitle(settings, message, '模型流式调用异常'), message);
    const finalizedAssistantDebug = finalizeAssistantDebug(assistantDebug, reasoningOpenInAssistantDebug);
    return {
      ok: false,
      raw: rawResponse,
      error: message,
      requestDebug: requestDebug,
      assistantDebug: finalizedAssistantDebug,
      surface: store.getSurface()
    };
  } finally {
    request.destroy();
  }
}

export async function callLocalModel(settings: LocalModelSettings, prompt: string, history: A2uiMessage[], onSurface: A2uiSurfaceCallback): Promise<A2uiCallResult> {
  const systemPrompt = resolveSystemPrompt(prompt);
  const messages = toOpenAiMessages(history, prompt, systemPrompt);
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

  const result = shouldStream ?
    await callStreamingModel(settings, body, requestDebug, onSurface) :
    await callNonStreamingModel(settings, body, requestDebug);
  if (!shouldRetryLocalModelTransport(settings, result)) {
    return result;
  }
  aiLogInfo('[AIPhone][ModelRetry] reason=local_model_transport baseUrl=' + settings.baseUrl + ' delayMs=1500');
  await waitBeforeLocalModelRetry();
  return shouldStream ?
    callStreamingModel(settings, body, requestDebug, onSurface) :
    callNonStreamingModel(settings, body, requestDebug);
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
