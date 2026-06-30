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
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiTravelOptionData,
  A2uiTrainData,
  defaultA2uiCapabilities,
  emptyA2uiSurface
} from './A2uiTypes';
import { parseA2uiJsonl, parseA2uiJsonlChunk } from './A2uiParser';
import { A2uiSurfaceStore } from './A2uiSurfaceStore';
import { A2uiSurfaceThrottle } from './A2uiSurfaceThrottle';
import { A2uiSurfaceCallback } from './LocalModelClient';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { connectCardA2ui, genericToolResultsA2ui, unsupportedTransportA2ui } from './DynamicToolA2ui';
import { AssetCredentialStore, CredentialStore, credentialRefFor } from './DynamicCredentialStore';
import {
  GMAIL_MCP_AUTH_SETUP_URL,
  GMAIL_MCP_SERVER_URL,
  GOOGLE_OAUTH_SETUP_URL,
  calendarAuthRequiredA2ui,
  gmailAuthRequiredA2ui,
  gmailBlockedSendA2ui,
  gmailDraftPreviewA2ui,
  gmailOpenWebA2ui,
  gmailThreadResultsA2ui
} from './GmailToolA2ui';
import { mailDraftPreviewA2ui, mailResultsA2ui, mailResultsFromDynamicA2ui } from './MailToolA2ui';
import { MailDraftArgs, MailProviderStatus, MailSearchArgs, MailThreadResult } from './MailToolTypes';
import {
  GMAIL_ACCESS_TOKEN_REF,
  GMAIL_DEFAULT_REDIRECT_URI,
  GMAIL_MCP_RESOURCE,
  GOOGLE_CLOUD_OAUTH_SCOPES,
  GmailOAuthConfig,
  buildGmailOAuthAuthorizationUrl,
  createGmailOAuthPending,
  gmailMcpArgsForPrompt,
  gmailMcpToolNameForToolId,
  gmailPkceChallengeS256,
  isGmailAccessTokenFresh,
  loadGmailOAuthTokenSet,
  refreshGmailOAuthAccessToken,
  saveGmailOAuthPending,
  saveGmailOAuthTokenSet
} from './GmailOAuthClient';
import { GenericMcpClient } from './GenericMcpClient';
import { callGmailApiTool } from './GmailApiClient';
import { callYouTubeVideoSearch } from './YouTubeApiClient';
import { callMediaVideoSearch, mediaVideoQueryFromArgs } from './MediaVideoClient';
import { callCalendarTool } from './CalendarApiClient';
import { callMapsPlaceDetails, callMapsPlaceSearch, mapsFoodRecordFromResult } from './MapsApiClient';
import { QqMailConfig, QqMailImapClient } from './QqMailImapClient';
import { discoverDynamicToolForPrompt, DynamicToolDiscoveryResult } from './DynamicToolDiscovery';
import { DynamicToolRegistry, isBuiltInToolId, isUnsafeMcpTool, selectBestRemoteTransport } from './DynamicToolRegistry';
import { sampleManifestForToolId } from './DynamicToolSamples';
import { isCalendarToolId, isGmailToolId, isKnownDomainToolId, isMailToolId, isMapsToolId, isMediaToolId, isYouTubeToolId } from './ToolDefinitionRegistry';
import {
  DynamicCredentialSpec,
  DynamicGenericToolResult,
  DynamicToolManifest,
  DynamicToolRegistration,
  DynamicToolTransport
} from './DynamicToolTypes';
import {
  A2uiPartialDataPatch,
  A2uiPartialRenderState,
  A2uiPartialUpdateCache,
  A2uiPartialUpdateResult,
  planA2uiPartialUpdate
} from './A2uiPartialUpdatePlanner';

interface ToolGatewayRequestBody {
  toolId: string;
  prompt: string;
  surfaceId: string;
  actionId: string;
  args?: Object;
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
  'Authorization'?: string;
  'MCP-Protocol-Version'?: string;
  'Mcp-Session-Id'?: string;
  'X-VARIFLIGHT-KEY'?: string;
  'Content-MD5'?: string;
  'S-Ca-App'?: string;
  'S-Ca-Signature'?: string;
  'S-Ca-Timestamp'?: string;
  'S-Ca-Signature-Headers'?: string;
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
  tencentMapKey: string;
  tencentMapApiUrl: string;
  baiduMapAk: string;
  baiduMapApiUrl: string;
  meituanUnionAppKey: string;
  meituanUnionAppSecret: string;
  meituanUnionApiUrl: string;
  taobaoAppKey: string;
  taobaoAppSecret: string;
  taobaoFlashPid: string;
  taobaoApiUrl: string;
  mcdMcpToken: string;
  mcdMcpUrl: string;
  luckinMcpToken: string;
  luckinMcpUrl: string;
  googleMapsApiKey: string;
  googleOauthClientId: string;
  googleOauthClientSecret: string;
  googleOauthRedirectUri: string;
  gmailAuthUrl: string;
  gmailOauthClientId: string;
  gmailOauthClientSecret: string;
  gmailOauthRedirectUri: string;
  gmailMcpUserProject: string;
  youtubeApiKey: string;
  qqMailAddress: string;
  qqMailAuthCode: string;
  qqMailImapHost: string;
  qqMailImapPort: string;
  qqMailDraftsMailbox: string;
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
  TENCENT_MAP_KEY?: string;
  TENCENT_MAP_API_URL?: string;
  BAIDU_MAP_AK?: string;
  BAIDU_MAP_API_URL?: string;
  MEITUAN_UNION_APP_KEY?: string;
  MEITUAN_UNION_APP_SECRET?: string;
  MEITUAN_UNION_API_URL?: string;
  TAOBAO_APP_KEY?: string;
  TAOBAO_APP_SECRET?: string;
  TAOBAO_FLASH_PID?: string;
  TAOBAO_API_URL?: string;
  MCD_MCP_TOKEN?: string;
  MCD_MCP_URL?: string;
  LUCKIN_MCP_TOKEN?: string;
  LUCKIN_MCP_URL?: string;
  GOOGLE_MAPS_API_KEY?: string;
  GMAIL_AUTH_URL?: string;
  GMAIL_OAUTH_CLIENT_ID?: string;
  GOOGLE_OAUTH_CLIENT_ID?: string;
  GMAIL_OAUTH_CLIENT_SECRET?: string;
  GOOGLE_OAUTH_CLIENT_SECRET?: string;
  GMAIL_OAUTH_REDIRECT_URI?: string;
  GOOGLE_OAUTH_REDIRECT_URI?: string;
  GMAIL_MCP_USER_PROJECT?: string;
  GOOGLE_CLOUD_PROJECT?: string;
  YOUTUBE_API_KEY?: string;
  QQ_MAIL_ADDRESS?: string;
  QQ_MAIL_AUTH_CODE?: string;
  QQ_MAIL_IMAP_HOST?: string;
  QQ_MAIL_IMAP_PORT?: string;
  QQ_MAIL_DRAFTS_MAILBOX?: string;
  flightMcpKey?: string;
  variflightApiUrl?: string;
  amapKey?: string;
  amapDefaultLocation?: string;
  amapRadius?: string;
  tencentMapKey?: string;
  tencentMapApiUrl?: string;
  baiduMapAk?: string;
  baiduMapApiUrl?: string;
  meituanUnionAppKey?: string;
  meituanUnionAppSecret?: string;
  meituanUnionApiUrl?: string;
  taobaoAppKey?: string;
  taobaoAppSecret?: string;
  taobaoFlashPid?: string;
  taobaoApiUrl?: string;
  mcdMcpToken?: string;
  mcdMcpUrl?: string;
  luckinMcpToken?: string;
  luckinMcpUrl?: string;
  googleMapsApiKey?: string;
  googleOauthClientId?: string;
  googleOauthClientSecret?: string;
  googleOauthRedirectUri?: string;
  gmailAuthUrl?: string;
  gmailOauthClientId?: string;
  gmailOauthClientSecret?: string;
  gmailOauthRedirectUri?: string;
  gmailMcpUserProject?: string;
  youtubeApiKey?: string;
  qqMailAddress?: string;
  qqMailAuthCode?: string;
  qqMailImapHost?: string;
  qqMailImapPort?: string;
  qqMailDraftsMailbox?: string;
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

export interface FlightProviderRecord {
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

interface AmapWeatherLive {
  province?: string;
  city?: string;
  adcode?: string;
  weather?: string;
  temperature?: string;
  winddirection?: string;
  windpower?: string;
  humidity?: string;
  reporttime?: string;
}

interface AmapWeatherCast {
  date?: string;
  week?: string;
  dayweather?: string;
  nightweather?: string;
  daytemp?: string;
  nighttemp?: string;
  daywind?: string;
  nightwind?: string;
  daypower?: string;
  nightpower?: string;
}

interface AmapWeatherForecast {
  province?: string;
  city?: string;
  adcode?: string;
  reporttime?: string;
  casts?: AmapWeatherCast[];
}

interface AmapWeatherPayload {
  status?: string;
  info?: string;
  infocode?: string;
  lives?: AmapWeatherLive[];
  forecasts?: AmapWeatherForecast[];
}

export interface TencentMapPlace {
  title?: string;
  address?: string;
  category?: string;
  _distance?: string | number;
  distance?: string | number;
  location?: FoodMapPoint;
}

interface TencentMapPayload {
  status?: string | number;
  message?: string;
  data?: TencentMapPlace[];
}

export interface BaiduPlaceDetailInfo {
  tag?: string;
  distance?: string | number;
  overall_rating?: string | number;
  price?: string | number;
}

export interface BaiduPlace {
  name?: string;
  address?: string;
  location?: FoodMapPoint;
  detail_info?: BaiduPlaceDetailInfo;
}

interface BaiduPlacePayload {
  status?: string | number;
  message?: string;
  results?: BaiduPlace[];
}

export interface FoodProviderResult {
  provider: string;
  foods: A2uiFoodData[];
  error: string;
}

export interface FoodAggregationResult {
  foods: A2uiFoodData[];
  issues: FoodProviderResult[];
}

export interface FoodProviderStreamResult {
  aggregation: FoodAggregationResult;
  results: FoodProviderResult[];
}

export interface FoodProviderPartialSnapshot {
  provider: string;
  completed: number;
  total: number;
  foods: A2uiFoodData[];
  issues: FoodProviderResult[];
  results: FoodProviderResult[];
}

interface FoodProviderAdapter {
  name: string;
  search(prompt: string, query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult>;
}

export interface MeituanUnionBrandInfo {
  brandName?: string;
  brandLogoUrl?: string;
}

export interface MeituanUnionCouponPackDetail {
  name?: string;
  sellPrice?: string;
  saleVolume?: string;
  productName?: string;
}

export interface MeituanUnionDeliverablePoiInfo {
  poiName?: string;
  deliveryDistance?: string;
  distributionCost?: string;
  deliveryDuration?: string;
  lastDeliveryFee?: string;
}

export interface MeituanUnionRecord {
  brandInfo?: MeituanUnionBrandInfo;
  couponPackDetail?: MeituanUnionCouponPackDetail;
  deliverablePoiInfo?: MeituanUnionDeliverablePoiInfo;
  brandName?: string;
  name?: string;
  title?: string;
  categoryName?: string;
  deliveryDistance?: string;
  distributionCost?: string;
  deliveryDuration?: string;
  lastDeliveryFee?: string;
}

interface MeituanUnionPayload {
  code?: string | number;
  status?: string | number;
  message?: string;
  msg?: string;
  error?: string;
  data?: MeituanUnionRecord[] | MeituanUnionRecordContainer;
  result?: MeituanUnionRecord[] | MeituanUnionRecordContainer;
}

interface MeituanUnionRecordContainer {
  list?: MeituanUnionRecord[];
  records?: MeituanUnionRecord[];
  items?: MeituanUnionRecord[];
  products?: MeituanUnionRecord[];
}

export interface TaobaoFlashItemRecord {
  title?: string;
  price?: string;
}

export interface TaobaoFlashStoreRecord {
  title?: string;
  shop_name?: string;
  name?: string;
  category_1_name?: string;
  category_name?: string;
  delivery_distance?: string | number;
  distance?: string | number;
  delivery_time?: string | number;
  delivery_price?: string | number;
  service_rating?: string | number;
  rating?: string | number;
  items?: TaobaoFlashItemRecord[];
  item_list?: TaobaoFlashItemRecord[];
}

interface TaobaoFlashPayload {
  error_response?: TaobaoErrorResponse;
  alibaba_alsc_union_eleme_promotion_storepromotion_query_response?: TaobaoFlashResponse;
}

interface TaobaoErrorResponse {
  code?: string | number;
  sub_code?: string;
  msg?: string;
  sub_msg?: string;
}

interface TaobaoFlashResponse {
  result?: TaobaoFlashResult;
  data?: TaobaoFlashResult | TaobaoFlashStoreRecord[];
}

interface TaobaoFlashResult {
  success?: boolean | string;
  msg_info?: string;
  msg_code?: string;
  result_list?: TaobaoFlashStoreRecord[];
  records?: TaobaoFlashStoreRecord[];
  data?: TaobaoFlashStoreRecord[];
}

interface McpJsonRpcResponse {
  result?: McpToolResult;
  error?: McpJsonRpcError;
}

interface McpJsonRpcError {
  code?: string | number;
  message?: string;
  data?: Object | string | number | boolean;
}

interface McpToolResult {
  content?: McpContentItem[];
  structuredContent?: Object;
  isError?: boolean;
}

interface McpContentItem {
  type?: string;
  text?: string;
  data?: Object | string | number | boolean;
}

class EmptyMcpCapabilities {}

interface McpInitializeClientInfo {
  name: string;
  version: string;
}

interface McpInitializeParams {
  protocolVersion: string;
  capabilities: EmptyMcpCapabilities;
  clientInfo: McpInitializeClientInfo;
}

interface McpInitializeRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: McpInitializeParams;
}

interface McpInitializedNotification {
  jsonrpc: string;
  method: string;
}

interface McpToolCallParams {
  name: string;
  arguments: Object;
}

interface McpToolCallRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: McpToolCallParams;
}

interface McDonaldsNearbyStoresArgs {
  searchType: number;
  beType: number;
  city: string;
  keyword: string;
}

interface McDonaldsMealsArgs {
  storeCode: string;
  beCode: string;
  orderType: number;
  beType: number;
}

interface LuckinShopListArgs {
  deptName: string;
  longitude: number;
  latitude: number;
}

interface LuckinProductSearchArgs {
  deptId: number;
  query: string;
}

type McDonaldsMcpData =
  McDonaldsStoreRecord[] |
  McDonaldsStoreContainer |
  McDonaldsMealsData |
  McDonaldsMealRecord |
  McDonaldsCouponRecord[] |
  McDonaldsCouponContainer |
  McDonaldsPriceData;

interface McDonaldsPayload {
  success?: boolean | string;
  code?: string | number;
  message?: string;
  data?: McDonaldsMcpData;
  result?: McDonaldsMcpData;
}

interface McDonaldsStoreRecord {
  storeName?: string;
  name?: string;
  address?: string;
  distance?: string | number;
  storeCode?: string;
  beCode?: string;
  businessStatus?: boolean | string | number;
  businessStartTime?: string;
  businessEndTime?: string;
}

interface McDonaldsStoreContainer {
  list?: McDonaldsStoreRecord[];
  records?: McDonaldsStoreRecord[];
  items?: McDonaldsStoreRecord[];
  products?: McDonaldsStoreRecord[];
  data?: McDonaldsStoreRecord[];
  result?: McDonaldsStoreRecord[];
}

interface McDonaldsCategoryRecord {
  name?: string;
  meals?: McDonaldsCategoryMeal[];
}

interface McDonaldsCategoryMeal {
  code?: string;
  tags?: string[];
}

interface McDonaldsMealRecord {
  name?: string;
  currentPrice?: string | number;
  price?: string | number;
  tags?: string[];
}

interface McDonaldsMealsData {
  categories?: McDonaldsCategoryRecord[];
  meals?: McDonaldsMealsMap | McDonaldsMealRecord[];
}

interface McDonaldsMealsMap {
}

interface McDonaldsMealEntry {
  code: string;
  meal: McDonaldsMealRecord;
}

interface McDonaldsCouponRecord {
  title?: string;
  name?: string;
  couponCode?: string;
  couponId?: string;
  tradeDateTime?: string;
  products?: McDonaldsCouponProduct[];
}

interface McDonaldsCouponProduct {
  productName?: string;
  productCode?: string;
}

interface McDonaldsCouponContainer {
  list?: McDonaldsCouponRecord[];
  records?: McDonaldsCouponRecord[];
  items?: McDonaldsCouponRecord[];
  products?: McDonaldsCouponRecord[];
  data?: McDonaldsCouponRecord[];
  result?: McDonaldsCouponRecord[];
}

interface McDonaldsPriceData {
  productList?: McDonaldsPriceProduct[];
  price?: string | number;
  discount?: string | number;
  deliveryPrice?: string | number;
}

interface McDonaldsPriceProduct {
  productName?: string;
  productCode?: string;
  quantity?: string | number;
  subtotal?: string | number;
  originalSubtotal?: string | number;
}

type LuckinMcpData =
  LuckinShopRecord[] |
  LuckinShopContainer |
  LuckinProductRecord[] |
  LuckinProductContainer |
  LuckinProductRecord |
  LuckinOrderRecord;

interface LuckinPayload {
  data?: LuckinMcpData;
  result?: LuckinMcpData;
  message?: string;
  msg?: string;
  code?: string | number;
  success?: boolean | string;
}

interface LuckinShopRecord {
  deptId?: string | number;
  deptName?: string;
  name?: string;
  address?: string;
  deptTags?: string[];
  tags?: string[];
  longitude?: string | number;
  latitude?: string | number;
  workTimeStart?: string;
  workTimeEnd?: string;
  distance?: string | number;
  number?: string;
}

interface LuckinShopContainer {
  list?: LuckinShopRecord[];
  records?: LuckinShopRecord[];
  items?: LuckinShopRecord[];
  products?: LuckinShopRecord[];
  data?: LuckinShopRecord[];
  result?: LuckinShopRecord[];
}

interface LuckinProductRecord {
  productId?: string | number;
  productName?: string;
  name?: string;
  skuCode?: string;
  price?: string | number;
  discountPrice?: string | number;
  initPrice?: string | number;
  productAttrs?: LuckinProductAttr[];
  tags?: string[];
}

interface LuckinProductContainer {
  list?: LuckinProductRecord[];
  records?: LuckinProductRecord[];
  items?: LuckinProductRecord[];
  products?: LuckinProductRecord[];
  data?: LuckinProductRecord[];
  result?: LuckinProductRecord[];
}

interface LuckinProductAttr {
  attributeName?: string;
  productSubAttrs?: LuckinProductSubAttr[];
}

interface LuckinProductSubAttr {
  attributeName?: string;
  selected?: boolean | null;
}

interface LuckinOrderRecord {
  orderId?: string | number;
  orderStatusName?: string;
  orderStatus?: string | number;
  shopInfo?: LuckinShopRecord;
  productInfoList?: LuckinProductRecord[];
  orderPayAmount?: string | number;
}

interface FoodParamPair {
  key: string;
  value: string;
}

interface FoodMapPoint {
  lat?: string | number;
  lng?: string | number;
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

interface ToolA2uiSnapshot {
  title: string;
  summary: string;
  error: string;
  trains: A2uiTrainData[];
  flights: A2uiFlightData[];
  rows: A2uiLabelValueData[];
}

const LOCAL_TOOL_GATEWAY_URL: string = 'local://aiphone-tools';
const LOCAL_PROVIDER_CONFIG_RAWFILE: string = 'aiphone_provider_config.json';
const DEFAULT_VARIFLIGHT_API_URL: string = 'https://mcp.variflight.com/api/v1/mcp/data';
const DEFAULT_AMAP_RADIUS: string = '3000';
const DEFAULT_TENCENT_MAP_API_URL: string = 'https://apis.map.qq.com/ws/place/v1/search';
const DEFAULT_BAIDU_MAP_API_URL: string = 'https://api.map.baidu.com/place/v2/search';
const DEFAULT_MEITUAN_UNION_API_URL: string = 'https://media.meituan.com/cps_open/common/api/v1/query_coupon';
const DEFAULT_TAOBAO_API_URL: string = 'https://eco.taobao.com/router/rest';
const DEFAULT_MCD_MCP_URL: string = 'https://mcp.mcd.cn';
const DEFAULT_LUCKIN_MCP_URL: string = 'https://gwmcp.lkcoffee.com/order/user/mcp';
const MCP_PROTOCOL_VERSION: string = '2025-06-18';
const FOOD_PROVIDER_RESULT_LIMIT: number = 10;
const FOOD_AGGREGATED_RESULT_LIMIT: number = 24;
const TRAIN_RESULT_LIMIT: number = 30;
const TRAIN_INITIAL_VISIBLE: number = 6;
const TRAIN_CLIENT_ACTIONS: A2uiAction[] = [
  { id: 'client_show_more', label: '多展示一些', prompt: 'client_show_more', kind: 'client', variant: 'primary' },
  { id: 'client_sort_fastest', label: '选最快的', prompt: 'client_sort_fastest', kind: 'client', variant: 'secondary' },
  { id: 'client_filter_available', label: '只看有票', prompt: 'client_filter_available', kind: 'client', variant: 'secondary' },
  { id: 'client_edit_query', label: '修改查询', prompt: 'client_edit_query', kind: 'input', variant: 'secondary' }
];
const TRAVEL_CLIENT_ACTIONS: A2uiAction[] = [
  { id: 'travel_show_all', label: '全部', prompt: 'travel_show_all', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_train', label: '只看高铁', prompt: 'travel_filter_train', kind: 'client', variant: 'secondary' },
  { id: 'travel_filter_flight', label: '只看飞机', prompt: 'travel_filter_flight', kind: 'client', variant: 'secondary' },
  { id: 'travel_change_date', label: '换日期', prompt: '换日期重新查询出行方案', kind: 'input', variant: 'secondary' },
  { id: 'travel_retry', label: '重新查询', prompt: '重新查询出行方案', kind: 'prompt', variant: 'primary' }
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
  amapRadius: DEFAULT_AMAP_RADIUS,
  tencentMapKey: '',
  tencentMapApiUrl: DEFAULT_TENCENT_MAP_API_URL,
  baiduMapAk: '',
  baiduMapApiUrl: DEFAULT_BAIDU_MAP_API_URL,
  meituanUnionAppKey: '',
  meituanUnionAppSecret: '',
  meituanUnionApiUrl: DEFAULT_MEITUAN_UNION_API_URL,
  taobaoAppKey: '',
  taobaoAppSecret: '',
  taobaoFlashPid: '',
  taobaoApiUrl: DEFAULT_TAOBAO_API_URL,
  mcdMcpToken: '',
  mcdMcpUrl: DEFAULT_MCD_MCP_URL,
  luckinMcpToken: '',
  luckinMcpUrl: DEFAULT_LUCKIN_MCP_URL,
  googleMapsApiKey: '',
  googleOauthClientId: '',
  googleOauthClientSecret: '',
  googleOauthRedirectUri: '',
  gmailAuthUrl: '',
  gmailOauthClientId: '',
  gmailOauthClientSecret: '',
  gmailOauthRedirectUri: '',
  gmailMcpUserProject: '',
  youtubeApiKey: '',
  qqMailAddress: '',
  qqMailAuthCode: '',
  qqMailImapHost: 'imap.qq.com',
  qqMailImapPort: '993',
  qqMailDraftsMailbox: ''
};

export interface LocalToolDebugConfig {
  foodProviderDelayEnabled: boolean;
  foodProviderDelayMs: number;
  foodPartialThrottleMs: number;
}

let localToolDebugConfig: LocalToolDebugConfig = {
  foodProviderDelayEnabled: false,
  foodProviderDelayMs: 0,
  foodPartialThrottleMs: 500
};

type LocalA2uiEmitter = (jsonl: string) => void;

interface MapsToolArgs {
  query?: string;
  textQuery?: string;
  keyword?: string;
  placeId?: string;
  id?: string;
}

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
  if (isKnownDomainToolId(toolId)) {
    return true;
  }
  if (isBuiltInToolId(toolId)) {
    return true;
  }
  if (toolId === 'dynamic.search') {
    return true;
  }
  return sampleManifestForToolId(toolId) !== null;
}

export function configureLocalToolDebugConfig(config: LocalToolDebugConfig): void {
  const delayMs = config.foodProviderDelayMs < 0 ? 0 : config.foodProviderDelayMs;
  const throttleMs = config.foodPartialThrottleMs < 0 ? 0 : config.foodPartialThrottleMs;
  localToolDebugConfig = {
    foodProviderDelayEnabled: config.foodProviderDelayEnabled,
    foodProviderDelayMs: delayMs,
    foodPartialThrottleMs: throttleMs
  };
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
    amapRadius: config.amapRadius.trim().length > 0 ? config.amapRadius.trim() : DEFAULT_AMAP_RADIUS,
    tencentMapKey: config.tencentMapKey.trim(),
    tencentMapApiUrl: config.tencentMapApiUrl.trim().length > 0 ? config.tencentMapApiUrl.trim() : DEFAULT_TENCENT_MAP_API_URL,
    baiduMapAk: config.baiduMapAk.trim(),
    baiduMapApiUrl: config.baiduMapApiUrl.trim().length > 0 ? config.baiduMapApiUrl.trim() : DEFAULT_BAIDU_MAP_API_URL,
    meituanUnionAppKey: config.meituanUnionAppKey.trim(),
    meituanUnionAppSecret: config.meituanUnionAppSecret.trim(),
    meituanUnionApiUrl: config.meituanUnionApiUrl.trim().length > 0 ? config.meituanUnionApiUrl.trim() : DEFAULT_MEITUAN_UNION_API_URL,
    taobaoAppKey: config.taobaoAppKey.trim(),
    taobaoAppSecret: config.taobaoAppSecret.trim(),
    taobaoFlashPid: config.taobaoFlashPid.trim(),
    taobaoApiUrl: config.taobaoApiUrl.trim().length > 0 ? config.taobaoApiUrl.trim() : DEFAULT_TAOBAO_API_URL,
    mcdMcpToken: config.mcdMcpToken.trim(),
    mcdMcpUrl: config.mcdMcpUrl.trim().length > 0 ? config.mcdMcpUrl.trim() : DEFAULT_MCD_MCP_URL,
    luckinMcpToken: config.luckinMcpToken.trim(),
    luckinMcpUrl: config.luckinMcpUrl.trim().length > 0 ? config.luckinMcpUrl.trim() : DEFAULT_LUCKIN_MCP_URL,
    googleMapsApiKey: config.googleMapsApiKey.trim(),
    googleOauthClientId: config.googleOauthClientId.trim(),
    googleOauthClientSecret: config.googleOauthClientSecret.trim(),
    googleOauthRedirectUri: config.googleOauthRedirectUri.trim().length > 0 ? config.googleOauthRedirectUri.trim() : GMAIL_DEFAULT_REDIRECT_URI,
    gmailAuthUrl: config.gmailAuthUrl.trim(),
    gmailOauthClientId: config.gmailOauthClientId.trim(),
    gmailOauthClientSecret: config.gmailOauthClientSecret.trim(),
    gmailOauthRedirectUri: config.gmailOauthRedirectUri.trim().length > 0 ? config.gmailOauthRedirectUri.trim() : GMAIL_DEFAULT_REDIRECT_URI,
    gmailMcpUserProject: config.gmailMcpUserProject.trim(),
    youtubeApiKey: config.youtubeApiKey.trim(),
    qqMailAddress: config.qqMailAddress.trim(),
    qqMailAuthCode: config.qqMailAuthCode.trim(),
    qqMailImapHost: config.qqMailImapHost.trim().length > 0 ? config.qqMailImapHost.trim() : 'imap.qq.com',
    qqMailImapPort: config.qqMailImapPort.trim().length > 0 ? config.qqMailImapPort.trim() : '993',
    qqMailDraftsMailbox: config.qqMailDraftsMailbox.trim()
  };
  aiLogInfo('[AIPhone][LocalProviderConfig] rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ' flightKeyChars=' + localProviderConfig.flightMcpKey.length.toString() +
    ' amapKeyChars=' + localProviderConfig.amapKey.length.toString() +
    ' tencentMapKeyChars=' + localProviderConfig.tencentMapKey.length.toString() +
    ' baiduMapAkChars=' + localProviderConfig.baiduMapAk.length.toString() +
    ' meituanKeyChars=' + localProviderConfig.meituanUnionAppKey.length.toString() +
    ' taobaoKeyChars=' + localProviderConfig.taobaoAppKey.length.toString() +
    ' taobaoPidChars=' + localProviderConfig.taobaoFlashPid.length.toString() +
    ' mcdMcpTokenChars=' + localProviderConfig.mcdMcpToken.length.toString() +
    ' luckinMcpTokenChars=' + localProviderConfig.luckinMcpToken.length.toString() +
    ' googleMapsApiKeyChars=' + localProviderConfig.googleMapsApiKey.length.toString() +
    ' googleOauthClientIdChars=' + localProviderConfig.googleOauthClientId.length.toString() +
    ' gmailOauthClientIdChars=' + localProviderConfig.gmailOauthClientId.length.toString() +
    ' gmailOauthClientSecretChars=' + localProviderConfig.gmailOauthClientSecret.length.toString() +
    ' youtubeApiKeyChars=' + localProviderConfig.youtubeApiKey.length.toString() +
    ' gmailMcpUserProjectPresent=' + (localProviderConfig.gmailMcpUserProject.length > 0 ? 'true' : 'false') +
    ' qqMailAddressPresent=' + (localProviderConfig.qqMailAddress.length > 0 ? 'true' : 'false') +
    ' qqMailAuthCodeChars=' + localProviderConfig.qqMailAuthCode.length.toString() +
    ' defaultLocationPresent=' + (localProviderConfig.amapDefaultLocation.length > 0 ? 'true' : 'false'));
}

export function configureLocalProviderConfigFromRawJson(rawJson: string): void {
  const parsed = JSON.parse(rawJson) as LocalProviderRawConfig;
  configureLocalProviderConfig({
    flightMcpKey: firstText([parsed.FLIGHT_MCP_KEY, parsed.VARIFLIGHT_API_KEY, parsed.X_VARIFLIGHT_KEY, parsed.FLIGHT_API_KEY, parsed.flightMcpKey]),
    variflightApiUrl: firstText([parsed.VARIFLIGHT_API_URL, parsed.FLIGHT_VARIFLIGHT_URL, parsed.variflightApiUrl]),
    amapKey: firstText([parsed.AMAP_KEY, parsed.amapKey]),
    amapDefaultLocation: firstText([parsed.AMAP_DEFAULT_LOCATION, parsed.FOOD_DEFAULT_LOCATION, parsed.amapDefaultLocation]),
    amapRadius: firstText([parsed.AMAP_RADIUS, parsed.amapRadius]),
    tencentMapKey: firstText([parsed.TENCENT_MAP_KEY, parsed.tencentMapKey]),
    tencentMapApiUrl: firstText([parsed.TENCENT_MAP_API_URL, parsed.tencentMapApiUrl]),
    baiduMapAk: firstText([parsed.BAIDU_MAP_AK, parsed.baiduMapAk]),
    baiduMapApiUrl: firstText([parsed.BAIDU_MAP_API_URL, parsed.baiduMapApiUrl]),
    meituanUnionAppKey: firstText([parsed.MEITUAN_UNION_APP_KEY, parsed.meituanUnionAppKey]),
    meituanUnionAppSecret: firstText([parsed.MEITUAN_UNION_APP_SECRET, parsed.meituanUnionAppSecret]),
    meituanUnionApiUrl: firstText([parsed.MEITUAN_UNION_API_URL, parsed.meituanUnionApiUrl]),
    taobaoAppKey: firstText([parsed.TAOBAO_APP_KEY, parsed.taobaoAppKey]),
    taobaoAppSecret: firstText([parsed.TAOBAO_APP_SECRET, parsed.taobaoAppSecret]),
    taobaoFlashPid: firstText([parsed.TAOBAO_FLASH_PID, parsed.taobaoFlashPid]),
    taobaoApiUrl: firstText([parsed.TAOBAO_API_URL, parsed.taobaoApiUrl]),
    mcdMcpToken: firstText([parsed.MCD_MCP_TOKEN, parsed.mcdMcpToken]),
    mcdMcpUrl: firstText([parsed.MCD_MCP_URL, parsed.mcdMcpUrl]),
    luckinMcpToken: firstText([parsed.LUCKIN_MCP_TOKEN, parsed.luckinMcpToken]),
    luckinMcpUrl: firstText([parsed.LUCKIN_MCP_URL, parsed.luckinMcpUrl]),
    googleMapsApiKey: firstText([parsed.GOOGLE_MAPS_API_KEY, parsed.googleMapsApiKey]),
    googleOauthClientId: firstText([parsed.GOOGLE_OAUTH_CLIENT_ID, parsed.GMAIL_OAUTH_CLIENT_ID, parsed.googleOauthClientId]),
    googleOauthClientSecret: firstText([parsed.GOOGLE_OAUTH_CLIENT_SECRET, parsed.GMAIL_OAUTH_CLIENT_SECRET, parsed.googleOauthClientSecret]),
    googleOauthRedirectUri: firstText([parsed.GOOGLE_OAUTH_REDIRECT_URI, parsed.GMAIL_OAUTH_REDIRECT_URI, parsed.googleOauthRedirectUri]),
    gmailAuthUrl: firstText([parsed.GMAIL_AUTH_URL, parsed.gmailAuthUrl]),
    gmailOauthClientId: firstText([parsed.GMAIL_OAUTH_CLIENT_ID, parsed.GOOGLE_OAUTH_CLIENT_ID, parsed.gmailOauthClientId]),
    gmailOauthClientSecret: firstText([parsed.GMAIL_OAUTH_CLIENT_SECRET, parsed.GOOGLE_OAUTH_CLIENT_SECRET, parsed.gmailOauthClientSecret]),
    gmailOauthRedirectUri: firstText([parsed.GMAIL_OAUTH_REDIRECT_URI, parsed.GOOGLE_OAUTH_REDIRECT_URI, parsed.gmailOauthRedirectUri]),
    gmailMcpUserProject: firstText([parsed.GMAIL_MCP_USER_PROJECT, parsed.GOOGLE_CLOUD_PROJECT, parsed.gmailMcpUserProject]),
    youtubeApiKey: firstText([parsed.YOUTUBE_API_KEY, parsed.youtubeApiKey]),
    qqMailAddress: firstText([parsed.QQ_MAIL_ADDRESS, parsed.qqMailAddress]),
    qqMailAuthCode: firstText([parsed.QQ_MAIL_AUTH_CODE, parsed.qqMailAuthCode]),
    qqMailImapHost: firstText([parsed.QQ_MAIL_IMAP_HOST, parsed.qqMailImapHost]),
    qqMailImapPort: firstText([parsed.QQ_MAIL_IMAP_PORT, parsed.qqMailImapPort]),
    qqMailDraftsMailbox: firstText([parsed.QQ_MAIL_DRAFTS_MAILBOX, parsed.qqMailDraftsMailbox])
  });
}

export function localProviderConfigDebugSummary(): string {
  return 'rawfile=' + LOCAL_PROVIDER_CONFIG_RAWFILE +
    ', flightKey=' + (localProviderConfig.flightMcpKey.length > 0 ? 'present(' + localProviderConfig.flightMcpKey.length.toString() + ')' : 'missing') +
    ', amapKey=' + (localProviderConfig.amapKey.length > 0 ? 'present(' + localProviderConfig.amapKey.length.toString() + ')' : 'missing') +
    ', tencentMapKey=' + (localProviderConfig.tencentMapKey.length > 0 ? 'present(' + localProviderConfig.tencentMapKey.length.toString() + ')' : 'missing') +
    ', baiduMapAk=' + (localProviderConfig.baiduMapAk.length > 0 ? 'present(' + localProviderConfig.baiduMapAk.length.toString() + ')' : 'missing') +
    ', meituanKey=' + (localProviderConfig.meituanUnionAppKey.length > 0 ? 'present(' + localProviderConfig.meituanUnionAppKey.length.toString() + ')' : 'missing') +
    ', taobaoKey=' + (localProviderConfig.taobaoAppKey.length > 0 ? 'present(' + localProviderConfig.taobaoAppKey.length.toString() + ')' : 'missing') +
    ', taobaoPid=' + (localProviderConfig.taobaoFlashPid.length > 0 ? 'present(' + localProviderConfig.taobaoFlashPid.length.toString() + ')' : 'missing') +
    ', mcdMcpToken=' + (localProviderConfig.mcdMcpToken.length > 0 ? 'present(' + localProviderConfig.mcdMcpToken.length.toString() + ')' : 'missing') +
    ', luckinMcpToken=' + (localProviderConfig.luckinMcpToken.length > 0 ? 'present(' + localProviderConfig.luckinMcpToken.length.toString() + ')' : 'missing') +
    ', googleMapsApiKey=' + (localProviderConfig.googleMapsApiKey.length > 0 ? 'present(' + localProviderConfig.googleMapsApiKey.length.toString() + ')' : 'missing') +
    ', googleOauthClientId=' + (localProviderConfig.googleOauthClientId.length > 0 ? 'present(' + localProviderConfig.googleOauthClientId.length.toString() + ')' : 'missing') +
    ', gmailOauthClientId=' + (localProviderConfig.gmailOauthClientId.length > 0 ? 'present(' + localProviderConfig.gmailOauthClientId.length.toString() + ')' : 'missing') +
    ', gmailOauthClientSecret=' + (localProviderConfig.gmailOauthClientSecret.length > 0 ? 'present(' + localProviderConfig.gmailOauthClientSecret.length.toString() + ')' : 'missing') +
    ', youtubeApiKey=' + (localProviderConfig.youtubeApiKey.length > 0 ? 'present(' + localProviderConfig.youtubeApiKey.length.toString() + ')' : 'missing') +
    ', gmailMcpUserProject=' + (localProviderConfig.gmailMcpUserProject.length > 0 ? 'present' : 'missing') +
    ', qqMailAddress=' + (localProviderConfig.qqMailAddress.length > 0 ? 'present' : 'missing') +
    ', qqMailAuthCode=' + (localProviderConfig.qqMailAuthCode.length > 0 ? 'present(' + localProviderConfig.qqMailAuthCode.length.toString() + ')' : 'missing') +
    ', qqMailImapHost=' + (localProviderConfig.qqMailImapHost.length > 0 ? 'present' : 'missing') +
    ', qqMailDraftsMailbox=' + (localProviderConfig.qqMailDraftsMailbox.length > 0 ? 'present' : 'missing') +
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

function utf8Bytes(value: string): number[] {
  const bytes: number[] = [];
  for (let index = 0; index < value.length; index++) {
    let code = value.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length) {
      const next = value.charCodeAt(index + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00);
        index++;
      }
    }
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3f));
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3f));
      bytes.push(0x80 | (code & 0x3f));
    } else {
      bytes.push(0xf0 | (code >> 18));
      bytes.push(0x80 | ((code >> 12) & 0x3f));
      bytes.push(0x80 | ((code >> 6) & 0x3f));
      bytes.push(0x80 | (code & 0x3f));
    }
  }
  return bytes;
}

