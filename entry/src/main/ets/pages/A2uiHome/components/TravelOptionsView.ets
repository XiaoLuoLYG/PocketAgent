import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, travelOptions, A2uiTravelOption } from '../../../model/A2uiData';
import {
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_INSET,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT,
  COLOR_TRAVEL_FLIGHT,
  COLOR_TRAVEL_FLIGHT_CARD,
  COLOR_TRAVEL_FLIGHT_GLOW,
  COLOR_TRAVEL_FLIGHT_LINE,
  COLOR_TRAVEL_FLIGHT_SOFT,
  COLOR_TRAVEL_TRAIN,
  COLOR_TRAVEL_TRAIN_CARD,
  COLOR_TRAVEL_TRAIN_GLOW,
  COLOR_TRAVEL_TRAIN_LINE,
  COLOR_TRAVEL_TRAIN_SOFT,
  statusColor
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

type TravelFilterMode = 'all' | 'train' | 'flight';

@Component
export struct TravelOptionsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'TravelOptions' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State filterMode: TravelFilterMode = 'all';
  @State expandedTravelKey: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private options(): A2uiTravelOption[] {
    return travelOptions(this.surface, this.component);
  }

  private parseClockMinutes(value: string): number {
    const match = /(\d{1,2}):(\d{2})/.exec(value);
    if (match !== null) {
      return Number.parseInt(match[1], 10) * 60 + Number.parseInt(match[2], 10);
    }
    return 99999;
  }

  private sourceOrder(source: string): number {
    if (source === 'train') {
      return 0;
    }
    if (source === 'flight') {
      return 1;
    }
    return 2;
  }

  private sortedOptions(rows: A2uiTravelOption[]): A2uiTravelOption[] {
    const copy = rows.slice();
    copy.sort((left: A2uiTravelOption, right: A2uiTravelOption) => {
      const departDelta = this.parseClockMinutes(left.depart) - this.parseClockMinutes(right.depart);
      if (departDelta !== 0) {
        return departDelta;
      }
      const arriveDelta = this.parseClockMinutes(left.arrive) - this.parseClockMinutes(right.arrive);
      if (arriveDelta !== 0) {
        return arriveDelta;
      }
      return this.sourceOrder(left.source) - this.sourceOrder(right.source);
    });
    return copy;
  }

  private visibleOptions(): A2uiTravelOption[] {
    let rows = this.options();
    if (this.filterMode === 'train') {
      rows = rows.filter((item: A2uiTravelOption) => item.source === 'train');
    } else if (this.filterMode === 'flight') {
      rows = rows.filter((item: A2uiTravelOption) => item.source === 'flight');
    }
    return this.sortedOptions(rows);
  }

  private rowKey(item: A2uiTravelOption): string {
    return item.id + '|' + item.source + '|' + item.depart + '|' + item.from;
  }

  private sourceLabel(item: A2uiTravelOption): string {
    if (item.sourceTag.length > 0) {
      return item.sourceTag;
    }
    return item.source === 'flight' ? '飞机 · 飞常准' : '高铁 · 12306';
  }

  private sourceAccent(source: string): string {
    if (source === 'flight') {
      return COLOR_TRAVEL_FLIGHT;
    }
    return COLOR_TRAVEL_TRAIN;
  }

  private sourceSoft(source: string): string {
    if (source === 'flight') {
      return COLOR_TRAVEL_FLIGHT_SOFT;
    }
    return COLOR_TRAVEL_TRAIN_SOFT;
  }

  private sourceLine(source: string): string {
    if (source === 'flight') {
      return COLOR_TRAVEL_FLIGHT_LINE;
    }
    return COLOR_TRAVEL_TRAIN_LINE;
  }

  private sourceCard(source: string): string {
    if (source === 'flight') {
      return COLOR_TRAVEL_FLIGHT_CARD;
    }
    return COLOR_TRAVEL_TRAIN_CARD;
  }

  private sourceGlow(source: string): string {
    if (source === 'flight') {
      return COLOR_TRAVEL_FLIGHT_GLOW;
    }
    return COLOR_TRAVEL_TRAIN_GLOW;
  }

  private isLocalTravelAction(action: A2uiAction): boolean {
    return action.id === 'travel_show_all' || action.id === 'travel_filter_train' || action.id === 'travel_filter_flight';
  }

  private actionForFilter(action: A2uiAction): A2uiAction {
    let active = false;
    if (action.id === 'travel_show_all') {
      active = this.filterMode === 'all';
    } else if (action.id === 'travel_filter_train') {
      active = this.filterMode === 'train';
    } else if (action.id === 'travel_filter_flight') {
      active = this.filterMode === 'flight';
    }
    if (!active) {
      return action;
    }
    return {
      id: action.id,
      label: action.label,
      prompt: action.prompt,
      kind: action.kind,
      variant: 'activated'
    };
  }

  private visibleActions(): A2uiAction[] {
    const next: A2uiAction[] = [];
    actionsOf(this.component).forEach((action: A2uiAction) => {
      next.push(this.actionForFilter(action));
    });
    return next;
  }

  private handleAction(action: A2uiAction): void {
    if (!this.isLocalTravelAction(action)) {
      this.onAction(action);
      return;
    }
    if (action.id === 'travel_filter_train') {
      this.filterMode = 'train';
    } else if (action.id === 'travel_filter_flight') {
      this.filterMode = 'flight';
    } else {
      this.filterMode = 'all';
    }
  }

  @Builder
  private StationTime(name: string, time: string) {
    Column() {
      Text(time.length > 0 ? time : '--')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text(name.length > 0 ? name : '待确认')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width(58)
      Text(value)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private TravelDetailPanel(item: A2uiTravelOption) {
    Column() {
      this.DetailRow('来源', this.sourceLabel(item))
      this.DetailRow('路线', (item.from.length > 0 ? item.from : '--') + ' → ' + (item.to.length > 0 ? item.to : '--'))
      this.DetailRow('时间', (item.depart.length > 0 ? item.depart : '--') + ' → ' + (item.arrive.length > 0 ? item.arrive : '--'))
      if (item.duration.length > 0) {
        this.DetailRow('耗时', item.duration)
      }
      if (item.price.length > 0) {
        this.DetailRow('价格', item.price)
      }
      if (item.availability.length > 0) {
        this.DetailRow('余票', item.availability)
      }
      if (item.status.length > 0) {
        this.DetailRow('状态', item.status)
      }
      if (item.detail.length > 0) {
        this.DetailRow('详情', item.detail)
      }
      Text(item.source === 'flight' ? '以飞常准返回为准，不支持订票' : '以 12306 返回为准，不支持订票')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(10)
    .border({ width: { left: 3 }, color: this.sourceLine(item.source) })
    .margin({ top: 10 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '出行方案'))
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

      Row() {
        Text('高铁 · 12306')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TRAVEL_TRAIN)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(COLOR_TRAVEL_TRAIN_SOFT)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_TRAVEL_TRAIN_LINE })
        Text('飞机 · 飞常准')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TRAVEL_FLIGHT)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(COLOR_TRAVEL_FLIGHT_SOFT)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_TRAVEL_FLIGHT_LINE })
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 10 })

      ActionBarView({
        actions: this.visibleActions(),
        isBusy: this.isBusy,
        onAction: (action: A2uiAction) => {
          this.handleAction(action);
        }
      })

      if (this.visibleOptions().length === 0) {
        Text('暂无可展示出行方案')
          .height(52)
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 17 })
      } else {
        ForEach(this.visibleOptions(), (item: A2uiTravelOption) => {
          Column() {
            Column() {
              Row() {
                Text(this.sourceLabel(item))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.sourceAccent(item.source))
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(this.sourceSoft(item.source))
                  .borderRadius(8)
                  .border({ width: 1, color: this.sourceLine(item.source) })
                Blank()
                  .layoutWeight(1)
                if (item.status.length > 0) {
                  Text(item.status)
                    .fontSize(12)
                    .fontColor(statusColor(item.status.indexOf('失败') >= 0 || item.status.indexOf('取消') >= 0 ? 'error' : 'ready'))
                }
                Text(this.expandedTravelKey === this.rowKey(item) ? '收起' : '详情')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.sourceAccent(item.source))
                  .margin({ left: 10 })
              }
              .width('100%')

              Row() {
                Column() {
                  Text(item.title.length > 0 ? item.title : '出行方案')
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(COLOR_INK)
                  if (item.detail.length > 0) {
                    Text(item.detail)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .lineHeight(18)
                      .margin({ top: 4 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  if (item.price.length > 0) {
                    Text(item.price)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.sourceAccent(item.source))
                  } else if (item.availability.length > 0) {
                    Text(item.availability)
                      .fontSize(13)
                      .fontColor(COLOR_TEXT)
                      .lineHeight(18)
                  }
                  if (item.duration.length > 0) {
                    Text('耗时 ' + item.duration)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .margin({ top: 5 })
                  }
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .margin({ top: 12 })

              Row() {
                this.StationTime(item.from, item.depart)
                Text('→')
                  .fontSize(18)
                  .fontColor(COLOR_MUTED)
                  .margin({ left: 14, right: 14, top: 8 })
                this.StationTime(item.to, item.arrive)
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.sourceCard(item.source))
            .borderRadius(16)
            .border({ width: 1, color: this.sourceLine(item.source) })
            .shadow({ radius: 20, color: this.sourceGlow(item.source), offsetX: 0, offsetY: 9 })
            .onClick(() => {
              const key = this.rowKey(item);
              this.expandedTravelKey = this.expandedTravelKey === key ? '' : key;
            })

            if (this.expandedTravelKey === this.rowKey(item)) {
              this.TravelDetailPanel(item)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 10 })
        }, (item: A2uiTravelOption) => this.rowKey(item) + '-' + this.renderTick.toString())
      }
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
