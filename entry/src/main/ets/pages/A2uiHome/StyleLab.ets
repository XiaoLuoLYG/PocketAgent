import { A2uiAction, A2uiSurfaceState } from '../../model/A2uiTypes';
import router from '@ohos.router';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_TEXT
} from './style/A2uiHomeTheme';
import {
  A2UI_STYLE_LAB_CASES,
  A2uiStyleLabCase,
  cloneA2uiStyleLabSurface,
  defaultA2uiStyleLabCase,
  findA2uiStyleLabCase
} from './mocks/A2uiStyleLabMocks';
import { A2uiSurfaceView } from './components/A2uiSurfaceView';
import { StatusBadgeView } from './components/StatusBadgeView';

const initialLabCase: A2uiStyleLabCase = defaultA2uiStyleLabCase();
const initialLabSurface: A2uiSurfaceState = cloneA2uiStyleLabSurface(initialLabCase.surface);

@Entry
@Component
struct StyleLab {
  @State selectedCaseId: string = initialLabCase.id;
  @State currentSurface: A2uiSurfaceState = initialLabSurface;
  @State renderTick: number = 1;
  @State lastActionLabel: string = '尚未触发操作';

  private selectedCase(): A2uiStyleLabCase {
    return findA2uiStyleLabCase(this.selectedCaseId);
  }

  private isSelected(id: string): boolean {
    return this.selectedCaseId === id;
  }

  private selectCase(item: A2uiStyleLabCase): void {
    this.selectedCaseId = item.id;
    this.currentSurface = cloneA2uiStyleLabSurface(item.surface);
    this.renderTick = this.renderTick + 1;
    this.lastActionLabel = '已切换到 ' + item.title;
  }

  private handleAction(action: A2uiAction): void {
    this.lastActionLabel = '点击了 ' + action.label + ' (' + action.id + ')';
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('A2UI Style Lab')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('隐藏调试页，只切换 mock surface，不调用模型。')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('返回')
          .height(36)
          .width(66)
          .fontSize(12)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .margin({ right: 8 })
          .onClick(() => {
            router.back();
          })

        StatusBadgeView({
          status: this.currentSurface.status,
          label: this.currentSurface.status
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .backgroundColor(COLOR_PANEL)
      .borderRadius(20)
      .border({ width: 1, color: COLOR_CARD_EDGE })

      Column() {
        Text(this.selectedCase().title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text(this.selectedCase().description + ' · ' + this.lastActionLabel)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .lineHeight(18)
          .margin({ top: 5 })

        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
          ForEach(A2UI_STYLE_LAB_CASES, (item: A2uiStyleLabCase) => {
            Button(item.title)
              .height(36)
              .fontSize(12)
              .fontColor(this.isSelected(item.id) ? COLOR_BUTTON_TEXT : COLOR_INK)
              .backgroundColor(this.isSelected(item.id) ? COLOR_ACCENT_DEEP : COLOR_CARD_RAISED)
              .borderRadius(10)
              .border({ width: 1, color: this.isSelected(item.id) ? COLOR_ACCENT : COLOR_CARD_EDGE })
              .padding({ left: 12, right: 12 })
              .margin({ right: 8, top: 10 })
              .onClick(() => {
                this.selectCase(item);
              })
          }, (item: A2uiStyleLabCase) => item.id)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor(COLOR_PANEL)
      .borderRadius(18)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .margin({ top: 12 })

      A2uiSurfaceView({
        surface: this.currentSurface,
        renderTick: this.renderTick,
        isBusy: this.currentSurface.status === 'thinking',
        onAction: (action: A2uiAction) => {
          this.handleAction(action);
        }
      })
      .layoutWeight(1)
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(COLOR_PAGE)
  }
}
