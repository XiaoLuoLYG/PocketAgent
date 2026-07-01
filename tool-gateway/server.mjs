import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOL_GATEWAY_DIR = path.dirname(fileURLToPath(import.meta.url));

function unquoteEnvValue(value) {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

function loadLocalEnv() {
  const envPath = path.join(TOOL_GATEWAY_DIR, '.env.local');
  if (!fs.existsSync(envPath)) {
    return;
  }
  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  lines.forEach(line => {
    const trimmed = line.trim();
    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      return;
    }
    const eq = trimmed.indexOf('=');
    if (eq <= 0) {
      return;
    }
    const key = trimmed.substring(0, eq).trim();
    if (process.env[key] !== undefined) {
      return;
    }
    process.env[key] = unquoteEnvValue(trimmed.substring(eq + 1));
  });
}

loadLocalEnv();

const PORT = Number.parseInt(process.env.TOOL_GATEWAY_PORT || '8787', 10);
const HOST = process.env.TOOL_GATEWAY_HOST || '127.0.0.1';
const GATEWAY_API_KEY = (process.env.TOOL_GATEWAY_API_KEY || '').trim();
const MAX_BODY_BYTES = 1024 * 1024;
const A2UI_VERSION = 'v0.9.1';
const A2UI_MIME = 'application/a2ui+json';
const TRAIN_RESULT_LIMIT = Math.min(Math.max(Number.parseInt(process.env.TRAIN_RESULT_LIMIT || '30', 10) || 30, 6), 50);
const TRAIN_INITIAL_VISIBLE = 6;
const TRAIN_CLIENT_ACTIONS = [
  { id: 'client_show_more', label: '多展示一些', prompt: 'client_show_more', kind: 'client', variant: 'primary' },
  { id: 'client_sort_fastest', label: '选最快的', prompt: 'client_sort_fastest', kind: 'client', variant: 'secondary' },
  { id: 'client_filter_available', label: '只看有票', prompt: 'client_filter_available', kind: 'client', variant: 'secondary' },
  { id: 'client_edit_query', label: '修改查询', prompt: 'client_edit_query', kind: 'input', variant: 'secondary' }
];
const TRAVEL_CLIENT_ACTIONS = [
  { id: 'travel_show_all', label: '全部', prompt: 'travel_show_all', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_train', label: '只看高铁', prompt: 'travel_filter_train', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_flight', label: '只看飞机', prompt: 'travel_filter_flight', kind: 'client', variant: 'secondary' },
  { id: 'travel_change_date', label: '换日期', prompt: '换日期重新查询出行方案', kind: 'input', variant: 'secondary' },
  { id: 'travel_retry', label: '重新查询', prompt: '重新查询出行方案', kind: 'prompt', variant: 'primary' }
];

process.on('uncaughtException', error => {
  console.error('[uncaughtException]', error);
});

process.on('unhandledRejection', reason => {
  console.error('[unhandledRejection]', reason);
});

const TOOL_DEFS = {
  'travel.search': {
    title: '综合出行方案查询',
    envPrefix: 'TRAVEL',
    providerHint: '同时查询 12306 高铁余票和飞常准航班，并按出发时间混排',
    requiredArgs: ['departure_city', 'arrival_city', 'date'],
    configItems: ['12306 无需注册', '航班需要 FLIGHT_MCP_KEY 或 VARIFLIGHT_API_KEY'],
    actions: ['换日期', '只看高铁', '只看飞机', '重新查询']
  },
  'flight.search': {
    title: '国内航班查询',
    envPrefix: 'FLIGHT',
    providerHint: '飞常准 VariFlight MCP/API（国内航班查询）',
    requiredArgs: ['departure_city', 'arrival_city', 'date 或 flight_number'],
    configItems: ['FLIGHT_MCP_KEY 或 VARIFLIGHT_API_KEY', '可选 VARIFLIGHT_API_URL'],
    actions: ['打开飞常准注册页', '配置飞常准 Key', '只查询不预订']
  },
  'train.search': {
    title: '火车票查询',
    envPrefix: 'TRAIN',
    providerHint: '12306 公开余票查询接口',
    requiredArgs: ['from_station', 'to_station', 'train_date'],
    configItems: ['无需注册即可查询 12306 余票摘要', '可选 TRAIN_MCP_URL 或 TRAIN_API_URL'],
    actions: ['多展示一些', '选最快的', '修改查询']
  },
  'food.search': {
    title: '外卖聚合搜索',
    envPrefix: 'FOOD',
    providerHint: '高德 Web 服务 POI、美团联盟商品查询、淘宝闪购联盟店铺推广查询（仅查询展示）',
    requiredArgs: ['location', 'keyword'],
    configItems: ['AMAP_KEY', 'AMAP_DEFAULT_LOCATION=经度,纬度', 'MEITUAN_UNION_APP_KEY/SECRET', 'TAOBAO_APP_KEY/SECRET/TAOBAO_FLASH_PID'],
    actions: ['配置外卖来源 Key', '设置默认坐标', '只查询不下单']
  }
};

const CHINA_FLIGHT_CITY_CODES = {
  '北京': 'BJS',
  '上海': 'SHA',
  '广州': 'CAN',
  '深圳': 'SZX',
  '杭州': 'HGH',
  '成都': 'CTU',
  '重庆': 'CKG',
  '西安': 'SIA',
  '南京': 'NKG',
  '武汉': 'WUH',
  '厦门': 'XMN',
  '青岛': 'TAO',
  '长沙': 'CSX',
  '昆明': 'KMG',
  '海口': 'HAK',
  '三亚': 'SYX'
};

const HIGH_SPEED_DEFAULT_STATIONS = {
  '北京': '北京南',
  '上海': '上海虹桥',
  '天津': '天津西',
  '南京': '南京南',
  '杭州': '杭州东',
  '广州': '广州南',
  '深圳': '深圳北',
  '武汉': '武汉',
  '成都': '成都东',
  '重庆': '重庆北'
};

let stationCache = null;

function isGatewayAuthorized(req) {
  if (GATEWAY_API_KEY.length === 0) {
    return true;
  }
  const authHeader = textOf(req.headers.authorization).trim();
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  const apiKey = textOf(req.headers['x-api-key']).trim() || bearer;
  return apiKey.length > 0 && apiKey === GATEWAY_API_KEY;
}

function rejectUnauthorized(res) {
  sendJson(res, 401, {
    ok: false,
    error: 'Unauthorized: set TOOL_GATEWAY_API_KEY and send Authorization: Bearer <key> or X-API-Key'
  });
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-API-Key'
  });
  res.end(body);
}

function writeA2uiHeaders(res, statusCode = 200) {
  res.writeHead(statusCode, {
    'Content-Type': `${A2UI_MIME}; charset=utf-8`,
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-API-Key'
  });
}

function a2uiLine(envelope) {
  return JSON.stringify({
    version: A2UI_VERSION,
    ...envelope
  }) + '\n';
}

function a2uiJsonl(envelopes) {
  return envelopes.map(a2uiLine).join('');
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function writeA2uiStream(res, jsonl) {
  const lines = jsonl.split('\n').filter(line => line.trim().length > 0);
  const delay = Number.parseInt(process.env.A2UI_STREAM_DELAY_MS || '60', 10);
  for (const line of lines) {
    res.write(line + '\n');
    await sleep(Number.isFinite(delay) && delay >= 0 ? delay : 60);
  }
}

function rewriteA2uiSurfaceId(jsonl, requestedSurfaceId) {
  const surfaceId = textOf(requestedSurfaceId).trim();
  if (surfaceId.length === 0) {
    return jsonl;
  }
  return jsonl
    .split('\n')
    .filter(line => line.trim().length > 0)
    .map(line => {
      const envelope = JSON.parse(line);
      if (envelope.createSurface) {
        envelope.createSurface.surfaceId = surfaceId;
      }
      if (envelope.updateComponents) {
        envelope.updateComponents.surfaceId = surfaceId;
      }
      if (envelope.updateDataModel) {
        envelope.updateDataModel.surfaceId = surfaceId;
      }
      if (envelope.deleteSurface) {
        envelope.deleteSurface.surfaceId = surfaceId;
      }
      return JSON.stringify(envelope);
    })
    .join('\n') + '\n';
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', chunk => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        reject(new Error('Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (raw.trim().length === 0) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', chunk => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        reject(new Error('Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      resolve(Buffer.concat(chunks).toString('utf8'));
    });
    req.on('error', reject);
  });
}

function textOf(value) {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return JSON.stringify(value);
}

const socialCache = {
  items: []
};

function nowIso() {
  return new Date().toISOString();
}

function hasEnv(name) {
  return textOf(process.env[name]).trim().length > 0;
}

function describeError(error) {
  return error instanceof Error ? error.message : textOf(error);
}

function socialConnection(platform, configured, displayName, accountId, configuredMessage, setupMessage) {
  return {
    platform,
    status: configured ? 'connected' : 'needs_auth',
    displayName,
    accountId: configured ? accountId : '',
    message: configured ? configuredMessage : setupMessage
  };
}

function socialConnectionError(platform, message) {
  return {
    platform,
    status: 'error',
    displayName: platform === 'x' ? 'X' : 'Slack',
    accountId: '',
    message
  };
}

function socialConnections(source = '') {
  const xConfigured = hasEnv('X_BEARER_TOKEN') || hasEnv('X_ACCESS_TOKEN') || hasEnv('X_OAUTH_TOKEN');
  const slackConfigured = hasEnv('SLACK_BOT_TOKEN') || hasEnv('SLACK_USER_TOKEN');
  const wecomConfigured = ['WECOM_CORP_ID', 'WECOM_AGENT_ID', 'WECOM_SECRET', 'WECOM_CALLBACK_TOKEN', 'WECOM_ENCODING_AES_KEY'].every(hasEnv);
  const connections = [
    socialConnection('x', xConfigured, 'X', textOf(process.env.X_ACCOUNT_ID || process.env.X_USER_ID), 'X token configured.', 'Set X_BEARER_TOKEN or an OAuth-backed X access token.'),
    socialConnection('slack', slackConfigured, 'Slack', textOf(process.env.SLACK_TEAM_ID || process.env.SLACK_ACCOUNT_ID), 'Slack token configured.', 'Set SLACK_USER_TOKEN or SLACK_BOT_TOKEN with read scopes.'),
    socialConnection('wecom', wecomConfigured, '企业微信', textOf(process.env.WECOM_CORP_ID), 'WeCom app and callback secrets configured.', 'Set WECOM_CORP_ID, WECOM_AGENT_ID, WECOM_SECRET, WECOM_CALLBACK_TOKEN, and WECOM_ENCODING_AES_KEY.')
  ];
  return source === 'x' ? connections.filter(connection => connection.platform === 'x') : connections;
}

