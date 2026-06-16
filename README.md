# PocketAgent

PocketAgent is a HarmonyOS prototype for an agentic phone experience. It turns a natural-language command into a native A2UI task surface, then routes supported actions through a local tool gateway instead of hard-coded demo cards.

![PocketAgent running on HarmonyOS](docs/assets/pocketagent-current.jpeg)

The current demo focuses on five real-world assistant tasks:

- Unified travel plan search that queries high-speed rail and flights together.
- Train search through the 12306 public availability endpoint.
- Flight search through a configurable VariFlight or compatible provider.
- Food aggregation search through Amap POI, Meituan Union, and Taobao Flash/Ele.me Union provider adapters.
- Social inbox for real captured WeChat messages, with notification/accessibility diagnostics and failure-closed reply dispatch.

PocketAgent keeps regulated commerce query-only. It can summarize choices and render confirmation boundaries, but it does not book tickets, pay, grab seats, or place delivery orders. Social replies are only sent through a real device-side WeChat automation executor; if that executor or the required permissions are missing, the app shows an explicit failure instead of pretending a message was sent.

## What is inside

- `entry/`: HarmonyOS ArkTS app, A2UI renderer, model client, and unit tests.
- `tool-gateway/`: Optional Node.js compatibility gateway and provider smoke harness.
- `local-model-whitelist/`: Model whitelist snapshots used while testing local model integrations.
- `docs/a2ui.md`: Public notes for the A2UI message protocol used by this prototype.

## Architecture

```text
User command
  -> HarmonyOS ArkTS app
  -> OpenAI-compatible local/cloud model endpoint
  -> A2UI JSONL stream
  -> Native ArkUI task surface
  -> In-app local tool call
  -> Query-only provider adapter
```

The app supports an OpenAI-compatible chat completion endpoint and streams A2UI JSONL envelopes into a catalog-driven renderer. Unknown components, legacy payloads, malformed JSON, and unsafe dynamic UI formats are rejected instead of executed.

## Requirements

- DevEco Studio with HarmonyOS SDK 6.1.0 or compatible.
- Node.js 18 or newer for `tool-gateway`.
- Optional provider keys for flight and food search.
- Optional local model runtime exposing an OpenAI-compatible API, such as a local chat completion server.

## Tool execution

By default the HAP uses one tool route for every registered tool:

```text
flight.search -> local://aiphone-tools
train.search -> local://aiphone-tools
travel.search -> local://aiphone-tools
food.search -> local://aiphone-tools
social.reply.send -> local://aiphone-tools
```

The app calls 12306, VariFlight, Amap, Tencent Maps, Baidu Maps, Meituan Union, and Taobao Flash/Ele.me Union from the HarmonyOS provider adapters when the matching provider keys are configured. `travel.search` runs the train and flight query adapters, sorts the mixed rows by departure time, and `food.search` runs the enabled food provider adapters, then each aggregate tool merges only real returned rows into one result surface. You do not need to keep a Mac-side `tool-gateway` service running after the HAP is installed.

`social.reply.send` is a local social action. The first WeChat build exposes the A2UI surface, local short-term inbox model, permission diagnostics, and exact user-text reply path. It does not fabricate WeChat messages or report send success unless a real notification/accessibility bridge and WeChat automation executor are available.

For the WeChat notification-center path, apply for `ohos.permission.SUBSCRIBE_NOTIFICATION` and update the HAP Profile before testing on device. The project-side checklist is in [docs/social-notification-permission.md](docs/social-notification-permission.md).

Flight and food search need provider keys inside the installed HAP. Before building or installing, sync the ignored local env file into an ignored rawfile resource:

```bash
node scripts/sync-provider-config.mjs
```

This writes `entry/src/main/resources/rawfile/aiphone_provider_config.json`, which is packaged into the HAP and read by `EntryAbility` at startup. The generated file is ignored by git and should not be committed.

For food aggregation, configure any subset of these query-only providers:

```bash
AMAP_KEY="..."
AMAP_DEFAULT_LOCATION="116.397428,39.90923"
TENCENT_MAP_KEY="..."
BAIDU_MAP_AK="..."
MEITUAN_UNION_APP_KEY="..."
MEITUAN_UNION_APP_SECRET="..."
TAOBAO_APP_KEY="..."
TAOBAO_APP_SECRET="..."
TAOBAO_FLASH_PID="..."
```

The map POI providers (`AMAP_KEY`, `TENCENT_MAP_KEY`, `BAIDU_MAP_AK`) are the simplest query-only sources for nearby restaurants and shops. The Meituan and Taobao Flash providers remain available for platform-specific union results, but they require the matching union developer keys and permissions. Missing keys, provider authorization errors, HTTP errors, and empty provider responses are rendered as source status rows. The app does not place orders, create carts, pay, or invent cross-platform prices.

## Optional HTTP tool gateway

```bash
cd tool-gateway
cp .env.example .env.local
npm start
```

The compatibility gateway listens on `http://127.0.0.1:8787`, but the app does not use it by default.

Useful endpoints:

- `GET /health`
- `GET /mcp/tools`
- `POST /api/aiphone/tool`
- `POST /mcp/call`

If you explicitly switch the app back to the HTTP gateway for development, reverse the gateway port with HDC:

```bash
hdc rport tcp:8787 tcp:8787
```

## Run the HarmonyOS app

1. Open this repository in DevEco Studio.
2. Let DevEco restore OHPM dependencies.
3. Configure your own signing profile if DevEco does not create one automatically.
4. Fill `tool-gateway/.env.local`, then run `node scripts/sync-provider-config.mjs`.
5. Run the `entry` module on a HarmonyOS device or simulator.
6. The default tool route stays in-app for flight, train, food, travel aggregation, and social reply dispatch. No Mac-side gateway is required at runtime.

## Provider configuration

Copy `tool-gateway/.env.example` to `tool-gateway/.env.local` and fill only the providers you want to enable. Then sync it into the HAP rawfile before installation.

```bash
FLIGHT_MCP_KEY=
VARIFLIGHT_API_KEY=
AMAP_KEY=
AMAP_DEFAULT_LOCATION=116.397428,39.90923
TENCENT_MAP_KEY=
BAIDU_MAP_AK=
```

`.env.local` is ignored by git. Do not commit real provider keys, signing files, or local model credentials.

## A2UI protocol

A2UI messages are newline-delimited JSON envelopes. The app currently accepts:

- `createSurface`
- `updateComponents`
- `updateDataModel`
- `deleteSurface`

The first catalog includes `SurfaceRoot`, `Column`, `Row`, `Text`, `ActionBar`, `ErrorNotice`, `ThinkingStream`, `SocialInbox`, `TravelOptions`, `TrainOptions`, `FlightBoard`, `FoodChoices`, `ConfirmPanel`, and `InfoRows`.

See [docs/a2ui.md](docs/a2ui.md) for more detail.

## Security notes

- The renderer never executes model-generated HTML or JavaScript.
- Tool calls are limited to registered provider adapters and explicit local social actions.
- The social inbox never creates test contacts or synthetic messages; empty permission states are rendered as diagnostics.
- Booking, payment, ticket grabbing, order placement, and commerce account automation are outside the current boundary.
- Public example configuration uses placeholders only.

## License

No open-source license has been selected yet. All rights are reserved unless a license is added later.
