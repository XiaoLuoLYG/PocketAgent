# AIPhone Tool Gateway

This optional local gateway gives the HarmonyOS demo a stable HTTP endpoint for development-time tool-call smoke tests.

The app does not need this service for its default runtime path. Current HAP builds keep `flight.search`, `train.search`, `travel.search`, `food.search`, and `social.reply.send` on `local://aiphone-tools`; the device calls 12306, VariFlight, Amap, Meituan Union, and Taobao Flash/Ele.me Union directly when matching keys are configured. Social reply dispatch stays device-side and only reports success when a real WeChat automation executor is connected. Use `scripts/sync-provider-config.mjs` before installation to package provider keys into the ignored HAP rawfile.

## Start

```bash
cd tool-gateway
TOOL_GATEWAY_PORT=8787 npm start
```

Stable macOS launchd start:

```bash
launchctl remove com.aiphone.toolgateway 2>/dev/null || true
launchctl submit -l com.aiphone.toolgateway \
  -o /tmp/aiphone-tool-gateway.log \
  -e /tmp/aiphone-tool-gateway.err \
  -- /opt/homebrew/bin/node /Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/tool-gateway/server.mjs
```

For explicit HTTP gateway testing through HDC reverse port:

```bash
hdc -t 45N0124A19000274 rport tcp:8787 tcp:8787
```

Only use this if you have intentionally switched the app to an HTTP gateway for development. The default HAP does not call `http://127.0.0.1:8787`.

Stop the launchd job:

```bash
launchctl remove com.aiphone.toolgateway
```

## Endpoints

- `GET /health`
- `GET /mcp/tools`
- `POST /mcp/call`
- `POST /api/aiphone/tool`

## Provider Configuration

Without provider configuration, the gateway returns an A2UI error surface instead of fake live data.
`travel.search` is the aggregate travel query. It calls the train and flight providers, sorts the mixed rows by departure time, merges only real returned rows into `TravelOptions`, and writes partial provider failures into source-status rows.

`social.reply.send` is registered for compatibility but the Node gateway cannot send WeChat replies. It returns an explicit A2UI unavailable surface unless the HAP has a real notification/accessibility bridge and device-side WeChat executor.

`POST /api/aiphone/tool` accepts:

```json
{
  "toolId": "train.search",
  "prompt": "帮我查询明天北京到上海的高铁票",
  "rows": [{ "label": "出发地", "value": "北京" }],
  "bullets": ["明天出发"]
}
```

Unified travel search uses the same endpoint with `toolId: "travel.search"`:

```json
{
  "toolId": "travel.search",
  "prompt": "我明天要从北京去上海，帮我搜索出行方案"
}
```

Responses use `application/a2ui+json` JSONL:

```jsonl
{"version":"v0.9.1","createSurface":{"surfaceId":"surface_train_search","root":"root","title":"12306 余票查询","intent":"travel.train","status":"ready","sendDataModel":true}}
{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_train_search","components":[{"id":"root","component":"SurfaceRoot","child":"layout","title":"12306 余票查询","status":"ready"},{"id":"layout","component":"Column","children":["summary","results","confirm"]},{"id":"summary","component":"InfoRows","title":"查询摘要","dataPath":"/rows"},{"id":"results","component":"TrainOptions","title":"可选车次","dataPath":"/trains","actions":[{"id":"change_train_date","label":"换时间","prompt":"换个时间查询高铁","variant":"secondary"}]},{"id":"confirm","component":"ConfirmPanel","title":"确认边界","body":"我可以继续帮你整理方案，但不会自动订票、支付或抢票。","actions":[{"id":"explain_boundary","label":"说明边界","prompt":"说明订票和支付边界","variant":"secondary"}]}]}}
{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_train_search","path":"/trains","value":[{"trainCode":"G1","from":"北京南","to":"上海虹桥","depart":"09:00","arrive":"13:28","duration":"4小时28分","seats":"二等座有票","status":"success"}]}}
```

For `travel.search`, successful mixed rows are written to `/travelOptions` in departure-time order. Each row includes a visible source tag such as `高铁 · 12306` or `飞机 · 飞常准`.

Copy `tool-gateway/.env.example` to `tool-gateway/.env.local`, then fill the keys you have. `.env.local` is ignored by git. For the app runtime path, run this from the repo root before building:

```bash
node scripts/sync-provider-config.mjs
```

## Recommended Real Providers

### Train

The gateway can query the public 12306 ticket search endpoint directly for availability summaries.

- No account is required for query-only mode.
- Booking, passenger selection, payment, or ticket grabbing are not automated.
- If you prefer MCP, configure `TRAIN_MCP_URL`.

### Flights

Use VariFlight / 飞常准 MCP for China-focused flight query.

Register at:

```text
https://mcp.variflight.com/register
```

Registration fields:

- 用户名
- 电子邮箱
- 密码
- 电话号码（可选）
- 公司名称（可选）

After login, open API Keys and create an API Key. Configure one of these:

```bash
FLIGHT_MCP_KEY="..."
# or
VARIFLIGHT_API_KEY="..."
```

Optional override:

```bash
VARIFLIGHT_API_URL="https://mcp.variflight.com/api/v1/mcp/data"
```

The gateway calls VariFlight's query endpoint only. Booking, ticket issuing, passenger forms, and payment are out of scope.

### Food / Delivery

V1 is query-only. It does not call Meituan, Ele.me, Taobao Flash, or Amap ordering APIs.

The default HAP route is `local://aiphone-tools`, where `food.search` aggregates configured Amap, Meituan Union, and Taobao Flash/Ele.me Union adapters. The compatibility Node gateway can still return Amap POI data, but the in-app provider path is the primary implementation.

Query nearby restaurants with Amap Web Service POI:

```text
https://lbs.amap.com/api/webservice/create-project-and-key
```

Steps:

- 登录高德开放平台控制台；没有账号先注册成为开发者。
- 进入应用管理，点击创建新应用。
- 在应用下添加 Key，服务平台选择 Web 服务。
- Copy the created Key into `AMAP_KEY`.
- Set a default search center with `AMAP_DEFAULT_LOCATION` if the app has no live location yet.

```bash
AMAP_KEY="..."
AMAP_DEFAULT_LOCATION="116.397428,39.90923"
```

Enable Meituan Union product query and Taobao Flash/Ele.me Union store promotion query in the HAP rawfile sync input:

```bash
MEITUAN_UNION_APP_KEY="..."
MEITUAN_UNION_APP_SECRET="..."
TAOBAO_APP_KEY="..."
TAOBAO_APP_SECRET="..."
TAOBAO_FLASH_PID="..."
```

The app returns query choices only. Ordering, cart creation, delivery quote, and payment are out of scope. Missing keys and provider errors are displayed as source status rows instead of mock stores.

Generic HTTP API adapters:

```bash
FLIGHT_API_URL="https://provider.example/flight/search"
FLIGHT_API_KEY="..."
TRAIN_API_URL="https://provider.example/train/search"
TRAIN_API_KEY="..."
FOOD_API_URL="https://provider.example/food/search"
FOOD_API_KEY="..."
```

Experimental HTTP MCP adapters:

```bash
FLIGHT_MCP_URL="https://mcp.example/mcp"
TRAIN_MCP_URL="http://127.0.0.1:8788/mcp"
FOOD_MCP_URL="https://mcp.example/mcp"
```

If a provider needs custom signing, add a provider-specific adapter in `server.mjs`.