function replaceSocialConnection(connections, replacement) {
  return connections.map(connection => connection.platform === replacement.platform ? replacement : connection);
}

function socialItemMatchesQuery(item, query) {
  const needle = textOf(query).trim().toLowerCase();
  if (needle.length === 0) {
    return true;
  }
  return [item.author, item.handle, item.text, item.channel, item.threadId]
    .map(textOf)
    .some(value => value.toLowerCase().includes(needle));
}

function upsertSocialItems(items) {
  items.forEach(item => {
    const id = textOf(item?.id).trim();
    if (id.length === 0) {
      return;
    }
    const index = socialCache.items.findIndex(cached => cached.id === id);
    if (index >= 0) {
      socialCache.items[index] = item;
      return;
    }
    socialCache.items.push(item);
  });
}

function uniqueSocialItems(items) {
  const seen = new Set();
  return items.filter(item => {
    const id = textOf(item?.id).trim();
    if (id.length === 0 || seen.has(id)) {
      return false;
    }
    seen.add(id);
    return true;
  });
}

async function fetchXRecentSearch(query) {
  const token = textOf(process.env.X_BEARER_TOKEN || process.env.X_ACCESS_TOKEN || process.env.X_OAUTH_TOKEN).trim();
  if (token.length === 0 || textOf(query).trim().length === 0) {
    return { items: [], connection: null };
  }
  const params = new URLSearchParams({
    query: textOf(query).trim(),
    max_results: '10',
    'tweet.fields': 'created_at,author_id,conversation_id',
    expansions: 'author_id',
    'user.fields': 'username,name'
  });
  const response = await fetch(`https://api.x.com/2/tweets/search/recent?${params.toString()}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json'
    }
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`X recent search failed: HTTP ${response.status} ${text.slice(0, 240)}`);
  }
  const payload = JSON.parse(text);
  const users = new Map((Array.isArray(payload.includes?.users) ? payload.includes.users : [])
    .map(user => [textOf(user.id), user]));
  const items = (Array.isArray(payload.data) ? payload.data : []).map(tweet => {
    const user = users.get(textOf(tweet.author_id)) || {};
    const username = textOf(user.username);
    return {
      id: `x-${textOf(tweet.id)}`,
      platform: 'x',
      kind: 'post',
      author: textOf(user.name || username),
      handle: username.length > 0 ? `@${username}` : '',
      text: textOf(tweet.text),
      timestamp: textOf(tweet.created_at),
      url: username.length > 0 && textOf(tweet.id).length > 0 ? `https://x.com/${username}/status/${tweet.id}` : '',
      channel: '',
      threadId: textOf(tweet.conversation_id || tweet.id),
      unread: false
    };
  });
  return { items, connection: null };
}

async function fetchSlackSearch(query) {
  const token = textOf(process.env.SLACK_USER_TOKEN || process.env.SLACK_BOT_TOKEN).trim();
  const searchQuery = slackSearchQuery(query);
  if (token.length === 0 || searchQuery.length === 0) {
    return { items: [], connection: null };
  }
  const params = new URLSearchParams({
    query: searchQuery,
    count: '10'
  });
  const response = await fetch(`https://slack.com/api/search.messages?${params.toString()}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json'
    }
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Slack search.messages failed: HTTP ${response.status} ${text.slice(0, 240)}`);
  }
  const payload = JSON.parse(text);
  if (payload.ok === false) {
    throw new Error(`Slack search.messages failed: ${textOf(payload.error || 'ok:false')}`);
  }
  const matches = Array.isArray(payload.messages?.matches) ? payload.messages.matches : [];
  const items = matches.map(match => {
    const ts = textOf(match.ts || match.iid);
    return {
      id: `slack-${textOf(match.channel?.id || match.channel_name)}-${ts}`.replaceAll(/\s+/g, '_'),
      platform: 'slack',
      kind: 'message',
      author: textOf(match.user_name || match.username || match.user),
      handle: textOf(match.user_name || match.username || match.user),
      text: textOf(match.text),
      timestamp: ts,
      url: textOf(match.permalink),
      channel: textOf(match.channel?.name || match.channel_name),
      threadId: textOf(match.thread_ts || match.previous?.ts || ts),
      unread: false
    };
  });
  return { items, connection: null };
}

function slackSearchQuery(query) {
  const prompt = textOf(query).trim();
  const operator = /\b(?:from|after|before|in):[^\s,，]+/i.exec(prompt);
  if (operator !== null) {
    return operator[0];
  }
  const match = /(?:Slack|slack)\s*(?:搜索|查找|查看|search)?\s*[:：]?\s*(.+)$/i.exec(prompt) ||
    /(?:搜索|查找|查看)\s*(?:Slack|slack)\s*(?:消息)?\s*[:：]?\s*(.+)$/i.exec(prompt);
  return match === null ? prompt : textOf(match[1]).trim();
}

async function socialFeedResponse(url) {
  const source = textOf(url.searchParams.get('source')).trim().toLowerCase();
  const query = url.searchParams.get('q') || '';
  let connections = socialConnections(source);
  const fetchedItems = [];
  if (query.trim().length > 0) {
    if (source === '' || source === 'x') {
      try {
        const items = (await fetchXRecentSearch(query)).items;
        upsertSocialItems(items);
        fetchedItems.push(...items);
      } catch (error) {
        connections = replaceSocialConnection(connections, socialConnectionError('x', describeError(error)));
      }
    }
    if (source === '') {
      try {
        const items = (await fetchSlackSearch(query)).items;
        upsertSocialItems(items);
        fetchedItems.push(...items);
      } catch (error) {
        connections = replaceSocialConnection(connections, socialConnectionError('slack', describeError(error)));
      }
    }
  }
  let items = uniqueSocialItems(socialCache.items.filter(item => socialItemMatchesQuery(item, query)).concat(fetchedItems));
  if (source === 'x') {
    items = items.filter(item => item.platform === 'x' && item.kind === 'post');
  }
  return {
    items,
    connections
  };
}

function findSocialItem(itemId) {
  return socialCache.items.find(item => item.id === itemId) || null;
}

function normalizeSocialPlatform(value) {
  const platform = textOf(value).trim().toLowerCase();
  if (platform === 'x' || platform === 'twitter') {
    return 'x';
  }
  if (platform === 'slack') {
    return 'slack';
  }
  if (platform === 'wecom' || platform === 'wework' || platform === '企业微信') {
    return 'wecom';
  }
  return 'unknown';
}

function socialDraftResponse(body) {
  const itemId = textOf(body.itemId).trim();
  const platform = normalizeSocialPlatform(body.platform);
  if (itemId.length === 0) {
    return {
      draft: {
        itemId: '',
        platform,
        text: '',
        status: 'error',
        error: 'itemId is required to create a local SocialHub draft.',
        localOnly: true,
        sent: false
      }
    };
  }
  const item = findSocialItem(itemId);
  if (!item || (platform !== 'unknown' && item.platform !== platform)) {
    return {
      draft: {
        itemId,
        platform,
        text: '',
        status: 'error',
        error: `SocialHub item not found for local draft: ${itemId}`,
        localOnly: true,
        sent: false
      }
    };
  }
  return {
    draft: {
      itemId,
      platform: item.platform,
      text: textOf(body.instruction).trim(),
      status: 'draft',
      error: '',
      localOnly: true,
      sent: false
    }
  };
}

function isWecomCallbackAuthorized(req, url) {
  if (!isGatewayAuthorized(req)) {
    return false;
  }
  const callbackToken = textOf(process.env.WECOM_CALLBACK_TOKEN).trim();
  if (callbackToken.length === 0) {
    return true;
  }
  const suppliedToken = textOf(url.searchParams.get('token') || req.headers['x-wecom-token']).trim();
  return suppliedToken === callbackToken;
}

function wecomCallbackItem(raw) {
  const text = textOf(raw).trim();
  if (text.length === 0) {
    return null;
  }
  return {
    id: `wecom-${Date.now()}`,
    platform: 'wecom',
    kind: 'message',
    author: '',
    handle: '',
    text,
    timestamp: nowIso(),
    url: '',
    channel: '',
    threadId: '',
    unread: true
  };
}

function normalizeToolId(name) {
  const value = textOf(name).trim().toLowerCase().replaceAll('_', '.');
  if (value === 'travel.search' || value.includes('travel') || value.includes('出行方案') || value.includes('搜索出行') || value.includes('综合出行')) {
    return 'travel.search';
  }
  if (value.includes('flight') || value.includes('航班') || value.includes('机票') || value.includes('飞机')) {
    return 'flight.search';
  }
  if (value.includes('train') || value.includes('12306') || value.includes('火车') || value.includes('高铁') || value.includes('动车')) {
    return 'train.search';
  }
  if (value.includes('food') || value.includes('meal') || value.includes('order') || value.includes('外卖') || value.includes('点餐')) {
    return 'food.search';
  }
  return '';
}

function cardKind(card) {
  if (card.kind) {
    return card.kind;
  }
  const type = card.type;
  const toolId = textOf(card.toolId || card.toolName);
  if (type === 'choice_list') {
    return toolId.length > 0 ? 'tool_result' : 'choice';
  }
  if (type === 'tool_required') {
    return 'error';
  }
  if (type === 'draft_order') {
    return 'draft';
  }
  if ((type === 'info' || !type) && toolId.length > 0) {
    return 'tool_result';
  }
  return type || 'info';
}

function actionId(label, index) {
  const normalized = textOf(label)
    .trim()
    .toLowerCase()
    .replaceAll(/\s+/g, '_')
    .replaceAll(/[^\w.-]/g, '');
  return normalized.length > 0 ? normalized : `action_${index}`;
}

