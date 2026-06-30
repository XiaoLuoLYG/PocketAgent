# Appless Phone 快速开始

这份教程帮你跑起一个真实边界的 HarmonyOS agent phone demo。

Appless Phone 的默认原则很简单：缺少本地模型、provider key、设备权限或真实执行器时，界面显示真实失败，不返回假车次、假航班、假餐厅、假邮件或假消息。

## 1. 打开工程

1. 安装 DevEco Studio，并准备 HarmonyOS SDK 6.1.0 或兼容 SDK。
2. 克隆仓库，用 DevEco Studio 打开项目根目录。
3. 等待 DevEco Studio 恢复 OHPM 依赖。
4. 配置设备或模拟器签名。
5. 运行 `entry` 模块。

## 2. 连接模型

默认模型设置：

```text
Base URL: http://127.0.0.1:11434
Model: Qwen3-8B
```

进入 app 设置页，点击连接测试。如果使用 OpenAI-compatible 云端端点，在同一页填写模型、Base URL、API key 和必要的自定义 JSON 参数。

DashScope-compatible Qwen preset 已内置，但你仍然需要自己的 API key。

## 3. 不配置 key 也能试

没有 provider key 时，仍然可以验证主链路：

```text
你好
我明天从北京去上海，帮我搜索出行方案
帮我搜索深圳坂田华为基地附近的咖啡
```

预期行为：

- 模型返回 A2UI surface，而不是 Markdown。
- 实时查询会请求 `travel.search` 或 `food.search`。
- 缺失 provider 配置会显示为状态行或错误行。
- app 不会编造车次、航班、价格、餐厅或社交消息。

## 4. 开启真实 provider 查询

复制本地 provider 模板：

```bash
cd tool-gateway
cp .env.example .env.local
```

按需填写 key：

```bash
FLIGHT_MCP_KEY=
VARIFLIGHT_API_KEY=
AMAP_KEY=
AMAP_DEFAULT_LOCATION=116.397428,39.90923
TENCENT_MAP_KEY=
BAIDU_MAP_AK=
MEITUAN_UNION_APP_KEY=
MEITUAN_UNION_APP_SECRET=
TAOBAO_APP_KEY=
TAOBAO_APP_SECRET=
TAOBAO_FLASH_PID=
MCD_MCP_TOKEN=
LUCKIN_MCP_TOKEN=
QQ_MAIL_ADDRESS=
QQ_MAIL_AUTH_CODE=
QQ_MAIL_IMAP_HOST=imap.qq.com
QQ_MAIL_IMAP_PORT=993
QQ_MAIL_DRAFTS_MAILBOX=
```

构建或安装 HAP 前，把本地值同步到被忽略的 rawfile：

```bash
cd ..
node scripts/sync-provider-config.mjs
```

然后重新安装或从 DevEco Studio 重新运行 app。

## 5. Demo Prompt

出行：

```text
我明天从北京去上海，帮我搜索出行方案
帮我查后天深圳到杭州的高铁票
帮我查明天广州飞上海的航班
```

餐饮：

```text
帮我搜索深圳坂田华为基地附近的咖啡
附近有什么麦当劳
帮我看看附近瑞幸有什么可选
```

Gmail：

```text
帮我查看 Gmail 最近邮件
帮我给 Gmail 里最近一封邮件起草回复
```

邮箱聚合：

```text
帮我看邮箱里最新的重要邮件
帮我给 QQ 邮箱里最近一封邮件起草回复
```

动态工具：

```text
帮我查深圳明天天气
```

社交：

```text
打开微信消息
```

社交 demo 需要真实设备权限和真实捕获/发送路径。空收件箱和缺失权限应该显示诊断，不应该显示示例联系人。

## 6. 可选 gateway smoke

默认 HAP 使用 `local://aiphone-tools`。Node gateway 只用于开发 smoke 或显式 HTTP gateway 实验。

```bash
cd tool-gateway
npm run smoke
```

## 7. 设备 smoke

HDC 能看到目标设备且 app 已安装时：

```bash
node scripts/aiphone-device-smoke.mjs
```

设备 smoke 会检查模型路由、预期工具选择、本地工具执行，以及失败是否来自真实缺失配置或 provider/runtime 问题。

## 当前不会做什么

- 不订票、不支付、不抢票、不出票。
- 不下餐饮订单、不创建购物车、不兑换积分、不自动领券。
- 不伪造微信消息，也不会在没有真实设备发送器确认时声称已回复。
- 默认安装路径不需要运行可选 Node gateway。
