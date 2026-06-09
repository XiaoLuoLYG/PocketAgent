import {
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiApplyResult,
  A2uiComponent,
  A2uiDataValue,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiEnvelope,
  A2uiRuntimeDataModel,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiToolRequestData,
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
    foods: [],
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
    toolRequest: {
      toolId: '',
      prompt: '',
      actionId: ''
    }
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
      foods: Array.isArray(parsed.foods) ? parsed.foods : fallback.foods,
      thoughts: Array.isArray(parsed.thoughts) ? parsed.thoughts : fallback.thoughts,
      summary: parsed.summary === undefined || parsed.summary === null ? fallback.summary : parsed.summary,
      trip: parsed.trip === undefined || parsed.trip === null ? fallback.trip : {
        rows: Array.isArray(parsed.trip.rows) ? parsed.trip.rows : fallback.trip.rows
      },
      toolRequest: parsed.toolRequest === undefined || parsed.toolRequest === null ? fallback.toolRequest : parsed.toolRequest
    };
  } catch (_error) {
    return fallback;
  }
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
  } else if (path === '/foods') {
    next.foods = value as A2uiFoodData[];
  } else if (path === '/thoughts') {
    next.thoughts = value as string[];
  } else if (path === '/summary') {
    next.summary = value as A2uiSummaryData;
  } else if (path === '/trip') {
    next.trip = value as A2uiTripData;
  } else if (path === '/trip/rows') {
    next.trip.rows = value as A2uiLabelValueData[];
  } else if (path === '/toolRequest') {
    next.toolRequest = value as A2uiToolRequestData;
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

  apply(envelope: A2uiEnvelope): A2uiApplyResult {
    try {
      if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
        this.surface = {
          surfaceId: envelope.createSurface.surfaceId,
          rootId: envelope.createSurface.root === undefined || envelope.createSurface.root.length === 0 ? 'root' : envelope.createSurface.root,
          title: envelope.createSurface.title === undefined || envelope.createSurface.title.length === 0 ? 'AIPhone' : envelope.createSurface.title,
          intent: envelope.createSurface.intent === undefined || envelope.createSurface.intent.length === 0 ? 'general' : envelope.createSurface.intent,
          status: envelope.createSurface.status === undefined || envelope.createSurface.status.length === 0 ? 'thinking' : envelope.createSurface.status,
          components: [],
          dataModelJson: JSON.stringify(emptyDataModel()),
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
      this.applyError('A2UI 渲染失败', message);
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
      title: 'AIPhone',
      intent: 'general',
      status: 'idle',
      sendDataModel: true
    }
  });
  store.apply({
    version: 'v0.9.1',
    updateComponents: {
      surfaceId: 'surface_seed',
      components: [
        {
          id: 'root',
          component: A2UI_COMPONENT_SURFACE_ROOT,
          child: 'intro',
          title: 'AIPhone',
          body: '原生生成式任务画布',
          status: 'idle'
        },
        {
          id: 'intro',
          component: A2UI_COMPONENT_INFO_ROWS,
          title: '把一句话变成可执行界面',
          body: '告诉 AIPhone 你要安排的事，我会生成任务画布，并在需要时调用本地工具。',
          status: 'idle',
          dataPath: '/rows',
          actions: [
            {
              id: 'seed_train',
              label: '查高铁',
              prompt: '帮我查询明天北京到上海高铁票',
              variant: 'primary'
            },
            {
              id: 'seed_flight',
              label: '查航班',
              prompt: '帮我查询明天北京到上海航班',
              variant: 'secondary'
            },
            {
              id: 'seed_food',
              label: '找餐厅',
              prompt: '帮我查询北京王府井附近餐厅',
              variant: 'secondary'
            }
          ]
        }
      ]
    }
  });
  store.apply({
    version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_seed',
        path: '/rows',
        value: [
          { label: '可查询', value: '高铁 / 航班 / 附近餐饮' },
          { label: '输入', value: '告诉我城市、日期或位置' }
      ]
    }
  });
  return store.getSurface();
}