function normalizeAction(action, index) {
  if (typeof action === 'string') {
    return {
      id: actionId(action, index),
      label: action,
      prompt: action,
      variant: index === 0 ? 'primary' : 'secondary',
      kind: 'prompt'
    };
  }
  return {
    id: textOf(action?.id || actionId(action?.label, index)),
    label: textOf(action?.label || '继续'),
    prompt: textOf(action?.prompt || action?.label || '继续'),
    variant: ['primary', 'secondary', 'danger'].includes(action?.variant) ? action.variant : 'secondary',
    kind: ['prompt', 'client', 'input'].includes(action?.kind) ? action.kind : 'prompt'
  };
}

function cardRawItems(card) {
  if (Array.isArray(card.items) && card.items.length > 0) {
    return card.items;
  }
  if (Array.isArray(card.bullets) && card.bullets.length > 0) {
    return card.bullets;
  }
  return [];
}

function normalizeCard(card, index) {
  const kind = cardKind(card);
  const toolId = textOf(card.toolId || card.toolName);
  const status = textOf(card.status || (kind === 'tool_result' ? 'success' : (kind === 'error' ? 'error' : 'idle')));
  const rawItems = cardRawItems(card);
  return {
    id: textOf(card.id || `card_${index}`),
    kind,
    title: textOf(card.title || 'AIPhone'),
    body: textOf(card.body || ''),
    toolId,
    status,
    rows: Array.isArray(card.rows) ? card.rows.map(row => ({
      label: textOf(row?.label || ''),
      value: textOf(row?.value || '')
    })) : [],
    rawItems,
    bullets: rawItems.map(item => (typeof item === 'object' && item !== null ? trainItemText(item) : textOf(item))),
    actions: Array.isArray(card.actions) ? card.actions.map(normalizeAction) : []
  };
}

function safeId(value) {
  return textOf(value)
    .trim()
    .toLowerCase()
    .replaceAll(/\s+/g, '_')
    .replaceAll(/[^\w.-]/g, '')
    .slice(0, 60);
}

function surfaceIdForTool(toolName) {
  if (toolName === 'travel.search') {
    return 'surface_travel';
  }
  if (toolName === 'train.search') {
    return 'surface_train';
  }
  if (toolName === 'flight.search') {
    return 'surface_flight';
  }
  if (toolName === 'food.search') {
    return 'surface_food';
  }
  return 'surface_tool';
}

function intentForTool(toolName) {
  if (toolName === 'food.search') {
    return 'food';
  }
  if (toolName === 'travel.search' || toolName === 'train.search' || toolName === 'flight.search') {
    return 'travel';
  }
  return 'general';
}

function componentForTool(toolName, card) {
  if (card.status === 'error' || card.kind === 'error' || card.kind === 'tool_required') {
    return 'ErrorNotice';
  }
  if (toolName === 'train.search') {
    return 'TrainOptions';
  }
  if (toolName === 'travel.search') {
    return 'TravelOptions';
  }
  if (toolName === 'flight.search') {
    return 'FlightBoard';
  }
  if (toolName === 'food.search') {
    return 'FoodChoices';
  }
  return 'InfoRows';
}

function normalizeRowsForInfo(items) {
  return items.map((item, index) => ({
    label: index === 0 ? '状态' : `信息 ${index + 1}`,
    value: item
  }));
}

function parseTrainItem(item) {
  const text = textOf(item);
  const parts = text.split(/\s+/);
  const route = parts[1] || '';
  const times = parts[2] || '';
  const routeParts = route.split('-');
  const timeParts = times.split('-');
  const seatsIndex = text.indexOf(parts.slice(4).join(' '));
  return {
    trainCode: parts[0] || text.slice(0, 16),
    from: routeParts[0] || '',
    to: routeParts[1] || '',
    depart: timeParts[0] || '',
    arrive: timeParts[1] || '',
    duration: parts[3] || '',
    seats: seatsIndex > 0 ? text.slice(seatsIndex) : parts.slice(4).join(' '),
    status: '可查询',
    business: '',
    first: '',
    second: '',
    noSeat: '',
    hardSeat: '',
    sleeperSoft: ''
  };
}

function parseFlightItem(item) {
  const text = textOf(item);
  const routeMatch = text.match(/\b([A-Z]{2,4})\s*->\s*([A-Z]{2,4})\b/);
  const flightMatch = text.match(/\b[A-Z0-9]{2,3}\d{1,4}\b/);
  const statusMatch = text.match(/状态\s+([^\s]+)/);
  const timeMatch = text.match(/(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+-\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/);
  const airline = flightMatch ? text.slice(0, text.indexOf(flightMatch[0])).trim() : '';
  return {
    flightNo: flightMatch ? flightMatch[0] : text.slice(0, 16),
    airline,
    dep: routeMatch ? routeMatch[1] : '',
    arr: routeMatch ? routeMatch[2] : '',
    depTime: timeMatch ? timeMatch[1] : '',
    arrTime: timeMatch ? timeMatch[2] : '',
    status: statusMatch ? statusMatch[1] : '计划',
    price: ''
  };
}

function parseFoodItem(item) {
  const text = textOf(item);
  const distanceMatch = text.match(/(\d+米)$/);
  const distance = distanceMatch ? distanceMatch[1] : '';
  const clean = distance.length > 0 ? text.slice(0, text.length - distance.length).trim() : text;
  const firstSpace = clean.indexOf(' ');
  const name = firstSpace > 0 ? clean.slice(0, firstSpace) : clean;
  const rest = firstSpace > 0 ? clean.slice(firstSpace + 1).trim() : '';
  const secondSpace = rest.indexOf(' ');
  return {
    name,
    category: secondSpace > 0 ? rest.slice(0, secondSpace) : '',
    address: secondSpace > 0 ? rest.slice(secondSpace + 1) : rest,
    distance,
    sourceTags: ['高德']
  };
}

function dataForCard(toolName, card) {
  if (card.rows.length > 0) {
    return card.rows;
  }
  if (toolName === 'train.search') {
    const sourceItems = Array.isArray(card.rawItems) && card.rawItems.length > 0 ? card.rawItems : card.bullets;
    return sourceItems.map(item => {
      if (typeof item === 'object' && item !== null && textOf(item.trainCode).length > 0) {
        return trainRecordForA2ui(item);
      }
      return parseTrainItem(item);
    });
  }
  if (toolName === 'flight.search') {
    return card.bullets.map(parseFlightItem);
  }
  if (toolName === 'food.search') {
    const sourceItems = Array.isArray(card.rawItems) && card.rawItems.length > 0 ? card.rawItems : card.bullets;
    return sourceItems.map(item => {
      if (typeof item === 'object' && item !== null && textOf(item.name).length > 0) {
        return {
          name: textOf(item.name),
          category: textOf(item.category || item.type),
          address: textOf(item.address),
          distance: textOf(item.distance),
          sourceTags: Array.isArray(item.sourceTags) ? item.sourceTags.map(textOf).filter(tag => tag.length > 0) : ['高德']
        };
      }
      return parseFoodItem(item);
    });
  }
  return normalizeRowsForInfo(card.bullets);
}

function dataPathForTool(toolName) {
  if (toolName === 'travel.search') {
    return '/travelOptions';
  }
  if (toolName === 'train.search') {
    return '/trains';
  }
  if (toolName === 'flight.search') {
    return '/flights';
  }
  if (toolName === 'food.search') {
    return '/foods';
  }
  return '/rows';
}

function dataLabelForTool(toolName) {
  if (toolName === 'travel.search') {
    return 'travelOptions';
  }
  if (toolName === 'train.search') {
    return 'trains';
  }
  if (toolName === 'flight.search') {
    return 'flights';
  }
  if (toolName === 'food.search') {
    return 'foods';
  }
  return 'rows';
}

function pendingA2ui(toolName, prompt) {
  const surfaceId = surfaceIdForTool(toolName);
  const title = TOOL_DEFS[toolName]?.title || '工具调用';
  const message = toolName === 'travel.search'
    ? '正在同时等待 12306 和飞常准返回'
    : toolName === 'train.search'
    ? '正在等待 12306 返回'
    : (toolName === 'flight.search' ? '正在等待飞常准返回' : (toolName === 'food.search' ? '正在等待外卖聚合来源返回' : '正在调用工具'));
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId,
        root: 'root',
        title,
        intent: intentForTool(toolName),
        status: 'calling_tool',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'thinking',
            title,
            body: textOf(prompt).slice(0, 120),
            status: 'calling_tool'
          },
          {
            id: 'thinking',
            component: 'ThinkingStream',
            title: 'AIPhone 正在处理',
            body: message,
            status: 'calling_tool',
            dataPath: '/thoughts',
            actions: []
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId,
        path: '/thoughts',
        value: [
          '正在识别请求约束',
          message,
          '正在校验返回结构'
        ]
      }
    }
  ]);
}

function toolExceptionResponse(toolName, error) {
  const message = error instanceof Error ? error.message : String(error);
  return generated(
    '工具调用过程中出现异常。',
    [
      {
        type: 'tool_required',
        title: '工具调用异常',
        body: message.slice(0, 700),
        toolName,
        items: [
          '后端网关已收到请求，但供应商调用或流式写入中断。',
          '请检查供应商网络、Key、配额，或查看 gateway stderr。'
        ],
        actions: ['重新查询', '检查网关日志']
      }
    ]
  );
}

function parseJsonlEnvelopes(text) {
  const envelopes = [];
  const errors = [];
  text.split(/\r?\n/).forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return;
    }
    try {
      envelopes.push(JSON.parse(trimmed));
    } catch (error) {
      errors.push(`line ${index + 1}: ${error instanceof Error ? error.message : String(error)}`);
    }
  });
  return { envelopes, errors };
}

function snapshotFromA2ui(raw) {
  const parsed = parseJsonlEnvelopes(raw);
  const snapshot = {
    title: '',
    summary: '',
    error: parsed.errors.join('; '),
    trains: [],
    flights: [],
    rows: []
  };
  parsed.envelopes.forEach(envelope => {
    if (envelope.createSurface) {
      snapshot.title = textOf(envelope.createSurface.title) || snapshot.title;
    }
    if (envelope.updateComponents && Array.isArray(envelope.updateComponents.components)) {
      envelope.updateComponents.components.forEach(component => {
        if (component.component === 'ErrorNotice') {
          snapshot.error = `${textOf(component.title)} ${textOf(component.body)}`.trim();
        }
      });
    }
    if (envelope.updateDataModel) {
      const update = envelope.updateDataModel;
      if (update.path === '/trains' && Array.isArray(update.value)) {
        snapshot.trains = update.value;
      } else if (update.path === '/flights' && Array.isArray(update.value)) {
        snapshot.flights = update.value;
      } else if (update.path === '/rows' && Array.isArray(update.value)) {
        snapshot.rows = update.value;
      } else if (update.path === '/summary' && update.value && typeof update.value === 'object') {
        snapshot.summary = textOf(update.value.text);
      }
    }
  });
  return snapshot;
}

