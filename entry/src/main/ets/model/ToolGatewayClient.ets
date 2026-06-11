import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  A2UI_VERSION,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiEnvelope,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiSurfaceState,
  A2uiTrainData,
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

interface HttpTextResponse {
  code: number;
  text: string;
  cookies: string;
  headers: string;
}

interface HttpRequestHeaders {
  'User-Agent'?: string;
  'Accept'?: string;
  'Accept-Encoding'?: string;
  'Referer'?: string;
  'Cookie'?: string;
  'Content-Type'?: string;
  'X-VARIFLIGHT-KEY'?: string;
}

interface ToolRequestDebug {
  endpoint: string;
  body: ToolGatewayRequestBody;
}

interface LeftTicketData {
  result?: string[];
}

interface LeftTicketPayload {
  data?: LeftTicketData;
}

interface StationEntry {
  name: string;
  code: string;
}

interface StationCache {
  entries: StationEntry[];
  names: string[];
}

interface StationDefault {
  city: string;
  station: string;
}

interface LocalProviderConfig {
  flightMcpKey: string;
  variflightApiUrl: string;
  amapKey: string;
  amapDefaultLocation: string;
  amapRadius: string;
}

interface LocalProviderRawConfig {
  FLIGHT_MCP_KEY?: string;
  VARIFLIGHT_API_KEY?: string;
  X_VARIFLIGHT_KEY?: string;
  FLIGHT_API_KEY?: string;
  VARIFLIGHT_API_URL?: string;
  FLIGHT_VARIFLIGHT_URL?: string;
  AMAP_KEY?: string;
  AMAP_DEFAULT_LOCATION?: string;
  FOOD_DEFAULT_LOCATION?: string;
  AMAP_RADIUS?: string;
  flightMcpKey?: string;
  variflightApiUrl?: string;
  amapKey?: string;
  amapDefaultLocation?: string;
  amapRadius?: string;
}

interface VariFlightRequestParams {
  fnum?: string;
  date?: string;
  depcity?: string;
  arrcity?: string;
  dep_city?: string;
  arr_city?: string;
  dep_date?: string;
  price_mode?: string;
}

interface VariFlightRequestPayload {
  endpoint: string;
  params: VariFlightRequestParams;
}

type FlightProviderItem = FlightProviderRecord | string;

interface FlightProviderRecord {
  FlightNo?: string;
  flightNo?: string;
  flight_no?: string;
  fnum?: string;
  Fnum?: string;
  flightNumber?: string;
  flight_number?: string;
  flight?: string;
  FlightCompany?: string;
  airline?: string;
  airlineName?: string;
  AirlineName?: string;
  carrier?: string;
  carrierName?: string;
  FlightDepcode?: string;
  FlightDepAirport?: string;
  dep?: string;
  depAirport?: string;
  depAirportName?: string;
  dep_city?: string;
  departure?: string;
  departureAirport?: string;
  FlightArrcode?: string;
  FlightArrAirport?: string;
  arr?: string;
  arrAirport?: string;
  arrAirportName?: string;
  arr_city?: string;
  arrival?: string;
  arrivalAirport?: string;
  FlightDeptimePlanDate?: string;
  FlightDeptimeReadyDate?: string;
  FlightDeptimeDate?: string;
  FlightDepTime?: string;
  depTime?: string;
  dep_time?: string;
  departureTime?: string;
  std?: string;
  scheduleDepTime?: string;
  FlightArrtimePlanDate?: string;
  FlightArrtimeReadyDate?: string;
  FlightArrtimeDate?: string;
  FlightArrTime?: string;
  arrTime?: string;
  arr_time?: string;
  arrivalTime?: string;
  sta?: string;
  scheduleArrTime?: string;
  FlightState?: string;
  FlightStatus?: string;
  status?: string;
  flightStatus?: string;
  state?: string;
  price?: string;
  Price?: string;
  lowestPrice?: string;
  LowestPrice?: string;
  fare?: string;
  amount?: string;
}

interface FlightProviderData {
  flights?: FlightProviderItem[];
  flightList?: FlightProviderItem[];
  list?: FlightProviderItem[];
  items?: FlightProviderItem[];
  records?: FlightProviderItem[];
  result?: FlightProviderItem[];
  results?: FlightProviderItem[];
}

interface FlightProviderPayload extends FlightProviderData {
  data?: FlightProviderData | FlightProviderItem[];
  error?: string;
  message?: string;
  msg?: string;
  info?: string;
  errmsg?: string;
  success?: boolean | string;
  status?: string | number;
}

interface AmapPoi {
  name?: string;
  type?: string;
  address?: string;
  distance?: string;
  location?: string;
}

interface AmapGeocode {
  location?: string;
  formatted_address?: string;
  level?: string;
}

interface AmapPayload {
  status?: string;
  info?: string;
  infocode?: string;
  message?: string;
  pois?: AmapPoi[];
  geocodes?: AmapGeocode[];
}

interface FlightCityCode {
  city: string;
  code: string;
}

interface FlightRoute {
  routeNames: string[];
  depCode: string;
  arrCode: string;
}

interface AmapLocationResolution {
  location: string;
  locationSource: string;
  locationLabel: string;
}

interface FoodQuery {
  place: string;
  keyword: string;
}

const LOCAL_TOOL_GATEWAY_URL: string = 'local://aiphone-tools';
const LOCAL_PROVIDER_CONFIG_RAWFILE: string = 'aiphone_provider_config.json';
const DEFAULT_VARIFLIGHT_API_URL: string = 'https://mcp.variflight.com/api/v1/mcp/data';
const DEFAULT_AMAP_RADIUS: string = '3000';
const TRAIN_RESULT_LIMIT: number = 30;
const TRAIN_INITIAL_VISIBLE: number = 6;
const TRAIN_CLIENT_ACTIONS: A2uiAction[] = [
  { id: 'client_show_more', label: '多展示一些', prompt: 'client_show_more', kind: 'client', variant: 'primary' },
  { id: 'client_sort_fastest', label: '选最快的', prompt: 'client_sort_fastest', kind: 'client', variant: 'secondary' },
  { id: 'client_filter_available', label: '只看有票', prompt: 'client_filter_available', kind: 'client', variant: 'secondary' },
  { id: 'client_edit_query', label: '修改查询', prompt: 'client_edit_query', kind: 'input', variant: 'secondary' }
];
const HIGH_SPEED_DEFAULT_STATIONS: StationDefault[] = [
  { city: '北京', station: '北京南' },
  { city: '上海', station: '上海虹桥' },
  { city: '天津', station: '天津西' },
  { city: '南京', station: '南京南' },
  { city: '杭州', station: '杭州东' },
  { city: '广州', station: '广州南' },
  { city: '深圳', station: '深圳北' },
  { city: '武汉', station: '武汉' },
  { city: '成都', station: '成都东' },
  { city: '重庆', station: '重庆北' }
];
const CHINA_FLIGHT_CITY_CODES: FlightCityCode[] = [
  { city: '北京', code: 'BJS' },
  { city: '上海', code: 'SHA' },
  { city: '广州', code: 'CAN' },
  { city: '深圳', code: 'SZX' },
  { city: '杭州', code: 'HGH' },
  { city: '成都', code: 'CTU' },
  { city: '重庆', code: 'CKG' },
  { city: '西安', code: 'SIA' },
  { city: '南京', code: 'NKG' },
  { city: '武汉', code: 'WUH' },
  { city: '厦门', code: 'XMN' },
  { city: '青岛', code: 'TAO' },
  { city: '长沙', code: 'CSX' },
  { city: '昆明', code: 'KMG' },
  { city: '海口', code: 'HAK' },
  { city: '三亚', code: 'SYX' }
];

let stationCache: StationCache | null = null;
let localProviderConfig: LocalProviderConfig = {
  flightMcpKey: '',
  variflightApiUrl: DEFAULT_VARIFLIGHT_API_URL,
  amapKey: '',
  amapDefaultLocation: '',
  amapRadius: DEFAULT_AMAP_RADIUS
};

