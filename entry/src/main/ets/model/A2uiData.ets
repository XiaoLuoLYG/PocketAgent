import {
  A2uiAction,
  A2uiComponent,
  A2uiDataValue,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiLabelValueData,
  A2uiRowGroupsData,
  A2uiRuntimeDataModel,
  A2uiSocialData,
  A2uiSocialMessageData,
  A2uiSocialReplyData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTravelOptionData,
  A2uiTrainData
} from './A2uiTypes';

export type A2uiLabelValue = A2uiLabelValueData;
export type A2uiTrainOption = A2uiTrainData;
export type A2uiFlightOption = A2uiFlightData;
export type A2uiTravelOption = A2uiTravelOptionData;
export type A2uiFoodOption = A2uiFoodData;
export type A2uiSocialMessage = A2uiSocialMessageData;
export type A2uiSocialReply = A2uiSocialReplyData;
export type A2uiToolRequest = A2uiToolRequestData;

interface LooseRowData {
  label?: Object | string | number | boolean | null;
  value?: Object | string | number | boolean | null;
  title?: Object | string | number | boolean | null;
  subtitle?: Object | string | number | boolean | null;
  direction?: Object | string | number | boolean | null;
  type?: Object | string | number | boolean | null;
  status?: Object | string | number | boolean | null;
  note?: Object | string | number | boolean | null;
  rows?: Object[];
  items?: Object[];
  body?: Object[];
}

interface LooseGenericToolResultRowData {
  label?: Object | string | number | boolean | null;
  value?: Object | string | number | boolean | null;
}

interface LooseGenericToolResultData {
  sourceTag?: Object | string | number | boolean | null;
  toolName?: Object | string | number | boolean | null;
  title?: Object | string | number | boolean | null;
  status?: Object | string | number | boolean | null;
  summary?: Object | string | number | boolean | null;
  rows?: Object[];
  rawPreview?: Object | string | number | boolean | null;
}

function emptyModel(): A2uiRuntimeDataModel {
  return {
    rows: [],
    trains: [],
    flights: [],
    travelOptions: [],
    foods: [],
    social: emptySocial(),
    thoughts: [],
    summary: {
      text: '',
      toolName: '',
      dataLabel: '',
      count: 0
    },
    trip: {
      rows: []
    },
    rowGroups: emptyRowGroups(),
    toolRequest: {
      toolId: '',
      prompt: '',
      actionId: ''
    },
    dynamicToolConnect: emptyDynamicToolConnect(),
    genericToolResults: []
  };
}

function emptySocial(): A2uiSocialData {
  return {
    messages: [],
    replies: [],
    diagnostics: []
  };
}

function emptyRowGroups(): A2uiRowGroupsData {
  return {
    train: [],
    flight: [],
    food: []
  };
}

function emptyDynamicToolConnect(): A2uiDynamicToolConnectData {
  return {
    toolId: '',
    prompt: '',
    manifestId: '',
    displayName: '',
    sourceUrl: '',
    status: '',
    message: '',
    credentialName: '',
    credentialRef: '',
    registrationUrl: '',
    actions: []
  };
}

function normalizeDynamicToolConnect(parsed: A2uiRuntimeDataModel, fallback: A2uiDynamicToolConnectData): A2uiDynamicToolConnectData {
  if (parsed.dynamicToolConnect === undefined || parsed.dynamicToolConnect === null) {
    return fallback;
  }
  return {
    toolId: textOf(parsed.dynamicToolConnect.toolId),
    prompt: textOf(parsed.dynamicToolConnect.prompt),
    manifestId: textOf(parsed.dynamicToolConnect.manifestId),
    displayName: textOf(parsed.dynamicToolConnect.displayName),
    sourceUrl: textOf(parsed.dynamicToolConnect.sourceUrl),
    status: textOf(parsed.dynamicToolConnect.status),
    message: textOf(parsed.dynamicToolConnect.message),
    credentialName: textOf(parsed.dynamicToolConnect.credentialName),
    credentialRef: textOf(parsed.dynamicToolConnect.credentialRef),
    registrationUrl: textOf(parsed.dynamicToolConnect.registrationUrl),
    actions: Array.isArray(parsed.dynamicToolConnect.actions) ? parsed.dynamicToolConnect.actions : []
  };
}