function compactTime(value) {
  const text = textOf(value).trim();
  const match = text.match(/(\d{1,2}):(\d{2})/);
  if (match) {
    return `${String(Number.parseInt(match[1], 10)).padStart(2, '0')}:${match[2]}`;
  }
  return text;
}

function parseTravelDurationMinutes(duration) {
  const text = textOf(duration).trim();
  const colon = text.match(/^(\d{1,2}):(\d{2})$/);
  if (colon) {
    return Number.parseInt(colon[1], 10) * 60 + Number.parseInt(colon[2], 10);
  }
  let hours = 0;
  let minutes = 0;
  const hourMatch = text.match(/(\d+)\s*小时/);
  const minuteMatch = text.match(/(\d+)\s*分/);
  if (hourMatch) {
    hours = Number.parseInt(hourMatch[1], 10);
  }
  if (minuteMatch) {
    minutes = Number.parseInt(minuteMatch[1], 10);
  }
  return hours > 0 || minutes > 0 ? hours * 60 + minutes : 99999;
}

function durationFromTimes(depart, arrive) {
  const start = Date.parse(textOf(depart));
  const end = Date.parse(textOf(arrive));
  if (Number.isNaN(start) || Number.isNaN(end) || end <= start) {
    return '';
  }
  const minutes = Math.floor((end - start) / 60000);
  if (minutes <= 0 || minutes > 48 * 60) {
    return '';
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return hours > 0 ? `${hours}小时${rest}分` : `${rest}分`;
}

function clockScore(value) {
  const match = textOf(value).match(/(\d{1,2}):(\d{2})/);
  return match ? Number.parseInt(match[1], 10) * 60 + Number.parseInt(match[2], 10) : 9999;
}

function travelSourceSortOrder(source) {
  if (source === 'train') return 0;
  if (source === 'flight') return 1;
  return 2;
}

function sortTravelOptionsByDeparture(options) {
  return options.slice().sort((left, right) => {
    const departDelta = clockScore(left.depart) - clockScore(right.depart);
    if (departDelta !== 0) return departDelta;
    const arriveDelta = clockScore(left.arrive) - clockScore(right.arrive);
    if (arriveDelta !== 0) return arriveDelta;
    return travelSourceSortOrder(left.source) - travelSourceSortOrder(right.source);
  });
}

function trainToTravelOption(item, index) {
  return {
    id: `train-${textOf(item.trainCode) || index}-${textOf(item.depart)}`,
    source: 'train',
    sourceTag: '高铁 · 12306',
    title: textOf(item.trainCode),
    from: textOf(item.from),
    to: textOf(item.to),
    depart: compactTime(item.depart),
    arrive: compactTime(item.arrive),
    duration: textOf(item.duration),
    price: '',
    availability: textOf(item.seats),
    status: textOf(item.status) || '可查',
    detail: ''
  };
}

function flightToTravelOption(item, index) {
  return {
    id: `flight-${textOf(item.flightNo) || index}-${compactTime(item.depTime)}`,
    source: 'flight',
    sourceTag: '飞机 · 飞常准',
    title: textOf(item.flightNo) || textOf(item.airline),
    from: textOf(item.dep),
    to: textOf(item.arr),
    depart: compactTime(item.depTime),
    arrive: compactTime(item.arrTime),
    duration: durationFromTimes(item.depTime, item.arrTime),
    price: textOf(item.price),
    availability: '',
    status: textOf(item.status) || '计划',
    detail: textOf(item.airline)
  };
}

function travelIssueRow(label, snapshot, emptyText) {
  return {
    label,
    value: snapshot.error || snapshot.summary || emptyText
  };
}

function travelResultA2ui(options, rows, prompt) {
  const surfaceId = surfaceIdForTool('travel.search');
  const components = [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: rows.length > 0 ? 'layout' : 'results',
      title: '出行方案查询',
      body: '已查询高铁和航班工具。',
      status: 'ready'
    }
  ];
  if (rows.length > 0) {
    components.push({
      id: 'layout',
      component: 'Column',
      children: ['summary', 'results'],
      status: 'ready'
    });
    components.push({
      id: 'summary',
      component: 'InfoRows',
      title: '来源状态',
      body: '以下只展示真实工具返回；失败来源不会生成占位结果。',
      status: 'ready',
      dataPath: '/rows',
      actions: []
    });
  }
  components.push({
    id: 'results',
    component: 'TravelOptions',
    title: '出行方案查询',
    body: `用户请求：${textOf(prompt).slice(0, 120)}`,
    status: 'ready',
    dataPath: '/travelOptions',
    actions: [
      ...TRAVEL_CLIENT_ACTIONS
    ]
  });

  return a2uiJsonl([
    {
      createSurface: {
        surfaceId,
        root: 'root',
        title: '出行方案查询',
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId,
        components
      }
    },
    {
      updateDataModel: {
        surfaceId,
        path: '/travelOptions',
        value: options
      }
    },
    {
      updateDataModel: {
        surfaceId,
        path: '/rows',
        value: rows
      }
    },
    {
      updateDataModel: {
        surfaceId,
        path: '/summary',
        value: {
          text: `已查询高铁和航班，共 ${options.length} 个可展示方案。`,
          toolName: 'travel.search',
          dataLabel: 'travelOptions',
          count: options.length
        }
      }
    }
  ]);
}

async function callTravelSearch(args) {
  const source = joinedArgs(args);
  const trainPrompt = /高铁|动车|\bG\d+|\bD\d+/i.test(source) ? source : `${source} 高铁`;
  const flightPrompt = /航班|机票|飞机/.test(source) ? source : `${source} 航班`;
  const [trainRaw, flightRaw] = await Promise.all([
    call12306TrainSearch({ ...args, prompt: trainPrompt }),
    callVariFlightSearch({ ...args, prompt: flightPrompt })
  ]);
  const trainSnapshot = snapshotFromA2ui(trainRaw);
  const flightSnapshot = snapshotFromA2ui(flightRaw);
  let options = [
    ...trainSnapshot.trains.map(trainToTravelOption),
    ...flightSnapshot.flights.map(flightToTravelOption)
  ];
  options = sortTravelOptionsByDeparture(options);

  const rows = [];
  if (trainSnapshot.error || trainSnapshot.trains.length === 0) {
    rows.push(travelIssueRow('高铁 · 12306', trainSnapshot, '12306 没有返回可展示车次。'));
  }
  if (flightSnapshot.error || flightSnapshot.flights.length === 0) {
    rows.push(travelIssueRow('飞机 · 飞常准', flightSnapshot, '飞常准没有返回可展示航班。'));
  }
  if (options.length === 0) {
    return generated(
      '高铁和航班工具都没有返回可展示结果。为避免编造行程，当前只展示真实错误或空结果说明。',
      [
        {
          type: 'tool_required',
          title: '出行方案查询失败',
          body: '高铁和航班工具都没有返回可展示结果。',
          toolName: 'travel.search',
          rows,
          items: rows.map(row => `${row.label}：${row.value}`),
          actions: ['换日期或城市', '只查高铁', '只查飞机']
        }
      ]
    );
  }
  return travelResultA2ui(options, rows, args.prompt || source);
}

function generated(text, cards) {
  const normalizedCards = cards.map(normalizeCard);
  const first = normalizedCards[0] || {
    id: 'info',
    kind: 'info',
    title: 'AIPhone',
    body: text,
    toolId: '',
    status: 'ready',
    rows: [],
    bullets: [],
    actions: []
  };
  const toolName = first.toolId || '';
  const surfaceId = surfaceIdForTool(toolName);
  const componentId = safeId(first.id || first.title || 'result') || 'result';
  const sceneComponent = componentForTool(toolName, first);
  const dataPath = dataPathForTool(toolName);
  const dataLabel = dataLabelForTool(toolName);
  const isErrorSurface = first.status === 'error' || first.kind === 'error' || first.kind === 'tool_required';
  const status = isErrorSurface ? 'needs_input' : 'ready';
  const data = dataForCard(toolName, first);
  const components = [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: componentId,
      title: first.title || 'AIPhone',
      body: text,
      status
    },
    {
      id: componentId,
      component: sceneComponent,
      title: first.title || 'AIPhone',
      body: first.body || text,
      status,
      dataPath,
      actions: first.actions
    }
  ];

  const envelopes = [
    {
      createSurface: {
        surfaceId,
        root: 'root',
        title: first.title || 'AIPhone',
        intent: intentForTool(toolName),
        status,
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId,
        components
      }
    },
  ];

  if (Array.isArray(data) && status !== 'needs_input') {
    if (data.length === 0) {
      envelopes.push({
        updateDataModel: {
          surfaceId,
          path: dataPath,
          value: []
        }
      });
    } else {
      data.forEach((_item, index) => {
        envelopes.push({
          updateDataModel: {
            surfaceId,
            path: dataPath,
            value: data.slice(0, index + 1)
          }
        });
      });
    }
  } else {
    envelopes.push({
      updateDataModel: {
        surfaceId,
        path: dataPath,
        value: data
      }
    });
  }

  envelopes.push({
    updateDataModel: {
      surfaceId,
      path: '/summary',
      value: {
        text,
        toolName,
        dataLabel,
        count: Array.isArray(data) ? data.length : 0
      }
    }
  });
  return a2uiJsonl(envelopes);
}

function requestItems(body) {
  const items = [];
  if (Array.isArray(body.rows)) {
    body.rows.forEach(row => {
      const label = textOf(row?.label);
      const value = textOf(row?.value);
      if (label.length > 0 || value.length > 0) {
        items.push(`${label} ${value}`.trim());
      }
    });
  }
  if (Array.isArray(body.bullets)) {
    body.bullets.forEach(item => {
      const text = textOf(item);
      if (text.length > 0) {
        items.push(text);
      }
    });
  }
  if (Array.isArray(body.items)) {
    body.items.forEach(item => {
      const text = textOf(item);
      if (text.length > 0) {
        items.push(text);
      }
    });
  }
  return items;
}

