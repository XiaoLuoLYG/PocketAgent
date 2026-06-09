import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  A2uiCallResult,
  A2uiEnvelope,
  A2uiSurfaceState,
  defaultA2uiCapabilities,
  emptyA2uiSurface
} from './A2uiTypes';
import { parseA2uiJsonl, parseA2uiJsonlChunk } from './A2uiParser';
import { A2uiSurfaceStore } from './A2uiSurfaceStore';
import { A2uiSurfaceCallback } from './LocalModelClient';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

interface ToolGatewayRequestBody {
  toolId: string;
  prompt: string;
  surfaceId: string;
  actionId: string;
  stream: boolean;
  a2uiClientCapabilities: Object;
}

interface ToolGatewayHeaders {
  'Content-Type': string;
  'Accept': string;
}

function createHeaders(): ToolGatewayHeaders {
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/a2ui+json'
  };
}

function applyEnvelopes(store: A2uiSurfaceStore, envelopes: A2uiEnvelope[]): string {
  let error = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    const result = store.apply(envelope);
    if (!result.ok && error.length === 0) {
      error = result.error;
    }
  });
  return error;
}

export function defaultToolGatewayUrl(): string {
  return 'http://127.0.0.1:8787';
}

export function buildToolGatewayUrl(baseUrl: string): string {
  let cleaned = baseUrl.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  if (cleaned.endsWith('/api/aiphone/tool')) {
    return cleaned;
  }
  return cleaned + '/api/aiphone/tool';
}

export function isRegisteredToolId(toolId: string): boolean {
  return toolId === 'flight.search' || toolId === 'train.search' || toolId === 'food.search';
}

export function inferToolId(prompt: string): string {
  const source = prompt.toLowerCase().replace('_', '.');
  if (source.indexOf('flight') >= 0 || source.indexOf('航班') >= 0 || source.indexOf('机票') >= 0 || source.indexOf('飞机') >= 0) {
    return 'flight.search';
  }
  if (source.indexOf('train') >= 0 || source.indexOf('12306') >= 0 || source.indexOf('火车') >= 0 || source.indexOf('高铁') >= 0 || source.indexOf('动车') >= 0 || source.indexOf('车票') >= 0) {
    return 'train.search';
  }
  if (source.indexOf('food') >= 0 || source.indexOf('meal') >= 0 || source.indexOf('order') >= 0 || source.indexOf('外卖') >= 0 || source.indexOf('点餐') >= 0 || source.indexOf('午餐') >= 0 || source.indexOf('晚餐') >= 0) {
    return 'food.search';
  }
  return '';
}

export async function callToolGateway(baseUrl: string, toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback): Promise<A2uiCallResult> {
  const request = http.createHttp();
  const endpoint = buildToolGatewayUrl(baseUrl);
  const store = new A2uiSurfaceStore();
  const decoder = util.TextDecoder.create('utf-8');
  let rawResponse = '';
  let remainder = '';
  let streamError = '';
  let streamEndResolve: () => void = () => {};
  const streamEnd = new Promise<void>((resolve: () => void) => {
    streamEndResolve = resolve;
  });
  const body: ToolGatewayRequestBody = {
    toolId: toolId,
    prompt: prompt,
    surfaceId: surfaceId,
    actionId: actionId,
    stream: true,
    a2uiClientCapabilities: defaultA2uiCapabilities()
  };
  const requestDebug = JSON.stringify({
    endpoint: endpoint,
    body: body
  });
  aiLogInfo('[AIPhone][ToolGatewayRequest] endpoint=' + endpoint + ' toolId=' + toolId + ' surfaceId=' + surfaceId + ' promptChars=' + prompt.length.toString());

  request.on('dataReceive', (data: ArrayBuffer) => {
    const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
    rawResponse += chunk;
    aiLogInfo('[AIPhone][ToolGatewayChunk] chars=' + chunk.length.toString() + ' rawChars=' + rawResponse.length.toString());
    const parsed = parseA2uiJsonlChunk(chunk, remainder);
    remainder = parsed.remainder;
    if (parsed.error.length > 0) {
      streamError = parsed.error;
      aiLogError('[AIPhone][ToolGatewayParseError] ' + parsed.error);
      store.applyError('工具返回格式异常', parsed.error);
      onSurface(store.getSurface(), rawResponse);
      return;
    }
    const applyError = applyEnvelopes(store, parsed.envelopes);
    if (applyError.length > 0) {
      streamError = applyError;
      aiLogError('[AIPhone][ToolGatewayApplyError] ' + applyError);
    }
    if (parsed.envelopes.length > 0) {
      aiLogInfo('[AIPhone][ToolGatewayEnvelopes] count=' + parsed.envelopes.length.toString());
    }
    onSurface(store.getSurface(), rawResponse);
  });
  request.on('dataEnd', () => {
    streamEndResolve();
  });

  try {
    const responseCode = await request.requestInStream(endpoint, {
      method: http.RequestMethod.POST,
      header: createHeaders(),
      extraData: JSON.stringify(body),
      connectTimeout: 8000,
      readTimeout: 30000
    });
    aiLogInfo('[AIPhone][ToolGatewayResponse] code=' + responseCode.toString());
    await streamEnd;
    aiLogInfo('[AIPhone][ToolGatewayEnd] rawChars=' + rawResponse.length.toString());

    if (responseCode < 200 || responseCode >= 300) {
      const error = 'HTTP ' + responseCode.toString() + ': ' + rawResponse;
      store.applyError('工具调用失败', error);
      return {
        ok: false,
        raw: rawResponse,
        error: error,
        requestDebug: requestDebug,
        assistantDebug: '',
        surface: store.getSurface()
      };
    }

    if (remainder.trim().length > 0 && streamError.length === 0) {
      const parsed = parseA2uiJsonlChunk('\n', remainder);
      remainder = parsed.remainder;
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (store.getSurface().components.length === 0 && rawResponse.length > 0 && streamError.length === 0) {
      const parsed = parseA2uiJsonl(rawResponse);
      if (parsed.error.length > 0) {
        streamError = parsed.error;
      } else {
        const applyError = applyEnvelopes(store, parsed.envelopes);
        if (applyError.length > 0) {
          streamError = applyError;
        }
      }
    }

    if (streamError.length > 0) {
      store.applyError('工具返回格式异常', streamError);
    }
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } catch (error) {
    const message = JSON.stringify(error);
    store.applyError('工具调用异常', message);
    return {
      ok: false,
      raw: rawResponse,
      error: message,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } finally {
    request.destroy();
  }
}

export function emptyToolGatewayResult(error: string): A2uiCallResult {
  return {
    ok: false,
    raw: '',
    error: error,
    requestDebug: '',
    assistantDebug: '',
    surface: emptyA2uiSurface()
  };
}
