import { LocalModelSettings, defaultLocalModelSettings } from '../model/LocalModelSettings';
import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_CONFIRM_PANEL,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2uiAction,
  A2uiComponent,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSurfaceState
} from '../model/A2uiTypes';
import {
  A2uiFlightOption,
  A2uiFoodOption,
  A2uiLabelValue,
  A2uiTrainOption,
  actionsOf,
  componentById,
  flightOptions,
  foodOptions,
  labelValues,
  resolveData,
  toolRequest,
  trainOptions
} from '../model/A2uiData';
import { createSeedA2uiSurface } from '../model/A2uiSurfaceStore';
import { A2uiStreamMeta, buildChatCompletionsUrl, callLocalModel, modelThinkCloseSeen } from '../model/LocalModelClient';
import { callToolGateway, defaultToolGatewayUrl, isLocalToolGatewayUrl, isRegisteredToolId, localProviderConfigDebugSummary } from '../model/ToolGatewayClient';
import { aiLogError, aiLogInfo } from '../model/AiphoneLogger';

const MODEL_QWEN: string = 'Qwen3-8B';
const MODEL_DEEPSEEK: string = 'DeepSeek-R1-Distill-Qwen-7B';
const URL_LOCAL_MODEL: string = 'http://127.0.0.1:11434';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const STREAM_SOURCE_MODEL: string = 'model';
const STREAM_SOURCE_TOOL: string = 'tool';
const DEBUG_SCROLL_MAX_HEIGHT: number = 120;
const DEBUG_SCROLL_MIN_HEIGHT: number = 56;

const COLOR_INK: string = '#F3FBFA';
const COLOR_TEXT: string = '#D4E5E6';
const COLOR_MUTED: string = '#8A9DA3';
const COLOR_LINE: string = '#263943';
const COLOR_PAGE: string = '#05080D';
const COLOR_PANEL: string = '#0D151C';
const COLOR_GLASS: string = '#111D25';
const COLOR_CARD: string = '#17252D';
const COLOR_CARD_RAISED: string = '#1D3039';
const COLOR_FIELD: string = '#091017';
const COLOR_CARD_EDGE: string = '#38545E';
const COLOR_CARD_TOP: string = '#213742';
const COLOR_CARD_INSET: string = '#0C161D';
const COLOR_EDGE_LIGHT: string = '#577680';
const COLOR_HIGHLIGHT_LINE: string = '#68F0DE66';
const COLOR_CARD_GLOW: string = '#0F4D4566';
const COLOR_ACCENT_SHADOW: string = '#0B514880';
const COLOR_ACCENT: string = '#35D6B8';
const COLOR_ACCENT_DARK: string = '#83F2DC';
const COLOR_ACCENT_DEEP: string = '#0E6F62';
const COLOR_ACCENT_SOFT: string = '#102F2D';
const COLOR_BUTTON_TEXT: string = '#F7FFFD';
const COLOR_PROCESS: string = '#4FDBCA';
const COLOR_PROCESS_SOFT: string = '#123039';
const COLOR_PROCESS_TINT: string = '#0D171E';
const COLOR_PROCESS_LINE: string = '#2B7A72';
const COLOR_CARD_SHADOW: string = '#020B10D0';
const COLOR_PANEL_SHADOW: string = '#020B10C8';
const COLOR_ERROR: string = '#FF8A84';
const COLOR_ERROR_LINE: string = '#7B393A';
const FONT_THINK_DISPLAY: string = 'HarmonyOS Sans';
const FONT_THINK_STREAM: string = 'HarmonyOS Sans';
const COLOR_THINK_CARD: string = '#14212A';
const COLOR_THINK_CARD_BORDER: string = '#2B424B';
const COLOR_THINK_STREAM_BG: string = '#0B141B';
const COLOR_THINK_STREAM_BORDER: string = '#243740';
const COLOR_THINK_STREAM_INK: string = '#DDF6F2';
const COLOR_THINK_STREAM_MUTED: string = '#91A6AA';
const COLOR_THINK_STREAM_ACCENT: string = '#60E4D2';
const COLOR_ERROR_SOFT: string = '#351B1D';
const COLOR_CHROME: string = '#1B2A33';
const TRAIN_INITIAL_VISIBLE: number = 6;
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';

function messageId(): string {
  return Date.now().toString() + '-' + Math.random().toString();
}

function createMessage(role: string, content: string): A2uiMessage {
  return {
    id: messageId(),
    role: role,
    content: content
  };
}

function seedMessages(): A2uiMessage[] {
  return [
    createMessage('assistant', 'AIPhone 已就绪。')
  ];
}

@Entry
@Component
struct Index {
  @State currentSurface: A2uiSurfaceState = createSeedA2uiSurface();
  @State surfaceComponents: A2uiComponent[] = createSeedA2uiSurface().components;
  @State surfaceDataModelJson: string = createSeedA2uiSurface().dataModelJson;
  @State messages: A2uiMessage[] = seedMessages();
  @State inputText: string = '帮我查询明天北京到上海高铁票';
  @State isBusy: boolean = false;
  @State statusText: string = '就绪';
  @State lastModelRawStream: string = '';
  @State lastToolRawStream: string = '';
  @State lastModelRequest: string = '';
  @State lastModelOutput: string = '';
  @State lastError: string = '';
  @State showConfigPage: boolean = false;
  @State showAdvancedSettings: boolean = false;
  @State showDiagnostics: boolean = false;
  @State showHistory: boolean = false;
  @State renderRevision: number = 0;
  @State liveThinkingText: string = '';
  @State persistedThinkingText: string = '';
  @State thinkingPanelExpanded: boolean = false;
  @State modelThinkingActive: boolean = false;
  @State modelThinkClosed: boolean = false;
  @State orbPulse: number = 1;
  @State orbOpacity: number = 0.72;
  @State thinkPulse: number = 1;
  @State thinkShimmer: number = 0;
  @State standbyAnimActive: boolean = false;
  @State thinkAnimActive: boolean = false;
  @State baseUrl: string = defaultLocalModelSettings().baseUrl;
  @State apiKey: string = '';
  @State selectedModel: string = MODEL_QWEN;
  @State trainVisibleCount: number = TRAIN_INITIAL_VISIBLE;
  @State trainSortMode: string = 'default';
  @State trainFilterAvailable: boolean = false;
  @State expandedTrainKey: string = '';
  @State inputPlaceholder: string = '告诉 AIPhone 你想完成什么';

  aboutToAppear(): void {
    this.startStandbyAnimation();
  }

  aboutToDisappear(): void {
    this.standbyAnimActive = false;
    this.thinkAnimActive = false;
  }

  private getSettings(): LocalModelSettings {
    return {
      provider: 'Huawei Local API',
      baseUrl: this.baseUrl,
      model: this.selectedModel,
      apiKey: this.apiKey
    };
  }

  private startStandbyAnimation(): void {
    this.standbyAnimActive = true;
    this.runStandbyPulse();
  }

