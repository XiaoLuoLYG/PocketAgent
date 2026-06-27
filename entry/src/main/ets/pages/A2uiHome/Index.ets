import { LocalModelSettings, defaultLocalModelSettings } from '../../model/LocalModelSettings';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { notificationExtensionSubscription } from '@kit.NotificationKit';
import {
  A2UI_COMPONENT_SOCIAL_INBOX,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSocialMessageData,
  A2uiSocialReplyData,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData
} from '../../model/A2uiTypes';
import { A2uiStreamMeta, callLocalModel, modelThinkCloseSeen } from '../../model/LocalModelClient';
import { GMAIL_MCP_AUTH_SETUP_URL, GMAIL_WEB_URL } from '../../model/GmailToolA2ui';
import { A2uiSurfaceStore, createSeedA2uiSurface } from '../../model/A2uiSurfaceStore';
import { aiLogError, aiLogInfo } from '../../model/AiphoneLogger';
import { callToolGateway, configureLocalToolDebugConfig, defaultToolGatewayUrl, isRegisteredToolId, prepareGmailOAuthAuthorizationUrl } from '../../model/ToolGatewayClient';
import {
  NavigationCardSnapshot,
  NavigationCardSnapshotBuildResult,
  PreferencesNavigationCardSnapshotStore,
  buildNavigationCardBindingData,
  navigationCardSnapshotFromFlightOption,
  navigationCardSnapshotFromFoodOption,
  navigationCardSnapshotFromTrainOption,
  navigationCardSnapshotFromTravelOption
} from '../../model/NavigationCardSnapshot';
import {
  AccessibilityIngestProvider,
  NotificationIngestProvider,
  SocialMessageStore,
  WechatReplyAutomation,
  buildSocialDiagnosticsRows,
  probeSocialCapabilities
} from '../../model/SocialBridge';
import { detectSocialAccessibilitySync, detectWechatBundleSync } from '../../model/SocialCapabilityProbe';
import { readNotificationCaptureArchive, SocialNotificationArchiveRead } from '../../model/SocialNotificationArchive';
import { AssetCredentialStore } from '../../model/DynamicCredentialStore';
import { buildSystemFoodNavigationUri } from '../../model/FoodNavigation';
import { HomePage } from './components/HomePage';
import { ConfigPage } from './components/ConfigPage';
import { createHtmlHomeDocument } from './html/HtmlHomeSnapshot';
import { renderHtmlHomeDocument } from './html/HtmlHomeRenderer';
import { isHtmlHomeActionAllowed } from './html/HtmlHomeActionPolicy';
import { HtmlHomeDocument } from './html/HtmlHomeTypes';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from './state/A2uiHomeDebugSettings';
import {
  ConnectionPanelState,
  createInitialConnectionPanelState,
  inputTextAfterPromptSubmit,
  shouldApplySurfaceUpdate,
  shouldShowQueryPendingSurface,
  shouldShowWelcome,
  updateConnectionPanelState
} from './state/A2uiHomeState';
import { A2uiHomeResolvedToolRequest, resolveA2uiHomeToolRequest } from './render/A2uiHomeToolRequest';

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;
const DEFAULT_INPUT_PLACEHOLDER: string = '告诉 Appless Phone 你想完成什么';
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';
const SOCIAL_REPLY_UNAVAILABLE: string = '真实微信发送器未接入或当前设备未开放自动发送能力';
const SOCIAL_NOTIFICATION_UNSUPPORTED_HINT: string = '当前 PC 系统未向三方应用开放通知内容订阅；系统开放后会显示真实微信新消息';
const SOCIAL_MESSAGE_STORE: SocialMessageStore = new SocialMessageStore();
const NAVIGATION_CARD_TTL_MS: number = 60 * 60 * 1000;

type HtmlActionValue = Object | string | number | boolean | null | undefined;

