import { LocalModelSettings, defaultLocalModelSettings } from '../../model/LocalModelSettings';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationExtensionSubscription } from '@kit.NotificationKit';
import {
  A2UI_COMPONENT_SOCIAL_INBOX,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSocialMessageData,
  A2uiSocialReplyData,
  A2uiSurfaceState
} from '../../model/A2uiTypes';
import { A2uiStreamMeta, callLocalModel, modelThinkCloseSeen } from '../../model/LocalModelClient';
import { A2uiSurfaceStore, createSeedA2uiSurface } from '../../model/A2uiSurfaceStore';
import { aiLogError, aiLogInfo } from '../../model/AiphoneLogger';
import { callToolGateway, defaultToolGatewayUrl, isRegisteredToolId } from '../../model/ToolGatewayClient';
import {
  AccessibilityIngestProvider,
  NotificationIngestProvider,
  SocialMessageStore,
  WechatReplyAutomation,
  buildSocialDiagnosticsRows,
  probeSocialCapabilities
} from '../../model/SocialBridge';
import { readNotificationCaptureArchive, SocialNotificationArchiveRead } from '../../model/SocialNotificationArchive';
import { HomePage } from './components/HomePage';
import { ConfigPage } from './components/ConfigPage';
import {
  ConnectionPanelState,
  createInitialConnectionPanelState,
  updateConnectionPanelState
} from './state/A2uiHomeState';
import { A2uiHomeResolvedToolRequest, resolveA2uiHomeToolRequest } from './render/A2uiHomeToolRequest';

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;
const DEFAULT_INPUT_PLACEHOLDER: string = '告诉 PocketAgent 你想完成什么';
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';
const SOCIAL_REPLY_UNAVAILABLE: string = '辅助自动化未授权或未接入真实微信发送器';
const SOCIAL_MESSAGE_STORE: SocialMessageStore = new SocialMessageStore();

function logSnippet(text: string): string {
  if (text.length <= LOG_SNIPPET_LIMIT) {
    return text;
  }
  return text.substring(0, LOG_SNIPPET_LIMIT) + '...<truncated>';
}

@Entry
@Component
struct Index {
  @State showConfigPage: boolean = false;
  @State showAdvancedSettings: boolean = false;
  @State showHistory: boolean = false;
  @State baseUrl: string = defaultLocalModelSettings().baseUrl;
  @State apiKey: string = '';
  @State selectedModel: string = defaultLocalModelSettings().model;
  @State customParametersJson: string = defaultLocalModelSettings().customParametersJson;
  @State isBusy: boolean = false;
  @State connectionStatus: string = initialConnectionState.connectionStatus;
  @State connectionMessage: string = initialConnectionState.connectionMessage;
  @State lastModelRequest: string = initialConnectionState.lastModelRequest;
  @State lastModelOutput: string = initialConnectionState.lastModelOutput;
  @State lastError: string = initialConnectionState.lastError;
  @State refreshTick: number = initialConnectionState.refreshTick;
  @State currentSurface: A2uiSurfaceState = initialSurface;
  @State surfaceRenderTick: number = 0;
  @State inputText: string = '帮我查询6月16日北京到上海的高铁票';
  @State inputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  @State messages: A2uiMessage[] = [];
  @State selectedSocialMessageId: string = '';
  @State selectedSocialConversationTitle: string = '';
  @State socialLastCapture: string = '无真实消息';
  @State socialLastSend: string = '未发送';

  private getSettings(): LocalModelSettings {
    return {
      provider: 'Huawei Local API',
      baseUrl: this.baseUrl,
      model: this.selectedModel,
      apiKey: this.apiKey,
      customParametersJson: this.customParametersJson
    };
  }

  private currentPanelState(): ConnectionPanelState {
    return {
      connectionStatus: this.connectionStatus,
      connectionMessage: this.connectionMessage,
      lastModelRequest: this.lastModelRequest,
      lastModelOutput: this.lastModelOutput,
      lastError: this.lastError,
      refreshTick: this.refreshTick
    };
  }

  private applyPanelState(next: ConnectionPanelState): void {
    this.connectionStatus = next.connectionStatus;
    this.connectionMessage = next.connectionMessage;
    this.lastModelRequest = next.lastModelRequest;
    this.lastModelOutput = next.lastModelOutput;
    this.lastError = next.lastError;
    this.refreshTick = next.refreshTick;
  }

