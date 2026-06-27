import { webview } from '@kit.ArkWeb';
import { A2uiAction } from '../../../model/A2uiTypes';
import { aiLogError, aiLogInfo } from '../../../model/AiphoneLogger';
import { COLOR_PAGE } from '../style/A2uiHomeTheme';

type HtmlHomeActionValue = Object | string | number | boolean | null | undefined;

type HtmlHomePostedAction = Record<string, HtmlHomeActionValue>;

class HtmlHomeActionBridge {
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  postAction(raw: string): void {
    const action = parseHtmlHomeAction(raw);
    if (action !== null) {
      this.onAction(action);
    }
  }
}

@Component
export struct HtmlHomeSurfaceView {
  @Prop @Watch('onRenderStateChange') html: string = '';
  @Prop @Watch('onRenderStateChange') isBusy: boolean = false;
  @Prop renderTick: number = 0;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: HtmlHomeActionBridge = new HtmlHomeActionBridge();
  private loadedKey: string = '';
  private webReady: boolean = false;
  private busyFrameLoaded: boolean = false;

  aboutToAppear(): void {
    this.bridge.onAction = (action: A2uiAction): void => {
      this.onAction(action);
    };
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady) {
      return;
    }
    if (this.html.length === 0 || this.html === this.loadedKey) {
      return;
    }
    if (this.isBusy && this.busyFrameLoaded) {
      return;
    }
    try {
      this.controller.loadData(this.html, 'text/html', 'UTF-8', 'data:text/html;charset=utf-8,');
      this.loadedKey = this.html;
      if (this.isBusy) {
        this.busyFrameLoaded = true;
      }
      aiLogInfo('[AIPhone][HtmlHomeSurfaceLoad] chars=' + this.html.length.toString() +
        ' renderTick=' + this.renderTick.toString());
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeSurfaceLoadError] ' + JSON.stringify(error));
    }
  }

  onRenderStateChange(): void {
    if (!this.isBusy) {
      this.busyFrameLoaded = false;
    }
    this.loadHtmlIfNeeded();
  }

  build() {
    Web({ src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23F5F2EE"></body>', controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .javaScriptProxy({
        object: this.bridge,
        name: 'AIPhoneHome',
        methodList: ['postAction'],
        controller: this.controller
      })
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_PAGE)
      .onPageEnd(() => {
        this.webReady = true;
        this.loadHtmlIfNeeded();
      })
  }
}

function parseHtmlHomeAction(raw: string): A2uiAction | null {
  try {
    const parsed = JSON.parse(raw) as HtmlHomePostedAction;
    const keys = Object.keys(parsed);
    if (keys.indexOf('id') < 0 || keys.indexOf('label') < 0 ||
      keys.indexOf('prompt') < 0 || keys.indexOf('kind') < 0) {
      return null;
    }
    return {
      id: actionText(parsed['id']),
      label: actionText(parsed['label']),
      prompt: actionText(parsed['prompt']),
      variant: actionText(parsed['variant']),
      kind: actionText(parsed['kind']),
      args: actionObject(parsed['args'])
    };
  } catch (error) {
    return null;
  }
}

function actionText(value: HtmlHomeActionValue): string {
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

function actionObject(value: HtmlHomeActionValue): Object | undefined {
  if (value === undefined || value === null || typeof value !== 'object') {
    return undefined;
  }
  return value;
}