function userAgentHeaders(): HttpRequestHeaders {
  return {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
  };
}

function leftTicketHeaders(cookieHeader: string): HttpRequestHeaders {
  const headers: HttpRequestHeaders = {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
    'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init'
  };
  if (cookieHeader.length > 0) {
    headers.Cookie = cookieHeader;
  }
  return headers;
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
  return LOCAL_TOOL_GATEWAY_URL;
}

export function isLocalToolGatewayUrl(baseUrl: string): boolean {
  return baseUrl.trim().toLowerCase() === LOCAL_TOOL_GATEWAY_URL;
}

export function buildToolGatewayUrl(baseUrl: string): string {
  if (isLocalToolGatewayUrl(baseUrl)) {
    return LOCAL_TOOL_GATEWAY_URL;
  }
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

function firstText(values: Array<Object | string | number | boolean | null | undefined>): string {
  for (let index = 0; index < values.length; index++) {
    const text = textOf(values[index]).trim();
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

export function configureLocalProviderConfig(config: LocalProviderConfig): void {
  localProviderConfig = {
    flightMcpKey: config.flightMcpKey.trim(),
    variflightApiUrl: config.variflightApiUrl.trim().length > 0 ? config.variflightApiUrl.trim() : DEFAULT_VARIFLIGHT_API_URL,
    amapKey: config.amapKey.trim(),
    amapDefaultLocation: config.amapDefaultLocation.trim(),
    amapRadius: config.amapRadius.trim().length > 0 ? config.amapRadius.trim() : DEFAULT_AMAP_RADIUS
  };
  aiLogInfo('[AIPhone][LocalProviderConfig] rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ' flightKeyChars=' + localProviderConfig.flightMcpKey.length.toString() +
    ' amapKeyChars=' + localProviderConfig.amapKey.length.toString() +
    ' defaultLocationPresent=' + (localProviderConfig.amapDefaultLocation.length > 0 ? 'true' : 'false'));
}

export function configureLocalProviderConfigFromRawJson(rawJson: string): void {
  const parsed = JSON.parse(rawJson) as LocalProviderRawConfig;
  configureLocalProviderConfig({
    flightMcpKey: firstText([parsed.FLIGHT_MCP_KEY, parsed.VARIFLIGHT_API_KEY, parsed.X_VARIFLIGHT_KEY, parsed.FLIGHT_API_KEY, parsed.flightMcpKey]),
    variflightApiUrl: firstText([parsed.VARIFLIGHT_API_URL, parsed.FLIGHT_VARIFLIGHT_URL, parsed.variflightApiUrl]),
    amapKey: firstText([parsed.AMAP_KEY, parsed.amapKey]),
    amapDefaultLocation: firstText([parsed.AMAP_DEFAULT_LOCATION, parsed.FOOD_DEFAULT_LOCATION, parsed.amapDefaultLocation]),
    amapRadius: firstText([parsed.AMAP_RADIUS, parsed.amapRadius])
  });
}

export function localProviderConfigDebugSummary(): string {
  return 'rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ', flightKey=' + (localProviderConfig.flightMcpKey.length > 0 ? 'present(' + localProviderConfig.flightMcpKey.length.toString() + ')' : 'missing') +
    ', amapKey=' + (localProviderConfig.amapKey.length > 0 ? 'present(' + localProviderConfig.amapKey.length.toString() + ')' : 'missing') +
    ', defaultLocation=' + (localProviderConfig.amapDefaultLocation.length > 0 ? 'present' : 'missing');
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

function pad2(value: number): string {
  if (value < 10) {
    return '0' + value.toString();
  }
  return value.toString();
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date.getTime());
  next.setDate(next.getDate() + days);
  return next;
}

function formatDate(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
}

function parseTravelDate(source: string): string {
  const now = new Date();
  if (/后天/.test(source)) {
    return formatDate(addDays(now, 2));
  }
  if (/明天|明日/.test(source)) {
    return formatDate(addDays(now, 1));
  }
  if (/今天|今日/.test(source)) {
    return formatDate(now);
  }

  const iso = /20\d{2}[-/年](\d{1,2})[-/月](\d{1,2})/.exec(source);
  if (iso !== null) {
    return source.substring(iso.index, iso.index + 4) + '-' + pad2(Number(iso[1])) + '-' + pad2(Number(iso[2]));
  }

  const monthDay = /(\d{1,2})\s*(?:月|-|\/)\s*(\d{1,2})\s*(?:日|号)?/.exec(source);
  if (monthDay !== null) {
    return now.getFullYear().toString() + '-' + pad2(Number(monthDay[1])) + '-' + pad2(Number(monthDay[2]));
  }
  return '';
}

function parseChineseNumberToken(token: string): number {
  const raw = token.trim();
  if (/^\d+$/.test(raw)) {
    return Number(raw);
  }
  const chars = ['零', '一', '二', '两', '三', '四', '五', '六', '七', '八', '九', '十'];
  const values = [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  if (raw.length === 1) {
    const index = chars.indexOf(raw);
    return index >= 0 ? values[index] : -1;
  }
  if (raw.startsWith('十') && raw.length === 2) {
    const index = chars.indexOf(raw.substring(1));
    return index >= 0 ? 10 + values[index] : -1;
  }
  if (raw.endsWith('十') && raw.length === 2) {
    const index = chars.indexOf(raw.substring(0, 1));
    return index >= 0 ? values[index] * 10 : -1;
  }
  const tens = /^([一二三四五六七八九])十([一二三四五六七八九])?$/.exec(raw);
  if (tens !== null) {
    const tenIndex = chars.indexOf(tens[1]);
    const oneIndex = tens[2] === undefined ? -1 : chars.indexOf(tens[2]);
    return values[tenIndex] * 10 + (oneIndex >= 0 ? values[oneIndex] : 0);
  }
  return -1;
}

function parseDepartAfter(source: string): string {
  const colon = /(\d{1,2})\s*[:：]\s*(\d{2})\s*(?:之)?(?:后|以后|之后|起)?/.exec(source);
  if (colon !== null) {
    const hour = Number(colon[1]);
    const minute = Number(colon[2]);
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return pad2(hour) + ':' + pad2(minute);
    }
  }
  const point = /(凌晨|早上|上午|中午|下午|傍晚|晚上|夜间)?\s*([零一二三四五六七八九十两\d]{1,4})\s*点(?:\s*([零一二三四五六七八九十\d]{1,2})\s*分)?(?:\s*(?:之)?(?:后|以后|之后|起))?/.exec(source);
  if (point !== null) {
    let hour = parseChineseNumberToken(point[2]);
    const minute = point[3] === undefined ? 0 : parseChineseNumberToken(point[3]);
    if (hour < 0 || minute < 0) {
      return '';
    }
    const period = point[1] === undefined ? '' : point[1];
    if ((period === '下午' || period === '晚上' || period === '傍晚') && hour >= 1 && hour <= 11) {
      hour += 12;
    }
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return pad2(hour) + ':' + pad2(minute);
    }
  }
  return '';
}

function normalizeTrainStationName(name: string, source: string): string {
  if (!/高铁|动车|\bG\d+|\bD\d+/i.test(source)) {
    return name;
  }
  for (let index = 0; index < HIGH_SPEED_DEFAULT_STATIONS.length; index++) {
    const item = HIGH_SPEED_DEFAULT_STATIONS[index];
    if (item.city === name) {
      return item.station;
    }
  }
  return name;
}

function stationCodeFor(name: string, stations: StationCache): string {
  for (let index = 0; index < stations.entries.length; index++) {
    const item = stations.entries[index];
    if (item.name === name) {
      return item.code;
    }
  }
  return '';
}

function stationNameForCode(code: string, stations: StationCache): string {
  for (let index = 0; index < stations.entries.length; index++) {
    const item = stations.entries[index];
    if (item.code === code) {
      return item.name;
    }
  }
  return code;
}

function findCandidateInRoutePart(part: string, candidates: string[], preferLast: boolean): string {
  let selected = '';
  let selectedIndex = preferLast ? -1 : 999999;
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    const foundAt = part.indexOf(candidate);
    if (foundAt < 0) {
      continue;
    }
    if (selected.length === 0) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (preferLast && foundAt > selectedIndex) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (!preferLast && foundAt < selectedIndex) {
      selected = candidate;
      selectedIndex = foundAt;
      continue;
    }
    if (foundAt === selectedIndex && candidate.length > selected.length) {
      selected = candidate;
    }
  }
  return selected;
}

function extractRouteNames(source: string, candidates: string[]): string[] {
  const departRoute = /(?:从)?([\u4e00-\u9fa5]{2,12})\s*出发\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})/.exec(source);
  if (departRoute !== null) {
    const fromCandidate = findCandidateInRoutePart(departRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(departRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const stationRoute = /([\u4e00-\u9fa5]{2,12})站\s*(?:到|去|至)\s*([\u4e00-\u9fa5]{2,12})站/.exec(source);
  if (stationRoute !== null) {
    const fromCandidate = findCandidateInRoutePart(stationRoute[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(stationRoute[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const direct = /([\u4e00-\u9fa5]{2,12})\s*(?:到|去|至|飞)\s*([\u4e00-\u9fa5]{2,12})/.exec(source);
  if (direct !== null) {
    const fromCandidate = findCandidateInRoutePart(direct[1], candidates, true);
    const toCandidate = findCandidateInRoutePart(direct[2], candidates, false);
    if (fromCandidate.length > 0 && toCandidate.length > 0) {
      return [fromCandidate, toCandidate];
    }
  }

  const matched: string[] = [];
  for (let index = 0; index < candidates.length; index++) {
    const name = candidates[index];
    if (source.includes(name) && matched.indexOf(name) < 0) {
      matched.push(name);
    }
    if (matched.length >= 2) {
      break;
    }
  }
  return matched;
}

function describeThrown(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return JSON.stringify(error);
}

async function requestText(url: string, headers: HttpRequestHeaders): Promise<HttpTextResponse> {
  const request = http.createHttp();
  const decoder = util.TextDecoder.create('utf-8');
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    let text = '';
    if (typeof response.result === 'string') {
      text = response.result;
    } else {
      text = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return {
      code: response.responseCode,
      text: text,
      cookies: response.cookies === undefined ? '' : response.cookies,
      headers: JSON.stringify(response.header)
    };
  } catch (error) {
    throw new Error('GET ' + url + ' failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

async function postJsonText(url: string, headers: HttpRequestHeaders, body: string): Promise<HttpTextResponse> {
  const request = http.createHttp();
  const decoder = util.TextDecoder.create('utf-8');
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: body,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    let text = '';
    if (typeof response.result === 'string') {
      text = response.result;
    } else {
      text = decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return {
      code: response.responseCode,
      text: text,
      cookies: response.cookies === undefined ? '' : response.cookies,
      headers: JSON.stringify(response.header)
    };
  } catch (error) {
    throw new Error('POST ' + url + ' failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

function buildQueryUrl(baseUrl: string, keys: string[], values: string[]): string {
  let query = '';
  for (let index = 0; index < keys.length && index < values.length; index++) {
    const value = values[index];
    if (value.length === 0) {
      continue;
    }
    query += (query.length === 0 ? '?' : '&') + encodeURIComponent(keys[index]) + '=' + encodeURIComponent(value);
  }
  return baseUrl + query;
}

function build12306LeftTicketUrl(path: string, date: string, fromCode: string, toCode: string): string {
  return 'https://kyfw.12306.cn/otn/leftTicket/' + path +
    '?leftTicketDTO.train_date=' + encodeURIComponent(date) +
    '&leftTicketDTO.from_station=' + encodeURIComponent(fromCode) +
    '&leftTicketDTO.to_station=' + encodeURIComponent(toCode) +
    '&purpose_codes=ADULT';
}

function redirected12306Url(text: string, date: string, fromCode: string, toCode: string): string {
  const match = /"c_url"\s*:\s*"([^"]+)"/.exec(text);
  if (match === null || match[1].length === 0) {
    return '';
  }
  const path = match[1].startsWith('leftTicket/') ? match[1].substring('leftTicket/'.length) : match[1];
  return build12306LeftTicketUrl(path, date, fromCode, toCode);
}

function isCookieAttribute(name: string): boolean {
  const value = name.trim().toLowerCase();
  return value === 'path' ||
    value === 'domain' ||
    value === 'expires' ||
    value === 'max-age' ||
    value === 'samesite' ||
    value === 'httponly' ||
    value === 'secure';
}

function is12306CookieName(name: string): boolean {
  return name === 'route' ||
    name === 'JSESSIONID' ||
    name === 'BIGipServerotn' ||
    name.startsWith('BIGipServer') ||
    name.startsWith('RAIL_') ||
    name.startsWith('_jc_save_') ||
    name === 'guidesStatus' ||
    name === 'highContrastMode' ||
    name === 'cursorStatus';
}

function upsertCookiePair(pairs: string[], names: string[], name: string, value: string): void {
  for (let index = 0; index < names.length; index++) {
    if (names[index] === name) {
      pairs[index] = name + '=' + value;
      return;
    }
  }
  names.push(name);
  pairs.push(name + '=' + value);
}

function cookieHeaderFromRaw(rawCookies: string): string {
  const normalized = rawCookies
    .replace(/\\r/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\r/g, '\n');
  const result: string[] = [];
  const names: string[] = [];
  const matcher = /([A-Za-z_][A-Za-z0-9_]*|BIGipServer[A-Za-z0-9_]+)=([^;\s,"\\]+)/g;
  let match: RegExpExecArray | null = matcher.exec(normalized);
  while (match !== null) {
    const name = match[1].trim();
    const value = match[2].trim();
    if (name.length > 0 && value.length > 0 && !isCookieAttribute(name) && is12306CookieName(name)) {
      upsertCookiePair(result, names, name, value);
    }
    match = matcher.exec(normalized);
  }
  return result.join('; ');
}

async function request12306LeftTicket(date: string, fromCode: string, toCode: string, headers: HttpRequestHeaders): Promise<HttpTextResponse> {
  const paths: string[] = ['queryI', 'queryG', 'queryZ'];
  let lastResponse: HttpTextResponse = {
    code: 0,
    text: '',
    cookies: '',
    headers: ''
  };
  for (let index = 0; index < paths.length; index++) {
    const path = paths[index];
    const response = await requestText(build12306LeftTicketUrl(path, date, fromCode, toCode), headers);
    lastResponse = response;
    aiLogInfo('[AIPhone][LocalTool12306Endpoint] path=' + path + ' code=' + response.code.toString() + ' chars=' + response.text.length.toString());
    if (response.code >= 200 && response.code < 300 && response.text.indexOf('"result"') >= 0) {
      return response;
    }
    const redirected = redirected12306Url(response.text, date, fromCode, toCode);
    if (redirected.length > 0) {
      const redirectedResponse = await requestText(redirected, headers);
      lastResponse = redirectedResponse;
      aiLogInfo('[AIPhone][LocalTool12306Endpoint] path=redirect code=' + redirectedResponse.code.toString() + ' chars=' + redirectedResponse.text.length.toString());
      if (redirectedResponse.code >= 200 && redirectedResponse.code < 300 && redirectedResponse.text.indexOf('"result"') >= 0) {
        return redirectedResponse;
      }
    }
  }
  return lastResponse;
}

async function load12306Stations(): Promise<StationCache> {
  if (stationCache !== null) {
    return stationCache;
  }
  const response = await requestText('https://kyfw.12306.cn/otn/resources/js/framework/station_name.js', userAgentHeaders());
  if (response.code < 200 || response.code >= 300) {
    throw new Error('12306 station_name HTTP ' + response.code.toString());
  }

  const entries: StationEntry[] = [];
  const names: string[] = [];
  response.text.split('@').forEach((part: string) => {
    const fields = part.split('|');
    if (fields.length >= 3 && fields[1].length > 0 && fields[2].length > 0) {
      entries.push({
        name: fields[1],
        code: fields[2]
      });
      names.push(fields[1]);
    }
  });
  names.sort((left: string, right: string) => right.length - left.length);
  stationCache = {
    entries: entries,
    names: names
  };
  aiLogInfo('[AIPhone][LocalToolStations] count=' + entries.length.toString());
  return stationCache;
}

function parse12306Row(row: string, stations: StationCache): A2uiTrainData {
  const fields = row.split('|');
  const trainCode = fields.length > 3 ? fields[3] : '';
  return {
    trainCode: trainCode,
    from: fields.length > 6 ? stationNameForCode(fields[6], stations) : '',
    to: fields.length > 7 ? stationNameForCode(fields[7], stations) : '',
    depart: fields.length > 8 ? fields[8] : '',
    arrive: fields.length > 9 ? fields[9] : '',
    duration: fields.length > 10 ? fields[10] : '',
    seats: '',
    status: fields.length > 1 && fields[1].length > 0 ? fields[1] : (fields.length > 11 ? fields[11] : ''),
    business: fields.length > 32 ? fields[32] : '',
    first: fields.length > 31 ? fields[31] : '',
    second: fields.length > 30 ? fields[30] : '',
    noSeat: fields.length > 26 ? fields[26] : '',
    hardSeat: fields.length > 29 ? fields[29] : '',
    sleeperSoft: fields.length > 23 && fields[23].length > 0 ? fields[23] : (fields.length > 28 ? fields[28] : '')
  };
}

function formatTrainSeatsSummary(item: A2uiTrainData): string {
  const seats: string[] = [];
  if (item.business.length > 0) {
    seats.push('商务 ' + item.business);
  }
  if (item.first.length > 0) {
    seats.push('一等 ' + item.first);
  }
  if (item.second.length > 0) {
    seats.push('二等 ' + item.second);
  }
  if (item.sleeperSoft.length > 0) {
    seats.push('卧铺 ' + item.sleeperSoft);
  }
  if (item.hardSeat.length > 0) {
    seats.push('硬座 ' + item.hardSeat);
  }
  if (item.noSeat.length > 0) {
    seats.push('无座 ' + item.noSeat);
  }
  return seats.join(' / ');
}

function normalizeTrainRecord(item: A2uiTrainData): A2uiTrainData {
  return {
    trainCode: item.trainCode,
    from: item.from,
    to: item.to,
    depart: item.depart,
    arrive: item.arrive,
    duration: item.duration,
    seats: item.seats.length > 0 ? item.seats : formatTrainSeatsSummary(item),
    status: item.status.length > 0 ? item.status : '计划',
    business: item.business,
    first: item.first,
    second: item.second,
    noSeat: item.noSeat,
    hardSeat: item.hardSeat,
    sleeperSoft: item.sleeperSoft
  };
}

function filterTrainsByDepartAfter(trains: A2uiTrainData[], afterTime: string): A2uiTrainData[] {
  if (afterTime.length === 0) {
    return trains;
  }
  const result: A2uiTrainData[] = [];
  trains.forEach((item: A2uiTrainData) => {
    if (item.depart.length < 4) {
      result.push(item);
      return;
    }
    const hhmm = item.depart.length >= 5 ? item.depart.substring(0, 5) : item.depart;
    if (hhmm >= afterTime) {
      result.push(item);
    }
  });
  return result;
}

function filterHighSpeed(source: string, trains: A2uiTrainData[]): A2uiTrainData[] {
  if (!/高铁|动车|\bG\d+|\bD\d+/i.test(source)) {
    return trains;
  }
  const result: A2uiTrainData[] = [];
  trains.forEach((item: A2uiTrainData) => {
    if (item.trainCode.startsWith('G') || item.trainCode.startsWith('D')) {
      result.push(item);
    }
  });
  return result;
}

function intentForTool(toolId: string): string {
  if (toolId === 'food.search') {
    return 'food';
  }
  if (toolId === 'train.search' || toolId === 'flight.search') {
    return 'travel';
  }
  return 'general';
}

function componentForTool(toolId: string): string {
  if (toolId === 'train.search') {
    return 'TrainOptions';
  }
  if (toolId === 'flight.search') {
    return 'FlightBoard';
  }
  if (toolId === 'food.search') {
    return 'FoodChoices';
  }
  return 'InfoRows';
}

function dataPathForTool(toolId: string): string {
  if (toolId === 'train.search') {
    return '/trains';
  }
  if (toolId === 'flight.search') {
    return '/flights';
  }
  if (toolId === 'food.search') {
    return '/foods';
  }
  return '/rows';
}

function dataLabelForTool(toolId: string): string {
  if (toolId === 'train.search') {
    return 'trains';
  }
  if (toolId === 'flight.search') {
    return 'flights';
  }
  if (toolId === 'food.search') {
    return 'foods';
  }
  return 'rows';
}

function titleForTool(toolId: string): string {
  if (toolId === 'train.search') {
    return '火车票查询';
  }
  if (toolId === 'flight.search') {
    return '国内航班查询';
  }
  if (toolId === 'food.search') {
    return '附近餐饮查询';
  }
  return '工具调用';
}

function a2uiLine(envelope: A2uiEnvelope): string {
  const line: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    line.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    line.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    line.updateDataModel = envelope.updateDataModel;
  }
  if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
    line.deleteSurface = envelope.deleteSurface;
  }
  return JSON.stringify(line) + '\n';
}

function a2uiJsonl(envelopes: A2uiEnvelope[]): string {
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    jsonl += a2uiLine(envelope);
  });
  return jsonl;
}

function pendingA2ui(toolId: string, prompt: string, surfaceId: string): string {
  const title = titleForTool(toolId);
  const message = toolId === 'train.search'
    ? '正在等待 12306 返回'
    : (toolId === 'flight.search' ? '正在等待飞常准返回' : (toolId === 'food.search' ? '正在等待高德 POI 返回' : '正在调用工具'));
  const components: A2uiComponent[] = [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: 'thinking',
      title: title,
      body: prompt.substring(0, 120),
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
  ];
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: intentForTool(toolId),
        status: 'calling_tool',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
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

function errorA2ui(surfaceId: string, toolId: string, title: string, body: string, rows: string[], actions: string[]): string {
  const actionModels: A2uiAction[] = [];
  actions.forEach((action: string, index: number) => {
    actionModels.push({
      id: 'tool_action_' + index.toString(),
      label: action,
      prompt: action,
      kind: 'prompt',
      variant: index === 0 ? 'primary' : 'secondary'
    });
  });
  const rowModels: A2uiLabelValueData[] = [];
  rows.forEach((row: string, index: number) => {
    rowModels.push({
      label: index === 0 ? '状态' : '信息 ' + (index + 1).toString(),
      value: row
    });
  });
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: intentForTool(toolId),
        status: 'needs_input',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'notice',
            title: title,
            body: body,
            status: 'needs_input'
          },
          {
            id: 'notice',
            component: 'ErrorNotice',
            title: title,
            body: body,
            status: 'needs_input',
            tone: 'warning',
            dataPath: '/rows',
            actions: actionModels
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/rows',
        value: rowModels
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: body,
          toolName: toolId,
          dataLabel: 'rows',
          count: rowModels.length
        }
      }
    }
  ]);
}

function trainResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, trains: A2uiTrainData[]): string {
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'results',
            title: title,
            body: summaryText,
            status: 'ready'
          },
          {
            id: 'results',
            component: componentForTool('train.search'),
            title: title,
            body: body,
            status: 'ready',
            dataPath: dataPathForTool('train.search'),
            actions: TRAIN_CLIENT_ACTIONS
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/trains',
        value: trains
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'train.search',
          dataLabel: dataLabelForTool('train.search'),
          count: trains.length
        }
      }
    }
  ]);
}

function flightResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, flights: A2uiFlightData[]): string {
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'travel',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'results',
            title: title,
            body: summaryText,
            status: 'ready'
          },
          {
            id: 'results',
            component: componentForTool('flight.search'),
            title: title,
            body: body,
            status: 'ready',
            dataPath: dataPathForTool('flight.search'),
            actions: [
              { id: 'flight_change_date', label: '换个日期', prompt: '换个日期查询航班', kind: 'prompt', variant: 'secondary' },
              { id: 'flight_change_city', label: '换个城市', prompt: '换个城市查询航班', kind: 'prompt', variant: 'secondary' }
            ]
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/flights',
        value: flights
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'flight.search',
          dataLabel: dataLabelForTool('flight.search'),
          count: flights.length
        }
      }
    }
  ]);
}

function foodResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, foods: A2uiFoodData[]): string {
  return a2uiJsonl([
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'food',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: [
          {
            id: 'root',
            component: 'SurfaceRoot',
            child: 'results',
            title: title,
            body: summaryText,
            status: 'ready'
          },
          {
            id: 'results',
            component: componentForTool('food.search'),
            title: title,
            body: body,
            status: 'ready',
            dataPath: dataPathForTool('food.search'),
            actions: [
              { id: 'food_change_keyword', label: '换关键词', prompt: '换关键词查询附近餐饮', kind: 'prompt', variant: 'secondary' },
              { id: 'food_change_location', label: '换位置', prompt: '换位置查询附近餐饮', kind: 'prompt', variant: 'secondary' }
            ]
          }
        ]
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/foods',
        value: foods
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'food.search',
          dataLabel: dataLabelForTool('food.search'),
          count: foods.length
        }
      }
    }
  ]);
}

