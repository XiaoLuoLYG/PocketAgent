import { A2uiAction, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import {
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_PANEL_SHADOW,
  COLOR_TEXT
} from '../A2uiHomeTheme';
import { rootComponentIdOf } from '../A2uiRenderData';
import { A2uiNodeView } from './A2uiNodeView';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct A2uiSurfaceView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private hasRenderableSurface(): boolean {
    return this.surface.components.length > 0;
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text(this.surface.title.length > 0 ? this.surface.title : 'A2UI 原生任务画布')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('surface=' + this.surface.surfaceId + ' · seq=' + this.surface.sequence.toString() + ' · render=' + this.renderTick.toString())
              .fontSize(11)
              .fontColor(COLOR_MUTED)
              .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          StatusBadgeView({
            status: this.surface.status,
            label: this.surface.status
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 14 })

        if (this.hasRenderableSurface()) {
          A2uiNodeView({
            surface: this.surface,
            componentId: rootComponentIdOf(this.surface),
            renderTick: this.renderTick,
            isBusy: this.isBusy,
            onAction: this.onAction
          })
        } else {
          Column() {
            Text('主页已就绪')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('输入一句话生成 A2UI。')
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_CARD_EDGE })
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
}
