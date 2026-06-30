import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SOCIAL_INBOX,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_COMPONENT_TRAVEL_OPTIONS,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiFoodData,
  A2uiFlightData,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiMessage,
  A2uiSocialMessageData,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData
} from '../../../model/A2uiTypes';
import {
  actionsOf,
  dynamicToolConnect,
  flightOptions,
  foodOptions,
  genericToolResults,
  labelValues,
  resolveData,
  socialDiagnostics,
  socialMessages,
  trainOptions,
  travelOptions
} from '../../../model/A2uiData';
import {
  componentBodyOf,
  componentStatusOf,
  componentTextOf,
  componentTitleOf,
  findA2uiComponent
} from '../render/A2uiRenderData';
import { gmailOpenDraftAction, gmailReplyDraftAction } from '../../../model/GmailToolA2ui';
import { mailReplyDraftAction } from '../../../model/MailToolA2ui';
import { mediaVideoPlaybackAction } from '../../../model/MediaVideoToolA2ui';
import {
  HtmlHomeAction,
  HtmlHomeBlock,
  HtmlHomeDocument,
  HtmlHomeHistoryItem,
  HtmlHomeKind,
  HtmlHomeMediaEmbed,
  HtmlHomeMetric,
  HtmlHomeSource,
  HtmlHomeTimelineItem
} from './HtmlHomeTypes';

const HTML_HOME_VERSION: number = 1;
const HISTORY_LIMIT: number = 6;
type HtmlHomeTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy: boolean;
}

export interface CreateHtmlHomeDocumentParams {
  surface?: A2uiSurfaceState;
  messages: A2uiMessage[];
  isBusy: boolean;
  isAwaitingFirstSurface: boolean;
  inputText?: string;
}

export function createHtmlHomeDocument(params: CreateHtmlHomeDocumentParams): HtmlHomeDocument {
  const prompt = firstText(params.inputText, lastUserMessage(params.messages));
  if (params.surface === undefined || params.surface === null) {
    return params.isBusy || params.isAwaitingFirstSurface ? pendingDocument(params, prompt) : welcomeDocument(params);
  }

  const surface = params.surface;
  const kind = kindOf(surface);
  const root = findA2uiComponent(surface, surface.rootId.length > 0 ? surface.rootId : 'root');
  const document: HtmlHomeDocument = withBusy({
    version: HTML_HOME_VERSION,
    source: sourceOf(kind, surface, params.isBusy),
    kind: kind,
    title: firstText(surface.title, surface.surfaceId, 'A2UI'),
    subtitle: firstText(surface.error, prompt),
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    rawSurfaceRoot: root,
    generatedAt: new Date().toISOString()
  }, params.isBusy);

  surface.components.forEach((component: A2uiComponent) => {
    appendComponentActions(document.actions, component);
    appendBlocksForComponent(document, surface, component);
  });

  dropCompletedThinkingBlocks(document, params.isBusy);
  return document;
}

function welcomeDocument(params: CreateHtmlHomeDocumentParams): HtmlHomeDocument {
  return withBusy({
    version: HTML_HOME_VERSION,
    source: 'welcome',
    kind: 'welcome',
    title: 'Appless Phone',
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  }, params.isBusy);
}

function pendingDocument(params: CreateHtmlHomeDocumentParams, prompt: string): HtmlHomeDocument {
  const timeline: HtmlHomeTimelineItem[] = [];
  if (prompt.length > 0) {
    timeline.push({
      title: 'prompt',
      subtitle: prompt,
      status: 'pending'
    });
  }
  return withBusy({
    version: HTML_HOME_VERSION,
    source: 'pending',
    kind: 'thinking',
    title: 'Generating',
    subtitle: prompt,
    chips: [],
    metrics: [],
    timeline: timeline,
    blocks: [],
    actions: [],
    history: recentHistory(params.messages),
    rawSurfaceRoot: null,
    generatedAt: new Date().toISOString()
  }, params.isBusy);
}

