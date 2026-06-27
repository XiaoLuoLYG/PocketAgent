import { describe, it, expect } from '@ohos/hypium';
import { A2uiCallResult, A2uiFoodData, A2uiLabelValueData, A2uiSurfaceState, A2uiTravelOptionData } from '../main/ets/model/A2uiTypes';
import { genericToolResults, dynamicToolConnect } from '../main/ets/model/A2uiData';
import { planA2uiPartialUpdate, A2uiPartialUpdateResult } from '../main/ets/model/A2uiPartialUpdatePlanner';
import { buildSystemFoodNavigationUri, foodMapsLatLng } from '../main/ets/model/FoodNavigation';
import { MemoryCredentialStore } from '../main/ets/model/DynamicCredentialStore';
import { saveGmailOAuthTokenSet } from '../main/ets/model/GmailOAuthClient';
import { DynamicGenericToolResult, DynamicToolRegistration } from '../main/ets/model/DynamicToolTypes';
import { GenericMcpClient } from '../main/ets/model/GenericMcpClient';
import {
  aggregateFoodProviderResults,
  buildToolGatewayUrl,
  callToolGateway,
  configureGmailCredentialStoreForTests,
  configureGmailMcpClientForTests,
  configureLocalProviderConfigFromRawJson,
  defaultToolGatewayUrl,
  foodA2uiRenderState,
  foodDistanceMeters,
  foodProviderProgressRows,
  foodRecordFromBaiduPlace,
  foodRecordsFromLuckinMcpTool,
  foodRecordsFromMcDonaldsMcpTool,
  foodRecordFromMeituanUnion,
  foodRecordFromTencentMapPlace,
  foodRecordFromTaobaoFlashStore,
  flightRecordForA2ui,
  isReadonlyBrandMcpTool,
  isLocalToolGatewayUrl,
  isRegisteredToolId,
  providerIssueRows,
  sortTravelOptionsByDeparture,
  streamFoodProviderResultsWithPartials,
  FoodProviderPartialSnapshot,
  FoodProviderResult
} from '../main/ets/model/ToolGatewayClient';

class FixtureGmailMcpClient extends GenericMcpClient {
  lastToolName: string = '';
  lastCredential: string = '';
  lastArgs: string = '';

  async callTool(registration: DynamicToolRegistration, credentialValue: string, args: Object): Promise<DynamicGenericToolResult> {
    this.lastToolName = registration.mcpToolName;
    this.lastCredential = credentialValue;
    this.lastArgs = JSON.stringify(args);
    return {
      sourceTag: 'Gmail',
      toolName: registration.mcpToolName,
      title: 'Important launch thread',
      status: 'success',
      summary: 'MCP returned one real Gmail thread.',
      rows: [{ label: 'Thread', value: 'thread-123' }],
      rawPreview: '{"threadId":"thread-123"}'
    };
  }
}

class FailingGmailMcpClient extends GenericMcpClient {
  async callTool(_registration: DynamicToolRegistration, _credentialValue: string, _args: Object): Promise<DynamicGenericToolResult> {
    throw new Error('Operation timeout');
  }
}

class ErrorResultGmailMcpClient extends GenericMcpClient {
  async callTool(registration: DynamicToolRegistration, _credentialValue: string, _args: Object): Promise<DynamicGenericToolResult> {
    return {
      sourceTag: 'Gmail',
      toolName: registration.mcpToolName,
      title: 'Gmail API 调用失败',
      status: 'error',
      summary: 'Missing recipient email address.',
      rows: [{ label: 'Error', value: 'Missing recipient email address.' }],
      rawPreview: 'error=Missing recipient email address.'
    };
  }
}

interface GmailToolArgsFixture {
  query: string;
  pageSize: number;
  intentSummary: string;
}

interface McDonaldsStoreFixture {
  storeName: string;
  address: string;
  distance: string;
  businessStatus: boolean;
  businessStartTime: string;
  businessEndTime: string;
}

interface McDonaldsStoresPayloadFixture {
  data: McDonaldsStoreFixture[];
}

interface McDonaldsMealRefFixture {
  code: string;
  tags: string[];
}

interface McDonaldsCategoryFixture {
  name: string;
  meals: McDonaldsMealRefFixture[];
}

interface McDonaldsMealFixture {
  name: string;
  currentPrice: string;
}

interface McDonaldsMealsByCodeFixture {
  '920215': McDonaldsMealFixture;
}

interface McDonaldsMealsDataFixture {
  categories: McDonaldsCategoryFixture[];
  meals: McDonaldsMealsByCodeFixture;
}

interface McDonaldsMealsPayloadFixture {
  data: McDonaldsMealsDataFixture;
}

interface LuckinShopFixture {
  deptName: string;
  address: string;
  distance: number;
  deptTags: string[];
  longitude: number;
  latitude: number;
}

