import {
  A2uiAction,
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../../model/A2uiTypes';
import { actionsOf, genericToolResults } from '../../../model/A2uiData';
import { gmailOpenDraftAction, gmailReplyDraftAction } from '../../../model/GmailToolA2ui';
import { mailReplyDraftAction } from '../../../model/MailToolA2ui';
import { mediaVideoPlaybackAction } from '../../../model/MediaVideoToolA2ui';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_INSET,
  COLOR_CARD_RAISED,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct GenericToolResultsView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'GenericToolResults' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State selectedGmailKey: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private results(): A2uiGenericToolResultData[] {
    return genericToolResults(this.surface);
  }

  private titleOf(item: A2uiGenericToolResultData): string {
    if (item.title.length > 0) {
      return item.title;
    }
    return item.toolName.length > 0 ? item.toolName : '动态工具结果';
  }

  private componentTitle(): string {
    return this.component.title === undefined || this.component.title.length === 0 ? '动态工具结果' : this.component.title;
  }

  private isWeatherResult(item: A2uiGenericToolResultData): boolean {
    return item.toolName === 'maps_weather' || item.title.indexOf('天气') >= 0;
  }

  private isGmailResult(item: A2uiGenericToolResultData): boolean {
    return item.sourceTag === 'Gmail API' ||
      item.sourceTag === 'Gmail' ||
      item.sourceTag === 'QQ Mail' ||
      item.toolName === 'mail.thread' ||
      item.toolName.indexOf('users.threads') === 0 ||
      item.toolName.indexOf('users.drafts') === 0;
  }

  private isGmailWebResult(item: A2uiGenericToolResultData): boolean {
    return item.toolName === 'gmail.open.web';
  }

  private isGmailWebResults(): boolean {
    const rows = this.results();
    for (let index = 0; index < rows.length; index++) {
      if (this.isGmailWebResult(rows[index])) {
        return true;
      }
    }
    return false;
  }

  private isGmailResults(): boolean {
    const rows = this.results();
    for (let index = 0; index < rows.length; index++) {
      if (this.isGmailResult(rows[index])) {
        return true;
      }
    }
    return false;
  }

  private isGmailDraft(item: A2uiGenericToolResultData): boolean {
    if (item.status === 'error') {
      return false;
    }
    return item.toolName.indexOf('users.drafts') === 0 || item.title.indexOf('草稿') >= 0;
  }

  private rowValue(item: A2uiGenericToolResultData, label: string): string {
    for (let index = 0; index < item.rows.length; index++) {
      if (item.rows[index].label === label) {
        return item.rows[index].value;
      }
    }
    return '';
  }

  private cleanSender(value: string): string {
    const angle = value.indexOf('<');
    const raw = angle > 0 ? value.substring(0, angle) : value;
    const cleaned = raw.split('"').join('').trim();
    if (cleaned.length > 0) {
      return cleaned;
    }
    const at = value.indexOf('@');
    if (at > 0) {
      return value.substring(0, at).split('<').join('').trim();
    }
    return value.trim();
  }

  private gmailPrimary(item: A2uiGenericToolResultData): string {
    if (this.isGmailDraft(item)) {
      const to = this.rowValue(item, 'To');
      return to.length > 0 ? to : 'Draft';
    }
    const from = this.cleanSender(this.rowValue(item, 'From'));
    return from.length > 0 ? from : 'Unknown sender';
  }

  private gmailAvatar(item: A2uiGenericToolResultData): string {
    const primary = this.gmailPrimary(item).trim();
    if (primary.length === 0) {
      return 'G';
    }
    return primary.substring(0, 1).toUpperCase();
  }

  private gmailRowKey(item: A2uiGenericToolResultData, index: number): string {
    const id = this.rowValue(item, 'Thread ID').length > 0 ? this.rowValue(item, 'Thread ID') : this.rowValue(item, 'Draft ID');
    return id.length > 0 ? id : item.toolName + '|' + item.title + '|' + index.toString();
  }

  private gmailSelected(item: A2uiGenericToolResultData, index: number): boolean {
    return this.selectedGmailKey === this.gmailRowKey(item, index);
  }

  private gmailSubject(item: A2uiGenericToolResultData): string {
    if (this.isGmailDraft(item)) {
      const subject = this.rowValue(item, 'Subject');
      return subject.length > 0 ? subject : item.title;
    }
    return this.titleOf(item);
  }

  private gmailDate(item: A2uiGenericToolResultData): string {
    const date = this.firstRowValue(item, ['Date', 'Received']);
    if (date.length === 0) {
      return this.isGmailDraft(item) ? 'Draft' : '';
    }
    const parts = date.split(' ');
    if (parts.length >= 3 && parts[0].indexOf(',') >= 0) {
      return parts[1] + ' ' + parts[2];
    }
    return date.length > 18 ? date.substring(0, 18) : date;
  }

  private gmailLabelText(value: string): string {
    const label = value.trim();
    if (label === 'IMPORTANT') {
      return 'Important';
    }
    if (label === 'INBOX') {
      return 'Inbox';
    }
    if (label === 'UNREAD') {
      return 'Unread';
    }
    if (label === 'CATEGORY_PROMOTIONS') {
      return 'Promotions';
    }
    if (label === 'CATEGORY_PERSONAL') {
      return 'Personal';
    }
    if (label === 'SENT') {
      return 'Sent';
    }
    return '';
  }

  private gmailLabels(item: A2uiGenericToolResultData): string[] {
    const labels: string[] = [];
    if (this.isGmailDraft(item)) {
      labels.push('Draft');
      return labels;
    }
    if (item.sourceTag === 'QQ Mail') {
      labels.push('QQ Mail');
    } else if (item.sourceTag === 'Gmail') {
      labels.push('Gmail');
    }
    if (this.rowValue(item, 'Important') === 'Yes') {
      labels.push('Important');
    }
    if (this.rowValue(item, 'Unread') === 'Yes') {
      labels.push('Unread');
    }
    const raw = this.rowValue(item, 'Labels');
    if (raw.length === 0) {
      return labels;
    }
    const pieces = raw.split(',');
    for (let index = 0; index < pieces.length && labels.length < 3; index++) {
      const label = this.gmailLabelText(pieces[index]);
      if (label.length > 0) {
        labels.push(label);
      }
    }
    return labels;
  }

  private gmailDetailRows(item: A2uiGenericToolResultData): A2uiGenericToolResultRowData[] {
    const rows: A2uiGenericToolResultRowData[] = [];
    item.rows.forEach((row: A2uiGenericToolResultRowData) => {
      if (row.label === 'Labels' || row.label === 'Messages') {
        return;
      }
      rows.push(row);
    });
    return rows;
  }

  private gmailActions(item: A2uiGenericToolResultData): A2uiAction[] {
    const actions: A2uiAction[] = [];
    const mailAction = mailReplyDraftAction(item);
    if (mailAction !== null) {
      actions.push(mailAction);
    }
    const replyAction = gmailReplyDraftAction(item);
    if (replyAction !== null) {
      actions.push(replyAction);
    }
    const openDraftAction = gmailOpenDraftAction(item);
    if (openDraftAction !== null) {
      actions.push(openDraftAction);
    }
    return actions;
  }

  private mediaVideoActions(item: A2uiGenericToolResultData): A2uiAction[] {
    const action = mediaVideoPlaybackAction(item);
    return action === null ? [] : [action];
  }

  private gmailHeaderTitle(): string {
    const rows = this.results();
    for (let index = 0; index < rows.length; index++) {
      if (this.isGmailDraft(rows[index])) {
        return 'Draft saved';
      }
      if (rows[index].toolName === 'mail.thread') {
        return 'Mailbox';
      }
    }
    return 'Inbox';
  }

  private gmailHeaderMeta(): string {
    const count = this.results().length;
    if (this.gmailHeaderTitle() === 'Draft saved') {
      return 'Saved as draft. Not sent.';
    }
    return count.toString() + (count === 1 ? ' message' : ' messages');
  }

  private gmailWebResult(): A2uiGenericToolResultData {
    const rows = this.results();
    for (let index = 0; index < rows.length; index++) {
      if (this.isGmailWebResult(rows[index])) {
        return rows[index];
      }
    }
    return {
      sourceTag: 'System intent',
      toolName: 'gmail.open.web',
      title: 'Gmail Web',
      status: 'needs_user',
      summary: '',
      rows: [],
      rawPreview: ''
    };
  }

  private gmailWebUrl(): string {
    const value = this.firstRowValue(this.gmailWebResult(), ['URL', 'Link', 'Destination']);
    return value.length > 0 ? value : 'https://mail.google.com/mail/u/0/#inbox';
  }

  private gmailWebHost(): string {
    let host = this.gmailWebUrl();
    const httpsPrefix = 'https://';
    const httpPrefix = 'http://';
    if (host.indexOf(httpsPrefix) === 0) {
      host = host.substring(httpsPrefix.length);
    } else if (host.indexOf(httpPrefix) === 0) {
      host = host.substring(httpPrefix.length);
    }
    const slash = host.indexOf('/');
    return slash > 0 ? host.substring(0, slash) : host;
  }

  private firstRowValue(item: A2uiGenericToolResultData, labels: string[]): string {
    for (let index = 0; index < labels.length; index++) {
      const value = this.rowValue(item, labels[index]);
      if (value.length > 0) {
        return value;
      }
    }
    return '';
  }

  private weatherTemp(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['白天温度', '温度']);
  }

  private weatherCondition(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['白天天气', '天气']);
  }

  private weatherDate(item: A2uiGenericToolResultData): string {
    return this.firstRowValue(item, ['预报日期', '发布时间']);
  }

  build() {
    Column() {
      A2uiPanelAccentView()
      Column() {
        Text(this.componentTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)

        if (this.results().length === 0) {
          Text('工具没有返回可展示结果。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .margin({ top: 12 })
        } else if (this.isGmailWebResults()) {
          Column() {
            Row() {
              Text('G')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAF8')
                .width(38)
                .height(38)
                .textAlign(TextAlign.Center)
                .backgroundColor('#C94E43')
                .borderRadius(10)
                .margin({ right: 12 })

              Column() {
                Text('Gmail')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                Text(this.gmailWebHost())
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('网页版')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_ACCENT_DARK)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(COLOR_ACCENT_SOFT)
                .borderRadius(7)
                .border({ width: 1, color: COLOR_ACCENT })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text('已打开 Gmail 网页版')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .width('100%')
              .margin({ top: 16 })

            Text('使用当前浏览器会话继续处理邮件。')
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .lineHeight(20)
              .width('100%')
              .margin({ top: 6 })

            Column() {
              Row() {
                Text('目标地址')
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .layoutWeight(1)
                Text(this.gmailWebHost())
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_TEXT)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text(this.gmailWebUrl())
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .lineHeight(18)
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 11, bottom: 11 })
            .margin({ top: 14 })
            .backgroundColor(COLOR_FIELD)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_LINE })
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 14, bottom: 14 })
          .margin({ top: 14 })
          .backgroundColor(COLOR_CARD_INSET)
          .borderRadius(14)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .transition(a2uiEnterTransition())
        } else if (this.isGmailResults()) {
          Row() {
            Column() {
              Text(this.gmailHeaderTitle())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
              Text(this.gmailHeaderMeta())
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('G')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F6FAF8')
              .width(28)
              .height(28)
              .textAlign(TextAlign.Center)
              .backgroundColor('#C94E43')
              .borderRadius(7)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 14 })

          Column() {
            ForEach(this.results(), (item: A2uiGenericToolResultData, index: number) => {
              Row() {
                Text(this.gmailAvatar(item))
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isGmailDraft(item) ? COLOR_ACCENT_SOFT : COLOR_CARD)
                  .borderRadius(9)
                  .border({ width: 1, color: this.isGmailDraft(item) ? COLOR_ACCENT : COLOR_CARD_EDGE })
                  .margin({ right: 12 })

                Column() {
                  Row() {
                    Text(this.gmailPrimary(item))
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(COLOR_INK)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)

                    Text(this.gmailDate(item))
                      .fontSize(11)
                      .fontColor(COLOR_MUTED)
                      .margin({ left: 10 })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)

                  Text(this.gmailSubject(item))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(COLOR_TEXT)
                    .width('100%')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })

                  Text(item.summary)
                    .fontSize(12)
                    .fontColor(COLOR_MUTED)
                    .lineHeight(18)
                    .width('100%')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })

                  if (this.gmailLabels(item).length > 0) {
                    Row() {
                      ForEach(this.gmailLabels(item), (label: string) => {
                        Text(label)
                          .fontSize(10)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(label === 'Important' ? '#F3C26B' : COLOR_MUTED)
                          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                          .backgroundColor(label === 'Important' ? '#332813' : COLOR_FIELD)
                          .borderRadius(6)
                          .border({ width: 1, color: label === 'Important' ? '#7C6128' : COLOR_LINE })
                          .margin({ right: 6 })
                      }, (label: string, labelIndex: number) => label + labelIndex.toString())
                    }
                    .width('100%')
                    .margin({ top: 9 })
                  }

                  if (this.gmailSelected(item, index)) {
                    Column() {
                      Row() {
                        Text('Selected')
                          .fontSize(10)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(COLOR_ACCENT_DARK)
                          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                          .backgroundColor(COLOR_ACCENT_SOFT)
                          .borderRadius(6)
                          .border({ width: 1, color: COLOR_ACCENT })
                      }
                      .width('100%')

                      ForEach(this.gmailDetailRows(item), (row: A2uiGenericToolResultRowData) => {
                        Row() {
                          Text(row.label)
                            .fontSize(11)
                            .fontColor(COLOR_MUTED)
                            .width(74)
                          Text(row.value)
                            .fontSize(12)
                            .fontColor(COLOR_TEXT)
                            .lineHeight(18)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        }
                        .width('100%')
                        .alignItems(VerticalAlign.Top)
                        .margin({ top: 8 })
                      }, (row: A2uiGenericToolResultRowData, rowIndex: number) => row.label + row.value + rowIndex.toString())

                      ActionBarView({
                        actions: this.gmailActions(item),
                        isBusy: this.isBusy,
                        onAction: this.onAction
                      })
                    }
                    .width('100%')
                    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                    .margin({ top: 10 })
                    .backgroundColor(COLOR_FIELD)
                    .borderRadius(10)
                    .border({ width: 1, color: COLOR_LINE })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding({ left: 12, right: 12, top: 13, bottom: 13 })
              .backgroundColor(this.gmailSelected(item, index) ? COLOR_CARD_RAISED : (index === 0 ? COLOR_CARD : COLOR_CARD_INSET))
              .borderRadius(this.gmailSelected(item, index) || index === 0 ? 12 : 0)
              .border({
                width: this.gmailSelected(item, index) ? 1 : { bottom: index === this.results().length - 1 ? 0 : 1 },
                color: this.gmailSelected(item, index) ? COLOR_ACCENT : COLOR_LINE
              })
              .transition(a2uiEnterTransition())
              .onClick(() => {
                const key = this.gmailRowKey(item, index);
                this.selectedGmailKey = this.selectedGmailKey === key ? '' : key;
              })
            }, (item: A2uiGenericToolResultData, index: number) => item.toolName + item.title + index.toString() + '-' + this.renderTick.toString())
          }
          .width('100%')
          .margin({ top: 12 })
          .clip(true)
          .backgroundColor(COLOR_CARD_INSET)
          .borderRadius(14)
          .border({ width: 1, color: COLOR_CARD_EDGE })
        } else {
          ForEach(this.results(), (item: A2uiGenericToolResultData, index: number) => {
            Column() {
              if (this.isWeatherResult(item)) {
                Row() {
                  Column() {
                    Text(this.titleOf(item))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(COLOR_INK)
                    Text(this.weatherDate(item).length > 0 ? this.weatherDate(item) : item.sourceTag)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)
                  StatusBadgeView({ status: item.status, label: item.sourceTag })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row() {
                  Column() {
                    Text(this.weatherTemp(item).length > 0 ? this.weatherTemp(item) : '--')
                      .fontSize(34)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(COLOR_INK)
                      .fontFamily('HarmonyOS Sans')
                    Text(this.weatherCondition(item).length > 0 ? this.weatherCondition(item) : '天气')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(COLOR_ACCENT)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)

                  Column() {
                    Text(this.firstRowValue(item, ['夜间天气', '湿度']).length > 0 ? this.firstRowValue(item, ['夜间天气', '湿度']) : '实时来源')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(COLOR_TEXT)
                    Text(this.firstRowValue(item, ['夜间温度', '风力', '白天风力']).length > 0 ? this.firstRowValue(item, ['夜间温度', '风力', '白天风力']) : item.sourceTag)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .margin({ top: 5 })
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: 14, right: 14, top: 14, bottom: 14 })
                .margin({ top: 12 })
                .backgroundColor(COLOR_ACCENT_SOFT)
                .borderRadius(14)
                .border({ width: 1, color: COLOR_ACCENT })

                Text(item.summary)
                  .fontSize(13)
                  .fontColor(COLOR_TEXT)
                  .lineHeight(20)
                  .margin({ top: 12 })

                Column() {
                  ForEach(item.rows, (row: A2uiGenericToolResultRowData) => {
                    Row() {
                      Text(row.label)
                        .fontSize(12)
                        .fontColor(COLOR_MUTED)
                        .width(96)
                      Text(row.value)
                        .fontSize(13)
                        .fontColor(COLOR_TEXT)
                        .lineHeight(19)
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                    .padding({ top: 7, bottom: 7 })
                    .border({ width: { bottom: 1 }, color: COLOR_LINE })
                  }, (row: A2uiGenericToolResultRowData, rowIndex: number) => row.label + row.value + rowIndex.toString())
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ top: 12 })
                .backgroundColor(COLOR_CARD)
                .borderRadius(12)
                .border({ width: 1, color: COLOR_CARD_EDGE })
              } else {
                Row() {
                  Text(this.titleOf(item))
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(COLOR_TEXT)
                    .layoutWeight(1)
                  StatusBadgeView({ status: item.status, label: item.sourceTag })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Text(item.summary)
                  .fontSize(13)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(20)
                  .margin({ top: 8 })

                ForEach(item.rows, (row: A2uiGenericToolResultRowData) => {
                  Row() {
                    Text(row.label)
                      .fontSize(12)
                      .fontColor(COLOR_MUTED)
                      .width(88)
                    Text(row.value)
                      .fontSize(13)
                      .fontColor(COLOR_TEXT)
                      .lineHeight(19)
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .padding({ top: 8 })
                }, (row: A2uiGenericToolResultRowData, rowIndex: number) => row.label + row.value + rowIndex.toString())
              }

              if (item.status !== 'success' && item.rawPreview.length > 0) {
                Text(item.rawPreview)
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(16)
                  .maxLines(5)
                  .margin({ top: 10 })
              }

              if (this.mediaVideoActions(item).length > 0) {
                ActionBarView({
                  actions: this.mediaVideoActions(item),
                  isBusy: this.isBusy,
                  onAction: this.onAction
                })
                  .margin({ top: 12 })
              }
            }
            .width('100%')
            .padding({ left: this.isWeatherResult(item) ? 12 : 0, right: this.isWeatherResult(item) ? 12 : 0, top: 12, bottom: 12 })
            .backgroundColor(this.isWeatherResult(item) ? COLOR_CARD_RAISED : A2UI_PANEL_BACKGROUND_COLOR)
            .borderRadius(this.isWeatherResult(item) ? 16 : 0)
            .border({ width: { bottom: index === this.results().length - 1 ? 0 : 1 }, color: COLOR_CARD_EDGE })
            .transition(a2uiEnterTransition())
          }, (item: A2uiGenericToolResultData, index: number) => item.toolName + item.title + index.toString() + '-' + this.renderTick.toString())
        }

        ActionBarView({
          actions: actionsOf(this.component),
          isBusy: this.isBusy,
          onAction: this.onAction
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
    .transition(a2uiEnterTransition())
  }
}
