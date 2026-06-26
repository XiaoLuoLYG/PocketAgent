import { A2uiAction, A2uiFlightData, A2uiFoodData, A2uiTrainData, A2uiTravelOptionData } from './A2uiTypes';
import { buildSystemFoodNavigationUri } from './FoodNavigation';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION: string = 'navigation.destination';
export const NAVIGATION_CARD_ACTION_OPEN_MAP: string = 'open_map';
export const NAVIGATION_CARD_ACTION_OPEN_AGENT: string = 'open_agent';
export const NAVIGATION_CARD_ACTION_REFRESH: string = 'refresh';
export const NAVIGATION_CARD_PIN_ACTION_ID: string = 'navigation_card_pin_destination';

export type NavigationCardSnapshotStatus = 'ready' | 'empty' | 'expired' | 'error';
export type NavigationCardFormEvent = 'open_map' | 'open_agent' | 'refresh' | '';
export type NavigationCardStyle = 'destination' | 'travel';

export interface NavigationCardSnapshot {
  kind: string;
  status: NavigationCardSnapshotStatus;
  cardStyle: string;
  transport: string;
  title: string;
  subtitle: string;
  address: string;
  location: string;
  targetName: string;
  departureTime: string;
  arrivalTime: string;
  routeText: string;
  serviceText: string;
  sourceTags: string[];
  mapUri: string;
  surfaceId: string;
  toolId: string;
  updatedAt: number;
  expiresAt: number;
  error: string;
}

export interface NavigationCardSnapshotContext {
  surfaceId: string;
  toolId: string;
  updatedAt: number;
  expiresAt: number;
}

export interface NavigationCardSnapshotBuildResult {
  ok: boolean;
  error: string;
  snapshot?: NavigationCardSnapshot;
}

export interface NavigationCardBindingData {
  kind: string;
  status: string;
  cardStatus: string;
  cardStyle: string;
  transport: string;
  title: string;
  subtitle: string;
  address: string;
  location: string;
  targetName: string;
  departureTime: string;
  arrivalTime: string;
  routeText: string;
  serviceText: string;
  sourceText: string;
  mapUri: string;
  destinationUri: string;
  message: string;
  updatedText: string;
  primaryAction: string;
  secondaryAction: string;
}

export interface NavigationCardSnapshotStore {
  saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void>;
  getSnapshot(): Promise<NavigationCardSnapshot | null>;
  clearSnapshot(): Promise<void>;
  addFormId(formId: string): Promise<void>;
  removeFormId(formId: string): Promise<void>;
  getFormIds(): Promise<string[]>;
}

interface LooseNavigationCardEvent {
  action?: string;
  type?: string;
  event?: string;
}

interface TravelHubLocation {
  name: string;
  location: string;
  aliases: string[];
}

const NAVIGATION_CARD_SOURCE_TAG_LIMIT: number = 4;
const NAVIGATION_CARD_MISSING_COORDINATE: string = '缺少真实坐标，不能生成导航卡片';
const NAVIGATION_CARD_MISSING_TRAVEL_TARGET_COORDINATE: string = '缺少真实出发站或机场坐标，不能生成出行卡片';
const NAVIGATION_CARD_STORE: string = 'navigation_card_snapshot_store';
const NAVIGATION_CARD_SNAPSHOT_KEY: string = 'current_snapshot';
const NAVIGATION_CARD_FORM_IDS_KEY: string = 'form_ids';
const TRAIN_HUB_LOCATIONS: TravelHubLocation[] = [
  { name: '北京南站', location: '116.37639,39.86583', aliases: ['北京南'] },
  { name: '上海虹桥站', location: '121.32760,31.20033', aliases: ['上海虹桥'] },
  { name: '深圳北站', location: '114.029506,22.609878', aliases: ['深圳北'] }
];
const FLIGHT_HUB_LOCATIONS: TravelHubLocation[] = [
  { name: '北京首都机场', location: '116.58444,40.08000', aliases: ['北京首都国际机场'] },
  { name: '上海虹桥机场', location: '121.33632,31.19788', aliases: ['上海虹桥国际机场'] },
  { name: '深圳宝安机场', location: '113.810664,22.639258', aliases: ['深圳宝安国际机场'] }
];

function cleanText(value: string | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.trim();
}

function cleanNumber(value: number): number {
  if (Number.isFinite(value)) {
    return value;
  }
  return 0;
}

function flushPreferences(store: preferences.Preferences): void {
  store.flush().catch((_error: Error) => {});
}

