# A2UI Notes

A2UI is the message format Appless Phone uses to convert model and tool output into native HarmonyOS task surfaces.

## Goals

- Keep the model output declarative.
- Render through a fixed native component catalog.
- Stream partial updates safely.
- Keep tool calls query-only and explicit.
- Reject unknown components or legacy payloads.

## Message transport

Responses use newline-delimited JSON:

```jsonl
{"version":"v0.9.1","createSurface":{"surfaceId":"surface_train","root":"root","title":"Train search","intent":"travel.train","status":"thinking","sendDataModel":true}}
{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_train","components":[{"id":"root","component":"SurfaceRoot","child":"layout","title":"Train search","status":"ready"},{"id":"layout","component":"Column","children":["summary","results"]},{"id":"summary","component":"InfoRows","title":"Search summary","dataPath":"/rows"},{"id":"results","component":"TrainOptions","title":"Options","dataPath":"/trains"}]}}
{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_train","path":"/trains","value":[{"trainCode":"G1","from":"Beijing South","to":"Shanghai Hongqiao","depart":"09:00","arrive":"13:28","duration":"4h 28m","seats":"Available","status":"success"}]}}
```

Each envelope must contain exactly one of:

- `createSurface`
- `updateComponents`
- `updateDataModel`
- `deleteSurface`

## Catalog

Foundation components:

- `SurfaceRoot`
- `Column`
- `Row`
- `Text`
- `ActionBar`
- `ErrorNotice`

Task components:

- `ThinkingStream`
- `TravelOptions`
- `TrainOptions`
- `FlightBoard`
- `FoodChoices`
- `ConfirmPanel`
- `InfoRows`
- `SocialHub`

Unknown component names are parser errors. Components can bind to the surface data model with JSON Pointer style paths such as `/rows`, `/travelOptions`, `/trains`, `/flights`, `/foods`, `/thoughts`, `/toolRequest`, `/socialHub/items`, `/socialHub/selected`, `/socialHub/draft`, and `/socialHub/connections`.

`TravelOptions` renders mixed train and flight choices from `/travelOptions`, ordered by departure time. Each item must include a `sourceTag`, for example `高铁 · 12306` or `飞机 · 飞常准`, so users can see which real provider produced the row. Source filters such as `只看高铁` and `只看飞机` should be client actions over the existing rows, not new model prompts.

`FoodChoices` renders food search choices from `/foods`. Each item may include `sourceTags`, for example `["高德","腾讯地图","百度地图","美团","淘宝闪购"]`; the renderer shows these as small source tags beside the store result. Missing `sourceTags` are allowed for older Amap-only payloads.

`SocialHub` renders aggregated social read results from `/socialHub/items`. Each item uses `author`, `handle`, `text`, `timestamp`, `url`, `channel`, `threadId`, and `unread`; `/socialHub/selected` points at the active item, `/socialHub/draft` stores a reviewable local draft with `localOnly` and `sent`, and `/socialHub/connections` exposes provider connection statuses.

## Tool boundary

The local gateway exposes registered tool IDs:

- `train.search`
- `flight.search`
- `travel.search`
- `food.search`
- `social.feed.search`
- `social.reply.draft`
- `x.post.search`

Tool results must return A2UI surfaces. Provider errors, missing keys, empty results, and invalid inputs also return A2UI error or confirmation surfaces. They should not fall back to legacy UI payloads or opaque text blobs.

`travel.search` is an aggregate query tool. It calls the train and flight providers, merges successful real rows into `/travelOptions` by departure time, and writes partial source failures into `/rows`. If both providers fail or return no renderable rows, it returns an error surface instead of generating plausible travel options.

`food.search` is also an aggregate query tool. It calls configured Amap POI, Tencent Maps POI, Baidu Maps POI, Meituan Union, Taobao Flash/Ele.me Union, McDonald's China MCP, and Luckin Coffee MCP adapters, deduplicates by normalized store name, merges only the source tags, and writes missing keys or provider errors into `/rows`. The brand MCP adapters are only used for relevant McDonald's/Luckin/coffee-like prompts and only call read/query allowlisted tools. It never places orders, creates carts, pays, auto-binds coupons, redeems points, cancels orders, or fabricates platform-specific prices.

`social.feed.search` reads authorized X/Twitter and Slack sources into SocialHub when their tokens are configured and the query is non-empty; X uses API v2 recent search, and Slack uses `search.messages` for first-version compatibility even though Slack marks it legacy and recommends Real-time Search API for future work. WeCom reads callback-cache items. `x.post.search` returns only X posts and the X connection. `social.reply.draft` creates a local draft only, requires an existing selected or cached SocialHub item, and does not send to any provider. The first version has no social send tool.

Social tools must not return synthetic social messages, posts, contacts, channels, or send results. Missing auth, scope failure, rate limits, provider errors, and bridge outages should render visible connection or error state. If `TOOL_GATEWAY_API_KEY` is enabled, run `node scripts/sync-provider-config.mjs` before building the HAP so the app can send `X-API-Key` from its ignored rawfile config.