function add32(left: number, right: number): number {
  return (left + right) | 0;
}

function rotateLeft(value: number, bits: number): number {
  return (value << bits) | (value >>> (32 - bits));
}

function md5DigestBytes(value: string): number[] {
  const message = utf8Bytes(value);
  const originalLength = message.length;
  message.push(0x80);
  while ((message.length % 64) !== 56) {
    message.push(0);
  }
  const bitLow = (originalLength * 8) >>> 0;
  const bitHigh = Math.floor(originalLength / 0x20000000) >>> 0;
  for (let index = 0; index < 4; index++) {
    message.push((bitLow >>> (index * 8)) & 0xff);
  }
  for (let index = 0; index < 4; index++) {
    message.push((bitHigh >>> (index * 8)) & 0xff);
  }

  const shifts: number[] = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
  ];
  const constants: number[] = [];
  for (let index = 0; index < 64; index++) {
    constants.push(Math.floor(Math.abs(Math.sin(index + 1)) * 4294967296) | 0);
  }

  let a0 = 0x67452301;
  let b0 = 0xefcdab89 | 0;
  let c0 = 0x98badcfe | 0;
  let d0 = 0x10325476;

  for (let offset = 0; offset < message.length; offset += 64) {
    const words: number[] = [];
    for (let wordIndex = 0; wordIndex < 16; wordIndex++) {
      const base = offset + wordIndex * 4;
      words.push((message[base] | (message[base + 1] << 8) | (message[base + 2] << 16) | (message[base + 3] << 24)) | 0);
    }

    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;

    for (let index = 0; index < 64; index++) {
      let f = 0;
      let g = 0;
      if (index < 16) {
        f = (b & c) | ((~b) & d);
        g = index;
      } else if (index < 32) {
        f = (d & b) | ((~d) & c);
        g = (5 * index + 1) % 16;
      } else if (index < 48) {
        f = b ^ c ^ d;
        g = (3 * index + 5) % 16;
      } else {
        f = c ^ (b | (~d));
        g = (7 * index) % 16;
      }
      const previousD = d;
      d = c;
      c = b;
      const rotated = rotateLeft(add32(add32(a, f), add32(constants[index], words[g])), shifts[index]);
      b = add32(b, rotated);
      a = previousD;
    }

    a0 = add32(a0, a);
    b0 = add32(b0, b);
    c0 = add32(c0, c);
    d0 = add32(d0, d);
  }

  const digest: number[] = [];
  const words = [a0, b0, c0, d0];
  for (let wordIndex = 0; wordIndex < words.length; wordIndex++) {
    for (let byteIndex = 0; byteIndex < 4; byteIndex++) {
      digest.push((words[wordIndex] >>> (byteIndex * 8)) & 0xff);
    }
  }
  return digest;
}

function byteHex(value: number): string {
  const digits = '0123456789abcdef';
  return digits.charAt((value >>> 4) & 0x0f) + digits.charAt(value & 0x0f);
}

function md5Hex(value: string): string {
  const digest = md5DigestBytes(value);
  let result = '';
  for (let index = 0; index < digest.length; index++) {
    result += byteHex(digest[index]);
  }
  return result;
}

function bytesToBase64(bytes: number[]): string {
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
  return result;
}

function md5Base64(value: string): string {
  return bytesToBase64(md5DigestBytes(value));
}

function sortedParamPairs(pairs: FoodParamPair[]): FoodParamPair[] {
  const next: FoodParamPair[] = [];
  for (let index = 0; index < pairs.length; index++) {
    next.push({ key: pairs[index].key, value: pairs[index].value });
  }
  next.sort((left: FoodParamPair, right: FoodParamPair): number => {
    if (left.key < right.key) {
      return -1;
    }
    if (left.key > right.key) {
      return 1;
    }
    return 0;
  });
  return next;
}

function topMd5Sign(pairs: FoodParamPair[], appSecret: string): string {
  const sorted = sortedParamPairs(pairs);
  let source = appSecret;
  for (let index = 0; index < sorted.length; index++) {
    if (sorted[index].key === 'sign' || sorted[index].value.length === 0) {
      continue;
    }
    source += sorted[index].key + sorted[index].value;
  }
  source += appSecret;
  return md5Hex(source).toUpperCase();
}

function encodeForm(pairs: FoodParamPair[]): string {
  let body = '';
  for (let index = 0; index < pairs.length; index++) {
    if (body.length > 0) {
      body += '&';
    }
    body += encodeURIComponent(pairs[index].key) + '=' + encodeURIComponent(pairs[index].value);
  }
  return body;
}

function formatTopTimestamp(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate()) + ' ' +
    pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds());
}

function locationLongitude(location: string): string {
  const parts = location.split(',');
  return parts.length > 0 ? parts[0].trim() : '';
}

function locationLatitude(location: string): string {
  const parts = location.split(',');
  return parts.length > 1 ? parts[1].trim() : '';
}

function coordinateToMicros(value: string): string {
  const numeric = Number(value);
  if (isNaN(numeric)) {
    return '';
  }
  return Math.round(numeric * 1000000).toString();
}

function meituanUnionSignature(appSecret: string, appKey: string, timestamp: string, contentMd5: string, body: string): string {
  const source = appSecret +
    'Content-MD5' + contentMd5 +
    'S-Ca-App' + appKey +
    'S-Ca-Timestamp' + timestamp +
    body +
    appSecret;
  return md5Hex(source).toUpperCase();
}

