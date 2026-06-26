import { resolveNavigationCardMapUri } from '../../model/NavigationCardSnapshot';

let storage = LocalStorage.getShared();

const CARD_BG: string = '#11151C';
const CARD_BG_RAISED: string = '#171D26';
const CARD_EDGE: string = '#344052';
const CARD_EDGE_SOFT: string = '#253041';
const CARD_TEXT: string = '#F8FAFC';
const CARD_MUTED: string = '#B8C2D2';
const CARD_SUBTLE: string = '#7E8CA0';
const CARD_ACCENT: string = '#F2B84B';
const CARD_ACCENT_DARK: string = '#8B5E18';
const CARD_ERROR: string = '#FCA5A5';
const CARD_EXPIRED: string = '#FDBA74';
const CARD_SHADOW: string = '#6606111F';
const TRAVEL_BG: string = '#07131F';
const TRAVEL_PANEL: string = '#0E2133';
const TRAVEL_EDGE: string = '#2A5A75';
const TRAVEL_TRAIN: string = '#62D59B';
const TRAVEL_FLIGHT: string = '#76C7FF';
const TRAVEL_MUTED: string = '#A7B9C9';
const TRAVEL_BUTTON_TEXT: string = '#06111D';

@Entry(storage)
@Component
struct NavigationCard {
  @LocalStorageProp('cardStatus') cardStatus: string = 'empty';
  @LocalStorageProp('status') fallbackStatus: string = 'empty';
  @LocalStorageProp('cardStyle') cardStyle: string = 'destination';
  @LocalStorageProp('transport') transport: string = '';
  @LocalStorageProp('title') title: string = 'Appless Phone 导航';
  @LocalStorageProp('subtitle') subtitle: string = '';
  @LocalStorageProp('address') address: string = '';
  @LocalStorageProp('location') location: string = '';
  @LocalStorageProp('targetName') targetName: string = '';
  @LocalStorageProp('departureTime') departureTime: string = '';
  @LocalStorageProp('arrivalTime') arrivalTime: string = '';
  @LocalStorageProp('routeText') routeText: string = '';
  @LocalStorageProp('serviceText') serviceText: string = '';
  @LocalStorageProp('sourceText') sourceText: string = '';
  @LocalStorageProp('mapUri') mapUri: string = '';
  @LocalStorageProp('destinationUri') destinationUri: string = '';
  @LocalStorageProp('message') message: string = '从 Appless Phone 对话生成导航卡片';
  @LocalStorageProp('updatedText') updatedText: string = '';
  @LocalStorageProp('primaryAction') primaryAction: string = 'open_agent';
  @LocalStorageProp('secondaryAction') secondaryAction: string = 'refresh';

  private hasPinnedDestination(): boolean {
    return this.title.length > 0 && this.title !== 'Appless Phone 导航';
  }

  private resolvedMapUri(): string {
    const storedUri = this.destinationUri.length > 0 ? this.destinationUri : this.mapUri;
    return resolveNavigationCardMapUri(this.cardStyle, this.transport, this.location, this.targetName, storedUri);
  }

  private effectiveStatus(): string {
    if (this.cardStatus === 'error' || this.fallbackStatus === 'error') {
      return 'error';
    }
    if (this.cardStatus === 'expired' || this.fallbackStatus === 'expired') {
      return 'expired';
    }
    if (this.cardStatus.length > 0 && this.cardStatus !== 'empty') {
      return this.cardStatus;
    }
    if (this.fallbackStatus.length > 0 && this.fallbackStatus !== 'empty') {
      return this.fallbackStatus;
    }
    if (this.hasPinnedDestination()) {
      return 'ready';
    }
    return 'empty';
  }

  private isReady(): boolean {
    return this.effectiveStatus() === 'ready';
  }

  private isTravelStyle(): boolean {
    return this.cardStyle === 'travel';
  }