function normalizeGenericToolResultRows(rows: Object[] | undefined): A2uiGenericToolResultRowData[] {
  if (!Array.isArray(rows)) {
    return [];
  }
  const normalized: A2uiGenericToolResultRowData[] = [];
  for (let index = 0; index < rows.length; index++) {
    const source = rows[index];
    if (source === undefined || source === null) {
      continue;
    }
    const row = source as LooseGenericToolResultRowData;
    const label = textOf(row.label);
    const value = textOf(row.value);
    if (label.length > 0 || value.length > 0) {
      normalized.push({
        label: label,
        value: value
      });
    }
  }
  return normalized;
}

function normalizeGenericToolResults(parsed: A2uiRuntimeDataModel, fallback: A2uiGenericToolResultData[]): A2uiGenericToolResultData[] {
  if (!Array.isArray(parsed.genericToolResults)) {
    return fallback;
  }
  const normalized: A2uiGenericToolResultData[] = [];
  for (let index = 0; index < parsed.genericToolResults.length; index++) {
    const source = parsed.genericToolResults[index];
    if (source === undefined || source === null) {
      continue;
    }
    const result = source as LooseGenericToolResultData;
    normalized.push({
      sourceTag: textOf(result.sourceTag),
      toolName: textOf(result.toolName),
      title: textOf(result.title),
      status: textOf(result.status),
      summary: textOf(result.summary),
      rows: normalizeGenericToolResultRows(result.rows),
      rawPreview: textOf(result.rawPreview)
    });
  }
  return normalized;
}

function normalizeToolRequest(parsed: A2uiRuntimeDataModel, fallback: A2uiToolRequestData): A2uiToolRequestData {
  if (parsed.toolRequest !== undefined && parsed.toolRequest !== null && parsed.toolRequest.toolId !== undefined) {
    return parsed.toolRequest;
  }
  if (parsed.toolRequests !== undefined && parsed.toolRequests !== null && Array.isArray(parsed.toolRequests) && parsed.toolRequests.length > 0) {
    return parsed.toolRequests[0];
  }
  return fallback;
}

function normalizeRowGroups(parsed: A2uiRuntimeDataModel, fallback: A2uiRowGroupsData): A2uiRowGroupsData {
  if (parsed.rowGroups === undefined || parsed.rowGroups === null) {
    return fallback;
  }
  return {
    train: Array.isArray(parsed.rowGroups.train) ? parsed.rowGroups.train : fallback.train,
    flight: Array.isArray(parsed.rowGroups.flight) ? parsed.rowGroups.flight : fallback.flight,
    food: Array.isArray(parsed.rowGroups.food) ? parsed.rowGroups.food : fallback.food
  };
}

function normalizeSocial(parsed: A2uiRuntimeDataModel, fallback: A2uiSocialData): A2uiSocialData {
  if (parsed.social === undefined || parsed.social === null) {
    return fallback;
  }
  return {
    messages: Array.isArray(parsed.social.messages) ? parsed.social.messages : fallback.messages,
    replies: Array.isArray(parsed.social.replies) ? parsed.social.replies : fallback.replies,
    diagnostics: Array.isArray(parsed.social.diagnostics) ? parsed.social.diagnostics : fallback.diagnostics
  };
}

