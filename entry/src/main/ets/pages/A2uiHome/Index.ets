import { LocalModelSettings, defaultLocalModelSettings } from '../../model/LocalModelSettings';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import {
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiDataValue,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData
} from '../../model/A2uiTypes';
import { A2uiStreamMeta, callLocalModel, modelThinkCloseSeen } from '../../model/LocalModelClient';
import { GMAIL_MCP_AUTH_SETUP_URL, GMAIL_WEB_URL, GOOGLE_CALENDAR_WEB_URL, GOOGLE_OAUTH_SETUP_URL } from '../../model/GmailToolA2ui';
import { A2uiSurfaceStore, createSeedA2uiSurface } from '../../model/A2uiSurfaceStore';
import {
  emptySocialHubDraft,
  SocialHubConnectionData,
  SocialHubDraftData,
  SocialHubItemData
} from '../../model/SocialHubTypes';
import { aiLogError, aiLogInfo } from '../../model/AiphoneLogger';
import { callToolGateway, configureLocalToolDebugConfig, defaultToolGatewayUrl, isRegisteredToolId, prepareGmailOAuthAuthorizationUrl, prepareGoogleOAuthAuthorizationUrl } from '../../model/ToolGatewayClient';
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
import { AssetCredentialStore } from '../../model/DynamicCredentialStore';
import { buildSystemFoodNavigationUri } from '../../model/FoodNavigation';
import { officialMediaVideoPlaybackUrl } from '../../model/MediaVideoToolA2ui';
import { startVoiceInputSession, VoiceInputResult, VoiceInputSession } from '../../model/VoiceInputBridge';
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
  updateConnectionPanelState,
  voiceInputTextAfterRecognition
} from './state/A2uiHomeState';
import { A2uiHomeResolvedToolRequest, resolveA2uiHomeToolRequest } from './render/A2uiHomeToolRequest';

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;
const DEFAULT_INPUT_PLACEHOLDER: string = '告诉 Appless Phone 你想完成什么';
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';
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
  @State apiKey: string = defaultLocalModelSettings().apiKey;
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
  @State isVoiceListening: boolean = false;
  @State voiceInputMessage: string = '';
  @State inputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  @State messages: A2uiMessage[] = [];
  private htmlHomeCacheKey: string = '';
  private htmlHomeCacheHtml: string = '';
  private voiceSession: VoiceInputSession | null = null;
  private voiceSessionSeq: number = 0;
  private voiceBaseInputText: string = '';
  private voiceStopRequested: boolean = false;
  private voiceCompletionHandled: boolean = false;

  private getSettings(): LocalModelSettings {
    return {
      provider: defaultLocalModelSettings().provider,
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

  private defaultSocialHubConnections(): SocialHubConnectionData[] {
    return [
      {
        platform: 'x',
        status: 'needs_auth',
        displayName: 'X',
        accountId: '',
        message: '等待授权接入'
      },
      {
        platform: 'slack',
        status: 'needs_auth',
        displayName: 'Slack',
        accountId: '',
        message: '等待授权接入'
      },
      {
        platform: 'wecom',
        status: 'needs_auth',
        displayName: '企业微信',
        accountId: '',
        message: '等待授权接入'
      }
    ];
  }

  private createSocialHubSurface(): A2uiSurfaceState {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_social_hub',
        root: 'root',
        title: 'SocialHub',
        intent: 'social',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_social_hub',
        components: [
          {
            id: 'root',
            component: A2UI_COMPONENT_SURFACE_ROOT,
            child: 'socialHub',
            title: 'SocialHub',
            status: 'ready'
          },
          {
            id: 'socialHub',
            component: A2UI_COMPONENT_SOCIAL_HUB,
            title: 'SocialHub',
            status: 'ready',
            dataPath: '/socialHub/items'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social_hub',
        path: '/socialHub/connections',
        value: this.defaultSocialHubConnections()
      }
    });
    return store.getSurface();
  }

  private openSocialHub(): void {
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.applySurface(this.createSocialHubSurface());
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: 'SocialHub 已打开；等待真实社交数据接入。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private applySocialHubData(path: string, value: A2uiDataValue): void {
    const store = new A2uiSurfaceStore();
    store.seed(this.currentSurface);
    const result = store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: this.currentSurface.surfaceId,
        path: path,
        value: value
      }
    });
    if (!result.ok) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'SocialHub 本地状态更新失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      return;
    }
    this.applySurface(store.getSurface());
  }

  private currentSocialHubItems(): SocialHubItemData[] {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null) {
      return [];
    }
    return Array.isArray(model.socialHub.items) ? model.socialHub.items : [];
  }

  private currentSocialHubSelected(): SocialHubItemData | null {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null ||
      model.socialHub.selected === undefined || model.socialHub.selected === null ||
      model.socialHub.selected.id.length === 0) {
      return null;
    }
    return model.socialHub.selected;
  }

  private findSocialHubItem(itemId: string): SocialHubItemData | null {
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].id === itemId) {
        return items[index];
      }
    }
    return null;
  }

  private findSocialHubItemByUrl(url: string): SocialHubItemData | null {
    if (url.length === 0) {
      return null;
    }
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].url === url) {
        return items[index];
      }
    }
    return null;
  }

  private hasSocialHubComponent(): boolean {
    for (let index = 0; index < this.currentSurface.components.length; index++) {
      if (this.currentSurface.components[index].component === A2UI_COMPONENT_SOCIAL_HUB) {
        return true;
      }
    }
    return false;
  }

  private isCurrentSocialHubSurface(): boolean {
    const model = this.parsedDataModel();
    return this.currentSurface.intent === 'social' &&
      this.hasSocialHubComponent() &&
      model !== null &&
      model.socialHub !== undefined &&
      model.socialHub !== null &&
      Array.isArray(model.socialHub.items);
  }

  private socialHubDraftError(itemId: string, message: string): SocialHubDraftData {
    const selected = this.currentSocialHubSelected();
    return {
      itemId: itemId,
      platform: selected === null ? 'unknown' : selected.platform,
      text: '',
      status: 'error',
      error: message,
      localOnly: true,
      sent: false
    };
  }

  private socialHubDraftSnippet(text: string): string {
    const trimmed = text.trim();
    if (trimmed.length <= 80) {
      return trimmed;
    }
    return trimmed.substring(0, 80) + '...';
  }

  private selectSocialHubItem(action: A2uiAction): void {
    const item = this.findSocialHubItem(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(action.prompt, '未找到这条真实消息，无法选择。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
  }

  private draftSocialHubReply(action: A2uiAction): void {
    const selected = this.currentSocialHubSelected();
    const itemId = action.prompt.length > 0 ? action.prompt : (selected === null ? '' : selected.id);
    if (itemId.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '请先选择一条真实消息，再生成草稿。'));
      return;
    }
    const item = this.findSocialHubItem(itemId);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '未找到这条真实消息，不能生成草稿。'));
      return;
    }
    const sourceText = item.text.trim();
    if (sourceText.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '选中消息没有正文，不能生成本地草稿预览。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
    const draft: SocialHubDraftData = emptySocialHubDraft();
    draft.itemId = item.id;
    draft.platform = item.platform;
    draft.status = 'draft';
    draft.text = '本地草稿预览（未发送）：\n\n我会基于这条真实消息回复：' + this.socialHubDraftSnippet(sourceText);
    this.applySocialHubData('/socialHub/draft', draft);
  }

  private async openSocialHubSource(action: A2uiAction): Promise<void> {
    const item = this.findSocialHubItemByUrl(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '这条消息没有匹配的来源 URL。'));
      return;
    }
    await this.openExternalUrl(item.url);
  }

  private isSocialHubActionId(action: A2uiAction): boolean {
    return action.kind === 'client' &&
      (action.id === 'social_hub_select_item' ||
        action.id === 'social_hub_draft_reply' ||
        action.id === 'social_hub_open_source');
  }

  private isSocialHubClientAction(action: A2uiAction): boolean {
    return this.isSocialHubActionId(action) && this.isCurrentSocialHubSurface();
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

  private currentDynamicToolConnect(): A2uiDynamicToolConnectData | null {
    const model = this.parsedDataModel();
    if (model === null || model.dynamicToolConnect === undefined || model.dynamicToolConnect === null) {
      return null;
    }
    return model.dynamicToolConnect;
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
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private currentVoiceSession(seq: number): boolean {
    return this.isVoiceListening && this.voiceSessionSeq === seq && !this.voiceCompletionHandled;
  }

  private voiceLiveLabel(text: string): string {
    const next = text.trim();
    return next.length > 0 ? next : '语音识别中';
  }

  private finishVoiceInputWithResult(seq: number, result: VoiceInputResult): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const next = voiceInputTextAfterRecognition(this.voiceBaseInputText, result.text);
    if (next === this.voiceBaseInputText) {
      this.voiceInputMessage = '没有识别到语音内容';
    } else {
      this.inputText = next;
      this.voiceInputMessage = '已加入输入框';
    }
    this.voiceSession = null;
    this.isVoiceListening = false;
  }

  private finishVoiceInputWithError(seq: number, error: Error | Object | string | number | boolean | null | undefined): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const serialized = error === null || error === undefined ? '' : JSON.stringify(error);
    const message = error instanceof Error ? error.message : (serialized === undefined ? '' : serialized);
    this.voiceInputMessage = message.length > 0 ? '语音输入失败：' + message : '语音输入失败';
    this.voiceSession = null;
    this.isVoiceListening = false;
  }

  private async startVoiceInput(): Promise<void> {
    if (this.isBusy || this.isVoiceListening) {
      return;
    }
    const seq = this.voiceSessionSeq + 1;
    this.voiceSessionSeq = seq;
    this.voiceSession = null;
    this.voiceBaseInputText = this.inputText;
    this.voiceStopRequested = false;
    this.voiceCompletionHandled = false;
    this.isVoiceListening = true;
    this.voiceInputMessage = '语音识别中';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await startVoiceInputSession(context, (text: string) => {
        if (this.currentVoiceSession(seq)) {
          this.voiceInputMessage = this.voiceLiveLabel(text);
        }
      });
      if (!this.currentVoiceSession(seq)) {
        session.stop().catch((_error: Error) => {});
        return;
      }
      this.voiceSession = session;
      session.result
        .then((result: VoiceInputResult) => {
          this.finishVoiceInputWithResult(seq, result);
        })
        .catch((error: Error) => {
          this.finishVoiceInputWithError(seq, error);
        });
      if (this.voiceStopRequested) {
        session.stop().catch((_error: Error) => {});
      }
    } catch (error) {
      this.finishVoiceInputWithError(seq, error as Error | Object | string | number | boolean | null | undefined);
    }
  }

  private stopVoiceInput(): void {
    if (!this.isVoiceListening) {
      return;
    }
    this.voiceStopRequested = true;
    if (this.voiceSession === null) {
      this.voiceInputMessage = '识别整理中';
      return;
    }
    if (this.voiceInputMessage === '语音识别中') {
      this.voiceInputMessage = '识别整理中';
    }
    this.voiceSession.stop().catch((_error: Error) => {});
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
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (action.id === 'social_hub_select_item') {
      this.selectSocialHubItem(action);
      return;
    }
    if (action.id === 'social_hub_draft_reply') {
      this.draftSocialHubReply(action);
      return;
    }
    if (action.id === 'social_hub_open_source') {
      await this.openSocialHubSource(action);
      return;
    }
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
    if (action.id === 'calendar.authorize') {
      const authorizeUrl = await prepareGoogleOAuthAuthorizationUrl(GOOGLE_OAUTH_SETUP_URL);
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GOOGLE_OAUTH_SETUP_URL);
      return;
    }
    if (action.id === 'calendar.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GOOGLE_CALENDAR_WEB_URL);
      return;
    }
    if (action.id === 'gmail.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GMAIL_WEB_URL);
      return;
    }
    if (action.id === 'maps.open.web') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'media.open.web') {
      const mediaUrl = officialMediaVideoPlaybackUrl(action.prompt);
      if (mediaUrl.length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_media_url');
        return;
      }
      await this.openExternalUrl(mediaUrl);
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
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (this.isSocialHubClientAction(action)) {
      await this.handleClientAction(action);
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
        htmlHomeHtml: this.currentSurface.intent === 'social' ? '' : this.currentHtmlHomeHtml(),
        surfaceRenderTick: this.surfaceRenderTick,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputPlaceholder: this.inputPlaceholder,
        isVoiceListening: this.isVoiceListening,
        voiceInputMessage: this.voiceInputMessage,
        showWelcome: shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface),
        onToggleHistory: () => {
          this.showHistory = !this.showHistory;
        },
        onOpenConfig: () => {
          this.showConfigPage = true;
        },
        onOpenSocialHub: () => {
          this.openSocialHub();
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
        onStartVoiceInput: () => {
          this.startVoiceInput();
        },
        onStopVoiceInput: () => {
          this.stopVoiceInput();
        },
        onAction: (action: A2uiAction) => {
          this.sendAction(action);
        }
      })
    }
  }
}
