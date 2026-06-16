import { A2uiButtonVisualStyle, resolveA2uiButtonStyle } from '../../style/A2uiButtonStyle';

@Component
export struct A2uiButtonView {
  @Prop label: string = '';
  @Prop icon: Resource = $r('app.media.startIcon');
  @Prop hasIcon: boolean = false;
  @Prop shape: string = 'pill';
  @Prop tone: string = 'secondary';
  @Prop active: boolean = false;
  @Prop isEnabled: boolean = true;
  @Prop fill: boolean = false;

  private visualStyle(): A2uiButtonVisualStyle {
    return resolveA2uiButtonStyle(this.tone, this.active, this.isEnabled);
  }

  @Builder
  private Content(style: A2uiButtonVisualStyle) {
    if (this.hasIcon) {
      Image(this.icon)
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
    } else {
      Text(this.label)
        .fontSize(this.shape === 'circle' ? 12 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor(style.textColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  build() {
    if (this.shape === 'circle') {
      Stack() {
        this.Content(this.visualStyle())
      }
      .width(40)
      .height(40)
      .backgroundColor(this.visualStyle().backgroundColor)
      .borderRadius(20)
      .border({ width: 1, color: this.visualStyle().borderColor })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    } else if (this.fill) {
      Stack() {
        this.Content(this.visualStyle())
      }
      .width('100%')
      .height(40)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.visualStyle().backgroundColor)
      .borderRadius(12)
      .border({ width: 1, color: this.visualStyle().borderColor })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    } else {
      Stack() {
        this.Content(this.visualStyle())
      }
      .height(38)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.visualStyle().backgroundColor)
      .borderRadius(11)
      .border({ width: 1, color: this.visualStyle().borderColor })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    }
  }
}
