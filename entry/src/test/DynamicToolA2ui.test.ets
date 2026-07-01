import { describe, it, expect } from '@ohos/hypium';
import { parseA2uiJsonl } from '../main/ets/model/A2uiParser';
import {
  connectCardA2ui,
  genericToolResultsA2ui,
  unsupportedTransportA2ui
} from '../main/ets/model/DynamicToolA2ui';
import { DynamicGenericToolResult, DynamicToolManifest } from '../main/ets/model/DynamicToolTypes';

function manifest(): DynamicToolManifest {
  return {
    id: 'modelscope.@amap.amap-maps',
    displayName: '高德地图',
    sourceUrl: 'https://modelscope.cn/mcp/servers/%40amap/amap-maps',
    hosted: true,
    fromSiteUrl: 'https://lbs.amap.com/',
    capabilities: ['location-services'],
    requiredCredentials: [{
      name: 'AMAP_MAPS_API_KEY',
      description: '您在高德官网上申请的key',
      required: true,
      placement: 'env',
      scheme: '',
      testValue: '1'
    }],
    transports: [],
    tools: [{ name: 'maps_weather', description: '天气', inputSchema: new Object() }]
  };
}

function genericResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'CNBS',
    toolName: 'cnbs_search',
    title: '统计查询',
    status: 'success',
    summary: '真实工具返回',
    rows: [{ label: '指标', value: 'GDP' }],
    rawPreview: '{"metric":"GDP"}'
  };
}

export default function dynamicToolA2uiTest() {
  describe('dynamicToolA2ui', () => {
    it('builds a connect card surface', 0, () => {
      const parsed = parseA2uiJsonl(connectCardA2ui('surface_model', 'maps.weather', manifest(), 'needs_auth', 'API key required', '帮我查明天深圳天气'));
      const serialized = JSON.stringify(parsed.envelopes);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertLarger(2);
      expect(serialized.indexOf('ToolConnectCard')).assertLarger(-1);
      expect(serialized.indexOf('/dynamicToolConnect')).assertLarger(-1);
      expect(serialized.indexOf('dynamic:modelscope.@amap.amap-maps:AMAP_MAPS_API_KEY')).assertLarger(-1);
      expect(serialized.indexOf('帮我查明天深圳天气')).assertLarger(-1);
    });

    it('builds an unsupported transport surface', 0, () => {
      const parsed = parseA2uiJsonl(unsupportedTransportA2ui('surface_model', 'weather.query', manifest()));

      expect(parsed.error).assertEqual('');
      expect(JSON.stringify(parsed.envelopes).indexOf('unsupported_transport')).assertLarger(-1);
    });

    it('builds generic result surface', 0, () => {
      const results: DynamicGenericToolResult[] = [genericResult()];
      const parsed = parseA2uiJsonl(genericToolResultsA2ui('surface_model', 'statistics.search', results));
      const serialized = JSON.stringify(parsed.envelopes);

      expect(parsed.error).assertEqual('');
      expect(serialized.indexOf('GenericToolResults')).assertLarger(-1);
      expect(serialized.indexOf('/genericToolResults')).assertLarger(-1);
      expect(serialized.indexOf('动态工具结果')).assertLarger(-1);
      expect(serialized.indexOf('真实工具返回')).assertLarger(-1);
    });

    it('uses a Calendar surface title for Calendar generic results', 0, () => {
      const parsed = parseA2uiJsonl(genericToolResultsA2ui('surface_model', 'calendar.events.search', [genericResult()]));
      const serialized = JSON.stringify(parsed.envelopes);

      expect(parsed.error).assertEqual('');
      expect(serialized.indexOf('"title":"Google Calendar"')).assertLarger(-1);
      expect(serialized.indexOf('"title":"动态工具结果"')).assertEqual(-1);
    });
  });
}