function addDays(date, days) {
  const next = new Date(date.getTime());
  next.setDate(next.getDate() + days);
  return next;
}

function formatDate(date) {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function parseTravelDate(source) {
  const text = textOf(source);
  const now = new Date();
  if (/后天/.test(text)) {
    return formatDate(addDays(now, 2));
  }
  if (/明天|明日/.test(text)) {
    return formatDate(addDays(now, 1));
  }
  if (/今天|今日/.test(text)) {
    return formatDate(now);
  }

  const iso = text.match(/20\d{2}[-/年](\d{1,2})[-/月](\d{1,2})/);
  if (iso) {
    return `${iso[0].slice(0, 4)}-${iso[1].padStart(2, '0')}-${iso[2].padStart(2, '0')}`;
  }

  const monthDay = text.match(/(\d{1,2})\s*(?:月|-|\/)\s*(\d{1,2})\s*(?:日|号)?/);
  if (monthDay) {
    return `${now.getFullYear()}-${monthDay[1].padStart(2, '0')}-${monthDay[2].padStart(2, '0')}`;
  }

  return '';
}

function joinedArgs(args) {
  return `${textOf(args.prompt)} ${JSON.stringify(args.items || [])} ${JSON.stringify(args.arguments || {})}`;
}

function parseChineseNumberToken(token) {
  const raw = textOf(token).trim();
  if (/^\d+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  const map = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9, '十': 10
  };
  if (raw.length === 1 && map[raw] !== undefined) {
    return map[raw];
  }
  if (raw.startsWith('十') && raw.length === 2 && map[raw.slice(1)] !== undefined) {
    return 10 + map[raw.slice(1)];
  }
  if (raw.endsWith('十') && raw.length === 2 && map[raw.slice(0, 1)] !== undefined) {
    return map[raw.slice(0, 1)] * 10;
  }
  const tens = raw.match(/^([一二三四五六七八九])十([一二三四五六七八九])?$/);
  if (tens) {
    return (map[tens[1]] || 0) * 10 + (tens[2] ? map[tens[2]] : 0);
  }
  return -1;
}

function parseDepartAfter(source) {
  const text = textOf(source);
  const colon = text.match(/(\d{1,2})\s*[:：]\s*(\d{2})\s*(?:之)?(?:后|以后|之后|起)?/);
  if (colon) {
    const hour = Number.parseInt(colon[1], 10);
    const minute = Number.parseInt(colon[2], 10);
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    }
  }
  const point = text.match(/(凌晨|早上|上午|中午|下午|傍晚|晚上|夜间)?\s*([零一二三四五六七八九十两\d]{1,4})\s*点(?:\s*([零一二三四五六七八九十\d]{1,2})\s*分)?(?:\s*(?:之)?(?:后|以后|之后|起))?/);
  if (point) {
    let hour = parseChineseNumberToken(point[2]);
    const minute = point[3] ? parseChineseNumberToken(point[3]) : 0;
    if (hour < 0) {
      return '';
    }
    const period = point[1] || '';
    if ((period === '下午' || period === '晚上' || period === '傍晚') && hour >= 1 && hour <= 11) {
      hour += 12;
    }
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    }
  }
  return '';
}

function filterTrainsByDepartAfter(trains, afterTime) {
  if (!afterTime) {
    return trains;
  }
  return trains.filter(item => {
    const depart = textOf(item.depart);
    if (depart.length < 4) {
      return true;
    }
    const hhmm = depart.length >= 5 ? depart.slice(0, 5) : depart;
    return hhmm >= afterTime;
  });
}

function formatTrainSeatsSummary(item) {
  const seats = [];
  if (item.business) {
    seats.push(`商务 ${item.business}`);
  }
  if (item.first) {
    seats.push(`一等 ${item.first}`);
  }
  if (item.second) {
    seats.push(`二等 ${item.second}`);
  }
  if (item.sleeperSoft) {
    seats.push(`卧铺 ${item.sleeperSoft}`);
  }
  if (item.hardSeat) {
    seats.push(`硬座 ${item.hardSeat}`);
  }
  if (item.noSeat) {
    seats.push(`无座 ${item.noSeat}`);
  }
  return seats.join(' / ');
}

function trainRecordForA2ui(item) {
  return {
    trainCode: textOf(item.trainCode),
    from: textOf(item.from),
    to: textOf(item.to),
    depart: textOf(item.depart),
    arrive: textOf(item.arrive),
    duration: textOf(item.duration),
    seats: textOf(item.seats).length > 0 ? textOf(item.seats) : formatTrainSeatsSummary(item),
    status: textOf(item.status).length > 0 ? textOf(item.status) : '计划',
    business: textOf(item.business),
    first: textOf(item.first),
    second: textOf(item.second),
    noSeat: textOf(item.noSeat),
    hardSeat: textOf(item.hardSeat),
    sleeperSoft: textOf(item.sleeperSoft)
  };
}

