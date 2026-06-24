import { DynamicToolManifest, DynamicToolTransport } from './DynamicToolTypes';

export interface DynamicToolSampleRecord {
  toolIds: string[];
  manifest: DynamicToolManifest;
}

interface DynamicToolSampleFile {
  manifests: DynamicToolSampleRecord[];
}

const DEFAULT_DYNAMIC_TOOL_SAMPLES_JSON: string = '{"manifests":[{"toolIds":["fixture.echo"],"manifest":{"id":"modelscope.fixture.echo","displayName":"Fixture Echo MCP","sourceUrl":"local-fixture","hosted":true,"fromSiteUrl":"","capabilities":["test.echo"],"requiredCredentials":[],"transports":[{"type":"streamable_http","url":"https://fixture.invalid/mcp","command":"","args":[],"headers":{},"env":{}}],"tools":[{"name":"echo","description":"Return a deterministic echo result.","inputSchema":{"type":"object","required":["query"],"properties":{"query":{"type":"string"}}}}]}},{"toolIds":["weather.query","maps.weather"],"manifest":{"id":"modelscope.@amap.amap-maps","displayName":"高德地图","sourceUrl":"https://modelscope.cn/mcp/servers/%40amap/amap-maps","hosted":true,"fromSiteUrl":"https://lbs.amap.com/api/mcp-server/gettingstarted","capabilities":["location-services","weather.query","route.plan"],"requiredCredentials":[{"name":"AMAP_MAPS_API_KEY","description":"您在高德官网上申请的key","required":true,"placement":"env","scheme":"","testValue":"1"}],"transports":[{"type":"stdio","url":"","command":"npx","args":["-y","@amap/amap-maps-mcp-server"],"headers":{},"env":{"AMAP_MAPS_API_KEY":""}}],"tools":[{"name":"maps_weather","description":"根据城市名称或 adcode 查询天气","inputSchema":{"type":"object","required":["city"],"properties":{"city":{"type":"string"}}}}]}},{"toolIds":["statistics.search"],"manifest":{"id":"modelscope.thatcoder.cnbs","displayName":"中国国家统计局数据查询","sourceUrl":"https://modelscope.cn/mcp/servers/thatcoder/cnbs","hosted":true,"fromSiteUrl":"https://github.com/icen-ai/mcp-cnbs","capabilities":["research-and-data"],"requiredCredentials":[{"name":"Authorization","description":"Bearer token required by the hosted MCP endpoint","required":false,"placement":"header","scheme":"Bearer","testValue":"1"}],"transports":[{"type":"streamable_http","url":"https://cnbs.mcp.icen.ai","command":"","args":[],"headers":{},"env":{}}],"tools":[{"name":"cnbs_search","description":"Search statistics","inputSchema":{"type":"object","required":["query"],"properties":{"query":{"type":"string"}}}}]}},{"toolIds":["ppt.generate"],"manifest":{"id":"modelscope.@deckflow.gezhe-mcp-server","displayName":"歌者PPT","sourceUrl":"https://modelscope.cn/mcp/servers/%40deckflow/gezhe-mcp-server","hosted":false,"fromSiteUrl":"https://github.com/deckflow/gezhe-ppt-mcp","capabilities":["AIGC"],"requiredCredentials":[{"name":"API_KEY","description":"替换为获取的 API_KEY","required":true,"placement":"env","scheme":"","testValue":"1"}],"transports":[{"type":"stdio","url":"","command":"npx","args":["-y","gezhe-mcp-server"],"headers":{},"env":{"API_KEY":"your-api-key-here"}}],"tools":[]}}]}';

function recordsFromJson(rawJson: string): DynamicToolSampleRecord[] {
  const parsed = JSON.parse(rawJson) as DynamicToolSampleFile;
  return Array.isArray(parsed.manifests) ? parsed.manifests : [];
}

function withRuntimeApiFallbacks(records: DynamicToolSampleRecord[]): DynamicToolSampleRecord[] {
  return records.map((record: DynamicToolSampleRecord): DynamicToolSampleRecord => {
    const manifest = cloneManifest(record.manifest);
    if (manifest.id === 'modelscope.@amap.amap-maps') {
      if (manifest.requiredCredentials.length > 0) {
        manifest.requiredCredentials[0].placement = 'query';
        manifest.requiredCredentials[0].scheme = 'api_key';
      }
      const weatherApiTransport: DynamicToolTransport = {
        type: 'http_api',
        url: 'https://restapi.amap.com/v3/weather/weatherInfo',
        command: '',
        args: [],
        headers: {
          'Accept': 'application/json'
        },
        env: {},
        method: 'GET',
        credentialPlacement: 'query',
        credentialParam: 'key',
        queryParam: 'city',
        fixedQuery: 'extensions=base&output=json',
        forecastQuery: 'extensions=all&output=json'
      };
      manifest.transports = [weatherApiTransport].concat(manifest.transports);
    }
    return {
      toolIds: record.toolIds.slice(),
      manifest: manifest
    };
  });
}

function defaultSampleRecords(): DynamicToolSampleRecord[] {
  return withRuntimeApiFallbacks(recordsFromJson(DEFAULT_DYNAMIC_TOOL_SAMPLES_JSON));
}

function cloneManifest(manifest: DynamicToolManifest): DynamicToolManifest {
  return JSON.parse(JSON.stringify(manifest)) as DynamicToolManifest;
}

let sampleRecords: DynamicToolSampleRecord[] = defaultSampleRecords();

export function configureDynamicToolSamplesFromJson(rawJson: string): void {
  sampleRecords = withRuntimeApiFallbacks(recordsFromJson(rawJson));
}

export function configureDefaultDynamicToolSamplesForTests(): void {
  sampleRecords = defaultSampleRecords();
}

export function sampleManifestForToolId(toolId: string): DynamicToolManifest | null {
  for (let index = 0; index < sampleRecords.length; index++) {
    if (sampleRecords[index].toolIds.indexOf(toolId) >= 0) {
      return cloneManifest(sampleRecords[index].manifest);
    }
  }
  return null;
}

export function sampleManifestIds(): string[] {
  return sampleRecords.map((record: DynamicToolSampleRecord): string => record.manifest.id);
}

export function sampleRecordsForDiscovery(): DynamicToolSampleRecord[] {
  return sampleRecords.map((record: DynamicToolSampleRecord): DynamicToolSampleRecord => {
    return {
      toolIds: record.toolIds.slice(),
      manifest: cloneManifest(record.manifest)
    };
  });
}
