import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_COMPONENT_TRAVEL_OPTIONS,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2uiAction,
  A2uiComponent,
  A2uiFlightData,
  A2uiFoodData,
  A2uiTrainData,
  A2uiTravelOptionData,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { actionsOf } from '../../../model/A2uiData';
import {
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  childIdsOf,
  componentTextOf,
  componentTitleOf,
  componentToneOf,
  componentVariantOf,
  findA2uiComponent
} from '../render/A2uiRenderData';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { ErrorNoticeView } from './ErrorNoticeView';
import { FlightBoardView } from './FlightBoardView';
import { FoodChoicesView } from './FoodChoicesView';
import { GenericToolResultsView } from './GenericToolResultsView';
import { SocialHubView } from './SocialHubView';
import { InfoRowsView } from './InfoRowsView';
import { ThinkingStreamView } from './ThinkingStreamView';
import { ToolConnectCardView } from './ToolConnectCardView';
import { TrainOptionsView } from './TrainOptionsView';
import { TravelOptionsView } from './TravelOptionsView';

@Component
export struct A2uiNodeView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop componentId: string = '';
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onPinNavigationCard: (item: A2uiFoodData) => void = (_item: A2uiFoodData) => {};
  onPinTravelNavigationCard: (item: A2uiTravelOptionData) => void = (_item: A2uiTravelOptionData) => {};
  onPinTrainNavigationCard: (item: A2uiTrainData) => void = (_item: A2uiTrainData) => {};
  onPinFlightNavigationCard: (item: A2uiFlightData) => void = (_item: A2uiFlightData) => {};

  private component(): A2uiComponent | null {
    return findA2uiComponent(this.surface, this.componentId);
  }

  private childIds(component: A2uiComponent): string[] {
    return childIdsOf(component);
  }

  build() {
    if (this.component() === null) {
      Column() {
        Text('组件缺失')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_ERROR)
        Text(this.componentId)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(14)
      .backgroundColor(COLOR_ERROR_SOFT)
      .borderRadius(12)
      .margin({ bottom: 10 })
    } else {
      if (this.component()?.component === A2UI_COMPONENT_SURFACE_ROOT || this.component()?.component === A2UI_COMPONENT_COLUMN) {
        Column() {
          if (componentTitleOf(this.component() as A2uiComponent).length > 0 && this.component()?.component === A2UI_COMPONENT_COLUMN) {
            Text(componentTitleOf(this.component() as A2uiComponent))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .margin({ bottom: 8 })
          }
          ForEach(this.childIds(this.component() as A2uiComponent), (childId: string) => {
            A2uiNodeView({
              surface: this.surface,
              componentId: childId,
              renderTick: this.renderTick,
              isBusy: this.isBusy,
              onAction: this.onAction,
              onPinNavigationCard: (item: A2uiFoodData) => {
                this.onPinNavigationCard(item);
              },
              onPinTravelNavigationCard: (item: A2uiTravelOptionData) => {
                this.onPinTravelNavigationCard(item);
              },
              onPinTrainNavigationCard: (item: A2uiTrainData) => {
                this.onPinTrainNavigationCard(item);
              },
              onPinFlightNavigationCard: (item: A2uiFlightData) => {
                this.onPinFlightNavigationCard(item);
              }
            })
          }, (childId: string) => childId + '-' + this.renderTick.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: this.component()?.component === A2UI_COMPONENT_COLUMN ? 8 : 0 })
      } else if (this.component()?.component === A2UI_COMPONENT_ROW) {
        Row() {
          ForEach(this.childIds(this.component() as A2uiComponent), (childId: string) => {
            A2uiNodeView({
              surface: this.surface,
              componentId: childId,
              renderTick: this.renderTick,
              isBusy: this.isBusy,
              onAction: this.onAction,
              onPinNavigationCard: (item: A2uiFoodData) => {
                this.onPinNavigationCard(item);
              },
              onPinTravelNavigationCard: (item: A2uiTravelOptionData) => {
                this.onPinTravelNavigationCard(item);
              },
              onPinTrainNavigationCard: (item: A2uiTrainData) => {
                this.onPinTrainNavigationCard(item);
              },
              onPinFlightNavigationCard: (item: A2uiFlightData) => {
                this.onPinFlightNavigationCard(item);
              }
            })
          }, (childId: string) => childId + '-' + this.renderTick.toString())
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: 10 })
      } else if (this.component()?.component === A2UI_COMPONENT_TEXT) {
        Text(componentTextOf(this.component() as A2uiComponent))
          .fontSize(componentVariantOf(this.component() as A2uiComponent) === 'title' ? 20 : 14)
          .fontWeight(componentVariantOf(this.component() as A2uiComponent) === 'title' ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(componentToneOf(this.component() as A2uiComponent) === 'muted' ? COLOR_MUTED : COLOR_TEXT)
          .lineHeight(componentVariantOf(this.component() as A2uiComponent) === 'title' ? 26 : 21)
          .margin({ bottom: 10 })
          .transition(a2uiEnterTransition())
      } else if (this.component()?.component === A2UI_COMPONENT_INFO_ROWS) {
        InfoRowsView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_TRAIN_OPTIONS) {
        TrainOptionsView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction,
          onPinTrainNavigationCard: (item: A2uiTrainData) => {
            this.onPinTrainNavigationCard(item);
          }
        })
        .key('train-options-' + this.componentId + '-' + this.renderTick.toString())
      } else if (this.component()?.component === A2UI_COMPONENT_TRAVEL_OPTIONS) {
        TravelOptionsView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction,
          onPinTravelNavigationCard: (item: A2uiTravelOptionData) => {
            this.onPinTravelNavigationCard(item);
          }
        })
      } else if (this.component()?.component === A2UI_COMPONENT_FLIGHT_BOARD) {
        FlightBoardView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction,
          onPinFlightNavigationCard: (item: A2uiFlightData) => {
            this.onPinFlightNavigationCard(item);
          }
        })
      } else if (this.component()?.component === A2UI_COMPONENT_FOOD_CHOICES) {
        FoodChoicesView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction,
          onPinNavigationCard: (item: A2uiFoodData) => {
            this.onPinNavigationCard(item);
          }
        })
      } else if (this.component()?.component === A2UI_COMPONENT_TOOL_CONNECT_CARD) {
        ToolConnectCardView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_GENERIC_TOOL_RESULTS) {
        GenericToolResultsView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_SOCIAL_HUB) {
        SocialHubView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_ACTION_BAR) {
        ActionBarView({
          actions: actionsOf(this.component() as A2uiComponent),
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_ERROR_NOTICE) {
        ErrorNoticeView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      } else if (this.component()?.component === A2UI_COMPONENT_THINKING_STREAM || this.component()?.component === A2UI_COMPONENT_THINKING_CARD) {
        ThinkingStreamView({
          surface: this.surface,
          component: this.component() as A2uiComponent,
          renderTick: this.renderTick,
          isBusy: this.isBusy
        })
      } else {
        Column() {
          Text('暂不支持的组件')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_ERROR)
          Text((this.component() as A2uiComponent).component)
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(14)
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(12)
        .margin({ bottom: 10 })
      }
    }
  }
}
