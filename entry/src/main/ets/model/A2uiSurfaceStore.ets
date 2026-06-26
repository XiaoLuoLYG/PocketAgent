import {
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiApplyResult,
  A2uiComponent,
  A2uiDataValue,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiLabelValueData,
  A2uiEnvelope,
  A2uiRowGroupsData,
  A2uiRuntimeDataModel,
  A2uiSummaryData,
  A2uiSocialData,
  A2uiSocialMessageData,
  A2uiSocialReplyData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTravelOptionData,
  A2uiTrainData,
  A2uiTripData,
  emptyA2uiSurface
} from './A2uiTypes';

function cloneComponents(values: A2uiComponent[]): A2uiComponent[] {
  const next: A2uiComponent[] = [];
  values.forEach((component: A2uiComponent) => {
    next.push({
      id: component.id,
      component: component.component,
      child: component.child,
      children: component.children === undefined ? [] : component.children.slice(),
      title: component.title,
      text: component.text,
      body: component.body,
      status: component.status,
      tone: component.tone,
      variant: component.variant,
      path: component.path,
      dataPath: component.dataPath,
      actions: component.actions === undefined ? [] : component.actions.slice()
    });
  });
  return next;
}

function componentIndex(components: A2uiComponent[], id: string): number {
  for (let index = 0; index < components.length; index++) {
    if (components[index].id === id) {
      return index;
    }
  }
  return -1;
}

function upsertComponents(current: A2uiComponent[], updates: A2uiComponent[]): A2uiComponent[] {
  const next = cloneComponents(current);
  updates.forEach((component: A2uiComponent) => {
    const index = componentIndex(next, component.id);
    if (index >= 0) {
      next[index] = component;
    } else {
      next.push(component);
    }
  });
  return next;
}

