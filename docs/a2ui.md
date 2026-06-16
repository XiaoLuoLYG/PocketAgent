# A2UI Notes

A2UI is the message format PocketAgent uses to convert model and tool output into native HarmonyOS task surfaces.

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
- `SocialInbox`
- `ConfirmPanel`
- `InfoRows`

Unknown component names are parser errors. Components can bind to the surface data model with JSON Pointer style paths such as `/rows`, `/travelOptions`, `/trains`, `/flights`, `/foods`, `/social/messages`, `/social/replies`, `/social/diagnostics`, `/thoughts`, and `/toolRequest`.

`TravelOptions` renders mixed train and flight choices from `/travelOptions`, ordered by departure time. Each item must include a `sourceTag`, for example `高铁 · 12306` or `飞机 · 飞常准`, so users can see which real provider produced the row. Source filters such as `只看高铁` and `只看飞机` should be client actions over the existing rows, not new model prompts.

`FoodChoices` renders food search choices from `/foods`. Each item may include `sourceTags`, for example `["高德","腾讯地图","百度地图","美团","淘宝闪购"]`; the renderer shows these as small source tags beside the store result. Missing `sourceTags` are allowed for older Amap-only payloads.

`SocialInbox` renders real captured social messages from `/social/messages`, reply state from `/social/replies`, and permission status rows from `/social/diagnostics`. The first channel is WeChat. A message row must include platform, conversation ID/title, sender, preview text, receive time, source (`notification`, `accessibility`, or `official`), and status. Empty social inboxes should show diagnostics; they must not create sample contacts or synthetic messages.

## Tool boundary

The local gateway exposes registered tool IDs:

- `train.search`
- `flight.search`
- `travel.search`
- `food.search`
- `social.reply.send`

Tool results must return A2UI surfaces. Provider errors, missing keys, empty results, and invalid inputs also return A2UI error or confirmation surfaces. They should not fall back to legacy UI payloads or opaque text blobs.

`travel.search` is an aggregate query tool. It calls the train and flight providers, merges successful real rows into `/travelOptions` by departure time, and writes partial source failures into `/rows`. If both providers fail or return no renderable rows, it returns an error surface instead of generating plausible travel options.

`food.search` is also an aggregate query tool. It calls configured Amap POI, Tencent Maps POI, Baidu Maps POI, Meituan Union, and Taobao Flash/Ele.me Union adapters, deduplicates by normalized store name, merges only the source tags, and writes missing keys or provider errors into `/rows`. It never places orders, creates carts, pays, or fabricates platform-specific prices.

`social.reply.send` is a local action for sending the user's exact text to a selected WeChat message. It must only report `sent` after a real device-side WeChat executor confirms the action. Missing notification permissions, missing accessibility permissions, missing WeChat detection, or missing automation executors must return explicit A2UI errors or diagnostics instead of pretending success.