function postFormText(url: string, headers: HttpRequestHeaders, body: string): Promise<HttpTextResponse> {
  return postJsonText(url, headers, body);
}

function mcpHeaders(token: string, sessionId: string = ''): HttpRequestHeaders {
  if (sessionId.length > 0) {
    return {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json, text/event-stream',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token,
      'MCP-Protocol-Version': MCP_PROTOCOL_VERSION,
      'Mcp-Session-Id': sessionId
    };
  }
  return {
    'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
    'Accept': 'application/json, text/event-stream',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + token,
    'MCP-Protocol-Version': MCP_PROTOCOL_VERSION
  };
}

function escapeRegexLiteral(value: string): string {
  const specials = '\\^$.*+?()[]{}|';
  let escaped = '';
  for (let index = 0; index < value.length; index++) {
    const char = value.charAt(index);
    if (specials.indexOf(char) >= 0) {
      escaped += '\\';
    }
    escaped += char;
  }
  return escaped;
}

function jsonTextUnescape(value: string): string {
  return value.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}

function headerValueFromJson(headersJson: string, wantedKey: string): string {
  const key = escapeRegexLiteral(wantedKey);
  const arrayPattern = new RegExp('"' + key + '"\\s*:\\s*\\[\\s*"([^"]*)"', 'i');
  const arrayMatch = arrayPattern.exec(headersJson);
  if (arrayMatch !== null && arrayMatch.length > 1) {
    return jsonTextUnescape(arrayMatch[1]);
  }
  const stringPattern = new RegExp('"' + key + '"\\s*:\\s*"([^"]*)"', 'i');
  const stringMatch = stringPattern.exec(headersJson);
  if (stringMatch !== null && stringMatch.length > 1) {
    return jsonTextUnescape(stringMatch[1]);
  }
  const primitivePattern = new RegExp('"' + key + '"\\s*:\\s*([^,}\\]]+)', 'i');
  const primitiveMatch = primitivePattern.exec(headersJson);
  if (primitiveMatch !== null && primitiveMatch.length > 1) {
    return primitiveMatch[1].trim();
  }
  return '';
}

function parseMcpJsonRpcText(text: string): McpJsonRpcResponse {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return {};
  }
  if (trimmed.startsWith('{')) {
    return JSON.parse(trimmed) as McpJsonRpcResponse;
  }
  if (trimmed.startsWith('[')) {
    const responses = JSON.parse(trimmed) as McpJsonRpcResponse[];
    return responses.length > 0 ? responses[responses.length - 1] : {};
  }
  const lines = trimmed.split(/\r?\n/);
  for (let index = lines.length - 1; index >= 0; index--) {
    const line = lines[index].trim();
    if (!line.startsWith('data:')) {
      continue;
    }
    const data = line.substring('data:'.length).trim();
    if (data.length === 0 || data === '[DONE]') {
      continue;
    }
    return JSON.parse(data) as McpJsonRpcResponse;
  }
  return {};
}

function firstJsonSlice(text: string): string {
  const trimmed = text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return trimmed;
  }
  const objectStart = trimmed.indexOf('{');
  const objectEnd = trimmed.lastIndexOf('}');
  if (objectStart >= 0 && objectEnd > objectStart) {
    return trimmed.substring(objectStart, objectEnd + 1);
  }
  const arrayStart = trimmed.indexOf('[');
  const arrayEnd = trimmed.lastIndexOf(']');
  if (arrayStart >= 0 && arrayEnd > arrayStart) {
    return trimmed.substring(arrayStart, arrayEnd + 1);
  }
  return '';
}

function mcpToolPayloadFromText(text: string): Object {
  const response = parseMcpJsonRpcText(text);
  if (response.error !== undefined) {
    throw new Error(firstText([response.error.message, response.error.code, response.error.data, 'MCP JSON-RPC error']));
  }
  const result = response.result;
  if (result === undefined || result === null) {
    throw new Error('MCP 返回中没有 result。');
  }
  if (result.isError === true) {
    throw new Error('MCP 工具返回错误状态。');
  }
  if (result.structuredContent !== undefined && result.structuredContent !== null) {
    return result.structuredContent;
  }
  const content = result.content === undefined ? [] : result.content;
  for (let index = 0; index < content.length; index++) {
    const item = content[index];
    if (item.data !== undefined && item.data !== null && typeof item.data === 'object') {
      return item.data as Object;
    }
    const textValue = textOf(item.text).trim();
    const jsonSlice = firstJsonSlice(textValue);
    if (jsonSlice.length > 0) {
      return JSON.parse(jsonSlice) as Object;
    }
  }
  throw new Error('MCP 工具没有返回可解析的结构化 JSON。');
}

export function isReadonlyBrandMcpTool(provider: string, toolName: string): boolean {
  if (provider === '麦当劳') {
    return [
      'list-nutrition-foods',
      'delivery-query-addresses',
      'delivery-query-stores',
      'query-meal-assistance',
      'query-nearby-stores',
      'query-store-coupons',
      'query-meals',
      'query-meal-detail',
      'calculate-price',
      'query-order',
      'campaign-calendar',
      'available-coupons',
      'query-my-coupons',
      'query-my-account',
      'mall-points-products',
      'mall-product-detail',
      'mall-order-list',
      'mall-order-detail',
      'now-time-info'
    ].indexOf(toolName) >= 0;
  }
  if (provider === '瑞幸') {
    return [
      'queryShopList',
      'searchProductForMcp',
      'queryProductDetailInfo',
      'queryOrderDetailInfo'
    ].indexOf(toolName) >= 0;
  }
  return false;
}

function brandMcpHttpError(provider: string, phase: string, code: number, text: string): string {
  const detail = text.substring(0, 300);
  if (provider === '瑞幸' && detail.toLowerCase().indexOf('missing csrf token') >= 0) {
    return provider + ' MCP ' + phase + ' HTTP ' + code.toString() + '：服务端要求 CSRF/session 授权；请确认 LUCKIN_MCP_URL 指向 https://gwmcp.lkcoffee.com/order/user/mcp，而不是开放平台官网页面：' + detail;
  }
  return provider + ' MCP ' + phase + ' HTTP ' + code.toString() + '：' + detail;
}

async function callReadonlyBrandMcpTool(provider: string, url: string, token: string, toolName: string, args: Object): Promise<Object> {
  if (!isReadonlyBrandMcpTool(provider, toolName)) {
    throw new Error(provider + ' MCP 工具 ' + toolName + ' 不在只读查询白名单内。');
  }
  const initRequest: McpInitializeRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: {
      protocolVersion: MCP_PROTOCOL_VERSION,
      capabilities: new EmptyMcpCapabilities(),
      clientInfo: {
        name: 'AIPhoneDemo',
        version: '0.1'
      }
    }
  };
  const initBody = JSON.stringify(initRequest);
  const init = await postJsonText(url, mcpHeaders(token), initBody);
  if (init.code < 200 || init.code >= 300) {
    throw new Error(brandMcpHttpError(provider, 'initialize', init.code, init.text));
  }
  let initParsed: McpJsonRpcResponse = {};
  try {
    initParsed = parseMcpJsonRpcText(init.text);
  } catch (error) {
    throw new Error(provider + ' MCP initialize 返回格式异常：' + describeThrown(error));
  }
  if (initParsed.error !== undefined) {
    throw new Error(provider + ' MCP initialize 返回错误：' + firstText([initParsed.error.message, initParsed.error.code, initParsed.error.data, 'MCP initialize error']));
  }
  const sessionId = headerValueFromJson(init.headers, 'mcp-session-id');
  if (sessionId.length > 0) {
    try {
      const initializedNotification: McpInitializedNotification = {
        jsonrpc: '2.0',
        method: 'notifications/initialized'
      };
      await postJsonText(url, mcpHeaders(token, sessionId), JSON.stringify(initializedNotification));
    } catch (error) {
      aiLogInfo('[AIPhone][BrandMcpInitializedIgnored] provider=' + provider + ' error=' + describeThrown(error));
    }
  }
  const callRequest: McpToolCallRequest = {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/call',
    params: {
      name: toolName,
      arguments: args
    }
  };
  const callBody = JSON.stringify(callRequest);
  aiLogInfo('[AIPhone][BrandMcpRequest] provider=' + provider + ' tool=' + toolName + ' url=' + url + ' bodyChars=' + callBody.length.toString());
  const response = await postJsonText(url, mcpHeaders(token, sessionId), callBody);
  if (response.code < 200 || response.code >= 300) {
    throw new Error(brandMcpHttpError(provider, toolName, response.code, response.text));
  }
  return mcpToolPayloadFromText(response.text);
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
    fromLocation: item.fromLocation,
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
  if (toolId === 'social.reply.send') {
    return 'social';
  }
  if (toolId === 'food.search') {
    return 'food';
  }
  if (toolId === 'travel.search' || toolId === 'train.search' || toolId === 'flight.search') {
    return 'travel';
  }
  return 'general';
}

function componentForTool(toolId: string): string {
  if (toolId === 'social.reply.send') {
    return 'SocialInbox';
  }
  if (toolId === 'travel.search') {
    return 'TravelOptions';
  }
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
  if (toolId === 'social.reply.send') {
    return '/social/messages';
  }
  if (toolId === 'travel.search') {
    return '/travelOptions';
  }
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
  if (toolId === 'social.reply.send') {
    return 'social';
  }
  if (toolId === 'travel.search') {
    return 'travelOptions';
  }
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
  if (toolId === 'social.reply.send') {
    return '微信回复发送';
  }
  if (toolId === 'travel.search') {
    return '出行方案查询';
  }
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
  const message = toolId === 'travel.search'
    ? '正在同时等待 12306 和飞常准返回'
    : (toolId === 'train.search'
    ? '正在等待 12306 返回'
    : (toolId === 'flight.search' ? '正在等待飞常准返回' : (toolId === 'food.search' ? '正在等待外卖聚合来源返回' : '正在调用工具')));
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
              { id: 'flight_change_date', label: '换个日期', prompt: '换个日期查询航班', kind: 'prompt', variant: 'secondary' }
              // 换城市需要城市选择控件，先不暴露半成品入口。
              // { id: 'flight_change_city', label: '换个城市', prompt: '换个城市查询航班', kind: 'prompt', variant: 'secondary' }
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

function travelResultA2ui(surfaceId: string, title: string, body: string, summaryText: string, options: A2uiTravelOptionData[], rows: A2uiLabelValueData[]): string {
  const components: A2uiComponent[] = [];
  components.push({
    id: 'root',
    component: 'SurfaceRoot',
    child: rows.length > 0 ? 'layout' : 'results',
    title: title,
    body: summaryText,
    status: 'ready'
  });
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
    component: componentForTool('travel.search'),
    title: title,
    body: body,
    status: 'ready',
    dataPath: dataPathForTool('travel.search'),
    actions: TRAVEL_CLIENT_ACTIONS
  });

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
        components: components
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/travelOptions',
        value: options
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/rows',
        value: rows
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: {
          text: summaryText,
          toolName: 'travel.search',
          dataLabel: dataLabelForTool('travel.search'),
          count: options.length
        }
      }
    }
  ]);
}

function compactTime(value: string): string {
  const text = value.trim();
  const match = /(\d{1,2}):(\d{2})/.exec(text);
  if (match !== null) {
    return pad2(Number(match[1])) + ':' + match[2];
  }
  return text;
}

function parseTravelDurationMinutes(duration: string): number {
  const text = duration.trim();
  const colon = /^(\d{1,2}):(\d{2})$/.exec(text);
  if (colon !== null) {
    return Number.parseInt(colon[1], 10) * 60 + Number.parseInt(colon[2], 10);
  }
  let hours = 0;
  let minutes = 0;
  const hourMatch = /(\d+)\s*小时/.exec(text);
  const minuteMatch = /(\d+)\s*分/.exec(text);
  if (hourMatch !== null) {
    hours = Number.parseInt(hourMatch[1], 10);
  }
  if (minuteMatch !== null) {
    minutes = Number.parseInt(minuteMatch[1], 10);
  }
  if (hours > 0 || minutes > 0) {
    return hours * 60 + minutes;
  }
  return 99999;
}

function durationFromTimes(depart: string, arrive: string): string {
  const start = Date.parse(depart);
  const end = Date.parse(arrive);
  if (isNaN(start) || isNaN(end) || end <= start) {
    return '';
  }
  const minutes = Math.floor((end - start) / 60000);
  if (minutes <= 0 || minutes > 48 * 60) {
    return '';
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours > 0) {
    return hours.toString() + '小时' + rest.toString() + '分';
  }
  return rest.toString() + '分';
}

function clockScore(value: string): number {
  const match = /(\d{1,2}):(\d{2})/.exec(value);
  if (match === null) {
    return 9999;
  }
  return Number.parseInt(match[1], 10) * 60 + Number.parseInt(match[2], 10);
}

function travelSourceSortOrder(source: string): number {
  if (source === 'train') {
    return 0;
  }
  if (source === 'flight') {
    return 1;
  }
  return 2;
}

export function sortTravelOptionsByDeparture(options: A2uiTravelOptionData[]): A2uiTravelOptionData[] {
  const copy = options.slice();
  copy.sort((left: A2uiTravelOptionData, right: A2uiTravelOptionData) => {
    const departDelta = clockScore(left.depart) - clockScore(right.depart);
    if (departDelta !== 0) {
      return departDelta;
    }
    const arriveDelta = clockScore(left.arrive) - clockScore(right.arrive);
    if (arriveDelta !== 0) {
      return arriveDelta;
    }
    return travelSourceSortOrder(left.source) - travelSourceSortOrder(right.source);
  });
  return copy;
}

function trainToTravelOption(item: A2uiTrainData, index: number): A2uiTravelOptionData {
  return {
    id: 'train-' + (item.trainCode.length > 0 ? item.trainCode : index.toString()) + '-' + item.depart,
    source: 'train',
    sourceTag: '高铁 · 12306',
    title: item.trainCode,
    from: item.from,
    to: item.to,
    fromLocation: item.fromLocation,
    depart: compactTime(item.depart),
    arrive: compactTime(item.arrive),
    duration: item.duration,
    price: '',
    availability: item.seats,
    status: item.status.length > 0 ? item.status : '可查',
    detail: ''
  };
}

function flightToTravelOption(item: A2uiFlightData, index: number): A2uiTravelOptionData {
  const duration = durationFromTimes(item.depTime, item.arrTime);
  return {
    id: 'flight-' + (item.flightNo.length > 0 ? item.flightNo : index.toString()) + '-' + compactTime(item.depTime),
    source: 'flight',
    sourceTag: '飞机 · 飞常准',
    title: item.flightNo.length > 0 ? item.flightNo : item.airline,
    from: item.dep,
    to: item.arr,
    fromLocation: item.depLocation,
    depart: compactTime(item.depTime),
    arrive: compactTime(item.arrTime),
    duration: duration,
    price: item.price,
    availability: '',
    status: item.status.length > 0 ? item.status : '计划',
    detail: item.airline
  };
}

function snapshotFromToolA2ui(raw: string): ToolA2uiSnapshot {
  const parsed = parseA2uiJsonl(raw);
  const snapshot: ToolA2uiSnapshot = {
    title: '',
    summary: '',
    error: parsed.error,
    trains: [],
    flights: [],
    rows: []
  };
  parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
    if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
      snapshot.title = envelope.createSurface.title === undefined ? snapshot.title : envelope.createSurface.title;
    }
    if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
      envelope.updateComponents.components.forEach((component: A2uiComponent) => {
        if (component.component === 'ErrorNotice') {
          const title = component.title === undefined ? '' : component.title;
          const body = component.body === undefined ? '' : component.body;
          snapshot.error = (title + ' ' + body).trim();
        }
      });
    }
    if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
      const update = envelope.updateDataModel;
      if (update.path === '/trains' && Array.isArray(update.value)) {
        snapshot.trains = update.value as A2uiTrainData[];
      } else if (update.path === '/flights' && Array.isArray(update.value)) {
        snapshot.flights = update.value as A2uiFlightData[];
      } else if (update.path === '/rows' && Array.isArray(update.value)) {
        snapshot.rows = update.value as A2uiLabelValueData[];
      } else if (update.path === '/summary') {
        const summary = update.value as A2uiSummaryData;
        snapshot.summary = summary.text === undefined ? '' : summary.text;
      }
    }
  });
  return snapshot;
}

function issueRow(label: string, snapshot: ToolA2uiSnapshot, emptyText: string): A2uiLabelValueData | null {
  if (snapshot.error.length > 0) {
    return {
      label: label,
      value: snapshot.error
    };
  }
  const message = snapshot.summary.length > 0 ? snapshot.summary : emptyText;
  return {
    label: label,
    value: message
  };
}

async function callLocalTravelSearch(prompt: string, surfaceId: string): Promise<string> {
  const trainPrompt = /高铁|动车|\bG\d+|\bD\d+/i.test(prompt) ? prompt : prompt + ' 高铁';
  const flightPrompt = /航班|机票|飞机/.test(prompt) ? prompt : prompt + ' 航班';
  const results = await Promise.all([
    callLocalTrainSearch(trainPrompt, surfaceId + '_train'),
    callLocalFlightSearch(flightPrompt, surfaceId + '_flight')
  ]);
  const trainSnapshot = snapshotFromToolA2ui(results[0]);
  const flightSnapshot = snapshotFromToolA2ui(results[1]);
  let options: A2uiTravelOptionData[] = [];
  trainSnapshot.trains.forEach((item: A2uiTrainData, index: number) => {
    options.push(trainToTravelOption(item, index));
  });
  flightSnapshot.flights.forEach((item: A2uiFlightData, index: number) => {
    options.push(flightToTravelOption(item, index));
  });
  options = sortTravelOptionsByDeparture(options);

  const rows: A2uiLabelValueData[] = [];
  if (trainSnapshot.error.length > 0 || trainSnapshot.trains.length === 0) {
    const row = issueRow('高铁 · 12306', trainSnapshot, '12306 没有返回可展示车次。');
    if (row !== null) {
      rows.push(row);
    }
  }
  if (flightSnapshot.error.length > 0 || flightSnapshot.flights.length === 0) {
    const row = issueRow('飞机 · 飞常准', flightSnapshot, '飞常准没有返回可展示航班。');
    if (row !== null) {
      rows.push(row);
    }
  }

  aiLogInfo('[AIPhone][LocalToolTravelResult] trains=' + trainSnapshot.trains.length.toString() +
    ' flights=' + flightSnapshot.flights.length.toString() +
    ' options=' + options.length.toString() +
    ' issues=' + rows.length.toString());

  if (options.length === 0) {
    const messages: string[] = [];
    rows.forEach((row: A2uiLabelValueData) => {
      messages.push(row.label + '：' + row.value);
    });
    return errorA2ui(
      surfaceId,
      'travel.search',
      '出行方案查询失败',
      '高铁和航班工具都没有返回可展示结果。为避免编造行程，当前只展示真实错误或空结果说明。',
      messages.length > 0 ? messages : ['12306 和飞常准都没有返回可展示结果。'],
      ['换日期或城市', '只查高铁', '只查飞机']
    );
  }

  return travelResultA2ui(
    surfaceId,
    '出行方案查询',
    '用户请求：' + prompt,
    '已查询高铁和航班，共 ' + options.length.toString() + ' 个可展示方案。',
    options,
    rows
  );
}

function foodDataSignature(foods: A2uiFoodData[]): string {
  return JSON.stringify(foods);
}

function foodRowsSignature(rows: A2uiLabelValueData[]): string {
  return JSON.stringify(rows);
}

function foodSummaryData(summaryText: string, foods: A2uiFoodData[]): A2uiSummaryData {
  return {
    text: summaryText,
    toolName: 'food.search',
    dataLabel: dataLabelForTool('food.search'),
    count: foods.length
  };
}

function foodSummarySignature(summary: A2uiSummaryData): string {
  return summary.text + '|' + summary.toolName + '|' + summary.dataLabel + '|' + summary.count.toString();
}

