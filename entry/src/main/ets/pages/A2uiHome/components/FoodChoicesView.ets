import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, foodOptions, A2uiFoodOption } from '../../../model/A2uiData';
import {
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../A2uiRenderData';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

@Component
export struct FoodChoicesView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'FoodChoices' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private foods(): A2uiFoodOption[] {
    return foodOptions(this.surface, this.component);
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '附近餐饮'))
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

      if (this.foods().length === 0) {
        Text('暂无可展示餐饮')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.foods(), (item: A2uiFoodOption) => {
          Column() {
            Row() {
              Text(item.name.length > 0 ? item.name : '未命名餐厅')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
                .layoutWeight(1)
              if (item.distance.length > 0) {
                Text(item.distance)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DARK)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(8)
              }
            }
            .width('100%')

            if (item.category.length > 0) {
              Text(item.category)
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .lineHeight(18)
                .margin({ top: 6 })
            }

            Text(item.address.length > 0 ? item.address : '暂无地址')
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(19)
              .margin({ top: 7 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(16)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
          .margin({ top: 10 })
        }, (item: A2uiFoodOption) => item.name + '|' + item.address + '|' + item.distance + '-' + this.renderTick.toString())
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
