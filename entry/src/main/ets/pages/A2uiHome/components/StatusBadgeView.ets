import {
  COLOR_MUTED,
  statusBackground,
  statusColor
} from '../style/A2uiHomeTheme';
import { connectionStatusLabel } from '../state/A2uiHomeState';

@Component
export struct StatusBadgeView {
  @Prop status: string = 'idle';
  @Prop label: string = '';

  private displayLabel(): string {
    if (this.label.length > 0) {
      return this.label;
    }
    return connectionStatusLabel(this.status);
  }

  build() {
    Text(this.displayLabel())
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.status.length > 0 ? statusColor(this.status) : COLOR_MUTED)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(statusBackground(this.status))
      .borderRadius(9)
      .border({ width: 1, color: statusColor(this.status) })
  }
}