function extractRouteNames(source, candidates) {
  const text = textOf(source);

  const departRoute = text.match(/(?:从)?([\u4e00-\u9fa5]{2,12})\s*出发\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})/);
  if (departRoute) {
    const fromCandidate = findCandidateInRoutePart(departRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(departRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const stationRoute = text.match(/([\u4e00-\u9fa5]{2,12})站\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})站/);
  if (stationRoute) {
    const fromCandidate = findCandidateInRoutePart(stationRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(stationRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const direct = text.match(/([\u4e00-\u9fa5]{2,12})\s*(?:到|去|至|飞)\s*([\u4e00-\u9fa5]{2,12})/);
  if (direct) {
    const fromCandidate = findCandidateInRoutePart(direct[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(direct[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const matched = [];
  candidates.forEach(name => {
    if (text.includes(name) && !matched.includes(name)) {
      matched.push(name);
    }
  });
  return matched.slice(0, 2);
}

function findCandidateInRoutePart(part, candidates, preferLast) {
  const matched = candidates
    .filter(name => part.includes(name))
    .map(name => ({
      name,
      index: part.indexOf(name)
    }));

  if (matched.length === 0) {
    return '';
  }

  matched.sort((a, b) => {
    if (preferLast && a.index !== b.index) {
      return b.index - a.index;
    }
    if (!preferLast && a.index !== b.index) {
      return a.index - b.index;
    }
    return b.name.length - a.name.length;
  });
  return matched[0].name;
}

function normalizeTrainStationName(name, source) {
  if (/高铁|动车|\bG\d+|\bD\d+/.test(source) && HIGH_SPEED_DEFAULT_STATIONS[name]) {
    return HIGH_SPEED_DEFAULT_STATIONS[name];
  }
  return name;
}

async function load12306Stations() {
  if (stationCache !== null) {
    return stationCache;
  }

  const response = await fetch('https://kyfw.12306.cn/otn/resources/js/framework/station_name.js', {
    headers: {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
    }
  });
  const text = await response.text();
  const byName = {};
  const byCode = {};
  const names = [];
  text.split('@').forEach(part => {
    const fields = part.split('|');
    if (fields.length >= 3 && fields[1] && fields[2]) {
      byName[fields[1]] = fields[2];
      byCode[fields[2]] = fields[1];
      names.push(fields[1]);
    }
  });
  names.sort((a, b) => b.length - a.length);
  stationCache = {
    byName,
    byCode,
    names
  };
  return stationCache;
}

function parse12306Row(row, stationMap) {
  const fields = row.split('|');
  const trainCode = fields[3] || '';
  return {
    trainCode,
    from: stationMap[fields[6]] || fields[6] || '',
    to: stationMap[fields[7]] || fields[7] || '',
    depart: fields[8] || '',
    arrive: fields[9] || '',
    duration: fields[10] || '',
    status: fields[1] || fields[11] || '',
    business: fields[32] || '',
    first: fields[31] || '',
    second: fields[30] || '',
    sleeperSoft: fields[23] || fields[28] || '',
    hardSeat: fields[29] || '',
    noSeat: fields[26] || ''
  };
}

function trainItemText(item) {
  const seats = [];
  if (item.business) {
    seats.push(`商务 ${item.business}`);
  }
  if (item.first) {
    seats.push(`一等 ${item.first}`);
  }
  if (item.second) {
    seats.push(`二等 ${item.second}`);
  }
  if (item.sleeperSoft) {
    seats.push(`卧铺 ${item.sleeperSoft}`);
  }
  if (item.hardSeat) {
    seats.push(`硬座 ${item.hardSeat}`);
  }
  if (item.noSeat) {
    seats.push(`无座 ${item.noSeat}`);
  }
  return `${item.trainCode} ${item.from}-${item.to} ${item.depart}-${item.arrive} ${item.duration} ${seats.join(' / ')}`.trim();
}

async function call12306TrainSearch(args) {
  const source = joinedArgs(args);
  const stations = await load12306Stations();
  const routeNames = extractRouteNames(source, stations.names);
  const date = parseTravelDate(source);
  const departAfter = parseDepartAfter(source);

  if (routeNames.length < 2 || date.length === 0) {
    return generated(
      '火车票查询需要补充出发地、目的地和日期。',
      [
        {
          type: 'tool_required',
          title: '12306 查询参数不足',
          body: '我可以直接查 12306 余票，但需要明确的出发地、目的地和日期。',
          toolName: 'train.search',
          items: ['示例：明天北京到上海高铁票', '示例：2026-06-10 北京南到上海虹桥'],
          actions: ['补充日期', '补充城市']
        }
      ]
    );
  }

  const fromName = normalizeTrainStationName(routeNames[0], source);
  const toName = normalizeTrainStationName(routeNames[1], source);
  const fromCode = stations.byName[fromName] || stations.byName[routeNames[0]];
  const toCode = stations.byName[toName] || stations.byName[routeNames[1]];

  if (!fromCode || !toCode) {
    return generated(
      '没有识别到 12306 车站代码。',
      [
        {
          type: 'tool_required',
          title: '车站识别失败',
          body: '请使用更完整的车站名，例如北京南、上海虹桥、广州南、深圳北。',
          toolName: 'train.search',
          items: routeNames,
          actions: ['补充车站名']
        }
      ]
    );
  }

  const cookieResponse = await fetch('https://kyfw.12306.cn/otn/leftTicket/init', {
    headers: {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
    }
  });
  const cookies = cookieResponse.headers.getSetCookie ? cookieResponse.headers.getSetCookie() : [];
  const cookieHeader = cookies.map(cookie => cookie.split(';')[0]).join('; ');
  const url = new URL('https://kyfw.12306.cn/otn/leftTicket/queryG');
  url.searchParams.set('leftTicketDTO.train_date', date);
  url.searchParams.set('leftTicketDTO.from_station', fromCode);
  url.searchParams.set('leftTicketDTO.to_station', toCode);
  url.searchParams.set('purpose_codes', 'ADULT');

  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init',
      'Cookie': cookieHeader
    }
  });
  const payload = await response.json();
  const rows = Array.isArray(payload?.data?.result) ? payload.data.result : [];
  const parsed = rows.map(row => parse12306Row(row, payload.data.map || {}));
  let filtered = /高铁|动车|\bG\d+|\bD\d+/.test(source) ? parsed.filter(item => /^G|^D/.test(item.trainCode)) : parsed;
  if (departAfter.length > 0) {
    filtered = filterTrainsByDepartAfter(filtered, departAfter);
  }
  const top = filtered.slice(0, TRAIN_RESULT_LIMIT);
  const timeSummary = departAfter.length > 0 ? `${departAfter} 后` : '';

  if (top.length === 0) {
    const emptyBody = timeSummary.length > 0
      ? `${date} ${fromName} 到 ${toName} ${timeSummary}暂时没有查询到可展示车次，可尝试调整时段或日期。`
      : `${date} ${fromName} 到 ${toName} 暂时没有查询到可展示车次，可能是日期未开售、线路调整或接口限制。`;
    return generated(
      '12306 暂无可展示车次。',
      [
        {
          type: 'info',
          title: '12306 查询结果为空',
          body: emptyBody,
          toolName: 'train.search',
          items: [],
          actions: TRAIN_CLIENT_ACTIONS
        }
      ]
    );
  }

  const summaryText = timeSummary.length > 0
    ? `已从 12306 查询到 ${date} ${fromName} 到 ${toName} ${timeSummary}的车次。`
    : `已从 12306 查询到 ${date} ${fromName} 到 ${toName} 的车次。`;
  const resultBody = timeSummary.length > 0
    ? `以下为 ${timeSummary}出发的 12306 实时查询结果，默认先展示 ${TRAIN_INITIAL_VISIBLE} 趟。`
    : `以下为 12306 实时查询结果摘要，默认先展示 ${TRAIN_INITIAL_VISIBLE} 趟。`;

  return generated(
    summaryText,
    [
      {
        type: 'choice_list',
        title: '12306 余票查询',
        body: resultBody,
        toolName: 'train.search',
        items: top.map(trainRecordForA2ui),
        actions: TRAIN_CLIENT_ACTIONS
      }
    ]
  );
}

function extractFlightCityCodes(source) {
  const names = Object.keys(CHINA_FLIGHT_CITY_CODES).sort((a, b) => b.length - a.length);
  const routeNames = extractRouteNames(source, names);
  if (routeNames.length < 2) {
    return {
      routeNames,
      depCode: '',
      arrCode: ''
    };
  }
  return {
    routeNames,
    depCode: CHINA_FLIGHT_CITY_CODES[routeNames[0]] || '',
    arrCode: CHINA_FLIGHT_CITY_CODES[routeNames[1]] || ''
  };
}

function extractFlightNumber(source) {
  const match = textOf(source).toUpperCase().match(/\b[A-Z0-9]{2,3}\d{1,4}\b/);
  return match ? match[0] : '';
}

function findFirstArray(value, depth = 0) {
  if (depth > 5 || value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  if (typeof value !== 'object') {
    return [];
  }

  const preferredKeys = ['data', 'flights', 'flightList', 'list', 'items', 'records', 'result', 'results'];
  for (const key of preferredKeys) {
    if (Object.prototype.hasOwnProperty.call(value, key)) {
      const found = findFirstArray(value[key], depth + 1);
      if (found.length > 0) {
        return found;
      }
    }
  }

  for (const item of Object.values(value)) {
    const found = findFirstArray(item, depth + 1);
    if (found.length > 0) {
      return found;
    }
  }
  return [];
}

function pickField(source, names) {
  if (source === undefined || source === null || typeof source !== 'object') {
    return '';
  }
  for (const name of names) {
    const value = source[name];
    if (value !== undefined && value !== null && `${value}`.length > 0) {
      return `${value}`;
    }
  }
  return '';
}

function flightItemText(item) {
  if (typeof item === 'string') {
    const trimmed = item.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return flightItemText(JSON.parse(trimmed));
      } catch (_error) {
        return item.slice(0, 240);
      }
    }
    return item.slice(0, 240);
  }
  if (item === undefined || item === null || typeof item !== 'object') {
    return textOf(item).slice(0, 240);
  }

  const flightNo = pickField(item, ['FlightNo', 'flightNo', 'flight_no', 'fnum', 'Fnum', 'flightNumber', 'flight_number', 'flight']);
  const airline = pickField(item, ['FlightCompany', 'airline', 'airlineName', 'AirlineName', 'carrier', 'carrierName']);
  const dep = pickField(item, ['FlightDepcode', 'FlightDepAirport', 'dep', 'depAirport', 'depAirportName', 'dep_city', 'departure', 'departureAirport']);
  const arr = pickField(item, ['FlightArrcode', 'FlightArrAirport', 'arr', 'arrAirport', 'arrAirportName', 'arr_city', 'arrival', 'arrivalAirport']);
  const depTime = pickField(item, ['FlightDeptimePlanDate', 'FlightDeptimeReadyDate', 'FlightDeptimeDate', 'FlightDepTime', 'depTime', 'dep_time', 'departureTime', 'std', 'scheduleDepTime']);
  const arrTime = pickField(item, ['FlightArrtimePlanDate', 'FlightArrtimeReadyDate', 'FlightArrtimeDate', 'FlightArrTime', 'arrTime', 'arr_time', 'arrivalTime', 'sta', 'scheduleArrTime']);
  const status = pickField(item, ['FlightState', 'FlightStatus', 'status', 'flightStatus', 'state']);
  const price = pickField(item, ['price', 'Price', 'lowestPrice', 'LowestPrice', 'fare', 'amount']);

  const parts = [];
  if (flightNo.length > 0 || airline.length > 0) {
    parts.push(`${airline} ${flightNo}`.trim());
  }
  if (dep.length > 0 || arr.length > 0) {
    parts.push(`${dep || '出发地'} -> ${arr || '到达地'}`);
  }
  if (depTime.length > 0 || arrTime.length > 0) {
    parts.push(`${depTime || '--'} - ${arrTime || '--'}`);
  }
  if (status.length > 0) {
    parts.push(`状态 ${status}`);
  }
  if (price.length > 0) {
    parts.push(`参考价 ${price}`);
  }

  if (parts.length > 0) {
    return parts.join(' ');
  }
  return JSON.stringify(item).slice(0, 240);
}

function extractProviderError(payload) {
  if (payload === undefined || payload === null || typeof payload !== 'object') {
    return '';
  }
  const message = pickField(payload, ['error', 'message', 'msg', 'info', 'errmsg']);
  const success = payload.success;
  const status = payload.status;
  if (success === false || status === '0') {
    return message.length > 0 ? message : JSON.stringify(payload).slice(0, 500);
  }
  return '';
}

async function callVariFlightSearch(args) {
  const apiKey = process.env.FLIGHT_MCP_KEY || process.env.VARIFLIGHT_API_KEY || process.env.X_VARIFLIGHT_KEY || process.env.FLIGHT_API_KEY || '';
  if (apiKey.length === 0) {
    return missingConfigResponse('flight.search', args);
  }

  const source = joinedArgs(args);
  const date = parseTravelDate(source);
  const flightNumber = extractFlightNumber(source);
  const flightRoute = extractFlightCityCodes(source);
  const wantsPrice = /票价|价格|多少钱|最低价|机票/.test(source);

  if (date.length === 0 || (flightNumber.length === 0 && (flightRoute.depCode.length === 0 || flightRoute.arrCode.length === 0))) {
    return generated(
      '航班查询需要补充城市和日期。',
      [
        {
          type: 'tool_required',
          title: '飞常准查询参数不足',
          body: '飞常准查询需要明确的日期，并提供航班号，或提供出发城市和到达城市。',
          toolName: 'flight.search',
          items: ['示例：明天北京到上海航班', '示例：2026-06-10 深圳到杭州机票价格', '示例：明天 MU2157 航班'],
          actions: ['补充日期', '补充城市']
        }
      ]
    );
  }

  let endpoint = 'flights';
  let params = {
    depcity: flightRoute.depCode,
    arrcity: flightRoute.arrCode,
    date
  };

  if (flightNumber.length > 0) {
    endpoint = 'flight';
    params = {
      fnum: flightNumber,
      date
    };
  } else if (wantsPrice) {
    endpoint = 'getFlightPriceByCities';
    params = {
      dep_city: flightRoute.depCode,
      arr_city: flightRoute.arrCode,
      dep_date: date,
      price_mode: 'lowest'
    };
  }

  const baseUrl = process.env.VARIFLIGHT_API_URL || process.env.FLIGHT_VARIFLIGHT_URL || 'https://mcp.variflight.com/api/v1/mcp/data';
  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-VARIFLIGHT-KEY': apiKey
    },
    body: JSON.stringify({
      endpoint,
      params
    })
  });

  const rawText = await response.text();
  let payload = rawText;
  try {
    payload = JSON.parse(rawText);
  } catch (_error) {
    payload = rawText;
  }

  if (!response.ok) {
    return generated(
      '飞常准航班查询失败。',
      [
        {
          type: 'tool_required',
          title: `飞常准返回 HTTP ${response.status}`,
          body: rawText.slice(0, 700),
          toolName: 'flight.search',
          items: ['检查 FLIGHT_MCP_KEY 或 VARIFLIGHT_API_KEY', '检查免费调用次数和 Key 状态'],
          actions: ['重新配置飞常准 Key', '打开飞常准控制台']
        }
      ]
    );
  }

  const providerError = extractProviderError(payload);
  if (providerError.length > 0) {
    return generated(
      '飞常准返回了可恢复错误。',
      [
        {
          type: 'tool_required',
          title: '飞常准 Key 或参数需要检查',
          body: providerError,
          toolName: 'flight.search',
          items: [JSON.stringify(params).slice(0, 240)],
          actions: ['检查 Key', '换日期或城市']
        }
      ]
    );
  }

  const results = findFirstArray(payload);
  const items = results.slice(0, 8).map(flightItemText);
  if (items.length === 0) {
    items.push(typeof payload === 'string' ? payload.slice(0, 700) : JSON.stringify(payload).slice(0, 700));
  }

  const routeText = flightNumber.length > 0
    ? `${flightNumber} ${date}`
    : `${flightRoute.routeNames[0]} 到 ${flightRoute.routeNames[1]} ${date}`;

  return generated(
    `已通过飞常准查询到 ${routeText} 的航班信息。`,
    [
      {
        type: 'choice_list',
        title: wantsPrice ? '飞常准航班价格查询' : '飞常准航班查询',
        body: '以下为飞常准查询结果。',
        toolName: 'flight.search',
        items,
        actions: ['换个日期', '换个城市']
      }
    ]
  );
}

function parseCoordinatePair(text) {
  const match = textOf(text).match(/(-?\d{2,3}\.\d+)\s*,\s*(-?\d{1,2}\.\d+)/);
  if (!match) {
    return '';
  }
  return `${match[1]},${match[2]}`;
}

function defaultConfiguredLocation() {
  const configured = process.env.AMAP_DEFAULT_LOCATION || process.env.FOOD_DEFAULT_LOCATION || '';
  return parseCoordinatePair(configured);
}

function extractLocation(source) {
  return parseCoordinatePair(source) || defaultConfiguredLocation();
}

function extractFoodQuery(source) {
  const text = textOf(source).trim();
  const cleaned = text.replace(/^帮我(?:搜索|查|找|搜)?/u, '').trim();
  const nearPatterns = [
    /^(.+?)附近(?:的)?(.+)$/u,
    /^(.+?)周边(?:的)?(.+)$/u,
    /^(.+?)周围(?:的)?(.+)$/u
  ];
  for (const pattern of nearPatterns) {
    const match = cleaned.match(pattern);
    if (match && match[1] && match[2]) {
      return {
        place: match[1].trim(),
        keyword: match[2].trim()
      };
    }
  }
  return { place: '', keyword: '' };
}

function extractFoodKeyword(source) {
  const query = extractFoodQuery(source);
  if (query.keyword.length > 0) {
    return query.keyword;
  }
  const preset = /椰子鸡|椰子|火锅|烧烤|咖啡|奶茶|晚餐|午餐|早餐|快餐|餐厅|饭店|美食/u.exec(textOf(source));
  if (preset) {
    return preset[0];
  }
  return '餐饮';
}

function inferAmapCityFromPlace(place) {
  const match = textOf(place).match(/^(北京|上海|天津|重庆|深圳|广州|杭州|成都|武汉|南京|西安|东莞|佛山)/u);
  return match ? match[1] : '';
}

function isLandmarkPlace(place) {
  return /华为|基地|园区|总部|云谷|大学|医院|站|广场|大厦|小区/u.test(textOf(place));
}

async function geocodeAmapAddressDetail(address, key) {
  const trimmed = textOf(address).trim();
  if (trimmed.length === 0 || key.length === 0) {
    return { location: '', formatted: '', level: '' };
  }
  const url = new URL('https://restapi.amap.com/v3/geocode/geo');
  url.searchParams.set('key', key);
  url.searchParams.set('address', trimmed);
  const city = inferAmapCityFromPlace(trimmed);
  if (city.length > 0) {
    url.searchParams.set('city', city);
  }
  const response = await fetch(url);
  const payload = await response.json();
  if (payload.status !== '1' || !Array.isArray(payload.geocodes) || payload.geocodes.length === 0) {
    return { location: '', formatted: '', level: '' };
  }
  const first = payload.geocodes[0];
  return {
    location: textOf(first.location),
    formatted: textOf(first.formatted_address),
    level: textOf(first.level)
  };
}

async function searchAmapPoiLocation(keywords, city, key) {
  const trimmed = textOf(keywords).trim();
  if (trimmed.length === 0 || key.length === 0) {
    return { location: '', name: '', address: '' };
  }
  const url = new URL('https://restapi.amap.com/v3/place/text');
  url.searchParams.set('key', key);
  url.searchParams.set('keywords', trimmed);
  if (textOf(city).length > 0) {
    url.searchParams.set('city', city);
  }
  url.searchParams.set('offset', '5');
  url.searchParams.set('page', '1');
  const response = await fetch(url);
  const payload = await response.json();
  if (payload.status !== '1' || !Array.isArray(payload.pois) || payload.pois.length === 0) {
    return { location: '', name: '', address: '' };
  }
  const first = payload.pois[0];
  return {
    location: textOf(first.location),
    name: textOf(first.name),
    address: textOf(first.address)
  };
}

async function resolveFoodSearchLocation(place, key) {
  const city = inferAmapCityFromPlace(place) || '深圳';
  if (isLandmarkPlace(place)) {
    const poi = await searchAmapPoiLocation(place, city, key);
    if (poi.location.length > 0) {
      return {
        location: poi.location,
        locationSource: 'poi_text',
        locationLabel: poi.name.length > 0 ? poi.name : poi.address
      };
    }
  }
  const geo = await geocodeAmapAddressDetail(place, key);
  if (geo.location.length > 0) {
    return {
      location: geo.location,
      locationSource: 'geocode',
      locationLabel: geo.formatted.length > 0 ? geo.formatted : geo.level
    };
  }
  const poi = await searchAmapPoiLocation(place, city, key);
  if (poi.location.length > 0) {
    return {
      location: poi.location,
      locationSource: 'poi_text',
      locationLabel: poi.name.length > 0 ? poi.name : poi.address
    };
  }
  return { location: '', locationSource: 'none', locationLabel: '' };
}

function debugFoodSearchLog(payload) {
  // #region agent log
  fetch('http://127.0.0.1:7355/ingest/8ffaedf3-167e-4382-a899-3823430060c5', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': '65c5d6' },
    body: JSON.stringify({
      sessionId: '65c5d6',
      runId: payload.runId || 'pre-fix',
      hypothesisId: payload.hypothesisId || 'C',
      location: 'server.mjs:callAmapFoodSearch',
      message: payload.message || 'food search params',
      data: payload.data || {},
      timestamp: Date.now()
    })
  }).catch(() => {});
  // #endregion
}