function parseModel(surface: A2uiSurfaceState): A2uiRuntimeDataModel {
  const fallback = emptyModel();
  try {
    const parsed = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    return {
      rows: Array.isArray(parsed.rows) ? parsed.rows : fallback.rows,
      trains: Array.isArray(parsed.trains) ? parsed.trains : fallback.trains,
      flights: Array.isArray(parsed.flights) ? parsed.flights : fallback.flights,
      travelOptions: Array.isArray(parsed.travelOptions) ? parsed.travelOptions : fallback.travelOptions,
      foods: Array.isArray(parsed.foods) ? parsed.foods : fallback.foods,
      social: normalizeSocial(parsed, fallback.social),
      thoughts: Array.isArray(parsed.thoughts) ? parsed.thoughts : fallback.thoughts,
      summary: parsed.summary === undefined || parsed.summary === null ? fallback.summary : parsed.summary,
      trip: parsed.trip === undefined || parsed.trip === null ? fallback.trip : {
        rows: Array.isArray(parsed.trip.rows) ? parsed.trip.rows : fallback.trip.rows
      },
      rowGroups: normalizeRowGroups(parsed, fallback.rowGroups),
      toolRequest: normalizeToolRequest(parsed, fallback.toolRequest),
      dynamicToolConnect: normalizeDynamicToolConnect(parsed, fallback.dynamicToolConnect),
      genericToolResults: normalizeGenericToolResults(parsed, fallback.genericToolResults),
      toolRequests: Array.isArray(parsed.toolRequests) ? parsed.toolRequests : []
    };
  } catch (_error) {
    return fallback;
  }
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

function joinRowParts(first: string, second: string, third: string): string {
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

function rowsFromLooseArray(value: Object[]): A2uiLabelValue[] {
  const rows: A2uiLabelValue[] = [];
  value.forEach((item: Object, index: number) => {
    const record = item as LooseRowData;
    const labelSource = textOf(record.label);
    const titleSource = textOf(record.title);
    const typeSource = textOf(record.type);
    const directionSource = textOf(record.direction);
    const valueSource = textOf(record.value);
    const subtitleSource = textOf(record.subtitle);
    const statusSource = textOf(record.status);
    const noteSource = textOf(record.note);
    const label = labelSource.length > 0 ? labelSource :
      (titleSource.length > 0 ? titleSource :
      (typeSource.length > 0 ? typeSource :
      (directionSource.length > 0 ? directionSource : '信息 ' + (index + 1).toString())));
    const valueText = valueSource.length > 0 ? valueSource :
      (subtitleSource.length > 0 ? subtitleSource : joinRowParts(directionSource, statusSource, noteSource));
    rows.push({
      label: label,
      value: valueText.length > 0 ? valueText : textOf(item)
    });
  });
  return rows;
}

function labelValuesFromComponentBody(component: A2uiComponent): A2uiLabelValue[] {
  if (component.body === undefined || component.body.length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(component.body) as Object;
    if (Array.isArray(parsed)) {
      return rowsFromLooseArray(parsed as Object[]);
    }
    const record = parsed as LooseRowData;
    if (Array.isArray(record.rows)) {
      return rowsFromLooseArray(record.rows as Object[]);
    }
    if (Array.isArray(record.items)) {
      return rowsFromLooseArray(record.items as Object[]);
    }
    if (Array.isArray(record.body)) {
      return rowsFromLooseArray(record.body as Object[]);
    }
  } catch (_error) {
    return [];
  }
  return [];
}

export function resolveData(surface: A2uiSurfaceState, path: string | undefined): A2uiDataValue {
  const model = parseModel(surface);
  if (path === '/rows') {
    return model.rows;
  }
  if (path === '/trains') {
    return model.trains;
  }
  if (path === '/flights') {
    return model.flights;
  }
  if (path === '/travelOptions') {
    return model.travelOptions;
  }
  if (path === '/foods') {
    return model.foods;
  }
  if (path === '/social') {
    return model.social;
  }
  if (path === '/social/messages') {
    return model.social.messages;
  }
  if (path === '/social/replies') {
    return model.social.replies;
  }
  if (path === '/social/diagnostics') {
    return model.social.diagnostics;
  }
  if (path === '/thoughts') {
    return model.thoughts;
  }
  if (path === '/summary') {
    return model.summary;
  }
  if (path === '/trip') {
    return model.trip;
  }
  if (path === '/trip/rows') {
    return model.trip.rows;
  }
  if (path === '/rows/train') {
    return model.rowGroups.train;
  }
  if (path === '/rows/flight') {
    return model.rowGroups.flight;
  }
  if (path === '/rows/food') {
    return model.rowGroups.food;
  }
  if (path === '/toolRequest') {
    return model.toolRequest;
  }
  if (path === '/dynamicToolConnect') {
    return model.dynamicToolConnect;
  }
  if (path === '/genericToolResults') {
    return model.genericToolResults;
  }
  if (path === '/') {
    return model;
  }
  return null;
}

export function labelValues(surface: A2uiSurfaceState, component: A2uiComponent): A2uiLabelValue[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/trip/rows') {
    return data as A2uiLabelValue[];
  }
  if (component.dataPath === '/rows') {
    return data as A2uiLabelValue[];
  }
  if (component.dataPath === '/rows/train' || component.dataPath === '/rows/flight' || component.dataPath === '/rows/food') {
    return data as A2uiLabelValue[];
  }
  if (component.dataPath === '/social/diagnostics') {
    return data as A2uiLabelValue[];
  }
  return labelValuesFromComponentBody(component);
}

export function trainOptions(surface: A2uiSurfaceState, component: A2uiComponent): A2uiTrainOption[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/trains') {
    return data as A2uiTrainOption[];
  }
  return [];
}

