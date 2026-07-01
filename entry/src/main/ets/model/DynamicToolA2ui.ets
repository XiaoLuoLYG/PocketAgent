import {
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_VERSION,
  A2uiAction,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiEnvelope,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiSummaryData
} from './A2uiTypes';
import { credentialRefFor } from './DynamicCredentialStore';
import { DynamicCredentialSpec, DynamicGenericToolResult, DynamicToolManifest } from './DynamicToolTypes';

function envelopeWithVersion(envelope: A2uiEnvelope): A2uiEnvelope {
  const versioned: A2uiEnvelope = {
    version: A2UI_VERSION
  };
  if (envelope.createSurface !== undefined && envelope.createSurface !== null) {
    versioned.createSurface = envelope.createSurface;
  }
  if (envelope.updateComponents !== undefined && envelope.updateComponents !== null) {
    versioned.updateComponents = envelope.updateComponents;
  }
  if (envelope.updateDataModel !== undefined && envelope.updateDataModel !== null) {
    versioned.updateDataModel = envelope.updateDataModel;
  }
  if (envelope.deleteSurface !== undefined && envelope.deleteSurface !== null) {
    versioned.deleteSurface = envelope.deleteSurface;
  }
  return versioned;
}

function a2uiLine(envelope: A2uiEnvelope): string {
  return JSON.stringify(envelopeWithVersion(envelope)) + '\n';
}

function a2uiJsonl(envelopes: A2uiEnvelope[]): string {
  let jsonl = '';
  envelopes.forEach((envelope: A2uiEnvelope) => jsonl += a2uiLine(envelope));
  return jsonl;
}

function emptyCredentialSpec(): DynamicCredentialSpec {
  return {
    name: '',
    description: '',
    required: false,
    placement: 'header',
    scheme: '',
    testValue: ''
  };
}

function fallbackCredentialSpec(fallbackName: string): DynamicCredentialSpec {
  return {
    name: fallbackName.length > 0 ? fallbackName : 'Authorization',
    description: 'Credential required by remote MCP server',
    required: true,
    placement: 'header',
    scheme: 'Bearer',
    testValue: ''
  };
}

function firstCredential(manifest: DynamicToolManifest, fallbackName: string = ''): DynamicCredentialSpec {
  if (manifest.requiredCredentials.length > 0) {
    return manifest.requiredCredentials[0];
  }
  if (fallbackName.length === 0) {
    return emptyCredentialSpec();
  }
  return fallbackCredentialSpec(fallbackName);
}

function credentialForConnectCard(manifest: DynamicToolManifest, status: string): DynamicCredentialSpec {
  return status === 'needs_auth' ? firstCredential(manifest, 'Authorization') : firstCredential(manifest, '');
}

function connectActions(manifest: DynamicToolManifest): A2uiAction[] {
  const actions: A2uiAction[] = [];
  if (manifest.fromSiteUrl.length > 0) {
    actions.push({
      id: 'dynamic_open_registration',
      label: '打开注册页',
      prompt: manifest.fromSiteUrl,
      kind: 'client',
      variant: 'secondary'
    });
  }
  actions.push({
    id: 'dynamic_test_connection',
    label: '测试连接',
    prompt: '测试动态工具连接',
    kind: 'client',
    variant: 'primary'
  });
  actions.push({
    id: 'dynamic_disable_tool',
    label: '暂不启用',
    prompt: '暂不启用该工具',
    kind: 'client',
    variant: 'secondary'
  });
  return actions;
}

function connectComponents(manifest: DynamicToolManifest, status: string, message: string, actions: A2uiAction[]): A2uiComponent[] {
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'connect',
    title: '接入工具：' + manifest.displayName,
    status: 'needs_input'
  };
  const connect: A2uiComponent = {
    id: 'connect',
    component: A2UI_COMPONENT_TOOL_CONNECT_CARD,
    title: '接入工具：' + manifest.displayName,
    body: message,
    status: status,
    dataPath: '/dynamicToolConnect',
    actions: actions
  };
  return [root, connect];
}

