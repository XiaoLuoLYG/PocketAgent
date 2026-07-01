import { describe, it, expect } from '@ohos/hypium';
import {
  isBuiltInToolId,
  isRunnableRemoteTransport,
  isUnsafeMcpTool,
  normalizeModelScopeMcpDetail,
  selectBestRemoteTransport,
  DynamicToolRegistry
} from '../main/ets/model/DynamicToolRegistry';
import { DynamicToolManifest, DynamicToolRegistration, DynamicToolTransport, ModelScopeMcpDetail } from '../main/ets/model/DynamicToolTypes';

function amapDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"高德地图","Name":"amap-maps","Path":"@amap","Hosted":true,' +
      '"FromSiteUrl":"https://www.npmjs.com/package/@amap/amap-maps-mcp-server",' +
      '"EnvSchema":{"type":"object","required":["AMAP_MAPS_API_KEY"],"properties":{"AMAP_MAPS_API_KEY":{"type":"string","description":"您在高德官网上申请的key","test_value":"1"}}},' +
      '"ServerConfig":[{"mcpServers":{"amap-maps":{"command":"npx","args":["-y","@amap/amap-maps-mcp-server"],"env":{"AMAP_MAPS_API_KEY":""}}}}],' +
      '"SSEServerConfig":null,"StreamableHTTPServerConfig":null,"SupportedDeployTransportType":["streamable_http","sse"],' +
      '"Tools":[{"name":"maps_weather","description":"根据城市名称查询天气","inputSchema":{"type":"object","required":["city"],"properties":{"city":{"type":"string"}}}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function cnbsDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"中国国家统计局数据查询","Name":"cnbs","Path":"thatcoder","Hosted":true,' +
      '"FromSiteUrl":"https://github.com/icen-ai/mcp-cnbs",' +
      '"EnvSchema":{"type":"object","required":[],"properties":{"MCP_CNBS_AUTH_TOKEN":{"type":"string","description":"鉴权TOKEN, 可空走魔搭鉴权","test_value":"1"}}},' +
      '"ServerConfig":[],' +
      '"SSEServerConfig":[{"mcpServers":{"cnbs":{"type":"sse","url":"https://cnbs.mcp.icen.ai/sse","headers":{"Authorization":"Bearer your-secret-token","X-Trace":"cnbs-fixture"}}}}],' +
      '"StreamableHTTPServerConfig":[{"mcpServers":{"cnbs":{"type":"streamable_http","url":"https://cnbs.mcp.icen.ai","headers":{"Authorization":"Bearer your-secret-token","X-Trace":"cnbs-fixture"}}}}],' +
      '"SupportedDeployTransportType":["streamable_http","sse"],' +
      '"Tools":[{"name":"cnbs_search","description":"Search statistics","inputSchema":{"type":"object","required":["query"],"properties":{"query":{"type":"string"}}}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function emptyHttpWithSseDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"空 HTTP 但可 SSE","Name":"empty-http","Path":"fixture","Hosted":true,' +
      '"EnvSchema":{"type":"object","required":[],"properties":{}},' +
      '"ServerConfig":[],' +
      '"SSEServerConfig":[{"mcpServers":{"fixture":{"type":"sse","url":"https://example.test/sse","headers":{"X-Trace":"fixture"}}}}],' +
      '"StreamableHTTPServerConfig":[{"mcpServers":{"fixture":{"type":"streamable_http","url":"   ","headers":{"X-Trace":"fixture"}}}}],' +
      '"SupportedDeployTransportType":["streamable_http","sse"],' +
      '"Tools":[{"name":"fixture_search","description":"Search fixture","inputSchema":{"type":"object"}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function emptyHttpOnlyDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"空 HTTP","Name":"empty-http-only","Path":"fixture","Hosted":true,' +
      '"EnvSchema":{"type":"object","required":[],"properties":{}},' +
      '"ServerConfig":[],"SSEServerConfig":[],' +
      '"StreamableHTTPServerConfig":[{"mcpServers":{"fixture":{"type":"streamable_http","url":"","headers":{"X-Trace":"fixture"}}}}],' +
      '"SupportedDeployTransportType":["streamable_http"],' +
      '"Tools":[{"name":"fixture_search","description":"Search fixture","inputSchema":{"type":"object"}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function requiredCredentialRemoteDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"需要鉴权","Name":"needs-auth","Path":"fixture","Hosted":true,' +
      '"EnvSchema":{"type":"object","required":["REQUIRED_TOKEN"],"properties":{"REQUIRED_TOKEN":{"type":"string","description":"Required token","test_value":"1"}}},' +
      '"ServerConfig":[],"SSEServerConfig":[],' +
      '"StreamableHTTPServerConfig":[{"mcpServers":{"fixture":{"type":"streamable_http","url":"https://example.test/mcp","headers":{"X-Trace":"fixture"}}}}],' +
      '"SupportedDeployTransportType":["streamable_http"],' +
      '"Tools":[{"name":"fixture_search","description":"Search fixture","inputSchema":{"type":"object"}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function unsupportedTransportDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"只支持 stdio","Name":"stdio-only","Path":"fixture","Hosted":true,' +
      '"EnvSchema":{"type":"object","required":[],"properties":{}},' +
      '"ServerConfig":[{"mcpServers":{"fixture":{"command":"npx","args":["-y","fixture-mcp"],"env":{}}}}],' +
      '"SSEServerConfig":[],"StreamableHTTPServerConfig":[],' +
      '"SupportedDeployTransportType":["stdio"],' +
      '"Tools":[{"name":"fixture_search","description":"Search fixture","inputSchema":{"type":"object"}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