function missingConfigA2ui(surfaceId: string, toolId: string): string {
  aiLogInfo('[AIPhone][LocalToolMissingConfig] toolId=' + toolId);
  if (toolId === 'flight.search') {
    return errorA2ui(
      surfaceId,
      toolId,
      '国内航班查询需要供应商配置',
      '本机工具已收到航班查询请求。为了避免编造实时航班、票价或库存，需要在 App 本地接入飞常准或兼容航班 API Key 后才能查询。',
      ['需要配置：FLIGHT_MCP_KEY 或 VARIFLIGHT_API_KEY', '供应商方向：飞常准 VariFlight MCP/API', '建议参数：出发城市、到达城市、日期或航班号'],
      ['配置飞常准 Key', '只查询不预订']
    );
  }
  if (toolId === 'food.search') {
    return errorA2ui(
      surfaceId,
      toolId,
      '附近餐饮查询需要供应商配置',
      '本机工具已收到餐饮查询请求。为了避免编造店铺、距离或营业状态，需要在 App 本地接入高德 Web 服务 Key 和位置后才能查询。',
      ['需要配置：AMAP_KEY', '需要位置：经纬度、地点文本，或默认坐标', '供应商方向：高德 Web 服务 POI'],
      ['配置高德 Key', '换查询位置']
    );
  }
  return errorA2ui(
    surfaceId,
    toolId,
    '未知工具',
    '当前本机工具只支持航班查询、火车票查询和附近餐饮查询。',
    [],
    []
  );
}