export function foodA2uiRenderState(surfaceId: string, title: string, body: string, summaryText: string, foods: A2uiFoodData[], rows: A2uiLabelValueData[] = [], status: string = 'ready'): A2uiPartialRenderState {
  const components: A2uiComponent[] = [];
  components.push({
    id: 'root',
    component: 'SurfaceRoot',
    child: rows.length > 0 ? 'layout' : 'results',
    title: title,
    body: body,
    status: status
  });
  if (rows.length > 0) {
    components.push({
      id: 'layout',
      component: 'Column',
      children: ['summary', 'results'],
      status: status
    });
    components.push({
      id: 'summary',
      component: 'InfoRows',
      title: '来源状态',
      body: '以下只展示真实 provider 返回；失败来源不会生成占位店铺。',
      status: status,
      dataPath: '/rows',
      actions: []
    });
  }
  components.push({
    id: 'results',
    component: componentForTool('food.search'),
    title: title,
    body: body,
    status: status,
    dataPath: dataPathForTool('food.search'),
    actions: [
      { id: 'food_show_all', label: '全部范围', prompt: '显示全部附近餐饮', kind: 'client', variant: 'secondary' },
      { id: 'food_filter_1km', label: '1公里内', prompt: '只看一公里内餐饮', kind: 'client', variant: 'secondary' },
      { id: 'food_show_more', label: '展示更多', prompt: '展示更多附近餐饮', kind: 'client', variant: 'primary' },
      { id: 'food_change_keyword', label: '换关键词', prompt: '换关键词查询附近餐饮', kind: 'prompt', variant: 'secondary' },
      { id: 'food_change_location', label: '换位置', prompt: '换位置查询附近餐饮', kind: 'prompt', variant: 'secondary' }
    ]
  });
  const summary = foodSummaryData(summaryText, foods);
  const dataPatches: A2uiPartialDataPatch[] = [
    {
      path: '/foods',
      value: foods,
      signature: foodDataSignature(foods)
    },
    {
      path: '/rows',
      value: rows,
      signature: foodRowsSignature(rows)
    },
    {
      path: '/summary',
      value: summary,
      signature: foodSummarySignature(summary)
    }
  ];
  return {
    surfaceId: surfaceId,
    root: 'root',
    title: title,
    intent: 'food',
    status: status,
    sendDataModel: true,
    components: components,
    componentsSignature: 'food-result-v1|rows=' + (rows.length > 0 ? '1' : '0') + '|status=' + status,
    dataPatches: dataPatches
  };
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

export function flightRecordForA2ui(item: FlightProviderRecord | string): A2uiFlightData {
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
    dep: firstText([item.FlightDepAirport, item.depAirportName, item.depAirport, item.departureAirport, item.departure, item.dep, item.dep_city, item.FlightDepcode]),
    arr: firstText([item.FlightArrAirport, item.arrAirportName, item.arrAirport, item.arrivalAirport, item.arrival, item.arr, item.arr_city, item.FlightArrcode]),
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
      '飞常准返回 HTTP ' + response.code.toString() + '。当前只展示供应商返回的真实错误。',
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
    '以下为飞常准返回的查询结果。',
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

function normalizeFoodSearchKeyword(value: string): string {
  return value.trim()
    .replace(/^附近(?:的)?/u, '')
    .replace(/^周边(?:的)?/u, '')
    .replace(/(?:门店|餐厅|店)$/u, '')
    .trim();
}

function splitFoodSearchKeywords(keyword: string): string[] {
  const cleaned = normalizeFoodSearchKeyword(keyword);
  const keywords: string[] = [];
  if (cleaned.length === 0) {
    keywords.push('餐饮');
    return keywords;
  }
  const parts = cleaned.split(/和|及|与|、|，|,|\/|或/u);
  for (let index = 0; index < parts.length; index++) {
    const part = normalizeFoodSearchKeyword(parts[index]);
    if (part.length > 0) {
      appendUniqueText(keywords, part);
    }
  }
  if (keywords.length === 0) {
    keywords.push(cleaned);
  }
  return keywords;
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
    distance: distance.length > 0 ? distance + '米' : '',
    location: textOf(item.location),
    sourceTags: ['高德']
  };
}

function mapPointLocation(point: FoodMapPoint | undefined): string {
  if (point === undefined || point === null) {
    return '';
  }
  const longitude = textOf(point.lng);
  const latitude = textOf(point.lat);
  if (longitude.length === 0 || latitude.length === 0) {
    return '';
  }
  return longitude + ',' + latitude;
}

export function foodRecordFromTencentMapPlace(item: TencentMapPlace): A2uiFoodData {
  return {
    name: textOf(item.title),
    category: textOf(item.category),
    address: textOf(item.address),
    distance: meterDistanceText(firstText([item._distance, item.distance])),
    location: mapPointLocation(item.location),
    sourceTags: ['腾讯地图']
  };
}

export function foodRecordFromBaiduPlace(item: BaiduPlace): A2uiFoodData {
  const detail = item.detail_info === undefined ? null : item.detail_info;
  const rating = detail === null ? '' : textOf(detail.overall_rating);
  const price = detail === null ? '' : textOf(detail.price);
  return {
    name: textOf(item.name),
    category: detail === null ? '' : textOf(detail.tag),
    address: joinFoodParts([
      textOf(item.address),
      rating.length > 0 ? '评分' + rating : '',
      price.length > 0 ? '人均¥' + price : ''
    ]),
    distance: meterDistanceText(detail === null ? '' : detail.distance),
    location: mapPointLocation(item.location),
    sourceTags: ['百度地图']
  };
}

function joinFoodParts(parts: string[]): string {
  let value = '';
  for (let index = 0; index < parts.length; index++) {
    const part = parts[index].trim();
    if (part.length === 0) {
      continue;
    }
    value = value.length > 0 ? value + ' · ' + part : part;
  }
  return value;
}

function meituanDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  return text + '千米';
}

function meterDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  return text + '米';
}

function deliveryFeeText(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/元$/.test(text)) {
    return label + text;
  }
  return label + text + '元';
}

function minutesText(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/分钟|小时/.test(text)) {
    return label + text;
  }
  return label + text + '分钟';
}

export function foodRecordFromMeituanUnion(item: MeituanUnionRecord): A2uiFoodData {
  const brand = item.brandInfo === undefined ? '' : textOf(item.brandInfo.brandName);
  const coupon = item.couponPackDetail === undefined ? '' : firstText([item.couponPackDetail.name, item.couponPackDetail.productName]);
  const poi = item.deliverablePoiInfo === undefined ? null : item.deliverablePoiInfo;
  const name = firstText([
    poi === null ? '' : poi.poiName,
    item.name,
    item.title,
    brand
  ]);
  const salePrice = item.couponPackDetail === undefined ? '' : textOf(item.couponPackDetail.sellPrice);
  const saleVolume = item.couponPackDetail === undefined ? '' : textOf(item.couponPackDetail.saleVolume);
  const category = joinFoodParts([
    coupon,
    firstText([item.categoryName, brand]),
    salePrice.length > 0 ? '券价¥' + salePrice : '',
    saleVolume.length > 0 ? '销量' + saleVolume : ''
  ]);
  const distributionCost = firstText([
    poi === null ? '' : poi.distributionCost,
    item.distributionCost
  ]);
  const deliveryDuration = firstText([
    poi === null ? '' : poi.deliveryDuration,
    item.deliveryDuration
  ]);
  const lastDeliveryFee = firstText([
    poi === null ? '' : poi.lastDeliveryFee,
    item.lastDeliveryFee
  ]);
  const distance = firstText([
    poi === null ? '' : poi.deliveryDistance,
    item.deliveryDistance
  ]);
  return {
    name: name,
    category: category,
    address: joinFoodParts([
      deliveryFeeText('配送费', distributionCost),
      minutesText('预计', deliveryDuration),
      deliveryFeeText('起送', lastDeliveryFee)
    ]),
    distance: meituanDistanceText(distance),
    sourceTags: ['美团']
  };
}

export function foodRecordFromTaobaoFlashStore(item: TaobaoFlashStoreRecord): A2uiFoodData {
  const items: TaobaoFlashItemRecord[] = item.items !== undefined && item.items.length > 0 ? item.items :
    (item.item_list !== undefined ? item.item_list : []);
  const firstItem: TaobaoFlashItemRecord | null = items.length > 0 ? items[0] : null;
  const itemTitle = firstItem === null ? '' : textOf(firstItem.title);
  const itemPrice = firstItem === null ? '' : textOf(firstItem.price);
  return {
    name: firstText([item.title, item.shop_name, item.name]),
    category: joinFoodParts([
      firstText([item.category_1_name, item.category_name]),
      itemTitle,
      itemPrice.length > 0 ? '¥' + itemPrice : ''
    ]),
    address: joinFoodParts([
      textOf(item.service_rating).length > 0 ? '评分' + textOf(item.service_rating) : (textOf(item.rating).length > 0 ? '评分' + textOf(item.rating) : ''),
      deliveryFeeText('配送费', item.delivery_price),
      minutesText('预计', item.delivery_time)
    ]),
    distance: meterDistanceText(firstText([item.delivery_distance, item.distance])),
    sourceTags: ['淘宝闪购']
  };
}

function mcDonaldsStoresFromData(value: McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined): McDonaldsStoreRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as McDonaldsStoreContainer;
  const arrays: Array<McDonaldsStoreRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function mcDonaldsCouponsFromData(value: McDonaldsCouponRecord[] | McDonaldsCouponContainer | undefined): McDonaldsCouponRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as McDonaldsCouponContainer;
  const arrays: Array<McDonaldsCouponRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function luckinShopsFromData(value: LuckinShopRecord[] | LuckinShopContainer | undefined): LuckinShopRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as LuckinShopContainer;
  const arrays: Array<LuckinShopRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function luckinProductsFromData(value: LuckinProductRecord[] | LuckinProductContainer | undefined): LuckinProductRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as LuckinProductContainer;
  const arrays: Array<LuckinProductRecord[] | undefined> = [
    container.list,
    container.records,
    container.items,
    container.products,
    container.data,
    container.result
  ];
  for (let index = 0; index < arrays.length; index++) {
    const raw = arrays[index];
    if (raw !== undefined && raw.length > 0) {
      return raw;
    }
  }
  return [];
}

function mcpPayloadData(payload: McDonaldsPayload | LuckinPayload): McDonaldsMcpData | LuckinMcpData | undefined {
  if (payload.data !== undefined && payload.data !== null) {
    return payload.data;
  }
  return payload.result;
}

function kmNumberDistanceText(value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/米|千米|公里|km/i.test(text)) {
    return text.replace(/km/ig, '千米').replace(/公里/g, '千米');
  }
  const amount = Number(text);
  if (isNaN(amount)) {
    return text;
  }
  if (amount < 10) {
    return Math.round(amount * 1000).toString() + '米';
  }
  return Math.round(amount).toString() + '米';
}

function pricePart(label: string, value: Object | string | number | boolean | null | undefined): string {
  const text = textOf(value).trim();
  if (text.length === 0) {
    return '';
  }
  if (/^¥/.test(text)) {
    return label + text;
  }
  return label + '¥' + text;
}

function boolStatusText(value: Object | string | number | boolean | null | undefined, trueText: string, falseText: string): string {
  if (typeof value === 'boolean') {
    return value ? trueText : falseText;
  }
  const text = textOf(value).trim().toLowerCase();
  if (text.length === 0) {
    return '';
  }
  if (text === 'true' || text === '1' || text === 'yes') {
    return trueText;
  }
  if (text === 'false' || text === '0' || text === 'no') {
    return falseText;
  }
  return textOf(value);
}

function firstMcDonaldsStore(payload: Object): McDonaldsStoreRecord | null {
  const stores = mcDonaldsStoresFromData(mcpPayloadData(payload as McDonaldsPayload) as McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined);
  return stores.length > 0 ? stores[0] : null;
}

function firstLuckinShop(payload: Object): LuckinShopRecord | null {
  const shops = luckinShopsFromData(mcpPayloadData(payload as LuckinPayload) as LuckinShopRecord[] | LuckinShopContainer | undefined);
  return shops.length > 0 ? shops[0] : null;
}

function mcdStoreToFood(item: McDonaldsStoreRecord): A2uiFoodData {
  const status = boolStatusText(item.businessStatus, '营业中', '休息中');
  const hours = item.businessStartTime !== undefined && item.businessEndTime !== undefined ?
    item.businessStartTime + '-' + item.businessEndTime : '';
  return {
    name: firstText([item.storeName, item.name]),
    category: joinFoodParts(['麦当劳门店', status, hours]),
    address: textOf(item.address),
    distance: meterDistanceText(item.distance),
    sourceTags: ['麦当劳']
  };
}

function mcdMealTags(code: string, categories: McDonaldsCategoryRecord[]): string[] {
  const tags: string[] = [];
  for (let categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
    const category = categories[categoryIndex];
    const meals = category.meals === undefined ? [] : category.meals;
    for (let mealIndex = 0; mealIndex < meals.length; mealIndex++) {
      if (textOf(meals[mealIndex].code) !== code) {
        continue;
      }
      appendUniqueText(tags, textOf(category.name));
      const mealTags: string[] = meals[mealIndex].tags === undefined ? [] : (meals[mealIndex].tags as string[]);
      for (let tagIndex = 0; tagIndex < mealTags.length; tagIndex++) {
        appendUniqueText(tags, textOf(mealTags[tagIndex]));
      }
    }
  }
  return tags;
}

function jsonObjectSlice(source: string, objectStart: number): string {
  if (objectStart < 0 || objectStart >= source.length || source.charAt(objectStart) !== '{') {
    return '';
  }
  let depth = 0;
  let inString = false;
  let escaping = false;
  for (let index = objectStart; index < source.length; index++) {
    const char = source.charAt(index);
    if (escaping) {
      escaping = false;
      continue;
    }
    if (char === '\\') {
      escaping = true;
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
      depth++;
    } else if (char === '}') {
      depth--;
      if (depth === 0) {
        return source.substring(objectStart, index + 1);
      }
    }
  }
  return '';
}

function mcdMealRecordFromMap(mealObject: McDonaldsMealsMap, code: string): McDonaldsMealRecord | null {
  const source = JSON.stringify(mealObject);
  const keyToken = JSON.stringify(code);
  const keyIndex = source.indexOf(keyToken);
  if (keyIndex < 0) {
    return null;
  }
  const colonIndex = source.indexOf(':', keyIndex + keyToken.length);
  if (colonIndex < 0) {
    return null;
  }
  const objectStart = source.indexOf('{', colonIndex + 1);
  const slice = jsonObjectSlice(source, objectStart);
  if (slice.length === 0) {
    return null;
  }
  try {
    return JSON.parse(slice) as McDonaldsMealRecord;
  } catch (_error) {
    return null;
  }
}

function mcdMealEntries(meals: McDonaldsMealsMap | McDonaldsMealRecord[] | undefined): McDonaldsMealEntry[] {
  const entries: McDonaldsMealEntry[] = [];
  if (meals === undefined || meals === null) {
    return entries;
  }
  if (Array.isArray(meals)) {
    const mealRows = meals as McDonaldsMealRecord[];
    for (let index = 0; index < mealRows.length; index++) {
      const row = mealRows[index];
      const code = textOf((row as McDonaldsCategoryMeal).code);
      entries.push({ code: code.length > 0 ? code : index.toString(), meal: row });
    }
    return entries;
  }
  const mealObject = meals as McDonaldsMealsMap;
  const codes = Object.keys(mealObject);
  for (let index = 0; index < codes.length; index++) {
    const code = codes[index];
    const meal = mcdMealRecordFromMap(mealObject, code);
    if (meal === null) {
      continue;
    }
    entries.push({ code: code, meal: meal });
  }
  return entries;
}

