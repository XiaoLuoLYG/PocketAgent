import {
  A2UI_VERSION,
  A2uiComponent,
  A2uiDataValue,
  A2uiEnvelope
} from './A2uiTypes';

export interface A2uiPartialDataPatch {
  path: string;
  value: A2uiDataValue;
  signature: string;
}

export interface A2uiPartialRenderState {
  surfaceId: string;
  root: string;
  title: string;
  intent: string;
  status: string;
  sendDataModel: boolean;
  components: A2uiComponent[];
  componentsSignature: string;
  dataPatches: A2uiPartialDataPatch[];
}

export interface A2uiPartialDataSignature {
  path: string;
  signature: string;
}

export interface A2uiPartialUpdateCache {
  surfaceId: string;
  root: string;
  title: string;
  intent: string;
  status: string;
  componentsSignature: string;
  dataSignatures: A2uiPartialDataSignature[];
}

export interface A2uiPartialUpdateResult {
  jsonl: string;
  cache: A2uiPartialUpdateCache;
  emittedEnvelopeCount: number;
  surfaceCreated: boolean;
  componentsUpdated: boolean;
  updatedDataPaths: string[];
}

function a2uiPartialLine(envelope: A2uiEnvelope): string {
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

function a2uiPartialJsonl(envelopes: A2uiEnvelope[]): string {
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    jsonl += a2uiPartialLine(envelope);
  });
  return jsonl;
}

function dataSignatureFor(cache: A2uiPartialUpdateCache | null, path: string): string {
  if (cache === null) {
    return '';
  }
  for (let index = 0; index < cache.dataSignatures.length; index++) {
    const entry = cache.dataSignatures[index];
    if (entry.path === path) {
      return entry.signature;
    }
  }
  return '';
}

function cacheFor(state: A2uiPartialRenderState): A2uiPartialUpdateCache {
  const dataSignatures: A2uiPartialDataSignature[] = [];
  state.dataPatches.forEach((patch: A2uiPartialDataPatch) => {
    dataSignatures.push({
      path: patch.path,
      signature: patch.signature
    });
  });
  return {
    surfaceId: state.surfaceId,
    root: state.root,
    title: state.title,
    intent: state.intent,
    status: state.status,
    componentsSignature: state.componentsSignature,
    dataSignatures: dataSignatures
  };
}

function needsSurfaceEnvelope(previous: A2uiPartialUpdateCache | null, next: A2uiPartialRenderState): boolean {
  if (previous === null) {
    return true;
  }
  return previous.surfaceId !== next.surfaceId ||
    previous.root !== next.root ||
    previous.title !== next.title ||
    previous.intent !== next.intent ||
    previous.status !== next.status;
}

function needsComponentsEnvelope(previous: A2uiPartialUpdateCache | null, next: A2uiPartialRenderState): boolean {
  if (previous === null) {
    return true;
  }
  return previous.componentsSignature !== next.componentsSignature ||
    previous.status !== next.status;
}

export function planA2uiPartialUpdate(previous: A2uiPartialUpdateCache | null, next: A2uiPartialRenderState): A2uiPartialUpdateResult {
  const envelopes: A2uiEnvelope[] = [];
  const updatedDataPaths: string[] = [];
  const surfaceCreated = needsSurfaceEnvelope(previous, next);
  const componentsUpdated = needsComponentsEnvelope(previous, next);

  if (surfaceCreated) {
    envelopes.push({
      createSurface: {
        surfaceId: next.surfaceId,
        root: next.root,
        title: next.title,
        intent: next.intent,
        status: next.status,
        sendDataModel: next.sendDataModel
      }
    });
  }

  if (componentsUpdated) {
    envelopes.push({
      updateComponents: {
        surfaceId: next.surfaceId,
        components: next.components
      }
    });
  }

  next.dataPatches.forEach((patch: A2uiPartialDataPatch) => {
    if (dataSignatureFor(previous, patch.path) !== patch.signature) {
      envelopes.push({
        updateDataModel: {
          surfaceId: next.surfaceId,
          path: patch.path,
          value: patch.value
        }
      });
      updatedDataPaths.push(patch.path);
    }
  });

  return {
    jsonl: a2uiPartialJsonl(envelopes),
    cache: cacheFor(next),
    emittedEnvelopeCount: envelopes.length,
    surfaceCreated: surfaceCreated,
    componentsUpdated: componentsUpdated,
    updatedDataPaths: updatedDataPaths
  };
}
