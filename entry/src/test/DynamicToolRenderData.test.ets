import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiComponent,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiDynamicToolConnectData,
  A2uiGenericToolResultData
} from '../main/ets/model/A2uiTypes';
import { dynamicToolConnect, genericToolResults } from '../main/ets/model/A2uiData';
import { emptySocialHub } from '../main/ets/model/SocialHubTypes';

function baseModel(): A2uiRuntimeDataModel {
  return {
    rows: [],
    trains: [],
    flights: [],
    travelOptions: [],
    foods: [],
    thoughts: [],
    summary: { text: '', toolName: '', dataLabel: '', count: 0 },
    trip: { rows: [] },
    rowGroups: { train: [], flight: [], food: [] },
    form: {},
    toolRequest: { toolId: '', prompt: '', actionId: '' },
    dynamicToolConnect: {
      toolId: 'maps.weather',
      prompt: '帮我查明天深圳天气',
      manifestId: 'modelscope.@amap.amap-maps',
      displayName: 'Amap Maps',
      sourceUrl: 'https://modelscope.cn/mcp/servers/%40amap/amap-maps',
      status: 'needs_auth',
      message: 'API key required',
      credentialName: 'AMAP_MAPS_API_KEY',
      credentialRef: 'dynamic:modelscope.@amap.amap-maps:AMAP_MAPS_API_KEY',
      registrationUrl: 'https://lbs.amap.com/',
      actions: []
    },
    genericToolResults: [
      {
        sourceTag: 'MCP · fixture',
        toolName: 'fixture.search',
        title: 'Fixture result',
        status: 'success',
        summary: 'One real fixture row returned.',
        rows: [{ label: 'Result', value: 'Fixture row' }],
        rawPreview: '{"ok":true}'
      }
    ],
    socialHub: emptySocialHub()
  };
}

function surface(model: A2uiRuntimeDataModel): A2uiSurfaceState {
  const components: A2uiComponent[] = [];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: 'dynamic',
    intent: 'dynamic_tool',
    status: 'ready',
    components: components,
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

export default function dynamicToolRenderDataTest() {
  describe('dynamicToolRenderData', () => {
    it('reads dynamic connect data from the runtime model', 0, () => {
      const data: A2uiDynamicToolConnectData = dynamicToolConnect(surface(baseModel()));

      expect(data.toolId).assertEqual('maps.weather');
      expect(data.prompt).assertEqual('帮我查明天深圳天气');
      expect(data.status).assertEqual('needs_auth');
      expect(data.credentialName).assertEqual('AMAP_MAPS_API_KEY');
      expect(data.credentialRef).assertEqual('dynamic:modelscope.@amap.amap-maps:AMAP_MAPS_API_KEY');
    });

    it('reads generic tool results from the runtime model', 0, () => {
      const results: A2uiGenericToolResultData[] = genericToolResults(surface(baseModel()));

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('MCP · fixture');
      expect(results[0].rows[0].value).assertEqual('Fixture row');
    });
  });
}