function flightCityNames(): string[] {
  const names: string[] = [];
  for (let index = 0; index < CHINA_FLIGHT_CITY_CODES.length; index++) {
    names.push(CHINA_FLIGHT_CITY_CODES[index].city);
  }
  names.sort((left: string, right: string) => right.length - left.length);
  return names;
}

function flightCodeForCity(city: string): string {
  for (let index = 0; index < CHINA_FLIGHT_CITY_CODES.length; index++) {
    const item = CHINA_FLIGHT_CITY_CODES[index];
    if (item.city === city) {
      return item.code;
    }
  }
  return '';
}

function extractFlightCityCodes(source: string): FlightRoute {
  const routeNames = extractRouteNames(source, flightCityNames());
  if (routeNames.length < 2) {
    return {
      routeNames: routeNames,
      depCode: '',
      arrCode: ''
    };
  }
  return {
    routeNames: routeNames,
    depCode: flightCodeForCity(routeNames[0]),
    arrCode: flightCodeForCity(routeNames[1])
  };
}

function extractFlightNumber(source: string): string {
  const match = /\b[A-Z0-9]{2,3}\d{1,4}\b/.exec(source.toUpperCase());
  return match === null ? '' : match[0];
}

function firstFlightArrayFromData(data: FlightProviderData | FlightProviderItem[] | undefined): FlightProviderItem[] {
  if (data === undefined || data === null) {
    return [];
  }
  if (Array.isArray(data)) {
    return data;
  }
  return firstFlightArray([
    data.flights,
    data.flightList,
    data.list,
    data.items,
    data.records,
    data.result,
    data.results
  ]);
}

function firstFlightArray(arrays: Array<FlightProviderItem[] | undefined>): FlightProviderItem[] {
  for (let index = 0; index < arrays.length; index++) {
    const value = arrays[index];
    if (value !== undefined && value.length > 0) {
      return value;
    }
  }
  return [];
}

function flightResultsFromPayload(payload: FlightProviderPayload): FlightProviderItem[] {
  const dataResults = firstFlightArrayFromData(payload.data);
  if (dataResults.length > 0) {
    return dataResults;
  }
  return firstFlightArray([
    payload.flights,
    payload.flightList,
    payload.list,
    payload.items,
    payload.records,
    payload.result,
    payload.results
  ]);
}

function extractProviderError(payload: FlightProviderPayload): string {
  const message = firstText([payload.error, payload.message, payload.msg, payload.info, payload.errmsg]);
  const success = textOf(payload.success);
  const status = textOf(payload.status);
  if (success === 'false' || status === '0') {
    return message.length > 0 ? message : JSON.stringify(payload).substring(0, 500);
  }
  return '';
}

function parseFlightTextToA2ui(text: string): A2uiFlightData {
  const routeMatch = /\b([A-Z]{2,4})\s*->\s*([A-Z]{2,4})\b/.exec(text);
  const flightMatch = /\b[A-Z0-9]{2,3}\d{1,4}\b/.exec(text);
  const statusMatch = /状态\s+([^\s]+)/.exec(text);
  const timeMatch = /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s+-\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)/.exec(text);
  const flightNo = flightMatch === null ? '' : flightMatch[0];
  const airline = flightNo.length > 0 ? text.substring(0, text.indexOf(flightNo)).trim() : '';
  return {
    flightNo: flightNo,
    airline: airline,
    dep: routeMatch === null ? '' : routeMatch[1],
    arr: routeMatch === null ? '' : routeMatch[2],
    depTime: timeMatch === null ? '' : timeMatch[1],
    arrTime: timeMatch === null ? '' : timeMatch[2],
    status: statusMatch === null ? '计划' : statusMatch[1],
    price: ''
  };
}

function flightRecordForA2ui(item: FlightProviderItem): A2uiFlightData {
  if (typeof item === 'string') {
    const trimmed = item.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return flightRecordForA2ui(JSON.parse(trimmed) as FlightProviderRecord);
      } catch (_error) {
        return parseFlightTextToA2ui(trimmed);
      }
    }
    return parseFlightTextToA2ui(trimmed);
  }
  const flightNo = firstText([item.FlightNo, item.flightNo, item.flight_no, item.fnum, item.Fnum, item.flightNumber, item.flight_number, item.flight]);
  return {
    flightNo: flightNo,
    airline: firstText([item.FlightCompany, item.airline, item.airlineName, item.AirlineName, item.carrier, item.carrierName]),
    dep: firstText([item.FlightDepcode, item.FlightDepAirport, item.dep, item.depAirport, item.depAirportName, item.dep_city, item.departure, item.departureAirport]),
    arr: firstText([item.FlightArrcode, item.FlightArrAirport, item.arr, item.arrAirport, item.arrAirportName, item.arr_city, item.arrival, item.arrivalAirport]),
    depTime: firstText([item.FlightDeptimePlanDate, item.FlightDeptimeReadyDate, item.FlightDeptimeDate, item.FlightDepTime, item.depTime, item.dep_time, item.departureTime, item.std, item.scheduleDepTime]),
    arrTime: firstText([item.FlightArrtimePlanDate, item.FlightArrtimeReadyDate, item.FlightArrtimeDate, item.FlightArrTime, item.arrTime, item.arr_time, item.arrivalTime, item.sta, item.scheduleArrTime]),
    status: firstText([item.FlightState, item.FlightStatus, item.status, item.flightStatus, item.state]),
    price: firstText([item.price, item.Price, item.lowestPrice, item.LowestPrice, item.fare, item.amount])
  };
}

