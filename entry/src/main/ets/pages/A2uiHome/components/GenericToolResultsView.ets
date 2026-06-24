import {
  A2uiAction,
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { actionsOf, genericToolResults } from '../../../model/A2uiData';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct GenericToolResultsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'GenericToolResults' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private results(): A2uiGenericToolResultData[] {
    return genericToolResults(this.surface);
  }

  private titleOf(item: A2uiGenericToolResultData): string {
    if (item.title.length > 0) {
      return item.title;
    }
    return item.toolName.length > 0 ? item.toolName : '动态工具结果';
  }

  private componentTitle(): string {
    return this.component.title === undefined || this.component.title.length === 0 ? '动态工具结果' : this.component.title;
  }

  private isWeatherResult(item: A2uiGenericToolResultData): boolean {
    return item.toolName === 'maps_weather' || item.title.indexOf('天气') >= 0;
  }

  private rowValue(item: A2uiGenericToolResultData, label: string): string {
    for (let index = 0; index < item.rows.length; index++) {
      if (item.rows[index].label === label) {
        return item.rows[index].value;
      }
    }
    return '';
  }

  private firstRowValue(item: A2uiGenericToolResultData, labels: string[]): string {
    for (let index = 0; index < labels.length; index++) {
      const value = this.rowValue(item, labels[index]);
      if (value.length > 0) {
        return value;
      }
    }
    return '';
  }

  private weatherTemp(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['白天温度', '温度']);
  }

  private weatherCondition(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['白天天气', '天气']);
  }

  private weatherDate(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['预报日期', '发布时间']);
  }

  build() {
    Column() {
      A2uiPanelAccentView()
      Column() {
        Text(this.componentTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)

        if (this.results().length === 0) {
          Text('工具没有返回可展示结果。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .margin({ top: 12 })
        } else {
          ForEach(this.results(), (item: A2uiGenericToolResultData, index: number) => {
            Column() {
              if (this.isWeatherResult(item)) {
                Row() {
                  Column() {
                    Text(this.titleOf(item))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(COLOR_INK)
                    Text(this.weatherDate(item).length > 0 ? this.weatherDate(item) : item.sourceTag)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)
                  StatusBadgeView({ status: item.status, label: item.sourceTag })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row() {
                  Column() {
                    Text(this.weatherTemp(item).length > 0 ? this.weatherTemp(item) : '--')
                      .fontSize(34)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(COLOR_INK)
                      .fontFamily('HarmonyOS Sans')
                    Text(this.weatherCondition(item).length > 0 ? this.weatherCondition(item) : '天气')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(COLOR_ACCENT)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)

                  Column() {
                    Text(this.firstRowValue(item, ['夜间天气', '湿度']).length > 0 ? this.firstRowValue(item, ['夜间天气', '湿度']) : '实时来源')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(COLOR_TEXT)
                    Text(this.firstRowValue(item, ['夜间温度', '风力', '白天风力']).length > 0 ? this.firstRowValue(item, ['夜间温度', '风力', '白天风力']) : item.sourceTag)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .margin({ top: 5 })
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: 14, right: 14, top: 14, bottom: 14 })
                .margin({ top: 12 })
                .backgroundColor(COLOR_ACCENT_SOFT)
                .borderRadius(14)
                .border({ width: 1, color: COLOR_ACCENT })

                Text(item.summary)
                  .fontSize(13)
                  .fontColor(COLOR_TEXT)
                  .lineHeight(20)
                  .margin({ top: 12 })

                Column() {
                  ForEach(item.rows, (row: A2uiGenericToolResultRowData) => {
                    Row() {
                      Text(row.label)
                        .fontSize(12)
                        .fontColor(COLOR_MUTED)
                        .width(96)
                      Text(row.value)
                        .fontSize(13)
                        .fontColor(COLOR_TEXT)
                        .lineHeight(19)
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                    .padding({ top: 7, bottom: 7 })
                    .border({ width: { bottom: 1 }, color: COLOR_LINE })
                  }, (row: A2uiGenericToolResultRowData, rowIndex: number) => row.label + row.value + rowIndex.toString())
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ top: 12 })
                .backgroundColor(COLOR_CARD)
                .borderRadius(12)
                .border({ width: 1, color: COLOR_CARD_EDGE })
              } else {
                Row() {
                  Text(this.titleOf(item))
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(COLOR_TEXT)
                    .layoutWeight(1)
                  StatusBadgeView({ status: item.status, label: item.sourceTag })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Text(item.summary)
                  .fontSize(13)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(20)
                  .margin({ top: 8 })

                ForEach(item.rows, (row: A2uiGenericToolResultRowData) => {
                  Row() {
                    Text(row.label)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .width(88)
                    Text(row.value)
                      .fontSize(13)
                      .fontColor(COLOR_TEXT)
                      .lineHeight(19)
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .padding({ top: 8 })
                }, (row: A2uiGenericToolResultRowData, rowIndex: number) => row.label + row.value + rowIndex.toString())
              }

              if (item.status !== 'success' && item.rawPreview.length > 0) {
                Text(item.rawPreview)
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(16)
                  .maxLines(5)
                  .margin({ top: 10 })
              }
            }
            .width('100%')
            .padding({ left: this.isWeatherResult(item) ? 12 : 0, right: this.isWeatherResult(item) ? 12 : 0, top: 12, bottom: 12 })
            .backgroundColor(this.isWeatherResult(item) ? COLOR_CARD_RAISED : A2UI_PANEL_BACKGROUND_COLOR)
            .borderRadius(this.isWeatherResult(item) ? 16 : 0)
            .border({ width: { bottom: index === this.results().length - 1 ? 0 : 1 }, color: COLOR_CARD_EDGE })
            .transition(a2uiEnterTransition())
          }, (item: A2uiGenericToolResultData, index: number) => item.toolName + item.title + index.toString() + '-' + this.renderTick.toString())
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