export function flightOptions(surface: A2uiSurfaceState, component: A2uiComponent): A2uiFlightOption[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/flights') {
    return data as A2uiFlightOption[];
  }
  return [];
}

export function travelOptions(surface: A2uiSurfaceState, component: A2uiComponent): A2uiTravelOption[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/travelOptions') {
    return data as A2uiTravelOption[];
  }
  return [];
}

export function foodOptions(surface: A2uiSurfaceState, component: A2uiComponent): A2uiFoodOption[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/foods') {
    return data as A2uiFoodOption[];
  }
  return [];
}

export function uniqueFoodSourceTags(sourceTags: string[] | null | undefined): string[] {
  if (sourceTags === undefined || sourceTags === null || !Array.isArray(sourceTags)) {
    return [];
  }
  const tags: string[] = [];
  sourceTags.forEach((tag: string) => {
    if (tag.length > 0 && tags.indexOf(tag) < 0) {
      tags.push(tag);
    }
  });
  return tags;
}

export function foodVisualSourceTag(sourceTags: string[] | null | undefined): string {
  const tags = uniqueFoodSourceTags(sourceTags);
  return tags.length === 1 ? tags[0] : '';
}

export function socialMessages(surface: A2uiSurfaceState, component: A2uiComponent): A2uiSocialMessage[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/social/messages') {
    return data as A2uiSocialMessage[];
  }
  return [];
}

export function socialReplies(surface: A2uiSurfaceState): A2uiSocialReply[] {
  const data = resolveData(surface, '/social/replies');
  return data as A2uiSocialReply[];
}

export function socialDiagnostics(surface: A2uiSurfaceState): A2uiLabelValue[] {
  const data = resolveData(surface, '/social/diagnostics');
  return data as A2uiLabelValue[];
}

export function actionsOf(component: A2uiComponent): A2uiAction[] {
  if (component.actions === undefined || component.actions === null) {
    return [];
  }
  return component.actions;
}

export function toolRequest(surface: A2uiSurfaceState): A2uiToolRequest {
  return parseModel(surface).toolRequest;
}

export function dynamicToolConnect(surface: A2uiSurfaceState): A2uiDynamicToolConnectData {
  return parseModel(surface).dynamicToolConnect;
}

export function genericToolResults(surface: A2uiSurfaceState): A2uiGenericToolResultData[] {
  return parseModel(surface).genericToolResults;
}

export function componentById(surface: A2uiSurfaceState, id: string): A2uiComponent | null {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].id === id) {
      return surface.components[index];
    }
  }
  return null;
}