export function connectCardA2ui(
  surfaceId: string,
  toolId: string,
  manifest: DynamicToolManifest,
  status: string,
  message: string,
  prompt: string = ''
): string {
  const credential = credentialForConnectCard(manifest, status);
  const credentialRef = credential.name.length > 0 ? credentialRefFor(manifest.id, credential.name) : '';
  const actions = connectActions(manifest);
  const connectData: A2uiDynamicToolConnectData = {
    toolId: toolId,
    prompt: prompt,
    manifestId: manifest.id,
    displayName: manifest.displayName,
    sourceUrl: manifest.sourceUrl,
    status: status,
    message: message,
    credentialName: credential.name,
    credentialRef: credentialRef,
    registrationUrl: manifest.fromSiteUrl,
    actions: actions
  };
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: '接入工具：' + manifest.displayName,
        intent: 'dynamic_tool',
        status: 'needs_input',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: connectComponents(manifest, status, message, actions)
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/dynamicToolConnect',
        value: connectData
      }
    }
  ];
  return a2uiJsonl(envelopes);
}

export function unsupportedTransportA2ui(surfaceId: string, toolId: string, manifest: DynamicToolManifest, prompt: string = ''): string {
  return connectCardA2ui(surfaceId, toolId, manifest, 'unsupported_transport', '该候选工具只提供本地命令型配置，当前鸿蒙 HAP 不会执行 npx、uvx 或 stdio 工具。', prompt);
}

function rowsOf(result: DynamicGenericToolResult): A2uiLabelValueData[] {
  return result.rows.map((row: A2uiLabelValueData): A2uiLabelValueData => {
    const copy: A2uiLabelValueData = {
      label: row.label,
      value: row.value
    };
    return copy;
  });
}

function resultOf(result: DynamicGenericToolResult): A2uiGenericToolResultData {
  return {
    sourceTag: result.sourceTag,
    toolName: result.toolName,
    title: result.title,
    status: result.status,
    summary: result.summary,
    rows: rowsOf(result),
    rawPreview: result.rawPreview
  };
}

function genericResultTitle(toolId: string): string {
  return toolId.indexOf('calendar.') === 0 ? 'Google Calendar' : '动态工具结果';
}

function genericResultComponents(toolId: string): A2uiComponent[] {
  const title = genericResultTitle(toolId);
  const retryAction: A2uiAction = {
    id: 'dynamic_retry',
    label: '重新查询',
    prompt: '重新调用动态工具 ' + toolId,
    kind: 'prompt',
    variant: 'primary'
  };
  const root: A2uiComponent = {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    child: 'results',
    title: title,
    status: 'ready'
  };
  const results: A2uiComponent = {
    id: 'results',
    component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
    title: title,
    body: '以下只展示 MCP tools/call 的真实返回或真实错误。',
    status: 'ready',
    dataPath: '/genericToolResults',
    actions: [retryAction]
  };
  return [root, results];
}

export function genericToolResultsA2ui(surfaceId: string, toolId: string, results: DynamicGenericToolResult[]): string {
  const title = genericResultTitle(toolId);
  const a2uiResults: A2uiGenericToolResultData[] = results.map((result: DynamicGenericToolResult): A2uiGenericToolResultData => resultOf(result));
  const summary: A2uiSummaryData = {
    text: a2uiResults.length > 0 ? a2uiResults[0].summary : '动态工具没有返回可展示结果。',
    toolName: toolId,
    dataLabel: 'genericToolResults',
    count: a2uiResults.length
  };
  const envelopes: A2uiEnvelope[] = [
    {
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: title,
        intent: 'dynamic_tool',
        status: 'ready',
        sendDataModel: true
      }
    },
    {
      updateComponents: {
        surfaceId: surfaceId,
        components: genericResultComponents(toolId)
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/genericToolResults',
        value: a2uiResults
      }
    },
    {
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: summary
      }
    }
  ];
  return a2uiJsonl(envelopes);
}