function mcdMealsToFood(data: McDonaldsMealsData): A2uiFoodData[] {
  const categories = data.categories === undefined ? [] : data.categories;
  const foods: A2uiFoodData[] = [];
  const entries = mcdMealEntries(data.meals);
  for (let index = 0; index < entries.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const code = entries[index].code;
    const meal = entries[index].meal;
    const name = textOf(meal.name);
    if (name.length === 0) {
      continue;
    }
    const tags = mcdMealTags(code, categories);
    foods.push({
      name: '麦当劳 · ' + name,
      category: joinFoodParts([pricePart('', firstText([meal.currentPrice, meal.price])), code]),
      address: tags.join(' · '),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

function mcdCouponsToFood(coupons: McDonaldsCouponRecord[]): A2uiFoodData[] {
  const foods: A2uiFoodData[] = [];
  for (let index = 0; index < coupons.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const coupon = coupons[index];
    const products = coupon.products === undefined ? [] : coupon.products;
    const productNames: string[] = [];
    for (let productIndex = 0; productIndex < products.length; productIndex++) {
      appendUniqueText(productNames, textOf(products[productIndex].productName));
    }
    const title = firstText([coupon.title, coupon.name, coupon.couponCode, coupon.couponId]);
    if (title.length === 0) {
      continue;
    }
    foods.push({
      name: '麦当劳优惠 · ' + title,
      category: productNames.join(' · '),
      address: textOf(coupon.tradeDateTime),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

function mcdPriceToFood(data: McDonaldsPriceData): A2uiFoodData[] {
  const products = data.productList === undefined ? [] : data.productList;
  const foods: A2uiFoodData[] = [];
  for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const product = products[index];
    const name = firstText([product.productName, product.productCode]);
    if (name.length === 0) {
      continue;
    }
    foods.push({
      name: '麦当劳 · ' + name,
      category: joinFoodParts([
        textOf(product.quantity).length > 0 ? '数量' + textOf(product.quantity) : '',
        pricePart('小计', firstText([product.subtotal, product.originalSubtotal]))
      ]),
      address: joinFoodParts([
        pricePart('应付', data.price),
        pricePart('优惠', data.discount),
        pricePart('配送费', data.deliveryPrice)
      ]),
      distance: '',
      sourceTags: ['麦当劳']
    });
  }
  return foods;
}

export function foodRecordsFromMcDonaldsMcpTool(toolName: string, value: Object): A2uiFoodData[] {
  const payload = value as McDonaldsPayload;
  const data = mcpPayloadData(payload);
  if (toolName === 'query-nearby-stores' || toolName === 'delivery-query-stores') {
    const stores = mcDonaldsStoresFromData(data as McDonaldsStoreRecord[] | McDonaldsStoreContainer | undefined);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < stores.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = mcdStoreToFood(stores[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'query-meals') {
    return mcdMealsToFood(data as McDonaldsMealsData);
  }
  if (toolName === 'query-meal-detail') {
    const detail = data as McDonaldsMealRecord;
    const name = textOf(detail.name);
    if (name.length === 0) {
      return [];
    }
    return [{
      name: '麦当劳 · ' + name,
      category: pricePart('', firstText([detail.currentPrice, detail.price])),
      address: '',
      distance: '',
      sourceTags: ['麦当劳']
    }];
  }
  if (toolName === 'calculate-price') {
    return mcdPriceToFood(data as McDonaldsPriceData);
  }
  if (toolName === 'query-store-coupons' || toolName === 'available-coupons' || toolName === 'query-my-coupons') {
    return mcdCouponsToFood(mcDonaldsCouponsFromData(data as McDonaldsCouponRecord[] | McDonaldsCouponContainer | undefined));
  }
  return [];
}

function luckinShopToFood(item: LuckinShopRecord): A2uiFoodData {
  const tags = item.deptTags !== undefined ? item.deptTags : (item.tags !== undefined ? item.tags : []);
  return {
    name: firstText([item.deptName, item.name]),
    category: joinFoodParts(['瑞幸门店', tags.join(' · '), item.workTimeStart !== undefined && item.workTimeEnd !== undefined ? item.workTimeStart + '-' + item.workTimeEnd : '']),
    address: textOf(item.address),
    distance: kmNumberDistanceText(item.distance),
    location: mapPointLocation({ lng: item.longitude, lat: item.latitude }),
    sourceTags: ['瑞幸']
  };
}

function selectedLuckinAttrs(attrs: LuckinProductAttr[] | undefined): string {
  if (attrs === undefined) {
    return '';
  }
  const parts: string[] = [];
  for (let index = 0; index < attrs.length; index++) {
    const attr = attrs[index];
    const children = attr.productSubAttrs === undefined ? [] : attr.productSubAttrs;
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      if (child.selected === true) {
        appendUniqueText(parts, textOf(attr.attributeName) + ':' + textOf(child.attributeName));
      }
    }
  }
  return parts.join(' · ');
}

function luckinProductToFood(item: LuckinProductRecord): A2uiFoodData {
  return {
    name: '瑞幸 · ' + firstText([item.productName, item.name]),
    category: joinFoodParts([
      firstText([item.skuCode, item.productId]),
      pricePart('', firstText([item.discountPrice, item.price, item.initPrice])),
      item.tags === undefined ? '' : item.tags.join(' · ')
    ]),
    address: selectedLuckinAttrs(item.productAttrs),
    distance: '',
    sourceTags: ['瑞幸']
  };
}

function luckinOrderToFood(item: LuckinOrderRecord): A2uiFoodData[] {
  const foods: A2uiFoodData[] = [];
  const products = item.productInfoList === undefined ? [] : item.productInfoList;
  for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
    const product = luckinProductToFood(products[index]);
    product.address = joinFoodParts([
      textOf(item.orderStatusName),
      pricePart('订单金额', item.orderPayAmount),
      product.address
    ]);
    foods.push(product);
  }
  if (foods.length === 0 && firstText([item.orderId, item.orderStatusName]).length > 0) {
    foods.push({
      name: '瑞幸订单 · ' + textOf(item.orderId),
      category: textOf(item.orderStatusName),
      address: pricePart('订单金额', item.orderPayAmount),
      distance: '',
      sourceTags: ['瑞幸']
    });
  }
  return foods;
}

export function foodRecordsFromLuckinMcpTool(toolName: string, value: Object): A2uiFoodData[] {
  const payload = value as LuckinPayload;
  const data = mcpPayloadData(payload);
  if (toolName === 'queryShopList') {
    const shops = luckinShopsFromData(data as LuckinShopRecord[] | LuckinShopContainer | undefined);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < shops.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = luckinShopToFood(shops[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'searchProductForMcp' || toolName === 'queryProductDetailInfo') {
    if (data === undefined) {
      return [];
    }
    const productRows = luckinProductsFromData(data as LuckinProductRecord[] | LuckinProductContainer | undefined);
    const products = productRows.length > 0 ? productRows : [data as LuckinProductRecord];
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < products.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = luckinProductToFood(products[index]);
      if (food.name !== '瑞幸 · ') {
        foods.push(food);
      }
    }
    return foods;
  }
  if (toolName === 'queryOrderDetailInfo') {
    return luckinOrderToFood(data as LuckinOrderRecord);
  }
  return [];
}

function normalizeFoodName(value: string): string {
  return value.toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[·•\-_/|｜,，.。:：;；（）()【】\[\]{}]/g, '')
    .replace(/（.*?）/g, '')
    .replace(/\(.*?\)/g, '');
}

function normalizeFoodComparable(value: string): string {
  return normalizeFoodName(value)
    .replace(/北京市|北京城区|北京|上海市|上海城区|上海|深圳市|深圳|广州市|广州|杭州市|杭州|成都市|成都|重庆市|重庆|天津市|天津|南京市|南京|武汉市|武汉|西安市|西安|苏州市|苏州/g, '');
}

function foodMergeKey(item: A2uiFoodData): string {
  const name = normalizeFoodName(item.name);
  if (name.length > 0) {
    return 'name:' + name;
  }
  const address = normalizeFoodName(item.address);
  if (address.length > 0) {
    return 'address:' + address;
  }
  return 'distance:' + item.distance;
}

function foodBrandKey(item: A2uiFoodData): string {
  const name = item.name;
  const leftCn = name.indexOf('（');
  const leftAscii = name.indexOf('(');
  let cutIndex = -1;
  if (leftCn >= 0 && leftAscii >= 0) {
    cutIndex = Math.min(leftCn, leftAscii);
  } else if (leftCn >= 0) {
    cutIndex = leftCn;
  } else if (leftAscii >= 0) {
    cutIndex = leftAscii;
  }
  if (cutIndex > 0) {
    return normalizeFoodComparable(name.substring(0, cutIndex));
  }
  return '';
}

function normalizedFoodAddress(value: string): string {
  return normalizeFoodComparable(value)
    .replace(/街道|路南|路北|路东|路西|路中|门口|附近/g, '');
}

export function foodDistanceMeters(value: string): number {
  const compact = value.replace(/\s+/g, '');
  const match = /(\d+(?:\.\d+)?)/.exec(compact);
  if (match === null) {
    return 999999999;
  }
  const amount = Number(match[1]);
  if (isNaN(amount)) {
    return 999999999;
  }
  if (/千米|公里|km/i.test(compact)) {
    return amount * 1000;
  }
  return amount;
}

function foodDistanceClose(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftMeters = foodDistanceMeters(left.distance);
  const rightMeters = foodDistanceMeters(right.distance);
  if (leftMeters >= 999999999 || rightMeters >= 999999999) {
    return false;
  }
  return Math.abs(leftMeters - rightMeters) <= 150;
}

function textContainsWithSignal(left: string, right: string, minLength: number): boolean {
  if (left.length < minLength || right.length < minLength) {
    return false;
  }
  return left.indexOf(right) >= 0 || right.indexOf(left) >= 0;
}

function foodAddressLikelySame(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftAddress = normalizedFoodAddress(left.address);
  const rightAddress = normalizedFoodAddress(right.address);
  return textContainsWithSignal(leftAddress, rightAddress, 8);
}

function foodNamesLikelySame(left: A2uiFoodData, right: A2uiFoodData): boolean {
  const leftName = normalizeFoodComparable(left.name);
  const rightName = normalizeFoodComparable(right.name);
  if (leftName.length === 0 || rightName.length === 0) {
    return false;
  }
  if (leftName === rightName) {
    return true;
  }
  const leftBrand = foodBrandKey(left);
  const rightBrand = foodBrandKey(right);
  const sameBrand = leftBrand.length > 0 && leftBrand === rightBrand;
  if (sameBrand && textContainsWithSignal(leftName, rightName, 6)) {
    return true;
  }
  return textContainsWithSignal(leftName, rightName, 10) && foodDistanceClose(left, right);
}

function foodRecordsLikelySameStore(left: A2uiFoodData, right: A2uiFoodData): boolean {
  if (foodMergeKey(left) === foodMergeKey(right)) {
    return true;
  }
  if (foodNamesLikelySame(left, right)) {
    return true;
  }
  const leftBrand = foodBrandKey(left);
  const rightBrand = foodBrandKey(right);
  return leftBrand.length > 0 && leftBrand === rightBrand && foodAddressLikelySame(left, right) && foodDistanceClose(left, right);
}

function foodTags(item: A2uiFoodData, fallbackProvider: string): string[] {
  const tags: string[] = [];
  const rawTags: string[] = item.sourceTags === undefined || item.sourceTags === null ? [] : item.sourceTags;
  for (let index = 0; index < rawTags.length; index++) {
    const tag = textOf(rawTags[index]).trim();
    if (tag.length > 0 && tags.indexOf(tag) < 0) {
      tags.push(tag);
    }
  }
  if (tags.length === 0 && fallbackProvider.length > 0) {
    tags.push(fallbackProvider);
  }
  return tags;
}

function cloneFood(item: A2uiFoodData, fallbackProvider: string): A2uiFoodData {
  return {
    name: item.name,
    category: item.category,
    address: item.address,
    distance: item.distance,
    location: item.location,
    sourceTags: foodTags(item, fallbackProvider)
  };
}

function mergeFoodInto(target: A2uiFoodData, item: A2uiFoodData, fallbackProvider: string): void {
  const tags = foodTags(item, fallbackProvider);
  const targetTags: string[] = target.sourceTags === undefined || target.sourceTags === null ? [] : target.sourceTags;
  for (let index = 0; index < tags.length; index++) {
    if (targetTags.indexOf(tags[index]) < 0) {
      targetTags.push(tags[index]);
    }
  }
  target.sourceTags = targetTags;
  if (target.category.length === 0 && item.category.length > 0) {
    target.category = item.category;
  }
  if (target.address.length === 0 && item.address.length > 0) {
    target.address = item.address;
  }
  if (target.distance.length === 0 && item.distance.length > 0) {
    target.distance = item.distance;
    if (target.location === undefined || target.location.length === 0) {
      target.location = item.location;
    }
  } else if (item.distance.length > 0 && foodDistanceMeters(item.distance) < foodDistanceMeters(target.distance)) {
    target.distance = item.distance;
    if (item.location !== undefined && item.location.length > 0) {
      target.location = item.location;
    }
  } else if ((target.location === undefined || target.location.length === 0) && item.location !== undefined && item.location.length > 0) {
    target.location = item.location;
  }
}

function appendUniqueText(values: string[], value: string): void {
  if (value.length > 0 && values.indexOf(value) < 0) {
    values.push(value);
  }
}

function foodHasSourceTag(item: A2uiFoodData, source: string): boolean {
  const tags: string[] = foodTags(item, '');
  return tags.indexOf(source) >= 0;
}

function addCoveredFoodSources(coveredSources: string[], item: A2uiFoodData): void {
  const tags: string[] = foodTags(item, '');
  for (let index = 0; index < tags.length; index++) {
    appendUniqueText(coveredSources, tags[index]);
  }
}

function visibleFoodSourceOrder(sourceOrder: string[]): string[] {
  const ordered: string[] = [];
  for (let index = 0; index < sourceOrder.length; index++) {
    if (sourceOrder[index] !== '高德') {
      appendUniqueText(ordered, sourceOrder[index]);
    }
  }
  for (let index = 0; index < sourceOrder.length; index++) {
    if (sourceOrder[index] === '高德') {
      appendUniqueText(ordered, sourceOrder[index]);
    }
  }
  return ordered;
}

function foodSourceCount(item: A2uiFoodData): number {
  return foodTags(item, '').length;
}

function compareVisibleFood(left: A2uiFoodData, right: A2uiFoodData): number {
  const leftMerged = foodSourceCount(left) > 1 ? 0 : 1;
  const rightMerged = foodSourceCount(right) > 1 ? 0 : 1;
  if (leftMerged !== rightMerged) {
    return leftMerged - rightMerged;
  }
  const distanceDiff = foodDistanceMeters(left.distance) - foodDistanceMeters(right.distance);
  if (distanceDiff !== 0) {
    return distanceDiff;
  }
  return left.name.localeCompare(right.name);
}

function selectVisibleFoodResults(foods: A2uiFoodData[]): A2uiFoodData[] {
  const sorted = foods.slice();
  sorted.sort((left: A2uiFoodData, right: A2uiFoodData): number => compareVisibleFood(left, right));
  const sourceOrder: string[] = [];
  for (let index = 0; index < sorted.length; index++) {
    addCoveredFoodSources(sourceOrder, sorted[index]);
  }
  const selected: A2uiFoodData[] = [];
  const orderedSources = visibleFoodSourceOrder(sourceOrder);
  for (let sourceIndex = 0; sourceIndex < orderedSources.length && selected.length < FOOD_AGGREGATED_RESULT_LIMIT; sourceIndex++) {
    for (let foodIndex = 0; foodIndex < sorted.length; foodIndex++) {
      if (selected.indexOf(sorted[foodIndex]) < 0 && foodHasSourceTag(sorted[foodIndex], orderedSources[sourceIndex])) {
        selected.push(sorted[foodIndex]);
        break;
      }
    }
  }
  for (let index = 0; index < sorted.length && selected.length < FOOD_AGGREGATED_RESULT_LIMIT; index++) {
    if (selected.indexOf(sorted[index]) < 0) {
      selected.push(sorted[index]);
    }
  }
  selected.sort((left: A2uiFoodData, right: A2uiFoodData): number => compareVisibleFood(left, right));
  return selected;
}

function findExistingFoodIndex(foods: A2uiFoodData[], item: A2uiFoodData): number {
  for (let index = 0; index < foods.length; index++) {
    if (foodRecordsLikelySameStore(foods[index], item)) {
      return index;
    }
  }
  return -1;
}

export function aggregateFoodProviderResults(results: FoodProviderResult[]): FoodAggregationResult {
  const foods: A2uiFoodData[] = [];
  const issues: FoodProviderResult[] = [];
  for (let resultIndex = 0; resultIndex < results.length; resultIndex++) {
    const result = results[resultIndex];
    if (result.error.length > 0 || result.foods.length === 0) {
      issues.push({
        provider: result.provider,
        foods: [],
        error: result.error.length > 0 ? result.error : result.provider + '没有返回可展示结果。'
      });
    }
    for (let foodIndex = 0; foodIndex < result.foods.length; foodIndex++) {
      const food = result.foods[foodIndex];
      if (food.name.length === 0) {
        continue;
      }
      const existingIndex = findExistingFoodIndex(foods, food);
      if (existingIndex >= 0) {
        mergeFoodInto(foods[existingIndex], food, result.provider);
      } else {
        foods.push(cloneFood(food, result.provider));
      }
    }
  }
  return {
    foods: selectVisibleFoodResults(foods),
    issues: issues
  };
}

export function providerIssueRows(issues: FoodProviderResult[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  for (let index = 0; index < issues.length; index++) {
    const issue = issues[index];
    rows.push({
      label: issue.provider,
      value: issue.error.length > 0 ? issue.error : issue.provider + '没有返回可展示结果。'
    });
  }
  return rows;
}

export function foodProviderProgressRows(providerNames: string[], completedResults: FoodProviderResult[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  for (let providerIndex = 0; providerIndex < providerNames.length; providerIndex++) {
    const providerName = providerNames[providerIndex];
    let completedResult: FoodProviderResult | null = null;
    for (let resultIndex = 0; resultIndex < completedResults.length; resultIndex++) {
      const candidate = completedResults[resultIndex];
      if (candidate.provider === providerName) {
        completedResult = candidate;
      }
    }
    if (completedResult === null) {
      rows.push({
        label: providerName,
        value: '等待中'
      });
    } else if (completedResult.error.length > 0) {
      rows.push({
        label: providerName,
        value: completedResult.error
      });
    } else {
      rows.push({
        label: providerName,
        value: '已返回 ' + completedResult.foods.length.toString() + ' 条'
      });
    }
  }
  return rows;
}

export async function streamFoodProviderResultsWithPartials(tasks: Promise<FoodProviderResult>[], initialResults: FoodProviderResult[], onPartial: (snapshot: FoodProviderPartialSnapshot) => void, partialDelayMs: number = 0): Promise<FoodProviderStreamResult> {
  const providerResults: FoodProviderResult[] = initialResults.slice();
  let completed = 0;
  const delayMs = partialDelayMs > 0 ? partialDelayMs : 0;
  let partialChain: Promise<void> = Promise.resolve();
  const wrappedTasks: Promise<void>[] = [];
  for (let index = 0; index < tasks.length; index++) {
    wrappedTasks.push(tasks[index].then((result: FoodProviderResult) => {
      partialChain = partialChain.then(async () => {
        if (completed > 0 && delayMs > 0) {
          aiLogInfo('[AIPhone][LocalToolFoodPartialDelay] provider=' + result.provider +
            ' delayMs=' + delayMs.toString());
          await waitForDebugDelay(delayMs);
        }
        providerResults.push(result);
        completed += 1;
        const aggregated = aggregateFoodProviderResults(providerResults);
        onPartial({
          provider: result.provider,
          completed: completed,
          total: tasks.length,
          foods: aggregated.foods,
          issues: aggregated.issues,
          results: providerResults.slice()
        });
      });
      return partialChain;
    }));
  }
  await Promise.all(wrappedTasks);
  await partialChain;
  return {
    aggregation: aggregateFoodProviderResults(providerResults),
    results: providerResults
  };
}

function emptyProviderResult(provider: string, error: string): FoodProviderResult {
  return {
    provider: provider,
    foods: [],
    error: error
  };
}

function meituanRecordsFromContainer(value: MeituanUnionRecord[] | MeituanUnionRecordContainer | undefined): MeituanUnionRecord[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  const container = value as MeituanUnionRecordContainer;
  if (container.list !== undefined && container.list.length > 0) {
    return container.list;
  }
  if (container.records !== undefined && container.records.length > 0) {
    return container.records;
  }
  if (container.items !== undefined && container.items.length > 0) {
    return container.items;
  }
  if (container.products !== undefined && container.products.length > 0) {
    return container.products;
  }
  return [];
}

function meituanProviderError(payload: MeituanUnionPayload): string {
  const message = firstText([payload.error, payload.message, payload.msg]);
  const code = textOf(payload.code);
  const status = textOf(payload.status);
  if (code.length > 0 && code !== '0' && code !== '200') {
    return message.length > 0 ? message + '（code=' + code + '）' : '美团联盟返回 code=' + code;
  }
  if (status === '0' || status.toLowerCase() === 'false') {
    return message.length > 0 ? message : '美团联盟返回失败状态。';
  }
  return '';
}

function taobaoResponseResult(payload: TaobaoFlashPayload): TaobaoFlashResult {
  const response = payload.alibaba_alsc_union_eleme_promotion_storepromotion_query_response;
  if (response !== undefined) {
    if (response.result !== undefined) {
      return response.result;
    }
    if (response.data !== undefined) {
      if (Array.isArray(response.data)) {
        return { result_list: response.data };
      }
      return response.data as TaobaoFlashResult;
    }
  }
  const direct = payload as TaobaoFlashResponse;
  if (direct.result !== undefined) {
    return direct.result;
  }
  if (direct.data !== undefined) {
    if (Array.isArray(direct.data)) {
      return { result_list: direct.data };
    }
    return direct.data as TaobaoFlashResult;
  }
  return {};
}

function taobaoProviderError(payload: TaobaoFlashPayload): string {
  if (payload.error_response !== undefined) {
    return firstText([
      payload.error_response.sub_msg,
      payload.error_response.msg,
      payload.error_response.sub_code,
      payload.error_response.code
    ]);
  }
  const result = taobaoResponseResult(payload);
  if (textOf(result.success).toLowerCase() === 'false') {
    return firstText([result.msg_info, result.msg_code, '淘宝闪购返回失败状态。']);
  }
  return '';
}

function taobaoRecordsFromResult(result: TaobaoFlashResult): TaobaoFlashStoreRecord[] {
  if (result.result_list !== undefined && result.result_list.length > 0) {
    return result.result_list;
  }
  if (result.records !== undefined && result.records.length > 0) {
    return result.records;
  }
  if (result.data !== undefined && result.data.length > 0) {
    return result.data;
  }
  return [];
}

async function safeFoodProviderSearch(adapter: FoodProviderAdapter, prompt: string, query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
  try {
    return await adapter.search(prompt, query, keyword, location, locationSource);
  } catch (error) {
    return emptyProviderResult(adapter.name, describeThrown(error));
  }
}

function waitForDebugDelay(delayMs: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, delayMs);
  });
}

class AmapFoodProvider implements FoodProviderAdapter {
  name: string = '高德';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const key = localProviderConfig.amapKey;
    if (key.length === 0) {
      return emptyProviderResult(this.name, '未配置 AMAP_KEY');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用高德周边 POI。');
    }
    const foods: A2uiFoodData[] = [];
    const names: string[] = [];
    let totalPois = 0;
    let providerError = '';
    const keywords = splitFoodSearchKeywords(keyword);
    for (let keywordIndex = 0; keywordIndex < keywords.length && keywordIndex < 4 && foods.length < FOOD_PROVIDER_RESULT_LIMIT; keywordIndex++) {
      const currentKeyword = keywords[keywordIndex];
      aiLogInfo('[AIPhone][LocalToolAmapRequest] keyChars=' + key.length.toString() +
        ' locationSource=' + locationSource + ' locationPresent=true keyword=' + currentKeyword);
      const payload = await amapJsonGet(buildQueryUrl(
        'https://restapi.amap.com/v3/place/around',
        ['key', 'location', 'types', 'keywords', 'radius', 'offset', 'page', 'extensions'],
        [key, location, '050000', currentKeyword, localProviderConfig.amapRadius, '10', '1', 'all']
      ));
      if (textOf(payload.status) !== '1') {
        const providerMessage = firstText([payload.info, payload.infocode, payload.message]);
        if (providerError.length === 0) {
          providerError = providerMessage.length > 0 ? providerMessage : JSON.stringify(payload).substring(0, 500);
        }
        continue;
      }
      const pois = payload.pois === undefined ? [] : payload.pois;
      totalPois += pois.length;
      for (let index = 0; index < pois.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
        const food = foodRecordForA2ui(pois[index]);
        const normalized = normalizeFoodName(food.name);
        if (food.name.length === 0 || names.indexOf(normalized) >= 0) {
          continue;
        }
        names.push(normalized);
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolAmapResult] pois=' + totalPois.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : (providerError.length > 0 ? providerError : '高德没有返回可展示餐饮 POI。')
    };
  }
}

class TencentMapFoodProvider implements FoodProviderAdapter {
  name: string = '腾讯地图';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const key = localProviderConfig.tencentMapKey;
    if (key.length === 0) {
      return emptyProviderResult(this.name, '未配置 TENCENT_MAP_KEY');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用腾讯地图周边搜索。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const boundary = 'nearby(' + latitude + ',' + longitude + ',' + localProviderConfig.amapRadius + ',1)';
    aiLogInfo('[AIPhone][LocalToolTencentMapRequest] endpoint=' + localProviderConfig.tencentMapApiUrl +
      ' keyChars=' + key.length.toString() + ' locationSource=' + locationSource + ' keyword=' + keyword);
    const response = await requestText(buildQueryUrl(
      localProviderConfig.tencentMapApiUrl,
      ['key', 'keyword', 'boundary', 'page_size', 'page_index', 'orderby'],
      [key, keyword, boundary, '10', '1', '_distance']
    ), userAgentHeaders());
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300));
    }
    const payload = JSON.parse(response.text) as TencentMapPayload;
    if (textOf(payload.status) !== '0') {
      const message = firstText([payload.message, payload.status]);
      return emptyProviderResult(this.name, message.length > 0 ? message : response.text.substring(0, 300));
    }
    const places = payload.data === undefined ? [] : payload.data;
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < places.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromTencentMapPlace(places[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolTencentMapResult] rows=' + places.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '腾讯地图没有返回可展示餐饮 POI。'
    };
  }
}

class BaiduMapFoodProvider implements FoodProviderAdapter {
  name: string = '百度地图';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, locationSource: string): Promise<FoodProviderResult> {
    const ak = localProviderConfig.baiduMapAk;
    if (ak.length === 0) {
      return emptyProviderResult(this.name, '未配置 BAIDU_MAP_AK');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用百度地图地点检索。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    aiLogInfo('[AIPhone][LocalToolBaiduMapRequest] endpoint=' + localProviderConfig.baiduMapApiUrl +
      ' akChars=' + ak.length.toString() + ' locationSource=' + locationSource + ' keyword=' + keyword);
    const response = await requestText(buildQueryUrl(
      localProviderConfig.baiduMapApiUrl,
      ['ak', 'query', 'location', 'radius', 'output', 'scope', 'coord_type', 'ret_coordtype', 'page_size', 'page_num'],
      [ak, keyword, latitude + ',' + longitude, localProviderConfig.amapRadius, 'json', '2', '2', 'gcj02ll', '10', '0']
    ), userAgentHeaders());
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300));
    }
    const payload = JSON.parse(response.text) as BaiduPlacePayload;
    if (textOf(payload.status) !== '0') {
      const message = firstText([payload.message, payload.status]);
      return emptyProviderResult(this.name, message.length > 0 ? message : response.text.substring(0, 300));
    }
    const places = payload.results === undefined ? [] : payload.results;
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < places.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromBaiduPlace(places[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolBaiduMapResult] rows=' + places.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '百度地图没有返回可展示餐饮 POI。'
    };
  }
}

class GoogleMapsFoodProvider implements FoodProviderAdapter {
  name: string = 'Google Maps';

  async search(prompt: string, query: FoodQuery, keyword: string, _location: string, _locationSource: string): Promise<FoodProviderResult> {
    const searchQuery = query.place.length > 0 ? query.place + '附近的' + keyword : prompt;
    const results = await callMapsPlaceSearch(searchQuery, localProviderConfig.googleMapsApiKey);
    const foods: A2uiFoodData[] = [];
    let providerError = '';
    for (let index = 0; index < results.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const result = results[index];
      if (result.status !== 'success') {
        if (providerError.length === 0) {
          providerError = result.summary;
        }
        continue;
      }
      const food = mapsFoodRecordFromResult(result);
      if (food.name.length > 0 && food.location !== undefined && food.location.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolGoogleMapsResult] rows=' + results.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : (providerError.length > 0 ? providerError : 'Google Maps 没有返回可展示餐饮 POI。')
    };
  }
}

class MeituanUnionFoodProvider implements FoodProviderAdapter {
  name: string = '美团';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const appKey = localProviderConfig.meituanUnionAppKey;
    const appSecret = localProviderConfig.meituanUnionAppSecret;
    if (appKey.length === 0 || appSecret.length === 0) {
      return emptyProviderResult(this.name, '未配置 MEITUAN_UNION_APP_KEY 或 MEITUAN_UNION_APP_SECRET');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法按附近外卖商品查询。');
    }
    const longitude = coordinateToMicros(locationLongitude(location));
    const latitude = coordinateToMicros(locationLatitude(location));
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const body = '{"platform":1,"bizLine":1,"searchText":' + JSON.stringify(keyword) +
      ',"longitude":' + longitude +
      ',"latitude":' + latitude +
      ',"pageSize":10,"pageNo":1}';
    const timestamp = new Date().getTime().toString();
    const contentMd5 = md5Base64(body);
    const signature = meituanUnionSignature(appSecret, appKey, timestamp, contentMd5, body);
    aiLogInfo('[AIPhone][LocalToolMeituanRequest] endpoint=' + localProviderConfig.meituanUnionApiUrl +
      ' keyChars=' + appKey.length.toString() + ' keyword=' + keyword + ' bodyChars=' + body.length.toString());
    const response = await postJsonText(localProviderConfig.meituanUnionApiUrl, {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Content-MD5': contentMd5,
      'S-Ca-App': appKey,
      'S-Ca-Timestamp': timestamp,
      'S-Ca-Signature-Headers': 'S-Ca-Timestamp,S-Ca-App',
      'S-Ca-Signature': signature
    }, body);
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300));
    }
    const payload = JSON.parse(response.text) as MeituanUnionPayload;
    const providerError = meituanProviderError(payload);
    if (providerError.length > 0) {
      return emptyProviderResult(this.name, providerError);
    }
    const records = meituanRecordsFromContainer(payload.data).length > 0 ?
      meituanRecordsFromContainer(payload.data) :
      meituanRecordsFromContainer(payload.result);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < records.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromMeituanUnion(records[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolMeituanResult] rows=' + records.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '美团联盟没有返回可展示外卖商品券。'
    };
  }
}

