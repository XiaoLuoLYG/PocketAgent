import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import {
  socialHubConnections,
  socialHubDraft,
  socialHubItems,
  socialHubSelected
} from '../../../model/A2uiData';
import {
  SocialHubConnectionData,
  SocialHubItemData,
  SocialHubPlatform
} from '../../../model/SocialHubTypes';
import {
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_SOCIAL,
  COLOR_SOCIAL_CARD,
  COLOR_SOCIAL_GLOW,
  COLOR_SOCIAL_LINE,
  COLOR_SOCIAL_SOFT,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import {
  A2UI_PANEL_CORNER_RADIUS
} from '../style/A2uiPanelFrameStyle';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';
import { A2uiButtonView } from './common/A2uiButtonView';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import {
  socialHubAuthorText,
  socialHubBadgeStatus,
  socialHubConnectionMessage,
  socialHubConnectionStatusLabel,
  socialHubDraftDisplayText,
  socialHubItemMetaText,
  socialHubPlatformLabel,
  socialHubPrimaryText
} from './SocialHubViewData';

const SOCIAL_HUB_ROW_HEIGHT: number = 74;
const SOCIAL_HUB_CONNECTION_HEIGHT: number = 62;
const SOCIAL_HUB_ACTION_WIDTH: number = 68;

@Component
export struct SocialHubView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = {
    id: 'socialHub',
    component: 'SocialHub',
    dataPath: '/socialHub/items'
  };
  @Prop isBusy: boolean = false;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private items(): SocialHubItemData[] {
    return socialHubItems(this.surface);
  }

  private selected(): SocialHubItemData {
    return socialHubSelected(this.surface);
  }

  private isSelected(item: SocialHubItemData): boolean {
    return item.id.length > 0 && item.id === this.selected().id;
  }

  private connection(platform: SocialHubPlatform): SocialHubConnectionData {
    const connections = socialHubConnections(this.surface);
    for (let index = 0; index < connections.length; index++) {
      if (connections[index].platform === platform) {
        return connections[index];
      }
    }
    return {
      platform: platform,
      status: 'disabled',
      displayName: '',
      accountId: '',
      message: '未配置'
    };
  }

  private selectAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_select_item',
      label: '选择',
      prompt: item.id,
      variant: this.isSelected(item) ? 'activated' : 'secondary',
      kind: 'client'
    };
  }

  private draftAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_draft_reply',
      label: '生成草稿',
      prompt: item.id,
      variant: 'primary',
      kind: 'client'
    };
  }

  private openSourceAction(item: SocialHubItemData): A2uiAction {
    return {
      id: 'social_hub_open_source',
      label: '打开来源',
      prompt: item.url,
      variant: 'secondary',
      kind: 'client'
    };
  }

  private detailActions(): A2uiAction[] {
    const item = this.selected();
    const actions: A2uiAction[] = [this.draftAction(item)];
    if (item.url.length > 0) {
      actions.push(this.openSourceAction(item));
    }
    return actions;
  }

  @Builder
  private ConnectionCell(platform: SocialHubPlatform) {
    Column() {
      Row() {
        Text(socialHubPlatformLabel(platform))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .layoutWeight(1)
        StatusBadgeView({
          status: socialHubBadgeStatus(this.connection(platform).status),
          label: socialHubConnectionStatusLabel(this.connection(platform).status)
        })
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)

      Text(socialHubConnectionMessage(this.connection(platform)))
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 4 })
    }
    .height(SOCIAL_HUB_CONNECTION_HEIGHT)
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor(COLOR_SOCIAL_SOFT)
    .borderRadius(10)
    .border({ width: 1, color: COLOR_SOCIAL_LINE })
  }

  @Builder
  private MessageRow(item: SocialHubItemData) {
    Row() {
      Column() {
        Row() {
          Text(socialHubAuthorText(item))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (item.unread) {
            Text('未读')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_SOCIAL)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(COLOR_SOCIAL_SOFT)
              .borderRadius(7)
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(22)
        .alignItems(VerticalAlign.Center)

        Text(socialHubPrimaryText(item))
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })

        Text(socialHubItemMetaText(item))
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .padding({ right: 10 })

      A2uiButtonView({
        label: this.isSelected(item) ? '已选' : '选择',
        shape: 'pill',
        tone: this.isSelected(item) ? 'activated' : 'secondary',
        active: this.isSelected(item),
        isEnabled: !this.isBusy
      })
        .width(SOCIAL_HUB_ACTION_WIDTH)
        .onClick(() => {
          if (this.isBusy) {
            return;
          }
          this.onAction(this.selectAction(item));
        })
    }
    .width('100%')
    .height(SOCIAL_HUB_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 10 })
    .backgroundColor(this.isSelected(item) ? COLOR_SOCIAL_CARD : '#00000000')
    .border({ width: { bottom: 1 }, color: COLOR_LINE })
  }

  @Builder
  private MessageList() {
    Column() {
      Row() {
        Text('消息')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text(this.items().length.toString())
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .height(30)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })

      if (this.items().length === 0) {
        Column() {
          Text('还没有真实消息')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_INK)
          Text('真实数据接入前，这里只显示连接状态。')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 6 })
        }
        .width('100%')
        .height(168)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .border({ width: { top: 1 }, color: COLOR_LINE })
      } else {
        ForEach(this.items(), (item: SocialHubItemData) => {
          this.MessageRow(item)
        }, (item: SocialHubItemData) => item.id)
      }
    }
    .width('100%')
    .clip(true)
  }

  @Builder
  private DetailPanel() {
    Column() {
      Row() {
        Text('详情 / 草稿')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        StatusBadgeView({
          status: socialHubDraft(this.surface).status === 'error' ? 'error' : 'idle',
          label: socialHubDraft(this.surface).status === 'draft' ? '本地草稿' : '未发送'
        })
      }
      .width('100%')
      .height(30)
      .alignItems(VerticalAlign.Center)

      if (this.selected().id.length === 0) {
        Text('选择一条真实消息后，可以在这里生成本地草稿预览。')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(19)
          .height(54)
          .margin({ top: 10 })
      } else {
        Text(socialHubAuthorText(this.selected()))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 10 })

        Text(socialHubPrimaryText(this.selected()))
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }

      ActionBarView({
        actions: this.detailActions(),
        isBusy: this.isBusy,
        onAction: this.onAction
      })

      Text(socialHubDraftDisplayText(socialHubDraft(this.surface)))
        .fontSize(13)
        .fontColor(socialHubDraft(this.surface).status === 'error' ? '#B04A42' : COLOR_TEXT)
        .lineHeight(20)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(COLOR_SOCIAL_SOFT)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_SOCIAL_LINE })
        .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .border({ width: { top: 1 }, color: COLOR_LINE })
  }

  build() {
    Column() {
      A2uiPanelAccentView({
        accentColor: COLOR_SOCIAL,
        accentShadowColor: COLOR_SOCIAL_GLOW,
        showAccent: true
      })

      Column() {
        Row() {
          Text('SocialHub')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .layoutWeight(1)
          Text('社交工作台')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .height(34)
        .alignItems(VerticalAlign.Center)

        Row() {
          this.ConnectionCell('x')
          Blank()
            .width(8)
          this.ConnectionCell('slack')
          Blank()
            .width(8)
          this.ConnectionCell('wecom')
        }
        .width('100%')
        .height(SOCIAL_HUB_CONNECTION_HEIGHT)
        .margin({ top: 8 })

        Column() {
          this.MessageList()
        }
        .width('100%')
        .margin({ top: 12 })

        Column() {
          this.DetailPanel()
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(COLOR_CARD)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 24, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 8 })
    .clip(true)
  }
}