  private cloneSurfaceComponents(components: A2uiComponent[]): A2uiComponent[] {
    const next: A2uiComponent[] = [];
    components.forEach((component: A2uiComponent) => {
      next.push({
        id: component.id,
        component: component.component,
        child: component.child,
        children: component.children === undefined ? [] : component.children.slice(),
        title: component.title,
        text: component.text,
        body: component.body,
        status: component.status,
        tone: component.tone,
        variant: component.variant,
        path: component.path,
        dataPath: component.dataPath,
        actions: component.actions === undefined ? [] : component.actions.slice()
      });
    });
    return next;
  }

  private surfaceSnapshot(surface: A2uiSurfaceState): A2uiSurfaceState {
    return {
      surfaceId: surface.surfaceId,
      rootId: surface.rootId,
      title: surface.title,
      intent: surface.intent,
      status: surface.status,
      components: this.cloneSurfaceComponents(surface.components),
      dataModelJson: surface.dataModelJson,
      error: surface.error,
      sequence: surface.sequence
    };
  }

  private parsedDataModel(): A2uiRuntimeDataModel | null {
    try {
      return JSON.parse(this.currentSurface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return null;
    }
  }

  private emptySocialModel(): A2uiRuntimeDataModel {
    return {
      rows: [],
      trains: [],
      flights: [],
      travelOptions: [],
      foods: [],
      social: {
        messages: [],
        replies: [],
        diagnostics: []
      },
      thoughts: [],
      summary: {
        text: '',
        toolName: '',
        dataLabel: '',
        count: 0
      },
      trip: {
        rows: []
      },
      rowGroups: {
        train: [],
        flight: [],
        food: []
      },
      toolRequest: {
        toolId: '',
        prompt: '',
        actionId: ''
      }
    };
  }

  private applySurface(surface: A2uiSurfaceState): void {
    this.currentSurface = this.surfaceSnapshot(surface);
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    aiLogInfo('[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=' + surface.surfaceId +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + surface.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
  }

  private markChecking(message: string): void {
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'checking',
      message: message,
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private recentMessages(): A2uiMessage[] {
    if (this.messages.length <= 8) {
      return this.messages;
    }
    return this.messages.slice(this.messages.length - 8);
  }

  private appendMessage(role: string, content: string): void {
    const next = this.messages.slice();
    next.push({
      id: Date.now().toString() + '-' + next.length.toString(),
      role: role,
      content: content
    });
    this.messages = next;
  }

  private shouldOpenSocialPrompt(prompt: string): boolean {
    return prompt.indexOf('社交') >= 0 ||
      prompt.indexOf('微信消息') >= 0 ||
      prompt.indexOf('微信收件箱') >= 0 ||
      prompt.indexOf('打开微信') >= 0;
  }

  private currentSocialMessages(): A2uiSocialMessageData[] {
    const model = this.parsedDataModel();
    if (model === null || model.social === undefined || model.social === null || !Array.isArray(model.social.messages)) {
      return [];
    }
    return model.social.messages;
  }

  private currentSocialReplies(): A2uiSocialReplyData[] {
    const model = this.parsedDataModel();
    if (model === null || model.social === undefined || model.social === null || !Array.isArray(model.social.replies)) {
      return [];
    }
    return model.social.replies;
  }

  private selectedSocialMessage(): A2uiSocialMessageData | null {
    const messages = this.currentSocialMessages();
    for (let index = 0; index < messages.length; index++) {
      if (messages[index].id === this.selectedSocialMessageId) {
        return messages[index];
      }
    }
    return null;
  }

  private isSocialReplyMode(): boolean {
    return this.selectedSocialMessageId.length > 0 && this.currentSurface.intent === 'social';
  }

  private replaceCurrentSocialData(messages: A2uiSocialMessageData[], replies: A2uiSocialReplyData[]): void {
    let model = this.parsedDataModel();
    if (model === null) {
      model = this.emptySocialModel();
    }
    if (model.social === undefined || model.social === null) {
      model.social = {
        messages: [],
        replies: [],
        diagnostics: []
      };
    }
    model.social.messages = messages;
    model.social.replies = replies;
    const nextSurface = this.surfaceSnapshot(this.currentSurface);
    nextSurface.dataModelJson = JSON.stringify(model);
    nextSurface.sequence = nextSurface.sequence + 1;
    this.applySurface(nextSurface);
  }

  private markSocialMessageStatus(messageId: string, status: string): A2uiSocialMessageData[] {
    const messages = this.currentSocialMessages();
    const next: A2uiSocialMessageData[] = [];
    for (let index = 0; index < messages.length; index++) {
      const item = messages[index];
      next.push({
        id: item.id,
        platform: item.platform,
        conversationId: item.conversationId,
        conversationTitle: item.conversationTitle,
        senderName: item.senderName,
        preview: item.preview,
        receivedAt: item.receivedAt,
        source: item.source,
        status: item.id === messageId ? status : item.status
      });
    }
    return next;
  }

  private selectSocialMessageById(messageId: string): void {
    const messages = this.currentSocialMessages();
    for (let index = 0; index < messages.length; index++) {
      if (messages[index].id === messageId) {
        const message = messages[index];
        this.selectedSocialMessageId = message.id;
        this.selectedSocialConversationTitle = message.conversationTitle;
        this.inputText = '';
        this.inputPlaceholder = '回复 微信 · ' + message.conversationTitle;
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'ready',
          message: '正在回复 ' + message.conversationTitle,
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: ''
        }));
        this.replaceCurrentSocialData(this.markSocialMessageStatus(message.id, 'selected'), this.currentSocialReplies());
        return;
      }
    }
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: false,
      status: 'error',
      message: '没有找到可回复的微信消息。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: 'social message not found: ' + messageId
    }));
  }

  private readSocialNotificationArchive(): SocialNotificationArchiveRead {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return readNotificationCaptureArchive(context);
  }

  private async openSocialNotificationSubscriptionSettings(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await notificationExtensionSubscription.openSubscriptionSettings(context);
      this.socialLastCapture = '已请求系统通知订阅授权';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开通知订阅授权。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][SocialNotificationSettings] opened');
    } catch (error) {
      const businessError = error as BusinessError;
      const message = '通知订阅授权页打开失败：' + businessError.message;
      this.socialLastCapture = message;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '通知授权不可用。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      const code = businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString();
      aiLogError('[AIPhone][SocialNotificationSettingsError] code=' + code +
        ' message=' + businessError.message);
    }
  }

  private openSocialInbox(): void {
    const archive = this.readSocialNotificationArchive();
    const notificationCandidates = archive.ok ? archive.candidates : [];
    const notificationUnavailable = archive.ok ?
      '未捕获到真实微信通知：请确认 ACL/Profile、系统通知订阅授权和微信通知预览' :
      ('通知中心缓存读取失败：' + archive.error);
    const notification = new NotificationIngestProvider(notificationCandidates.length > 0, notificationUnavailable, notificationCandidates).capture();
    const accessibility = new AccessibilityIngestProvider(false, '辅助捕获未授权或未接入').capture();
    this.socialLastCapture = notification.ok ? '通知中心返回 ' + notification.messages.length.toString() + ' 条' :
      (accessibility.ok ? '辅助捕获返回 ' + accessibility.messages.length.toString() + ' 条' : '无真实消息：' + notification.error + '；' + accessibility.error);
    notification.messages.forEach(candidate => {
      SOCIAL_MESSAGE_STORE.ingest(candidate);
    });
    accessibility.messages.forEach(candidate => {
      SOCIAL_MESSAGE_STORE.ingest(candidate);
    });
    const capabilities = probeSocialCapabilities({
      notificationBridgeAvailable: notification.ok,
      accessibilityAvailable: accessibility.ok,
      wechatInstalled: notification.messages.length > 0,
      lastCapture: this.socialLastCapture,
      lastSend: this.socialLastSend
    });
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_social',
        root: 'root',
        title: '社交收件箱',
        intent: 'social',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_social',
        components: [
          {
            id: 'root',
            component: A2UI_COMPONENT_SURFACE_ROOT,
            child: 'social_inbox',
            title: '社交收件箱',
            status: 'ready'
          },
          {
            id: 'social_inbox',
            component: A2UI_COMPONENT_SOCIAL_INBOX,
            title: '微信消息',
            body: '只展示真实捕获的新消息；当前不会生成测试消息。',
            status: 'ready',
            dataPath: '/social/messages',
            actions: []
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social',
        path: '/social/messages',
        value: SOCIAL_MESSAGE_STORE.messages()
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social',
        path: '/social/replies',
        value: this.currentSocialReplies()
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social',
        path: '/social/diagnostics',
        value: buildSocialDiagnosticsRows(capabilities)
      }
    });
    this.selectedSocialMessageId = '';
    this.selectedSocialConversationTitle = '';
    this.inputPlaceholder = '选择微信消息后在这里回复';
    this.inputText = '';
    this.applySurface(store.getSurface());
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '社交收件箱已打开：当前只显示真实捕获的新消息。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
    this.appendMessage('assistant', '社交收件箱已打开：当前只显示真实捕获的新消息。');
  }

  private async sendSelectedSocialReply(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0 || this.isBusy) {
      return;
    }
    const message = this.selectedSocialMessage();
    if (message === null) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先选择一条微信消息。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: '缺少社交会话'
      }));
      return;
    }
    this.isBusy = true;
    this.inputText = '';
    this.replaceCurrentSocialData(this.markSocialMessageStatus(message.id, 'sending'), this.currentSocialReplies());
    aiLogInfo('[AIPhone][SocialReplyRequest] messageId=' + message.id +
      ' platform=' + message.platform +
      ' target=' + message.conversationTitle +
      ' textChars=' + text.length.toString());
    try {
      const automation = new WechatReplyAutomation(false, SOCIAL_REPLY_UNAVAILABLE);
      const reply = automation.send({
        targetMessageId: message.id,
        platform: message.platform,
        conversationId: message.conversationId,
        text
      });
      const replies = this.currentSocialReplies();
      const nextReplies = replies.slice();
      nextReplies.push(reply);
      const nextStatus = reply.status === 'sent' ? 'replied' : 'failed';
      this.replaceCurrentSocialData(this.markSocialMessageStatus(message.id, nextStatus), nextReplies);
      this.socialLastSend = reply.status === 'sent' ? '已发送 ' + text.length.toString() + ' 字' : '失败：' + reply.error;
      aiLogInfo('[AIPhone][SocialReplyResult] messageId=' + message.id +
        ' platform=' + message.platform +
        ' status=' + reply.status +
        ' failureStep=' + reply.error);
      if (reply.status === 'sent') {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'ready',
          message: '微信回复已发送。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: ''
        }));
        this.appendMessage('assistant', '微信回复已发送。');
      } else {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: false,
          status: 'error',
          message: '微信回复失败。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: reply.error
        }));
        this.appendMessage('assistant', '微信回复失败：' + reply.error);
      }
    } finally {
      this.isBusy = false;
    }
  }

  private async submitPrompt(prompt: string, visibleText: string, actionId: string = ''): Promise<void> {
    const trimmed = prompt.trim();
    if (trimmed.length === 0 || this.isBusy) {
      return;
    }
    if (this.baseUrl.trim().length === 0) {
      aiLogError('[AIPhone][A2uiHomeSubmitBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      return;
    }

    this.selectedSocialMessageId = '';
    this.selectedSocialConversationTitle = '';
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.appendMessage('user', visibleText);
    aiLogInfo('[AIPhone][A2uiHomeSubmitPrompt] chars=' + trimmed.length.toString() +
      ' model=' + this.selectedModel +
      ' baseUrl=' + this.baseUrl);
    this.inputText = '';
    this.isBusy = true;
    this.markChecking('正在生成 A2UI...');
    try {
      const result: A2uiCallResult = await callLocalModel(
        this.getSettings(),
        trimmed,
        this.recentMessages(),
        (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => {
          this.applySurface(surface);
          const thinkClosed = meta?.thinkClosed === true || modelThinkCloseSeen(raw);
          this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
            ok: true,
            status: 'checking',
            message: '模型流式更新：' + surface.title + (thinkClosed ? '，思考流已闭合。' : '。'),
            requestDebug: this.lastModelRequest,
            assistantDebug: raw,
            error: ''
          }));
        },
        this.currentSurface
      );
      this.applySurface(result.surface);
      aiLogInfo('[AIPhone][A2uiHomeModelResult] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][A2uiHomeModelOutput] ' + logSnippet(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: result.ok,
        status: result.ok ? 'ready' : 'error',
        message: result.ok ? 'A2UI 已更新到主页。' : 'A2UI 生成异常，请到配置页查看详情。',
        requestDebug: result.requestDebug,
        assistantDebug: result.assistantDebug.length > 0 ? result.assistantDebug : result.raw,
        error: result.error
      }));
      if (result.ok) {
        this.appendMessage('assistant', result.assistantDebug.length > 0 ? result.assistantDebug : result.surface.title);
        await this.callModelRequestedTool(result.surface, trimmed, actionId);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeModelException] ' + logSnippet(message));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'A2UI 生成异常，请到配置页查看详情。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
    } finally {
      this.isBusy = false;
    }
  }

  private async sendPrompt(): Promise<void> {
    if (this.isSocialReplyMode()) {
      await this.sendSelectedSocialReply();
      return;
    }
    if (this.shouldOpenSocialPrompt(this.inputText)) {
      this.appendMessage('user', this.inputText);
      this.openSocialInbox();
      return;
    }
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private handleClientAction(action: A2uiAction): void {
    aiLogInfo('[AIPhone][A2uiHomeClientAction] id=' + action.id);
    if (action.id === 'social_select_message') {
      this.selectSocialMessageById(action.prompt);
      return;
    }
    if (action.id === 'social_open_notification_settings') {
      this.openSocialNotificationSubscriptionSettings();
      return;
    }
  }

  private focusEditQuery(actionId: string = ''): void {
    if (actionId === 'travel_change_date') {
      this.inputPlaceholder = '请输入新的日期或路线，如：后天北京到上海出行方案';
      this.inputText = '';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '请在输入框补充新的日期或路线。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    this.inputPlaceholder = TRAIN_EDIT_QUERY_PLACEHOLDER;
    this.inputText = '';
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '请在输入框补充具体查询条件。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private async sendAction(action: A2uiAction): Promise<void> {
    const kind = action.kind.length > 0 ? action.kind : 'prompt';
    if (kind === 'client') {
      this.handleClientAction(action);
      return;
    }
    if (kind === 'input') {
      this.focusEditQuery(action.id);
      return;
    }
    await this.submitPrompt(action.prompt, action.label, action.id);
  }

  private toolSurfaceId(): string {
    if (this.currentSurface.surfaceId.length === 0 || this.currentSurface.status === 'error') {
      return 'surface_model';
    }
    return this.currentSurface.surfaceId;
  }

  private async callModelRequestedTool(surface: A2uiSurfaceState, fallbackPrompt: string, fallbackActionId: string): Promise<void> {
    const request: A2uiHomeResolvedToolRequest = resolveA2uiHomeToolRequest(surface, fallbackPrompt, fallbackActionId);
    if (!request.hasTool) {
      aiLogInfo('[AIPhone][A2uiHomeToolRequest] none');
      return;
    }
    aiLogInfo('[AIPhone][A2uiHomeToolRequestFromModel] toolId=' + request.toolId +
      ' modelPromptChars=' + request.modelPromptChars.toString() +
      ' userPromptChars=' + fallbackPrompt.length.toString() +
      ' sentPromptChars=' + request.prompt.length.toString());
    await this.callToolById(request.toolId, request.prompt, request.actionId);
  }

  private async callToolById(toolId: string, prompt: string, actionId: string): Promise<boolean> {
    if (!isRegisteredToolId(toolId)) {
      const message = '模型请求了未注册工具：' + toolId;
      aiLogError('[AIPhone][A2uiHomeToolRequestInvalid] toolId=' + toolId);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: message,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      return false;
    }

    aiLogInfo('[AIPhone][A2uiHomeToolRequest] toolId=' + toolId +
      ' promptChars=' + prompt.length.toString() +
      ' actionId=' + actionId +
      ' gateway=' + TOOL_GATEWAY_URL);
    this.markChecking('正在调用工具：' + toolId);
    const result: A2uiCallResult = await callToolGateway(
      TOOL_GATEWAY_URL,
      toolId,
      prompt,
      this.toolSurfaceId(),
      actionId,
      (surface: A2uiSurfaceState, raw: string) => {
        this.applySurface(surface);
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'checking',
          message: '工具流式更新：' + surface.title,
          requestDebug: this.lastModelRequest,
          assistantDebug: raw,
          error: ''
        }));
      },
      this.currentSurface
    );

    aiLogInfo('[AIPhone][A2uiHomeToolResult] ok=' + (result.ok ? 'true' : 'false') +
      ' errorChars=' + result.error.length.toString() +
      ' rawChars=' + result.raw.length.toString());
    aiLogInfo('[AIPhone][A2uiHomeToolOutput] ' + logSnippet(result.raw));
    this.applySurface(result.surface);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: result.ok,
      status: result.ok ? 'ready' : 'error',
      message: result.ok ? result.surface.title + ' 已返回工具结果。' : '工具返回异常，请到配置页查看详情。',
      requestDebug: this.lastModelRequest,
      assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
      error: result.error
    }));
    if (!result.ok) {
      this.appendMessage('assistant', '工具返回异常：' + result.error);
      return false;
    }
    this.appendMessage('assistant', result.surface.title + ' 已返回 A2UI 结果。');
    return true;
  }

  private async testConnection(): Promise<void> {
    if (this.isBusy) {
      return;
    }
    const trimmedBaseUrl = this.baseUrl.trim();
    if (trimmedBaseUrl.length === 0) {
      aiLogError('[AIPhone][A2uiHomeConnectionBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      return;
    }

    this.isBusy = true;
    aiLogInfo('[AIPhone][A2uiHomeConnectionTest] model=' + this.selectedModel + ' baseUrl=' + this.baseUrl);
    this.markChecking('正在向模型发起连接检查...');
    try {
      const result: A2uiCallResult = await callLocalModel(
        this.getSettings(),
        CONNECTION_TEST_PROMPT,
        this.recentMessages(),
        (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => {
          const thinkClosed = meta?.thinkClosed === true || modelThinkCloseSeen(raw);
          this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
            ok: true,
            status: 'checking',
            message: '已收到模型流式更新：' + surface.title + (thinkClosed ? '，思考流已闭合。' : '。'),
            requestDebug: this.lastModelRequest,
            assistantDebug: raw,
            error: ''
          }));
        }
      );
      aiLogInfo('[AIPhone][A2uiHomeConnectionResult] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][A2uiHomeConnectionOutput] ' + logSnippet(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: result.ok,
        status: result.ok ? 'ready' : 'error',
        message: result.ok ? '模型连接正常，测试返回已更新到当前页面。' : '模型连接异常，请查看最近异常。',
        requestDebug: result.requestDebug,
        assistantDebug: result.assistantDebug.length > 0 ? result.assistantDebug : result.raw,
        error: result.error
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeConnectionException] ' + logSnippet(message));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '模型连接异常，请查看最近异常。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
    } finally {
      this.isBusy = false;
    }
  }

  build() {
    if (this.showConfigPage) {
      ConfigPage({
        baseUrl: $baseUrl,
        apiKey: $apiKey,
        selectedModel: $selectedModel,
        customParametersJson: $customParametersJson,
        showAdvancedSettings: $showAdvancedSettings,
        connectionStatus: this.connectionStatus,
        connectionMessage: this.connectionMessage,
        isBusy: this.isBusy,
        lastModelRequest: this.lastModelRequest,
        lastModelOutput: this.lastModelOutput,
        lastError: this.lastError,
        refreshTick: this.refreshTick,
        onBack: () => {
          this.showConfigPage = false;
        },
        onTestConnection: () => {
          this.testConnection();
        }
      })
    } else {
      HomePage({
        inputText: $inputText,
        isBusy: this.isBusy,
        showHistory: this.showHistory,
        messages: this.messages,
        currentSurface: this.currentSurface,
        surfaceRenderTick: this.surfaceRenderTick,
        inputPlaceholder: this.inputPlaceholder,
        onToggleHistory: () => {
          this.showHistory = !this.showHistory;
        },
        onOpenSocial: () => {
          this.openSocialInbox();
        },
        onOpenConfig: () => {
          this.showConfigPage = true;
        },
        onOpenStyleLab: () => {
          router.pushUrl({ url: 'pages/A2uiHome/StyleLab' }, (error) => {
            if (error) {
              aiLogError('[AIPhone][A2uiStyleLabRouteFailed] ' + JSON.stringify(error));
            }
          });
        },
        onSendPrompt: () => {
          this.sendPrompt();
        },
        onAction: (action: A2uiAction) => {
          this.sendAction(action);
        }
      })
    }
  }
}