class TaobaoFlashFoodProvider implements FoodProviderAdapter {
  name: string = '淘宝闪购';

  async search(_prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const appKey = localProviderConfig.taobaoAppKey;
    const appSecret = localProviderConfig.taobaoAppSecret;
    const pid = localProviderConfig.taobaoFlashPid;
    if (appKey.length === 0 || appSecret.length === 0 || pid.length === 0) {
      return emptyProviderResult(this.name, '未配置 TAOBAO_APP_KEY、TAOBAO_APP_SECRET 或 TAOBAO_FLASH_PID');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用淘宝闪购店铺推广查询。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const queryRequest = '{"pid":' + JSON.stringify(pid) +
      ',"longitude":' + JSON.stringify(longitude) +
      ',"latitude":' + JSON.stringify(latitude) +
      ',"search_content":' + JSON.stringify(keyword) +
      ',"page_size":10,"include_dynamic":true}';
    const params: FoodParamPair[] = [
      { key: 'method', value: 'alibaba.alsc.union.eleme.promotion.storepromotion.query' },
      { key: 'app_key', value: appKey },
      { key: 'timestamp', value: formatTopTimestamp(new Date()) },
      { key: 'format', value: 'json' },
      { key: 'v', value: '2.0' },
      { key: 'sign_method', value: 'md5' },
      { key: 'simplify', value: 'true' },
      { key: 'query_request', value: queryRequest }
    ];
    params.push({ key: 'sign', value: topMd5Sign(params, appSecret) });
    const body = encodeForm(params);
    aiLogInfo('[AIPhone][LocalToolTaobaoFlashRequest] endpoint=' + localProviderConfig.taobaoApiUrl +
      ' keyChars=' + appKey.length.toString() + ' pidChars=' + pid.length.toString() +
      ' keyword=' + keyword + ' bodyChars=' + body.length.toString());
    const response = await postFormText(localProviderConfig.taobaoApiUrl, {
      'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'
    }, body);
    if (response.code < 200 || response.code >= 300) {
      return emptyProviderResult(this.name, 'HTTP ' + response.code.toString() + '：' + response.text.substring(0, 300));
    }
    const payload = JSON.parse(response.text) as TaobaoFlashPayload;
    const providerError = taobaoProviderError(payload);
    if (providerError.length > 0) {
      return emptyProviderResult(this.name, providerError);
    }
    const result = taobaoResponseResult(payload);
    const records = taobaoRecordsFromResult(result);
    const foods: A2uiFoodData[] = [];
    for (let index = 0; index < records.length && foods.length < FOOD_PROVIDER_RESULT_LIMIT; index++) {
      const food = foodRecordFromTaobaoFlashStore(records[index]);
      if (food.name.length > 0) {
        foods.push(food);
      }
    }
    aiLogInfo('[AIPhone][LocalToolTaobaoFlashResult] rows=' + records.length.toString() + ' returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '淘宝闪购没有返回可展示店铺推广结果。'
    };
  }
}

function foodPartialA2ui(surfaceId: string, prompt: string, providerNames: string[], snapshot: FoodProviderPartialSnapshot, previous: A2uiPartialUpdateCache | null): A2uiPartialUpdateResult {
  const rows = foodProviderProgressRows(providerNames, snapshot.results);
  return planA2uiPartialUpdate(previous, foodA2uiRenderState(
    surfaceId,
    '外卖聚合搜索',
    '以下结果来自高德、腾讯地图、百度地图、Google Maps、美团联盟、淘宝闪购联盟，以及已配置的麦当劳/瑞幸官方 MCP；仅展示真实返回字段，不下单、不支付、不创建购物车。',
    '已返回 ' + snapshot.completed.toString() + '/' + snapshot.total.toString() +
      ' 个餐饮来源；当前可展示 ' + snapshot.foods.length.toString() + ' 个结果。用户请求：' + prompt,
    snapshot.foods,
    rows,
    'calling_tool'
  ));
}

function shouldQueryMcDonalds(prompt: string, keyword: string): boolean {
  return /麦当劳|mcdonald|mcd|巨无霸|麦乐鸡|麦辣|薯条|汉堡|板烧|麦乐送/i.test(prompt + ' ' + keyword);
}

function shouldQueryLuckin(prompt: string, keyword: string): boolean {
  return /瑞幸|luckin|咖啡|拿铁|美式|生椰|冰萃|澳瑞白|厚乳|饮品/i.test(prompt + ' ' + keyword);
}

function inferFoodCityFromText(text: string): string {
  const direct = inferAmapCityFromPlace(text);
  if (direct.length > 0) {
    return direct;
  }
  const cityMatch = /(北京|上海|天津|重庆|深圳|广州|杭州|成都|武汉|南京|西安|苏州|厦门|青岛|长沙|昆明|海口|三亚|东莞|佛山|郑州|宁波|无锡|合肥|福州|济南|沈阳|大连)/u.exec(text);
  return cityMatch === null ? '深圳' : cityMatch[1];
}

function brandSearchKeyword(prompt: string, query: FoodQuery, fallback: string): string {
  if (query.place.length > 0) {
    return query.place;
  }
  const cleaned = prompt
    .replace(/麦当劳|瑞幸|luckin|mcdonald|mcd/ig, '')
    .replace(/附近|周边|查询|查|搜索|帮我|门店|菜单|有什么|外卖|点餐/g, '')
    .trim();
  return cleaned.length > 0 ? cleaned : fallback;
}

function wantsBrandMenu(prompt: string, keyword: string): boolean {
  return /菜单|餐品|商品|价格|多少钱|套餐|汉堡|薯条|麦乐鸡|咖啡|拿铁|美式|生椰|冰萃|饮品/u.test(prompt + ' ' + keyword);
}

class McDonaldsMcpFoodProvider implements FoodProviderAdapter {
  name: string = '麦当劳';

  async search(prompt: string, query: FoodQuery, keyword: string, _location: string, _locationSource: string): Promise<FoodProviderResult> {
    const token = localProviderConfig.mcdMcpToken;
    if (token.length === 0) {
      return emptyProviderResult(this.name, '未配置 MCD_MCP_TOKEN');
    }
    const city = inferFoodCityFromText(query.place.length > 0 ? query.place : prompt);
    const searchKeyword = brandSearchKeyword(prompt, query, keyword);
    const storeArgs: McDonaldsNearbyStoresArgs = {
      searchType: 2,
      beType: 1,
      city: city,
      keyword: searchKeyword
    };
    const storePayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.mcdMcpUrl, token, 'query-nearby-stores', storeArgs);
    let foods = foodRecordsFromMcDonaldsMcpTool('query-nearby-stores', storePayload);
    const firstStore = firstMcDonaldsStore(storePayload);
    if (wantsBrandMenu(prompt, keyword) && firstStore !== null && textOf(firstStore.storeCode).length > 0) {
      const menuArgs: McDonaldsMealsArgs = {
        storeCode: textOf(firstStore.storeCode),
        beCode: textOf(firstStore.beCode),
        orderType: 1,
        beType: 1
      };
      const menuPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.mcdMcpUrl, token, 'query-meals', menuArgs);
      foods = foods.concat(foodRecordsFromMcDonaldsMcpTool('query-meals', menuPayload));
    }
    aiLogInfo('[AIPhone][LocalToolMcDonaldsMcpResult] returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '麦当劳 MCP 没有返回可展示的门店或菜单结果。'
    };
  }
}

class LuckinMcpFoodProvider implements FoodProviderAdapter {
  name: string = '瑞幸';

  async search(prompt: string, _query: FoodQuery, keyword: string, location: string, _locationSource: string): Promise<FoodProviderResult> {
    const token = localProviderConfig.luckinMcpToken;
    if (token.length === 0) {
      return emptyProviderResult(this.name, '未配置 LUCKIN_MCP_TOKEN');
    }
    if (location.length === 0) {
      return emptyProviderResult(this.name, '缺少经纬度，无法调用瑞幸门店查询。');
    }
    const longitude = locationLongitude(location);
    const latitude = locationLatitude(location);
    if (longitude.length === 0 || latitude.length === 0) {
      return emptyProviderResult(this.name, '经纬度格式无效：' + location);
    }
    const emptyQuery: FoodQuery = { place: '', keyword: keyword };
    const shopArgs: LuckinShopListArgs = {
      deptName: /瑞幸|luckin/i.test(prompt) ? brandSearchKeyword(prompt, emptyQuery, '') : '',
      longitude: Number(longitude),
      latitude: Number(latitude)
    };
    const shopPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.luckinMcpUrl, token, 'queryShopList', shopArgs);
    let foods = foodRecordsFromLuckinMcpTool('queryShopList', shopPayload);
    const firstShop = firstLuckinShop(shopPayload);
    if (wantsBrandMenu(prompt, keyword) && firstShop !== null && textOf(firstShop.deptId).length > 0) {
      const productArgs: LuckinProductSearchArgs = {
        deptId: Number(textOf(firstShop.deptId)),
        query: keyword
      };
      const productPayload = await callReadonlyBrandMcpTool(this.name, localProviderConfig.luckinMcpUrl, token, 'searchProductForMcp', productArgs);
      foods = foods.concat(foodRecordsFromLuckinMcpTool('searchProductForMcp', productPayload));
    }
    aiLogInfo('[AIPhone][LocalToolLuckinMcpResult] returned=' + foods.length.toString());
    return {
      provider: this.name,
      foods: foods,
      error: foods.length > 0 ? '' : '瑞幸 MCP 没有返回可展示的门店或商品结果。'
    };
  }
}

async function callLocalFoodSearch(prompt: string, surfaceId: string, emitJsonl: LocalA2uiEmitter | null = null): Promise<string> {
  const key = localProviderConfig.amapKey;

  const query = extractFoodQuery(prompt);
  const preflightResults: FoodProviderResult[] = [];
  let locationSource = 'none';
  let location = parseCoordinatePair(prompt);
  if (location.length > 0) {
    locationSource = 'prompt_coords';
  } else if (query.place.length > 0 && key.length > 0) {
    try {
      const resolved = await resolveFoodSearchLocation(query.place, key);
      location = resolved.location;
      locationSource = resolved.locationSource;
    } catch (error) {
      preflightResults.push(emptyProviderResult('高德', '地点解析失败：' + describeThrown(error)));
      locationSource = 'geocode_error';
    }
  }
  if (location.length === 0) {
    location = defaultConfiguredLocation();
    if (location.length > 0) {
      locationSource = 'rawfile_default';
    }
  }
  const keyword = extractFoodKeyword(prompt);

  const adapters: FoodProviderAdapter[] = [
    new AmapFoodProvider(),
    new TencentMapFoodProvider(),
    new BaiduMapFoodProvider(),
    new MeituanUnionFoodProvider(),
    new TaobaoFlashFoodProvider()
  ];
  if (localProviderConfig.googleMapsApiKey.length > 0) {
    adapters.push(new GoogleMapsFoodProvider());
  }
  if (shouldQueryMcDonalds(prompt, keyword)) {
    adapters.push(new McDonaldsMcpFoodProvider());
  }
  if (shouldQueryLuckin(prompt, keyword)) {
    adapters.push(new LuckinMcpFoodProvider());
  }
  const providerNames: string[] = [];
  for (let preflightIndex = 0; preflightIndex < preflightResults.length; preflightIndex++) {
    const providerName = preflightResults[preflightIndex].provider;
    if (providerNames.indexOf(providerName) < 0) {
      providerNames.push(providerName);
    }
  }
  for (let adapterIndex = 0; adapterIndex < adapters.length; adapterIndex++) {
    if (providerNames.indexOf(adapters[adapterIndex].name) < 0) {
      providerNames.push(adapters[adapterIndex].name);
    }
  }
  const providerResults: FoodProviderResult[] = preflightResults.slice();
  if (location.length === 0) {
    providerResults.push(emptyProviderResult('位置', '缺少经纬度。请在 prompt 写明地点，或把 AMAP_DEFAULT_LOCATION/FOOD_DEFAULT_LOCATION=经度,纬度 同步到 HAP rawfile。'));
    if (providerNames.indexOf('位置') < 0) {
      providerNames.push('位置');
    }
  }
  const tasks: Promise<FoodProviderResult>[] = [];
  for (let index = 0; index < adapters.length; index++) {
    tasks.push(safeFoodProviderSearch(adapters[index], prompt, query, keyword, location, locationSource));
  }
  let foodPartialCache: A2uiPartialUpdateCache | null = null;
  const streamed = await streamFoodProviderResultsWithPartials(tasks, providerResults, (snapshot: FoodProviderPartialSnapshot) => {
    aiLogInfo('[AIPhone][LocalToolFoodPartial] provider=' + snapshot.provider +
      ' completed=' + snapshot.completed.toString() + '/' + snapshot.total.toString() +
      ' foods=' + snapshot.foods.length.toString() +
      ' issues=' + snapshot.issues.length.toString());
    if (emitJsonl !== null) {
      const planned = foodPartialA2ui(surfaceId, prompt, providerNames, snapshot, foodPartialCache);
      foodPartialCache = planned.cache;
      aiLogInfo('[AIPhone][LocalToolFoodPartialEmit] envelopes=' + planned.emittedEnvelopeCount.toString() +
        ' components=' + (planned.componentsUpdated ? 'true' : 'false') +
        ' dataPaths=' + planned.updatedDataPaths.join(','));
      emitJsonl(planned.jsonl);
    }
  }, localToolDebugConfig.foodProviderDelayEnabled ? localToolDebugConfig.foodProviderDelayMs : 0);
  const aggregated = streamed.aggregation;
  const rows = foodProviderProgressRows(providerNames, streamed.results);
  aiLogInfo('[AIPhone][LocalToolFoodAggregate] keyword=' + keyword +
    ' locationSource=' + locationSource +
    ' locationPresent=' + (location.length > 0 ? 'true' : 'false') +
    ' foods=' + aggregated.foods.length.toString() +
    ' issues=' + rows.length.toString());

  const finalState = foodA2uiRenderState(
    surfaceId,
    '外卖聚合搜索',
    '以下结果来自高德、腾讯地图、百度地图、Google Maps、美团联盟、淘宝闪购联盟，以及已配置的麦当劳/瑞幸官方 MCP；仅展示真实返回字段，不下单、不支付、不创建购物车。',
    aggregated.foods.length > 0 ?
      '已聚合 ' + aggregated.foods.length.toString() + ' 个可展示结果；' + rows.length.toString() + ' 个来源状态见下方。' :
      '所有来源都没有可展示外卖结果；下面只列出真实 provider 状态。',
    aggregated.foods,
    rows,
    'ready'
  );
  if (emitJsonl !== null) {
    const planned = planA2uiPartialUpdate(foodPartialCache, finalState);
    foodPartialCache = planned.cache;
    aiLogInfo('[AIPhone][LocalToolFoodFinalEmit] envelopes=' + planned.emittedEnvelopeCount.toString() +
      ' components=' + (planned.componentsUpdated ? 'true' : 'false') +
      ' dataPaths=' + planned.updatedDataPaths.join(','));
    return planned.jsonl;
  }
  return planA2uiPartialUpdate(null, finalState).jsonl;
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
      '查询 12306 余票需要明确的出发地、目的地和日期。',
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

interface DynamicPromptArgs {
  query: string;
  prompt: string;
  city: string;
  weatherTargetOffset: number;
  weatherTargetDate: string;
  weatherTargetLabel: string;
  weatherForecast: boolean;
}

const dynamicToolRegistry: DynamicToolRegistry = new DynamicToolRegistry();
const genericMcpClient: GenericMcpClient = new GenericMcpClient();
const dynamicCredentialStore: AssetCredentialStore = new AssetCredentialStore();

let gmailMcpClient: GenericMcpClient = genericMcpClient;
let gmailCredentialStore: CredentialStore = dynamicCredentialStore;

export function configureGmailMcpClientForTests(client: GenericMcpClient | null): void {
  gmailMcpClient = client === null ? genericMcpClient : client;
}

export function configureGmailCredentialStoreForTests(store: CredentialStore | null): void {
  gmailCredentialStore = store === null ? dynamicCredentialStore : store;
}

function dynamicCityFromPrompt(prompt: string): string {
  if (prompt.indexOf('深圳') >= 0) {
    return '深圳';
  }
  if (prompt.indexOf('北京') >= 0) {
    return '北京';
  }
  if (prompt.indexOf('上海') >= 0) {
    return '上海';
  }
  if (prompt.indexOf('广州') >= 0) {
    return '广州';
  }
  return prompt;
}

function twoDigit(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function localDateAfter(offset: number): string {
  const today = new Date();
  const target = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset);
  return target.getFullYear().toString() + '-' + twoDigit(target.getMonth() + 1) + '-' + twoDigit(target.getDate());
}

function dynamicWeatherTargetOffset(prompt: string): number {
  if (prompt.indexOf('大后天') >= 0) {
    return 3;
  }
  if (prompt.indexOf('后天') >= 0) {
    return 2;
  }
  if (prompt.indexOf('明天') >= 0 || prompt.indexOf('明日') >= 0) {
    return 1;
  }
  return 0;
}

function dynamicWeatherTargetLabel(offset: number): string {
  if (offset === 1) {
    return '明天';
  }
  if (offset === 2) {
    return '后天';
  }
  if (offset === 3) {
    return '大后天';
  }
  return '当前';
}

function dynamicArgsFromPrompt(prompt: string): DynamicPromptArgs {
  const weatherTargetOffset = dynamicWeatherTargetOffset(prompt);
  return {
    query: prompt,
    prompt: prompt,
    city: dynamicCityFromPrompt(prompt),
    weatherTargetOffset: weatherTargetOffset,
    weatherTargetDate: localDateAfter(weatherTargetOffset),
    weatherTargetLabel: dynamicWeatherTargetLabel(weatherTargetOffset),
    weatherForecast: weatherTargetOffset > 0
  };
}

function transportOption(transport: DynamicToolTransport, key: string, fallback: string = ''): string {
  const fromProperty = (transport as Object as Record<string, string>)[key];
  if (typeof fromProperty === 'string' && fromProperty.trim().length > 0) {
    return fromProperty.trim();
  }
  const fromEnv = transport.env[key];
  return fromEnv === undefined || fromEnv === null || fromEnv.trim().length === 0 ? fallback : fromEnv.trim();
}

function appendQueryParam(url: string, key: string, value: string): string {
  if (key.length === 0 || value.length === 0) {
    return url;
  }
  const separator = url.indexOf('?') >= 0 ? '&' : '?';
  return url + separator + encodeURIComponent(key) + '=' + encodeURIComponent(value);
}

function appendFixedQuery(url: string, fixedQuery: string): string {
  const trimmed = fixedQuery.trim();
  if (trimmed.length === 0) {
    return url;
  }
  const separator = url.indexOf('?') >= 0 ? '&' : '?';
  return url + separator + trimmed;
}

function dynamicArgumentValue(args: DynamicPromptArgs, key: string): string {
  if (key === 'city') {
    return args.city;
  }
  if (key === 'prompt') {
    return args.prompt;
  }
  return args.query;
}

function dynamicHttpApiHeaders(transport: DynamicToolTransport, credentialValue: string): Record<string, string> {
  const headers: Record<string, string> = {};
  const keys = Object.keys(transport.headers);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    headers[key] = transport.headers[key];
  }
  const placement = transportOption(transport, 'credentialPlacement', '');
  if (credentialValue.length > 0 && placement === 'header') {
    const headerName = transportOption(transport, 'credentialParam', 'Authorization');
    headers[headerName] = headerName.toLowerCase() === 'authorization' ? 'Bearer ' + credentialValue : credentialValue;
  }
  return headers;
}

function dynamicHttpApiFixedQuery(transport: DynamicToolTransport, args: DynamicPromptArgs): string {
  if (args.weatherForecast) {
    return transportOption(transport, 'forecastQuery', transportOption(transport, 'fixedQuery', ''));
  }
  return transportOption(transport, 'fixedQuery', '');
}

function dynamicHttpApiUrl(transport: DynamicToolTransport, credentialValue: string, args: DynamicPromptArgs): string {
  let url = appendFixedQuery(transport.url, dynamicHttpApiFixedQuery(transport, args));
  const queryParam = transportOption(transport, 'queryParam', 'query');
  url = appendQueryParam(url, queryParam, dynamicArgumentValue(args, queryParam));
  if (credentialValue.length > 0 && transportOption(transport, 'credentialPlacement', '') === 'query') {
    url = appendQueryParam(url, transportOption(transport, 'credentialParam', 'key'), credentialValue);
  }
  return url;
}

async function requestDynamicHttpApiGet(url: string, headers: Record<string, string>): Promise<HttpTextResponse> {
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
    throw new Error('Dynamic HTTP API GET failed: ' + describeThrown(error));
  } finally {
    request.destroy();
  }
}

function rowsFromAmapWeather(live: AmapWeatherLive): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const pairs: A2uiLabelValueData[] = [
    { label: '城市', value: textOf(live.city) },
    { label: '天气', value: textOf(live.weather) },
    { label: '温度', value: textOf(live.temperature).length > 0 ? textOf(live.temperature) + '°C' : '' },
    { label: '风向', value: textOf(live.winddirection) },
    { label: '风力', value: textOf(live.windpower) },
    { label: '湿度', value: textOf(live.humidity).length > 0 ? textOf(live.humidity) + '%' : '' },
    { label: '发布时间', value: textOf(live.reporttime) }
  ];
  for (let index = 0; index < pairs.length; index++) {
    if (pairs[index].value.length > 0) {
      rows.push(pairs[index]);
    }
  }
  return rows;
}

function rowsFromAmapWeatherForecast(forecast: AmapWeatherForecast, cast: AmapWeatherCast): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const pairs: A2uiLabelValueData[] = [
    { label: '城市', value: textOf(forecast.city) },
    { label: '预报日期', value: textOf(cast.date) },
    { label: '白天天气', value: textOf(cast.dayweather) },
    { label: '夜间天气', value: textOf(cast.nightweather) },
    { label: '白天温度', value: textOf(cast.daytemp).length > 0 ? textOf(cast.daytemp) + '°C' : '' },
    { label: '夜间温度', value: textOf(cast.nighttemp).length > 0 ? textOf(cast.nighttemp) + '°C' : '' },
    { label: '白天风向', value: textOf(cast.daywind) },
    { label: '白天风力', value: textOf(cast.daypower) },
    { label: '夜间风向', value: textOf(cast.nightwind) },
    { label: '夜间风力', value: textOf(cast.nightpower) },
    { label: '预报发布时间', value: textOf(forecast.reporttime) }
  ];
  for (let index = 0; index < pairs.length; index++) {
    if (pairs[index].value.length > 0) {
      rows.push(pairs[index]);
    }
  }
  return rows;
}

