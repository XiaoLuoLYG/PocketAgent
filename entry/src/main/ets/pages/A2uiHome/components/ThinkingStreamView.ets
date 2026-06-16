import { A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import {
  COLOR_ACCENT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_FIELD,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf, thinkingTextOf } from '../render/A2uiRenderData';
import {
  A2UI_THINKING_DOT_MS,
  A2UI_THINKING_PULSE_MIN,
  a2uiThinkingDotOpacity,
  a2uiThinkingDotScale,
  a2uiThinkingDotsActive,
  a2uiEnterTransition
} from '../style/A2uiHomeMotion';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct ThinkingStreamView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'ThinkingStream' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State loadingStep: number = 0;
  @State pulseActive: boolean = false;
  private loadingTimerId: number = -1;

  aboutToAppear(): void {
    this.pulseActive = true;
    this.startLoadingTimer();
  }

  aboutToDisappear(): void {
    this.pulseActive = false;
    this.stopLoadingTimer();
  }

  private startLoadingTimer(): void {
    if (this.loadingTimerId >= 0) {
      return;
    }
    this.loadingTimerId = setInterval(() => {
      if (!this.pulseActive) {
        return;
      }
      if (this.isThinkingActive()) {
        this.loadingStep = (this.loadingStep + 1) % 3;
      }
    }, A2UI_THINKING_DOT_MS);
  }

  private stopLoadingTimer(): void {
    if (this.loadingTimerId < 0) {
      return;
    }
    clearInterval(this.loadingTimerId);
    this.loadingTimerId = -1;
  }

  private titleText(): string {
    const title = componentTitleOf(this.component, '');
    if (title.length > 0) {
      return title;
    }
    return '正在理解你的请求';
  }

  private bodyText(): string {
    const body = componentBodyOf(this.component, '');
    if (body.length > 0) {
      return body;
    }
    const status = componentStatusOf(this.component, this.surface.status);
    if (status === 'calling_tool') {
      return '正在等待工具返回，结果会自动更新到任务画布。';
    }
    if (status === 'thinking') {
      return '正在拆解你的请求，并生成可执行的 A2UI。';
    }
    return '新的内容正在到达。';
  }

  private streamText(): string {
    return thinkingTextOf(this.surface, this.component);
  }

  private statusText(): string {
    return componentStatusOf(this.component, this.surface.status);
  }

  private dotIndexes(): number[] {
    const indexes: number[] = [0, 1, 2];
    return indexes;
  }

  private isThinkingActive(): boolean {
    return a2uiThinkingDotsActive(this.isBusy, this.statusText());
  }

  private showDots(): boolean {
    return this.isThinkingActive() || this.streamText().trim().length > 0;
  }

  private dotOpacity(index: number): number {
    if (!this.isThinkingActive()) {
      return index === 0 ? 0.9 : (index === 1 ? 0.55 : 0.28);
    }
    return a2uiThinkingDotOpacity(index, this.loadingStep);
  }

  private dotScale(index: number): number {
    if (!this.isThinkingActive()) {
      return A2UI_THINKING_PULSE_MIN;
    }
    return a2uiThinkingDotScale(index, this.loadingStep);
  }

  build() {
    Column() {
      Row() {
        Text('')
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(COLOR_ACCENT)
          .opacity(0.72)
          .margin({ top: 6, right: 12 })
        Column() {
          Text(this.titleText())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(this.bodyText())
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .lineHeight(18)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        StatusBadgeView({
          status: this.statusText(),
          label: this.statusText()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.streamText().trim().length > 0) {
        Row() {
          Text('')
            .width(2)
            .constraintSize({ minHeight: 72 })
            .backgroundColor(COLOR_ACCENT)
            .borderRadius(2)
            .opacity(0.78)
            .margin({ right: 12 })
          Scroll() {
            Text(this.streamText())
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .lineHeight(24)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .layoutWeight(1)
          .constraintSize({ maxHeight: 260 })
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .backgroundColor(COLOR_FIELD)
        .borderRadius(14)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ top: 14 })
        .transition(a2uiEnterTransition())
      } else {
        Row() {
          Text('')
            .width(2)
            .height(40)
            .backgroundColor(COLOR_ACCENT)
            .borderRadius(2)
            .opacity(0.55)
            .margin({ right: 12 })
          Text(this.statusText() === 'calling_tool' ? '正在等待工具返回，结果会自动更新到任务画布。' : '思考流正在写入，稍后显示完整内容。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(22)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .backgroundColor(COLOR_FIELD)
        .borderRadius(14)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ top: 14 })
        .transition(a2uiEnterTransition())
      }

      if (this.showDots()) {
        Row() {
          ForEach(this.dotIndexes(), (dotIndex: number) => {
            Text('')
              .width(5)
              .height(5)
              .borderRadius(3)
              .backgroundColor(COLOR_ACCENT)
              .opacity(this.dotOpacity(dotIndex))
              .scale({ x: this.dotScale(dotIndex), y: this.dotScale(dotIndex) })
              .margin({ right: dotIndex === 2 ? 0 : 6 })
              .animation({ duration: A2UI_THINKING_DOT_MS - 80, curve: Curve.EaseInOut })
          }, (dotIndex: number) => dotIndex.toString() + '-' + this.renderTick.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: 14 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
    .transition(a2uiEnterTransition())
  }
}
