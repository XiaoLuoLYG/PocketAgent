import {
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  A2uiAction,
  A2uiFlightData,
  A2uiFoodData,
  A2uiMessage,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { A2uiButtonView } from './common/A2uiButtonView';
import { HistoryPanelView } from './HistoryPanelView';
import { A2uiSurfaceView } from './A2uiSurfaceView';
import {
  isPromptInputEnabled,
  nextSendSpinnerRotation,
  shouldShowQueryPendingSurface
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
  onPinNavigationCard: (item: A2uiFoodData) => void = (_item: A2uiFoodData) => {};
  onPinTravelNavigationCard: (item: A2uiTravelOptionData) => void = (_item: A2uiTravelOptionData) => {};
  onPinTrainNavigationCard: (item: A2uiTrainData) => void = (_item: A2uiTrainData) => {};
  onPinFlightNavigationCard: (item: A2uiFlightData) => void = (_item: A2uiFlightData) => {};

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

  @Builder
  private WelcomeCard() {
    Row() {
      Column() {
        Text('开始一个任务')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)

        Text('在底部输入一句话，生成原生任务卡片。')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 5 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('A2UI')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .maxLines(1)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#12323A')
        .borderRadius(12)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .backgroundColor(COLOR_PANEL)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Text('Appless Phone')
            .fontSize(18)
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
            label: '清',
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
              label: '社',
              shape: 'circle',
              tone: 'secondary',
              active: this.currentSurface.intent === 'social'
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
        .alignItems(VerticalAlign.Center)
        .padding({ left: 4, right: 4, top: 10, bottom: 16 })

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

      if (this.showWelcome) {
        Column() {
          this.WelcomeCard()
          Blank()
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 14 })
      } else {
        A2uiSurfaceView({
          surface: this.currentSurface,
          renderTick: this.surfaceRenderTick,
          isBusy: this.isBusy,
          showPendingSurface: shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface),
          onAction: this.onAction,
          onPinNavigationCard: (item: A2uiFoodData) => {
            this.onPinNavigationCard(item);
          },
          onPinTravelNavigationCard: (item: A2uiTravelOptionData) => {
            this.onPinTravelNavigationCard(item);
          },
          onPinTrainNavigationCard: (item: A2uiTrainData) => {
            this.onPinTrainNavigationCard(item);
          },
          onPinFlightNavigationCard: (item: A2uiFlightData) => {
            this.onPinFlightNavigationCard(item);
          }
        })
        .layoutWeight(1)
        .margin({ top: 14 })
      }

      Column() {
        Row() {
          TextArea({
            placeholder: this.inputPlaceholder,
            text: this.inputText
          })
            .constraintSize({ minHeight: 32, maxHeight: 72 })
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .lineHeight(21)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor('#00000000')
            .borderRadius(0)
            .border({ width: 0 })
            .padding({
              left: 0,
              right: 0,
              top: 5,
              bottom: 5
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
            circleSize: 32,
            iconSize: this.isBusy ? 20 : 16,
            customBackgroundColor: '#0D9488',
            customBorderWidth: 0,
            shadowColor: '#0D948866',
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
        .constraintSize({ minHeight: 48 })
        .padding({ left: 16, right: 8, top: 8, bottom: 8 })
        .backgroundColor('#18181B')
        .borderRadius(24)
        .border({ width: 1, color: '#27272A' })
        .shadow({ radius: 20, color: '#00000080', offsetX: 0, offsetY: 10 })

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, left: 4, right: 4 })
      }
      .width('100%')
      .constraintSize({ maxWidth: A2UI_HOME_MAX_WIDTH })
      .height('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor(COLOR_PAGE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