function flightRecordHasData(item: A2uiFlightData): boolean {
  return item.flightNo.length > 0 ||
    item.airline.length > 0 ||
    item.dep.length > 0 ||
    item.arr.length > 0 ||
    item.depTime.length > 0 ||
    item.arrTime.length > 0;
}

async function callLocalFlightSearch(prompt: string, surfaceId: string): Promise<string> {
  const apiKey = localProviderConfig.flightMcpKey;
  if (apiKey.length === 0) {
    return missingConfigA2ui(surfaceId, 'flight.search');
  }

  const source = prompt;
  const date = parseTravelDate(source);
  const flightNumber = extractFlightNumber(source);
  const flightRoute = extractFlightCityCodes(source);
  const wantsPrice = /票价|价格|多少钱|最低价|机票/.test(source);
  if (date.length === 0 || (flightNumber.length === 0 && (flightRoute.depCode.length === 0 || flightRoute.arrCode.length === 0))) {
    return errorA2ui(
      surfaceId,
      'flight.search',
      '飞常准查询参数不足',
      '飞常准查询需要明确的日期，并提供航班号，或提供出发城市和到达城市。',
      ['示例：明天北京到上海航班', '示例：2026-06-10 深圳到杭州机票价格', '示例：明天 MU2157 航班'],
      ['补充日期', '补充城市']
    );
  }

  let requestBody = '';
  let routeText = '';
  if (flightNumber.length > 0) {
    requestBody = '{"endpoint":"flight","params":{"fnum":' + JSON.stringify(flightNumber) +
      ',"date":' + JSON.stringify(date) + '}}';
    routeText = flightNumber + ' ' + date;
  } else if (wantsPrice) {
    requestBody = '{"endpoint":"getFlightPriceByCities","params":{"dep_city":' + JSON.stringify(flightRoute.depCode) +
      ',"arr_city":' + JSON.stringify(flightRoute.arrCode) +
      ',"dep_date":' + JSON.stringify(date) +
      ',"price_mode":"lowest"}}';
    routeText = flightRoute.routeNames[0] + ' 到 ' + flightRoute.routeNames[1] + ' ' + date;
  } else {
    requestBody = '{"endpoint":"flights","params":{"depcity":' + JSON.stringify(flightRoute.depCode) +
      ',"arrcity":' + JSON.stringify(flightRoute.arrCode) +
      ',"date":' + JSON.stringify(date) + '}}';
    routeText = flightRoute.routeNames[0] + ' 到 ' + flightRoute.routeNames[1] + ' ' + date;
  }

  const endpoint = localProviderConfig.variflightApiUrl.length > 0 ? localProviderConfig.variflightApiUrl : DEFAULT_VARIFLIGHT_API_URL;
  aiLogInfo('[AIPhone][LocalToolFlightRequest] endpoint=' + endpoint + ' keyChars=' + apiKey.length.toString() + ' bodyChars=' + requestBody.length.toString());
  const response = await postJsonText(endpoint, {
    'Content-Type': 'application/json',
    'X-VARIFLIGHT-KEY': apiKey
  }, requestBody);

  let payload: FlightProviderPayload = {};
  try {
    payload = JSON.parse(response.text) as FlightProviderPayload;
  } catch (_error) {
    return errorA2ui(
      surfaceId,
      'flight.search',
      '飞常准返回格式异常',
      '飞常准返回的内容不是 JSON。为避免编造航班信息，当前只展示原始返回摘要。',
      [response.text.substring(0, 700)],
      ['重新查询', '检查供应商返回']
    );
  }

  if (response.code < 200 || response.code >= 300) {
    return errorA2ui(
      surfaceId,
      'flight.search',
      '飞常准航班查询失败',
      '飞常准返回 HTTP ' + response.code.toString() + '。这是设备本机直接调用供应商的结果，不是 Mac gateway 连接失败。',
      [response.text.substring(0, 700)],
      ['重新查询', '检查飞常准 Key']
    );
  }

  const providerError = extractProviderError(payload);
  if (providerError.length > 0) {
    return errorA2ui(
      surfaceId,
      'flight.search',
      '飞常准 Key 或参数需要检查',
      providerError,
      [requestBody.substring(0, 240)],
      ['检查 Key', '换日期或城市']
    );
  }

  const results = flightResultsFromPayload(payload);
  const flights: A2uiFlightData[] = [];
  const count = results.length > 8 ? 8 : results.length;
  for (let index = 0; index < count; index++) {
    const record = flightRecordForA2ui(results[index]);
    if (record.status.length === 0) {
      record.status = '计划';
    }
    if (flightRecordHasData(record)) {
      flights.push(record);
    }
  }

  aiLogInfo('[AIPhone][LocalToolFlightResult] providerCode=' + response.code.toString() + ' rows=' + results.length.toString() + ' returned=' + flights.length.toString());
  if (flights.length === 0) {
    return errorA2ui(
      surfaceId,
      'flight.search',
      '飞常准未返回航班列表',
      '供应商请求成功，但返回体里没有可渲染的航班列表。为避免编造航班信息，当前只展示原始返回摘要。',
      [response.text.substring(0, 700)],
      ['换日期或城市', '检查供应商返回结构']
    );
  }

  return flightResultA2ui(
    surfaceId,
    wantsPrice ? '飞常准航班价格查询' : '飞常准航班查询',
    '以下为设备本机直连飞常准返回的查询结果。',
    '已通过飞常准查询到 ' + routeText + ' 的航班信息。',
    flights
  );
}

function parseCoordinatePair(text: string): string {
  const match = /(-?\d{2,3}\.\d+)\s*,\s*(-?\d{1,2}\.\d+)/.exec(text);
  if (match === null) {
    return '';
  }
  return match[1] + ',' + match[2];
}

function defaultConfiguredLocation(): string {
  return parseCoordinatePair(localProviderConfig.amapDefaultLocation);
}

function extractFoodQuery(source: string): FoodQuery {
  const cleaned = source.trim().replace(/^帮我(?:搜索|查|找|搜)?/u, '').trim();
  const nearPatterns: RegExp[] = [
    /^(.+?)附近(?:的)?(.+)$/u,
    /^(.+?)周边(?:的)?(.+)$/u,
    /^(.+?)周围(?:的)?(.+)$/u
  ];
  for (let index = 0; index < nearPatterns.length; index++) {
    const match = nearPatterns[index].exec(cleaned);
    if (match !== null && match[1].trim().length > 0 && match[2].trim().length > 0) {
      return {
        place: match[1].trim(),
        keyword: match[2].trim()
      };
    }
  }
  return {
    place: '',
    keyword: ''
  };
}

function extractFoodKeyword(source: string): string {
  const query = extractFoodQuery(source);
  if (query.keyword.length > 0) {
    return query.keyword;
  }
  const preset = /椰子鸡|椰子|火锅|烧烤|咖啡|奶茶|晚餐|午餐|早餐|快餐|餐厅|饭店|美食/u.exec(source);
  if (preset !== null) {
    return preset[0];
  }
  return '餐饮';
}

function inferAmapCityFromPlace(place: string): string {
  const match = /^(北京|上海|天津|重庆|深圳|广州|杭州|成都|武汉|南京|西安|东莞|佛山)/u.exec(place);
  return match === null ? '' : match[1];
}