function unsafeRemoteDetail(): ModelScopeMcpDetail {
  const raw =
    '{"ChineseName":"危险动作","Name":"unsafe","Path":"fixture","Hosted":true,' +
      '"EnvSchema":{"type":"object","required":[],"properties":{}},' +
      '"ServerConfig":[],"SSEServerConfig":[],' +
      '"StreamableHTTPServerConfig":[{"mcpServers":{"fixture":{"type":"streamable_http","url":"https://example.test/mcp","headers":{"X-Trace":"fixture"}}}}],' +
      '"SupportedDeployTransportType":["streamable_http"],' +
      '"Tools":[{"name":"book_ticket","description":"Book a ticket","inputSchema":{"type":"object"}}]}';
  return JSON.parse(raw) as ModelScopeMcpDetail;
}

export default function dynamicToolRegistryTest() {
  describe('dynamicToolRegistry', () => {
    it('keeps current built-in tools recognized', 0, () => {
      expect(isBuiltInToolId('travel.search')).assertTrue();
      expect(isBuiltInToolId('train.search')).assertTrue();
      expect(isBuiltInToolId('flight.search')).assertTrue();
      expect(isBuiltInToolId('food.search')).assertTrue();
      expect(isBuiltInToolId('social.reply.send')).assertFalse();
      expect(isBuiltInToolId('social.feed.search')).assertFalse();
      expect(isBuiltInToolId('ferry.ticket.search')).assertFalse();
    });

    it('normalizes ModelScope detail into a dynamic manifest', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(amapDetail(), 'https://modelscope.cn/mcp/servers/%40amap/amap-maps');

      expect(manifest.id).assertEqual('modelscope.@amap.amap-maps');
      expect(manifest.displayName).assertEqual('高德地图');
      expect(manifest.requiredCredentials[0].name).assertEqual('AMAP_MAPS_API_KEY');
      expect(manifest.tools[0].name).assertEqual('maps_weather');
      expect(manifest.transports[0].type).assertEqual('stdio');
    });

    it('selects streamable_http before sse and ignores stdio for HAP runtime', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(cnbsDetail(), 'https://modelscope.cn/mcp/servers/thatcoder/cnbs');
      const transport = selectBestRemoteTransport(manifest);

      expect(transport === null).assertFalse();
      expect((transport as DynamicToolTransport).type).assertEqual('streamable_http');
      expect(Object.keys((transport as DynamicToolTransport).headers).indexOf('Authorization')).assertEqual(-1);
      expect((transport as DynamicToolTransport).headers['X-Trace']).assertEqual('cnbs-fixture');
      expect(isRunnableRemoteTransport('streamable_http')).assertTrue();
      expect(isRunnableRemoteTransport('sse')).assertTrue();
      expect(isRunnableRemoteTransport('http_api')).assertTrue();
      expect(isRunnableRemoteTransport('stdio')).assertFalse();
    });

    it('ignores streamable_http transports with empty endpoint URLs', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(emptyHttpWithSseDetail(), 'memory:empty-http-with-sse');
      const transport = selectBestRemoteTransport(manifest);

      expect(transport === null).assertFalse();
      expect((transport as DynamicToolTransport).type).assertEqual('sse');
      expect((transport as DynamicToolTransport).url).assertEqual('https://example.test/sse');
    });

    it('returns null when no remote transport has an endpoint URL', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(emptyHttpOnlyDetail(), 'memory:empty-http-only');
      const transport = selectBestRemoteTransport(manifest);

      expect(transport === null).assertTrue();
    });

    it('detects unsafe transaction-like tools', 0, () => {
      expect(isUnsafeMcpTool('book_ticket', 'Book and pay for a ticket')).assertTrue();
      expect(isUnsafeMcpTool('create_order', 'Create order')).assertTrue();
      expect(isUnsafeMcpTool('maps_weather', 'Query weather')).assertFalse();
    });

    it('stores dynamic registry entries by model-facing alias', 0, () => {
      const manifest: DynamicToolManifest = normalizeModelScopeMcpDetail(cnbsDetail(), 'https://modelscope.cn/mcp/servers/thatcoder/cnbs');
      const registry = new DynamicToolRegistry();

      const registration = registry.enableAlias('statistics.search', manifest, 'cnbs_search', 'memory:cnbs');

      expect(registration.status).assertEqual('candidate');
      expect(registry.canHandleToolId('statistics.search')).assertFalse();
      expect(registry.canHandleToolId('cnbs_search')).assertFalse();
      expect(registry.registrationForToolId('statistics.search')?.mcpToolName).assertEqual('cnbs_search');

      registration.status = 'enabled';
      expect(registry.canHandleToolId('statistics.search')).assertFalse();

      const storedBeforeSet = registry.registrationForToolId('statistics.search') as DynamicToolRegistration;
      storedBeforeSet.status = 'enabled';
      storedBeforeSet.transport.url = 'https://mutated.example.test';
      expect(registry.canHandleToolId('statistics.search')).assertFalse();
      expect((registry.registrationForToolId('statistics.search') as DynamicToolRegistration).transport.url)
        .assertEqual('https://cnbs.mcp.icen.ai');

      const allRegistrations = registry.allRegistrations();
      allRegistrations[0].status = 'enabled';
      allRegistrations[0].transport.url = 'https://mutated-list.example.test';
      expect(registry.canHandleToolId('statistics.search')).assertFalse();
      expect((registry.allRegistrations()[0]).transport.url).assertEqual('https://cnbs.mcp.icen.ai');

      registry.setRegistration(registration);
      expect(registry.canHandleToolId('statistics.search')).assertTrue();
    });

    it('keeps missing-credential aliases out of the runnable registry', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(requiredCredentialRemoteDetail(), 'memory:needs-auth');
      const registry = new DynamicToolRegistry();
      const registration = registry.enableAlias('needs.auth', manifest, 'fixture_search', '');

      expect(registration.status).assertEqual('needs_auth');
      expect(registry.canHandleToolId('needs.auth')).assertFalse();
    });

    it('keeps unsupported-transport aliases out of the runnable registry', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(unsupportedTransportDetail(), 'memory:stdio-only');
      const registry = new DynamicToolRegistry();
      const registration = registry.enableAlias('stdio.search', manifest, 'fixture_search', 'memory:stdio');

      expect(registration.status).assertEqual('unsupported_transport');
      expect(registry.canHandleToolId('stdio.search')).assertFalse();
    });

    it('keeps unsafe-tool aliases out of the runnable registry', 0, () => {
      const manifest = normalizeModelScopeMcpDetail(unsafeRemoteDetail(), 'memory:unsafe');
      const registry = new DynamicToolRegistry();
      const registration = registry.enableAlias('ticket.book', manifest, 'book_ticket', 'memory:unsafe');

      expect(registration.status).assertEqual('unsafe_action_blocked');
      expect(registry.canHandleToolId('ticket.book')).assertFalse();
    });
  });
}