function navigationCardStoreError(): Error {
  return new Error('导航卡片存储暂时不可用');
}

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function snapshotSubtitle(item: A2uiFoodData): string {
  const distance = cleanText(item.distance);
  if (distance.length > 0) {
    return distance;
  }
  const address = cleanText(item.address);
  if (address.length > 0) {
    return address;
  }
  return '真实地点结果';
}

function joinRoute(from: string, to: string): string {
  const cleanFrom = cleanText(from);
  const cleanTo = cleanText(to);
  if (cleanFrom.length > 0 && cleanTo.length > 0) {
    return cleanFrom + ' → ' + cleanTo;
  }
  if (cleanFrom.length > 0) {
    return cleanFrom + ' 出发';
  }
  if (cleanTo.length > 0) {
    return '到 ' + cleanTo;
  }
  return '';
}

function normalizeTrainHub(value: string): string {
  const hub = cleanText(value);
  if (hub.length === 0) {
    return '';
  }
  if (hub.indexOf('站') >= 0) {
    return hub;
  }
  return hub + '站';
}

function looksLikeAirportCode(value: string): boolean {
  return /^[A-Z]{2,4}$/.test(cleanText(value));
}

function normalizeFlightHub(value: string): string {
  const hub = cleanText(value);
  if (hub.length === 0 || looksLikeAirportCode(hub)) {
    return '';
  }
  if (hub.indexOf('机场') >= 0 || hub.indexOf('航站楼') >= 0 || hub.indexOf('Airport') >= 0) {
    return hub;
  }
  if (/[\u4e00-\u9fa5]/.test(hub) && hub.length >= 4) {
    return hub + '机场';
  }
  return '';
}

function cleanDirectLocation(value: string | undefined): string {
  const location = cleanText(value);
  if (location.length > 0 && buildSystemFoodNavigationUri(location, '', '目的地').length > 0) {
    return location;
  }
  return '';
}

function normalizeTravelHubLookupText(value: string): string {
  return cleanText(value)
    .replace(/[\s　]/g, '')
    .replace(/国际机场/g, '机场');
}

function travelHubMatches(hub: TravelHubLocation, target: string): boolean {
  const normalizedTarget = normalizeTravelHubLookupText(target);
  if (normalizedTarget.length === 0) {
    return false;
  }
  if (normalizeTravelHubLookupText(hub.name) === normalizedTarget) {
    return true;
  }
  let matched = false;
  hub.aliases.forEach((alias: string) => {
    if (normalizeTravelHubLookupText(alias) === normalizedTarget) {
      matched = true;
    }
  });
  return matched;
}

function resolveTravelHubLocation(transport: string, targetName: string): TravelHubLocation | null {
  const hubs = transport === 'flight' ? FLIGHT_HUB_LOCATIONS : TRAIN_HUB_LOCATIONS;
  let matched: TravelHubLocation | null = null;
  hubs.forEach((hub: TravelHubLocation) => {
    if (matched === null && travelHubMatches(hub, targetName)) {
      matched = hub;
    }
  });
  return matched;
}

export function resolveNavigationCardMapUri(cardStyle: string, transport: string, location: string,
  targetName: string, mapUri: string): string {
  if (cardStyle !== 'travel') {
    return cleanText(mapUri).length > 0 ? cleanText(mapUri) : buildSystemFoodNavigationUri(location, '', targetName);
  }
  const target = cleanText(targetName).length > 0 ? cleanText(targetName) : cleanText(location);
  const directLocation = cleanDirectLocation(location);
  if (directLocation.length > 0) {
    const directUri = buildSystemFoodNavigationUri(directLocation, '', target);
    if (directUri.length > 0) {
      return directUri;
    }
  }
  const resolvedHub = resolveTravelHubLocation(transport, target);
  if (resolvedHub !== null) {
    return buildSystemFoodNavigationUri(resolvedHub.location, '', resolvedHub.name);
  }
  return cleanText(mapUri);
}

function buildTravelSourceTags(sourceTag: string): string[] {
  const tag = cleanText(sourceTag);
  if (tag.length > 0) {
    return sanitizeNavigationCardSourceTags([tag]);
  }
  return [];
}

function bindingSourceText(snapshot: NavigationCardSnapshot): string {
  if (snapshot.cardStyle === 'travel') {
    return '';
  }
  return snapshot.sourceTags.join(' / ');
}