  private openAgent(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        message: 'navigation_card'
      }
    });
  }

  private openMap(): void {
    const uri = this.resolvedMapUri();
    if (!this.isReady() || uri.length === 0) {
      this.openAgent();
      return;
    }
    postCardAction(this, {
      action: 'router',
      uri: uri,
      params: {
        message: 'open_map'
      }
    });
  }

  private refresh(): void {
    postCardAction(this, {
      action: 'message',
      params: {
        message: 'refresh'
      }
    });
  }

  private titleText(): string {
    return this.title.length > 0 ? this.title : 'Appless Phone 导航';
  }

  private destinationTitleSize(): number {
    const count = this.titleText().length;
    if (count >= 26) {
      return 19;
    }
    if (count >= 20) {
      return 21;
    }
    if (count >= 15) {
      return 23;
    }
    return 25;
  }

  private destinationTitleLineHeight(): number {
    const size = this.destinationTitleSize();
    if (size <= 19) {
      return 23;
    }
    if (size <= 21) {
      return 25;
    }
    return 29;
  }

  private travelAccentColor(): string {
    return this.transport === 'flight' ? TRAVEL_FLIGHT : TRAVEL_TRAIN;
  }

  private travelKindText(): string {
    return this.transport === 'flight' ? '航班' : '高铁';
  }

  private travelTargetText(): string {
    if (this.targetName.length > 0) {
      return this.targetName;
    }
    if (this.address.length > 0) {
      return this.address;
    }
    return this.transport === 'flight' ? '出发机场' : '出发车站';
  }

  private travelRouteText(): string {
    if (this.routeText.length > 0) {
      return this.routeText;
    }
    if (this.subtitle.length > 0) {
      return this.subtitle;
    }
    return '出发信息';
  }

  private travelTimeText(): string {
    return this.departureTime.length > 0 ? this.departureTime : '--:--';
  }

  private subtitleText(): string {
    if (this.isReady()) {
      return this.subtitle.length > 0 ? this.subtitle : this.message;
    }
    return this.message;
  }

  private primaryLabel(): string {
    if (!this.isReady()) {
      return '回到对话';
    }
    return this.isTravelStyle() ? '去出发地' : '打开地图';
  }

  private secondaryLabel(): string {
    return this.isReady() ? '回到对话' : '刷新';
  }

  private statusAccentColor(): string {
    const status = this.effectiveStatus();
    if (status === 'error') {
      return CARD_ERROR;
    }
    if (status === 'expired') {
      return CARD_EXPIRED;
    }
    if (status === 'ready') {
      return CARD_ACCENT;
    }
    return CARD_MUTED;
  }

  private statusLabel(): string {
    const status = this.effectiveStatus();
    if (status === 'ready') {
      return this.isTravelStyle() ? '出发' : '导航';
    }
    if (status === 'expired') {
      return '已过期';
    }
    if (status === 'error') {
      return '失败';
    }
    return '待固定';
  }

  private metadataText(): string {
    const source = this.sourceText.length > 0 ? this.sourceText : '真实结果';
    if (this.updatedText.length > 0) {
      return source + ' / ' + this.updatedText;
    }
    return source;
  }

  @Builder
  private StatusMark() {
    Text(this.statusLabel())
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.statusAccentColor())
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(CARD_BG_RAISED)
      .border({ width: 1, color: CARD_EDGE_SOFT })
      .borderRadius(9)
      .maxLines(1)
  }

  @Builder
  private PrimaryAction() {
    Text(this.primaryLabel())
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor('#15110A')
      .textAlign(TextAlign.Center)
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(CARD_ACCENT)
      .borderRadius(9)
      .layoutWeight(1)
      .maxLines(1)
      .shadow({ radius: 14, color: '#553E2408', offsetX: 0, offsetY: 5 })
      .onClick(() => {
        if (this.isReady()) {
          this.openMap();
        } else {
          this.openAgent();
        }
      })
  }

  @Builder
  private SecondaryAction() {
    Text(this.secondaryLabel())
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(CARD_TEXT)
      .textAlign(TextAlign.Center)
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(CARD_BG_RAISED)
      .border({ width: 1, color: CARD_EDGE_SOFT })
      .borderRadius(9)
      .maxLines(1)
      .margin({ left: 8 })
      .onClick(() => {
        if (this.isReady()) {
          this.openAgent();
        } else {
          this.refresh();
        }
      })
  }

  @Builder
  private FailureCopy() {
    if (!this.isReady()) {
      Text(this.subtitleText())
        .fontSize(17)
        .fontColor(this.statusAccentColor())
        .lineHeight(22)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
    }
  }

  @Builder
  private Metadata() {
    if (this.sourceText.length > 0 || this.updatedText.length > 0 || this.isReady()) {
      Text(this.metadataText())
        .fontSize(16)
        .fontWeight(FontWeight.Regular)
        .fontColor(CARD_MUTED)
        .lineHeight(20)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 5 })
    }
  }

  @Builder
  private AddressLine() {
    if (!this.isReady() && this.address.length > 0) {
      Text(this.address)
        .fontSize(15)
        .fontColor(CARD_SUBTLE)
        .lineHeight(20)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 5 })
    }
  }

  @Builder
  private CardChrome() {
    Column() {
      Row()
        .height(1)
        .width('100%')
        .backgroundColor('#526174')
        .opacity(0.48)
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CARD_BG)
  }

  @Builder
  private AccentRail() {
    Row() {
      Row()
        .width(28)
        .height(3)
        .backgroundColor(this.statusAccentColor())
        .borderRadius(2)
      Row()
        .width(8)
        .height(3)
        .backgroundColor(CARD_ACCENT_DARK)
        .borderRadius(2)
        .margin({ left: 5 })
    }
    .margin({ top: 8 })
  }

  @Builder
  private DestinationCard() {
    Stack() {
      this.CardChrome()

      Column() {
        Row() {
          Text('Appless Phone')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(CARD_MUTED)
            .layoutWeight(1)
            .maxLines(1)
          this.StatusMark()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.AccentRail()

        Text(this.titleText())
          .fontSize(this.destinationTitleSize())
          .fontWeight(FontWeight.Bold)
          .fontColor(CARD_TEXT)
          .lineHeight(this.destinationTitleLineHeight())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        this.FailureCopy()
        this.Metadata()
        this.AddressLine()

        Blank()
          .layoutWeight(1)

        Row() {
          this.PrimaryAction()
          this.SecondaryAction()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 9 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CARD_BG)
    .borderRadius(18)
    .border({ width: 1, color: CARD_EDGE })
    .shadow({ radius: 22, color: CARD_SHADOW, offsetX: 0, offsetY: 10 })
  }

  @Builder
  private TravelCard() {
    Stack() {
      Column() {
        Row()
          .height(1)
          .width('100%')
          .backgroundColor(this.travelAccentColor())
          .opacity(0.72)
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TRAVEL_BG)

      Column() {
        Row() {
          Text(this.travelKindText())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.travelAccentColor())
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(TRAVEL_PANEL)
            .border({ width: 1, color: TRAVEL_EDGE })
            .borderRadius(9)
            .maxLines(1)
          Blank()
            .layoutWeight(1)
          if (!this.isReady()) {
            this.StatusMark()
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.travelRouteText())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(CARD_TEXT)
          .lineHeight(22)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 9 })

        if (this.isReady()) {
          Row() {
            Text(this.travelTimeText())
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor(CARD_TEXT)
              .lineHeight(38)
              .maxLines(1)
              .layoutWeight(1)
            if (this.arrivalTime.length > 0) {
              Text('到 ' + this.arrivalTime)
                .fontSize(13)
                .fontColor(TRAVEL_MUTED)
                .maxLines(1)
                .margin({ top: 13 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: 2 })

          Text(this.travelTargetText())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TRAVEL_MUTED)
            .lineHeight(20)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        } else {
          Text(this.subtitleText())
            .fontSize(17)
            .fontColor(this.statusAccentColor())
            .lineHeight(22)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 10 })
        }

        Blank()
          .layoutWeight(1)

        Row() {
          Text(this.primaryLabel())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TRAVEL_BUTTON_TEXT)
            .textAlign(TextAlign.Center)
            .padding({ left: 11, right: 11, top: 6, bottom: 6 })
            .backgroundColor(this.travelAccentColor())
            .borderRadius(9)
            .layoutWeight(1)
            .maxLines(1)
            .onClick(() => {
              if (this.isReady()) {
                this.openMap();
              } else {
                this.openAgent();
              }
            })
          this.SecondaryAction()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TRAVEL_BG)
    .borderRadius(18)
    .border({ width: 1, color: TRAVEL_EDGE })
    .shadow({ radius: 22, color: '#66060F18', offsetX: 0, offsetY: 10 })
  }

  build() {
    if (this.isTravelStyle()) {
      this.TravelCard()
    } else {
      this.DestinationCard()
    }
  }
}
