# Appless Phone

Appless Phone is about OpenAI's AI phone idea: the agent is the entry point, and apps become tools behind the task.

Today, ordering milk tea can mean jumping between Meituan, Taobao Flash, and other apps. Travel has the same problem across rail and flight platforms. Appless Phone points to a simpler pattern: ask once, compare the options in one place, and let the agent handle the rest of the flow.

The HarmonyOS app is a temporary shell. The plan is to make the app layer optional.

![Appless Phone home screen](docs/assets/screenshots/home.jpg)

## What it can show now

- Travel choices across rail and flight
- Nearby place search with map actions
- Gmail inbox and draft flows
- SocialHub read across X, Slack, and WeCom, public X post viewing, and reviewable local reply drafts; v1 does not send
- Dynamic weather lookup
- Home cards for saved results

## Screenshots

<div align="center">
  <img src="docs/assets/screenshots/travel-results.jpg" width="48%" alt="Travel planning" />
  <img src="docs/assets/screenshots/coffee-search.jpg" width="48%" alt="Nearby coffee search" />
</div>

<p align="center"><sub>Travel planning | Nearby coffee</sub></p>

<div align="center">
  <img src="docs/assets/screenshots/gmail-inbox.jpg" width="72%" alt="Gmail inbox" />
</div>

<p align="center"><sub>Gmail inbox</sub></p>

<div align="center">
  <img src="docs/assets/screenshots/home-cards.jpg" width="82%" alt="HarmonyOS home cards" />
</div>

<p align="center"><sub>HarmonyOS home cards</sub></p>

## Video previews

GitHub README pages do not always show repository MP4 files as inline players. These GIFs play in place. Click any preview to open the MP4.

<div align="center">
  <a href="docs/assets/demos/travel-card.mp4"><img src="docs/assets/demos/gif/beijing-to-shanghai-travel.gif" width="48%" alt="我明天要从北京去上海，帮我搜索合适的出行方式" /></a>
  <a href="docs/assets/demos/food-card.mp4"><img src="docs/assets/demos/gif/coffee-near-huawei-base.gif" width="48%" alt="帮我查询深圳坂田基地附近的咖啡店" /></a>
</div>

<p align="center"><sub><code>我明天要从北京去上海，帮我搜索合适的出行方式</code> | <code>帮我查询深圳坂田基地附近的咖啡店</code></sub></p>

<div align="center">
  <a href="docs/assets/demos/gmail-search.mp4"><img src="docs/assets/demos/gif/gmail-important-mail.gif" width="48%" alt="帮我看 Gmail 里最新的重要邮件" /></a>
  <a href="docs/assets/demos/gmail-draft.mp4"><img src="docs/assets/demos/gif/gmail-draft-reply.gif" width="48%" alt="帮我给 Gmail 里最近一封邮件起草回复" /></a>
</div>

<p align="center"><sub><code>帮我看 Gmail 里最新的重要邮件</code> | <code>帮我给 Gmail 里最近一封邮件起草回复</code></sub></p>

<div align="center">
  <a href="docs/assets/demos/weather-dynamic-mcp.mp4"><img src="docs/assets/demos/gif/shenzhen-weather.gif" width="48%" alt="帮我查深圳明天天气" /></a>
</div>

<p align="center"><sub><code>帮我查深圳明天天气</code></sub></p>

## Run locally

1. Open this repository in DevEco Studio.
2. Run the `entry` module on a HarmonyOS device or emulator.
3. Type a request in the bottom input.

## License

No open-source license has been selected yet. All rights are reserved unless a license is added later.