function travelSnapshot(
  transport: string,
  title: string,
  routeText: string,
  targetName: string,
  targetLocation: string | undefined,
  departureTime: string,
  arrivalTime: string,
  serviceText: string,
  sourceTags: string[],
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  let target = cleanText(targetName);
  let location = cleanDirectLocation(targetLocation);
  const resolvedHub = resolveTravelHubLocation(transport, target);
  if (location.length === 0 && resolvedHub !== null) {
    location = resolvedHub.location;
    target = resolvedHub.name;
  }
  const mapUri = buildSystemFoodNavigationUri(location, '', target);
  if (target.length === 0 || location.length === 0 || mapUri.length === 0) {
    return {
      ok: false,
      error: NAVIGATION_CARD_MISSING_TRAVEL_TARGET_COORDINATE
    };
  }
  const snapshot: NavigationCardSnapshot = {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'ready',
    cardStyle: 'travel',
    transport: transport,
    title: cleanText(title).length > 0 ? cleanText(title) : (transport === 'flight' ? '航班出发' : '高铁出发'),
    subtitle: cleanText(routeText),
    address: target,
    location: location,
    targetName: target,
    departureTime: cleanText(departureTime),
    arrivalTime: cleanText(arrivalTime),
    routeText: cleanText(routeText),
    serviceText: cleanText(serviceText),
    sourceTags: sanitizeNavigationCardSourceTags(sourceTags),
    mapUri: mapUri,
    surfaceId: cleanText(context.surfaceId),
    toolId: cleanText(context.toolId),
    updatedAt: cleanNumber(context.updatedAt),
    expiresAt: cleanNumber(context.expiresAt),
    error: ''
  };
  return {
    ok: true,
    error: '',
    snapshot: snapshot
  };
}

export function sanitizeNavigationCardSourceTags(values: string[] | undefined): string[] {
  if (values === undefined || values === null || !Array.isArray(values)) {
    return [];
  }
  const tags: string[] = [];
  values.forEach((value: string) => {
    const tag = cleanText(value);
    if (tag.length > 0 && tags.indexOf(tag) < 0 && tags.length < NAVIGATION_CARD_SOURCE_TAG_LIMIT) {
      tags.push(tag);
    }
  });
  return tags;
}

export function navigationCardSnapshotExpired(snapshot: NavigationCardSnapshot, nowMs: number): boolean {
  return snapshot.expiresAt > 0 && nowMs >= snapshot.expiresAt;
}

export function navigationCardSnapshotFromFoodOption(
  item: A2uiFoodData,
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  const location = cleanText(item.location);
  const title = cleanText(item.name).length > 0 ? cleanText(item.name) : '目的地';
  const mapUri = buildSystemFoodNavigationUri(location, '', title);
  if (mapUri.length === 0) {
    return {
      ok: false,
      error: NAVIGATION_CARD_MISSING_COORDINATE
    };
  }
  const snapshot: NavigationCardSnapshot = {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'ready',
    cardStyle: 'destination',
    transport: '',
    title: title,
    subtitle: snapshotSubtitle(item),
    address: cleanText(item.address),
    location: location,
    targetName: title,
    departureTime: '',
    arrivalTime: '',
    routeText: '',
    serviceText: '',
    sourceTags: sanitizeNavigationCardSourceTags(item.sourceTags),
    mapUri: mapUri,
    surfaceId: cleanText(context.surfaceId),
    toolId: cleanText(context.toolId),
    updatedAt: cleanNumber(context.updatedAt),
    expiresAt: cleanNumber(context.expiresAt),
    error: ''
  };
  return {
    ok: true,
    error: '',
    snapshot: snapshot
  };
}

export function canCreateNavigationCardFromFoodOption(item: A2uiFoodData): boolean {
  const location = cleanText(item.location);
  const title = cleanText(item.name).length > 0 ? cleanText(item.name) : '目的地';
  return buildSystemFoodNavigationUri(location, '', title).length > 0;
}

export function navigationCardPinActionFromFoodOption(item: A2uiFoodData): A2uiAction {
  if (!canCreateNavigationCardFromFoodOption(item)) {
    return {
      id: '',
      label: '',
      prompt: '',
      variant: '',
      kind: ''
    };
  }
  return {
    id: NAVIGATION_CARD_PIN_ACTION_ID,
    label: '固定为导航卡片',
    prompt: '',
    variant: 'secondary',
    kind: 'client'
  };
}