async function callAmapFoodSearch(args) {
  const key = process.env.AMAP_KEY || '';
  if (key.length === 0) {
    return missingConfigResponse('food.search', args);
  }

  const promptText = textOf(args.prompt);
  const query = extractFoodQuery(promptText);
  let locationSource = 'none';
  let location = parseCoordinatePair(promptText);
  if (location.length > 0) {
    locationSource = 'prompt_coords';
  } else if (query.place.length > 0) {
    const resolved = await resolveFoodSearchLocation(query.place, key);
    location = resolved.location;
    locationSource = resolved.locationSource;
    debugFoodSearchLog({
      hypothesisId: 'A',
      message: 'food location resolved',
      data: {
        place: query.place,
        locationSource: resolved.locationSource,
        location: resolved.location,
        locationLabel: resolved.locationLabel
      }
    });
  }
  if (location.length === 0) {
    location = defaultConfiguredLocation();
    if (location.length > 0) {
      locationSource = 'env_default';
    }
  }

  const keyword = extractFoodKeyword(promptText);

  debugFoodSearchLog({
    hypothesisId: 'C',
    data: {
      place: query.place,
      keyword,
      locationSource,
      locationPresent: location.length > 0,
      promptChars: promptText.length
    }
  });

  if (location.length === 0) {
    return generated(
      '附近餐饮查询需要位置。',
      [
        {
          type: 'tool_required',
          title: '需要位置或默认坐标',
          body: '高德周边搜索需要经纬度。请在 prompt 中写明「地点附近的餐饮」，或配置 AMAP_DEFAULT_LOCATION=经度,纬度。',
          toolName: 'food.search',
          items: ['需要 AMAP_KEY', '需要地点文本或 AMAP_DEFAULT_LOCATION'],
          actions: ['配置默认坐标', '换查询位置']
        }
      ]
    );
  }

  const url = new URL('https://restapi.amap.com/v3/place/around');
  url.searchParams.set('key', key);
  url.searchParams.set('location', location);
  url.searchParams.set('types', '050000');
  url.searchParams.set('keywords', keyword);
  url.searchParams.set('radius', process.env.AMAP_RADIUS || '3000');
  url.searchParams.set('offset', '10');
  url.searchParams.set('page', '1');
  url.searchParams.set('extensions', 'all');

  const response = await fetch(url);
  const payload = await response.json();
  if (payload.status !== '1') {
    return generated(
      '高德餐饮查询失败。',
      [
        {
          type: 'tool_required',
          title: `高德返回 ${payload.infocode || 'unknown'}`,
          body: payload.info || JSON.stringify(payload).slice(0, 500),
          toolName: 'food.search',
          items: ['检查 AMAP_KEY', '检查坐标和配额'],
          actions: ['重新配置 Key']
        }
      ]
    );
  }

  const seenNames = new Set();
  const pois = Array.isArray(payload.pois)
    ? payload.pois.filter(poi => {
      const name = textOf(poi.name);
      if (name.length === 0 || seenNames.has(name)) {
        return false;
      }
      seenNames.add(name);
      return true;
    }).slice(0, 8)
    : [];

  debugFoodSearchLog({
    hypothesisId: 'A',
    message: 'food poi results',
    data: {
      place: query.place,
      keyword,
      location,
      locationSource,
      radius: process.env.AMAP_RADIUS || '3000',
      poiCount: pois.length,
      poiPreview: pois.map(poi => ({
        name: textOf(poi.name),
        distance: textOf(poi.distance)
      }))
    }
  });

  return generated(
    `已通过高德查询到附近餐饮 POI。`,
    [
      {
        type: 'choice_list',
        title: '附近餐饮选择',
        body: '以下为高德周边餐饮结果。',
        toolName: 'food.search',
        items: pois.map(poi => ({
          name: textOf(poi.name),
          category: textOf(poi.type),
          address: textOf(poi.address),
          distance: poi.distance ? `${poi.distance}米` : '',
          sourceTags: ['高德']
        })),
        actions: ['换关键词', '换位置']
      }
    ]
  );
}

