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
const HOST = process.env.TOOL_GATEWAY_HOST || '0.0.0.0';
const DEMO_MODE = process.env.TOOL_GATEWAY_DEMO === '1';
const MAX_BODY_BYTES = 1024 * 1024;
const A2UI_VERSION = 'v0.9.1';
const A2UI_MIME = 'application/a2ui+json';

process.on('uncaughtException', error => {
  console.error('[uncaughtException]', error);
});

process.on('unhandledRejection', reason => {
  console.error('[unhandledRejection]', reason);
});

const TOOL_DEFS = {
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
    actions: ['查询 12306', '换日期', '换车站']
  },
  'food.search': {
    title: '附近餐饮查询',
    envPrefix: 'FOOD',
    providerHint: '高德 Web 服务 POI 搜索（仅查询餐饮地点）',
    requiredArgs: ['location', 'keyword'],
    configItems: ['AMAP_KEY', 'AMAP_DEFAULT_LOCATION=经度,纬度'],
    actions: ['配置高德 Web 服务 Key', '设置默认坐标', '只查询不下单']
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

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
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
    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
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

function textOf(value) {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return JSON.stringify(value);
}

function normalizeToolId(name, prompt) {
  const value = textOf(name).trim().toLowerCase().replaceAll('_', '.');
  if (value.includes('flight') || value.includes('航班') || value.includes('机票') || value.includes('飞机')) {
    return 'flight.search';
  }
  if (value.includes('train') || value.includes('12306') || value.includes('火车') || value.includes('高铁') || value.includes('动车')) {
    return 'train.search';
  }
  if (value.includes('food') || value.includes('meal') || value.includes('order') || value.includes('外卖') || value.includes('点餐')) {
    return 'food.search';
  }

  const p = textOf(prompt);
  if (/航班|机票|飞机/.test(p)) {
    return 'flight.search';
  }
  if (/火车|高铁|动车|车票|12306/.test(p)) {
    return 'train.search';
  }
  if (/外卖|点餐|午餐|晚餐|奶茶|咖啡/.test(p)) {
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
      variant: index === 0 ? 'primary' : 'secondary'
    };
  }
  return {
    id: textOf(action?.id || actionId(action?.label, index)),
    label: textOf(action?.label || '继续'),
    prompt: textOf(action?.prompt || action?.label || '继续'),
    variant: ['primary', 'secondary', 'danger'].includes(action?.variant) ? action.variant : 'secondary'
  };
}

function normalizeCard(card, index) {
  const kind = cardKind(card);
  const toolId = textOf(card.toolId || card.toolName);
  const status = textOf(card.status || (kind === 'tool_result' ? 'success' : (kind === 'error' ? 'error' : 'idle')));
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
    bullets: Array.isArray(card.bullets) ? card.bullets.map(textOf) : (Array.isArray(card.items) ? card.items.map(textOf) : []),
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
  if (toolName === 'train.search' || toolName === 'flight.search') {
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
    status: '可查询'
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
    distance
  };
}

function dataForCard(toolName, card) {
  if (card.rows.length > 0) {
    return card.rows;
  }
  if (toolName === 'train.search') {
    return card.bullets.map(parseTrainItem);
  }
  if (toolName === 'flight.search') {
    return card.bullets.map(parseFlightItem);
  }
  if (toolName === 'food.search') {
    return card.bullets.map(parseFoodItem);
  }
  return normalizeRowsForInfo(card.bullets);
}