export function navigationCardSnapshotFromTravelOption(
  item: A2uiTravelOptionData,
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  const transport = cleanText(item.source) === 'flight' ? 'flight' : 'train';
  const target = transport === 'flight' ? normalizeFlightHub(item.from) : normalizeTrainHub(item.from);
  const service = cleanText(item.sourceTag).length > 0 ? cleanText(item.sourceTag) :
    (transport === 'flight' ? '飞机 · 飞常准' : '高铁 · 12306');
  return travelSnapshot(
    transport,
    cleanText(item.title),
    joinRoute(item.from, item.to),
    target,
    item.fromLocation,
    item.depart,
    item.arrive,
    service,
    buildTravelSourceTags(service),
    context
  );
}

export function canCreateNavigationCardFromTravelOption(item: A2uiTravelOptionData): boolean {
  return navigationCardSnapshotFromTravelOption(item, {
    surfaceId: '',
    toolId: '',
    updatedAt: 0,
    expiresAt: 0
  }).ok;
}

export function navigationCardSnapshotFromTrainOption(
  item: A2uiTrainData,
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  return travelSnapshot(
    'train',
    cleanText(item.trainCode),
    joinRoute(item.from, item.to),
    normalizeTrainHub(item.from),
    item.fromLocation,
    item.depart,
    item.arrive,
    '高铁 · 12306',
    ['高铁 · 12306'],
    context
  );
}

export function canCreateNavigationCardFromTrainOption(item: A2uiTrainData): boolean {
  return navigationCardSnapshotFromTrainOption(item, {
    surfaceId: '',
    toolId: '',
    updatedAt: 0,
    expiresAt: 0
  }).ok;
}

export function navigationCardSnapshotFromFlightOption(
  item: A2uiFlightData,
  context: NavigationCardSnapshotContext
): NavigationCardSnapshotBuildResult {
  const title = cleanText(item.flightNo).length > 0 ? cleanText(item.flightNo) : cleanText(item.airline);
  return travelSnapshot(
    'flight',
    title,
    joinRoute(item.dep, item.arr),
    normalizeFlightHub(item.dep),
    item.depLocation,
    item.depTime,
    item.arrTime,
    '飞机 · 飞常准',
    ['飞机 · 飞常准'],
    context
  );
}

export function canCreateNavigationCardFromFlightOption(item: A2uiFlightData): boolean {
  return navigationCardSnapshotFromFlightOption(item, {
    surfaceId: '',
    toolId: '',
    updatedAt: 0,
    expiresAt: 0
  }).ok;
}

function formatUpdatedText(updatedAt: number): string {
  if (updatedAt <= 0) {
    return '';
  }
  const date = new Date(updatedAt);
  const hours = twoDigits(date.getHours());
  const minutes = twoDigits(date.getMinutes());
  return hours + ':' + minutes + ' 更新';
}

function twoDigits(value: number): string {
  if (value < 10) {
    return '0' + value.toString();
  }
  return value.toString();
}

export function buildEmptyNavigationCardBindingData(): NavigationCardBindingData {
  return {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'empty',
    cardStatus: 'empty',
    cardStyle: 'destination',
    transport: '',
    title: 'Appless Phone 导航',
    subtitle: '',
    address: '',
    location: '',
    targetName: '',
    departureTime: '',
    arrivalTime: '',
    routeText: '',
    serviceText: '',
    sourceText: '',
    mapUri: '',
    destinationUri: '',
    message: '从 Appless Phone 对话生成导航卡片',
    updatedText: '',
    primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
    secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
  };
}