function missingConfigResponse(toolName, args) {
  const def = TOOL_DEFS[toolName];
  const title = def ? def.title : '工具调用';
  const providerHint = def ? def.providerHint : '对应的 MCP/API 供应商';
  const configItems = def && Array.isArray(def.configItems) ? def.configItems : ['对应工具的 API_URL 或 MCP_URL'];
  const items = [
    `需要配置：${configItems.join('；')}`,
    `供应商方向：${providerHint}`
  ];

  if (def && def.requiredArgs.length > 0) {
    items.push(`建议参数：${def.requiredArgs.join(', ')}`);
  }

  return generated(
    `${title}已进入后端网关，但还没有配置真实供应商。`,
    [
      {
        type: 'tool_required',
        title: `${title}需要供应商配置`,
        body: '后端已收到请求。为了避免编造实时班次、价格或地点信息，当前只返回配置要求；填入查询 API/MCP 配置后会改为真实调用。',
        toolName,
        items,
        actions: def ? def.actions : ['补充配置']
      }
    ]
  );
}

function providerConfig(toolName) {
  const def = TOOL_DEFS[toolName];
  const prefix = def.envPrefix;
  return {
    apiUrl: process.env[`${prefix}_API_URL`] || '',
    apiKey: process.env[`${prefix}_API_KEY`] || '',
    apiMethod: process.env[`${prefix}_API_METHOD`] || 'POST',
    authHeader: process.env[`${prefix}_API_AUTH_HEADER`] || 'Authorization',
    authPrefix: process.env[`${prefix}_API_AUTH_PREFIX`] || 'Bearer ',
    mcpUrl: process.env[`${prefix}_MCP_URL`] || '',
    mcpKey: process.env[`${prefix}_MCP_KEY`] || ''
  };
}

async function callGenericApi(toolName, args, config) {
  const headers = {
    'Content-Type': 'application/json'
  };
  if (config.apiKey.length > 0) {
    headers[config.authHeader] = `${config.authPrefix}${config.apiKey}`;
  }

  const response = await fetch(config.apiUrl, {
    method: config.apiMethod,
    headers,
    body: config.apiMethod.toUpperCase() === 'GET' ? undefined : JSON.stringify({
      toolName,
      prompt: args.prompt,
      items: args.items || [],
      arguments: args.arguments || {}
    })
  });
  const text = await response.text();
  if (!response.ok) {
    return generated(
      '供应商 API 调用失败。',
      [
        {
          type: 'tool_required',
          title: `供应商 API 返回 HTTP ${response.status}`,
          body: text.slice(0, 600),
          toolName,
          items: [config.apiUrl],
          actions: ['检查密钥', '检查签名规则']
        }
      ]
    );
  }

  return generated(
    '供应商 API 已返回结果。',
    [
      {
        type: 'info',
        title: `${TOOL_DEFS[toolName].title}结果`,
        body: text.slice(0, 900),
        toolName,
        items: ['原始响应已截断展示；后续可按供应商字段做结构化渲染。'],
        actions: ['结构化解析', '继续查询']
      }
    ]
  );
}

async function callHttpMcp(toolName, args, config) {
  const headers = {
    'Content-Type': 'application/json'
  };
  if (config.mcpKey.length > 0) {
    headers.Authorization = `Bearer ${config.mcpKey}`;
  }

  const response = await fetch(config.mcpUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: `aiphone-${Date.now()}`,
      method: 'tools/call',
      params: {
        name: toolName,
        arguments: {
          prompt: args.prompt,
          items: args.items || [],
          ...(args.arguments || {})
        }
      }
    })
  });
  const text = await response.text();
  if (!response.ok) {
    return generated(
      'MCP 工具调用失败。',
      [
        {
          type: 'tool_required',
          title: `MCP 返回 HTTP ${response.status}`,
          body: text.slice(0, 600),
          toolName,
          items: [config.mcpUrl],
          actions: ['检查 MCP URL', '检查鉴权']
        }
      ]
    );
  }

  return generated(
    'MCP 工具已返回结果。',
    [
      {
        type: 'info',
        title: `${TOOL_DEFS[toolName].title} MCP 结果`,
        body: text.slice(0, 900),
        toolName,
        items: ['原始 MCP 响应已截断展示；后续可按工具 schema 做结构化渲染。'],
        actions: ['结构化解析', '继续查询']
      }
    ]
  );
}

async function callTool(toolName, args) {
  if (!TOOL_DEFS[toolName]) {
    return generated(
      '未知工具。',
      [
        {
          type: 'tool_required',
          title: '未知工具',
          body: '当前网关只支持航班查询、火车票查询和附近餐饮查询。',
          toolName,
          items: [],
          actions: []
        }
      ]
    );
  }

  if (toolName === 'travel.search') {
    return callTravelSearch(args);
  }
  const config = providerConfig(toolName);
  if (config.mcpUrl.length > 0) {
    return callHttpMcp(toolName, args, config);
  }
  if (config.apiUrl.length > 0) {
    return callGenericApi(toolName, args, config);
  }
  if (toolName === 'train.search') {
    return call12306TrainSearch(args);
  }
  if (toolName === 'flight.search') {
    return callVariFlightSearch(args);
  }
  if (toolName === 'food.search' && process.env.AMAP_KEY) {
    return callAmapFoodSearch(args);
  }
  return missingConfigResponse(toolName, args);
}

async function handleAiphoneTool(req, res) {
  const body = await readJson(req);
  const toolName = normalizeToolId(body.toolId);
  const requestedSurfaceId = textOf(body.surfaceId).trim();
  if (toolName.length === 0) {
    writeA2uiHeaders(res, 200);
    await writeA2uiStream(res, rewriteA2uiSurfaceId(generated(
      '工具调用缺少 toolId。',
      [
        {
          type: 'tool_required',
          title: '缺少真实工具 ID',
          body: '工具网关只执行模型或客户端已经明确选择的真实工具；不会根据 prompt 静默生成候选项或占位结果。',
          status: 'needs_input',
          items: [],
          actions: []
        }
      ]
    ), requestedSurfaceId));
    res.end();
    return;
  }

  writeA2uiHeaders(res, 200);
  await writeA2uiStream(res, rewriteA2uiSurfaceId(pendingA2ui(toolName, body.prompt || ''), requestedSurfaceId));
  let result = '';
  try {
    result = await callTool(toolName, {
      prompt: body.prompt || '',
      items: requestItems(body),
      arguments: body.arguments || {}
    });
  } catch (error) {
    console.error('[toolError]', toolName, error);
    result = toolExceptionResponse(toolName, error);
  }
  await writeA2uiStream(res, rewriteA2uiSurfaceId(result, requestedSurfaceId));
  res.end();
}

async function handleMcpCall(req, res) {
  const body = await readJson(req);
  const toolName = normalizeToolId(body.name);
  const result = await callTool(toolName, {
    prompt: body.arguments?.prompt || '',
    items: body.arguments?.items || [],
    arguments: body.arguments || {}
  });
  sendJson(res, 200, {
    content: [
      {
        type: 'text',
        text: result
      }
    ]
  });
}

function handleTools(res) {
  sendJson(res, 200, {
    tools: Object.entries(TOOL_DEFS).map(([name, def]) => ({
      name,
      description: `${def.title}: ${def.providerHint}`,
      inputSchema: {
        type: 'object',
        properties: {
          prompt: { type: 'string' },
          items: { type: 'array', items: { type: 'string' } }
        }
      }
    }))
  });
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') {
      sendJson(res, 204, {});
      return;
    }

    const url = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
    if (req.method === 'GET' && url.pathname === '/health') {
      sendJson(res, 200, {
        ok: true,
        gateway: 'AIPhone Tool Gateway',
        tools: Object.keys(TOOL_DEFS)
      });
      return;
    }
    if (req.method === 'GET' && url.pathname === '/mcp/tools') {
      handleTools(res);
      return;
    }
    if (req.method === 'GET' && url.pathname === '/api/social/feed') {
      if (!isGatewayAuthorized(req)) {
        rejectUnauthorized(res);
        return;
      }
      sendJson(res, 200, await socialFeedResponse(url));
      return;
    }
    if (req.method === 'POST' && url.pathname === '/api/social/draft') {
      if (!isGatewayAuthorized(req)) {
        rejectUnauthorized(res);
        return;
      }
      sendJson(res, 200, socialDraftResponse(await readJson(req)));
      return;
    }
    if (req.method === 'POST' && url.pathname === '/api/social/wecom/callback') {
      if (!isWecomCallbackAuthorized(req, url)) {
        rejectUnauthorized(res);
        return;
      }
      const item = wecomCallbackItem(await readRawBody(req));
      if (!item) {
        sendJson(res, 400, {
          ok: false,
          error: 'WeCom callback body is empty; no SocialHub item was cached.'
        });
        return;
      }
      socialCache.items.push(item);
      sendJson(res, 200, {
        ok: true,
        item
      });
      return;
    }
    if (req.method === 'POST' && url.pathname === '/mcp/call') {
      if (!isGatewayAuthorized(req)) {
        rejectUnauthorized(res);
        return;
      }
      await handleMcpCall(req, res);
      return;
    }
    if (req.method === 'POST' && url.pathname === '/api/aiphone/tool') {
      if (!isGatewayAuthorized(req)) {
        rejectUnauthorized(res);
        return;
      }
      await handleAiphoneTool(req, res);
      return;
    }

    sendJson(res, 404, {
      ok: false,
      error: 'Not found'
    });
  } catch (error) {
    console.error('[requestError]', error);
    if (res.headersSent) {
      res.end();
      return;
    }
    sendJson(res, 500, {
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    });
  }
});

server.on('clientError', (error, socket) => {
  console.error('[clientError]', error.message);
  if (socket.writable) {
    socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
  } else {
    socket.destroy();
  }
});

server.listen(PORT, HOST, () => {
  console.log(`AIPhone Tool Gateway listening on http://${HOST}:${PORT}`);
});
