import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  normalizeSocialHubConnection,
  normalizeSocialHubDraft,
  normalizeSocialHubItem,
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform
} from './SocialHubTypes';

export interface SocialHubFeedResult {
  items: SocialHubItemData[];
  connections: SocialHubConnectionData[];
}

interface SocialHubBridgeFeedPayload {
  items?: Object[];
  connections?: Object[];
}

interface SocialHubBridgeDraftPayload {
  draft?: Object;
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

function responseText(value: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(value));
  }
  return textOf(value);
}

function bridgeUrl(): string {
  return 'http://127.0.0.1:8787/api/social';
}

export function socialHubBridgeHeaders(gatewayApiKey: string): Record<string, string> {
  const headers: Record<string, string> = {
    'Accept': 'application/json'
  };
  const apiKey = gatewayApiKey.trim();
  if (apiKey.length > 0) {
    headers['X-API-Key'] = apiKey;
  }
  return headers;
}

export function parseSocialHubFeedPayload(raw: string): SocialHubFeedResult {
  const payload = JSON.parse(raw) as SocialHubBridgeFeedPayload;
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  if (Array.isArray(payload.items)) {
    payload.items.forEach((item: Object) => {
      items.push(normalizeSocialHubItem(item));
    });
  }
  if (Array.isArray(payload.connections)) {
    payload.connections.forEach((connection: Object) => {
      connections.push(normalizeSocialHubConnection(connection));
    });
  }
  return { items: items, connections: connections };
}

export function parseSocialHubDraftPayload(raw: string): SocialHubDraftData {
  const payload = JSON.parse(raw) as SocialHubBridgeDraftPayload;
  return normalizeSocialHubDraft(payload.draft);
}

export function socialHubXPostResult(result: SocialHubFeedResult): SocialHubFeedResult {
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  result.items.forEach((item: SocialHubItemData) => {
    if (item.platform === 'x' && item.kind === 'post') {
      items.push(item);
    }
  });
  result.connections.forEach((connection: SocialHubConnectionData) => {
    if (connection.platform === 'x') {
      connections.push(connection);
    }
  });
  return {
    items: items,
    connections: connections
  };
}

function connectionError(platform: SocialHubPlatform, message: string): SocialHubConnectionData {
  return {
    platform: platform,
    status: 'error',
    displayName: platform === 'x' ? 'X' : (platform === 'slack' ? 'Slack' : '企业微信'),
    accountId: '',
    message: message
  };
}

export function socialHubBridgeUnavailableFeed(message: string): SocialHubFeedResult {
  const detail = 'Social bridge unavailable: ' + message;
  return {
    items: [],
    connections: [
      connectionError('x', detail),
      connectionError('slack', detail),
      connectionError('wecom', detail)
    ]
  };
}

export function socialHubBridgeDraftError(itemId: string, platform: SocialHubPlatform, message: string): SocialHubDraftData {
  return {
    itemId: itemId,
    platform: platform,
    text: '',
    status: 'error',
    error: 'Social bridge unavailable: ' + message,
    localOnly: true,
    sent: false
  };
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
  return JSON.stringify(error);
}

async function httpText(url: string, method: http.RequestMethod, body: string = '', gatewayApiKey: string = ''): Promise<string> {
  const request = http.createHttp();
  try {
    const headers = socialHubBridgeHeaders(gatewayApiKey);
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 3000,
      readTimeout: 5000
    };
    if (body.length > 0) {
      headers['Content-Type'] = 'application/json';
      options.extraData = body;
    }
    const response = await request.request(url, options);
    const text = responseText(response.result);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('HTTP ' + response.responseCode.toString() + ': ' + text);
    }
    return text;
  } finally {
    request.destroy();
  }
}

export class SocialHubClient {
  async feed(query: string, gatewayApiKey: string = ''): Promise<SocialHubFeedResult> {
    try {
      return parseSocialHubFeedPayload(await httpText(bridgeUrl() + '/feed?q=' + encodeURIComponent(query), http.RequestMethod.GET, '', gatewayApiKey));
    } catch (error) {
      return socialHubBridgeUnavailableFeed(describeThrown(error));
    }
  }

  async xPostSearch(query: string, gatewayApiKey: string = ''): Promise<SocialHubFeedResult> {
    try {
      return socialHubXPostResult(parseSocialHubFeedPayload(await httpText(bridgeUrl() + '/feed?source=x&q=' + encodeURIComponent(query), http.RequestMethod.GET, '', gatewayApiKey)));
    } catch (error) {
      return socialHubXPostResult(socialHubBridgeUnavailableFeed(describeThrown(error)));
    }
  }

  async draft(itemId: string, platform: SocialHubPlatform, instruction: string, gatewayApiKey: string = ''): Promise<SocialHubDraftData> {
    try {
      return parseSocialHubDraftPayload(await httpText(bridgeUrl() + '/draft', http.RequestMethod.POST, JSON.stringify({
        itemId: itemId,
        platform: platform,
        instruction: instruction
      }), gatewayApiKey));
    } catch (error) {
      return socialHubBridgeDraftError(itemId, platform, describeThrown(error));
    }
  }
}