function emptyDataModel(): A2uiRuntimeDataModel {
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

function emptyToolRequest(): A2uiToolRequestData {
  return {
    toolId: '',
    prompt: '',
    actionId: ''
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

function labelRowsFromLooseArray(value: Object[]): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
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

function labelRowsFromDataValue(value: A2uiDataValue): A2uiLabelValueData[] {
  if (Array.isArray(value)) {
    return labelRowsFromLooseArray(value as Object[]);
  }
  if (value === undefined || value === null || typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return [];
  }
  const record = value as LooseRowData;
  if (Array.isArray(record.rows)) {
    return labelRowsFromLooseArray(record.rows as Object[]);
  }
  if (Array.isArray(record.items)) {
    return labelRowsFromLooseArray(record.items as Object[]);
  }
  if (Array.isArray(record.body)) {
    return labelRowsFromLooseArray(record.body as Object[]);
  }
  return [];
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

function parseDataModel(json: string): A2uiRuntimeDataModel {
  const fallback = emptyDataModel();
  try {
    const parsed = JSON.parse(json) as A2uiRuntimeDataModel;
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

function decodeJsonPointerSegment(segment: string): string {
  return segment.split('~1').join('/').split('~0').join('~');
}

function jsonPointerSegments(path: string): string[] {
  const segments: string[] = [];
  if (path.length === 0 || path.charAt(0) !== '/') {
    return segments;
  }
  const rawSegments = path.substring(1).split('/');
  rawSegments.forEach((segment: string) => {
    segments.push(decodeJsonPointerSegment(segment));
  });
  return segments;
}

function arrayIndex(value: string, length: number): number {
  const index = Number(value);
  if (index < 0 || Math.floor(index) !== index || index >= length) {
    return -1;
  }
  return index;
}

function setLabelValueField(rows: A2uiLabelValueData[], indexText: string, field: string, value: A2uiDataValue): boolean {
  const index = arrayIndex(indexText, rows.length);
  if (index < 0) {
    return false;
  }
  if (field === 'label') {
    rows[index].label = textOf(value);
    return true;
  }
  if (field === 'value') {
    rows[index].value = textOf(value);
    return true;
  }
  return false;
}

function setKnownNestedDataPath(next: A2uiRuntimeDataModel, path: string, value: A2uiDataValue): boolean {
  const segments = jsonPointerSegments(path);
  if (segments.length === 3 && segments[0] === 'rows') {
    return setLabelValueField(next.rows, segments[1], segments[2], value);
  }
  if (segments.length === 4 && segments[0] === 'trip' && segments[1] === 'rows') {
    return setLabelValueField(next.trip.rows, segments[2], segments[3], value);
  }
  if (segments.length === 4 && segments[0] === 'rows' && segments[1] === 'train') {
    return setLabelValueField(next.rowGroups.train, segments[2], segments[3], value);
  }
  if (segments.length === 4 && segments[0] === 'rows' && segments[1] === 'flight') {
    return setLabelValueField(next.rowGroups.flight, segments[2], segments[3], value);
  }
  if (segments.length === 4 && segments[0] === 'rows' && segments[1] === 'food') {
    return setLabelValueField(next.rowGroups.food, segments[2], segments[3], value);
  }
  return false;
}

function setKnownDataPath(model: A2uiRuntimeDataModel, path: string, value: A2uiDataValue): A2uiRuntimeDataModel {
  const next = parseDataModel(JSON.stringify(model));
  if (path === '/') {
    return value as A2uiRuntimeDataModel;
  }
  if (path === '/rows') {
    next.rows = value as A2uiLabelValueData[];
  } else if (path === '/trains') {
    next.trains = value as A2uiTrainData[];
  } else if (path === '/flights') {
    next.flights = value as A2uiFlightData[];
  } else if (path === '/travelOptions') {
    next.travelOptions = value as A2uiTravelOptionData[];
  } else if (path === '/foods') {
    next.foods = value as A2uiFoodData[];
  } else if (path === '/social') {
    next.social = value as A2uiSocialData;
  } else if (path === '/social/messages') {
    next.social.messages = value as A2uiSocialMessageData[];
  } else if (path === '/social/replies') {
    next.social.replies = value as A2uiSocialReplyData[];
  } else if (path === '/social/diagnostics') {
    next.social.diagnostics = labelRowsFromDataValue(value);
  } else if (path === '/thoughts') {
    const incoming = value as string[];
    const existingJoined = next.thoughts.join('');
    const incomingJoined = incoming.join('');
    if (existingJoined.length > incomingJoined.length) {
      return next;
    }
    next.thoughts = incoming;
  } else if (path === '/summary') {
    next.summary = value as A2uiSummaryData;
  } else if (path === '/trip') {
    next.trip = value as A2uiTripData;
  } else if (path === '/trip/rows') {
    next.trip.rows = value as A2uiLabelValueData[];
  } else if (path === '/rows/train') {
    next.rowGroups.train = labelRowsFromDataValue(value);
  } else if (path === '/rows/flight') {
    next.rowGroups.flight = labelRowsFromDataValue(value);
  } else if (path === '/rows/food') {
    next.rowGroups.food = labelRowsFromDataValue(value);
  } else if (path === '/toolRequest') {
    next.toolRequest = value as A2uiToolRequestData;
    next.toolRequests = [next.toolRequest];
  } else if (path === '/dynamicToolConnect') {
    next.dynamicToolConnect = value as A2uiDynamicToolConnectData;
  } else if (path === '/genericToolResults') {
    next.genericToolResults = value as A2uiGenericToolResultData[];
  } else if (path === '/toolRequests') {
    const requests = value as A2uiToolRequestData[];
    next.toolRequests = requests;
    next.toolRequest = requests.length > 0 ? requests[0] : emptyToolRequest();
  } else {
    setKnownNestedDataPath(next, path, value);
  }
  return next;
}

function hasRoot(surface: A2uiSurfaceState): boolean {
  return componentIndex(surface.components, surface.rootId) >= 0;
}

function createErrorComponent(title: string, body: string): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'error',
    children: [],
    title: title,
    body: body,
    status: 'error'
  };
}

function errorNotice(title: string, body: string): A2uiComponent {
  return {
    id: 'error',
    component: A2UI_COMPONENT_ERROR_NOTICE,
    title: title,
    body: body,
    status: 'error',
    actions: []
  };
}

export class A2uiSurfaceStore {
  private surface: A2uiSurfaceState = emptyA2uiSurface();

  getSurface(): A2uiSurfaceState {
    return {
      surfaceId: this.surface.surfaceId,
      rootId: this.surface.rootId,
      title: this.surface.title,
      intent: this.surface.intent,
      status: this.surface.status,
      components: cloneComponents(this.surface.components),
      dataModelJson: this.surface.dataModelJson,
      error: this.surface.error,
      sequence: this.surface.sequence
    };
  }

  reset(surfaceId: string = 'surface_main'): A2uiSurfaceState {
    this.surface = emptyA2uiSurface(surfaceId);
    return this.getSurface();
  }

  seed(surface: A2uiSurfaceState): A2uiSurfaceState {
    this.surface = {
      surfaceId: surface.surfaceId,
      rootId: surface.rootId,
      title: surface.title,
      intent: surface.intent,
      status: surface.status,
      components: cloneComponents(surface.components),
      dataModelJson: surface.dataModelJson,
      error: surface.error,
      sequence: surface.sequence
    };
    return this.getSurface();
  }

  apply(envelope: A2uiEnvelope): A2uiApplyResult {
    try {
      if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
        const nextSurfaceId = envelope.createSurface.surfaceId;
        const nextRootId = envelope.createSurface.root === undefined || envelope.createSurface.root.length === 0 ?
          'root' : envelope.createSurface.root;
        const nextTitle = envelope.createSurface.title === undefined || envelope.createSurface.title.length === 0 ?
          'Appless Phone' : envelope.createSurface.title;
        const nextIntent = envelope.createSurface.intent === undefined || envelope.createSurface.intent.length === 0 ?
          'general' : envelope.createSurface.intent;
        const nextStatus = envelope.createSurface.status === undefined || envelope.createSurface.status.length === 0 ?
          'thinking' : envelope.createSurface.status;
        const preservedThoughts = parseDataModel(this.surface.dataModelJson).thoughts;
        if (this.surface.surfaceId === nextSurfaceId && this.surface.components.length > 0) {
          if (envelope.createSurface.sendDataModel === true && nextStatus === 'calling_tool') {
            this.surface.dataModelJson = JSON.stringify(emptyDataModel());
          }
          this.surface.rootId = nextRootId;
          this.surface.title = nextTitle;
          this.surface.intent = nextIntent;
          this.surface.status = nextStatus;
          this.surface.error = '';
          this.surface.sequence = this.surface.sequence + 1;
          return { ok: true, error: '' };
        }
        const nextDataModel = emptyDataModel();
        if (preservedThoughts.length > 0) {
          nextDataModel.thoughts = preservedThoughts;
        }
        this.surface = {
          surfaceId: nextSurfaceId,
          rootId: nextRootId,
          title: nextTitle,
          intent: nextIntent,
          status: nextStatus,
          components: [],
          dataModelJson: JSON.stringify(nextDataModel),
          error: '',
          sequence: this.surface.sequence + 1
        };
        return { ok: true, error: '' };
      }

      if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
        if (envelope.updateComponents.surfaceId !== this.surface.surfaceId) {
          throw new Error('A2UI surfaceId mismatch');
        }
        this.surface.components = upsertComponents(this.surface.components, envelope.updateComponents.components);
        this.surface.sequence = this.surface.sequence + 1;
        if (!hasRoot(this.surface)) {
          this.surface.status = 'thinking';
        }
        return { ok: true, error: '' };
      }

      if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
        if (envelope.updateDataModel.surfaceId !== this.surface.surfaceId) {
          throw new Error('A2UI surfaceId mismatch');
        }
        const model = parseDataModel(this.surface.dataModelJson);
        this.surface.dataModelJson = JSON.stringify(setKnownDataPath(model, envelope.updateDataModel.path, envelope.updateDataModel.value));
        this.surface.sequence = this.surface.sequence + 1;
        return { ok: true, error: '' };
      }

      if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
        if (envelope.deleteSurface.surfaceId === this.surface.surfaceId) {
          this.reset();
        }
        return { ok: true, error: '' };
      }

      throw new Error('A2UI envelope is empty');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'A2UI apply failed';
      return { ok: false, error: message };
    }
  }

  applyError(title: string, detail: string): A2uiSurfaceState {
    this.surface = {
      surfaceId: 'surface_error',
      rootId: 'root',
      title: title,
      intent: 'general',
      status: 'error',
      components: [
        createErrorComponent(title, detail),
        errorNotice(title, detail)
      ],
      dataModelJson: '{}',
      error: detail,
      sequence: this.surface.sequence + 1
    };
    return this.getSurface();
  }
}

export function createSeedA2uiSurface(): A2uiSurfaceState {
  const store = new A2uiSurfaceStore();
  store.apply({
    version: 'v0.9.1',
    createSurface: {
      surfaceId: 'surface_seed',
      root: 'root',
      title: 'Appless Phone',
      intent: 'general',
      status: 'idle',
      sendDataModel: true
    }
  });
  return store.getSurface();
}
