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
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import {
  A2UI_TRAIN_ACTION_SHOW_MORE,
  A2UI_TRAIN_INITIAL_VISIBLE,
  A2uiTrainViewState,
  isLocalTrainAction,
  nextTrainViewStateForAction,
  trainActionForState,
  visibleTrainOptions
} from '../state/A2uiTrainOptionsState';
import { A2UI_MOTION_CURVE, A2UI_MOTION_NORMAL_MS, a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

const A2UI_TRAIN_CARD_BASE_HEIGHT: number = 152;
const A2UI_TRAIN_CARD_EXPANDED_HEIGHT: number = 232;
const A2UI_TRAIN_CARD_TOP_MARGIN: number = 10;
const A2UI_TRAIN_LIST_EMPTY_HEIGHT: number = 50;

@Component
export struct TrainOptionsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'TrainOptions' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State expandedTrainKey: string = '';
  @State showAllTrains: boolean = false;
  @State fastestFirst: boolean = false;
  @State availableOnly: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private trains(): A2uiTrainOption[] {
    return trainOptions(this.surface, this.component);
  }

  private viewState(): A2uiTrainViewState {
    return {
      showAll: this.showAllTrains,
      fastestFirst: this.fastestFirst,
      availableOnly: this.availableOnly
    };
  }

  private visibleTrains(): A2uiTrainOption[] {
    return visibleTrainOptions(this.trains(), this.viewState());
  }

  private trainCardHeight(item: A2uiTrainOption): number {
    return this.expandedTrainKey === this.trainKey(item) ? A2UI_TRAIN_CARD_EXPANDED_HEIGHT : A2UI_TRAIN_CARD_BASE_HEIGHT;
  }

  private trainListHeight(): number {
    const items = this.visibleTrains();
    if (items.length === 0) {
      return A2UI_TRAIN_LIST_EMPTY_HEIGHT;
    }
    let height = 0;
    items.forEach((item: A2uiTrainOption) => {
      height = height + this.trainCardHeight(item) + A2UI_TRAIN_CARD_TOP_MARGIN;
    });
    return height;
  }

  private titleText(): string {
    return componentTitleOf(this.component, '高铁候选');
  }

  private showTitle(): boolean {
    const title = this.titleText();
    return title.length > 0 && title !== this.surface.title;
  }

  private visibleActions(): A2uiAction[] {
    const source = actionsOf(this.component);
    const next: A2uiAction[] = [];
    source.forEach((action: A2uiAction) => {
      if (action.id === A2UI_TRAIN_ACTION_SHOW_MORE && this.trains().length <= A2UI_TRAIN_INITIAL_VISIBLE) {
        return;
      }
      next.push(trainActionForState(action, this.showAllTrains, this.fastestFirst, this.availableOnly));
    });
    return next;
  }

  private handleAction(action: A2uiAction): void {
    if (!isLocalTrainAction(action)) {
      this.onAction(action);
      return;
    }
    const next = nextTrainViewStateForAction(this.viewState(), action);
    this.showAllTrains = next.showAll;
    this.fastestFirst = next.fastestFirst;
    this.availableOnly = next.availableOnly;
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
          if (this.showTitle()) {
            Text(this.titleText())
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
          }
          if (componentBodyOf(this.component).length > 0) {
            Text(componentBodyOf(this.component))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: this.showTitle() ? 7 : 0 })
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

      Column() {
        if (this.visibleTrains().length === 0) {
          Text('暂无可展示车次')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .padding({ top: 14, bottom: 4 })
        } else {
          ForEach(this.visibleTrains(), (item: A2uiTrainOption) => {
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
                .transition(a2uiEnterTransition(4))
              }
            }
            .width('100%')
            .height(this.trainCardHeight(item))
            .clip(true)
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor(COLOR_CARD)
            .borderRadius(16)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
            .margin({ top: 10 })
            .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })
            .transition(a2uiEnterTransition())
            .onClick(() => {
              const rowKey = this.trainKey(item);
              this.expandedTrainKey = this.expandedTrainKey === rowKey ? '' : rowKey;
            })
          }, (item: A2uiTrainOption) => this.trainKey(item) + '-' + this.renderTick.toString())
        }
      }
      .width('100%')
      .height(this.trainListHeight())
      .clip(true)
      .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })

      ActionBarView({
        actions: this.visibleActions(),
        isBusy: this.isBusy,
        onAction: (action: A2uiAction) => {
          this.handleAction(action);
        }
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
