import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_ERROR_LINE,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_PANEL_SHADOW,
  COLOR_TEXT,
  statusBackground,
  statusColor
} from '../style/A2uiHomeTheme';
import { connectionStatusLabel } from '../state/A2uiHomeState';
import { DebugTextPanel } from './DebugTextPanel';

@Component
export struct ConfigPage {
  @Link baseUrl: string;
  @Link apiKey: string;
  @Link selectedModel: string;
  @Link customParametersJson: string;
  @Link showAdvancedSettings: boolean;
  @Prop connectionStatus: string = 'idle';
  @Prop connectionMessage: string = '';
  @Prop isBusy: boolean = false;
  @Prop lastModelRequest: string = '';
  @Prop lastModelOutput: string = '';
  @Prop lastError: string = '';
  @Prop refreshTick: number = 0;
  onBack: () => void = () => {};
  onTestConnection: () => void = () => {};

  @Builder
  InputLabel(label: string, top: number) {
    Text(label)
      .fontSize(12)
      .fontColor(COLOR_MUTED)
      .margin({ top: top, bottom: 6 })
  }

  @Builder
  StatusBadge() {
    Text(connectionStatusLabel(this.connectionStatus))
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(statusColor(this.connectionStatus))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(statusBackground(this.connectionStatus))
      .borderRadius(9)
      .border({ width: 1, color: statusColor(this.connectionStatus) })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('返回')
            .height(40)
            .width(76)
            .fontSize(13)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .onClick(() => {
              this.onBack();
            })

          Column() {
            Text('配置')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('测试模型连接，并观察本页状态是否实时刷新')
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)

          this.StatusBadge()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 16 })

        Column() {
          Text('模型连接')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('这里是最小刷新实验：点击测试连接后，状态、错误、请求和响应面板应立即更新，不需要切页。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(19)
            .margin({ top: 8, bottom: 14 })

          if (this.lastError.length > 0) {
            Column() {
              Text('最近异常')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_ERROR)
              Text(this.lastError)
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .lineHeight(18)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(12)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(COLOR_ERROR_SOFT)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_ERROR_LINE })
            .margin({ bottom: 14 })
          }

          Row() {
            Button('云端 Qwen')
              .height(36)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(COLOR_BUTTON_TEXT)
              .backgroundColor(COLOR_ACCENT_DEEP)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_ACCENT })
              .margin({ right: 8 })
              .onClick(() => {
                this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
                this.selectedModel = 'qwen3-8b';
                this.customParametersJson = '{"enable_thinking":false}';
              })
            Button('本地 Qwen')
              .height(36)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(COLOR_INK)
              .backgroundColor(COLOR_CARD_RAISED)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .onClick(() => {
                this.baseUrl = 'http://127.0.0.1:11434';
                this.selectedModel = 'Qwen3-8B';
                this.customParametersJson = '';
              })
          }
          .width('100%')
          .margin({ bottom: 14 })

          this.InputLabel('Model', 0)
          TextInput({ text: this.selectedModel, placeholder: 'Qwen3-8B' })
            .height(42)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 10, right: 10 })
            .onChange((value: string) => {
              this.selectedModel = value;
            })

          this.InputLabel('Base URL', 12)
          TextInput({ text: this.baseUrl, placeholder: 'http://127.0.0.1:11434' })
            .height(42)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 10, right: 10 })
            .onChange((value: string) => {
              this.baseUrl = value;
            })

          Row() {
            Text('高级设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_INK)
              .layoutWeight(1)
            Text(this.showAdvancedSettings ? '收起' : '展开')
              .fontSize(12)
              .fontColor(COLOR_ACCENT)
          }
          .width('100%')
          .padding({ top: 14, bottom: 10 })
          .onClick(() => {
            this.showAdvancedSettings = !this.showAdvancedSettings;
          })

          if (this.showAdvancedSettings) {
            this.InputLabel('API Key（可选）', 0)
            TextInput({ text: this.apiKey, placeholder: '如果接口要求鉴权，在这里填写' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .onChange((value: string) => {
                this.apiKey = value;
              })

            this.InputLabel('自定义请求参数 JSON（可选）', 12)
            TextInput({ text: this.customParametersJson, placeholder: '{"enable_thinking":false}' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .onChange((value: string) => {
                this.customParametersJson = value;
              })
          }

          Button(this.isBusy ? '检查中' : '测试连接')
            .enabled(!this.isBusy)
            .height(44)
            .width('100%')
            .fontSize(15)
            .fontColor(COLOR_BUTTON_TEXT)
            .backgroundColor(COLOR_ACCENT_DEEP)
            .borderRadius(11)
            .border({ width: 1, color: COLOR_ACCENT })
            .margin({ top: 16 })
            .onClick(() => {
              this.onTestConnection();
            })

          Divider()
            .color(COLOR_LINE)
            .margin({ top: 16, bottom: 14 })

          Row() {
            Text('面板刷新计数')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
            Text(this.refreshTick.toString())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_ACCENT)
              .margin({ left: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.connectionMessage)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .margin({ top: 10 })

          DebugTextPanel({
            label: '模型请求',
            value: this.lastModelRequest,
            refreshTick: this.refreshTick
          })
          DebugTextPanel({
            label: '模型输出',
            value: this.lastModelOutput,
            refreshTick: this.refreshTick
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(16)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .shadow({ radius: 22, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 10 })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