function selectAmapWeatherCast(forecast: AmapWeatherForecast, args: DynamicPromptArgs): AmapWeatherCast | null {
  if (forecast.casts === undefined || forecast.casts.length === 0) {
    return null;
  }
  for (let index = 0; index < forecast.casts.length; index++) {
    if (textOf(forecast.casts[index].date) === args.weatherTargetDate) {
      return forecast.casts[index];
    }
  }
  if (args.weatherTargetOffset >= 0 && args.weatherTargetOffset < forecast.casts.length) {
    return forecast.casts[args.weatherTargetOffset];
  }
  return forecast.casts[0];
}

function amapForecastSummary(forecast: AmapWeatherForecast, cast: AmapWeatherCast, args: DynamicPromptArgs): string {
  const city = textOf(forecast.city).length > 0 ? textOf(forecast.city) : args.city;
  const date = textOf(cast.date).length > 0 ? textOf(cast.date) : args.weatherTargetDate;
  const dayWeather = textOf(cast.dayweather);
  const nightWeather = textOf(cast.nightweather);
  const dayTemp = textOf(cast.daytemp);
  const nightTemp = textOf(cast.nighttemp);
  let summary = city + args.weatherTargetLabel + '（' + date + '）';
  if (dayWeather.length > 0) {
    summary += '白天' + dayWeather;
  }
  if (dayTemp.length > 0) {
    summary += '，' + dayTemp + '°C';
  }
  if (nightWeather.length > 0) {
    summary += '；夜间' + nightWeather;
  }
  if (nightTemp.length > 0) {
    summary += '，' + nightTemp + '°C';
  }
  return summary + '。';
}

function dynamicHttpApiResultFromJson(registration: DynamicToolRegistration, response: HttpTextResponse, args: DynamicPromptArgs): DynamicGenericToolResult {
  if (registration.mcpToolName === 'maps_weather') {
    const payload = JSON.parse(response.text) as AmapWeatherPayload;
    if (args.weatherForecast) {
      const forecast = payload.forecasts !== undefined && payload.forecasts.length > 0 ? payload.forecasts[0] : null;
      const cast = forecast === null ? null : selectAmapWeatherCast(forecast, args);
      if (response.code >= 200 && response.code < 300 && payload.status === '1' && forecast !== null && cast !== null) {
        return {
          sourceTag: registration.displayName,
          toolName: registration.mcpToolName,
          title: '高德天气预报',
          status: 'success',
          summary: amapForecastSummary(forecast, cast, args),
          rows: rowsFromAmapWeatherForecast(forecast, cast),
          rawPreview: response.text.substring(0, 1200)
        };
      }
    }
    const live = payload.lives !== undefined && payload.lives.length > 0 ? payload.lives[0] : null;
    if (response.code >= 200 && response.code < 300 && payload.status === '1' && live !== null) {
      return {
        sourceTag: registration.displayName,
        toolName: registration.mcpToolName,
        title: '高德天气查询',
        status: 'success',
        summary: textOf(live.city) + '当前天气：' + textOf(live.weather) + '，' + textOf(live.temperature) + '°C。',
        rows: rowsFromAmapWeather(live),
        rawPreview: response.text.substring(0, 1200)
      };
    }
    return {
      sourceTag: registration.displayName,
      toolName: registration.mcpToolName,
      title: '高德天气查询失败',
      status: 'error',
      summary: textOf(payload.info).length > 0 ? textOf(payload.info) : '高德天气 API 返回异常。',
      rows: [
        { label: 'HTTP', value: response.code.toString() },
        { label: 'infocode', value: textOf(payload.infocode) }
      ],
      rawPreview: response.text.substring(0, 1200)
    };
  }

  return {
    sourceTag: registration.displayName,
    toolName: registration.mcpToolName,
    title: '动态 HTTP API 返回',
    status: response.code >= 200 && response.code < 300 ? 'success' : 'error',
    summary: response.code >= 200 && response.code < 300 ? '已收到远程 HTTP API 返回。' : '远程 HTTP API 返回 HTTP ' + response.code.toString(),
    rows: [{ label: 'HTTP', value: response.code.toString() }],
    rawPreview: response.text.substring(0, 1200)
  };
}

async function callDynamicHttpApiTool(registration: DynamicToolRegistration, credentialValue: string, prompt: string): Promise<DynamicGenericToolResult> {
  const method = transportOption(registration.transport, 'method', 'GET').toUpperCase();
  if (method !== 'GET') {
    return dynamicErrorResult(registration.displayName, registration.mcpToolName, 'HTTP API 暂不支持', '当前 HAP 动态 HTTP API 只支持 GET。');
  }
  try {
    const args = dynamicArgsFromPrompt(prompt);
    const url = dynamicHttpApiUrl(registration.transport, credentialValue, args);
    const response = await requestDynamicHttpApiGet(url, dynamicHttpApiHeaders(registration.transport, credentialValue));
    return dynamicHttpApiResultFromJson(registration, response, args);
  } catch (error) {
    return dynamicErrorResult(registration.displayName, registration.mcpToolName, 'HTTP API 调用失败', describeThrown(error));
  }
}

function firstSafeToolName(manifest: DynamicToolManifest): string {
  for (let index = 0; index < manifest.tools.length; index++) {
    if (!isUnsafeMcpTool(manifest.tools[index].name, manifest.tools[index].description)) {
      return manifest.tools[index].name;
    }
  }
  return '';
}

function firstRequiredCredential(manifest: DynamicToolManifest): DynamicCredentialSpec | null {
  for (let index = 0; index < manifest.requiredCredentials.length; index++) {
    if (manifest.requiredCredentials[index].required) {
      return manifest.requiredCredentials[index];
    }
  }
  return null;
}

function credentialNameFromRef(credentialRef: string): string {
  const index = credentialRef.lastIndexOf(':');
  if (index < 0 || index >= credentialRef.length - 1) {
    return '';
  }
  return credentialRef.substring(index + 1);
}

function missingDynamicManifest(toolId: string): DynamicToolManifest {
  return {
    id: 'dynamic.missing.' + toolId,
    displayName: toolId,
    sourceUrl: '',
    hosted: false,
    fromSiteUrl: '',
    capabilities: [],
    requiredCredentials: [],
    transports: [],
    tools: []
  };
}

function manifestForRegistration(registration: DynamicToolRegistration): DynamicToolManifest {
  const sample = sampleManifestForToolId(registration.toolId);
  if (sample !== null) {
    return sample;
  }
  const credentials: DynamicCredentialSpec[] = [];
  const credentialName = credentialNameFromRef(registration.credentialRef);
  if (credentialName.length > 0) {
    credentials.push({
      name: credentialName,
      description: 'Credential required by remote MCP server',
      required: true,
      placement: 'header',
      scheme: 'Bearer',
      testValue: ''
    });
  }
  return {
    id: registration.manifestId,
    displayName: registration.displayName,
    sourceUrl: registration.sourceUrl,
    hosted: true,
    fromSiteUrl: registration.sourceUrl,
    capabilities: [],
    requiredCredentials: credentials,
    transports: [registration.transport],
    tools: [{
      name: registration.mcpToolName,
      description: '',
      inputSchema: new Object()
    }]
  };
}

function manifestWithInferredCredential(manifest: DynamicToolManifest, credential: DynamicCredentialSpec): DynamicToolManifest {
  const credentials: DynamicCredentialSpec[] = [credential];
  for (let index = 0; index < manifest.requiredCredentials.length; index++) {
    if (manifest.requiredCredentials[index].name !== credential.name) {
      credentials.push(manifest.requiredCredentials[index]);
    }
  }
  return {
    id: manifest.id,
    displayName: manifest.displayName,
    sourceUrl: manifest.sourceUrl,
    hosted: manifest.hosted,
    fromSiteUrl: manifest.fromSiteUrl,
    capabilities: manifest.capabilities.slice(),
    requiredCredentials: credentials,
    transports: manifest.transports,
    tools: manifest.tools
  };
}

function dynamicErrorResult(displayName: string, toolName: string, title: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: displayName,
    toolName: toolName,
    title: title,
    status: 'error',
    summary: message,
    rows: [{ label: '状态', value: 'error' }],
    rawPreview: message
  };
}

function enabledRegistration(registration: DynamicToolRegistration): DynamicToolRegistration {
  return {
    toolId: registration.toolId,
    manifestId: registration.manifestId,
    displayName: registration.displayName,
    status: 'enabled',
    transport: registration.transport,
    mcpToolName: registration.mcpToolName,
    credentialRef: registration.credentialRef,
    sourceUrl: registration.sourceUrl,
    lastError: ''
  };
}

function failedRegistration(registration: DynamicToolRegistration, message: string): DynamicToolRegistration {
  return {
    toolId: registration.toolId,
    manifestId: registration.manifestId,
    displayName: registration.displayName,
    status: 'preflight_failed',
    transport: registration.transport,
    mcpToolName: registration.mcpToolName,
    credentialRef: registration.credentialRef,
    sourceUrl: registration.sourceUrl,
    lastError: message
  };
}

async function callEnabledDynamicTool(registration: DynamicToolRegistration, credentialValue: string, prompt: string, surfaceId: string): Promise<string> {
  try {
    if (registration.transport.type === 'http_api') {
      const result = await callDynamicHttpApiTool(registration, credentialValue, prompt);
      return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
    }
    const result = await genericMcpClient.callTool(registration, credentialValue, dynamicArgsFromPrompt(prompt));
    return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    const result = dynamicErrorResult(registration.displayName, registration.mcpToolName, 'MCP 工具调用失败', message);
    return genericToolResultsA2ui(surfaceId, registration.toolId, [result]);
  }
}

async function preflightAndCallDynamicTool(
  registration: DynamicToolRegistration,
  manifest: DynamicToolManifest,
  credentialValue: string,
  prompt: string,
  surfaceId: string
): Promise<string> {
  try {
    if (registration.transport.type === 'http_api') {
      const next = enabledRegistration(registration);
      dynamicToolRegistry.setRegistration(next);
      return callEnabledDynamicTool(next, credentialValue, prompt, surfaceId);
    }
    const preflight = await genericMcpClient.preflight(registration, credentialValue);
    if (!preflight.ok) {
      const message = preflight.message.length > 0 ? preflight.message : '远程 MCP 预检失败。';
      if (preflight.inferredCredential !== null) {
        const inferredManifest = manifestWithInferredCredential(manifest, preflight.inferredCredential);
        const inferredRef = credentialRefFor(manifest.id, preflight.inferredCredential.name);
        dynamicToolRegistry.enableAlias(registration.toolId, inferredManifest, registration.mcpToolName, inferredRef);
        return connectCardA2ui(surfaceId, registration.toolId, inferredManifest, 'needs_auth', message, prompt);
      }
      dynamicToolRegistry.setRegistration(failedRegistration(registration, message));
      return connectCardA2ui(surfaceId, registration.toolId, manifest, 'preflight_failed', message, prompt);
    }
    const next = enabledRegistration(registration);
    dynamicToolRegistry.setRegistration(next);
    return callEnabledDynamicTool(next, credentialValue, prompt, surfaceId);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    dynamicToolRegistry.setRegistration(failedRegistration(registration, message));
    return connectCardA2ui(surfaceId, registration.toolId, manifest, 'preflight_failed', message, prompt);
  }
}

async function buildRegisteredDynamicToolJsonl(registration: DynamicToolRegistration, prompt: string, surfaceId: string): Promise<string> {
  const manifest = manifestForRegistration(registration);
  const credentialValue = registration.credentialRef.length > 0 ? await dynamicCredentialStore.get(registration.credentialRef) : '';
  if (registration.credentialRef.length > 0 && credentialValue.length === 0 && registration.status !== 'enabled') {
    return connectCardA2ui(surfaceId, registration.toolId, manifest, 'needs_auth', '该工具需要凭据后才能测试连接。', prompt);
  }
  if (registration.status === 'enabled') {
    return callEnabledDynamicTool(registration, credentialValue, prompt, surfaceId);
  }
  return preflightAndCallDynamicTool(registration, manifest, credentialValue, prompt, surfaceId);
}

async function buildDynamicToolJsonlWithManifest(toolId: string, prompt: string, surfaceId: string, manifest: DynamicToolManifest): Promise<string> {
  const transport = selectBestRemoteTransport(manifest);
  if (transport === null) {
    return unsupportedTransportA2ui(surfaceId, toolId, manifest, prompt);
  }

  const mcpToolName = firstSafeToolName(manifest);
  if (mcpToolName.length === 0) {
    return connectCardA2ui(surfaceId, toolId, manifest, 'unsafe_action_blocked', '该 MCP 只暴露交易或高风险动作，当前版本不会自动调用。', prompt);
  }

  let credentialRef = '';
  let credentialValue = '';
  const requiredCredential = firstRequiredCredential(manifest);
  if (requiredCredential !== null) {
    credentialRef = credentialRefFor(manifest.id, requiredCredential.name);
    credentialValue = await dynamicCredentialStore.get(credentialRef);
    if (credentialValue.length === 0) {
      return connectCardA2ui(surfaceId, toolId, manifest, 'needs_auth', '该工具需要凭据后才能测试连接。', prompt);
    }
  }

  const candidate = dynamicToolRegistry.enableAlias(toolId, manifest, mcpToolName, credentialRef);
  if (candidate.status === 'unsupported_transport') {
    return unsupportedTransportA2ui(surfaceId, toolId, manifest, prompt);
  }
  if (candidate.status === 'unsafe_action_blocked') {
    return connectCardA2ui(surfaceId, toolId, manifest, 'unsafe_action_blocked', '该 MCP 只暴露交易或高风险动作，当前版本不会自动调用。', prompt);
  }
  return preflightAndCallDynamicTool(candidate, manifest, credentialValue, prompt, surfaceId);
}

function dynamicDiscoveryMissingManifest(prompt: string): DynamicToolManifest {
  const manifest = missingDynamicManifest('dynamic.search');
  manifest.displayName = '动态工具搜索';
  manifest.sourceUrl = 'modelscope-local-catalog';
  manifest.capabilities = ['dynamic.discovery'];
  manifest.tools = [{
    name: 'dynamic.search',
    description: 'Search the local ModelScope-derived MCP catalog for a matching remote tool.',
    inputSchema: new Object()
  }];
  manifest.fromSiteUrl = 'https://modelscope.cn/mcp';
  return manifest;
}

async function buildDiscoveredDynamicToolJsonl(prompt: string, surfaceId: string): Promise<string> {
  const discovery: DynamicToolDiscoveryResult | null = discoverDynamicToolForPrompt(prompt);
  if (discovery === null) {
    aiLogInfo('[AIPhone][DynamicToolDiscovery] query=' + prompt + ' selectedToolId=none source=modelscope-local-catalog');
    return connectCardA2ui(
      surfaceId,
      'dynamic.search',
      dynamicDiscoveryMissingManifest(prompt),
      'no_tool_found',
      '已根据用户请求搜索本机 ModelScope MCP 候选目录，但没有找到可直接接入的远程 MCP/API。',
      prompt
    );
  }
  aiLogInfo('[AIPhone][DynamicToolDiscovery] query=' + prompt +
    ' selectedToolId=' + discovery.toolId +
    ' manifestId=' + discovery.manifest.id +
    ' source=' + discovery.source +
    ' score=' + discovery.score.toString() +
    ' reason=' + discovery.reason);
  return buildDynamicToolJsonlWithManifest(discovery.toolId, prompt, surfaceId, discovery.manifest);
}

async function buildDynamicToolJsonl(toolId: string, prompt: string, surfaceId: string): Promise<string> {
  if (toolId === 'dynamic.search') {
    return buildDiscoveredDynamicToolJsonl(prompt, surfaceId);
  }

  const registration = dynamicToolRegistry.registrationForToolId(toolId);
  if (registration !== null) {
    return buildRegisteredDynamicToolJsonl(registration, prompt, surfaceId);
  }

  const manifest = sampleManifestForToolId(toolId);
  if (manifest === null) {
    return connectCardA2ui(surfaceId, toolId, missingDynamicManifest(toolId), 'no_tool_found', '没有找到可在鸿蒙设备直接运行的远程 MCP/API。', prompt);
  }

  return buildDynamicToolJsonlWithManifest(toolId, prompt, surfaceId, manifest);
}

function gmailAuthUnavailableMessage(toolId: string, prompt: string): string {
  return 'Gmail 工具 ' + toolId + ' 已在统一工具框架注册，但当前设备没有可用的 Google Workspace MCP OAuth 授权；Gmail Web 仅作为人工处理兜底。AIPhone 不会模拟 Gmail 邮件、草稿或发送结果。请求：' + prompt.substring(0, 160);
}

export function gmailOAuthConfigFromProvider(): GmailOAuthConfig {
  return {
    clientId: localProviderConfig.gmailOauthClientId,
    clientSecret: localProviderConfig.gmailOauthClientSecret,
    redirectUri: localProviderConfig.gmailOauthRedirectUri.length > 0 ? localProviderConfig.gmailOauthRedirectUri : GMAIL_DEFAULT_REDIRECT_URI,
    resource: GMAIL_MCP_RESOURCE,
    scopes: GOOGLE_CLOUD_OAUTH_SCOPES
  };
}

export async function prepareGoogleOAuthAuthorizationUrl(setupUrl: string = GMAIL_MCP_AUTH_SETUP_URL): Promise<string> {
  if (localProviderConfig.gmailAuthUrl.length > 0) {
    aiLogInfo('[AIPhone][GmailOAuthAuthorizeUrl] source=configured-url');
    return localProviderConfig.gmailAuthUrl;
  }
  const config = gmailOAuthConfigFromProvider();
  if (config.clientId.length === 0 || config.redirectUri.length === 0) {
    aiLogInfo('[AIPhone][GmailOAuthAuthorizeUrl] source=setup-docs clientConfigured=' +
      (config.clientId.length > 0 ? 'true' : 'false') +
      ' redirectConfigured=' + (config.redirectUri.length > 0 ? 'true' : 'false'));
    return setupUrl;
  }
  const pending = createGmailOAuthPending();
  await saveGmailOAuthPending(gmailCredentialStore, pending);
  aiLogInfo('[AIPhone][GmailOAuthPendingSaved] stateChars=' + pending.state.length.toString() +
    ' verifierChars=' + pending.codeVerifier.length.toString() +
    ' redirectChars=' + config.redirectUri.length.toString() +
    ' clientChars=' + config.clientId.length.toString());
  return buildGmailOAuthAuthorizationUrl({
    clientId: config.clientId,
    redirectUri: config.redirectUri,
    state: pending.state,
    codeChallenge: gmailPkceChallengeS256(pending.codeVerifier),
    resource: config.resource,
    scopes: config.scopes
  });
}

export async function prepareGmailOAuthAuthorizationUrl(): Promise<string> {
  return prepareGoogleOAuthAuthorizationUrl(GMAIL_MCP_AUTH_SETUP_URL);
}

async function gmailAccessTokenForMcp(): Promise<string> {
  aiLogInfo('[AIPhone][GmailAccessLoad] start');
  const token = await loadGmailOAuthTokenSet(gmailCredentialStore);
  if (token !== null) {
    aiLogInfo('[AIPhone][GmailAccessLoad] tokenSet=true accessChars=' + token.accessToken.length.toString() +
      ' refreshChars=' + token.refreshToken.length.toString() +
      ' fresh=' + (isGmailAccessTokenFresh(token) ? 'true' : 'false'));
    if (isGmailAccessTokenFresh(token)) {
      return token.accessToken;
    }
    if (token.refreshToken.length > 0) {
      const config = gmailOAuthConfigFromProvider();
      if (config.clientId.length === 0) {
        throw new Error('Gmail OAuth access token expired and OAuth client config is missing.');
      }
      const refreshed = await refreshGmailOAuthAccessToken(config, token.refreshToken);
      const saved = await saveGmailOAuthTokenSet(gmailCredentialStore, refreshed);
      aiLogInfo('[AIPhone][GmailAccessRefreshOk] accessChars=' + saved.accessToken.length.toString() +
        ' refreshChars=' + saved.refreshToken.length.toString());
      return saved.accessToken;
    }
    aiLogInfo('[AIPhone][GmailAccessLoad] expiredNoRefresh=true returningAccessChars=' + token.accessToken.length.toString());
    return token.accessToken;
  }
  const fallback = await gmailCredentialStore.get(GMAIL_ACCESS_TOKEN_REF);
  aiLogInfo('[AIPhone][GmailAccessLoad] tokenSet=false fallbackAccessChars=' + fallback.length.toString());
  return fallback;
}

function gmailMcpRegistration(toolId: string, mcpToolName: string): DynamicToolRegistration {
  const headers: Record<string, string> = {};
  if (localProviderConfig.gmailMcpUserProject.length > 0) {
    headers['x-goog-user-project'] = localProviderConfig.gmailMcpUserProject;
  }
  return {
    toolId: toolId,
    manifestId: 'google.gmail',
    displayName: 'Gmail',
    status: 'enabled',
    transport: {
      type: 'streamable_http',
      url: GMAIL_MCP_SERVER_URL,
      command: '',
      args: [],
      headers: headers,
      env: {}
    },
    mcpToolName: mcpToolName,
    credentialRef: GMAIL_ACCESS_TOKEN_REF,
    sourceUrl: GMAIL_MCP_SERVER_URL,
    lastError: ''
  };
}

async function gmailUnavailableA2ui(surfaceId: string, toolId: string, prompt: string, reason: string): Promise<string> {
  aiLogError('[AIPhone][GmailUnavailable] toolId=' + toolId + ' reason=' + reason.substring(0, 220));
  return gmailAuthRequiredA2ui(surfaceId, toolId, gmailAuthUnavailableMessage(toolId, prompt), await prepareGmailOAuthAuthorizationUrl());
}