interface LuckinShopsPayloadFixture {
  data: LuckinShopFixture[];
}

interface LuckinProductSubAttributeFixture {
  attributeName: string;
  selected: boolean;
}

interface LuckinProductAttributeFixture {
  attributeName: string;
  productSubAttrs: LuckinProductSubAttributeFixture[];
}

interface LuckinProductFixture {
  productName: string;
  price: number;
  skuCode: string;
  productAttrs: LuckinProductAttributeFixture[];
  tags: string[];
}

interface LuckinProductsPayloadFixture {
  data: LuckinProductFixture[];
}

export default function toolGatewayClientTest() {
  describe('toolGatewayClient', () => {
    it('defaults to the in-app local tool route', 0, () => {
      expect(defaultToolGatewayUrl()).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(defaultToolGatewayUrl())).assertTrue();
      expect(buildToolGatewayUrl(defaultToolGatewayUrl())).assertEqual('local://aiphone-tools');
    });

    it('still supports explicit HTTP tool gateways', 0, () => {
      expect(isLocalToolGatewayUrl('http://127.0.0.1:8787')).assertFalse();
      expect(buildToolGatewayUrl('http://127.0.0.1:8787')).assertEqual('http://127.0.0.1:8787/api/aiphone/tool');
    });

    it('does not create a tool-specific override for provider tools', 0, () => {
      const endpoint = buildToolGatewayUrl(defaultToolGatewayUrl());
      expect(endpoint).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(endpoint)).assertTrue();
    });

    it('registers unified travel search as a real query tool', 0, () => {
      expect(isRegisteredToolId('travel.search')).assertTrue();
      expect(isRegisteredToolId('train.search')).assertTrue();
      expect(isRegisteredToolId('flight.search')).assertTrue();
      expect(isRegisteredToolId('food.search')).assertTrue();
      expect(isRegisteredToolId('social.reply.send')).assertTrue();
    });

    it('allows only explicit dynamic catalog aliases to enter the local tool host', 0, () => {
      expect(isRegisteredToolId('travel.search')).assertTrue();
      expect(isRegisteredToolId('dynamic.search')).assertTrue();
      expect(isRegisteredToolId('weather.query')).assertTrue();
      expect(isRegisteredToolId('maps.weather')).assertTrue();
      expect(isRegisteredToolId('statistics.search')).assertTrue();
      expect(isRegisteredToolId('ppt.generate')).assertTrue();
      expect(isRegisteredToolId('weather.search')).assertFalse();
      expect(isRegisteredToolId('ferry.ticket.search')).assertFalse();
    });

    it('registers Gmail tools on the same local tool framework without enabling silent send', 0, () => {
      expect(isRegisteredToolId('gmail.mail.search')).assertTrue();
      expect(isRegisteredToolId('gmail.thread.read')).assertTrue();
      expect(isRegisteredToolId('gmail.draft.create')).assertTrue();
      expect(isRegisteredToolId('gmail.draft.apply')).assertTrue();
      expect(isRegisteredToolId('gmail.open.web')).assertTrue();
      expect(isRegisteredToolId('gmail.message.send')).assertTrue();
      expect(isRegisteredToolId('gmail.unknown')).assertFalse();
    });

    it('returns Gmail auth-required, blocked, and open-web A2UI from the local gateway', 0, async () => {
      const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
      const authResult: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'gmail.mail.search',
        '帮我看下 Gmail 最近的重要邮件',
        'surface_gmail_auth',
        'client_intent_fallback',
        noop
      );
      const blockedResult: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'gmail.message.send',
        '帮我 Gmail 直接发送这封邮件',
        'surface_gmail_blocked',
        'client_intent_fallback',
        noop
      );
      const webResult: A2uiCallResult = await callToolGateway(
        defaultToolGatewayUrl(),
        'gmail.open.web',
        '打开 Gmail 网页版',
        'surface_gmail_web',
        'client_intent_fallback',
        noop
      );

      expect(authResult.ok).assertTrue();
      expect(dynamicToolConnect(authResult.surface).toolId).assertEqual('gmail.mail.search');
      expect(dynamicToolConnect(authResult.surface).credentialName).assertEqual('Google Workspace MCP OAuth');
      expect(dynamicToolConnect(authResult.surface).sourceUrl).assertEqual('https://gmailmcp.googleapis.com/mcp/v1');
      expect(dynamicToolConnect(authResult.surface).actions[0].id).assertEqual('gmail.authorize');
      expect(dynamicToolConnect(authResult.surface).actions[1].id).assertEqual('gmail.open.web');
      expect(authResult.raw.indexOf('不会模拟 Gmail 邮件')).assertLarger(-1);

      expect(blockedResult.ok).assertTrue();
      expect(genericToolResults(blockedResult.surface)[0].status).assertEqual('blocked');
      expect(genericToolResults(blockedResult.surface)[0].summary.indexOf('不会自动发送 Gmail')).assertLarger(-1);

      expect(webResult.ok).assertTrue();
      expect(genericToolResults(webResult.surface)[0].toolName).assertEqual('gmail.open.web');
      expect(genericToolResults(webResult.surface)[0].status).assertEqual('needs_user');
      expect(webResult.raw.indexOf('https://mail.google.com/mail/u/0/#inbox')).assertLarger(-1);
    });

    it('builds a Google OAuth authorization URL for Gmail MCP when client config is present', 0, async () => {
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GMAIL_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GMAIL_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google'
        }));

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const authResult: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '帮我看下 Gmail 最近的重要邮件',
          'surface_gmail_auth_with_client',
          'client_intent_fallback',
          noop
        );

        const authAction = dynamicToolConnect(authResult.surface).actions[0];
        expect(authResult.ok).assertTrue();
        expect(authAction.id).assertEqual('gmail.authorize');
        expect(authAction.prompt.indexOf('https://accounts.google.com/o/oauth2/v2/auth?')).assertEqual(0);
        expect(authAction.prompt.indexOf('client_id=client-123.apps.googleusercontent.com')).assertLarger(-1);
        expect(authAction.prompt.indexOf('redirect_uri=com.example.aiphonedemo%3A%2Foauth%2Fgoogle')).assertLarger(-1);
        expect(authAction.prompt.indexOf('gmail.readonly')).assertLarger(-1);
        expect(authAction.prompt.indexOf('gmail.compose')).assertLarger(-1);
        expect(authAction.prompt.indexOf('code_challenge=')).assertLarger(-1);
        expect(authAction.prompt.indexOf('code_challenge_method=S256')).assertLarger(-1);
      } finally {
        configureGmailCredentialStoreForTests(null);
        configureGmailMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('uses stored Gmail OAuth tokens to call Gmail MCP without asking auth again', 0, async () => {
      const store = new MemoryCredentialStore();
      await saveGmailOAuthTokenSet(store, {
        access_token: 'stored-access-token',
        refresh_token: 'stored-refresh-token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose'
      });
      const mcp = new FixtureGmailMcpClient();
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GMAIL_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GMAIL_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google'
        }));
        configureGmailCredentialStoreForTests(store);
        configureGmailMcpClientForTests(mcp);

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '帮我看 Gmail 里最新的重要邮件',
          'surface_gmail_mcp',
          'client_intent_fallback',
          noop
        );

        expect(result.ok).assertTrue();
        expect(result.surface.status).assertEqual('ready');
        expect(genericToolResults(result.surface)[0].title).assertEqual('Important launch thread');
        expect(mcp.lastToolName).assertEqual('search_threads');
        expect(mcp.lastCredential).assertEqual('stored-access-token');
        expect(mcp.lastArgs.indexOf('newer_than:30d')).assertLarger(-1);
        expect(mcp.lastArgs.indexOf('-in:draft')).assertLarger(-1);
        expect(mcp.lastArgs.indexOf('is:important')).assertEqual(-1);
      } finally {
        configureGmailCredentialStoreForTests(null);
        configureGmailMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('passes structured Gmail args to stored-token Gmail MCP calls', 0, async () => {
      const store = new MemoryCredentialStore();
      await saveGmailOAuthTokenSet(store, {
        access_token: 'stored-access-token',
        refresh_token: 'stored-refresh-token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose'
      });
      const mcp = new FixtureGmailMcpClient();
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GMAIL_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GMAIL_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google'
        }));
        configureGmailCredentialStoreForTests(store);
        configureGmailMcpClientForTests(mcp);

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const args: GmailToolArgsFixture = {
          query: 'from:committee@example.edu subject:"decision"',
          pageSize: 4,
          intentSummary: '模型结构化查询'
        };
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '原始 prompt 不应决定 Gmail 搜索语义',
          'surface_gmail_mcp_args',
          'model_tool_request',
          noop,
          null,
          args
        );

        expect(result.ok).assertTrue();
        expect(mcp.lastToolName).assertEqual('search_threads');
        expect(mcp.lastArgs.indexOf('committee@example.edu')).assertLarger(-1);
        expect(mcp.lastArgs.indexOf('-in:draft')).assertLarger(-1);
        expect(mcp.lastArgs.indexOf('is:important')).assertEqual(-1);
      } finally {
        configureGmailCredentialStoreForTests(null);
        configureGmailMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('renders a Gmail error result when stored Gmail token cannot reach MCP', 0, async () => {
      const store = new MemoryCredentialStore();
      await saveGmailOAuthTokenSet(store, {
        access_token: 'stored-access-token',
        refresh_token: 'stored-refresh-token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose'
      });
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GMAIL_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GMAIL_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google'
        }));
        configureGmailCredentialStoreForTests(store);
        configureGmailMcpClientForTests(new FailingGmailMcpClient());

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.mail.search',
          '帮我看 Gmail 里最新的重要邮件',
          'surface_gmail_mcp_timeout',
          'client_intent_fallback',
          noop
        );

        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].status).assertEqual('error');
        expect(genericToolResults(result.surface)[0].title).assertEqual('Gmail MCP 调用失败');
        expect(genericToolResults(result.surface)[0].summary.indexOf('Operation timeout')).assertLarger(-1);
        expect(result.raw.indexOf('Gmail MCP 调用失败')).assertLarger(-1);
        expect(result.raw.indexOf('打开 Gmail Web')).assertEqual(-1);
      } finally {
        configureGmailCredentialStoreForTests(null);
        configureGmailMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('renders Gmail returned error results instead of relabeling them as auth', 0, async () => {
      const store = new MemoryCredentialStore();
      await saveGmailOAuthTokenSet(store, {
        access_token: 'stored-access-token',
        refresh_token: 'stored-refresh-token',
        expires_in: 3600,
        token_type: 'Bearer',
        scope: 'https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.compose'
      });
      try {
        configureLocalProviderConfigFromRawJson(JSON.stringify({
          GMAIL_OAUTH_CLIENT_ID: 'client-123.apps.googleusercontent.com',
          GMAIL_OAUTH_REDIRECT_URI: 'com.example.aiphonedemo:/oauth/google'
        }));
        configureGmailCredentialStoreForTests(store);
        configureGmailMcpClientForTests(new ErrorResultGmailMcpClient());

        const noop = (_surface: A2uiSurfaceState, _raw: string): void => {};
        const result: A2uiCallResult = await callToolGateway(
          defaultToolGatewayUrl(),
          'gmail.draft.create',
          '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了',
          'surface_gmail_error_result',
          'client_intent_fallback',
          noop
        );

        expect(result.ok).assertTrue();
        expect(genericToolResults(result.surface)[0].status).assertEqual('error');
        expect(genericToolResults(result.surface)[0].title).assertEqual('Gmail API 调用失败');
        expect(genericToolResults(result.surface)[0].summary.indexOf('Missing recipient email address')).assertLarger(-1);
        expect(result.raw.indexOf('Gmail API 调用失败')).assertLarger(-1);
        expect(result.raw.indexOf('打开 Gmail Web')).assertEqual(-1);
      } finally {
        configureGmailCredentialStoreForTests(null);
        configureGmailMcpClientForTests(null);
        configureLocalProviderConfigFromRawJson('{}');
      }
    });

    it('keeps brand MCP adapters query-only', 0, () => {
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-nearby-stores')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'query-meals')).assertTrue();
      expect(isReadonlyBrandMcpTool('麦当劳', 'create-order')).assertFalse();
      expect(isReadonlyBrandMcpTool('麦当劳', 'auto-bind-coupons')).assertFalse();
      expect(isReadonlyBrandMcpTool('瑞幸', 'queryShopList')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'searchProductForMcp')).assertTrue();
      expect(isReadonlyBrandMcpTool('瑞幸', 'createOrder')).assertFalse();
      expect(isReadonlyBrandMcpTool('瑞幸', 'cancelOrder')).assertFalse();
    });

    it('maps McDonalds MCP store and menu query payloads to food records', 0, () => {
      const storesPayload: McDonaldsStoresPayloadFixture = {
        data: [
          {
            storeName: '麦当劳深圳科技园餐厅',
            address: '深圳市南山区科苑路',
            distance: '320米',
            businessStatus: true,
            businessStartTime: '07:00',
            businessEndTime: '22:00'
          }
        ]
      };
      const mealsPayload: McDonaldsMealsPayloadFixture = {
        data: {
          categories: [
            {
              name: '人气热卖',
              meals: [
                { code: '920215', tags: ['第二份半价'] }
              ]
            }
          ],
          meals: {
            '920215': {
              name: '培根安格斯厚牛堡大套餐',
              currentPrice: '55.5'
            }
          }
        }
      };
      const stores = foodRecordsFromMcDonaldsMcpTool('query-nearby-stores', storesPayload);
      const meals = foodRecordsFromMcDonaldsMcpTool('query-meals', mealsPayload);

      expect(stores[0].name).assertEqual('麦当劳深圳科技园餐厅');
      expect(stores[0].category.indexOf('营业中')).assertLarger(-1);
      expect(stores[0].distance).assertEqual('320米');
      expect((stores[0].sourceTags === undefined ? [] : stores[0].sourceTags)[0]).assertEqual('麦当劳');
      expect(meals[0].name).assertEqual('麦当劳 · 培根安格斯厚牛堡大套餐');
      expect(meals[0].category.indexOf('¥55.5')).assertLarger(-1);
      expect(meals[0].address.indexOf('第二份半价')).assertLarger(-1);
    });

    it('maps Luckin MCP shop and product query payloads to food records', 0, () => {
      const shopsPayload: LuckinShopsPayloadFixture = {
        data: [
          {
            deptName: '瑞幸咖啡 深圳科技园店',
            address: '深圳市南山区科技园',
            distance: 0.42,
            deptTags: ['可自提'],
            longitude: 114.0579,
            latitude: 22.5431
          }
        ]
      };
      const productsPayload: LuckinProductsPayloadFixture = {
        data: [
          {
            productName: '生椰拿铁',
            price: 19,
            skuCode: 'SKU001',
            productAttrs: [
              { attributeName: '温度', productSubAttrs: [{ attributeName: '冰', selected: true }] }
            ],
            tags: ['人气']
          }
        ]
      };
      const shops = foodRecordsFromLuckinMcpTool('queryShopList', shopsPayload);
      const products = foodRecordsFromLuckinMcpTool('searchProductForMcp', productsPayload);

      expect(shops[0].name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(shops[0].category.indexOf('可自提')).assertLarger(-1);
      expect(shops[0].distance).assertEqual('420米');
      expect(shops[0].location).assertEqual('114.0579,22.5431');
      expect((shops[0].sourceTags === undefined ? [] : shops[0].sourceTags)[0]).assertEqual('瑞幸');
      expect(products[0].name).assertEqual('瑞幸 · 生椰拿铁');
      expect(products[0].category.indexOf('SKU001')).assertLarger(-1);
      expect(products[0].address.indexOf('温度:冰')).assertLarger(-1);
    });

    it('builds system map food destination search', 0, () => {
      expect(foodMapsLatLng('116.397470,39.908823')).assertEqual('39.908823,116.397470');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E7%9B%AE%E7%9A%84%E5%9C%B0&utm_source=com.example.aiphonedemo');
      expect(buildSystemFoodNavigationUri('116.397470,39.908823', '116.398470,39.909823', '喜茶(深圳坂田华创里店)')).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E5%96%9C%E8%8C%B6%28%E6%B7%B1%E5%9C%B3%E5%9D%82%E7%94%B0%E5%8D%8E%E5%88%9B%E9%87%8C%E5%BA%97%29&utm_source=com.example.aiphonedemo');
    });

    it('sorts unified travel options by departure time', 0, () => {
      const rows: A2uiTravelOptionData[] = [
        {
          id: 'flight-empty',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: '',
          from: 'BJS',
          to: 'SHA',
          depart: '',
          arrive: '',
          duration: '',
          price: '',
          availability: '',
          status: '计划',
          detail: '缺少时间'
        },
        {
          id: 'train-early',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G5',
          from: '北京南',
          to: '上海虹桥',
          depart: '06:30',
          arrive: '12:00',
          duration: '5小时30分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'train-fast',
          source: 'train',
          sourceTag: '高铁 · 12306',
          title: 'G1',
          from: '北京南',
          to: '上海虹桥',
          depart: '09:00',
          arrive: '13:28',
          duration: '4小时28分',
          price: '',
          availability: '二等座有票',
          status: '可查',
          detail: '真实高铁'
        },
        {
          id: 'flight-priced',
          source: 'flight',
          sourceTag: '飞机 · 飞常准',
          title: 'MU5101',
          from: 'BJS',
          to: 'SHA',
          depart: '07:00',
          arrive: '09:15',
          duration: '2小时15分',
          price: '¥680',
          availability: '',
          status: '计划',
          detail: '真实航班'
        }
      ];

      const sorted = sortTravelOptionsByDeparture(rows);
      expect(sorted[0].id).assertEqual('train-early');
      expect(sorted[1].id).assertEqual('flight-priced');
      expect(sorted[3].id).assertEqual('flight-empty');
    });

    it('prefers real flight airport names over provider city codes', 0, () => {
      const record = flightRecordForA2ui({
        FlightNo: 'ZH9951',
        FlightCompany: '深圳航空',
        FlightDepcode: 'SZX',
        FlightDepAirport: '深圳宝安国际机场',
        FlightArrcode: 'SHA',
        FlightArrAirport: '上海虹桥机场',
        FlightDeptimePlanDate: '2026-06-24 18:40',
        FlightArrtimePlanDate: '2026-06-24 20:55',
        FlightState: '计划'
      });

      expect(record.dep).assertEqual('深圳宝安国际机场');
      expect(record.arr).assertEqual('上海虹桥机场');
    });

    it('maps Meituan union delivery coupon results to food records', 0, () => {
      const record = foodRecordFromMeituanUnion({
        brandInfo: {
          brandName: '茶百道',
          brandLogoUrl: 'https://example.test/logo.png'
        },
        couponPackDetail: {
          name: '双杯奶茶套餐兑换券',
          sellPrice: '19.90',
          saleVolume: '10000+'
        },
        deliverablePoiInfo: {
          poiName: '茶百道 深圳科技园店',
          deliveryDistance: '1.2',
          distributionCost: '3.0',
          deliveryDuration: '30',
          lastDeliveryFee: '20'
        }
      });

      expect(record.name).assertEqual('茶百道 深圳科技园店');
      expect(record.category.indexOf('双杯奶茶套餐兑换券')).assertLarger(-1);
      expect(record.address.indexOf('配送费3.0元')).assertLarger(-1);
      expect(record.distance).assertEqual('1.2千米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('美团');
    });

    it('maps Taobao flash store promotion results to food records', 0, () => {
      const record = foodRecordFromTaobaoFlashStore({
        title: '肯德基 科技园店',
        category_1_name: '全球美食',
        delivery_distance: 820,
        delivery_time: 34,
        delivery_price: '4.0',
        service_rating: '4.6',
        items: [
          {
            title: '香辣鸡腿堡套餐',
            price: '29.9'
          }
        ]
      });

      expect(record.name).assertEqual('肯德基 科技园店');
      expect(record.category.indexOf('香辣鸡腿堡套餐')).assertLarger(-1);
      expect(record.address.indexOf('评分4.6')).assertLarger(-1);
      expect(record.distance).assertEqual('820米');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('淘宝闪购');
    });

    it('maps Tencent map nearby POI results to food records', 0, () => {
      const record = foodRecordFromTencentMapPlace({
        title: '瑞幸咖啡 深圳科技园店',
        category: '美食:咖啡厅',
        address: '深圳市南山区科技园',
        _distance: 230,
        location: {
          lat: 22.5431,
          lng: 114.0579
        }
      });

      expect(record.name).assertEqual('瑞幸咖啡 深圳科技园店');
      expect(record.category).assertEqual('美食:咖啡厅');
      expect(record.address).assertEqual('深圳市南山区科技园');
      expect(record.distance).assertEqual('230米');
      expect(record.location).assertEqual('114.0579,22.5431');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('腾讯地图');
    });

    it('maps Baidu place nearby POI results to food records', 0, () => {
      const record = foodRecordFromBaiduPlace({
        name: '星巴克 深圳科技园店',
        address: '深圳市南山区科苑路',
        location: {
          lat: 22.544,
          lng: 114.058
        },
        detail_info: {
          tag: '美食;咖啡厅',
          distance: 410,
          overall_rating: '4.5'
        }
      });

      expect(record.name).assertEqual('星巴克 深圳科技园店');
      expect(record.category.indexOf('美食;咖啡厅')).assertLarger(-1);
      expect(record.address.indexOf('评分4.5')).assertLarger(-1);
      expect(record.distance).assertEqual('410米');
      expect(record.location).assertEqual('114.058,22.544');
      const tags = record.sourceTags === undefined ? [] : record.sourceTags;
      expect(tags[0]).assertEqual('百度地图');
    });

    it('parses food distance text for local range filters', 0, () => {
      expect(foodDistanceMeters('832米')).assertEqual(832);
      expect(foodDistanceMeters('1.2千米')).assertEqual(1200);
      expect(foodDistanceMeters('0.85公里')).assertEqual(850);
    });

    it('deduplicates food results and merges source tags without fake rows', 0, () => {
      const amap: A2uiFoodData = {
        name: '喜茶 深圳科技园店',
        category: '餐饮服务',
        address: '南山科技园',
        distance: '120米',
        sourceTags: ['高德']
      };
      const meituan: A2uiFoodData = {
        name: '喜茶深圳科技园店',
        category: '芝芝莓莓',
        address: '配送费3元 · 预计28分钟',
        distance: '0.1千米',
        sourceTags: ['美团']
      };

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [amap], error: '' },
        { provider: '美团', foods: [meituan], error: '' },
        { provider: '腾讯地图', foods: [{ name: '喜茶-深圳科技园店', category: '美食', address: '科技园', distance: '100米', sourceTags: ['腾讯地图'] }], error: '' },
        { provider: '淘宝闪购', foods: [], error: '未配置 TAOBAO_APP_KEY' }
      ]);

      expect(merged.foods.length).assertEqual(1);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(3);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('美团');
      expect(tags[2]).assertEqual('腾讯地图');
      expect(providerIssueRows(merged.issues)[0].label).assertEqual('淘宝闪购');
    });

    it('builds food provider progress rows for waiting, completed, and errored sources', 0, () => {
      const rice: A2uiFoodData = {
        name: '米粉店',
        category: '餐饮',
        address: '科技园',
        distance: '100米',
        sourceTags: ['高德']
      };
      const providerNames: string[] = ['高德', '腾讯地图', '美团'];
      const completedResults: FoodProviderResult[] = [
        { provider: '高德', foods: [rice], error: '' },
        { provider: '美团', foods: [], error: '未配置 MEITUAN_UNION_APP_KEY。' }
      ];
      const rows: A2uiLabelValueData[] = foodProviderProgressRows(providerNames, completedResults);

      expect(rows.length).assertEqual(3);
      expect(rows[0].label).assertEqual('高德');
      expect(rows[0].value).assertEqual('已返回 1 条');
      expect(rows[1].label).assertEqual('腾讯地图');
      expect(rows[1].value).assertEqual('等待中');
      expect(rows[2].label).assertEqual('美团');
      expect(rows[2].value.indexOf('未配置')).assertLarger(-1);
    });

    it('keeps food partial component signatures stable when only provider data changes', 0, () => {
      const firstRows: A2uiLabelValueData[] = [
        { label: '高德', value: '等待中' }
      ];
      const secondRows: A2uiLabelValueData[] = [
        { label: '高德', value: '已返回 1 条' }
      ];
      const noodles: A2uiFoodData = {
        name: '牛肉面',
        category: '餐饮',
        address: '深圳北站',
        distance: '300米',
        sourceTags: ['高德']
      };
      const first: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, foodA2uiRenderState(
        'surface_food',
        '外卖聚合搜索',
        '真实 provider 返回',
        '已返回 0/5 个餐饮来源',
        [],
        firstRows,
        'calling_tool'
      ));
      const second: A2uiPartialUpdateResult = planA2uiPartialUpdate(first.cache, foodA2uiRenderState(
        'surface_food',
        '外卖聚合搜索',
        '真实 provider 返回',
        '已返回 1/5 个餐饮来源',
        [noodles],
        secondRows,
        'calling_tool'
      ));

      expect(first.componentsUpdated).assertTrue();
      expect(second.componentsUpdated).assertFalse();
      expect(second.updatedDataPaths.indexOf('/foods')).assertLarger(-1);
      expect(second.updatedDataPaths.indexOf('/rows')).assertLarger(-1);
    });

    it('merges the same store when map providers include different city prefixes', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '茶百道(北京东城故宫东华门店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '北京城区东华门大街83号2幢',
            distance: '832米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '835.32米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('832米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.length).assertEqual(2);
      expect(tags[0]).assertEqual('高德');
      expect(tags[1]).assertEqual('腾讯地图');
    });

    it('merges the same store when one map address includes street direction words', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [{
            name: '蜜雪冰城(东华门大街店)',
            category: '餐饮服务;冷饮店;冷饮店',
            address: '东华门大街56号',
            distance: '863米',
            sourceTags: ['高德']
          }],
          error: ''
        },
        {
          provider: '腾讯地图',
          foods: [{
            name: '蜜雪冰城(故宫东门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门街道东华门大街路南56号',
            distance: '860.31米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(1);
      expect(merged.foods[0].distance).assertEqual('860.31米');
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(tags.indexOf('高德')).assertLarger(-1);
      expect(tags.indexOf('腾讯地图')).assertLarger(-1);
    });

    it('orders merged-source food results first and then by distance', 0, () => {
      const merged = aggregateFoodProviderResults([
        {
          provider: '高德',
          foods: [
            {
              name: '近距离单源店',
              category: '餐饮服务',
              address: '近距离地址',
              distance: '50米',
              sourceTags: ['高德']
            },
            {
              name: '远距离多源店',
              category: '餐饮服务',
              address: '远距离地址',
              distance: '500米',
              sourceTags: ['高德']
            },
            {
              name: '近距离多源店',
              category: '餐饮服务',
              address: '近多源地址',
              distance: '200米',
              sourceTags: ['高德']
            }
          ],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [
            {
              name: '远距离多源店',
              category: '美食',
              address: '远距离地址',
              distance: '480米',
              sourceTags: ['百度地图']
            },
            {
              name: '近距离多源店',
              category: '美食',
              address: '近多源地址',
              distance: '210米',
              sourceTags: ['百度地图']
            }
          ],
          error: ''
        }
      ]);

      expect(merged.foods[0].name).assertEqual('近距离多源店');
      expect(merged.foods[1].name).assertEqual('远距离多源店');
      expect(merged.foods[2].name).assertEqual('近距离单源店');
    });

    it('keeps later map provider tags visible when Amap fills the limit first', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 8; index++) {
        amapFoods.push({
          name: index === 0 ? '茶百道(北京东城故宫东华门店)' : '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: index === 0 ? '北京城区东华门大街83号2幢' : '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        {
          provider: '腾讯地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食:冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '110米',
            sourceTags: ['腾讯地图']
          }],
          error: ''
        },
        {
          provider: '百度地图',
          foods: [{
            name: '茶百道(东城故宫东华门店)',
            category: '美食;冷饮店',
            address: '北京市东城区东华门大街83号2幢',
            distance: '120米',
            sourceTags: ['百度地图']
          }],
          error: ''
        }
      ]);

      expect(merged.foods.length).assertEqual(8);
      const firstTags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;
      expect(firstTags.indexOf('高德')).assertLarger(-1);
      expect(firstTags.indexOf('腾讯地图')).assertLarger(-1);
      expect(firstTags.indexOf('百度地图')).assertLarger(-1);
    });

    it('keeps more than the default visible food rows for client show more', 0, () => {
      const amapFoods: A2uiFoodData[] = [];
      const tencentFoods: A2uiFoodData[] = [];
      for (let index = 0; index < 10; index++) {
        amapFoods.push({
          name: '高德餐饮 ' + index.toString(),
          category: '餐饮服务',
          address: '高德地址 ' + index.toString(),
          distance: (100 + index).toString() + '米',
          sourceTags: ['高德']
        });
        tencentFoods.push({
          name: '腾讯餐饮 ' + index.toString(),
          category: '美食',
          address: '腾讯地址 ' + index.toString(),
          distance: (300 + index).toString() + '米',
          sourceTags: ['腾讯地图']
        });
      }

      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: amapFoods, error: '' },
        { provider: '腾讯地图', foods: tencentFoods, error: '' }
      ]);

      expect(merged.foods.length).assertLarger(8);
    });

    it('keeps legacy food records without source tags renderable', 0, () => {
      const legacy: A2uiFoodData = {
        name: '老乡鸡 科技园店',
        category: '中式快餐',
        address: '科技园',
        distance: '300米'
      };
      const merged = aggregateFoodProviderResults([
        { provider: '高德', foods: [legacy], error: '' }
      ]);
      const tags = merged.foods[0].sourceTags === undefined ? [] : merged.foods[0].sourceTags;

      expect(merged.foods.length).assertEqual(1);
      expect(tags[0]).assertEqual('高德');
    });

    it('emits food partial snapshots as provider promises complete', 0, async () => {
      const snapshots: string[] = [];
      const fastResult: FoodProviderResult = {
        provider: '快来源',
        foods: [{
          name: '快来源餐厅',
          category: '餐饮',
          address: '快来源地址',
          distance: '100米',
          sourceTags: ['快来源']
        }],
        error: ''
      };
      const fast: Promise<FoodProviderResult> = Promise.resolve(fastResult);
      const slow: Promise<FoodProviderResult> = new Promise<FoodProviderResult>((resolve: (value: FoodProviderResult) => void) => {
        setTimeout(() => {
          const slowResult: FoodProviderResult = {
            provider: '慢来源',
            foods: [{
              name: '慢来源餐厅',
              category: '餐饮',
              address: '慢来源地址',
              distance: '200米',
              sourceTags: ['慢来源']
            }],
            error: ''
          };
          resolve(slowResult);
        }, 10);
      });
      const tasks: Promise<FoodProviderResult>[] = [slow, fast];

      const finalResult = await streamFoodProviderResultsWithPartials(tasks, [], (snapshot: FoodProviderPartialSnapshot) => {
        snapshots.push(snapshot.provider + ':' + snapshot.foods.length.toString());
      });

      expect(snapshots.length).assertEqual(2);
      expect(snapshots[0].indexOf('快来源')).assertEqual(0);
      expect(snapshots[1].indexOf('慢来源')).assertEqual(0);
      expect(finalResult.aggregation.foods.length).assertEqual(2);
      expect(finalResult.results.length).assertEqual(2);
    });

    it('spaces food partial snapshots by configured delay after each provider result', 0, async () => {
      const emittedAt: number[] = [];
      const firstResult: FoodProviderResult = {
        provider: '一号来源',
        foods: [{ name: '一号店', category: '餐饮', address: '一号地址', distance: '100米', sourceTags: ['一号来源'] }],
        error: ''
      };
      const secondResult: FoodProviderResult = {
        provider: '二号来源',
        foods: [{ name: '二号店', category: '餐饮', address: '二号地址', distance: '200米', sourceTags: ['二号来源'] }],
        error: ''
      };
      const thirdResult: FoodProviderResult = {
        provider: '三号来源',
        foods: [{ name: '三号店', category: '餐饮', address: '三号地址', distance: '300米', sourceTags: ['三号来源'] }],
        error: ''
      };
      const tasks: Promise<FoodProviderResult>[] = [
        Promise.resolve(firstResult),
        Promise.resolve(secondResult),
        Promise.resolve(thirdResult)
      ];

      await streamFoodProviderResultsWithPartials(tasks, [], (_snapshot: FoodProviderPartialSnapshot) => {
        emittedAt.push(Date.now());
      }, 20);

      expect(emittedAt.length).assertEqual(3);
      expect(emittedAt[1] - emittedAt[0]).assertLarger(10);
      expect(emittedAt[2] - emittedAt[1]).assertLarger(10);
    });
  });
}
