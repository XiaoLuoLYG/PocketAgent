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
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2uiAction,
  A2uiComponent,
  A2uiMessage,
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
import { buildChatCompletionsUrl, callLocalModel } from '../model/LocalModelClient';
import { buildToolGatewayUrl, callToolGateway, defaultToolGatewayUrl, isRegisteredToolId } from '../model/ToolGatewayClient';
import { aiLogError, aiLogInfo } from '../model/AiphoneLogger';

const MODEL_QWEN: string = 'Qwen3-8B';
const MODEL_DEEPSEEK: string = 'DeepSeek-R1-Distill-Qwen-7B';
const URL_LOCAL_MODEL: string = 'http://127.0.0.1:11434';
const URL_DEEPSEEK: string = 'https://api.deepseek.com';
const URL_DASHSCOPE: string = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
const URL_SILICONFLOW: string = 'https://api.siliconflow.cn/v1';
const MODEL_DEEPSEEK_CLOUD: string = 'deepseek-v4-flash';
const MODEL_DASHSCOPE: string = 'qwen-plus';
const MODEL_SILICONFLOW: string = 'Qwen/Qwen3-8B';

const COLOR_INK: string = '#101820';
const COLOR_TEXT: string = '#24323B';
const COLOR_MUTED: string = '#66747D';
const COLOR_LINE: string = '#D8E1E4';
const COLOR_PAGE: string = '#EEF4F5';
const COLOR_PANEL: string = '#FBFDFD';
const COLOR_GLASS: string = '#F7FAFA';
const COLOR_ACCENT: string = '#176B75';
const COLOR_ACCENT_DARK: string = '#0D5158';
const COLOR_ACCENT_SOFT: string = '#DFF1F2';
const COLOR_WARN: string = '#996800';
const COLOR_WARN_SOFT: string = '#FFF4DA';
const COLOR_ERROR: string = '#B42318';
const COLOR_ERROR_SOFT: string = '#FDE7E5';
const COLOR_CHROME: string = '#E7EFF0';

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
    createMessage('assistant', 'AIPhone 已就绪，可以把一句话生成 A2UI 原生任务画布。')
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
  @State lastRawStream: string = '';
  @State lastModelRequest: string = '';
  @State lastModelOutput: string = '';
  @State lastError: string = '';
  @State showConfigPage: boolean = false;
  @State showSetupGuide: boolean = false;
  @State showDiagnostics: boolean = false;
  @State showHistory: boolean = false;
  @State baseUrl: string = defaultLocalModelSettings().baseUrl;
  @State apiKey: string = '';
  @State selectedModel: string = MODEL_QWEN;
  @State toolGatewayUrl: string = defaultToolGatewayUrl();

  private getSettings(): LocalModelSettings {
    return {
      provider: 'A2UI Local API',
      baseUrl: this.baseUrl,
      model: this.selectedModel,
      apiKey: this.apiKey
    };
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
      return COLOR_WARN;
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
      return COLOR_WARN_SOFT;
    }
    if (status === 'needs_input') {
      return COLOR_ACCENT_SOFT;
    }
    return COLOR_ACCENT_SOFT;
  }

  private actionBackground(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT_DARK;
    }
    if (variant === 'danger') {
      return COLOR_ERROR_SOFT;
    }
    return '#EDF4F4';
  }

  private actionTextColor(variant: string): string {
    if (variant === 'primary') {
      return '#FFFFFF';
    }
    if (variant === 'danger') {
      return COLOR_ERROR;
    }
    return COLOR_INK;
  }

  private actionBorder(variant: string): string {
    if (variant === 'primary') {
      return COLOR_ACCENT_DARK;
    }
    if (variant === 'danger') {
      return '#F6B8B3';
    }
    return COLOR_LINE;
  }

  private updateSurfaceFromStream(surface: A2uiSurfaceState, raw: string): void {
    aiLogInfo('[AIPhone][SurfaceUpdate] surfaceId=' + surface.surfaceId + ' status=' + surface.status + ' components=' + surface.components.length.toString() + ' dataChars=' + surface.dataModelJson.length.toString() + ' rawChars=' + raw.length.toString());
    this.currentSurface = surface;
    this.surfaceComponents = surface.components.slice();
    this.surfaceDataModelJson = surface.dataModelJson;
    this.lastRawStream = raw;
    this.statusText = this.statusLabel(surface.status);
    if (surface.error.length > 0) {
      this.lastError = surface.error;
    }
  }

  private surfaceForRender(): A2uiSurfaceState {
    return {
      surfaceId: this.currentSurface.surfaceId,
      rootId: this.currentSurface.rootId,
      title: this.currentSurface.title,
      intent: this.currentSurface.intent,
      status: this.currentSurface.status,
      components: this.surfaceComponents,
      dataModelJson: this.surfaceDataModelJson,
      error: this.currentSurface.error,
      sequence: this.currentSurface.sequence
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
    for (let index = 0; index < this.surfaceComponents.length; index++) {
      if (this.surfaceComponents[index].component === componentType) {
        return this.surfaceComponents[index];
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

  private thinkingDotOpacity(revision: number, dotIndex: number): number {
    const phase = revision % 3;
    return phase === dotIndex ? 1 : 0.32;
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
    if (this.baseUrl.trim().length === 0) {
      this.lastError = '请先填写本地模型服务的 Base URL。';
      this.statusText = '缺少配置';
      aiLogError('[AIPhone][SubmitBlocked] missingBaseUrl');
      return;
    }

    aiLogInfo('[AIPhone][SubmitPrompt] actionId=' + actionId + ' chars=' + trimmed.length.toString());
    this.appendMessage('user', visibleText);
    this.inputText = '';
    this.isBusy = true;
    this.statusText = '正在生成';
    this.lastError = '';

    const result = await callLocalModel(this.getSettings(), trimmed, this.recentMessages(), (surface: A2uiSurfaceState, raw: string) => {
      this.updateSurfaceFromStream(surface, raw);
    });
    aiLogInfo('[AIPhone][ModelResult] ok=' + (result.ok ? 'true' : 'false') + ' errorChars=' + result.error.length.toString() + ' assistantChars=' + result.assistantDebug.length.toString());
    this.lastModelRequest = result.requestDebug;
    this.lastModelOutput = result.assistantDebug;
    this.updateSurfaceFromStream(result.surface, result.raw);
    this.statusText = this.statusLabel(result.surface.status);
    if (!result.ok) {
      this.lastError = result.error;
      this.appendMessage('assistant', 'A2UI 生成失败：' + result.error);
      this.isBusy = false;
      return;
    }

    this.appendMessage('assistant', result.assistantDebug.length > 0 ? result.assistantDebug : result.surface.title);
    await this.callModelRequestedTool(result.surface, trimmed, actionId);
    this.isBusy = false;
  }

  private async callModelRequestedTool(surface: A2uiSurfaceState, fallbackPrompt: string, fallbackActionId: string): Promise<void> {
    const request = toolRequest(surface);
    if (request.toolId.length === 0) {
      aiLogInfo('[AIPhone][ToolRequest] none');
      return;
    }
    if (!isRegisteredToolId(request.toolId)) {
      this.lastError = '模型请求了未注册工具：' + request.toolId;
      aiLogError('[AIPhone][ToolRequestInvalid] toolId=' + request.toolId);
      return;
    }
    if (this.toolGatewayUrl.trim().length === 0) {
      this.lastError = '模型请求工具，但 Tool Gateway URL 为空。';
      aiLogError('[AIPhone][ToolRequestBlocked] missingGateway toolId=' + request.toolId);
      return;
    }
    const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
    const actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
    aiLogInfo('[AIPhone][ToolRequest] toolId=' + request.toolId + ' promptChars=' + prompt.length.toString() + ' actionId=' + actionId);
    this.statusText = '正在调用工具';
    const result = await callToolGateway(this.toolGatewayUrl, request.toolId, prompt, this.currentSurface.surfaceId, actionId, (surface: A2uiSurfaceState, raw: string) => {
      this.updateSurfaceFromStream(surface, raw);
    });
    aiLogInfo('[AIPhone][ToolResult] ok=' + (result.ok ? 'true' : 'false') + ' errorChars=' + result.error.length.toString() + ' rawChars=' + result.raw.length.toString());
    this.updateSurfaceFromStream(result.surface, result.raw);
    this.statusText = this.statusLabel(result.surface.status);
    if (!result.ok) {
      this.lastError = result.error;
      this.appendMessage('assistant', '工具返回异常：' + result.error);
    } else {
      this.appendMessage('assistant', result.surface.title + ' 已返回 A2UI 结果。');
    }
  }

  private async sendPrompt(): Promise<void> {
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private async sendAction(action: A2uiAction): Promise<void> {
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
  TopBar() {
    Row() {
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
        .backgroundColor(COLOR_GLASS)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_LINE })
        .margin({ left: 10 })
        .onClick(() => {
          this.showHistory = !this.showHistory;
        })

      Button('配置')
        .height(40)
        .width(78)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_GLASS)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_LINE })
        .margin({ left: 8 })
        .onClick(() => {
          this.showConfigPage = true;
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 14 })
    .backgroundColor(COLOR_PANEL)
    .borderRadius(20)
    .border({ width: 1, color: '#FFFFFF' })
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
        this.SurfaceHero()
        if (this.surfaceDataModelJson.indexOf('"trainCode"') >= 0) {
          this.TrainOptions(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_TRAIN_OPTIONS, 'train_direct'), this.surfaceForRender().sequence)
        } else if (this.surfaceDataModelJson.indexOf('"flightNo"') >= 0) {
          this.FlightBoard(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_FLIGHT_BOARD, 'flight_direct'), this.surfaceForRender().sequence)
        } else if (this.surfaceDataModelJson.indexOf('"distance"') >= 0 && this.surfaceDataModelJson.indexOf('"foods"') >= 0) {
          this.FoodChoices(this.surfaceForRender(), this.componentWithType(A2UI_COMPONENT_FOOD_CHOICES, 'food_direct'), this.surfaceForRender().sequence)
        } else if (this.surfaceComponents.length === 0) {
          this.EmptySurface()
        } else if (!this.hasComponent(this.surfaceForRender(), this.surfaceForRender().rootId)) {
          this.ThinkingFallback(this.surfaceForRender())
        } else {
          this.RenderComponent(this.surfaceForRender(), this.componentOrFallback(this.surfaceForRender(), this.surfaceForRender().rootId), this.surfaceForRender().sequence)
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
    .border({ width: 1, color: '#FFFFFF' })
  }

  @Builder
  SurfaceHero() {
    Column() {
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
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ bottom: 14 })
  }

  @Builder
  EmptySurface() {
    Column() {
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
    .backgroundColor(COLOR_GLASS)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  ThinkingFallback(surface: A2uiSurfaceState) {
    Column() {
      Text('正在整理结果')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text('新的内容正在到达。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .margin({ top: 8 })
      this.SkeletonLines()
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(COLOR_WARN_SOFT)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_WARN })
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
      this.ThinkingStream(surface, component, revision)
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
  ThinkingStream(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      Text(this.componentTitle(component, 'AIPhone 正在处理'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text(this.componentBody(component, '正在生成任务画布'))
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 8 })
      this.ThinkingDots(revision)
      if (this.thoughtsOf(this.surfaceForRender(), component).length > 0) {
        Column() {
          ForEach(this.thoughtsOf(this.surfaceForRender(), component), (item: string) => {
            Text(item)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .padding({ top: 7, bottom: 7 })
          }, (item: string) => item + '-' + revision.toString())
        }
        .width('100%')
        .margin({ top: 10 })
      } else {
        this.SkeletonLines()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_WARN_SOFT)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_WARN })
    .margin({ bottom: 12 })
  }

  @Builder
  ThinkingDots(revision: number) {
    Row() {
      Text('')
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(COLOR_ACCENT_DARK)
        .opacity(this.thinkingDotOpacity(revision, 0))
      Text('')
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(COLOR_ACCENT_DARK)
        .opacity(this.thinkingDotOpacity(revision, 1))
        .margin({ left: 7 })
      Text('')
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(COLOR_ACCENT_DARK)
        .opacity(this.thinkingDotOpacity(revision, 2))
        .margin({ left: 7 })
    }
    .height(12)
    .margin({ top: 12 })
  }

  @Builder
  TrainOptions(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.ModuleHeader(this.componentTitle(component, '高铁候选'), this.componentBody(component), this.componentStatus(component))
      ForEach(trainOptions(this.surfaceForRender(), component), (item: A2uiTrainOption) => {
        Column() {
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
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: COLOR_LINE })
        .margin({ top: 10 })
      }, (item: A2uiTrainOption) => item.trainCode + item.depart + '-' + revision.toString())
      if (trainOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE })
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
      this.ModuleHeader(this.componentTitle(component, '航班候选'), this.componentBody(component), this.componentStatus(component))
      ForEach(flightOptions(this.surfaceForRender(), component), (item: A2uiFlightOption) => {
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
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: COLOR_LINE })
        .margin({ top: 10 })
      }, (item: A2uiFlightOption) => item.flightNo + item.depTime + '-' + revision.toString())
      if (flightOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ bottom: 12 })
  }

  @Builder
  FoodChoices(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.ModuleHeader(this.componentTitle(component, '附近餐饮'), this.componentBody(component), this.componentStatus(component))
      ForEach(foodOptions(this.surfaceForRender(), component), (item: A2uiFoodOption) => {
        Column() {
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
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: COLOR_LINE })
        .margin({ top: 10 })
      }, (item: A2uiFoodOption) => item.name + item.distance + '-' + revision.toString())
      if (foodOptions(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ bottom: 12 })
  }

  @Builder
  InfoRows(surface: A2uiSurfaceState, component: A2uiComponent, revision: number) {
    Column() {
      this.ModuleHeader(this.componentTitle(component, '信息'), this.componentBody(component), this.componentStatus(component))
      ForEach(labelValues(this.surfaceForRender(), component), (row: A2uiLabelValue) => {
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
      if (labelValues(this.surfaceForRender(), component).length === 0) {
        this.EmptyRows()
      }
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ bottom: 12 })
  }

  @Builder
  ErrorNotice(component: A2uiComponent) {
    Column() {
      Text(this.componentTitle(component, 'A2UI 错误'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ERROR)
      Text(this.componentBody(component, '无法渲染这次返回。'))
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(20)
        .margin({ top: 8 })
      this.ActionButtons(actionsOf(component))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_ERROR_SOFT)
    .borderRadius(18)
    .border({ width: 1, color: '#F6B8B3' })
    .margin({ bottom: 12 })
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
    .border({ width: 1, color: '#F6B8B3' })
  }

  @Builder
  ModuleHeader(title: string, body: string, status: string) {
    Row() {
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
  SkeletonLines() {
    Column() {
      Text('')
        .height(12)
        .width('82%')
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .margin({ top: 12 })
      Text('')
        .height(12)
        .width('62%')
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .margin({ top: 8 })
      Text('')
        .height(12)
        .width('42%')
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .margin({ top: 8 })
    }
    .width('100%')
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
            .backgroundColor(message.role === 'user' ? COLOR_ACCENT_SOFT : '#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: message.role === 'user' ? '#BBDCDD' : COLOR_LINE })
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
    .border({ width: 1, color: '#FFFFFF' })
  }

  @Builder
  InputDock() {
    Row() {
      TextInput({
        placeholder: '告诉 AIPhone 你想完成什么',
        text: this.inputText
      })
        .height(52)
        .layoutWeight(1)
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(15)
        .border({ width: 1, color: COLOR_LINE })
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
        .fontColor('#FFFFFF')
        .backgroundColor(COLOR_ACCENT_DARK)
        .borderRadius(15)
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
        .border({ width: 1, color: '#F6B8B3' })
        .margin({ bottom: 14 })
      }

      this.ModelPicker()
      this.InputLabel('Model', 14)
      TextInput({ text: this.selectedModel, placeholder: 'Qwen3-8B' })
        .height(42)
        .fontSize(13)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_LINE })
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.selectedModel = value;
        })

      this.InputLabel('Base URL', 16)
      TextInput({ text: this.baseUrl, placeholder: 'http://127.0.0.1:11434' })
        .height(42)
        .fontSize(13)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_LINE })
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.baseUrl = value;
        })

      this.InputLabel('API Key（可选）', 12)
      TextInput({ text: this.apiKey, placeholder: '如果接口要求鉴权，在这里填写' })
        .height(42)
        .fontSize(13)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_LINE })
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.apiKey = value;
        })

      this.InputLabel('Tool Gateway URL', 12)
      TextInput({ text: this.toolGatewayUrl, placeholder: 'http://127.0.0.1:8787' })
        .height(42)
        .fontSize(13)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_LINE })
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.toolGatewayUrl = value;
        })

      Row() {
        Button(this.isBusy ? '检查中' : '检查连接')
          .enabled(!this.isBusy)
          .height(42)
          .layoutWeight(1)
          .fontColor('#FFFFFF')
          .backgroundColor(COLOR_ACCENT_DARK)
          .borderRadius(10)
          .onClick(() => {
            this.testConnection();
          })

        Button(this.showSetupGuide ? '收起说明' : '查看说明')
          .height(42)
          .layoutWeight(1)
          .fontColor(COLOR_INK)
          .backgroundColor('#E7EFF0')
          .borderRadius(10)
          .border({ width: 1, color: COLOR_LINE })
          .margin({ left: 8 })
          .onClick(() => {
            this.showSetupGuide = !this.showSetupGuide;
          })
      }
      .width('100%')
      .margin({ top: 14 })

      if (this.showSetupGuide) {
        this.ConnectionGuide()
      }

      Divider()
        .color(COLOR_LINE)
        .margin({ top: 16, bottom: 14 })

      Button(this.showDiagnostics ? '收起技术详情' : '查看技术详情')
        .height(40)
        .width('100%')
        .fontColor(COLOR_INK)
        .backgroundColor('#F2F7F7')
        .borderRadius(10)
        .border({ width: 1, color: COLOR_LINE })
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
    .border({ width: 1, color: COLOR_LINE })
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
        this.ProviderPresetButton('本地 DeepSeek', URL_LOCAL_MODEL, MODEL_DEEPSEEK)
      }
      .width('100%')

      Row() {
        this.ProviderPresetButton('DeepSeek', URL_DEEPSEEK, MODEL_DEEPSEEK_CLOUD)
        this.ProviderPresetButton('百炼 Qwen', URL_DASHSCOPE, MODEL_DASHSCOPE)
        this.ProviderPresetButton('硅基 Qwen', URL_SILICONFLOW, MODEL_SILICONFLOW)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProviderPresetButton(label: string, baseUrl: string, model: string) {
    Button(label)
      .height(36)
      .layoutWeight(1)
      .fontSize(11)
      .fontColor(this.baseUrl === baseUrl && this.selectedModel === model ? '#FFFFFF' : COLOR_INK)
      .backgroundColor(this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_ACCENT_DARK : '#EDF4F4')
      .borderRadius(9)
      .border({ width: 1, color: this.baseUrl === baseUrl && this.selectedModel === model ? COLOR_ACCENT_DARK : COLOR_LINE })
      .margin({ right: 8 })
      .onClick(() => {
        this.applyProviderPreset(baseUrl, model);
      })
  }

  @Builder
  ConnectionGuide() {
    Column() {
      this.GuideStep('1', '本地模型流式', 'Local API 使用 OpenAI-compatible SSE，内容必须是 A2UI JSONL。')
      this.GuideStep('2', '工具网关', 'tool-gateway 返回 application/a2ui+json，设备通过 hdc rport 映射 8787。')
      this.GuideStep('3', '调试日志', '运行时会写入 AIPhone hilog，便于排查模型流和工具流。')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F9F9')
    .borderRadius(10)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ top: 12, bottom: 4 })
  }

  @Builder
  GuideStep(order: string, title: string, detail: string) {
    Row() {
      Text(order)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLOR_ACCENT)
        .borderRadius(7)

      Column() {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text(detail)
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .lineHeight(16)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .margin({ bottom: order === '3' ? 0 : 10 })
  }

  @Builder
  DiagnosticDetails() {
    Column() {
      this.DebugText('模型请求地址', buildChatCompletionsUrl(this.baseUrl))
      this.DebugText('工具网关', buildToolGatewayUrl(this.toolGatewayUrl))
      this.DebugScroll('最近 A2UI 原始流', this.lastRawStream.length > 0 ? this.lastRawStream : '暂无返回内容。', 128)
      this.DebugScroll('最近模型输入', this.lastModelRequest.length > 0 ? this.lastModelRequest : '暂无模型输入。', 140)
      this.DebugScroll('最近模型输出', this.lastModelOutput.length > 0 ? this.lastModelOutput : '暂无模型输出。', 140)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(COLOR_GLASS)
    .borderRadius(10)
    .border({ width: 1, color: COLOR_LINE })
    .margin({ top: 10 })
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
  DebugScroll(label: string, value: string, heightValue: number) {
    Text(label)
      .fontSize(11)
      .fontColor(COLOR_MUTED)
      .margin({ top: 12, bottom: 6 })
    Scroll() {
      Text(value)
        .fontSize(10)
        .fontColor(COLOR_TEXT)
        .lineHeight(15)
    }
    .height(heightValue)
    .width('100%')
    .padding(10)
    .backgroundColor('#FBFDFD')
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
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
            .backgroundColor('#E7EFF0')
            .borderRadius(10)
            .border({ width: 1, color: COLOR_LINE })
            .onClick(() => {
              this.showConfigPage = false;
            })

          Column() {
            Text('配置')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('管理 A2UI 模型连接和工具网关')
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
