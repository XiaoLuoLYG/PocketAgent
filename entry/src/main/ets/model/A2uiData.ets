import {
  A2uiAction,
  A2uiComponent,
  A2uiDataValue,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTrainData
} from './A2uiTypes';

export type A2uiLabelValue = A2uiLabelValueData;
export type A2uiTrainOption = A2uiTrainData;
export type A2uiFlightOption = A2uiFlightData;
export type A2uiFoodOption = A2uiFoodData;
export type A2uiToolRequest = A2uiToolRequestData;

function emptyModel(): A2uiRuntimeDataModel {
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

function parseModel(surface: A2uiSurfaceState): A2uiRuntimeDataModel {
  const fallback = emptyModel();
  try {
    const parsed = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
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
  if (path === '/foods') {
    return model.foods;
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
  if (path === '/toolRequest') {
    return model.toolRequest;
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
  return [];
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

export function foodOptions(surface: A2uiSurfaceState, component: A2uiComponent): A2uiFoodOption[] {
  const data = resolveData(surface, component.dataPath);
  if (component.dataPath === '/foods') {
    return data as A2uiFoodOption[];
  }
  return [];
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

export function componentById(surface: A2uiSurfaceState, id: string): A2uiComponent | null {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].id === id) {
      return surface.components[index];
    }
  }
  return null;
}
