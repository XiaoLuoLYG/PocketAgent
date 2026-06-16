import {
  COLOR_CARD_EDGE,
  COLOR_FIELD,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';

@Component
export struct DebugTextPanel {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop refreshTick: number = 0;

  build() {
    Column() {
      Row() {
        Text(this.label)
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Text('刷新 ' + this.refreshTick.toString())
          .fontSize(10)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12, bottom: 6 })

      Scroll() {
        Text(this.value.length > 0 ? this.value : '暂无内容')
          .fontSize(10)
          .fontColor(COLOR_TEXT)
          .lineHeight(15)
          .width('100%')
      }
      .constraintSize({ minHeight: 58, maxHeight: 130 })
      .width('100%')
      .padding(10)
      .backgroundColor(COLOR_FIELD)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
