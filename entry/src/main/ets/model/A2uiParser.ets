import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_CONFIRM_PANEL,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  A2uiStreamParseResult
} from './A2uiTypes';

const KNOWN_COMPONENTS: string[] = [
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_CONFIRM_PANEL,
  A2UI_COMPONENT_INFO_ROWS
];

function normalizeString(value: string | undefined | null, fallback: string): string {
  if (value === undefined || value === null || value.length === 0) {
    return fallback;
  }
  return value;
}

function isKnownComponent(value: string): boolean {
  return KNOWN_COMPONENTS.indexOf(value) >= 0;
}

function normalizeStringList(value: string[] | undefined | null): string[] {
  const result: string[] = [];
  if (value === undefined || value === null || !Array.isArray(value)) {
    return result;
  }
  value.forEach((item: string) => {
    if (item.length > 0) {
      result.push(item);
    }
  });
  return result;
}

function normalizeActions(value: A2uiAction[] | undefined | null): A2uiAction[] {
  const result: A2uiAction[] = [];
  if (value === undefined || value === null || !Array.isArray(value)) {
    return result;
  }
  value.forEach((action: A2uiAction, index: number) => {
    const label = normalizeString(action.label, '');
    const prompt = normalizeString(action.prompt, '');
    if (label.length === 0 || prompt.length === 0) {
      throw new Error('A2UI action requires label and prompt');
    }
    const variant = normalizeString(action.variant, index === 0 ? 'primary' : 'secondary');
    if (variant !== 'primary' && variant !== 'secondary' && variant !== 'danger') {
      throw new Error('A2UI action variant is not registered');
    }
    result.push({
      id: normalizeString(action.id, 'action_' + index.toString()),
      label: label,
      prompt: prompt,
      variant: variant
    });
  });
  return result;
}

function normalizeComponent(value: A2uiComponent): A2uiComponent {
  const id = normalizeString(value.id, '');
  const component = normalizeString(value.component, '');
  if (id.length === 0 || component.length === 0) {
    throw new Error('A2UI component requires id and component');
  }
  if (!isKnownComponent(component)) {
    throw new Error('A2UI component is not registered: ' + component);
  }
  return {
    id: id,
    component: component,
    child: normalizeString(value.child, ''),
    children: normalizeStringList(value.children),
    title: normalizeString(value.title, ''),
    text: normalizeString(value.text, ''),
    body: normalizeString(value.body, ''),
    status: normalizeString(value.status, 'idle'),
    tone: normalizeString(value.tone, ''),
    variant: normalizeString(value.variant, ''),
    path: normalizeString(value.path, ''),
    dataPath: normalizeString(value.dataPath, ''),
    actions: normalizeActions(value.actions)
  };
}

function normalizeEnvelope(value: A2uiEnvelope): A2uiEnvelope {
  const messageCount =
    (value.createSurface !== undefined && value.createSurface !== null ? 1 : 0) +
    (value.updateComponents !== undefined && value.updateComponents !== null ? 1 : 0) +
    (value.updateDataModel !== undefined && value.updateDataModel !== null ? 1 : 0) +
    (value.deleteSurface !== undefined && value.deleteSurface !== null ? 1 : 0);
  if (messageCount !== 1) {
    throw new Error('A2UI envelope must contain exactly one message');
  }

  if (value.createSurface !== undefined && value.createSurface !== null) {
    const surfaceId = normalizeString(value.createSurface.surfaceId, '');
    if (surfaceId.length === 0) {
      throw new Error('createSurface.surfaceId is required');
    }
    return {
      version: normalizeString(value.version, ''),
      createSurface: {
        surfaceId: surfaceId,
        root: normalizeString(value.createSurface.root, 'root'),
        title: normalizeString(value.createSurface.title, 'AIPhone'),
        intent: normalizeString(value.createSurface.intent, 'general'),
        status: normalizeString(value.createSurface.status, 'thinking'),
        sendDataModel: value.createSurface.sendDataModel === true
      }
    };
  }

  if (value.updateComponents !== undefined && value.updateComponents !== null) {
    const surfaceId = normalizeString(value.updateComponents.surfaceId, '');
    if (surfaceId.length === 0 || value.updateComponents.components === undefined || !Array.isArray(value.updateComponents.components)) {
      throw new Error('updateComponents requires surfaceId and components');
    }
    const components: A2uiComponent[] = [];
    value.updateComponents.components.forEach((component: A2uiComponent) => {
      components.push(normalizeComponent(component));
    });
    return {
      version: normalizeString(value.version, ''),
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    };
  }

  if (value.updateDataModel !== undefined && value.updateDataModel !== null) {
    const surfaceId = normalizeString(value.updateDataModel.surfaceId, '');
    const path = normalizeString(value.updateDataModel.path, '');
    if (surfaceId.length === 0 || path.length === 0) {
      throw new Error('updateDataModel requires surfaceId and path');
    }
    return {
      version: normalizeString(value.version, ''),
      updateDataModel: {
        surfaceId: surfaceId,
        path: path,
        value: value.updateDataModel.value
      }
    };
  }

  const surfaceId = normalizeString(value.deleteSurface?.surfaceId, '');
  if (surfaceId.length === 0) {
    throw new Error('deleteSurface.surfaceId is required');
  }
  return {
    version: normalizeString(value.version, ''),
    deleteSurface: {
      surfaceId: surfaceId
    }
  };
}

export function parseA2uiEnvelope(content: string): A2uiEnvelope {
  const parsed = JSON.parse(content) as A2uiEnvelope;
  if (parsed === undefined || parsed === null) {
    throw new Error('A2UI envelope is empty');
  }
  return normalizeEnvelope(parsed);
}

export function parseA2uiJsonlChunk(chunk: string, previousRemainder: string = ''): A2uiStreamParseResult {
  const text = previousRemainder + chunk;
  const lines = text.split('\n');
  const hasTrailingNewline = text.endsWith('\n');
  const limit = hasTrailingNewline ? lines.length : lines.length - 1;
  const envelopes: A2uiEnvelope[] = [];
  let error = '';

  for (let index = 0; index < limit; index++) {
    const line = lines[index].trim();
    if (line.length === 0) {
      continue;
    }
    try {
      envelopes.push(parseA2uiEnvelope(line));
    } catch (parseError) {
      error = parseError instanceof Error ? parseError.message : 'invalid A2UI stream line';
      break;
    }
  }

  return {
    envelopes: envelopes,
    remainder: hasTrailingNewline ? '' : lines[lines.length - 1],
    error: error
  };
}

export function parseA2uiJsonl(content: string): A2uiStreamParseResult {
  const result = parseA2uiJsonlChunk(content.endsWith('\n') ? content : content + '\n', '');
  return {
    envelopes: result.envelopes,
    remainder: '',
    error: result.error
  };
}
