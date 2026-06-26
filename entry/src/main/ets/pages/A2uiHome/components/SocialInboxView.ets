import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { socialDiagnostics, socialMessages, socialReplies, A2uiLabelValue, A2uiSocialMessage, A2uiSocialReply } from '../../../model/A2uiData';
import {
  COLOR_ACCENT_DARK,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_INSET,
  COLOR_ERROR,
  COLOR_ERROR_LINE,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_SOCIAL,
  COLOR_SOCIAL_CARD,
  COLOR_SOCIAL_GLOW,
  COLOR_SOCIAL_LINE,
  COLOR_SOCIAL_SOFT,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct SocialInboxView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'SocialInbox' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private messages(): A2uiSocialMessage[] {
    return socialMessages(this.surface, this.component);
  }

  private diagnostics(): A2uiLabelValue[] {
    return socialDiagnostics(this.surface);
  }

  private replyFor(messageId: string): A2uiSocialReply | null {
    const replies = socialReplies(this.surface);
    for (let index = replies.length - 1; index >= 0; index--) {
      if (replies[index].targetMessageId === messageId) {
        return replies[index];
      }
    }
    return null;
  }

  private socialSourceLabel(source: string): string {
    if (source === 'notification') {
      return '通知中心';
    }
    if (source === 'accessibility') {
      return '辅助捕获';
    }
    if (source === 'official') {
      return '官方渠道';
    }
    return source.length > 0 ? source : '未知来源';
  }

  private socialStatusLabel(status: string): string {
    if (status === 'sent' || status === 'replied') {
      return '已回复';
    }
    if (status === 'failed') {
      return '失败';
    }
    if (status === 'sending' || status === 'queued') {
      return '发送中';
    }
    if (status === 'selected') {
      return '正在回复';
    }
    return '未读';
  }

  private socialStatusColor(status: string): string {
    if (status === 'failed') {
      return COLOR_ERROR;
    }
    if (status === 'sent' || status === 'replied') {
      return COLOR_ACCENT_DARK;
    }
    return COLOR_SOCIAL;
  }

  private socialReplyText(messageId: string): string {
    const reply = this.replyFor(messageId);
    if (reply === null) {
      return '';
    }
    return reply.text;
  }

  private socialReplyError(messageId: string): string {
    const reply = this.replyFor(messageId);
    if (reply === null) {
      return '';
    }
    return reply.error;
  }

  private selectAction(item: A2uiSocialMessage): A2uiAction {
    return {
      id: 'social_select_message',
      label: '选择消息',
      prompt: item.id,
      kind: 'client',
      variant: 'secondary'
    };
  }

  private settingsAction(): A2uiAction {
    return {
      id: 'social_open_notification_settings',
      label: '打开通知授权',
      prompt: 'social_open_notification_settings',
      kind: 'client',
      variant: 'secondary'
    };
  }

  @Builder
  private SocialDiagnostics() {
    Column() {
      Text('社交权限诊断')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      ForEach(this.diagnostics(), (row: A2uiLabelValue) => {
        Row() {
          Text(row.label)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .width(104)
          Text(row.value)
            .fontSize(13)
            .fontColor(row.value.indexOf('不可用') >= 0 || row.value.indexOf('未检测到') >= 0 || row.value.indexOf('失败') >= 0 ? COLOR_ERROR : COLOR_TEXT)
            .lineHeight(20)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ top: 7, bottom: 7 })
      }, (row: A2uiLabelValue) => row.label + row.value + '-' + this.renderTick.toString())
      Button('尝试通知授权')
        .enabled(!this.isBusy)
        .fontSize(13)
        .fontColor(COLOR_BUTTON_TEXT)
        .height(38)
        .width('100%')
        .backgroundColor(COLOR_SOCIAL)
        .borderRadius(10)
        .margin({ top: 10 })
        .onClick(() => {
          this.onAction(this.settingsAction());
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(14)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 14 })
  }

  build() {
    Column() {
      A2uiPanelAccentView({ showAccent: false })

      Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '微信消息'))
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
        Text('微信')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_SOCIAL)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(COLOR_SOCIAL_SOFT)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_SOCIAL_LINE })
        Text('新消息收件箱')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.messages().length === 0) {
        Column() {
          Text('还没有真实捕获到微信新消息')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('等待系统通知读取能力开放后，真实微信新消息会出现在这里。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(COLOR_CARD_INSET)
        .borderRadius(14)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ top: 12 })
      }

      ForEach(this.messages(), (item: A2uiSocialMessage) => {
        Column() {
          Row() {
            Text(this.socialSourceLabel(item.source))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_SOCIAL)
              .padding({ left: 9, right: 9, top: 5, bottom: 5 })
              .backgroundColor(COLOR_SOCIAL_SOFT)
              .borderRadius(8)
              .border({ width: 1, color: COLOR_SOCIAL_LINE })
            Blank()
              .layoutWeight(1)
            Text(this.socialStatusLabel(item.status))
              .fontSize(12)
              .fontColor(this.socialStatusColor(item.status))
          }
          .width('100%')

          Text(item.conversationTitle.length > 0 ? item.conversationTitle : '微信会话')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .margin({ top: 12 })
          Text(item.senderName.length > 0 ? item.senderName : item.conversationTitle)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
          Text(item.preview)
            .fontSize(15)
            .fontColor(COLOR_TEXT)
            .lineHeight(22)
            .margin({ top: 10 })
          Text(item.receivedAt)
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ top: 8 })
          if (this.socialReplyText(item.id).length > 0) {
            Column() {
              Text('Appless Phone 回复')
                .fontSize(11)
                .fontColor(COLOR_MUTED)
              Text(this.socialReplyText(item.id))
                .fontSize(13)
                .fontColor(COLOR_TEXT)
                .lineHeight(20)
                .margin({ top: 5 })
              if (this.socialReplyError(item.id).length > 0) {
                Text(this.socialReplyError(item.id))
                  .fontSize(12)
                  .fontColor(COLOR_ERROR)
                  .lineHeight(18)
                  .margin({ top: 6 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(COLOR_CARD_INSET)
            .borderRadius(12)
            .border({ width: 1, color: this.socialReplyError(item.id).length > 0 ? COLOR_ERROR_LINE : COLOR_CARD_EDGE })
            .margin({ top: 12 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(item.status === 'selected' ? COLOR_SOCIAL_SOFT : COLOR_SOCIAL_CARD)
        .borderRadius(16)
        .border({ width: 1, color: item.status === 'selected' ? COLOR_SOCIAL : COLOR_SOCIAL_LINE })
        .shadow({ radius: 20, color: COLOR_SOCIAL_GLOW, offsetX: 0, offsetY: 9 })
        .margin({ top: 10 })
        .onClick(() => {
          this.onAction(this.selectAction(item));
        })
      }, (item: A2uiSocialMessage) => item.id + '-' + this.renderTick.toString())

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }
}
