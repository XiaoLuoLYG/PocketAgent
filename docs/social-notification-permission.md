# Appless Phone 社交通知权限准备清单

## 要申请的权限

- 权限名：`ohos.permission.SUBSCRIBE_NOTIFICATION`
- 权限用途：允许应用读取系统或已安装应用发布的通知。
- 权限级别：`system_basic`
- 授权方式：`system_grant`
- 设备范围：Phone、Tablet
- API 要求：通知订阅扩展能力从 API 22 开始支持。

不要把第一版通知中心聚合申请成 `ohos.permission.NOTIFICATION_CONTROLLER`。那条更偏系统通知控制/系统 API 路线，普通三方应用通常不应该用它做通知订阅闭环。Appless Phone 现在走官方 `NotificationSubscriberExtensionAbility` 路线，所以申请 `ohos.permission.SUBSCRIBE_NOTIFICATION`。

## 项目侧已准备

- `entry/src/main/module.json5` 已声明 `ohos.permission.SUBSCRIBE_NOTIFICATION`。
- `entry/src/main/module.json5` 已注册 `NotificationSubscriberExtAbility`，类型为 `notificationSubscriber`。
- `entry/src/main/ets/extensionability/NotificationSubscriberExtAbility.ets` 会接收系统通知回调，记录 `[AIPhone][SocialNotificationReceived]` 日志。
- `entry/src/main/ets/model/SocialNotificationArchive.ets` 只归档识别为微信、且标题和正文都非空的真实通知。
- Appless Phone 的“社交权限诊断”里有“打开通知授权”按钮，调用系统通知订阅授权页。

## AppGallery Connect 申请步骤

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)。
2. 进入“开发与服务”，选择 AIPhoneDemo 对应项目和应用/元服务。
3. 确认应用包名与工程一致：`com.example.aiphonedemo`。
4. 进入“项目设置 > ACL权限”，点击申请 ACL 权限。
5. 在权限搜索框里搜索并选择：`ohos.permission.SUBSCRIBE_NOTIFICATION`。
6. 权限使用场景建议填写：

   `Appless Phone 社交收件箱需要在用户主动授权后读取本机微信通知，用于在 Appless Phone 内展示真实新消息并支持用户输入原文转发回复。消息仅保存在设备本地短期缓存，不上传服务器，不生成模拟消息，不读取未授权应用通知。`

7. 审核通过后，重新创建或更新调试 Profile。
8. 在调试 Profile 的“申请权限”里选择“受限 ACL 权限（HarmonyOS API9及以上）”，确保已获批的 `ohos.permission.SUBSCRIBE_NOTIFICATION` 被加入 Profile。
9. 如果是调试 Profile，添加当前设备 UDID 后下载新的 `.p7b`。
10. 在 DevEco Studio 的签名配置中替换为新的 `.p7b` Profile，并重新打包安装。

发布 Profile 也要重复同样的 ACL 权限加入动作，否则发布包会没有该权限。

## 设备侧授权步骤

1. 安装带新 Profile 签名的 HAP。
2. 打开 Appless Phone，点击顶部“社交”。
3. 在“社交权限诊断”里点击“打开通知授权”。
4. 在系统弹窗里开启“允许获取本机通知”。
5. 在“已获取的本机通知”应用列表里开启微信。
6. 确认微信系统通知和消息详情预览已开启，否则 Appless Phone 只能拿到系统实际展示的隐藏文案。
7. 用另一台设备或另一个微信账号发送真实新消息。
8. 回到 Appless Phone 社交页，确认消息来源显示为“通知中心”。

## 验证命令

```bash
hdc list targets
hdc -t "$TARGET" shell bm get --udid
hdc -t "$TARGET" shell aa force-stop com.example.aiphonedemo
hdc -t "$TARGET" shell aa start -a EntryAbility -b com.example.aiphonedemo
hdc -t "$TARGET" hilog | rg "AIPhone.*SocialNotification|NotificationSubscriber"
```

关键日志：

- `[AIPhone][SocialNotificationReceived]`：扩展能力收到了系统通知。
- `[AIPhone][SocialNotificationArchive]`：通知被识别为微信并写入本地短缓存。
- `[AIPhone][SocialNotificationSkip]`：通知不是微信，或标题/正文不足，没有进入收件箱。
- `[AIPhone][SocialNotificationSettingsError]`：ACL/Profile/设备能力不足，系统拒绝打开授权页。

## 官方参考

- [通知订阅扩展能力概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-subscriber-extension-ability)
- [通知订阅扩展能力开发步骤](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ion-subscriber-extension-ability-development-steps)
- [受限开放权限列表](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions)
- [申请 ACL 权限](https://developer.huawei.com/consumer/cn/doc/app/agc-help-apply-acl-0000002394212138)
- [申请调试 Profile](https://developer.huawei.com/consumer/cn/doc/app/agc-help-debug-profile-0000002248181278)
