import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_TEXT,
} from '../style/A2uiHomeTheme';
import { A2uiAction, A2uiMessage, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { A2uiButtonView } from './common/A2uiButtonView';
import { HistoryPanelView } from './HistoryPanelView';
import { A2uiSurfaceView } from './A2uiSurfaceView';
import { A2UI_MOTION_CURVE, A2UI_MOTION_NORMAL_MS } from '../style/A2uiHomeMotion';

const A2UI_HISTORY_EMPTY_HEIGHT: number = 108;
const A2UI_HISTORY_ROW_HEIGHT: number = 76;
const A2UI_HISTORY_MAX_HEIGHT: number = 254;
const A2UI_SEND_SPINNER_INTERVAL_MS: number = 90;
const A2UI_SEND_SPINNER_STEP_DEG: number = 24;

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop isBusy: boolean = false;
  @Prop showHistory: boolean = false;
  @Prop messages: A2uiMessage[] = [];
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop surfaceRenderTick: number = 0;
  @Prop inputPlaceholder: string = '告诉 PocketAgent 你想完成什么';
  @State sendSpinnerRotation: number = 0;
  private sendSpinnerTimerId: number = -1;
  onToggleHistory: () => void = () => {};
  onOpenSocial: () => void = () => {};
  onOpenConfig: () => void = () => {};
  onOpenStyleLab: () => void = () => {};
  onSendPrompt: () => void = () => {};
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
      if (this.isBusy) {
        this.sendSpinnerRotation = (this.sendSpinnerRotation + A2UI_SEND_SPINNER_STEP_DEG) % 360;
      } else if (this.sendSpinnerRotation !== 0) {
        this.sendSpinnerRotation = 0;
      }
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

  build() {
    Column() {
      Row() {
        Row() {
          Text('PocketAgent')
            .minFontSize(20)
            .maxFontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('A2UI Home 最小刷新实验')
            .minFontSize(10)
            .maxFontSize(13)
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 8 })
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Center)
        .layoutWeight(1)
        .constraintSize({ maxWidth: 150 })

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
          .margin({ left: 10 })

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
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })

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

      A2uiSurfaceView({
        surface: this.currentSurface,
        renderTick: this.surfaceRenderTick,
        isBusy: this.isBusy,
        onAction: this.onAction
      })
      .layoutWeight(1)
      .margin({ top: 14 })

      Column() {
        Row() {
          TextArea({
            placeholder: this.inputPlaceholder,
            text: this.inputText
          })
            .constraintSize({ minHeight: 52 })
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .lineHeight(21)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor('#091017')
            .borderRadius(15)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 14, right: 14, top: 13, bottom: 13 })
            .onChange((value: string) => {
              this.inputText = value;
            })

          Stack() {
            if (this.isBusy) {
              Image($r('app.media.icon_wait_spinner'))
                .width(25)
                .height(25)
                .objectFit(ImageFit.Contain)
                .rotate({ angle: this.sendSpinnerRotation })
                .animation({ duration: A2UI_SEND_SPINNER_INTERVAL_MS, curve: Curve.Linear })
            } else {
              Image($r('app.media.arrow_up'))
                .width(27)
                .height(27)
                .objectFit(ImageFit.Contain)
            }
          }
            .width(46)
            .height(46)
            .backgroundColor(COLOR_ACCENT_DEEP)
            .borderRadius(23)
            .border({ width: 1, color: COLOR_ACCENT })
            .shadow({ radius: 14, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 7 })
            .margin({ left: 8, right: 2 })
            .onClick(() => {
              if (this.isBusy) {
                return;
              }
              this.onSendPrompt();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('surface=' + this.surfaceRenderTick.toString())
            .fontSize(11)
            .fontColor(COLOR_ACCENT)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, left: 4, right: 4 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(COLOR_PAGE)
  }
}