function dataPathForTool(toolName) {
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
  const message = toolName === 'train.search'
    ? '正在等待 12306 返回'
    : (toolName === 'flight.search' ? '正在等待飞常准返回' : (toolName === 'food.search' ? '正在等待高德 POI 返回' : '正在调用工具'));
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

function extractRouteNames(source, candidates) {
  const text = textOf(source);
  const direct = text.match(/([\u4e00-\u9fa5]{2,8})\s*(?:到|去|至|飞)\s*([\u4e00-\u9fa5]{2,8})/);
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
  const filtered = /高铁|动车|\bG\d+|\bD\d+/.test(source) ? parsed.filter(item => /^G|^D/.test(item.trainCode)) : parsed;
  const top = filtered.slice(0, 6);

  if (top.length === 0) {
    return generated(
      '12306 暂无可展示车次。',
      [
        {
          type: 'info',
          title: '12306 查询结果为空',
          body: `${date} ${fromName} 到 ${toName} 暂时没有查询到可展示车次，可能是日期未开售、线路调整或接口限制。`,
          toolName: 'train.search',
          items: [],
          actions: ['换个日期', '换个车站']
        }
      ]
    );
  }

  return generated(
    `已从 12306 查询到 ${date} ${fromName} 到 ${toName} 的车次。`,
    [
      {
        type: 'choice_list',
        title: '12306 余票查询',
        body: '以下为 12306 实时查询结果摘要。',
        toolName: 'train.search',
        items: top.map(trainItemText),
        actions: ['换个时间', '换个车站']
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

function extractLocation(source) {
  const configured = process.env.AMAP_DEFAULT_LOCATION || process.env.FOOD_DEFAULT_LOCATION || '';
  const text = `${textOf(source)} ${configured}`;
  const match = text.match(/(-?\d{2,3}\.\d+)\s*,\s*(-?\d{1,2}\.\d+)/);
  if (!match) {
    return '';
  }
  return `${match[1]},${match[2]}`;
}

async function callAmapFoodSearch(args) {
  const key = process.env.AMAP_KEY || '';
  if (key.length === 0) {
    return missingConfigResponse('food.search', args);
  }

  const source = joinedArgs(args);
  const location = extractLocation(source);
  if (location.length === 0) {
    return generated(
      '附近餐饮查询需要位置。',
      [
        {
          type: 'tool_required',
          title: '需要位置授权或默认坐标',
          body: '高德周边搜索需要经纬度。你可以在环境变量 AMAP_DEFAULT_LOCATION 中填入经度,纬度，例如 116.397428,39.90923。',
          toolName: 'food.search',
          items: ['需要 AMAP_KEY', '需要 AMAP_DEFAULT_LOCATION 或用户授权位置'],
          actions: ['配置默认坐标', '换查询位置']
        }
      ]
    );
  }

  const keyword = /咖啡|奶茶|晚餐|午餐|早餐|快餐/.exec(source)?.[0] || '餐饮';
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

  const pois = Array.isArray(payload.pois) ? payload.pois.slice(0, 8) : [];
  return generated(
    `已通过高德查询到附近餐饮 POI。`,
    [
      {
        type: 'choice_list',
        title: '附近餐饮选择',
        body: '以下为高德周边餐饮结果。',
        toolName: 'food.search',
        items: pois.map(poi => `${poi.name} ${poi.type || ''} ${poi.address || ''} ${poi.distance ? `${poi.distance}米` : ''}`),
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

function demoResponse(toolName, args) {
  const title = TOOL_DEFS[toolName]?.title || '工具调用';
  return generated(
    `${title}暂未连接实时供应商。`,
    [
      {
        type: 'info',
        title: `${title}暂未返回实时结果`,
        body: '当前网关未连接实时供应商，请配置对应 API 或 MCP 服务后重新查询。',
        toolName,
        items: [
          `请求：${textOf(args.prompt).slice(0, 160)}`,
          '需要配置供应商 API 或 MCP 服务。'
        ],
        actions: ['配置供应商', '重新查询']
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
          items: Object.values(TOOL_DEFS).map(def => def.title),
          actions: ['选择工具', '补充需求']
        }
      ]
    );
  }

  if (DEMO_MODE) {
    return demoResponse(toolName, args);
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
  const toolName = normalizeToolId(body.toolId, body.prompt);
  const requestedSurfaceId = textOf(body.surfaceId).trim();
  if (toolName.length === 0) {
    writeA2uiHeaders(res, 200);
    await writeA2uiStream(res, rewriteA2uiSurfaceId(generated(
      '需要选择工具。',
      [
        {
          kind: 'error',
          title: '无法判断工具类型',
          body: '请说明要查航班、火车票，还是附近餐饮。',
          status: 'needs_input',
          bullets: ['航班查询', '火车票查询', '附近餐饮查询'],
          actions: [
            { id: 'choose_flight', label: '查航班', prompt: '我要查询航班信息', variant: 'primary' },
            { id: 'choose_train', label: '查火车票', prompt: '我要查询火车票信息', variant: 'secondary' },
            { id: 'choose_food', label: '查餐饮', prompt: '我要查询附近餐饮', variant: 'secondary' }
          ]
        }
      ]
    ), requestedSurfaceId));
    res.end();
    return;
  }

  writeA2uiHeaders(res, 200);
  await writeA2uiStream(res, rewriteA2uiSurfaceId(pendingA2ui(toolName, body.prompt || ''), requestedSurfaceId));
  const result = await callTool(toolName, {
    prompt: body.prompt || '',
    items: requestItems(body),
    arguments: body.arguments || {}
  });
  await writeA2uiStream(res, rewriteA2uiSurfaceId(result, requestedSurfaceId));
  res.end();
}

async function handleMcpCall(req, res) {
  const body = await readJson(req);
  const toolName = normalizeToolId(body.name, JSON.stringify(body.arguments || {}));
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
        demoMode: DEMO_MODE,
        tools: Object.keys(TOOL_DEFS)
      });
      return;
    }
    if (req.method === 'GET' && url.pathname === '/mcp/tools') {
      handleTools(res);
      return;
    }
    if (req.method === 'POST' && url.pathname === '/mcp/call') {
      await handleMcpCall(req, res);
      return;
    }
    if (req.method === 'POST' && url.pathname === '/api/aiphone/tool') {
      await handleAiphoneTool(req, res);
      return;
    }

    sendJson(res, 404, {
      ok: false,
      error: 'Not found'
    });
  } catch (error) {
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