interface HtmlDynamicCredentialPayload {
  credentialRef?: HtmlActionValue;
  credentialValue?: HtmlActionValue;
  toolId?: HtmlActionValue;
  prompt?: HtmlActionValue;
}

interface HtmlPinPayload {
  index?: HtmlActionValue;
  id?: HtmlActionValue;
  source?: HtmlActionValue;
  trainCode?: HtmlActionValue;
  flightNo?: HtmlActionValue;
  name?: HtmlActionValue;
  address?: HtmlActionValue;
  location?: HtmlActionValue;
  distance?: HtmlActionValue;
  depart?: HtmlActionValue;
  depTime?: HtmlActionValue;
  from?: HtmlActionValue;
  to?: HtmlActionValue;
  dep?: HtmlActionValue;
  arr?: HtmlActionValue;
}

function logSnippet(text: string): string {
  if (text.length <= LOG_SNIPPET_LIMIT) {
    return text;
  }
  return text.substring(0, LOG_SNIPPET_LIMIT) + '...<truncated>';
}

function modelPromptWithActionContext(prompt: string, actionId: string, args: Object | null): string {
  if (actionId.length === 0 && args === null) {
    return prompt;
  }
  return prompt + '\n\nAction ID: ' + actionId + '\nStructured action args JSON: ' +
    (args === null ? '{}' : JSON.stringify(args));
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
  @State foodProviderDelayEnabled: boolean = false;
  @State foodProviderDelayMs: string = '0';
  @State foodPartialThrottleMs: string = A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS.toString();
  @State isBusy: boolean = false;
  @State connectionStatus: string = initialConnectionState.connectionStatus;
  @State connectionMessage: string = initialConnectionState.connectionMessage;
  @State lastModelRequest: string = initialConnectionState.lastModelRequest;
  @State lastModelOutput: string = initialConnectionState.lastModelOutput;
  @State lastError: string = initialConnectionState.lastError;
  @State refreshTick: number = initialConnectionState.refreshTick;
  @State currentSurface: A2uiSurfaceState = initialSurface;
  @State surfaceRenderTick: number = 0;
  @State isAwaitingFirstSurface: boolean = false;
  @State inputText: string = '';
  @State inputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  @State messages: A2uiMessage[] = [];
  @State selectedSocialMessageId: string = '';
  @State selectedSocialConversationTitle: string = '';
  @State socialLastCapture: string = '无真实消息';
  @State socialLastSend: string = '未发送';
  @State hasSocialReturnSurface: boolean = false;
  @State socialReturnSurface: A2uiSurfaceState = initialSurface;
  @State socialReturnInputText: string = '';
  @State socialReturnInputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  private htmlHomeCacheKey: string = '';
  private htmlHomeCacheHtml: string = '';

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

  private resetPanelState(): void {
    const next = createInitialConnectionPanelState();
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
      form: {},
      toolRequest: {
        toolId: '',
        prompt: '',
        actionId: ''
      },
      dynamicToolConnect: {
        toolId: '',
        prompt: '',
        manifestId: '',
        displayName: '',
        sourceUrl: '',
        status: '',
        message: '',
        credentialName: '',
        credentialRef: '',
        registrationUrl: '',
        actions: []
      },
      genericToolResults: []
    };
  }

  private currentHtmlHomeDocument(): HtmlHomeDocument {
    if (shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface) ||
      shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface)) {
      return createHtmlHomeDocument({
        messages: this.messages,
        isBusy: this.isBusy,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputText: this.inputText
      });
    }
    return createHtmlHomeDocument({
      surface: this.currentSurface,
      messages: this.messages,
      isBusy: this.isBusy,
      isAwaitingFirstSurface: this.isAwaitingFirstSurface
    });
  }

  private currentHtmlHomeCacheKey(): string {
    const needsInputText = shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface);
    const sequenceKey = this.isBusy ? 'busy' : this.currentSurface.sequence.toString();
    return [
      this.currentSurface.surfaceId,
      sequenceKey,
      this.currentSurface.status,
      this.isBusy ? 'busy' : 'idle',
      this.isAwaitingFirstSurface ? 'awaiting' : 'ready',
      this.messages.length.toString(),
      needsInputText ? this.inputText : ''
    ].join('|');
  }

  private currentHtmlHomeHtml(): string {
    const key = this.currentHtmlHomeCacheKey();
    if (key === this.htmlHomeCacheKey && this.htmlHomeCacheHtml.length > 0) {
      return this.htmlHomeCacheHtml;
    }
    const document = this.currentHtmlHomeDocument();
    const html = renderHtmlHomeDocument(document, this.isBusy);
    this.htmlHomeCacheKey = key;
    this.htmlHomeCacheHtml = html;
    aiLogInfo('[AIPhone][HtmlHomeDocument] source=' + document.source +
      ' kind=' + document.kind +
      ' chars=' + html.length.toString() +
      ' blocks=' + document.blocks.length.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
    return html;
  }

  private applySurface(surface: A2uiSurfaceState): void {
    if (!shouldApplySurfaceUpdate(this.currentSurface, surface)) {
      return;
    }
    this.currentSurface = this.surfaceSnapshot(surface);
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    aiLogInfo('[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=' + surface.surfaceId +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + surface.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
  }

  private resetCurrentSession(): void {
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.messages = [];
    this.currentSurface = this.surfaceSnapshot(createSeedA2uiSurface());
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.inputText = '';
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.selectedSocialMessageId = '';
    this.selectedSocialConversationTitle = '';
    this.hasSocialReturnSurface = false;
    this.socialReturnSurface = this.surfaceSnapshot(createSeedA2uiSurface());
    this.socialReturnInputText = '';
    this.socialReturnInputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.resetPanelState();
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

  private currentDynamicToolConnect(): A2uiDynamicToolConnectData | null {
    const model = this.parsedDataModel();
    if (model === null || model.dynamicToolConnect === undefined || model.dynamicToolConnect === null) {
      return null;
    }
    return model.dynamicToolConnect;
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

  private rememberSocialReturnSurface(): void {
    if (this.currentSurface.intent === 'social') {
      return;
    }
    this.socialReturnSurface = this.surfaceSnapshot(this.currentSurface);
    this.socialReturnInputText = this.inputText;
    this.socialReturnInputPlaceholder = this.inputPlaceholder;
    this.hasSocialReturnSurface = true;
  }

  private restoreSocialReturnSurface(): void {
    if (!this.hasSocialReturnSurface) {
      return;
    }
    const surface = this.surfaceSnapshot(this.socialReturnSurface);
    this.selectedSocialMessageId = '';
    this.selectedSocialConversationTitle = '';
    this.inputText = this.socialReturnInputText;
    this.inputPlaceholder = this.socialReturnInputPlaceholder.length > 0 ? this.socialReturnInputPlaceholder : DEFAULT_INPUT_PLACEHOLDER;
    this.hasSocialReturnSurface = false;
    this.applySurface(surface);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '已返回上一页。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private handleSocialNavigation(): void {
    if (this.currentSurface.intent === 'social' && this.hasSocialReturnSurface) {
      this.restoreSocialReturnSurface();
      return;
    }
    this.openSocialInbox();
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
      const code = businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString();
      const message = code === '201' ?
        '通知订阅不可用：权限被拒绝，或当前 PC 系统未向三方应用开放通知内容订阅' :
        ('通知订阅授权页打开失败：' + businessError.message);
      this.socialLastCapture = message;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: code === '201' ? '当前设备不支持通知订阅桥接。' : '通知授权不可用。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][SocialNotificationSettingsError] code=' + code +
        ' message=' + businessError.message);
    }
  }

  private async openExternalUrl(url: string): Promise<void> {
    if (url.length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
      aiLogInfo('[AIPhone][A2uiHomeOpenUrl] ok=true url=' + url);
    } catch (error) {
      const businessError = error as BusinessError;
      const message = '外部页面打开失败：' + businessError.message;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '无法打开外部页面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false url=' + url + ' message=' + businessError.message);
    }
  }

  private openSocialInbox(): void {
    this.rememberSocialReturnSurface();
    const archive = this.readSocialNotificationArchive();
    const wechatProbe = detectWechatBundleSync();
    const accessibilityProbe = detectSocialAccessibilitySync();
    aiLogInfo('[AIPhone][SocialWechatProbe] installed=' + wechatProbe.installed.toString() +
      ' bundle=' + wechatProbe.bundleName +
      ' detail=' + wechatProbe.detail);
    aiLogInfo('[AIPhone][SocialAccessibilityProbe] available=' + accessibilityProbe.available.toString() +
      ' detail=' + accessibilityProbe.detail);
    const notificationCandidates = archive.ok ? archive.candidates.filter(candidate => candidate.source === 'notification') : [];
    const accessibilityCandidates = archive.ok ? archive.candidates.filter(candidate => candidate.source === 'accessibility') : [];
    const notificationUnavailable = archive.ok ?
      SOCIAL_NOTIFICATION_UNSUPPORTED_HINT :
      ('通知中心缓存读取失败：' + archive.error);
    const notification = new NotificationIngestProvider(notificationCandidates.length > 0, notificationUnavailable, notificationCandidates).capture();
    const accessibilityUnavailable = archive.ok ? accessibilityProbe.detail : ('辅助缓存读取失败：' + archive.error);
    const accessibility = new AccessibilityIngestProvider(accessibilityProbe.available || accessibilityCandidates.length > 0,
      accessibilityUnavailable, accessibilityCandidates).capture();
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
      notificationBridgeDetail: notification.ok ? '已读取真实通知缓存' : notification.error,
      accessibilityAvailable: accessibility.ok,
      accessibilityDetail: accessibility.ok ? accessibilityProbe.detail + '；缓存 ' + accessibility.messages.length.toString() + ' 条' : accessibility.error,
      wechatInstalled: wechatProbe.installed || notification.messages.length > 0 || accessibility.messages.length > 0,
      wechatBundleName: wechatProbe.bundleName,
      wechatDetectionDetail: wechatProbe.detail,
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
    this.inputText = inputTextAfterPromptSubmit(this.inputText);
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

  private async submitPrompt(prompt: string, visibleText: string, actionId: string = '', actionArgs: Object | null = null): Promise<void> {
    const trimmed = prompt.trim();
    if (trimmed.length === 0 || this.isBusy) {
      return;
    }
    const modelPrompt = modelPromptWithActionContext(trimmed, actionId, actionArgs);
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
    aiLogInfo('[AIPhone][A2uiHomeSubmitPrompt] chars=' + modelPrompt.length.toString() +
      ' model=' + this.selectedModel +
      ' baseUrl=' + this.baseUrl);
    this.inputText = inputTextAfterPromptSubmit(this.inputText);
    this.isBusy = true;
    this.isAwaitingFirstSurface = true;
    this.markChecking('正在生成 A2UI...');
    try {
      const result: A2uiCallResult = await callLocalModel(
        this.getSettings(),
        modelPrompt,
        this.recentMessages(),
        (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => {
          this.isAwaitingFirstSurface = false;
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
        null
      );
      this.isAwaitingFirstSurface = false;
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
        await this.callModelRequestedTool(result.surface, modelPrompt, actionId, actionArgs);
      } else {
        const fallbackRequest: A2uiHomeResolvedToolRequest = resolveA2uiHomeToolRequest(result.surface, modelPrompt, actionId, actionArgs);
        if (fallbackRequest.hasTool) {
          aiLogInfo('[AIPhone][A2uiHomeToolRequestByIntent] toolId=' + fallbackRequest.toolId +
            ' reason=model_failed promptChars=' + fallbackRequest.prompt.length.toString());
          await this.callToolById(fallbackRequest.toolId, fallbackRequest.prompt, fallbackRequest.actionId, fallbackRequest.args);
        } else {
          this.appendMessage('assistant', 'A2UI 生成失败：' + result.error);
        }
      }
    } catch (error) {
      this.isAwaitingFirstSurface = false;
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
      this.isAwaitingFirstSurface = false;
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

  private htmlPinPayload(action: A2uiAction): HtmlPinPayload {
    if (action.prompt.trim().charAt(0) !== '{') {
      return { index: action.prompt };
    }
    try {
      const payload = JSON.parse(action.prompt) as HtmlPinPayload;
      return payload === null ? { index: action.prompt } : payload;
    } catch (_error) {
      return { index: action.prompt };
    }
  }

  private htmlActionIndex(action: A2uiAction, payload: HtmlPinPayload): number {
    const payloadValue = Number.parseInt(this.actionText(payload.index), 10);
    if (payloadValue === payloadValue && payloadValue >= 0) {
      return payloadValue;
    }
    const value = Number.parseInt(action.prompt, 10);
    return value === value && value >= 0 ? value : -1;
  }

  private htmlPinTravelMatches(item: A2uiTravelOptionData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTravelPayloadHasIdentity(payload)) {
      return false;
    }
    const id = this.actionText(payload.id);
    const source = this.actionText(payload.source);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return id === this.actionText(item.id) &&
      source === this.actionText(item.source) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinTrainMatches(item: A2uiTrainData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTrainPayloadHasIdentity(payload)) {
      return false;
    }
    const trainCode = this.actionText(payload.trainCode);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return trainCode === this.actionText(item.trainCode) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinFlightMatches(item: A2uiFlightData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFlightPayloadHasIdentity(payload)) {
      return false;
    }
    const flightNo = this.actionText(payload.flightNo);
    const depTime = this.actionText(payload.depTime);
    const dep = this.actionText(payload.dep);
    const arr = this.actionText(payload.arr);
    return flightNo === this.actionText(item.flightNo) &&
      depTime === this.actionText(item.depTime) &&
      dep === this.actionText(item.dep) &&
      arr === this.actionText(item.arr);
  }

  private htmlPinFoodMatches(item: A2uiFoodData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFoodPayloadHasIdentity(payload)) {
      return false;
    }
    const name = this.actionText(payload.name);
    const address = this.actionText(payload.address);
    const location = this.actionText(payload.location);
    const distance = this.actionText(payload.distance);
    return name === this.actionText(item.name) &&
      address === this.actionText(item.address) &&
      location === this.actionText(item.location) &&
      distance === this.actionText(item.distance);
  }

  private htmlPinTravelPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.id).length + this.actionText(payload.source).length +
      this.actionText(payload.depart).length + this.actionText(payload.from).length +
      this.actionText(payload.to).length > 0;
  }

  private htmlPinTrainPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.trainCode).length + this.actionText(payload.depart).length +
      this.actionText(payload.from).length + this.actionText(payload.to).length > 0;
  }

  private htmlPinFlightPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.flightNo).length + this.actionText(payload.depTime).length +
      this.actionText(payload.dep).length + this.actionText(payload.arr).length > 0;
  }

  private htmlPinFoodPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.name).length + this.actionText(payload.address).length +
      this.actionText(payload.location).length + this.actionText(payload.distance).length > 0;
  }

  private htmlPinTravelRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTravelOptionData | null {
    if (!Array.isArray(model.travelOptions)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.travelOptions.length; rowIndex++) {
      if (this.htmlPinTravelMatches(model.travelOptions[rowIndex], payload)) {
        return model.travelOptions[rowIndex];
      }
    }
    if (this.htmlPinTravelPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.travelOptions.length ? model.travelOptions[index] : null;
  }

  private htmlPinTrainRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTrainData | null {
    if (!Array.isArray(model.trains)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.trains.length; rowIndex++) {
      if (this.htmlPinTrainMatches(model.trains[rowIndex], payload)) {
        return model.trains[rowIndex];
      }
    }
    if (this.htmlPinTrainPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.trains.length ? model.trains[index] : null;
  }

  private htmlPinFlightRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFlightData | null {
    if (!Array.isArray(model.flights)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.flights.length; rowIndex++) {
      if (this.htmlPinFlightMatches(model.flights[rowIndex], payload)) {
        return model.flights[rowIndex];
      }
    }
    if (this.htmlPinFlightPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.flights.length ? model.flights[index] : null;
  }

  private htmlPinFoodRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFoodData | null {
    if (!Array.isArray(model.foods)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.foods.length; rowIndex++) {
      if (this.htmlPinFoodMatches(model.foods[rowIndex], payload)) {
        return model.foods[rowIndex];
      }
    }
    if (this.htmlPinFoodPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.foods.length ? model.foods[index] : null;
  }

  private logHtmlHomeActionError(action: A2uiAction, reason: string): void {
    aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id +
      ' ok=false reason=' + reason +
      ' promptChars=' + action.prompt.length.toString());
  }

  private async handleHtmlPinAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_pin_travel' && action.id !== 'html_pin_train' &&
      action.id !== 'html_pin_flight' && action.id !== 'html_pin_food') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    if (action.id === 'html_pin_travel') {
      const row = this.htmlPinTravelRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_travel_row');
        return true;
      }
      await this.pinTravelNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_train') {
      const row = this.htmlPinTrainRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_train_row');
        return true;
      }
      await this.pinTrainNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_flight') {
      const row = this.htmlPinFlightRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_flight_row');
        return true;
      }
      await this.pinFlightNavigationCard(row);
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    await this.pinNavigationCard(row);
    return true;
  }

  private async handleHtmlFoodMapAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_open_food_map') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    const uri = buildSystemFoodNavigationUri(this.actionText(row.location), '', row.name);
    if (uri.length === 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '缺少真实坐标，不能打开地图。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.logHtmlHomeActionError(action, 'missing_food_coordinate');
      return true;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      try {
        await context.openLink(uri);
      } catch (_linkError) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: uri
        });
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开系统地图：' + row.name,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][HtmlHomeFoodMap] ok=true uriChars=' + uri.length.toString() + ' name=' + row.name);
    } catch (error) {
      const businessError = error as BusinessError;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '地图打开失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: businessError.message
      }));
      aiLogError('[AIPhone][HtmlHomeFoodMap] ok=false message=' + businessError.message);
    }
    return true;
  }

  private actionText(value: HtmlActionValue): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }
    return '';
  }

  private async saveDynamicCredentialAndTest(action: A2uiAction): Promise<void> {
    let payload: HtmlDynamicCredentialPayload;
    try {
      payload = JSON.parse(action.prompt) as HtmlDynamicCredentialPayload;
    } catch (_error) {
      this.logHtmlHomeActionError(action, 'invalid_dynamic_payload');
      return;
    }
    const credentialRef = this.actionText(payload.credentialRef);
    const credentialValue = this.actionText(payload.credentialValue).trim();
    const data = this.currentDynamicToolConnect();
    let toolId = this.actionText(payload.toolId);
    let testPrompt = this.actionText(payload.prompt);
    if (toolId.length === 0 && data !== null) {
      toolId = data.toolId;
    }
    if (testPrompt.length === 0 && data !== null) {
      testPrompt = data.prompt;
    }
    if (testPrompt.length === 0) {
      testPrompt = toolId;
    }
    if (data === null || credentialRef !== data.credentialRef || toolId !== data.toolId) {
      this.logHtmlHomeActionError(action, 'dynamic_credential_not_allowed');
      return;
    }
    if (credentialRef.length === 0 || credentialValue.length === 0 || toolId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_dynamic_credential');
      return;
    }
    try {
      await new AssetCredentialStore().put(credentialRef, credentialValue);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'checking',
        message: '已保存到本机，正在测试连接。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      await this.callToolById(toolId, testPrompt, 'dynamic_test_connection');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '凭据保存失败，请检查本机安全存储状态。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id + ' ok=false reason=credential_save_failed message=' + message);
    }
  }

  private async handleClientAction(action: A2uiAction): Promise<void> {
    aiLogInfo('[AIPhone][A2uiHomeClientAction] id=' + action.id);
    if (await this.handleHtmlFoodMapAction(action)) {
      return;
    }
    if (await this.handleHtmlPinAction(action)) {
      return;
    }
    if (action.id === 'html_dynamic_save_and_test') {
      await this.saveDynamicCredentialAndTest(action);
      return;
    }
    if (action.id === 'gmail.authorize') {
      const authorizeUrl = await prepareGmailOAuthAuthorizationUrl();
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL);
      return;
    }
    if (action.id === 'gmail.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GMAIL_WEB_URL);
      return;
    }
    if (action.id === 'social_select_message') {
      this.selectSocialMessageById(action.prompt);
      return;
    }
    if (action.id === 'social_open_notification_settings') {
      await this.openSocialNotificationSubscriptionSettings();
      return;
    }
    if (action.id === 'dynamic_open_registration') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'dynamic_test_connection') {
      const data = this.currentDynamicToolConnect();
      if (data === null || data.toolId.length === 0) {
        return;
      }
      const testPrompt = action.prompt.length > 0 ? action.prompt : (data.prompt.length > 0 ? data.prompt : data.toolId);
      await this.callToolById(data.toolId, testPrompt, action.id);
      return;
    }
  }

  private navigationCardStore(): PreferencesNavigationCardSnapshotStore {
    const context = this.getUIContext().getHostContext() as common.Context;
    return new PreferencesNavigationCardSnapshotStore(context);
  }

  private async refreshNavigationCardForms(snapshot: NavigationCardSnapshot): Promise<void> {
    const store = this.navigationCardStore();
    const formIds = await store.getFormIds();
    if (formIds.length === 0) {
      aiLogInfo('[AIPhone][NavigationCardRefresh] noForms title=' + snapshot.title);
      return;
    }
    const binding = formBindingData.createFormBindingData(buildNavigationCardBindingData(snapshot, Date.now()));
    for (let index = 0; index < formIds.length; index++) {
      const formId = formIds[index];
      try {
        await formProvider.updateForm(formId, binding);
        aiLogInfo('[AIPhone][NavigationCardRefresh] formId=' + formId + ' ok=true');
      } catch (error) {
        const businessError = error as BusinessError;
        aiLogError('[AIPhone][NavigationCardRefresh] formId=' + formId +
          ' ok=false code=' + (businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString()) +
          ' message=' + businessError.message);
      }
    }
  }

  private async saveNavigationCardResult(result: NavigationCardSnapshotBuildResult, label: string): Promise<void> {
    if (!result.ok || result.snapshot === undefined) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: result.error,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false label=' + label + ' reason=' + result.error);
      return;
    }
    try {
      const store = this.navigationCardStore();
      await store.saveSnapshot(result.snapshot);
      await this.refreshNavigationCardForms(result.snapshot);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已固定为桌面导航卡片：' + (result.snapshot.cardStyle === 'travel' ? result.snapshot.routeText : result.snapshot.title),
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][NavigationCardPin] ok=true title=' + result.snapshot.title +
        ' cardStyle=' + result.snapshot.cardStyle +
        ' transport=' + result.snapshot.transport +
        ' sourceTags=' + result.snapshot.sourceTags.join('/') +
        ' mapUriChars=' + result.snapshot.mapUri.length.toString());
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '导航卡片保存失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false saveError=' + message);
    }
  }

  private async pinNavigationCard(item: A2uiFoodData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFoodOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'food.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'food');
  }

  private async pinTravelNavigationCard(item: A2uiTravelOptionData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTravelOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'travel.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), item.source === 'flight' ? 'travel-flight' : 'travel-train');
  }

  private async pinTrainNavigationCard(item: A2uiTrainData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTrainOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'train.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'train');
  }

  private async pinFlightNavigationCard(item: A2uiFlightData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFlightOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'flight.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'flight');
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
    if (this.isBusy) {
      aiLogInfo('[AIPhone][A2uiHomeActionIgnored] id=' + action.id + ' reason=busy');
      return;
    }
    if (!isHtmlHomeActionAllowed(this.currentHtmlHomeDocument(), action)) {
      this.logHtmlHomeActionError(action, 'not_allowed');
      return;
    }
    const kind = action.kind.length > 0 ? action.kind : 'prompt';
    if (kind === 'client') {
      await this.handleClientAction(action);
      return;
    }
    if (kind === 'input') {
      this.focusEditQuery(action.id);
      return;
    }
    await this.submitPrompt(action.prompt, action.label, action.id, action.args === undefined ? null : action.args);
  }

  private toolSurfaceId(): string {
    if (this.currentSurface.surfaceId.length === 0 || this.currentSurface.status === 'error') {
      return 'surface_model';
    }
    return this.currentSurface.surfaceId;
  }

  private async callModelRequestedTool(
    surface: A2uiSurfaceState,
    fallbackPrompt: string,
    fallbackActionId: string,
    fallbackArgs: Object | null = null
  ): Promise<void> {
    const request: A2uiHomeResolvedToolRequest = resolveA2uiHomeToolRequest(surface, fallbackPrompt, fallbackActionId, fallbackArgs);
    if (!request.hasTool) {
      aiLogInfo('[AIPhone][A2uiHomeToolRequest] none');
      return;
    }
    aiLogInfo('[AIPhone][A2uiHomeToolRequestFromModel] toolId=' + request.toolId +
      ' modelPromptChars=' + request.modelPromptChars.toString() +
      ' userPromptChars=' + fallbackPrompt.length.toString() +
      ' sentPromptChars=' + request.prompt.length.toString());
    await this.callToolById(request.toolId, request.prompt, request.actionId, request.args);
  }

  private async callToolById(toolId: string, prompt: string, actionId: string, args: Object | null = null): Promise<boolean> {
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
    configureLocalToolDebugConfig({
      foodProviderDelayEnabled: this.foodProviderDelayEnabled,
      foodProviderDelayMs: normalizeFoodProviderDelayMs(this.foodProviderDelayMs),
      foodPartialThrottleMs: normalizeFoodPartialThrottleMs(this.foodPartialThrottleMs)
    });
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
      null,
      args
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
      requestDebug: result.requestDebug,
      assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
      error: result.error
    }));
    if (!result.ok) {
      this.appendMessage('assistant', '工具返回异常：' + result.error);
      return false;
    }
    this.appendMessage('assistant', result.surface.title + ' 已返回 A2UI 结果。');
    if (toolId === 'gmail.open.web') {
      await this.openExternalUrl(GMAIL_WEB_URL);
    }
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
        foodProviderDelayEnabled: $foodProviderDelayEnabled,
        foodProviderDelayMs: $foodProviderDelayMs,
        foodPartialThrottleMs: $foodPartialThrottleMs,
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
        htmlHomeHtml: this.currentHtmlHomeHtml(),
        surfaceRenderTick: this.surfaceRenderTick,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputPlaceholder: this.inputPlaceholder,
        isSocialReturnAvailable: this.hasSocialReturnSurface,
        showWelcome: shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface),
        onToggleHistory: () => {
          this.showHistory = !this.showHistory;
        },
        onOpenSocial: () => {
          this.handleSocialNavigation();
        },
        onOpenConfig: () => {
          this.showConfigPage = true;
        },
        onResetSession: () => {
          this.resetCurrentSession();
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