  private runStandbyPulse(): void {
    if (!this.standbyAnimActive) {
      return;
    }
    const targetPulse = this.orbPulse < 1.02 ? 1.06 : 1;
    const targetOpacity = this.orbOpacity < 0.74 ? 0.9 : 0.68;
    animateTo({
      duration: 1400,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (this.standbyAnimActive) {
          this.runStandbyPulse();
        }
      }
    }, () => {
      this.orbPulse = targetPulse;
      this.orbOpacity = targetOpacity;
    });
  }

  private startThinkingAnimation(): void {
    if (this.thinkAnimActive) {
      return;
    }
    this.thinkAnimActive = true;
    this.runThinkingPulse();
    this.runThinkingShimmer();
  }

  private stopThinkingAnimation(): void {
    this.thinkAnimActive = false;
  }

  private runThinkingPulse(): void {
    if (!this.thinkAnimActive) {
      return;
    }
    const targetPulse = this.thinkPulse < 1.02 ? 1.08 : 1;
    animateTo({
      duration: 1200,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (this.thinkAnimActive) {
          this.runThinkingPulse();
        }
      }
    }, () => {
      this.thinkPulse = targetPulse;
    });
  }

  private runThinkingShimmer(): void {
    if (!this.thinkAnimActive) {
      return;
    }
    const targetShimmer = this.thinkShimmer < 12 ? 100 : 0;
    animateTo({
      duration: 1800,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (this.thinkAnimActive) {
          this.runThinkingShimmer();
        }
      }
    }, () => {
      this.thinkShimmer = targetShimmer;
    });
  }

  private isStandbyState(): boolean {
    return this.currentSurface.surfaceId === 'surface_seed'
      && this.currentSurface.status === 'idle'
      && !this.isBusy;
  }

  private isProcessingState(): boolean {
    if (this.isBusy) {
      return true;
    }
    const status = this.currentSurface.status;
    return status === 'calling_tool' || status === 'thinking' || status === 'pending';
  }

  private hasThinkingCard(): boolean {
    for (let index = 0; index < this.surfaceComponents.length; index++) {
      if (this.surfaceComponents[index].component === A2UI_COMPONENT_THINKING_CARD) {
        return true;
      }
    }
    return false;
  }

  private hasThinkingStream(): boolean {
    for (let index = 0; index < this.surfaceComponents.length; index++) {
      if (this.surfaceComponents[index].component === A2UI_COMPONENT_THINKING_STREAM) {
        return true;
      }
    }
    return false;
  }

  private hasActiveThinkingUi(): boolean {
    return this.shouldShowThinkingPanel() || this.modelThinkingActive;
  }

  private thinkingCardComponent(): A2uiComponent {
    for (let index = 0; index < this.surfaceComponents.length; index++) {
      if (this.surfaceComponents[index].component === A2UI_COMPONENT_THINKING_CARD) {
        return this.surfaceComponents[index];
      }
    }
    return {
      id: 'model_thinking_card',
      component: A2UI_COMPONENT_THINKING_CARD,
      title: '正在理解你的请求',
      body: '思考流写入中',
      status: 'thinking',
      dataPath: '/thoughts',
      actions: []
    };
  }

  private hasTaskContent(): boolean {
    if (this.hasTrainDataInModel()) {
      return true;
    }
    if (this.hasFlightDataInModel()) {
      return true;
    }
    if (this.hasFoodDataInModel()) {
      return true;
    }
    if (this.hasDirectRowsData()) {
      return true;
    }
    return false;
  }

  private isThinkingOnlySurface(): boolean {
    return false;
  }

  private syncLiveThinkingText(dataModelJson: string): void {
    try {
      const parsed = JSON.parse(dataModelJson) as A2uiRuntimeDataModel;
      if (Array.isArray(parsed.thoughts) && parsed.thoughts.length > 0) {
        if (parsed.thoughts.length === 1 && parsed.thoughts[0] === '等待模型响应') {
          this.liveThinkingText = '';
          return;
        }
        this.liveThinkingText = parsed.thoughts.join('');
        return;
      }
    } catch (_error) {
      this.liveThinkingText = '';
      return;
    }
    this.liveThinkingText = '';
  }

  private recentMessages(): A2uiMessage[] {
    if (this.messages.length > 8) {
      return this.messages.slice(this.messages.length - 8);
    }
    return this.messages;
  }

  private appendMessage(role: string, content: string): void {
    const next = this.messages.slice();
    next.push(createMessage(role, content));
    this.messages = next;
  }

  private applyProviderPreset(baseUrl: string, model: string): void {
    this.baseUrl = baseUrl;
    this.selectedModel = model;
    this.statusText = '配置已填入';
    this.lastError = '';
  }

  private surfaceIntentLabel(intent: string): string {
    if (intent === 'travel') {
      return '出行';
    }
    if (intent === 'food') {
      return '餐饮';
    }
    if (intent === 'setup') {
      return '连接';
    }
    return '任务';
  }

  private statusLabel(status: string): string {
    if (status === 'calling_tool') {
      return '调用工具';
    }
    if (status === 'thinking') {
      return '生成中';
    }
    if (status === 'needs_input') {
      return '待确认';
    }
    if (status === 'ready' || status === 'success') {
      return '已就绪';
    }
    if (status === 'error') {
      return '异常';
    }
    return '就绪';
  }

  private statusColor(status: string): string {
    if (status === 'error') {
      return COLOR_ERROR;
    }
    if (status === 'calling_tool' || status === 'thinking' || status === 'pending') {
      return COLOR_PROCESS;
    }
    if (status === 'needs_input') {
      return COLOR_ACCENT_DARK;
    }
    return COLOR_ACCENT_DARK;
  }

  private statusBackground(status: string): string {
    if (status === 'error') {
      return COLOR_ERROR_SOFT;
    }
    if (status === 'calling_tool' || status === 'thinking' || status === 'pending') {
      return COLOR_PROCESS_SOFT;
    }
    if (status === 'needs_input') {
      return COLOR_ACCENT_SOFT;
    }
    return COLOR_ACCENT_SOFT;
  }

  private actionBackground(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT_DEEP;
    }
    if (variant === 'danger') {
      return COLOR_ERROR_SOFT;
    }
    return COLOR_CARD_RAISED;
  }

  private actionTextColor(variant: string): string {
    if (variant === 'primary') {
      return COLOR_BUTTON_TEXT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_INK;
  }

  private actionBorder(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT;
    }
    if (variant === 'danger') {
      return COLOR_ERROR_LINE;
    }
    return COLOR_LINE;
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

  private collapseThinkingPanel(): void {
    this.modelThinkClosed = true;
    this.modelThinkingActive = false;
    this.thinkingPanelExpanded = false;
  }

  private applyModelThinkingStreamState(raw: string, meta?: A2uiStreamMeta): void {
    if (meta?.thinkClosed === true || modelThinkCloseSeen(raw)) {
      this.collapseThinkingPanel();
    }
    if (this.liveThinkingText.length > 0) {
      this.persistedThinkingText = this.liveThinkingText;
    }
    if (!this.modelThinkClosed && this.liveThinkingText.length > 0) {
      this.modelThinkingActive = true;
      this.thinkingPanelExpanded = true;
    }
  }

  private updateSurfaceFromStream(surface: A2uiSurfaceState, raw: string, source: string, meta?: A2uiStreamMeta): void {
    aiLogInfo('[AIPhone][SurfaceUpdate] surfaceId=' + surface.surfaceId + ' status=' + surface.status + ' components=' + surface.components.length.toString() + ' dataChars=' + surface.dataModelJson.length.toString() + ' rawChars=' + raw.length.toString() + ' source=' + source);
    const priorPersistedThinking = this.persistedThinkingText;
    const nextSurface = this.surfaceSnapshot(surface);
    this.currentSurface = nextSurface;
    this.surfaceComponents = nextSurface.components;
    this.surfaceDataModelJson = nextSurface.dataModelJson;
    this.renderRevision = this.renderRevision + 1;
    this.syncLiveThinkingText(nextSurface.dataModelJson);
    if (source === STREAM_SOURCE_MODEL) {
      this.lastModelRawStream = raw;
      this.applyModelThinkingStreamState(raw, meta);
    } else if (source === STREAM_SOURCE_TOOL) {
      this.lastToolRawStream = raw;
      this.modelThinkingActive = false;
      this.thinkingPanelExpanded = false;
      if (priorPersistedThinking.length > 0) {
        this.persistedThinkingText = priorPersistedThinking;
        this.liveThinkingText = priorPersistedThinking;
      }
      if (nextSurface.dataModelJson.indexOf('"trainCode"') >= 0) {
        this.resetTrainViewState();
      }
    }
    this.statusText = this.statusLabel(nextSurface.status);
    // #region agent log
    aiLogInfo('[Debug65c5d6][H-UI] source=' + source + ' route=' + this.debugUiRouteTag() +
      ' trains=' + (this.hasTrainDataInModel() ? '1' : '0') +
      ' rows=' + (this.hasDirectRowsData() ? '1' : '0') +
      ' components=' + nextSurface.components.length.toString());
    if (source === STREAM_SOURCE_TOOL && this.hasFoodDataInModel()) {
      const foodComponent = this.componentWithType(A2UI_COMPONENT_FOOD_CHOICES, 'food_direct');
      const foods = foodOptions(nextSurface, foodComponent);
      aiLogInfo('[Debug65c5d6][H-FOOD-UI] count=' + foods.length.toString() +
        ' seq=' + nextSurface.sequence.toString());
    }
    // #endregion
    if (nextSurface.error.length > 0) {
      this.lastError = nextSurface.error;
    }
    if (this.modelThinkingActive) {
      this.startThinkingAnimation();
    } else {
      this.stopThinkingAnimation();
    }
  }

  private hasThinkingCardInSurface(surface: A2uiSurfaceState): boolean {
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].component === A2UI_COMPONENT_THINKING_CARD) {
        return true;
      }
    }
    return false;
  }

  private surfaceForRender(): A2uiSurfaceState {
    return {
      surfaceId: this.currentSurface.surfaceId,
      rootId: this.currentSurface.rootId,
      title: this.currentSurface.title,
      intent: this.currentSurface.intent,
      status: this.currentSurface.status,
      components: this.cloneSurfaceComponents(this.currentSurface.components),
      dataModelJson: this.currentSurface.dataModelJson,
      error: this.currentSurface.error,
      sequence: this.currentSurface.sequence + this.renderRevision
    };
  }

  private hasComponent(surface: A2uiSurfaceState, id: string): boolean {
    return componentById(surface, id) !== null;
  }

  private componentOrFallback(surface: A2uiSurfaceState, id: string): A2uiComponent {
    const found = componentById(surface, id);
    if (found !== null) {
      return found;
    }
    return {
      id: 'missing_' + id,
      component: A2UI_COMPONENT_ERROR_NOTICE,
      title: '组件缺失',
      body: 'A2UI 引用了不存在的组件：' + id,
      status: 'error',
      actions: []
    };
  }

  private componentWithType(componentType: string, fallbackId: string): A2uiComponent {
    for (let index = 0; index < this.currentSurface.components.length; index++) {
      if (this.currentSurface.components[index].component === componentType) {
        return this.currentSurface.components[index];
      }
    }
    return {
      id: fallbackId,
      component: componentType,
      title: this.currentSurface.title,
      body: '',
      status: this.currentSurface.status,
      dataPath: componentType === A2UI_COMPONENT_TRAIN_OPTIONS ? '/trains' : (componentType === A2UI_COMPONENT_FLIGHT_BOARD ? '/flights' : (componentType === A2UI_COMPONENT_FOOD_CHOICES ? '/foods' : '/rows')),
      actions: []
    };
  }

  private directRowsComponent(): A2uiComponent {
    return {
      id: 'rows_direct',
      component: A2UI_COMPONENT_INFO_ROWS,
      title: this.currentSurface.title.length > 0 ? this.currentSurface.title : '整理结果',
      body: '',
      status: this.currentSurface.status,
      dataPath: '/rows',
      actions: []
    };
  }

  private parsedDataModel(): A2uiRuntimeDataModel | null {
    try {
      return JSON.parse(this.currentSurface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return null;
    }
  }

  private hasTrainDataInModel(): boolean {
    const model = this.parsedDataModel();
    return model !== null && Array.isArray(model.trains) && model.trains.length > 0;
  }

  private hasFlightDataInModel(): boolean {
    const model = this.parsedDataModel();
    return model !== null && Array.isArray(model.flights) && model.flights.length > 0;
  }

  private hasFoodDataInModel(): boolean {
    const model = this.parsedDataModel();
    return model !== null && Array.isArray(model.foods) && model.foods.length > 0;
  }

  private hasDirectRowsData(): boolean {
    if (this.currentSurface.surfaceId === 'surface_seed') {
      return false;
    }
    const model = this.parsedDataModel();
    return model !== null && Array.isArray(model.rows) && model.rows.length > 0;
  }

  private debugUiRouteTag(): string {
    if (this.hasTrainDataInModel()) {
      return 'train';
    }
    if (this.hasFlightDataInModel()) {
      return 'flight';
    }
    if (this.hasFoodDataInModel()) {
      return 'food';
    }
    if (this.hasDirectRowsData()) {
      return 'rows';
    }
    if (this.currentSurface.components.length === 0 && !this.hasThinkingCard()) {
      return 'empty-components';
    }
    if (!this.hasComponent(this.surfaceForRender(), this.surfaceForRender().rootId) && !this.hasThinkingCard()) {
      return 'missing-root';
    }
    return 'component-tree';
  }

  private componentTitle(component: A2uiComponent, fallback: string): string {
    if (component.title !== undefined && component.title.length > 0) {
      return component.title;
    }
    return fallback;
  }

  private componentBody(component: A2uiComponent, fallback: string = ''): string {
    if (component.body !== undefined && component.body.length > 0) {
      return component.body;
    }
    return fallback;
  }

  private componentText(component: A2uiComponent): string {
    if (component.text !== undefined && component.text.length > 0) {
      return component.text;
    }
    return this.componentBody(component);
  }

  private componentStatus(component: A2uiComponent): string {
    if (component.status !== undefined && component.status.length > 0) {
      return component.status;
    }
    return 'idle';
  }

  private componentVariant(component: A2uiComponent): string {
    if (component.variant !== undefined && component.variant.length > 0) {
      return component.variant;
    }
    return '';
  }

  private componentTone(component: A2uiComponent): string {
    if (component.tone !== undefined && component.tone.length > 0) {
      return component.tone;
    }
    return '';
  }

  private processingCardBackground(status: string): string {
    if (status === 'calling_tool' || status === 'thinking' || status === 'pending') {
      return COLOR_THINK_CARD;
    }
    return COLOR_GLASS;
  }

  private processingCardBorder(status: string): string {
    if (status === 'calling_tool' || status === 'thinking' || status === 'pending') {
      return COLOR_THINK_CARD_BORDER;
    }
    return COLOR_LINE;
  }

  private thinkingStatusAccent(status: string): string {
    if (status === 'calling_tool') {
      return COLOR_ACCENT_DARK;
    }
    return COLOR_THINK_STREAM_ACCENT;
  }

  private processingTitle(component: A2uiComponent): string {
    const status = this.componentStatus(component);
    const title = this.componentTitle(component, '');
    if (title.length > 0 && title !== 'AIPhone 正在处理') {
      return title;
    }
    if (status === 'calling_tool') {
      return '工具正在处理';
    }
    if (status === 'thinking') {
      return 'AIPhone 正在思考';
    }
    return '正在整理结果';
  }

  private thinkingDisplayText(): string {
    if (this.modelThinkingActive && this.liveThinkingText.trim().length > 0) {
      return this.liveThinkingText;
    }
    if (this.persistedThinkingText.trim().length > 0) {
      return this.persistedThinkingText;
    }
    if (this.liveThinkingText.trim().length > 0) {
      return this.liveThinkingText;
    }
    return '';
  }

  private thinkingPreviewText(): string {
    const text = this.thinkingDisplayText().trim();
    if (text.length === 0) {
      return '';
    }
    if (text.length <= 80) {
      return text;
    }
    return text.substring(0, 80) + '…';
  }

  private shouldShowThinkingPanel(): boolean {
    return this.thinkingDisplayText().trim().length > 0;
  }

  private toggleThinkingPanel(): void {
    this.thinkingPanelExpanded = !this.thinkingPanelExpanded;
  }

  private thinkingStreamText(surface: A2uiSurfaceState, component: A2uiComponent): string {
    const panelText = this.thinkingDisplayText();
    if (panelText.length > 0) {
      return panelText;
    }
    const thoughts = this.thoughtsOf(surface, component);
    if (thoughts.length === 0) {
      return '';
    }
    if (thoughts.length === 1 && thoughts[0] === '等待模型响应') {
      return '';
    }
    return thoughts.join('');
  }

  private hasThinkingStreamContent(surface: A2uiSurfaceState, component: A2uiComponent): boolean {
    return this.thinkingStreamText(surface, component).trim().length > 0;
  }

  private thinkingCardTitle(component: A2uiComponent): string {
    const title = this.componentTitle(component, '');
    if (title.length > 0) {
      return title;
    }
    return '正在理解你的请求';
  }

  private thinkingCardBody(component: A2uiComponent): string {
    const body = this.componentBody(component, '');
    if (body.length > 0) {
      return body;
    }
    return '思考流写入中';
  }

  private processingBody(component: A2uiComponent): string {
    const status = this.componentStatus(component);
    const body = this.componentBody(component, '');
    if (body.length > 0) {
      return body;
    }
    if (status === 'calling_tool') {
      return '正在等待工具返回，结果会自动更新到任务画布。';
    }
    if (status === 'thinking') {
      return '正在拆解你的请求，并生成可执行的 A2UI。';
    }
    return '新的内容正在到达。';
  }

  private componentChildren(component: A2uiComponent): string[] {
    if (component.children === undefined || component.children === null) {
      return [];
    }
    return component.children;
  }

  private componentChild(component: A2uiComponent): string {
    if (component.child === undefined) {
      return '';
    }
    return component.child;
  }

  private thoughtsOf(surface: A2uiSurfaceState, component: A2uiComponent): string[] {
    if (component.dataPath === '/thoughts') {
      return resolveData(surface, component.dataPath) as string[];
    }
    return [];
  }

  private async submitPrompt(prompt: string, visibleText: string, actionId: string = ''): Promise<void> {
    const trimmed = prompt.trim();
    if (trimmed.length === 0 || this.isBusy) {
      return;
    }
    aiLogInfo('[AIPhone][SubmitPrompt] actionId=' + actionId + ' chars=' + trimmed.length.toString());
    this.appendMessage('user', visibleText);
    this.inputText = '';
    this.isBusy = true;
    this.statusText = '正在生成';
    this.lastError = '';
    this.liveThinkingText = '';
    this.persistedThinkingText = '';
    this.thinkingPanelExpanded = false;
    this.modelThinkingActive = false;
    this.modelThinkClosed = false;

    try {
      if (this.baseUrl.trim().length === 0) {
        this.lastError = '请先填写本地模型服务的 Base URL。';
        this.statusText = '缺少配置';
        aiLogError('[AIPhone][SubmitBlocked] missingBaseUrl');
        return;
      }

      const result = await callLocalModel(this.getSettings(), trimmed, this.recentMessages(), (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => {
        this.updateSurfaceFromStream(surface, raw, STREAM_SOURCE_MODEL, meta);
      });
      aiLogInfo('[AIPhone][ModelResult] ok=' + (result.ok ? 'true' : 'false') + ' errorChars=' + result.error.length.toString() + ' assistantChars=' + result.assistantDebug.length.toString());
      this.lastModelRequest = result.requestDebug;
      this.lastModelOutput = result.assistantDebug;
      this.updateSurfaceFromStream(result.surface, result.raw, STREAM_SOURCE_MODEL, {
        thinkClosed: modelThinkCloseSeen(result.assistantDebug) || modelThinkCloseSeen(result.raw)
      });
      if (!this.modelThinkClosed && this.persistedThinkingText.length > 0) {
        this.collapseThinkingPanel();
      }
      this.statusText = this.statusLabel(result.surface.status);
      if (!result.ok) {
        this.lastError = result.error;
        this.appendMessage('assistant', 'A2UI 生成失败：' + result.error);
        return;
      }

      this.appendMessage('assistant', result.assistantDebug.length > 0 ? result.assistantDebug : result.surface.title);
      await this.callModelRequestedTool(result.surface, trimmed, actionId);
    } finally {
      this.isBusy = false;
    }
  }

  private async callModelRequestedTool(surface: A2uiSurfaceState, fallbackPrompt: string, fallbackActionId: string): Promise<void> {
    const request = toolRequest(surface);
    const toolId = request.toolId;
    const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
    const actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
    if (toolId.length === 0) {
      aiLogInfo('[AIPhone][ToolRequest] none');
      return;
    }
    aiLogInfo('[AIPhone][ToolRequestFromModel] toolId=' + toolId +
      ' modelPromptChars=' + request.prompt.length.toString() +
      ' userPromptChars=' + fallbackPrompt.length.toString() +
      ' sentPromptChars=' + prompt.length.toString());
    await this.callToolById(toolId, prompt, actionId);
  }

  private toolSurfaceId(): string {
    if (this.currentSurface.surfaceId.length === 0 || this.currentSurface.status === 'error') {
      return 'surface_model';
    }
    return this.currentSurface.surfaceId;
  }

  private async callToolById(toolId: string, prompt: string, actionId: string): Promise<boolean> {
    if (!isRegisteredToolId(toolId)) {
      this.lastError = '模型请求了未注册工具：' + toolId;
      aiLogError('[AIPhone][ToolRequestInvalid] toolId=' + toolId);
      return false;
    }
    aiLogInfo('[AIPhone][ToolRequest] toolId=' + toolId + ' promptChars=' + prompt.length.toString() + ' actionId=' + actionId);
    this.statusText = '正在调用工具';
    const result = await callToolGateway(TOOL_GATEWAY_URL, toolId, prompt, this.toolSurfaceId(), actionId, (surface: A2uiSurfaceState, raw: string) => {
      this.updateSurfaceFromStream(surface, raw, STREAM_SOURCE_TOOL);
    }, this.currentSurface);
    aiLogInfo('[AIPhone][ToolResult] ok=' + (result.ok ? 'true' : 'false') + ' errorChars=' + result.error.length.toString() + ' rawChars=' + result.raw.length.toString());
    this.updateSurfaceFromStream(result.surface, result.raw, STREAM_SOURCE_TOOL);
    this.statusText = this.statusLabel(result.surface.status);
    if (!result.ok) {
      this.lastError = result.error;
      this.appendMessage('assistant', '工具返回异常：' + result.error);
      return false;
    } else {
      this.appendMessage('assistant', result.surface.title + ' 已返回 A2UI 结果。');
      return true;
    }
  }

  private async sendPrompt(): Promise<void> {
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private resetTrainViewState(): void {
    this.trainVisibleCount = TRAIN_INITIAL_VISIBLE;
    this.trainSortMode = 'default';
    this.trainFilterAvailable = false;
    this.expandedTrainKey = '';
  }

  private trainRowKey(item: A2uiTrainOption): string {
    return item.trainCode + '|' + item.depart + '|' + item.from;
  }

  private parseDurationMinutes(duration: string): number {
    const colonMatch = duration.match(/^(\d{1,2}):(\d{2})$/);
    if (colonMatch !== null) {
      return Number.parseInt(colonMatch[1], 10) * 60 + Number.parseInt(colonMatch[2], 10);
    }
    let hours = 0;
    let minutes = 0;
    const hourMatch = duration.match(/(\d+)\s*小时/);
    if (hourMatch !== null) {
      hours = Number.parseInt(hourMatch[1], 10);
    }
    const minuteMatch = duration.match(/(\d+)\s*分/);
    if (minuteMatch !== null) {
      minutes = Number.parseInt(minuteMatch[1], 10);
    }
    if (hours > 0 || minutes > 0) {
      return hours * 60 + minutes;
    }
    return 99999;
  }

  private trainHasAvailableSeats(item: A2uiTrainOption): boolean {
    return item.seats.indexOf('有') >= 0;
  }

  private sortTrainsByDuration(rows: A2uiTrainOption[]): A2uiTrainOption[] {
    const copy = rows.slice();
    copy.sort((left: A2uiTrainOption, right: A2uiTrainOption) => {
      return this.parseDurationMinutes(left.duration) - this.parseDurationMinutes(right.duration);
    });
    return copy;
  }

  private displayedTrains(component: A2uiComponent): A2uiTrainOption[] {
    let rows = trainOptions(this.surfaceForRender(), component);
    if (this.trainFilterAvailable) {
      const filtered: A2uiTrainOption[] = [];
      for (let index = 0; index < rows.length; index++) {
        if (this.trainHasAvailableSeats(rows[index])) {
          filtered.push(rows[index]);
        }
      }
      rows = filtered;
    }
    if (this.trainSortMode === 'fastest') {
      rows = this.sortTrainsByDuration(rows);
    }
    if (rows.length <= this.trainVisibleCount) {
      return rows;
    }
    return rows.slice(0, this.trainVisibleCount);
  }

  private trainSeatField(item: A2uiTrainOption, field: string): string {
    if (field === 'business') {
      return item.business;
    }
    if (field === 'first') {
      return item.first;
    }
    if (field === 'second') {
      return item.second;
    }
    if (field === 'sleeperSoft') {
      return item.sleeperSoft;
    }
    if (field === 'hardSeat') {
      return item.hardSeat;
    }
    return item.noSeat;
  }

  private handleClientAction(action: A2uiAction): void {
    aiLogInfo('[AIPhone][ClientAction] id=' + action.id);
    if (action.id === 'client_show_more') {
      this.trainVisibleCount = this.trainVisibleCount + TRAIN_INITIAL_VISIBLE;
      this.renderRevision = this.renderRevision + 1;
      return;
    }
    if (action.id === 'client_sort_fastest') {
      this.trainSortMode = 'fastest';
      this.renderRevision = this.renderRevision + 1;
      return;
    }
    if (action.id === 'client_filter_available') {
      this.trainFilterAvailable = true;
      this.renderRevision = this.renderRevision + 1;
    }
  }

  private focusEditQuery(): void {
    this.inputPlaceholder = TRAIN_EDIT_QUERY_PLACEHOLDER;
    this.inputText = '';
    this.statusText = '请在输入框补充具体查询条件';
  }

  private async sendAction(action: A2uiAction): Promise<void> {
    const kind = action.kind.length > 0 ? action.kind : 'prompt';
    if (kind === 'client') {
      this.handleClientAction(action);
      return;
    }
    if (kind === 'input') {
      this.focusEditQuery();
      return;
    }
    await this.submitPrompt(action.prompt, action.label, action.id);
  }

  private async testConnection(): Promise<void> {
    await this.submitPrompt('连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。', '检查连接');
  }

  @Builder
  StatusBadge(label: string, status: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.statusColor(status))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(this.statusBackground(status))
      .borderRadius(9)
      .border({ width: 1, color: this.statusColor(status) })
  }

  @Builder
  CardGlint() {
    Row() {
      Text('')
        .width(54)
        .height(1)
        .backgroundColor(COLOR_ACCENT_DARK)
        .opacity(0.54)
        .margin({ right: 8 })
      Text('')
        .height(1)
        .layoutWeight(1)
        .backgroundColor(COLOR_HIGHLIGHT_LINE)
        .opacity(0.48)
    }
    .width('100%')
    .height(1)
    .clip(true)
    .margin({ bottom: 14 })
  }

  @Builder
  PremiumRail(accentColor: string, heightValue: number) {
    Text('')
      .width(3)
      .height(heightValue)
      .borderRadius(3)
      .backgroundColor(accentColor)
      .opacity(0.78)
      .margin({ right: 12 })
  }

  @Builder
  TopBar() {
    Row() {
      this.PremiumRail(COLOR_ACCENT, 48)
      Column() {
        Row() {
          Text('AIPhone')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(this.surfaceIntentLabel(this.currentSurface.intent))
            .fontSize(12)
            .fontColor(COLOR_ACCENT_DARK)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(COLOR_ACCENT_SOFT)
            .borderRadius(9)
            .margin({ left: 10 })
        }
        Text(this.currentSurface.title.length > 0 ? this.currentSurface.title : 'A2UI 原生任务画布')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .margin({ top: 5 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.StatusBadge(this.statusLabel(this.currentSurface.status), this.currentSurface.status)

      Button(this.showHistory ? '隐藏轨迹' : '轨迹')
        .height(40)
        .width(82)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD_RAISED)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ left: 10 })
        .onClick(() => {
          this.showHistory = !this.showHistory;
        })

      Button('配置')
        .height(40)
        .width(78)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD_RAISED)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ left: 8 })
        .onClick(() => {
          this.showConfigPage = true;
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 14 })
    .backgroundColor(COLOR_PANEL)
    .borderRadius(20)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 24, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 12 })
  }

  @Builder
  ActionButtons(actions: A2uiAction[]) {
    if (actions.length > 0) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(actions, (action: A2uiAction) => {
          Button(action.label)
            .enabled(!this.isBusy)
            .height(38)
            .fontSize(13)
            .fontColor(this.actionTextColor(action.variant))
            .backgroundColor(this.actionBackground(action.variant))
            .borderRadius(11)
            .border({ width: 1, color: this.actionBorder(action.variant) })
            .padding({ left: 14, right: 14 })
            .margin({ right: 8, top: 10 })
            .shadow({ radius: 10, color: action.variant === 'primary' ? COLOR_ACCENT_SHADOW : COLOR_CARD_SHADOW, offsetX: 0, offsetY: 5 })
            .onClick(() => {
              this.sendAction(action);
            })
        }, (action: A2uiAction) => action.id + action.label)
      }
      .width('100%')
      .margin({ top: 4 })
    }
  }

  @Builder
  A2uiSurface() {
    Scroll() {
      Column() {
        if (this.isStandbyState()) {
          this.StandbyCanvas()
        } else {
          if (!this.hasActiveThinkingUi()) {
            this.SurfaceHero()
          }
          if (this.shouldShowThinkingPanel()) {
            this.ThinkingPanel(this.surfaceForRender().sequence)
          }
          if (this.hasTrainDataInModel()) {
            this.TrainOptions(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_TRAIN_OPTIONS, 'train_direct'), this.surfaceForRender().sequence)
          } else if (this.hasFlightDataInModel()) {
            this.FlightBoard(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_FLIGHT_BOARD, 'flight_direct'), this.surfaceForRender().sequence)
          } else if (this.hasFoodDataInModel()) {
            this.FoodChoices(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_FOOD_CHOICES, 'food_direct'), this.surfaceForRender().sequence)
          } else if (this.hasDirectRowsData()) {
            this.InfoRows(this.surfaceForRender(), this.directRowsComponent(), this.surfaceForRender().sequence)
          } else if (this.currentSurface.components.length === 0 && !this.hasThinkingCard()) {
            if (this.isProcessingState()) {
              this.ThinkingFallback(this.surfaceForRender())
            } else {
              this.EmptySurface()
            }
          } else if (!this.hasComponent(this.surfaceForRender(), this.surfaceForRender().rootId) && !this.hasThinkingCard()) {
            this.ThinkingFallback(this.surfaceForRender())
          } else if (!this.isThinkingOnlySurface()) {
            this.RenderComponent(this.surfaceForRender(), this.componentOrFallback(this.surfaceForRender(), this.surfaceForRender().rootId), this.surfaceForRender().sequence)
          }
        }
      }
      .width('100%')
      .padding(18)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(COLOR_PANEL)
    .borderRadius(24)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 28, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 14 })
  }

  @Builder
  SurfaceHero() {
    Column() {
      this.CardGlint()
      Row() {
        Text(this.surfaceIntentLabel(this.currentSurface.intent))
          .fontSize(12)
          .fontColor(COLOR_ACCENT_DARK)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(COLOR_ACCENT_SOFT)
          .borderRadius(9)
        Blank()
        this.StatusBadge(this.statusLabel(this.currentSurface.status), this.currentSurface.status)
      }
      .width('100%')

      Text(this.currentSurface.title.length > 0 ? this.currentSurface.title : 'AIPhone')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .lineHeight(40)
        .margin({ top: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor(COLOR_CARD_TOP)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_EDGE_LIGHT })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 14 })
  }

  @Builder
  StandbyTexture() {
    Column() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (lineIndex: number) => {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(COLOR_LINE)
          .opacity(0.2)
          .margin({ top: lineIndex === 0 ? 0 : 26 })
      }, (lineIndex: number) => lineIndex.toString())
    }
    .width('100%')
    .opacity(0.42)
  }

  @Builder
  StandbyOrb() {
    Stack({ alignContent: Alignment.Center }) {
      Text('')
        .width(196)
        .height(196)
        .borderRadius(98)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .opacity(this.orbOpacity * 0.55)
        .scale({ x: this.orbPulse, y: this.orbPulse })
      Text('')
        .width(148)
        .height(148)
        .borderRadius(74)
        .backgroundColor(COLOR_PROCESS_SOFT)
        .opacity(this.orbOpacity * 0.72)
        .scale({ x: this.orbPulse, y: this.orbPulse })
      Text('')
        .width(88)
        .height(88)
        .borderRadius(44)
        .backgroundColor(COLOR_CARD_RAISED)
        .border({ width: 1, color: COLOR_PROCESS_LINE })
        .opacity(0.96)
        .scale({ x: this.orbPulse, y: this.orbPulse })
      Text('')
        .width(18)
        .height(18)
        .borderRadius(9)
        .backgroundColor(COLOR_ACCENT)
        .opacity(0.82)
    }
    .width(220)
    .height(220)
  }

  @Builder
  StandbyCanvas() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.StandbyTexture()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)

      Column() {
        this.StandbyOrb()
        Text('说一件事，我来完成。')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .textAlign(TextAlign.Center)
          .lineHeight(34)
          .maxLines(2)
          .margin({ top: 28 })
        Text('在下方输入，或直接用语音描述。')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .margin({ top: 10 })
      }
      .width('100%')
      .constraintSize({ minHeight: 420 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 28, right: 28 })
    }
    .width('100%')
    .constraintSize({ minHeight: 420 })
  }

  @Builder
  EmptySurface() {
    Column() {
      this.CardGlint()
      Text('今天想安排什么？')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text('告诉我出发地、目的地、日期，或你想找的附近餐饮。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 18, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 8 })
  }

  @Builder
  ThinkingFallback(surface: A2uiSurfaceState) {
    Column() {
      this.CardGlint()
      Row() {
        this.ThinkingPulseMark(surface.status)
        Column() {
          Text(surface.status === 'calling_tool' ? '工具正在处理' : '正在整理结果')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_INK)
            .letterSpacing(-0.3)
            .lineHeight(24)
          Text(surface.status === 'calling_tool' ? '工具返回前，AIPhone 会保持任务画布在线。' : '新的内容正在到达，卡片会自动完成。')
            .fontSize(12)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_THINK_STREAM_MUTED)
            .lineHeight(18)
            .letterSpacing(0.2)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      this.StaticProcessingNote(surface.status)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.processingCardBackground(surface.status))
    .borderRadius(18)
    .border({ width: 1, color: this.processingCardBorder(surface.status) })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
  }

  @Builder
  RenderComponent(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    if (component.component === A2UI_COMPONENT_SURFACE_ROOT) {
      this.SurfaceRootComponent(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_COLUMN) {
      this.ColumnComponent(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_ROW) {
      this.RowComponent(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_TEXT) {
      this.TextComponent(component)
    } else if (component.component === A2UI_COMPONENT_ACTION_BAR) {
      this.ActionButtons(actionsOf(component))
    } else if (component.component === A2UI_COMPONENT_THINKING_STREAM) {
      Blank()
        .height(0)
    } else if (component.component === A2UI_COMPONENT_THINKING_CARD) {
      Blank()
        .height(0)
    } else if (component.component === A2UI_COMPONENT_TRAIN_OPTIONS) {
      this.TrainOptions(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_FLIGHT_BOARD) {
      this.FlightBoard(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_FOOD_CHOICES) {
      this.FoodChoices(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_CONFIRM_PANEL) {
      Blank()
        .height(0)
    } else if (component.component === A2UI_COMPONENT_INFO_ROWS) {
      this.InfoRows(surface, component, revision)
    } else if (component.component === A2UI_COMPONENT_ERROR_NOTICE) {
      this.ErrorNotice(component)
    } else {
      this.UnknownComponent(component)
    }
  }

  @Builder
  SurfaceRootComponent(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      if (this.componentChild(component).length > 0) {
        this.RenderComponent(surface, this.componentOrFallback(surface, this.componentChild(component)), revision)
      }
      if (this.componentChildren(component).length > 0) {
        ForEach(this.componentChildren(component), (childId: string) => {
          this.RenderComponent(surface, this.componentOrFallback(surface, childId), revision)
        }, (childId: string) => childId + '-' + revision.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ColumnComponent(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      if (this.componentTitle(component, '').length > 0) {
        Text(this.componentTitle(component, ''))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
      }
      if (this.componentChildren(component).length > 0) {
        ForEach(this.componentChildren(component), (childId: string) => {
          this.RenderComponent(surface, this.componentOrFallback(surface, childId), revision)
        }, (childId: string) => childId + '-' + revision.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 12 })
  }

  @Builder
  RowComponent(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Row() {
      if (this.componentChildren(component).length > 0) {
        ForEach(this.componentChildren(component), (childId: string) => {
          this.RenderComponent(surface, this.componentOrFallback(surface, childId), revision)
        }, (childId: string) => childId + '-' + revision.toString())
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 12 })
  }

  @Builder
  TextComponent(component: A2uiComponent) {
    Text(this.componentText(component))
      .fontSize(this.componentVariant(component) === 'title' ? 20 : 14)
      .fontWeight(this.componentVariant(component) === 'title' ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.componentTone(component) === 'muted' ? COLOR_MUTED : COLOR_TEXT)
      .lineHeight(this.componentVariant(component) === 'title' ? 26 : 21)
      .margin({ bottom: 10 })
  }

  @Builder
  ThinkingPanel(revision: number) {
    Column() {
      this.CardGlint()
      Row() {
        Column() {
          Row() {
            Text('思考过程')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontFamily(FONT_THINK_DISPLAY)
              .fontColor(COLOR_THINK_STREAM_MUTED)
              .letterSpacing(1.1)
            if (this.modelThinkingActive) {
              Text('写入中')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontFamily(FONT_THINK_DISPLAY)
                .fontColor(COLOR_THINK_STREAM_ACCENT)
                .letterSpacing(0.8)
                .opacity(0.82)
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          if (!this.thinkingPanelExpanded && !this.modelThinkingActive) {
            Text(this.thinkingPreviewText())
              .fontSize(13)
              .fontWeight(FontWeight.Regular)
              .fontFamily(FONT_THINK_STREAM)
              .fontColor(COLOR_THINK_STREAM_MUTED)
              .lineHeight(20)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 8 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(this.thinkingPanelExpanded || this.modelThinkingActive ? '收起' : '展开')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontFamily(FONT_THINK_DISPLAY)
          .fontColor(COLOR_THINK_STREAM_ACCENT)
          .letterSpacing(0.4)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(COLOR_THINK_STREAM_BG)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_THINK_STREAM_BORDER })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .onClick(() => {
        this.toggleThinkingPanel();
      })

      if (this.thinkingPanelExpanded || this.modelThinkingActive) {
        this.ThinkingPanelStream(revision)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(COLOR_THINK_CARD)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_THINK_CARD_BORDER })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 14 })
    .key('thinking-panel-' + revision.toString())
  }

  @Builder
  ThinkingPanelStream(revision: number) {
    Row() {
      Text('')
        .width(2)
        .constraintSize({ minHeight: 72 })
        .backgroundColor(COLOR_THINK_STREAM_ACCENT)
        .borderRadius(2)
        .opacity(0.78)
        .margin({ right: 12 })
      Scroll() {
        Text(this.thinkingDisplayText())
          .fontSize(15)
          .fontWeight(FontWeight.Regular)
          .fontFamily(FONT_THINK_STREAM)
          .fontColor(COLOR_THINK_STREAM_INK)
          .lineHeight(26)
          .letterSpacing(0.25)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .constraintSize({ maxHeight: 300 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(COLOR_THINK_STREAM_BG)
    .borderRadius(14)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 14 })
    .key('thinking-panel-stream-' + revision.toString())
  }

  @Builder
  ThinkingStreamHeader(component: A2uiComponent) {
    Row() {
      this.ThinkingPulseMark(this.componentStatus(component))
      Column() {
        Row() {
          Text(this.processingTitle(component))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_INK)
            .letterSpacing(-0.3)
            .lineHeight(24)
            .layoutWeight(1)
          this.ThinkingStatusChip(this.statusLabel(this.componentStatus(component)), this.componentStatus(component))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text(this.processingBody(component))
          .fontSize(12)
          .fontWeight(FontWeight.Regular)
          .fontFamily(FONT_THINK_DISPLAY)
          .fontColor(COLOR_THINK_STREAM_MUTED)
          .lineHeight(18)
          .letterSpacing(0.2)
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ThinkingPulseMark(status: string) {
    Stack({ alignContent: Alignment.Center }) {
      Text('')
        .width(52)
        .height(52)
        .borderRadius(16)
        .backgroundColor(COLOR_THINK_STREAM_BG)
        .border({ width: 1, color: COLOR_THINK_STREAM_BORDER })
        .scale({ x: this.thinkPulse, y: this.thinkPulse })
      Text('')
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(this.thinkingStatusAccent(status))
        .opacity(0.92)
    }
    .width(52)
    .height(52)
  }

  @Builder
  ThinkingStatusChip(label: string, status: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontFamily(FONT_THINK_DISPLAY)
      .fontColor(this.thinkingStatusAccent(status))
      .letterSpacing(0.6)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(COLOR_THINK_STREAM_BG)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_THINK_STREAM_BORDER })
  }

  @Builder
  ThinkingStream(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.CardGlint()
      this.ThinkingStreamHeader(component)
      if (this.hasThinkingStreamContent(surface, component)) {
        this.ThinkingCardStream(surface, component, revision)
      } else {
        this.StaticProcessingNote(this.componentStatus(component))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(this.processingCardBackground(this.componentStatus(component)))
    .borderRadius(18)
    .border({ width: 1, color: this.processingCardBorder(this.componentStatus(component)) })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 14 })
  }

  @Builder
  ThinkingCardStream(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Row() {
      Text('')
        .width(2)
        .constraintSize({ minHeight: 72 })
        .backgroundColor(COLOR_THINK_STREAM_ACCENT)
        .borderRadius(2)
        .opacity(0.78)
        .margin({ right: 12 })
      Column() {
        Row() {
          Text('思考流')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_THINK_STREAM_MUTED)
            .letterSpacing(1.1)
          Blank()
            .layoutWeight(1)
          if (this.isBusy) {
            Text('写入中')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontFamily(FONT_THINK_DISPLAY)
              .fontColor(COLOR_THINK_STREAM_ACCENT)
              .letterSpacing(0.8)
              .opacity(0.82)
          }
        }
        .width('100%')
        .margin({ bottom: 10 })
        Scroll() {
          Text(this.thinkingStreamText(surface, component))
            .fontSize(15)
            .fontWeight(FontWeight.Regular)
            .fontFamily(FONT_THINK_STREAM)
            .fontColor(COLOR_THINK_STREAM_INK)
            .lineHeight(26)
            .letterSpacing(0.25)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .constraintSize({ maxHeight: 300 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(COLOR_THINK_STREAM_BG)
    .borderRadius(14)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 16 })
    .key('thinking-stream-' + revision.toString())
  }

  @Builder
  ThinkingCard(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      Row() {
        Text('')
          .width(56)
          .height(1)
          .backgroundColor(COLOR_THINK_STREAM_ACCENT)
          .opacity(0.35)
          .margin({ left: this.thinkShimmer })
      }
      .width('100%')
      .height(1)
      .clip(true)
      .margin({ bottom: 16 })

      Row() {
        Column() {
          Text(this.thinkingCardTitle(component))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_INK)
            .letterSpacing(-0.3)
            .lineHeight(24)
          Text(this.thinkingCardBody(component))
            .fontSize(12)
            .fontWeight(FontWeight.Regular)
            .fontFamily(FONT_THINK_DISPLAY)
            .fontColor(COLOR_THINK_STREAM_MUTED)
            .lineHeight(18)
            .letterSpacing(0.2)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        this.ThinkingStatusChip(this.statusLabel(this.componentStatus(component)), this.componentStatus(component))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.hasThinkingStreamContent(surface, component)) {
        this.ThinkingCardStream(surface, component, revision)
      } else {
        this.StaticProcessingNote(this.componentStatus(component))
      }

      if (this.isBusy) {
        Row() {
          ForEach([0, 1, 2], (dotIndex: number) => {
            Text('')
              .width(5)
              .height(5)
              .borderRadius(3)
              .backgroundColor(COLOR_THINK_STREAM_ACCENT)
              .opacity(dotIndex === 0 ? 0.9 : (dotIndex === 1 ? 0.55 : 0.28))
              .margin({ right: dotIndex === 2 ? 0 : 6 })
          }, (dotIndex: number) => dotIndex.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: 14 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 20, bottom: 20 })
    .backgroundColor(COLOR_THINK_CARD)
    .borderRadius(20)
    .border({ width: 1, color: COLOR_EDGE_LIGHT })
    .shadow({ radius: 24, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 12 })
    .margin({ bottom: 14 })
  }

  @Builder
  ProcessingCoreIcon(status: string) {
    this.ThinkingPulseMark(status)
  }

  @Builder
  StaticProcessingNote(status: string) {
    Row() {
      Text('')
        .width(2)
        .height(40)
        .backgroundColor(this.thinkingStatusAccent(status))
        .borderRadius(2)
        .opacity(0.55)
        .margin({ right: 12 })
      Text(status === 'calling_tool' ? '工具通道已接管，等待结构化结果。' : '思考流正在写入，稍后显示完整推理。')
        .fontSize(14)
        .fontWeight(FontWeight.Regular)
        .fontFamily(FONT_THINK_STREAM)
        .fontColor(COLOR_THINK_STREAM_MUTED)
        .lineHeight(24)
        .letterSpacing(0.2)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(14)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 16 })
  }

  @Builder
  ThoughtTimeline(thoughts: string[], revision: number, status: string) {
    Column() {
      ForEach(thoughts, (item: string) => {
        Row() {
          Column() {
            Text('')
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.thinkingStatusAccent(status))
              .opacity(0.72)
            Text('')
              .width(2)
              .height(19)
              .backgroundColor(COLOR_PROCESS_LINE)
              .opacity(0.7)
              .margin({ top: 3 })
          }
          .width(16)
          .alignItems(HorizontalAlign.Center)
          Text(item)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ top: 4, bottom: 4 })
      }, (item: string) => item + '-' + revision.toString())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 8 })
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(14)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 15 })
  }

  @Builder
  LabelValueRows(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    ForEach(labelValues(surface, component), (row: A2uiLabelValue) => {
      Row() {
        Text(row.label)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .width(92)
        Text(row.value)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 8, bottom: 8 })
    }, (row: A2uiLabelValue) => row.label + row.value + '-' + revision.toString())
  }

  @Builder
  TrainDetailPanel(item: A2uiTrainOption) {
    Column() {
      if (this.trainSeatField(item, 'business').length > 0) {
        this.TrainDetailRow('商务座', this.trainSeatField(item, 'business'))
      }
      if (this.trainSeatField(item, 'first').length > 0) {
        this.TrainDetailRow('一等座', this.trainSeatField(item, 'first'))
      }
      if (this.trainSeatField(item, 'second').length > 0) {
        this.TrainDetailRow('二等座', this.trainSeatField(item, 'second'))
      }
      if (this.trainSeatField(item, 'sleeperSoft').length > 0) {
        this.TrainDetailRow('卧铺', this.trainSeatField(item, 'sleeperSoft'))
      }
      if (this.trainSeatField(item, 'hardSeat').length > 0) {
        this.TrainDetailRow('硬座', this.trainSeatField(item, 'hardSeat'))
      }
      if (this.trainSeatField(item, 'noSeat').length > 0) {
        this.TrainDetailRow('无座', this.trainSeatField(item, 'noSeat'))
      }
      if (item.status.length > 0) {
        this.TrainDetailRow('状态', item.status)
      }
      Text('以 12306 为准，不支持订票')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(10)
    .border({ width: { left: 3 }, color: COLOR_ACCENT })
    .margin({ top: 10 })
  }

  @Builder
  TrainDetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width(56)
      Text(value)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  TrainOptions(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.CardGlint()
      this.ModuleHeader(this.componentTitle(component, '高铁候选'), this.componentBody(component), this.componentStatus(component))
      ForEach(this.displayedTrains(component), (item: A2uiTrainOption) => {
        Column() {
          Column() {
            this.CardGlint()
            Row() {
              Text(item.trainCode)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
                .layoutWeight(1)
              if (item.duration.length > 0) {
                Text('耗时 ' + item.duration)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DARK)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(8)
              }
            }
            .width('100%')
            Row() {
              this.StationTime(item.from, item.depart)
              Text('→')
                .fontSize(18)
                .fontColor(COLOR_MUTED)
                .margin({ left: 14, right: 14, top: 8 })
              this.StationTime(item.to, item.arrive)
            }
            .width('100%')
            .margin({ top: 12 })
            Text(item.seats)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(19)
              .margin({ top: 10 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
          .onClick(() => {
            const rowKey = this.trainRowKey(item);
            this.expandedTrainKey = this.expandedTrainKey === rowKey ? '' : rowKey;
          })

          if (this.expandedTrainKey === this.trainRowKey(item)) {
            this.TrainDetailPanel(item)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 10 })
      }, (item: A2uiTrainOption) => item.trainCode + item.depart + '-' + revision.toString())
      if (trainOptions(this.surfaceForRender(), component).length === 0 && labelValues(this.surfaceForRender(), component).length > 0) {
        this.LabelValueRows(this.surfaceForRender(), component, revision)
      } else if (trainOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }

  @Builder
  StationTime(name: string, time: string) {
    Column() {
      Text(time.length > 0 ? time : '--')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text(name)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  FlightBoard(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.CardGlint()
      this.ModuleHeader(this.componentTitle(component, '航班候选'), this.componentBody(component), this.componentStatus(component))
      ForEach(flightOptions(this.surfaceForRender(), component), (item: A2uiFlightOption) => {
        Column() {
          this.CardGlint()
          Row() {
            Column() {
              Text(item.flightNo)
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
              Text(item.airline)
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .lineHeight(18)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Column() {
              Text((item.dep.length > 0 ? item.dep : '--') + ' → ' + (item.arr.length > 0 ? item.arr : '--'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT)
              Text(item.status.length > 0 ? item.status : '计划')
                .fontSize(12)
                .fontColor(this.statusColor(item.status === '提前取消' ? 'error' : 'ready'))
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(COLOR_CARD)
        .borderRadius(16)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
        .margin({ top: 10 })
      }, (item: A2uiFlightOption) => item.flightNo + item.depTime + '-' + revision.toString())
      if (flightOptions(this.surfaceForRender(), component).length === 0 && labelValues(this.surfaceForRender(), component).length > 0) {
        this.LabelValueRows(this.surfaceForRender(), component, revision)
      } else if (flightOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }

  @Builder
  FoodChoices(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.CardGlint()
      this.ModuleHeader(this.componentTitle(component, '附近餐饮'), this.componentBody(component), this.componentStatus(component))
      ForEach(foodOptions(this.surfaceForRender(), component), (item: A2uiFoodOption) => {
        Column() {
          this.CardGlint()
          Row() {
            Text(item.name)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .layoutWeight(1)
            if (item.distance.length > 0) {
              Text(item.distance)
                .fontSize(12)
                .fontColor(COLOR_ACCENT_DARK)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .backgroundColor(COLOR_ACCENT_SOFT)
                .borderRadius(8)
            }
          }
          .width('100%')
          if (item.category.length > 0) {
            Text(item.category)
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .lineHeight(18)
              .margin({ top: 6 })
          }
          Text(item.address.length > 0 ? item.address : '暂无地址')
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(19)
            .margin({ top: 7 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(COLOR_CARD)
        .borderRadius(16)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
        .margin({ top: 10 })
      }, (item: A2uiFoodOption) => item.name + '|' + item.address + '|' + item.distance)
      if (foodOptions(this.surfaceForRender(), component).length === 0 && labelValues(this.surfaceForRender(), component).length > 0) {
        this.LabelValueRows(this.surfaceForRender(), component, revision)
      } else if (foodOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }

  @Builder
  InfoRows(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.CardGlint()
      this.ModuleHeader(this.componentTitle(component, '信息'), this.componentBody(component), this.componentStatus(component))
      this.LabelValueRows(this.surfaceForRender(), component, revision)
      if (labelValues(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }

  @Builder
  ErrorNotice(component: A2uiComponent) {
    Column() {
      this.CardGlint()
      Row() {
        this.ErrorCoreMark()
        Column() {
          Row() {
            Text(this.componentTitle(component, 'A2UI 流解析中断'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_ERROR)
              .layoutWeight(1)
            this.StatusBadge('异常', 'error')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(this.componentBody(component, '无法渲染这次返回。'))
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 13 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_ERROR_SOFT)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_ERROR_LINE })
    .shadow({ radius: 18, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 8 })
    .margin({ bottom: 12 })
  }

  @Builder
  ErrorCoreMark() {
    Stack({ alignContent: Alignment.Center }) {
      Text('')
        .width(54)
        .height(54)
        .borderRadius(17)
        .backgroundColor(COLOR_ERROR_SOFT)
        .opacity(0.92)
      Text('')
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor(COLOR_CARD_RAISED)
        .border({ width: 1, color: COLOR_ERROR_LINE })
      Text('!')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ERROR)
    }
    .width(62)
    .height(62)
    .backgroundColor(COLOR_CARD)
    .borderRadius(19)
    .border({ width: 1, color: COLOR_ERROR_LINE })
    .shadow({ radius: 14, color: COLOR_CARD_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  UnknownComponent(component: A2uiComponent) {
    Column() {
      Text('不支持的组件')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ERROR)
      Text(component.component)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_ERROR_SOFT)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_ERROR_LINE })
  }

  @Builder
  ModuleHeader(title: string, body: string, status: string) {
    Row() {
      this.PremiumRail(this.statusColor(status), body.length > 0 ? 48 : 34)
      Column() {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        if (body.length > 0) {
          Text(body)
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(20)
            .margin({ top: 7 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      this.StatusBadge(this.statusLabel(status), status)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  EmptyRows() {
    Text('暂无可展示数据')
      .fontSize(13)
      .fontColor(COLOR_MUTED)
      .padding({ top: 14, bottom: 4 })
  }

  @Builder
  HistoryPanel() {
    Column() {
      this.CardGlint()
      Row() {
        Text('生成轨迹')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Blank()
        Text(this.messages.length.toString())
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(COLOR_CHROME)
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Scroll() {
        Column() {
          ForEach(this.messages, (message: A2uiMessage) => {
            Column() {
              Text(message.role === 'user' ? '你' : 'AIPhone')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(message.role === 'user' ? COLOR_ACCENT_DARK : COLOR_MUTED)
              Text(message.content)
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .lineHeight(18)
                .margin({ top: 5 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(11)
            .backgroundColor(message.role === 'user' ? COLOR_ACCENT_SOFT : COLOR_CARD_INSET)
            .borderRadius(12)
            .border({ width: 1, color: message.role === 'user' ? COLOR_PROCESS_LINE : COLOR_CARD_EDGE })
            .margin({ bottom: 8 })
          }, (message: A2uiMessage) => message.id)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_PANEL)
    .borderRadius(20)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 10 })
  }

  @Builder
  InputDock() {
    Row() {
      TextInput({
        placeholder: this.inputPlaceholder,
        text: this.inputText
      })
        .height(52)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .placeholderColor(COLOR_MUTED)
        .backgroundColor(COLOR_FIELD)
        .borderRadius(15)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .padding({ left: 14, right: 14 })
        .enterKeyType(EnterKeyType.Send)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          if (!this.isBusy) {
            this.sendPrompt();
          }
        })

      Button(this.isBusy ? '生成中' : '生成')
        .enabled(!this.isBusy)
        .height(52)
        .width(98)
        .fontSize(15)
        .fontColor(COLOR_BUTTON_TEXT)
        .backgroundColor(COLOR_ACCENT_DEEP)
        .borderRadius(15)
        .border({ width: 1, color: COLOR_ACCENT })
        .shadow({ radius: 14, color: COLOR_ACCENT_SHADOW, offsetX: 0, offsetY: 7 })
        .margin({ left: 10 })
        .onClick(() => {
          this.sendPrompt();
        })
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 12 })
  }

  @Builder
  ModelPanel() {
    Column() {
      this.CardGlint()
      Text('模型连接')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text('首页只展示 A2UI 任务画布，连接和诊断集中在这里。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(19)
        .margin({ top: 8, bottom: 14 })

      if (this.lastError.length > 0) {
        Column() {
          Text('最近异常')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_ERROR)
          Text(this.lastError)
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .lineHeight(18)
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(12)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_ERROR_LINE })
        .margin({ bottom: 14 })
      }

      this.ModelPicker()

      Button(this.isBusy ? '检查中' : '检查连接')
        .enabled(!this.isBusy)
        .height(42)
        .width('100%')
        .fontColor(COLOR_BUTTON_TEXT)
        .backgroundColor(COLOR_ACCENT_DEEP)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_ACCENT })
        .shadow({ radius: 12, color: COLOR_ACCENT_SHADOW, offsetX: 0, offsetY: 6 })
        .margin({ top: 14 })
        .onClick(() => {
          this.testConnection();
        })

      this.AdvancedSettingsSection()

      Divider()
        .color(COLOR_LINE)
        .margin({ top: 16, bottom: 14 })

      Button(this.showDiagnostics ? '收起技术详情' : '查看技术详情')
        .height(40)
        .width('100%')
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD_RAISED)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .onClick(() => {
          this.showDiagnostics = !this.showDiagnostics;
        })

      if (this.showDiagnostics) {
        this.DiagnosticDetails()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_PANEL)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 10 })
  }

  @Builder
  InputLabel(label: string, top: number) {
    Text(label)
      .fontSize(12)
      .fontColor(COLOR_MUTED)
      .margin({ top: top, bottom: 6 })
  }

  @Builder
  ModelPicker() {
    Column() {
      Text('快速预设')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ bottom: 6 })

      Row() {
        this.ProviderPresetButton('本地 Qwen', URL_LOCAL_MODEL, MODEL_QWEN)
        this.ProviderPresetButton('本地 DeepSeek', URL_LOCAL_MODEL, MODEL_DEEPSEEK, false)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  AdvancedSettingsSection() {
    Column() {
      Row() {
        Text('高级设置')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text(this.showAdvancedSettings ? '收起' : '展开')
          .fontSize(12)
          .fontColor(COLOR_ACCENT_DARK)
      }
      .width('100%')
      .padding({ top: 14, bottom: 10 })
      .onClick(() => {
        this.showAdvancedSettings = !this.showAdvancedSettings;
      })

      if (this.showAdvancedSettings) {
        this.InputLabel('Model', 0)
        TextInput({ text: this.selectedModel, placeholder: 'Qwen3-8B' })
          .height(42)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(9)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.selectedModel = value;
          })

        this.InputLabel('Base URL', 16)
        TextInput({ text: this.baseUrl, placeholder: 'http://127.0.0.1:11434' })
          .height(42)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(9)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.baseUrl = value;
          })

        this.InputLabel('API Key（可选）', 12)
        TextInput({ text: this.apiKey, placeholder: '如果接口要求鉴权，在这里填写' })
          .height(42)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(9)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.apiKey = value;
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProviderPresetButton(label: string, baseUrl: string, model: string, withRightMargin: boolean = true) {
    Button(label)
      .height(36)
      .layoutWeight(1)
      .fontSize(11)
      .fontColor(this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_BUTTON_TEXT : COLOR_INK)
      .backgroundColor(this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_ACCENT_DEEP : COLOR_CARD_RAISED)
      .borderRadius(9)
      .border({ width: 1, color: this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_ACCENT : COLOR_CARD_EDGE })
      .shadow({ radius: this.baseUrl === baseUrl && this.selectedModel === model ? 10 : 6, color: this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_ACCENT_SHADOW : COLOR_CARD_SHADOW, offsetX: 0, offsetY: 4 })
      .margin({ right: withRightMargin ? 8 : 0 })
      .onClick(() => {
        this.applyProviderPreset(baseUrl, model);
      })
  }

  @Builder
  DiagnosticDetails() {
    Column() {
      this.ModelDiagnosticSection()
      this.ToolDiagnosticSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 10 })
  }

  @Builder
  DiagnosticPhaseShell(title: string, hint: string, accentColor: string) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      Text(hint)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .lineHeight(16)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 15, right: 12, top: 12, bottom: 8 })
    .border({ width: { left: 3 }, color: accentColor })
  }

  @Builder
  ModelDiagnosticSection() {
    Column() {
      this.CardGlint()
      this.DiagnosticPhaseShell(
        '模型阶段',
        '模型 SSE 原始流包含 data: 帧；从中提取的 content 即 A2UI JSONL，驱动画布渲染。',
        COLOR_ACCENT
      )
      Column() {
        this.DebugText('模型请求地址', buildChatCompletionsUrl(this.baseUrl))
        this.DebugScroll(
          '模型请求',
          this.lastModelRequest.length > 0 ? this.lastModelRequest : '尚未发起查询。',
          DEBUG_SCROLL_MAX_HEIGHT
        )
        this.DebugScroll(
          '模型 content 提取',
          this.lastModelOutput.length > 0 ? this.lastModelOutput : '尚未发起查询。',
          DEBUG_SCROLL_MAX_HEIGHT
        )
        this.DebugScroll(
          '模型 SSE 原始流',
          this.lastModelRawStream.length > 0 ? this.lastModelRawStream : '尚未发起查询。',
          DEBUG_SCROLL_MAX_HEIGHT
        )
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(10)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 16, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 7 })
    .margin({ bottom: 10 })
  }

  @Builder
  ToolDiagnosticSection() {
    Column() {
      this.CardGlint()
      this.DiagnosticPhaseShell(
        '工具阶段',
        '模型在 surface 中发出 toolRequest 后，所有注册工具都由 HAP 本机工具统一执行；航班和餐饮使用 HAP 包内 rawfile 配置直连真实供应商。',
        COLOR_PROCESS
      )
      Column() {
        this.DebugText('统一工具入口', TOOL_GATEWAY_URL)
        this.DebugText('本机 provider 配置', localProviderConfigDebugSummary())
        Text(isLocalToolGatewayUrl(TOOL_GATEWAY_URL) ? '航班、火车、餐饮都走 local://aiphone-tools；App 运行时不依赖 Mac 上的 8787 服务。' : '由显式 HTTP tool-gateway 提供；仅用于开发兼容模式。')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .lineHeight(16)
          .margin({ top: 4 })
        this.DebugScroll(
          '工具 JSONL 原始流',
          this.lastToolRawStream.length > 0 ? this.lastToolRawStream : '尚未调用工具。',
          DEBUG_SCROLL_MAX_HEIGHT
        )
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 12, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(10)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 16, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  DebugText(label: string, value: string) {
    Text(label)
      .fontSize(11)
      .fontColor(COLOR_MUTED)
      .margin({ top: 8 })
    Text(value)
      .fontSize(12)
      .fontColor(COLOR_INK)
      .lineHeight(18)
      .margin({ top: 5 })
  }

  @Builder
  DebugScroll(label: string, value: string, maxHeightValue: number) {
    Text(label)
      .fontSize(11)
      .fontColor(COLOR_MUTED)
      .margin({ top: 12, bottom: 6 })
    Scroll() {
      Text(value)
        .fontSize(10)
        .fontColor(COLOR_TEXT)
        .lineHeight(15)
        .width('100%')
    }
    .constraintSize({ minHeight: DEBUG_SCROLL_MIN_HEIGHT, maxHeight: maxHeightValue })
    .width('100%')
    .padding(10)
    .backgroundColor(COLOR_FIELD)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .scrollBar(BarState.Auto)
  }

  @Builder
  HomePage() {
    Column() {
      this.TopBar()

      if (this.showHistory) {
        GridRow({
          columns: 12,
          gutter: { x: 14, y: 14 },
          breakpoints: { value: ['620vp', '980vp'], reference: BreakpointsReference.WindowSize }
        }) {
          GridCol({ span: { xs: 12, sm: 12, md: 8, lg: 8 } }) {
            this.A2uiSurface()
          }
          GridCol({ span: { xs: 12, sm: 12, md: 4, lg: 4 } }) {
            this.HistoryPanel()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 14 })
      } else {
        Column() {
          this.A2uiSurface()
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 14 })
      }

      this.InputDock()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(COLOR_PAGE)
  }

  @Builder
  ConfigPage() {
    Scroll() {
      Column() {
        Row() {
          Button('返回')
            .height(40)
            .width(76)
            .fontSize(13)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .onClick(() => {
              this.showConfigPage = false;
            })

          Column() {
            Text('配置')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('管理本地模型连接')
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 16 })

        this.ModelPanel()
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }

  build() {
    if (this.showConfigPage) {
      this.ConfigPage()
    } else {
      this.HomePage()
    }
  }
}