export function buildNavigationCardBindingData(snapshot: NavigationCardSnapshot | null,
  nowMs: number = Date.now()): NavigationCardBindingData {
  if (snapshot === null || snapshot === undefined || snapshot.status === 'empty') {
    return buildEmptyNavigationCardBindingData();
  }
  if (snapshot.status === 'error') {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'error',
      cardStatus: 'error',
      cardStyle: snapshot.cardStyle.length > 0 ? snapshot.cardStyle : 'destination',
      transport: snapshot.transport,
      title: snapshot.title.length > 0 ? snapshot.title : '导航卡片不可用',
      subtitle: snapshot.subtitle,
      address: snapshot.address,
      location: snapshot.location,
      targetName: snapshot.targetName,
      departureTime: snapshot.departureTime,
      arrivalTime: snapshot.arrivalTime,
      routeText: snapshot.routeText,
      serviceText: snapshot.serviceText,
      sourceText: bindingSourceText(snapshot),
      mapUri: '',
      destinationUri: '',
      message: snapshot.error.length > 0 ? snapshot.error : '导航卡片生成失败',
      updatedText: formatUpdatedText(snapshot.updatedAt),
      primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
      secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
    };
  }
  if (navigationCardSnapshotExpired(snapshot, nowMs)) {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'expired',
      cardStatus: 'expired',
      cardStyle: snapshot.cardStyle.length > 0 ? snapshot.cardStyle : 'destination',
      transport: snapshot.transport,
      title: snapshot.title,
      subtitle: snapshot.subtitle,
      address: snapshot.address,
      location: snapshot.location,
      targetName: snapshot.targetName,
      departureTime: snapshot.departureTime,
      arrivalTime: snapshot.arrivalTime,
      routeText: snapshot.routeText,
      serviceText: snapshot.serviceText,
      sourceText: bindingSourceText(snapshot),
      mapUri: '',
      destinationUri: '',
      message: '导航卡片已过期，请回到 Appless Phone 刷新真实结果',
      updatedText: formatUpdatedText(snapshot.updatedAt),
      primaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT,
      secondaryAction: NAVIGATION_CARD_ACTION_REFRESH
    };
  }
  const readyMapUri = resolveNavigationCardMapUri(snapshot.cardStyle, snapshot.transport, snapshot.location,
    snapshot.targetName, snapshot.mapUri);
  return {
    kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
    status: 'ready',
    cardStatus: 'ready',
    cardStyle: snapshot.cardStyle.length > 0 ? snapshot.cardStyle : 'destination',
    transport: snapshot.transport,
    title: snapshot.title,
    subtitle: snapshot.subtitle,
    address: snapshot.address,
    location: snapshot.location,
    targetName: snapshot.targetName,
    departureTime: snapshot.departureTime,
    arrivalTime: snapshot.arrivalTime,
    routeText: snapshot.routeText,
    serviceText: snapshot.serviceText,
    sourceText: bindingSourceText(snapshot),
    mapUri: readyMapUri,
    destinationUri: readyMapUri,
    message: snapshot.address.length > 0 ? snapshot.address : '真实 provider 坐标',
    updatedText: formatUpdatedText(snapshot.updatedAt),
    primaryAction: NAVIGATION_CARD_ACTION_OPEN_MAP,
    secondaryAction: NAVIGATION_CARD_ACTION_OPEN_AGENT
  };
}

export function navigationCardFormEventFromMessage(message: string): NavigationCardFormEvent {
  const trimmed = cleanText(message);
  if (trimmed === NAVIGATION_CARD_ACTION_OPEN_MAP ||
    trimmed === NAVIGATION_CARD_ACTION_OPEN_AGENT ||
    trimmed === NAVIGATION_CARD_ACTION_REFRESH) {
    return trimmed as NavigationCardFormEvent;
  }
  try {
    const parsed = JSON.parse(trimmed) as LooseNavigationCardEvent;
    const candidate = cleanText(parsed.action).length > 0 ? cleanText(parsed.action) :
      (cleanText(parsed.type).length > 0 ? cleanText(parsed.type) : cleanText(parsed.event));
    if (candidate === NAVIGATION_CARD_ACTION_OPEN_MAP ||
      candidate === NAVIGATION_CARD_ACTION_OPEN_AGENT ||
      candidate === NAVIGATION_CARD_ACTION_REFRESH) {
      return candidate as NavigationCardFormEvent;
    }
  } catch (_error) {
  }
  return '';
}

export class MemoryNavigationCardSnapshotStore implements NavigationCardSnapshotStore {
  private snapshot: NavigationCardSnapshot | null = null;
  private formIds: string[] = [];

  async saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void> {
    this.snapshot = snapshot;
  }

  async getSnapshot(): Promise<NavigationCardSnapshot | null> {
    return this.snapshot;
  }

  async clearSnapshot(): Promise<void> {
    this.snapshot = null;
  }

  async addFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    if (id.length > 0 && this.formIds.indexOf(id) < 0) {
      this.formIds.push(id);
    }
  }

  async removeFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    this.formIds = this.formIds.filter((value: string) => value !== id);
  }

  async getFormIds(): Promise<string[]> {
    return this.formIds.slice();
  }
}

function stringArrayFromRaw(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw) as string[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    const values: string[] = [];
    parsed.forEach((item: string) => {
      const value = cleanText(item);
      if (value.length > 0 && values.indexOf(value) < 0) {
        values.push(value);
      }
    });
    return values;
  } catch (_error) {
    return [];
  }
}

