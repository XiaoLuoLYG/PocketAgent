import { LocalModelSettings, defaultLocalModelSettings } from '../../model/LocalModelSettings';
import { A2uiAction, A2uiCallResult, A2uiComponent, A2uiMessage, A2uiSurfaceState } from '../../model/A2uiTypes';
import { A2uiStreamMeta, callLocalModel, modelThinkCloseSeen } from '../../model/LocalModelClient';
import { createSeedA2uiSurface } from '../../model/A2uiSurfaceStore';
import { aiLogError, aiLogInfo } from '../../model/AiphoneLogger';
import { callToolGateway, defaultToolGatewayUrl, isRegisteredToolId } from '../../model/ToolGatewayClient';
import { HomePage } from './components/HomePage';
import { ConfigPage } from './components/ConfigPage';
import {
  ConnectionPanelState,
  createInitialConnectionPanelState,
  updateConnectionPanelState
} from './A2uiHomeState';
import { A2uiHomeResolvedToolRequest, resolveA2uiHomeToolRequest } from './A2uiHomeToolRequest';

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;

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
  @State inputText: string = '帮我查询明天北京到上海的航班';
  @State messages: A2uiMessage[] = [];

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
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private async sendAction(action: A2uiAction): Promise<void> {
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
        connectionStatus: this.connectionStatus,
        connectionMessage: this.connectionMessage,
        selectedModel: this.selectedModel,
        baseUrl: this.baseUrl,
        isBusy: this.isBusy,
        refreshTick: this.refreshTick,
        currentSurface: this.currentSurface,
        surfaceRenderTick: this.surfaceRenderTick,
        onOpenConfig: () => {
          this.showConfigPage = true;
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
