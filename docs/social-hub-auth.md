# SocialHub 授权与接入指南

SocialHub 第一版面向 X/Twitter、Slack 和企业微信，只支持聚合读取、查看公开 X 帖子，以及在本地生成可检查的回复草稿。它不会自动发送社交消息，也不会把草稿提交给任何平台。

## 功能边界

- 支持：聚合读取已授权 X/Slack 来源、读取企业微信回调缓存、查看公开 X 帖子、基于已选或已缓存条目生成本地回复草稿。
- 不支持：自动发送、批量群发、代用户发布 X 帖子、代用户发送 Slack 或企业微信消息。
- 草稿要求已有 SocialHub 条目被选中或已缓存；草稿字段会标记 `localOnly`，未发送时 `sent` 为 `false`。
- 缺少授权、scope 不足、触发限流、供应商报错或 Social Bridge 不可用时，界面必须显示可见的连接或错误状态，不能编造消息、帖子、联系人或频道。

## X/Twitter

1. 在 X Developer Portal 创建 Project 和 App。
2. 配置 OAuth 或 Bearer Token，并把 token 写入 Social Bridge 使用的环境变量。
3. 第一版只需要最小读取权限，例如 `tweet.read`、`users.read`，需要长期会话时可选 `offline.access`。
4. 第一版不申请也不使用 `tweet.write`；SocialHub 不会发布、回复或转发 X 帖子。
5. Social Bridge 在 token 已配置且查询非空时调用 X API v2 recent search：`GET https://api.x.com/2/tweets/search/recent`。
6. X API tier、scope 和额度会影响 recent search 可用性；认证失败、scope 不足或限流时只展示 X 连接错误，不会生成假帖子。

## Slack

1. 创建 Slack App，并安装到目标 workspace。
2. 按实际读取路径配置 OAuth scopes，例如搜索、频道历史、用户资料等读取相关权限。
3. 第一版不申请也不使用 `chat:write`；SocialHub 不会向 Slack 发送消息。
4. Social Bridge 使用 `SLACK_USER_TOKEN` 或 `SLACK_BOT_TOKEN`。User token 适合代表用户搜索/读取其可见内容，Bot token 只读取 bot 已加入并获授权的范围。
5. 第一版兼容调用 Slack Web API `search.messages`；Slack 已将该方法标记为 legacy，后续应迁移到 Slack 推荐的 Real-time Search API。
6. Slack API 返回 `ok:false`、HTTP 错误、scope 不足或限流时只展示 Slack 连接错误，不会生成假消息。

## 企业微信

1. 在企业微信管理后台创建自建应用，记录 CorpID、AgentID 和 Secret。
2. 配置回调 URL，并设置回调 Token 和 EncodingAESKey。
3. Social Bridge 需要用回调 token gate 校验企业微信回调来源。
4. 第一版企业微信读取来自 Social Bridge 的 callback cache；群机器人 webhook 只能用于单向推送，不能作为 SocialHub 的读取来源。

## Social Bridge 环境变量与鉴权

- 网关 API key：`TOOL_GATEWAY_API_KEY`
- X/Twitter token：`X_BEARER_TOKEN`、`X_ACCESS_TOKEN` 或 `X_OAUTH_TOKEN`
- Slack token：`SLACK_USER_TOKEN` 或 `SLACK_BOT_TOKEN`
- 企业微信：`WECOM_CORP_ID`、`WECOM_AGENT_ID`、`WECOM_SECRET`
- 企业微信回调：`WECOM_CALLBACK_TOKEN`、`WECOM_ENCODING_AES_KEY`

当配置了 `TOOL_GATEWAY_API_KEY` 时，feed 和 draft 接口必须带 API key。企业微信 callback 在配置后必须同时通过 API key 和 callback token 校验。

如果启用了 `TOOL_GATEWAY_API_KEY`，安装 HAP 前还要运行 `node scripts/sync-provider-config.mjs`，把该 key 同步到被 git 忽略的 rawfile；应用的 SocialHubClient 会从 rawfile 读取 key 并发送 `X-API-Key`。

## 草稿规则

`social.reply.draft` 只能基于已有的已选或已缓存 SocialHub item 生成本地草稿。草稿保存在本地状态中，供用户检查、修改或复制；第一版没有社交发送工具，也不会把草稿自动提交到 X/Twitter、Slack 或企业微信。