function snapshotFromRaw(raw: string): NavigationCardSnapshot | null {
  if (raw.length === 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as NavigationCardSnapshot;
    if (parsed === undefined || parsed === null || parsed.kind !== CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION) {
      return null;
    }
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: parsed.status === 'ready' || parsed.status === 'error' || parsed.status === 'expired' || parsed.status === 'empty' ? parsed.status : 'error',
      cardStyle: cleanText(parsed.cardStyle).length > 0 ? cleanText(parsed.cardStyle) : 'destination',
      transport: cleanText(parsed.transport),
      title: cleanText(parsed.title),
      subtitle: cleanText(parsed.subtitle),
      address: cleanText(parsed.address),
      location: cleanText(parsed.location),
      targetName: cleanText(parsed.targetName),
      departureTime: cleanText(parsed.departureTime),
      arrivalTime: cleanText(parsed.arrivalTime),
      routeText: cleanText(parsed.routeText),
      serviceText: cleanText(parsed.serviceText),
      sourceTags: sanitizeNavigationCardSourceTags(parsed.sourceTags),
      mapUri: cleanText(parsed.mapUri),
      surfaceId: cleanText(parsed.surfaceId),
      toolId: cleanText(parsed.toolId),
      updatedAt: cleanNumber(parsed.updatedAt),
      expiresAt: cleanNumber(parsed.expiresAt),
      error: cleanText(parsed.error)
    };
  } catch (_error) {
    return null;
  }
}

export class PreferencesNavigationCardSnapshotStore implements NavigationCardSnapshotStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  private preferences(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.context, { name: NAVIGATION_CARD_STORE });
    } catch (_error) {
      return null;
    }
  }

  saveSnapshotSync(snapshot: NavigationCardSnapshot): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(NAVIGATION_CARD_SNAPSHOT_KEY, JSON.stringify(snapshot));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async saveSnapshot(snapshot: NavigationCardSnapshot): Promise<void> {
    const store = this.preferences();
    if (store === null) {
      throw navigationCardStoreError();
    }
    try {
      store.putSync(NAVIGATION_CARD_SNAPSHOT_KEY, JSON.stringify(snapshot));
      await store.flush();
    } catch (_error) {
      throw navigationCardStoreError();
    }
  }

  getSnapshotSync(): NavigationCardSnapshot | null {
    const store = this.preferences();
    if (store === null) {
      return null;
    }
    try {
      const raw = textFromValue(store.getSync(NAVIGATION_CARD_SNAPSHOT_KEY, ''));
      return snapshotFromRaw(raw);
    } catch (_error) {
      return null;
    }
  }

  async getSnapshot(): Promise<NavigationCardSnapshot | null> {
    return this.getSnapshotSync();
  }

  clearSnapshotSync(): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.deleteSync(NAVIGATION_CARD_SNAPSHOT_KEY);
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async clearSnapshot(): Promise<void> {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.deleteSync(NAVIGATION_CARD_SNAPSHOT_KEY);
      await store.flush();
    } catch (_error) {
    }
  }

  addFormIdSync(formId: string): void {
    const id = cleanText(formId);
    if (id.length === 0) {
      return;
    }
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
      if (ids.indexOf(id) < 0) {
        ids.push(id);
      }
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async addFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    if (id.length === 0) {
      return;
    }
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
      if (ids.indexOf(id) < 0) {
        ids.push(id);
      }
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      await store.flush();
    } catch (_error) {
    }
  }

  removeFormIdSync(formId: string): void {
    const id = cleanText(formId);
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')))
        .filter((value: string) => value !== id);
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      flushPreferences(store);
    } catch (_error) {
    }
  }

  async removeFormId(formId: string): Promise<void> {
    const id = cleanText(formId);
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      const ids = stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')))
        .filter((value: string) => value !== id);
      store.putSync(NAVIGATION_CARD_FORM_IDS_KEY, JSON.stringify(ids));
      await store.flush();
    } catch (_error) {
    }
  }

  getFormIdsSync(): string[] {
    const store = this.preferences();
    if (store === null) {
      return [];
    }
    try {
      return stringArrayFromRaw(textFromValue(store.getSync(NAVIGATION_CARD_FORM_IDS_KEY, '')));
    } catch (_error) {
      return [];
    }
  }

  async getFormIds(): Promise<string[]> {
    return this.getFormIdsSync();
  }
}
