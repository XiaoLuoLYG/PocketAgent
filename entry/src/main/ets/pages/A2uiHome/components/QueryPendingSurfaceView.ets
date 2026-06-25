import {
  COLOR_ACCENT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED
} from '../style/A2uiHomeTheme';
import {
  A2UI_THINKING_DOT_MS,
  a2uiEnterTransition,
  a2uiThinkingDotOpacity,
  a2uiThinkingDotScale
} from '../style/A2uiHomeMotion';
import {
  A2UI_PANEL_BACKGROUND_COLOR,
  A2UI_PANEL_BORDER_COLOR,
  A2UI_PANEL_CORNER_RADIUS
} from '../style/A2uiPanelFrameStyle';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct QueryPendingSurfaceView {
  @State loadingStep: number = 0;
  private loadingTimerId: number = -1;

  aboutToAppear(): void {
    this.startLoadingTimer();
  }

  aboutToDisappear(): void {
    this.stopLoadingTimer();
  }

  private startLoadingTimer(): void {
    if (this.loadingTimerId >= 0) {
      return;
    }
    this.loadingTimerId = setInterval(() => {
      this.loadingStep = (this.loadingStep + 1) % 3;
    }, A2UI_THINKING_DOT_MS);
  }

  private stopLoadingTimer(): void {
    if (this.loadingTimerId < 0) {
      return;
    }
    clearInterval(this.loadingTimerId);
    this.loadingTimerId = -1;
  }

  private dotIndexes(): number[] {
    return [0, 1, 2];
  }

  build() {
    Column() {
      A2uiPanelAccentView()

      Column() {
        Row() {
          Column() {
            Text('正在理解你的请求')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('正在唤起本地模型，马上生成新的任务卡片。')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .lineHeight(18)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row() {
            ForEach(this.dotIndexes(), (dotIndex: number) => {
              Text('')
                .width(5)
                .height(5)
                .borderRadius(3)
                .backgroundColor(COLOR_ACCENT)
                .opacity(a2uiThinkingDotOpacity(dotIndex, this.loadingStep))
                .scale({
                  x: a2uiThinkingDotScale(dotIndex, this.loadingStep),
                  y: a2uiThinkingDotScale(dotIndex, this.loadingStep)
                })
                .margin({ right: dotIndex === 2 ? 0 : 6 })
                .animation({ duration: A2UI_THINKING_DOT_MS - 80, curve: Curve.EaseInOut })
            }, (dotIndex: number) => dotIndex.toString())
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .backgroundColor(COLOR_FIELD)
          .borderRadius(18)
          .border({ width: 1, color: COLOR_CARD_EDGE })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column() {
          Text('')
            .height(10)
            .width('72%')
            .borderRadius(5)
            .backgroundColor(COLOR_CARD_EDGE)
            .opacity(0.72)
          Text('')
            .height(10)
            .width('48%')
            .borderRadius(5)
            .backgroundColor(COLOR_CARD_EDGE)
            .opacity(0.46)
            .margin({ top: 10 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: 14, bottom: 14 })
        .backgroundColor(COLOR_FIELD)
        .borderRadius(14)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ top: 14 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
    .transition(a2uiEnterTransition())
  }
}
