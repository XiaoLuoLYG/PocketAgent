import {
  COLOR_ACCENT,
  COLOR_ACCENT_SHADOW,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_TEXT,
  statusColor
} from '../style/A2uiHomeTheme';
import {
  A2uiAction,
  A2uiMessage,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { A2uiButtonView } from './common/A2uiButtonView';
import { HistoryPanelView } from './HistoryPanelView';
import { HtmlHomeSurfaceView } from './HtmlHomeSurfaceView';
import {
  isPromptInputEnabled,
  nextSendSpinnerRotation
} from '../state/A2uiHomeState';
import {
  A2UI_HOME_MAX_WIDTH
} from '../style/A2uiHomeLayout';
import { A2UI_MOTION_CURVE, A2UI_MOTION_NORMAL_MS } from '../style/A2uiHomeMotion';

const A2UI_HISTORY_EMPTY_HEIGHT: number = 108;
const A2UI_HISTORY_ROW_HEIGHT: number = 76;
const A2UI_HISTORY_MAX_HEIGHT: number = 254;
const A2UI_SEND_SPINNER_INTERVAL_MS: number = 90;

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop isBusy: boolean = false;
  @Prop showHistory: boolean = false;
  @Prop messages: A2uiMessage[] = [];
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop htmlHomeHtml: string = '';
  @Prop surfaceRenderTick: number = 0;
  @Prop isAwaitingFirstSurface: boolean = false;
  @Prop inputPlaceholder: string = '告诉 Appless Phone 你想完成什么';
  @Prop isSocialReturnAvailable: boolean = false;
  @Prop showWelcome: boolean = false;
  @State sendSpinnerRotation: number = 0;
  private sendSpinnerTimerId: number = -1;
  onToggleHistory: () => void = () => {};
  onOpenSocial: () => void = () => {};
  onOpenConfig: () => void = () => {};
  onOpenStyleLab: () => void = () => {};
  onSendPrompt: () => void = () => {};
  onResetSession: () => void = () => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  aboutToAppear(): void {
    this.startSendSpinnerTimer();
  }

  aboutToDisappear(): void {
    this.stopSendSpinnerTimer();
  }

  private startSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId >= 0) {
      return;
    }
    this.sendSpinnerTimerId = setInterval(() => {
      this.sendSpinnerRotation = nextSendSpinnerRotation(this.sendSpinnerRotation, this.isBusy);
    }, A2UI_SEND_SPINNER_INTERVAL_MS);
  }

  private stopSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId < 0) {
      return;
    }
    clearInterval(this.sendSpinnerTimerId);
    this.sendSpinnerTimerId = -1;
  }

  private historyPanelHeight(): number {
    if (!this.showHistory) {
      return 0;
    }
    if (this.messages.length === 0) {
      return A2UI_HISTORY_EMPTY_HEIGHT;
    }
    const contentHeight = A2UI_HISTORY_EMPTY_HEIGHT + this.messages.length * A2UI_HISTORY_ROW_HEIGHT;
    return Math.min(contentHeight, A2UI_HISTORY_MAX_HEIGHT);
  }

  private shouldShowSocialBackButton(): boolean {
    return this.currentSurface.intent === 'social' && this.isSocialReturnAvailable;
  }

  private canResetSession(): boolean {
    return !this.isBusy && (!this.showWelcome || this.inputText.trim().length > 0);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(statusColor(this.currentSurface.status))
            .margin({ right: 8 })

          Text('Appless Phone')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .layoutWeight(1)

          A2uiButtonView({
            icon: $r('app.media.icon_history'),
            hasIcon: true,
            shape: 'circle',
            tone: 'secondary',
            active: this.showHistory
          })
            .onClick(() => {
              this.onToggleHistory();
            })
            .margin({ left: 8 })

          A2uiButtonView({
            icon: $r('app.media.icon_reset'),
            hasIcon: true,
            shape: 'circle',
            tone: 'secondary',
            isEnabled: this.canResetSession()
          })
            .enabled(this.canResetSession())
            .onClick(() => {
              if (!this.canResetSession()) {
                return;
              }
              this.onResetSession();
            })
            .margin({ left: 8 })

          if (this.shouldShowSocialBackButton()) {
            A2uiButtonView({
              icon: $r('app.media.icon_back'),
              hasIcon: true,
              shape: 'circle',
              tone: 'secondary'
            })
              .onClick(() => {
                this.onOpenSocial();
              })
              .margin({ left: 8 })
          } else {
            A2uiButtonView({
              icon: $r('app.media.icon_social'),
              hasIcon: true,
              shape: 'circle',
              tone: 'secondary',
              active: this.currentSurface.intent === 'social',
              customBackgroundColor: this.currentSurface.intent === 'social' ? COLOR_ACCENT_SOFT : '',
              customBorderColor: this.currentSurface.intent === 'social' ? COLOR_ACCENT : ''
            })
              .onClick(() => {
                this.onOpenSocial();
              })
              .margin({ left: 8 })
          }

          A2uiButtonView({
            icon: $r('app.media.icon_settings'),
            hasIcon: true,
            shape: 'circle',
            tone: 'secondary'
          })
            .onClick(() => {
              this.onOpenConfig();
            })
            .margin({ left: 8 })

          A2uiButtonView({
            icon: $r('app.media.icon_lab'),
            hasIcon: true,
            shape: 'circle',
            tone: 'secondary'
          })
            .onClick(() => {
              this.onOpenStyleLab();
            })
            .margin({ left: 8 })
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 0, right: 0 })
        .margin({ bottom: 12 })

      Column() {
        if (this.showHistory) {
          HistoryPanelView({
            messages: this.messages
          })
          .height('100%')
        }
      }
      .width('100%')
      .height(this.historyPanelHeight())
      .opacity(this.showHistory ? 1 : 0)
      .clip(true)
      .margin({ top: this.showHistory ? 14 : 0 })
      .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })

      HtmlHomeSurfaceView({
        html: this.htmlHomeHtml,
        isBusy: this.isBusy,
        renderTick: this.surfaceRenderTick,
        onAction: this.onAction
      })
      .layoutWeight(1)
      .margin({ top: 12 })

      Column() {
        Row() {
          TextArea({
            placeholder: this.inputPlaceholder,
            text: this.inputText
          })
            .constraintSize({ minHeight: 32, maxHeight: 72 })
            .layoutWeight(1)
            .fontSize(16)
            .fontColor(COLOR_TEXT)
            .lineHeight(24)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor('#00000000')
            .borderRadius(0)
            .border({ width: 0 })
            .padding({
              left: 0,
              right: 0,
              top: 4,
              bottom: 4
            })
            .enabled(isPromptInputEnabled(this.isBusy))
            .onChange((value: string) => {
              if (!isPromptInputEnabled(this.isBusy)) {
                return;
              }
              this.inputText = value;
            })

          A2uiButtonView({
            icon: this.isBusy ? $r('app.media.icon_wait_spinner') : $r('app.media.arrow_up'),
            hasIcon: true,
            shape: 'circle',
            circleSize: 40,
            iconSize: this.isBusy ? 22 : 18,
            customBackgroundColor: COLOR_ACCENT,
            customBorderWidth: 0,
            shadowColor: COLOR_ACCENT_SHADOW,
            shadowRadius: 15,
            iconRotation: this.sendSpinnerRotation
          })
            .animation({ duration: A2UI_SEND_SPINNER_INTERVAL_MS, curve: Curve.Linear })
            .margin({ left: 8 })
            .enabled(!this.isBusy)
            .onClick(() => {
              if (this.isBusy) {
                return;
              }
              this.onSendPrompt();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .constraintSize({ minHeight: 52 })
        .padding({ left: 16, right: 6, top: 6, bottom: 6 })
        .backgroundColor(COLOR_CARD)
        .borderRadius(26)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .shadow({ radius: 24, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 8 })

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, left: 0, right: 0 })
      }
      .width('100%')
      .constraintSize({ maxWidth: A2UI_HOME_MAX_WIDTH })
      .height('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 14 })
      .backgroundColor(COLOR_PAGE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
