import { A2uiMessage } from '../../../model/A2uiTypes';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_MOTION_CURVE, A2UI_MOTION_NORMAL_MS, a2uiEnterTransition } from '../style/A2uiHomeMotion';

@Component
export struct HistoryPanelView {
  @Prop messages: A2uiMessage[] = [];

  private roleLabel(role: string): string {
    return role === 'user' ? '你' : 'PocketAgent';
  }

  private rowBackground(role: string): string {
    return role === 'user' ? COLOR_ACCENT_SOFT : COLOR_FIELD;
  }

  private rowBorder(role: string): string {
    return role === 'user' ? COLOR_ACCENT : COLOR_CARD_EDGE;
  }

  build() {
    Column() {
      Row() {
        Text('生成轨迹')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text(this.messages.length.toString())
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(COLOR_CARD)
          .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })

      if (this.messages.length === 0) {
        Text('暂无对话轨迹')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(19)
          .padding({ top: 4, bottom: 4 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.messages, (message: A2uiMessage) => {
              Column() {
                Text(this.roleLabel(message.role))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(message.role === 'user' ? COLOR_ACCENT : COLOR_MUTED)
                Text(message.content)
                  .fontSize(12)
                  .fontColor(COLOR_TEXT)
                  .lineHeight(18)
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 5 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(11)
              .backgroundColor(this.rowBackground(message.role))
              .borderRadius(12)
              .border({ width: 1, color: this.rowBorder(message.role) })
              .margin({ bottom: 8 })
            }, (message: A2uiMessage) => message.id)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 190 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(COLOR_PANEL)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
    .transition(a2uiEnterTransition())
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })
  }
}
