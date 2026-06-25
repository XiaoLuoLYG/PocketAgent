import {
  A2uiAction,
  A2uiFlightData,
  A2uiFoodData,
  A2uiSurfaceState,
  A2uiTrainData,
  A2uiTravelOptionData,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { rootComponentIdOf } from '../render/A2uiRenderData';
import { A2uiNodeView } from './A2uiNodeView';
import { QueryPendingSurfaceView } from './QueryPendingSurfaceView';

@Component
export struct A2uiSurfaceView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @Prop showPendingSurface: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onPinNavigationCard: (item: A2uiFoodData) => void = (_item: A2uiFoodData) => {};
  onPinTravelNavigationCard: (item: A2uiTravelOptionData) => void = (_item: A2uiTravelOptionData) => {};
  onPinTrainNavigationCard: (item: A2uiTrainData) => void = (_item: A2uiTrainData) => {};
  onPinFlightNavigationCard: (item: A2uiFlightData) => void = (_item: A2uiFlightData) => {};

  private hasRenderableSurface(): boolean {
    return this.surface.components.length > 0;
  }

  build() {
    Scroll() {
      if (this.showPendingSurface) {
        QueryPendingSurfaceView()
      } else if (this.hasRenderableSurface()) {
        A2uiNodeView({
          surface: this.surface,
          componentId: rootComponentIdOf(this.surface),
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
      }
    }
    .width('100%')
    .scrollBar(BarState.Off)
  }
}
