import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, trainOptions, A2uiTrainOption } from '../../../model/A2uiData';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_FIELD,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../A2uiRenderData';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct TrainOptionsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'TrainOptions' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State expandedTrainKey: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private trains(): A2uiTrainOption[] {
    return trainOptions(this.surface, this.component);
  }

  private trainKey(item: A2uiTrainOption): string {
    return item.trainCode + '|' + item.depart + '|' + item.from;
  }

  private seatText(label: string, value: string): string {
    if (value.length === 0) {
      return '';
    }
    return label + ' ' + value;
  }

  private seatSummary(item: A2uiTrainOption): string {
    const parts: string[] = [];
    const business = this.seatText('商务', item.business);
    const first = this.seatText('一等', item.first);
    const second = this.seatText('二等', item.second);
    const sleeper = this.seatText('卧铺', item.sleeperSoft);
    const noSeat = this.seatText('无座', item.noSeat);
    if (business.length > 0) {
      parts.push(business);
    }
    if (first.length > 0) {
      parts.push(first);
    }
    if (second.length > 0) {
      parts.push(second);
    }
    if (sleeper.length > 0) {
      parts.push(sleeper);
    }
    if (noSeat.length > 0) {
      parts.push(noSeat);
    }
    return parts.length > 0 ? parts.join(' · ') : item.seats;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '高铁候选'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          if (componentBodyOf(this.component).length > 0) {
            Text(componentBodyOf(this.component))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: 7 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        StatusBadgeView({
          status: componentStatusOf(this.component, this.surface.status),
          label: ''
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.trains().length === 0) {
        Text('暂无可展示车次')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.trains(), (item: A2uiTrainOption) => {
          Column() {
            Row() {
              Text(item.trainCode.length > 0 ? item.trainCode : '--')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
                .layoutWeight(1)
              if (item.duration.length > 0) {
                Text('耗时 ' + item.duration)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DARK)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(8)
              }
            }
            .width('100%')

            Row() {
              Column() {
                Text(item.depart.length > 0 ? item.depart : '--')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                Text(item.from.length > 0 ? item.from : '出发站')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('→')
                .fontSize(18)
                .fontColor(COLOR_MUTED)
                .margin({ left: 14, right: 14, top: 8 })

              Column() {
                Text(item.arrive.length > 0 ? item.arrive : '--')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                Text(item.to.length > 0 ? item.to : '到达站')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.End)
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 12 })

            Text(this.seatSummary(item))
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(19)
              .margin({ top: 10 })

            if (this.expandedTrainKey === this.trainKey(item)) {
              Column() {
                Text(item.status.length > 0 ? '状态：' + item.status : '状态：以 12306 为准')
                  .fontSize(12)
                  .fontColor(COLOR_TEXT)
                Text('以 12306 为准，不支持订票、支付或抢票。')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(18)
                  .margin({ top: 8 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(10)
              .border({ width: { left: 3 }, color: COLOR_ACCENT })
              .margin({ top: 10 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
          .margin({ top: 10 })
          .onClick(() => {
            const rowKey = this.trainKey(item);
            this.expandedTrainKey = this.expandedTrainKey === rowKey ? '' : rowKey;
          })
        }, (item: A2uiTrainOption) => this.trainKey(item) + '-' + this.renderTick.toString())
      }

      ActionBarView({
        actions: actionsOf(this.component),
        isBusy: this.isBusy,
        onAction: this.onAction
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    .backgroundColor(COLOR_GLASS)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }
}
