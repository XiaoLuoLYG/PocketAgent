import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, labelValues, A2uiLabelValue } from '../../../model/A2uiData';
import {
  COLOR_ERROR,
  COLOR_ERROR_LINE,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../A2uiHomeTheme';
import { componentBodyOf, componentTitleOf } from '../A2uiRenderData';
import { ActionBarView } from './ActionBarView';

@Component
export struct ErrorNoticeView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'ErrorNotice' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private rows(): A2uiLabelValue[] {
    return labelValues(this.surface, this.component);
  }

  build() {
    Column() {
      Text(componentTitleOf(this.component, 'A2UI 提示'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ERROR)
      Text(componentBodyOf(this.component, '当前结果需要检查。'))
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(20)
        .margin({ top: 8 })

      if (this.rows().length > 0) {
        Column() {
          ForEach(this.rows(), (row: A2uiLabelValue, index: number) => {
            Row() {
              Text(row.label)
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .width(72)
              Text(row.value)
                .fontSize(13)
                .fontColor(COLOR_TEXT)
                .lineHeight(19)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ top: index === 0 ? 0 : 8, bottom: 2 })
          }, (row: A2uiLabelValue, index: number) => row.label + row.value + index.toString() + '-' + this.renderTick.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_ERROR_LINE })
        .margin({ top: 12 })
      }

      ActionBarView({
        actions: actionsOf(this.component),
        isBusy: this.isBusy,
        onAction: this.onAction
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_ERROR_SOFT)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_ERROR_LINE })
    .margin({ bottom: 12 })
  }
}