function isLandmarkPlace(place: string): boolean {
  return /华为|基地|园区|总部|云谷|大学|医院|站|广场|大厦|小区/u.test(place);
}

async function amapJsonGet(url: string): Promise<AmapPayload> {
  const response = await requestText(url, userAgentHeaders());
  if (response.code < 200 || response.code >= 300) {
    throw new Error('Amap HTTP ' + response.code.toString());
  }
  return JSON.parse(response.text) as AmapPayload;
}

async function geocodeAmapAddress(address: string, key: string): Promise<AmapLocationResolution> {
  const trimmed = address.trim();
  if (trimmed.length === 0 || key.length === 0) {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const city = inferAmapCityFromPlace(trimmed);
  const payload = await amapJsonGet(buildQueryUrl(
    'https://restapi.amap.com/v3/geocode/geo',
    ['key', 'address', 'city'],
    [key, trimmed, city]
  ));
  if (textOf(payload.status) !== '1') {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const geocodes = payload.geocodes === undefined ? [] : payload.geocodes;
  if (geocodes.length === 0) {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const first = geocodes[0];
  return {
    location: textOf(first.location),
    locationSource: 'geocode',
    locationLabel: firstText([first.formatted_address, first.level])
  };
}

async function searchAmapPoiLocation(keywords: string, city: string, key: string): Promise<AmapLocationResolution> {
  const trimmed = keywords.trim();
  if (trimmed.length === 0 || key.length === 0) {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const payload = await amapJsonGet(buildQueryUrl(
    'https://restapi.amap.com/v3/place/text',
    ['key', 'keywords', 'city', 'offset', 'page'],
    [key, trimmed, city, '5', '1']
  ));
  if (textOf(payload.status) !== '1') {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const pois = payload.pois === undefined ? [] : payload.pois;
  if (pois.length === 0) {
    return { location: '', locationSource: 'none', locationLabel: '' };
  }
  const first = pois[0];
  return {
    location: textOf(first.location),
    locationSource: 'poi_text',
    locationLabel: firstText([first.name, first.address])
  };
}

async function resolveFoodSearchLocation(place: string, key: string): Promise<AmapLocationResolution> {
  const city = inferAmapCityFromPlace(place).length > 0 ? inferAmapCityFromPlace(place) : '深圳';
  if (isLandmarkPlace(place)) {
    const poi = await searchAmapPoiLocation(place, city, key);
    if (poi.location.length > 0) {
      return poi;
    }
  }
  const geo = await geocodeAmapAddress(place, key);
  if (geo.location.length > 0) {
    return geo;
  }
  const poi = await searchAmapPoiLocation(place, city, key);
  if (poi.location.length > 0) {
    return poi;
  }
  return { location: '', locationSource: 'none', locationLabel: '' };
}

function foodRecordForA2ui(item: AmapPoi): A2uiFoodData {
  const distance = textOf(item.distance);
  return {
    name: textOf(item.name),
    category: textOf(item.type),
    address: textOf(item.address),
    distance: distance.length > 0 ? distance + '米' : ''
  };
}

async function callLocalFoodSearch(prompt: string, surfaceId: string): Promise<string> {
  const key = localProviderConfig.amapKey;
  if (key.length === 0) {
    return missingConfigA2ui(surfaceId, 'food.search');
  }

  const query = extractFoodQuery(prompt);
  let locationSource = 'none';
  let location = parseCoordinatePair(prompt);
  if (location.length > 0) {
    locationSource = 'prompt_coords';
  } else if (query.place.length > 0) {
    const resolved = await resolveFoodSearchLocation(query.place, key);
    location = resolved.location;
    locationSource = resolved.locationSource;
  }
  if (location.length === 0) {
    location = defaultConfiguredLocation();
    if (location.length > 0) {
      locationSource = 'rawfile_default';
    }
  }
  const keyword = extractFoodKeyword(prompt);
  aiLogInfo('[AIPhone][LocalToolAmapRequest] keyChars=' + key.length.toString() +
    ' locationSource=' + locationSource + ' locationPresent=' + (location.length > 0 ? 'true' : 'false') +
    ' keyword=' + keyword);

  if (location.length === 0) {
    return errorA2ui(
      surfaceId,
      'food.search',
      '需要位置或默认坐标',
      '高德周边搜索需要经纬度。请在 prompt 中写明「地点附近的餐饮」，或把 AMAP_DEFAULT_LOCATION=经度,纬度 同步到 HAP 本地 rawfile 配置。',
      ['需要 AMAP_KEY', '需要地点文本或 AMAP_DEFAULT_LOCATION'],
      ['配置默认坐标', '换查询位置']
    );
  }

  const payload = await amapJsonGet(buildQueryUrl(
    'https://restapi.amap.com/v3/place/around',
    ['key', 'location', 'types', 'keywords', 'radius', 'offset', 'page', 'extensions'],
    [key, location, '050000', keyword, localProviderConfig.amapRadius, '10', '1', 'all']
  ));
  if (textOf(payload.status) !== '1') {
    const providerMessage = firstText([payload.info, payload.infocode, payload.message]);
    return errorA2ui(
      surfaceId,
      'food.search',
      '高德餐饮查询失败',
      providerMessage.length > 0 ? providerMessage : JSON.stringify(payload).substring(0, 500),
      ['检查 AMAP_KEY', '检查坐标和配额'],
      ['重新配置 Key']
    );
  }

  const pois = payload.pois === undefined ? [] : payload.pois;
  const foods: A2uiFoodData[] = [];
  const names: string[] = [];
  for (let index = 0; index < pois.length && foods.length < 8; index++) {
    const food = foodRecordForA2ui(pois[index]);
    if (food.name.length === 0 || names.indexOf(food.name) >= 0) {
      continue;
    }
    names.push(food.name);
    foods.push(food);
  }

  aiLogInfo('[AIPhone][LocalToolAmapResult] pois=' + pois.length.toString() + ' returned=' + foods.length.toString());
  if (foods.length === 0) {
    return foodResultA2ui(
      surfaceId,
      '附近餐饮选择',
      '高德返回成功，但没有可展示的餐饮 POI。',
      '已通过高德查询附近餐饮，暂无可展示结果。',
      []
    );
  }

  return foodResultA2ui(
    surfaceId,
    '附近餐饮选择',
    '以下为设备本机直连高德返回的周边餐饮结果。',
    '已通过高德查询到附近餐饮 POI。',
    foods
  );
}

async function callLocalTrainSearch(prompt: string, surfaceId: string): Promise<string> {
  const source = prompt;
  const stations = await load12306Stations();
  const routeNames = extractRouteNames(source, stations.names);
  const date = parseTravelDate(source);
  const departAfter = parseDepartAfter(source);
  if (routeNames.length < 2 || date.length === 0) {
    return errorA2ui(
      surfaceId,
      'train.search',
      '12306 查询参数不足',
      '我可以在设备本机直接查 12306 余票，但需要明确的出发地、目的地和日期。',
      ['示例：明天北京到上海高铁票', '示例：2026-06-10 北京南到上海虹桥'],
      ['补充日期', '补充城市']
    );
  }

  const fromName = normalizeTrainStationName(routeNames[0], source);
  const toName = normalizeTrainStationName(routeNames[1], source);
  const fromCode = stationCodeFor(fromName, stations).length > 0 ? stationCodeFor(fromName, stations) : stationCodeFor(routeNames[0], stations);
  const toCode = stationCodeFor(toName, stations).length > 0 ? stationCodeFor(toName, stations) : stationCodeFor(routeNames[1], stations);
  if (fromCode.length === 0 || toCode.length === 0) {
    return errorA2ui(
      surfaceId,
      'train.search',
      '车站识别失败',
      '请使用更完整的车站名，例如北京南、上海虹桥、广州南、深圳北。',
      routeNames,
      ['补充车站名']
    );
  }

  const init = await requestText('https://kyfw.12306.cn/otn/leftTicket/init', userAgentHeaders());
  const cookieHeader = cookieHeaderFromRaw(init.cookies + '\n' + init.headers);
  aiLogInfo('[AIPhone][LocalTool12306Request] from=' + fromName + '(' + fromCode + ') to=' + toName + '(' + toCode + ') date=' + date + ' initCode=' + init.code.toString() + ' cookieChars=' + cookieHeader.length.toString() + ' headerChars=' + init.headers.length.toString());
  const response = await request12306LeftTicket(date, fromCode, toCode, leftTicketHeaders(cookieHeader));
  if (response.code < 200 || response.code >= 300) {
    return errorA2ui(
      surfaceId,
      'train.search',
      '12306 查询失败',
      '12306 返回 HTTP ' + response.code.toString() + '。这是供应商或网络返回，不是 Mac gateway 连接失败。',
      [response.text.substring(0, 500)],
      ['重新查询', '换日期或车站']
    );
  }

  const payload = JSON.parse(response.text) as LeftTicketPayload;
  const result = payload.data === undefined ? [] : payload.data.result;
  const rows = Array.isArray(result) ? result : [];
  let parsed: A2uiTrainData[] = [];
  rows.forEach((row: string) => {
    parsed.push(parse12306Row(row, stations));
  });
  parsed = filterHighSpeed(source, parsed);
  parsed = filterTrainsByDepartAfter(parsed, departAfter);

  const top: A2uiTrainData[] = [];
  const count = parsed.length > TRAIN_RESULT_LIMIT ? TRAIN_RESULT_LIMIT : parsed.length;
  for (let index = 0; index < count; index++) {
    top.push(normalizeTrainRecord(parsed[index]));
  }

  const timeSummary = departAfter.length > 0 ? departAfter + ' 后' : '';
  if (top.length === 0) {
    const emptyBody = timeSummary.length > 0
      ? date + ' ' + fromName + ' 到 ' + toName + ' ' + timeSummary + '暂时没有查询到可展示车次，可尝试调整时段或日期。'
      : date + ' ' + fromName + ' 到 ' + toName + ' 暂时没有查询到可展示车次，可能是日期未开售、线路调整或接口限制。';
    return trainResultA2ui(surfaceId, '12306 查询结果为空', emptyBody, '12306 暂无可展示车次。', []);
  }

  const summaryText = timeSummary.length > 0
    ? '已从 12306 查询到 ' + date + ' ' + fromName + ' 到 ' + toName + ' ' + timeSummary + '的车次。'
    : '已从 12306 查询到 ' + date + ' ' + fromName + ' 到 ' + toName + ' 的车次。';
  const body = timeSummary.length > 0
    ? '以下为 ' + timeSummary + '出发的 12306 实时查询结果，默认先展示 ' + TRAIN_INITIAL_VISIBLE.toString() + ' 趟。'
    : '以下为 12306 实时查询结果摘要，默认先展示 ' + TRAIN_INITIAL_VISIBLE.toString() + ' 趟。';
  aiLogInfo('[AIPhone][LocalTool12306Result] rows=' + rows.length.toString() + ' filtered=' + parsed.length.toString() + ' returned=' + top.length.toString());
  return trainResultA2ui(surfaceId, '12306 余票查询', body, summaryText, top);
}

async function buildLocalToolJsonl(toolId: string, prompt: string, surfaceId: string): Promise<string> {
  if (toolId === 'flight.search') {
    return callLocalFlightSearch(prompt, surfaceId);
  }
  if (toolId === 'train.search') {
    return callLocalTrainSearch(prompt, surfaceId);
  }
  if (toolId === 'food.search') {
    return callLocalFoodSearch(prompt, surfaceId);
  }
  return missingConfigA2ui(surfaceId, toolId);
}

async function callLocalTool(toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null): Promise<A2uiCallResult> {
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }
  let rawResponse = '';
  const localDebugBody: ToolGatewayRequestBody = {
    toolId: toolId,
    prompt: prompt,
    surfaceId: surfaceId,
    actionId: actionId,
    stream: false,
    a2uiClientCapabilities: defaultA2uiCapabilities()
  };
  const localDebugPayload: ToolRequestDebug = {
    endpoint: LOCAL_TOOL_GATEWAY_URL,
    body: localDebugBody
  };
  const requestDebug = JSON.stringify(localDebugPayload);
  aiLogInfo('[AIPhone][LocalToolRequest] endpoint=' + LOCAL_TOOL_GATEWAY_URL + ' toolId=' + toolId + ' surfaceId=' + surfaceId + ' promptChars=' + prompt.length.toString());
  const pending = pendingA2ui(toolId, prompt, surfaceId);
  rawResponse += pending;
  let parsed = parseA2uiJsonl(pending);
  let streamError = parsed.error;
  if (streamError.length === 0) {
    streamError = applyEnvelopes(store, parsed.envelopes);
    onSurface(store.getSurface(), rawResponse);
  }

  try {
    const resultJsonl = await buildLocalToolJsonl(toolId, prompt, surfaceId);
    rawResponse += resultJsonl;
    parsed = parseA2uiJsonl(resultJsonl);
    if (parsed.error.length > 0 && streamError.length === 0) {
      streamError = parsed.error;
    }
    if (streamError.length === 0) {
      streamError = applyEnvelopes(store, parsed.envelopes);
    }
    onSurface(store.getSurface(), rawResponse);
    aiLogInfo('[AIPhone][LocalToolResult] ok=' + (streamError.length === 0 ? 'true' : 'false') + ' rawChars=' + rawResponse.length.toString());
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][LocalToolException] ' + message);
    const exceptionJsonl = errorA2ui(
      surfaceId,
      toolId,
      '工具供应商调用异常',
      message,
      ['本机工具已运行，但真实供应商调用失败。', '请检查设备网络、供应商 TLS/接口状态，或稍后重试。'],
      ['重新查询']
    );
    rawResponse += exceptionJsonl;
    parsed = parseA2uiJsonl(exceptionJsonl);
    streamError = parsed.error.length > 0 ? parsed.error : applyEnvelopes(store, parsed.envelopes);
    onSurface(store.getSurface(), rawResponse);
    return {
      ok: streamError.length === 0,
      raw: rawResponse,
      error: streamError,
      requestDebug: requestDebug,
      assistantDebug: '',
      surface: store.getSurface()
    };
  }
}

export async function callToolGateway(baseUrl: string, toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null): Promise<A2uiCallResult> {
  const endpoint = buildToolGatewayUrl(baseUrl);
  if (isLocalToolGatewayUrl(endpoint)) {
    return callLocalTool(toolId, prompt, surfaceId, actionId, onSurface, initialSurface);
  }

  const request = http.createHttp();
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }
  const decoder = util.TextDecoder.create('utf-8');
  let rawResponse = '';
  let remainder = '';
  let streamError = '';
  let envelopeCount = 0;
  let streamEndResolve: () => void = () => {};
  let streamEnded = false;
  const finishStream = (): void => {
    if (!streamEnded) {
      streamEnded = true;
      streamEndResolve();
    }
  };
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
  const debugPayload: ToolRequestDebug = {
    endpoint: endpoint,
    body: body
  };
  const requestDebug = JSON.stringify(debugPayload);
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
    } else {
      envelopeCount += parsed.envelopes.length;
      const applyError = applyEnvelopes(store, parsed.envelopes);
      if (applyError.length > 0) {
        streamError = applyError;
        aiLogError('[AIPhone][ToolGatewayApplyError] ' + applyError);
      }
      if (parsed.envelopes.length > 0) {
        aiLogInfo('[AIPhone][ToolGatewayEnvelopes] count=' + parsed.envelopes.length.toString());
      }
      onSurface(store.getSurface(), rawResponse);
    }
  });
  request.on('dataEnd', () => {
    finishStream();
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
    finishStream();
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
      if (envelopeCount === 0) {
        store.applyError('工具返回格式异常', streamError);
      }
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
    aiLogError('[AIPhone][ToolGatewayException] endpoint=' + endpoint + ' error=' + message);
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
