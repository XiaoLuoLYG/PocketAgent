import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, flightOptions, A2uiFlightOption } from '../../../model/A2uiData';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_RAISED,
  COLOR_FIELD,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct FlightBoardView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'FlightBoard' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State selectedDate: Date = new Date();
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  aboutToAppear(): void {
    this.selectedDate = this.initialDate();
  }

  private flights(): A2uiFlightOption[] {
    return flightOptions(this.surface, this.component);
  }

  private visibleActions(): A2uiAction[] {
    const actions: A2uiAction[] = [];
    actionsOf(this.component).forEach((action: A2uiAction) => {
      if (action.id !== 'flight_change_date' && action.id !== 'flight_change_city') {
        actions.push(action);
      }
    });
    return actions;
  }

  private pad2(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  private formatDate(date: Date): string {
    return date.getFullYear().toString() + '-' + this.pad2(date.getMonth() + 1) + '-' + this.pad2(date.getDate());
  }

  private initialDate(): Date {
    const text = componentTitleOf(this.component, '') + ' ' + componentBodyOf(this.component, '');
    const match = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(text);
    if (match !== null) {
      const year = Number(match[1]);
      const month = Number(match[2]);
      const day = Number(match[3]);
      if (year > 1970 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return new Date(year, month - 1, day);
      }
    }
    return new Date();
  }

  private retryPrompt(): string {
    const dateText = this.formatDate(this.selectedDate);
    const flights = this.flights();
    if (flights.length > 0 && flights[0].dep.length > 0 && flights[0].arr.length > 0) {
      return '查询 ' + dateText + ' ' + flights[0].dep + ' 到 ' + flights[0].arr + ' 航班';
    }
    return '把当前航班查询改到 ' + dateText + '，沿用当前出发城市和到达城市';
  }

  private retryAction(): A2uiAction {
    return {
      id: 'flight_retry_date',
      label: '重新查询',
      prompt: this.retryPrompt(),
      kind: 'prompt',
      variant: 'primary'
    };
  }

  private flightRoute(item: A2uiFlightOption): string {
    const dep = item.dep.length > 0 ? item.dep : '--';
    const arr = item.arr.length > 0 ? item.arr : '--';
    return dep + ' → ' + arr;
  }

  private timeText(item: A2uiFlightOption): string {
    const dep = item.depTime.length > 0 ? item.depTime : '--';
    const arr = item.arrTime.length > 0 ? item.arrTime : '--';
    return dep + ' - ' + arr;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '航班候选'))
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

      if (this.flights().length === 0) {
        Text('暂无可展示航班')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.flights(), (item: A2uiFlightOption) => {
          Column() {
            Row() {
              Column() {
                Text(item.flightNo.length > 0 ? item.flightNo : '--')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                Text(item.airline.length > 0 ? item.airline : '航空公司待确认')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(18)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (item.price.length > 0) {
                Text('¥' + item.price)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DARK)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(8)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Row() {
              Text(this.flightRoute(item))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT)
                .layoutWeight(1)
              Text(item.status.length > 0 ? item.status : '计划')
                .fontSize(12)
                .fontColor(COLOR_ACCENT_DARK)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 12 })

            Text(this.timeText(item))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
          .margin({ top: 10 })
        }, (item: A2uiFlightOption) => item.flightNo + item.depTime + item.arrTime + '-' + this.renderTick.toString())
      }

      Column() {
        Text('调整日期')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ bottom: 8 })
        Row() {
          CalendarPicker({
            selected: this.selectedDate
          })
            .onChange((value: Date) => {
              this.selectedDate = value;
            })
            .markToday(true)
            .height(40)
            .layoutWeight(1)
            .textStyle({
              color: COLOR_INK,
              font: {
                size: 14,
                weight: FontWeight.Medium
              }
            })
            .backgroundColor(COLOR_FIELD)
            .borderRadius(11)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 10, right: 10 })
          Button('重新查询')
            .enabled(!this.isBusy)
            .height(40)
            .fontSize(13)
            .fontColor(COLOR_BUTTON_TEXT)
            .backgroundColor(COLOR_ACCENT_DEEP)
            .borderRadius(11)
            .border({ width: 1, color: COLOR_ACCENT })
            .padding({ left: 14, right: 14 })
            .margin({ left: 10 })
            .onClick(() => {
              this.onAction(this.retryAction());
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .backgroundColor(COLOR_CARD_RAISED)
      .borderRadius(14)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .margin({ top: 12 })

      ActionBarView({
        actions: this.visibleActions(),
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