function appendBlocksForComponent(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  if (component.component === A2UI_COMPONENT_TRAVEL_OPTIONS) {
    appendTravelBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_TRAIN_OPTIONS) {
    appendTrainBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_FLIGHT_BOARD) {
    appendFlightBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_FOOD_CHOICES) {
    appendFoodBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_TOOL_CONNECT_CARD) {
    appendDynamicConnectBlock(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_GENERIC_TOOL_RESULTS) {
    appendGenericToolResultBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_SOCIAL_INBOX) {
    appendSocialBlocks(document, surface, component);
    return;
  }
  if (component.component === A2UI_COMPONENT_ACTION_BAR ||
    component.component === A2UI_COMPONENT_SURFACE_ROOT ||
    component.component === A2UI_COMPONENT_COLUMN ||
    component.component === A2UI_COMPONENT_ROW) {
    return;
  }
  appendGenericComponentBlock(document, surface, component);
}

function appendTravelBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const options = travelOptions(surface, component);
  options.forEach((item: A2uiTravelOptionData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'travel-option', firstText(item.title, item.id, component.id));
    block.subtitle = joinText([item.from, item.to], ' -> ');
    block.status = item.status;
    block.source = firstText(item.sourceTag, item.source);
    appendMetric(block.metrics, 'source', item.source);
    appendMetric(block.metrics, 'from', item.from);
    appendMetric(block.metrics, 'to', item.to);
    appendMetric(block.metrics, 'depart', item.depart);
    appendMetric(block.metrics, 'arrive', item.arrive);
    appendMetric(block.metrics, 'duration', item.duration);
    appendMetric(block.metrics, 'price', item.price);
    appendMetric(block.metrics, 'availability', item.availability);
    appendMetric(block.rows, 'detail', item.detail);
    block.actions.push(clientAction('html_pin_travel', '固定到桌面', JSON.stringify({
      index: index,
      id: textOf(item.id),
      source: textOf(item.source),
      depart: textOf(item.depart),
      from: textOf(item.from),
      to: textOf(item.to)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendTrainBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const trains = trainOptions(surface, component);
  if (trains.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  trains.forEach((item: A2uiTrainData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'train-option', firstText(item.trainCode, component.id));
    block.subtitle = joinText([item.from, item.to], ' -> ');
    block.status = item.status;
    appendMetric(block.metrics, 'from', item.from);
    appendMetric(block.metrics, 'to', item.to);
    appendMetric(block.metrics, 'depart', item.depart);
    appendMetric(block.metrics, 'arrive', item.arrive);
    appendMetric(block.metrics, 'duration', item.duration);
    appendMetric(block.rows, 'seats', item.seats);
    appendMetric(block.rows, 'business', item.business);
    appendMetric(block.rows, 'first', item.first);
    appendMetric(block.rows, 'second', item.second);
    appendMetric(block.rows, 'noSeat', item.noSeat);
    appendMetric(block.rows, 'hardSeat', item.hardSeat);
    appendMetric(block.rows, 'sleeperSoft', item.sleeperSoft);
    block.actions.push(clientAction('html_pin_train', '固定到桌面', JSON.stringify({
      index: index,
      trainCode: textOf(item.trainCode),
      depart: textOf(item.depart),
      from: textOf(item.from),
      to: textOf(item.to)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendFlightBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const flights = flightOptions(surface, component);
  if (flights.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  flights.forEach((item: A2uiFlightData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'flight-option', firstText(item.flightNo, item.airline, component.id));
    block.subtitle = joinText([item.dep, item.arr], ' -> ');
    block.status = item.status;
    const retryDate = firstDateText(
      componentTitleOf(component),
      componentBodyOf(component),
      surface.title,
      surface.error,
      summaryText(surface)
    );
    if (retryDate.length > 0) {
      block.prompt = retryDate;
    }
    appendMetric(block.metrics, 'airline', item.airline);
    appendMetric(block.metrics, 'dep', item.dep);
    appendMetric(block.metrics, 'arr', item.arr);
    appendMetric(block.metrics, 'depTime', item.depTime);
    appendMetric(block.metrics, 'arrTime', item.arrTime);
    appendMetric(block.metrics, 'price', item.price);
    block.actions.push(clientAction('html_pin_flight', '固定到桌面', JSON.stringify({
      index: index,
      flightNo: textOf(item.flightNo),
      depTime: textOf(item.depTime),
      dep: textOf(item.dep),
      arr: textOf(item.arr)
    }), component.id));
    document.blocks.push(block);
  });
}

function appendFoodBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const foods = foodOptions(surface, component);
  foods.forEach((item: A2uiFoodData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'food-result', firstText(item.name, component.id));
    block.subtitle = item.category;
    block.source = sourceTagsText(item.sourceTags);
    appendMetric(block.metrics, 'category', item.category);
    appendMetric(block.metrics, 'address', item.address);
    appendMetric(block.metrics, 'distance', item.distance);
    appendMetric(block.metrics, 'location', item.location === undefined ? '' : item.location);
    appendMetric(block.metrics, 'source', block.source === undefined ? '' : block.source);
    const payload = JSON.stringify({
      index: index,
      name: textOf(item.name),
      address: textOf(item.address),
      location: textOf(item.location),
      distance: textOf(item.distance)
    });
    block.actions.push(clientAction('html_pin_food', '固定到桌面', payload, component.id));
    block.actions.push(clientAction('html_open_food_map', '导航去', payload, component.id));
    document.blocks.push(block);
  });
}

function appendDynamicConnectBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const data = dynamicToolConnect(surface);
  if (!hasConnectData(data)) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  const block = newBlock(component.id, 'dynamic-tool-connect', firstText(data.displayName, data.toolId, componentTitleOf(component, component.id)));
  block.subtitle = data.message;
  block.status = data.status;
  block.source = firstText(data.sourceUrl, data.manifestId);
  block.credentialName = data.credentialName;
  block.credentialRef = data.credentialRef;
  block.toolId = data.toolId;
  block.prompt = data.prompt;
  appendMetric(block.metrics, 'provider', data.displayName);
  appendMetric(block.metrics, 'toolId', data.toolId);
  appendMetric(block.metrics, 'manifest', data.manifestId);
  appendMetric(block.metrics, 'source', block.source === undefined ? '' : block.source);
  appendMetric(block.metrics, 'credential', data.credentialName);
  block.actions = htmlActions(actionsOf(component).length > 0 ? actionsOf(component) : data.actions, component.id);
  block.actions.forEach((action: HtmlHomeAction) => {
    appendAction(document.actions, action);
  });
  document.blocks.push(block);
}

function appendGenericToolResultBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const results = genericToolResults(surface);
  if (results.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  results.forEach((item: A2uiGenericToolResultData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'generic-tool-result', firstText(item.title, item.toolName, component.id));
    block.subtitle = item.summary;
    block.status = item.status;
    block.source = item.sourceTag;
    appendMetric(block.metrics, 'source', item.sourceTag);
    appendMetric(block.metrics, 'toolName', item.toolName);
    item.rows.forEach((row: A2uiLabelValueData) => {
      appendMetric(block.rows, row.label, row.value);
    });
    if (item.rawPreview.length > 0) {
      block.rawPreview = item.rawPreview;
    }
    const mediaEmbed = mediaEmbedForResult(item);
    if (mediaEmbed !== null) {
      block.mediaEmbed = mediaEmbed;
    }
    block.actions = htmlActions(actionsOf(component), component.id);
    const mailAction = mailReplyDraftAction(item);
    if (mailAction !== null) {
      block.actions = block.actions.concat(htmlActions([mailAction], component.id));
    }
    const gmailAction = gmailReplyDraftAction(item);
    if (gmailAction !== null) {
      block.actions = block.actions.concat(htmlActions([gmailAction], component.id));
    }
    const gmailOpenDraft = gmailOpenDraftAction(item);
    if (gmailOpenDraft !== null) {
      block.actions = block.actions.concat(htmlActions([gmailOpenDraft], component.id));
    }
    const mapsOpenWeb = mapsOpenWebAction(item);
    if (mapsOpenWeb !== null) {
      block.actions = block.actions.concat(htmlActions([mapsOpenWeb], component.id));
    }
    const mediaPlayback = mediaVideoPlaybackAction(item);
    if (mediaPlayback !== null) {
      block.actions = block.actions.concat(htmlActions([mediaPlayback], component.id));
    }
    document.blocks.push(block);
  });
}

function mediaEmbedForResult(result: A2uiGenericToolResultData): HtmlHomeMediaEmbed | null {
  if (result.status !== 'success') {
    return null;
  }
  const pageUrl = firstText(firstText(
    genericResultRowValue(result, 'Watch URL'),
    genericResultRowValue(result, 'Playback URL'),
    genericResultRowValue(result, 'Share URL')),
    genericResultRowValue(result, 'Video URL')
  );
  const embedUrl = mediaEmbedUrl(pageUrl, result);
  if (embedUrl.length === 0) {
    return null;
  }
  return {
    provider: firstText(result.sourceTag, result.toolName),
    title: result.title,
    embedUrl: embedUrl,
    pageUrl: pageUrl,
    thumbnail: genericResultRowValue(result, 'Thumbnail')
  };
}

function mediaEmbedUrl(pageUrl: string, result: A2uiGenericToolResultData): string {
  const youtubeId = youtubeVideoId(pageUrl, genericResultRowValue(result, 'Video ID'));
  if (youtubeId.length > 0) {
    return 'https://www.youtube.com/embed/' + encodeURIComponent(youtubeId) +
      '?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local';
  }
  const bvid = bilibiliBvid(pageUrl, genericResultRowValue(result, 'BVID'));
  if (bvid.length > 0) {
    const cid = genericResultRowValue(result, 'CID');
    return 'https://player.bilibili.com/player.html?bvid=' + encodeURIComponent(bvid) +
      (cid.length > 0 ? '&cid=' + encodeURIComponent(cid) : '') +
      '&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true';
  }
  return '';
}

function youtubeVideoId(pageUrl: string, rowValue: string): string {
  const direct = rowValue.trim();
  if (direct.length > 0) {
    return direct;
  }
  const watchMarker = 'youtube.com/watch?v=';
  const watchIndex = pageUrl.indexOf(watchMarker);
  if (watchIndex >= 0) {
    return tokenUntil(pageUrl.substring(watchIndex + watchMarker.length), ['&', '#', '?', '/']);
  }
  const shortMarker = 'youtu.be/';
  const shortIndex = pageUrl.indexOf(shortMarker);
  if (shortIndex >= 0) {
    return tokenUntil(pageUrl.substring(shortIndex + shortMarker.length), ['&', '#', '?', '/']);
  }
  return '';
}

function bilibiliBvid(pageUrl: string, rowValue: string): string {
  const direct = rowValue.trim();
  if (direct.startsWith('BV')) {
    return direct;
  }
  const marker = '/video/';
  const index = pageUrl.indexOf(marker);
  if (index >= 0) {
    const token = tokenUntil(pageUrl.substring(index + marker.length), ['?', '#', '/', '&']);
    return token.startsWith('BV') ? token : '';
  }
  const queryMarker = 'bvid=';
  const queryIndex = pageUrl.indexOf(queryMarker);
  if (queryIndex >= 0) {
    const token = tokenUntil(pageUrl.substring(queryIndex + queryMarker.length), ['&', '#', '?', '/']);
    return token.startsWith('BV') ? token : '';
  }
  return '';
}

function tokenUntil(value: string, stops: string[]): string {
  let end = value.length;
  for (let index = 0; index < stops.length; index++) {
    const hit = value.indexOf(stops[index]);
    if (hit >= 0 && hit < end) {
      end = hit;
    }
  }
  return value.substring(0, end).trim();
}

function mapsOpenWebAction(result: A2uiGenericToolResultData): A2uiAction | null {
  if (result.sourceTag !== 'Google Places API' && result.toolName.indexOf('maps.place.') !== 0) {
    return null;
  }
  const url = genericResultRowValue(result, 'Maps URL');
  if (url.length === 0) {
    return null;
  }
  return {
    id: 'maps.open.web',
    label: '打开 Google Maps',
    prompt: url,
    variant: 'secondary',
    kind: 'client'
  };
}

function genericResultRowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function appendSocialBlocks(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const messages = socialMessages(surface, component);
  const diagnostics = socialDiagnostics(surface);
  if (messages.length === 0 && diagnostics.length === 0) {
    appendGenericComponentBlock(document, surface, component);
    return;
  }
  messages.forEach((item: A2uiSocialMessageData, index: number) => {
    const block = newBlock(component.id + '-' + index.toString(), 'social-message', firstText(item.conversationTitle, item.senderName, item.id));
    block.subtitle = item.preview;
    block.status = item.status;
    block.source = item.source;
    appendMetric(block.metrics, 'platform', item.platform);
    appendMetric(block.metrics, 'sender', item.senderName);
    appendMetric(block.metrics, 'receivedAt', item.receivedAt);
    block.actions = htmlActions(actionsOf(component), component.id);
    const itemId = textOf(item.id);
    if (itemId.length > 0) {
      block.actions.push(clientAction('social_select_message', '选择消息', itemId, component.id));
    }
    document.blocks.push(block);
  });
  if (diagnostics.length > 0) {
    const block = newBlock(component.id + '-diagnostics', 'social-diagnostics', '社交权限诊断');
    diagnostics.forEach((row: A2uiLabelValueData) => {
      appendMetric(block.rows, row.label, row.value);
    });
    block.actions.push(clientAction('social_open_notification_settings', '打开通知授权',
      'social_open_notification_settings', component.id));
    document.blocks.push(block);
  }
}

function appendGenericComponentBlock(document: HtmlHomeDocument, surface: A2uiSurfaceState, component: A2uiComponent): void {
  const title = firstText(componentTitleOf(component), componentTextOf(component), component.component + ':' + component.id);
  const block = newBlock(component.id, component.component, title);
  block.subtitle = componentBodyOf(component);
  block.status = componentStatusOf(component, '');
  block.source = component.dataPath === undefined ? '' : component.dataPath;
  if (component.component === A2UI_COMPONENT_INFO_ROWS) {
    labelValues(surface, component).forEach((row: A2uiLabelValueData) => {
      appendMetric(block.rows, row.label, row.value);
    });
  }
  block.actions = htmlActions(actionsOf(component), component.id);
  if (block.subtitle !== undefined && block.subtitle.length > 0 || block.status !== undefined && block.status.length > 0 ||
    block.rows.length > 0 || block.actions.length > 0 || component.component === A2UI_COMPONENT_TEXT ||
    component.component === A2UI_COMPONENT_ERROR_NOTICE || component.component === A2UI_COMPONENT_THINKING_STREAM ||
    component.component === A2UI_COMPONENT_THINKING_CARD || component.component === A2UI_COMPONENT_INFO_ROWS ||
    component.component === A2UI_COMPONENT_TRAIN_OPTIONS || component.component === A2UI_COMPONENT_FLIGHT_BOARD) {
    document.blocks.push(block);
  }
}

function dropCompletedThinkingBlocks(document: HtmlHomeDocument, isBusy: boolean): void {
  if (isBusy || !hasNonThinkingBlock(document.blocks)) {
    return;
  }
  document.blocks = document.blocks.filter((block: HtmlHomeBlock) => !isThinkingBlock(block));
}

function hasNonThinkingBlock(blocks: HtmlHomeBlock[]): boolean {
  for (let index = 0; index < blocks.length; index++) {
    if (!isThinkingBlock(blocks[index])) {
      return true;
    }
  }
  return false;
}

function isThinkingBlock(block: HtmlHomeBlock): boolean {
  return block.kind === A2UI_COMPONENT_THINKING_STREAM || block.kind === A2UI_COMPONENT_THINKING_CARD ||
    block.kind === 'thinking';
}

function kindOf(surface: A2uiSurfaceState): HtmlHomeKind {
  if (hasComponent(surface, A2UI_COMPONENT_SOCIAL_INBOX) || surface.intent === 'social') {
    return 'social';
  }
  if (hasGmailData(surface)) {
    return 'gmail';
  }
  if (hasComponent(surface, A2UI_COMPONENT_TRAVEL_OPTIONS) ||
    hasComponent(surface, A2UI_COMPONENT_TRAIN_OPTIONS) ||
    hasComponent(surface, A2UI_COMPONENT_FLIGHT_BOARD) ||
    surface.intent === 'travel') {
    return 'travel';
  }
  if (hasComponent(surface, A2UI_COMPONENT_FOOD_CHOICES) || surface.intent === 'food') {
    return 'food';
  }
  if (hasComponent(surface, A2UI_COMPONENT_TOOL_CONNECT_CARD) ||
    hasComponent(surface, A2UI_COMPONENT_GENERIC_TOOL_RESULTS) ||
    surface.intent === 'dynamic_tool' ||
    hasDynamicData(surface)) {
    return 'dynamic-tools';
  }
  if (hasComponent(surface, A2UI_COMPONENT_THINKING_STREAM) ||
    hasComponent(surface, A2UI_COMPONENT_THINKING_CARD) ||
    surface.status === 'thinking') {
    return 'thinking';
  }
  return 'generic';
}

function sourceOf(kind: HtmlHomeKind, surface: A2uiSurfaceState, isBusy: boolean): HtmlHomeSource {
  if (kind === 'thinking' || isBusy && surface.status !== 'ready') {
    return 'pending';
  }
  if (kind === 'travel' || kind === 'food' || kind === 'social' || kind === 'dynamic-tools' || kind === 'gmail') {
    return 'tool';
  }
  return 'model';
}

function hasComponent(surface: A2uiSurfaceState, componentName: string): boolean {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].component === componentName) {
      return true;
    }
  }
  return false;
}

function hasDynamicData(surface: A2uiSurfaceState): boolean {
  const connect = dynamicToolConnect(surface);
  return hasConnectData(connect) || genericToolResults(surface).length > 0;
}

function hasConnectData(data: A2uiDynamicToolConnectData): boolean {
  return data.toolId.length > 0 || data.displayName.length > 0 || data.sourceUrl.length > 0 ||
    data.status.length > 0 || data.message.length > 0 || data.credentialName.length > 0 ||
    data.credentialRef.length > 0 || data.actions.length > 0;
}

function hasGmailData(surface: A2uiSurfaceState): boolean {
  const connect = dynamicToolConnect(surface);
  if (connect.toolId.indexOf('gmail.') >= 0 || connect.displayName.indexOf('Gmail') >= 0) {
    return true;
  }
  const results = genericToolResults(surface);
  for (let index = 0; index < results.length; index++) {
    if (results[index].sourceTag === 'Gmail API' ||
      results[index].toolName.indexOf('gmail.') >= 0 ||
      results[index].toolName.indexOf('users.') === 0) {
      return true;
    }
  }
  return false;
}

function appendComponentActions(actions: HtmlHomeAction[], component: A2uiComponent): void {
  htmlActions(actionsOf(component), component.id).forEach((action: HtmlHomeAction) => {
    appendAction(actions, action);
  });
}

function htmlActions(actions: A2uiAction[], sourceComponentId: string): HtmlHomeAction[] {
  const mapped: HtmlHomeAction[] = [];
  if (actions === undefined || actions === null || !Array.isArray(actions)) {
    return mapped;
  }
  actions.forEach((action: A2uiAction) => {
    if (action === undefined || action === null) {
      return;
    }
    const actionId = textOf(action.id);
    const actionLabel = textOf(action.label);
    const prompt = textOf(action.prompt);
    if (actionId.length === 0 && actionLabel.length === 0 && prompt.length === 0) {
      return;
    }
    const id = firstText(actionId, sourceComponentId);
    const label = firstText(actionLabel, id);
    mapped.push({
      id: id,
      label: label,
      prompt: prompt,
      variant: textOf(action.variant),
      kind: textOf(action.kind),
      sourceComponentId: sourceComponentId,
      args: action.args
    });
  });
  return mapped;
}

function clientAction(id: string, label: string, prompt: string, sourceComponentId: string): HtmlHomeAction {
  return {
    id: id,
    label: label,
    prompt: prompt,
    variant: 'secondary',
    kind: 'client',
    sourceComponentId: sourceComponentId
  };
}

function appendAction(actions: HtmlHomeAction[], action: HtmlHomeAction): void {
  for (let index = 0; index < actions.length; index++) {
    if (actions[index].id === action.id && actions[index].prompt === action.prompt) {
      return;
    }
  }
  actions.push(action);
}

function withBusy(document: HtmlHomeDocument, isBusy: boolean): HtmlHomeDocument {
  (document as HtmlHomeDocumentWithBusy).isBusy = isBusy;
  return document;
}

function sourceTagsText(sourceTags: string[] | null | undefined): string {
  if (sourceTags === undefined || sourceTags === null || !Array.isArray(sourceTags)) {
    return '';
  }
  return sourceTags.join(' / ');
}

function newBlock(id: string, kind: string, title: string): HtmlHomeBlock {
  return {
    id: textOf(id),
    kind: textOf(kind),
    title: textOf(title),
    metrics: [],
    rows: [],
    actions: []
  };
}

function appendMetric(metrics: HtmlHomeMetric[], label: HtmlHomeTextValue, value: HtmlHomeTextValue): void {
  const labelText = textOf(label);
  const valueText = textOf(value);
  if (labelText.length === 0 || valueText.length === 0) {
    return;
  }
  metrics.push({
    label: labelText,
    value: valueText
  });
}

function appendTimeline(timeline: HtmlHomeTimelineItem[], title: HtmlHomeTextValue, subtitle: HtmlHomeTextValue, status: HtmlHomeTextValue): void {
  const titleText = textOf(title);
  const subtitleText = textOf(subtitle);
  const statusText = textOf(status);
  if (titleText.length === 0 && subtitleText.length === 0 && statusText.length === 0) {
    return;
  }
  timeline.push({
    title: titleText,
    subtitle: subtitleText,
    status: statusText
  });
}

function recentHistory(messages: A2uiMessage[]): HtmlHomeHistoryItem[] {
  const start = messages.length > HISTORY_LIMIT ? messages.length - HISTORY_LIMIT : 0;
  const history: HtmlHomeHistoryItem[] = [];
  for (let index = start; index < messages.length; index++) {
    const content = visibleHistoryContent(messages[index]);
    if (content.length === 0) {
      continue;
    }
    history.push({
      id: messages[index].id,
      role: messages[index].role,
      content: content
    });
  }
  return history;
}

function visibleHistoryContent(message: A2uiMessage): string {
  const content = message.content.trim();
  if (message.role === 'assistant' &&
    (content.indexOf('<think>') >= 0 ||
      content.indexOf('"createSurface"') >= 0 ||
      content.indexOf('"updateComponents"') >= 0 ||
      content.indexOf('"updateDataModel"') >= 0)) {
    return '';
  }
  return content;
}

function lastUserMessage(messages: A2uiMessage[]): string {
  for (let index = messages.length - 1; index >= 0; index--) {
    if (messages[index].role === 'user' && messages[index].content.length > 0) {
      return messages[index].content;
    }
  }
  return '';
}

function textOf(value: HtmlHomeTextValue): string {
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

function firstText(first: HtmlHomeTextValue, second: HtmlHomeTextValue = '', third: HtmlHomeTextValue = ''): string {
  const firstValue = textOf(first);
  if (firstValue.length > 0) {
    return firstValue;
  }
  const secondValue = textOf(second);
  if (secondValue.length > 0) {
    return secondValue;
  }
  return textOf(third);
}

function joinText(values: HtmlHomeTextValue[], separator: string): string {
  const kept: string[] = [];
  values.forEach((value: HtmlHomeTextValue) => {
    const text = textOf(value);
    if (text.length > 0) {
      kept.push(text);
    }
  });
  return kept.join(separator);
}

function firstDateText(...values: HtmlHomeTextValue[]): string {
  const match = /(\d{4}-\d{1,2}-\d{1,2})/.exec(joinText(values, ' '));
  return match === null ? '' : match[1];
}

function summaryText(surface: A2uiSurfaceState): string {
  const summary = resolveData(surface, '/summary') as A2uiSummaryData;
  return summary === undefined || summary === null ? '' : textOf(summary.text);
}