function gmailErrorResult(toolName: string, message: string): DynamicGenericToolResult {
  return dynamicErrorResult('Gmail', toolName, 'Gmail MCP 调用失败', message);
}

function dynamicRowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  return '';
}

function mailArgs(args: Object | null): Record<string, Object | string | number | boolean | null | undefined> {
  if (args === null) {
    return JSON.parse('{}') as Record<string, Object | string | number | boolean | null | undefined>;
  }
  return args as Record<string, Object | string | number | boolean | null | undefined>;
}

function stringListArg(value: Object | string | number | boolean | null | undefined): string[] {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? [trimmed] : [];
  }
  if (!Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  const values = value as string[];
  for (let index = 0; index < values.length; index++) {
    const text = textOf(values[index]).trim();
    if (text.length > 0) {
      result.push(text);
    }
  }
  return result;
}

function hasMailTimeOperator(query: string): boolean {
  return query.indexOf('newer_than:') >= 0 || query.indexOf('older_than:') >= 0 ||
    query.indexOf('after:') >= 0 || query.indexOf('before:') >= 0;
}

function trimMailKeywordTail(value: string): string {
  let text = value.trim();
  const leading = ['"', "'", '“', '”', '‘', '’', ':', '：', ',', '，'];
  while (text.length > 0 && leading.indexOf(text.charAt(0)) >= 0) {
    text = text.substring(1).trim();
  }
  const stops = [' 的邮件', '的邮件', ' 邮件', '邮件', ' 相关邮件', '相关邮件', ' 相关', '相关'];
  let end = text.length;
  for (let index = 0; index < stops.length; index++) {
    const hit = text.indexOf(stops[index]);
    if (hit > 0 && hit < end) {
      end = hit;
    }
  }
  return text.substring(0, end).trim();
}

function isMailAsciiKeywordChar(char: string): boolean {
  if (char.length === 0) {
    return false;
  }
  const code = char.charCodeAt(0);
  return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
    char === '_' || char === '-' || char === '.';
}

function fallbackMailSearchQuery(prompt: string): string {
  const text = prompt.trim();
  const markers = ['关键词', '关键字', 'keyword', '包含', '含有'];
  for (let index = 0; index < markers.length; index++) {
    const marker = markers[index];
    const hit = text.toLowerCase().indexOf(marker.toLowerCase());
    if (hit >= 0) {
      const candidate = trimMailKeywordTail(text.substring(hit + marker.length));
      if (candidate.length > 0) {
        return candidate;
      }
    }
  }

  let current = '';
  let last = '';
  for (let index = 0; index < text.length; index++) {
    const char = text.charAt(index);
    if (isMailAsciiKeywordChar(char)) {
      current += char;
    } else if (current.length > 0) {
      const lower = current.toLowerCase();
      if (lower !== 'gmail' && lower !== 'qq' && lower !== 'mail' && lower !== 'email') {
        last = current;
      }
      current = '';
    }
  }
  if (current.length > 0) {
    const lower = current.toLowerCase();
    if (lower !== 'gmail' && lower !== 'qq' && lower !== 'mail' && lower !== 'email') {
      last = current;
    }
  }
  return last.length > 0 ? last : text;
}

function defaultMailSearchWindow(query: string): string {
  const trimmed = query.trim();
  if (trimmed.length === 0 || hasMailTimeOperator(trimmed)) {
    return trimmed;
  }
  return 'newer_than:30d ' + trimmed;
}

export function mailSearchArgs(prompt: string, args: Object | null): MailSearchArgs {
  const record = mailArgs(args);
  const providers = stringListArg(record.providers);
  const explicitQuery = textOf(record.query).trim();
  const query = explicitQuery.length > 0 ? explicitQuery : fallbackMailSearchQuery(prompt);
  const normalizedQuery = defaultMailSearchWindow(query);
  return {
    query: normalizedQuery.length > 0 ? normalizedQuery : defaultMailSearchWindow(prompt.trim()),
    pageSize: typeof record.pageSize === 'number' && record.pageSize > 0 ? Math.min(record.pageSize, 10) : 10,
    providers: providers.length > 0 ? providers : ['gmail', 'qq'],
    intentSummary: textOf(record.intentSummary)
  };
}

function mailDraftArgs(args: Object | null): MailDraftArgs {
  const record = mailArgs(args);
  return {
    provider: textOf(record.provider),
    accountLabel: textOf(record.accountLabel),
    threadId: textOf(record.threadId),
    messageId: textOf(record.messageId),
    to: stringListArg(record.to),
    subject: textOf(record.subject),
    body: textOf(record.body),
    replyMode: textOf(record.replyMode),
    contextSummary: textOf(record.contextSummary)
  };
}

function qqMailConfig(): QqMailConfig {
  return {
    address: localProviderConfig.qqMailAddress,
    authCode: localProviderConfig.qqMailAuthCode,
    imapHost: localProviderConfig.qqMailImapHost,
    imapPort: Number.parseInt(localProviderConfig.qqMailImapPort, 10) || 993,
    draftsMailbox: localProviderConfig.qqMailDraftsMailbox
  };
}

function mailProviderError(provider: string, message: string): MailProviderStatus {
  return {
    provider: provider,
    status: 'error',
    title: provider === 'qq' ? 'QQ 邮箱调用失败' : 'Gmail 调用失败',
    message: message
  };
}

function gmailResultsHaveError(results: DynamicGenericToolResult[]): boolean {
  return results.length > 0 && results[0].status === 'error';
}

function gmailResultErrorSummary(results: DynamicGenericToolResult[]): string {
  if (results.length === 0) {
    return 'empty Gmail API result';
  }
  return results[0].summary.length > 0 ? results[0].summary : results[0].title;
}

function youtubeQueryFromArgs(prompt: string, args: Object | null): string {
  return mediaVideoQueryFromArgs(prompt, args);
}

async function callLocalYouTubeTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'youtube.video.search') {
    return genericToolResultsA2ui(
      surfaceId,
      toolId,
      await callYouTubeVideoSearch(youtubeQueryFromArgs(prompt, args), localProviderConfig.youtubeApiKey)
    );
  }
  return genericToolResultsA2ui(surfaceId, toolId, [{
    sourceTag: 'YouTube Data API',
    toolName: toolId,
    title: 'YouTube OAuth 授权需要登录',
    status: 'auth_required',
    summary: '当前设备没有可用的 YouTube OAuth 授权；不会模拟播放列表或订阅内容。',
    rows: [
      { label: 'OAuth', value: 'Google YouTube scope required' },
      { label: 'Client', value: localProviderConfig.googleOauthClientId.length > 0 ? 'configured' : 'missing GOOGLE_OAUTH_CLIENT_ID' }
    ],
    rawPreview: 'youtube oauth required'
  }]);
}

async function callLocalMediaTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'media.video.search') {
    return genericToolResultsA2ui(
      surfaceId,
      toolId,
      await callMediaVideoSearch(
        prompt,
        args,
        localProviderConfig.youtubeApiKey
      )
    );
  }
  return genericToolResultsA2ui(surfaceId, toolId, [{
    sourceTag: '媒体聚合',
    toolName: toolId,
    title: '未知媒体工具',
    status: 'error',
    summary: '当前媒体聚合只支持 media.video.search。',
    rows: [{ label: 'Tool ID', value: toolId }],
    rawPreview: 'unknown media tool'
  }]);
}

async function callLocalGmailTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'gmail.message.send') {
    return gmailBlockedSendA2ui(surfaceId, toolId);
  }
  if (toolId === 'gmail.open.web') {
    return gmailOpenWebA2ui(surfaceId, 'https://mail.google.com/mail/u/0/#inbox');
  }
  const mcpToolName = gmailMcpToolNameForToolId(toolId);
  if (mcpToolName.length === 0) {
    return gmailAuthRequiredA2ui(surfaceId, toolId, '未知 Gmail 工具：' + toolId, GMAIL_MCP_AUTH_SETUP_URL);
  }

  let accessToken = '';
  try {
    accessToken = await gmailAccessTokenForMcp();
  } catch (error) {
    return gmailUnavailableA2ui(surfaceId, toolId, prompt, describeThrown(error));
  }
  if (accessToken.length === 0) {
    aiLogInfo('[AIPhone][GmailAccessMissing] toolId=' + toolId);
    return gmailAuthRequiredA2ui(surfaceId, toolId, gmailAuthUnavailableMessage(toolId, prompt), await prepareGmailOAuthAuthorizationUrl());
  }

  try {
    if (gmailMcpClient === genericMcpClient) {
      aiLogInfo('[AIPhone][GmailApiRequest] toolId=' + toolId);
      const apiResults = await callGmailApiTool(toolId, prompt, accessToken, args);
      if (gmailResultsHaveError(apiResults)) {
        aiLogInfo('[AIPhone][GmailApiErrorResult] toolId=' + toolId +
          ' reason=' + gmailResultErrorSummary(apiResults).substring(0, 180));
        if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
          return gmailDraftPreviewA2ui(surfaceId, apiResults[0]);
        }
        return gmailThreadResultsA2ui(surfaceId, toolId, apiResults);
      }
      if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
        return gmailDraftPreviewA2ui(surfaceId, apiResults[0]);
      }
      return gmailThreadResultsA2ui(surfaceId, toolId, apiResults);
    }
    aiLogInfo('[AIPhone][GmailMcpRequest] toolId=' + toolId +
      ' mcpToolName=' + mcpToolName);
    const result = await gmailMcpClient.callTool(gmailMcpRegistration(toolId, mcpToolName), accessToken, gmailMcpArgsForPrompt(toolId, prompt, args));
    if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
      return gmailDraftPreviewA2ui(surfaceId, result);
    }
    return gmailThreadResultsA2ui(surfaceId, toolId, [result]);
  } catch (error) {
    return gmailThreadResultsA2ui(surfaceId, toolId, [gmailErrorResult(mcpToolName, describeThrown(error))]);
  }
}

async function callLocalMailTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  if (toolId === 'mail.search') {
    const parsed = mailSearchArgs(prompt, args);
    const threads: MailThreadResult[] = [];
    const statuses: MailProviderStatus[] = [];

    if (parsed.providers.indexOf('gmail') >= 0) {
      try {
        const accessToken = await gmailAccessTokenForMcp();
        if (accessToken.length === 0) {
          statuses.push(mailProviderError('gmail', gmailAuthUnavailableMessage('gmail.mail.search', prompt)));
        } else {
          const gmailRows = await callGmailApiTool('gmail.mail.search', prompt, accessToken, parsed as Object);
          gmailRows.forEach((row: DynamicGenericToolResult) => {
            if (row.status === 'success' && row.toolName.indexOf('users.threads') === 0) {
              const threadId = dynamicRowValue(row, 'Thread ID');
              const labels = dynamicRowValue(row, 'Labels');
              threads.push({
                provider: 'gmail',
                accountLabel: 'Gmail',
                threadId: threadId,
                messageId: threadId,
                subject: row.title,
                from: dynamicRowValue(row, 'From'),
                to: [],
                participants: [],
                snippet: row.summary,
                receivedAt: dynamicRowValue(row, 'Date'),
                unread: labels.indexOf('UNREAD') >= 0,
                important: labels.indexOf('IMPORTANT') >= 0,
                sourceUrl: '',
                rawProviderRef: threadId
              });
            } else if (row.title !== 'Gmail 搜索条件') {
              statuses.push({
                provider: 'gmail',
                status: row.status,
                title: row.title,
                message: row.summary
              });
            }
          });
        }
      } catch (error) {
        statuses.push(mailProviderError('gmail', describeThrown(error)));
      }
    }

    if (parsed.providers.indexOf('qq') >= 0) {
      try {
        const qq = new QqMailImapClient(qqMailConfig());
        const qqRows = await qq.search(parsed);
        qqRows.forEach((row: MailThreadResult) => threads.push(row));
      } catch (error) {
        statuses.push(mailProviderError('qq', describeThrown(error)));
      }
    }

    return mailResultsA2ui(surfaceId, toolId, threads, statuses);
  }

  if (toolId === 'mail.draft.create') {
    const parsed = mailDraftArgs(args);
    if (parsed.provider === 'gmail') {
      return callLocalGmailTool('gmail.draft.create', prompt, surfaceId, args);
    }
    if (parsed.provider === 'qq') {
      try {
        const qq = new QqMailImapClient(qqMailConfig());
        return mailDraftPreviewA2ui(surfaceId, await qq.createDraft(parsed));
      } catch (error) {
        const rows: A2uiLabelValueData[] = [
          { label: 'Source', value: 'QQ Mail' },
          { label: 'Status', value: 'Draft not saved' }
        ];
        const result: DynamicGenericToolResult = {
          sourceTag: 'QQ Mail',
          toolName: 'mail.draft.create',
          title: 'QQ 邮箱草稿保存失败',
          status: 'error',
          summary: describeThrown(error),
          rows: rows,
          rawPreview: 'qq draft failed'
        };
        return mailResultsFromDynamicA2ui(surfaceId, toolId, [result], 'Mail Draft Preview');
      }
    }
    const rows: A2uiLabelValueData[] = [{ label: 'Missing', value: 'provider' }];
    const result: DynamicGenericToolResult = {
      sourceTag: 'Mail',
      toolName: 'mail.draft.create',
      title: '邮箱草稿缺少 provider',
      status: 'error',
      summary: 'mail.draft.create requires args.provider to be gmail or qq.',
      rows: rows,
      rawPreview: 'missing provider'
    };
    return mailResultsFromDynamicA2ui(surfaceId, toolId, [result]);
  }

  const rows: A2uiLabelValueData[] = [{ label: 'Tool', value: toolId }];
  const result: DynamicGenericToolResult = {
    sourceTag: 'Mail',
    toolName: toolId,
    title: '未知邮箱工具',
    status: 'error',
    summary: 'Unsupported mail tool: ' + toolId,
    rows: rows,
    rawPreview: 'unsupported mail tool'
  };
  return mailResultsFromDynamicA2ui(surfaceId, toolId, [result]);
}

function hasCalendarScope(scope: string): boolean {
  return scope.indexOf('https://www.googleapis.com/auth/calendar') >= 0 ||
    scope.indexOf('https://www.googleapis.com/auth/calendar.events') >= 0 ||
    scope.indexOf('https://www.googleapis.com/auth/calendar.readonly') >= 0;
}

async function googleAccessTokenForCalendar(): Promise<string> {
  const token = await loadGmailOAuthTokenSet(gmailCredentialStore);
  if (token !== null && hasCalendarScope(token.scope)) {
    if (isGmailAccessTokenFresh(token)) {
      return token.accessToken;
    }
    if (token.refreshToken.length > 0) {
      const config = gmailOAuthConfigFromProvider();
      if (config.clientId.length > 0) {
        const refreshed = await refreshGmailOAuthAccessToken(config, token.refreshToken);
        const saved = await saveGmailOAuthTokenSet(gmailCredentialStore, refreshed);
        return hasCalendarScope(saved.scope) ? saved.accessToken : '';
      }
    }
  }
  return '';
}

function calendarAuthUnavailableMessage(toolId: string, prompt: string): string {
  return 'Google Calendar OAuth 未授权：工具 ' + toolId + ' 已注册，但当前设备没有可用的 Calendar scope；请先授权 Calendar。AIPhone 不会模拟日程或 eventId。请求：' + prompt.substring(0, 160);
}

async function callLocalCalendarTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  let token = '';
  try {
    token = await googleAccessTokenForCalendar();
  } catch (error) {
    return calendarAuthRequiredA2ui(surfaceId, toolId, calendarAuthUnavailableMessage(toolId, prompt) + ' 错误：' + describeThrown(error), await prepareGoogleOAuthAuthorizationUrl(GOOGLE_OAUTH_SETUP_URL));
  }
  if (token.length === 0) {
    return calendarAuthRequiredA2ui(surfaceId, toolId, calendarAuthUnavailableMessage(toolId, prompt), await prepareGoogleOAuthAuthorizationUrl(GOOGLE_OAUTH_SETUP_URL));
  }
  return genericToolResultsA2ui(surfaceId, toolId, await callCalendarTool(toolId, prompt, token, args));
}

function mapsArgs(args: Object | null): MapsToolArgs {
  if (args === null) {
    return JSON.parse('{}') as MapsToolArgs;
  }
  return args as MapsToolArgs;
}

function mapsSearchQuery(args: MapsToolArgs): string {
  const query = textOf(args.query).trim();
  if (query.length > 0) {
    return query;
  }
  const textQuery = textOf(args.textQuery).trim();
  if (textQuery.length > 0) {
    return textQuery;
  }
  return textOf(args.keyword).trim();
}

function mapsPlaceId(args: MapsToolArgs): string {
  const placeId = textOf(args.placeId).trim();
  return placeId.length > 0 ? placeId : textOf(args.id).trim();
}

async function callLocalMapsTool(toolId: string, prompt: string, surfaceId: string, args: Object | null = null): Promise<string> {
  const parsed = mapsArgs(args);
  if (toolId === 'maps.place.details') {
    return genericToolResultsA2ui(surfaceId, toolId, await callMapsPlaceDetails(mapsPlaceId(parsed), localProviderConfig.googleMapsApiKey));
  }
  const query = mapsSearchQuery(parsed);
  return genericToolResultsA2ui(surfaceId, toolId, await callMapsPlaceSearch(query.length > 0 ? query : prompt, localProviderConfig.googleMapsApiKey));
}

async function buildLocalToolJsonl(toolId: string, prompt: string, surfaceId: string, emitJsonl: LocalA2uiEmitter | null = null, args: Object | null = null): Promise<string> {
  if (isCalendarToolId(toolId)) {
    return callLocalCalendarTool(toolId, prompt, surfaceId, args);
  }
  if (isMapsToolId(toolId)) {
    return callLocalMapsTool(toolId, prompt, surfaceId, args);
  }
  if (isMailToolId(toolId)) {
    return callLocalMailTool(toolId, prompt, surfaceId, args);
  }
  if (isGmailToolId(toolId)) {
    return callLocalGmailTool(toolId, prompt, surfaceId, args);
  }
  if (isMediaToolId(toolId)) {
    return callLocalMediaTool(toolId, prompt, surfaceId, args);
  }
  if (isYouTubeToolId(toolId)) {
    return callLocalYouTubeTool(toolId, prompt, surfaceId, args);
  }
  if (toolId === 'social.reply.send') {
    return errorA2ui(
      surfaceId,
      toolId,
      '微信回复未发送',
      'social.reply.send 已注册为真实本地动作，但当前 HAP 未接入可执行的微信辅助发送器；不会假装发送成功。',
      ['缺少真实微信辅助发送执行器', '请先授权并接入通知/辅助桥接后重试'],
      ['打开社交权限诊断']
    );
  }
  if (toolId === 'travel.search') {
    return callLocalTravelSearch(prompt, surfaceId);
  }
  if (toolId === 'flight.search') {
    return callLocalFlightSearch(prompt, surfaceId);
  }
  if (toolId === 'train.search') {
    return callLocalTrainSearch(prompt, surfaceId);
  }
  if (toolId === 'food.search') {
    return callLocalFoodSearch(prompt, surfaceId, emitJsonl);
  }
  return buildDynamicToolJsonl(toolId, prompt, surfaceId);
}

async function callLocalTool(toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null, args: Object | null = null): Promise<A2uiCallResult> {
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }
  let rawResponse = '';
  const throttleMs = toolId === 'food.search' ? localToolDebugConfig.foodPartialThrottleMs : 0;
  const surfaceThrottle = new A2uiSurfaceThrottle(throttleMs, (surface: A2uiSurfaceState, raw: string) => {
    aiLogInfo('[AIPhone][LocalToolSurfaceThrottleEmit] intervalMs=' + throttleMs.toString() +
      ' sequence=' + surface.sequence.toString() + ' status=' + surface.status);
    onSurface(surface, raw);
  });
  const emitJsonl = (jsonl: string, immediate: boolean = false): void => {
    if (jsonl.length === 0 || streamError.length > 0) {
      return;
    }
    rawResponse += jsonl;
    const emitted = parseA2uiJsonl(jsonl);
    if (emitted.error.length > 0) {
      streamError = emitted.error;
      aiLogError('[AIPhone][LocalToolEmitParseError] ' + emitted.error);
      return;
    }
    const applyError = applyEnvelopes(store, emitted.envelopes);
    if (applyError.length > 0) {
      streamError = applyError;
      aiLogError('[AIPhone][LocalToolEmitApplyError] ' + applyError);
      return;
    }
    const surface = store.getSurface();
    if (immediate) {
      onSurface(surface, rawResponse);
    } else {
      surfaceThrottle.enqueue(surface, rawResponse);
    }
  };
  const localDebugBody: ToolGatewayRequestBody = {
    toolId: toolId,
    prompt: prompt,
    surfaceId: surfaceId,
    actionId: actionId,
    stream: false,
    a2uiClientCapabilities: defaultA2uiCapabilities()
  };
  if (args !== null) {
    localDebugBody.args = args;
  }
  const localDebugPayload: ToolRequestDebug = {
    endpoint: LOCAL_TOOL_GATEWAY_URL,
    body: localDebugBody
  };
  const requestDebug = JSON.stringify(localDebugPayload);
  aiLogInfo('[AIPhone][LocalToolRequest] endpoint=' + LOCAL_TOOL_GATEWAY_URL + ' toolId=' + toolId + ' surfaceId=' + surfaceId + ' promptChars=' + prompt.length.toString());
  const pending = pendingA2ui(toolId, prompt, surfaceId);
  let parsed = parseA2uiJsonl(pending);
  let streamError = parsed.error;
  if (streamError.length === 0) {
    emitJsonl(pending, true);
  }

  try {
    const resultJsonl = await buildLocalToolJsonl(toolId, prompt, surfaceId, emitJsonl, args);
    emitJsonl(resultJsonl);
    surfaceThrottle.flush();
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
    surfaceThrottle.cancel();
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

export async function callToolGateway(baseUrl: string, toolId: string, prompt: string, surfaceId: string, actionId: string, onSurface: A2uiSurfaceCallback, initialSurface: A2uiSurfaceState | null = null, args: Object | null = null): Promise<A2uiCallResult> {
  const endpoint = buildToolGatewayUrl(baseUrl);
  if (isLocalToolGatewayUrl(endpoint)) {
    return callLocalTool(toolId, prompt, surfaceId, actionId, onSurface, initialSurface, args);
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
  if (args !== null) {
    body.args = args;
  }
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
