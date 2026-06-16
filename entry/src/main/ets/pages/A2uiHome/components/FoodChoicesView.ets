import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, foodOptions, A2uiFoodOption } from '../../../model/A2uiData';
import { aiLogError, aiLogInfo } from '../../../model/AiphoneLogger';
import { foodDistanceMeters } from '../../../model/ToolGatewayClient';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_INSET,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_FOOD_AMAP,
  COLOR_FOOD_AMAP_CARD,
  COLOR_FOOD_AMAP_GLOW,
  COLOR_FOOD_AMAP_LINE,
  COLOR_FOOD_AMAP_SOFT,
  COLOR_FOOD_BAIDU,
  COLOR_FOOD_BAIDU_CARD,
  COLOR_FOOD_BAIDU_GLOW,
  COLOR_FOOD_BAIDU_LINE,
  COLOR_FOOD_BAIDU_SOFT,
  COLOR_FOOD_MEITUAN,
  COLOR_FOOD_MEITUAN_CARD,
  COLOR_FOOD_MEITUAN_GLOW,
  COLOR_FOOD_MEITUAN_LINE,
  COLOR_FOOD_MEITUAN_SOFT,
  COLOR_FOOD_TAOBAO,
  COLOR_FOOD_TAOBAO_CARD,
  COLOR_FOOD_TAOBAO_GLOW,
  COLOR_FOOD_TAOBAO_LINE,
  COLOR_FOOD_TAOBAO_SOFT,
  COLOR_FOOD_TENCENT,
  COLOR_FOOD_TENCENT_CARD,
  COLOR_FOOD_TENCENT_GLOW,
  COLOR_FOOD_TENCENT_LINE,
  COLOR_FOOD_TENCENT_SOFT,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';

const SYSTEM_MAP_BUNDLE: string = 'com.huawei.hmos.maps.app';
const SYSTEM_MAP_ABILITY: string = 'EntryAbility';

interface FoodNavigationTarget {
  name: string;
  want: Want;
}

type FoodFilterMode = 'all' | 'within_1km';

@Component
export struct FoodChoicesView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'FoodChoices' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State filterMode: FoodFilterMode = 'all';
  @State expandedFoodKey: string = '';
  @State foodNavigationStatus: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private foods(): A2uiFoodOption[] {
    return foodOptions(this.surface, this.component);
  }

  private visibleFoods(): A2uiFoodOption[] {
    let rows = this.foods();
    if (this.filterMode === 'within_1km') {
      rows = rows.filter((item: A2uiFoodOption) => foodDistanceMeters(item.distance) <= 1000);
    }
    return rows;
  }

  private foodRowKey(item: A2uiFoodOption): string {
    const location = item.location === undefined || item.location === null ? '' : item.location;
    return item.name + '|' + item.address + '|' + item.distance + '|' + location;
  }

  private sourceTags(item: A2uiFoodOption): string[] {
    if (item.sourceTags === undefined || item.sourceTags === null || !Array.isArray(item.sourceTags)) {
      return [];
    }
    const tags: string[] = [];
    item.sourceTags.forEach((tag: string) => {
      if (tag.length > 0 && tags.indexOf(tag) < 0) {
        tags.push(tag);
      }
    });
    return tags;
  }

  private primarySource(item: A2uiFoodOption): string {
    const tags = this.sourceTags(item);
    if (tags.length === 1) {
      return tags[0];
    }
    return '';
  }

  private sourceAccent(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO;
    }
    return COLOR_ACCENT_DARK;
  }

  private sourceSoft(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_SOFT;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_SOFT;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_SOFT;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_SOFT;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_SOFT;
    }
    return COLOR_ACCENT_SOFT;
  }

  private sourceLine(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_LINE;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_LINE;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_LINE;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_LINE;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_LINE;
    }
    return COLOR_CARD_EDGE;
  }

  private sourceCard(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_CARD;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_CARD;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_CARD;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_CARD;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_CARD;
    }
    return COLOR_CARD;
  }

  private sourceGlow(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_GLOW;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_GLOW;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_GLOW;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_GLOW;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_GLOW;
    }
    return COLOR_CARD_GLOW;
  }

  private cardBackground(item: A2uiFoodOption): string {
    return this.sourceCard(this.primarySource(item));
  }

  private cardBorder(item: A2uiFoodOption): string {
    return this.sourceLine(this.primarySource(item));
  }

  private cardGlow(item: A2uiFoodOption): string {
    return this.sourceGlow(this.primarySource(item));
  }

  private cardAccent(item: A2uiFoodOption): string {
    return this.sourceAccent(this.primarySource(item));
  }

  private locationText(item: A2uiFoodOption): string {
    if (item.location === undefined || item.location === null) {
      return '';
    }
    return item.location.trim();
  }

  private locationParts(item: A2uiFoodOption): string[] {
    const location = this.locationText(item);
    if (location.length === 0) {
      return [];
    }
    const parts = location.split(',');
    if (parts.length < 2) {
      return [];
    }
    const longitude = parts[0].trim();
    const latitude = parts[1].trim();
    if (longitude.length === 0 || latitude.length === 0) {
      return [];
    }
    return [latitude, longitude];
  }

  private canNavigate(item: A2uiFoodOption): boolean {
    return this.locationParts(item).length === 2;
  }

  private navigationUnavailableText(item: A2uiFoodOption): string {
    if (!this.canNavigate(item)) {
      return '缺少真实坐标，不能导航';
    }
    return '';
  }

  private systemNavigationUri(item: A2uiFoodOption): string {
    const parts = this.locationParts(item);
    if (parts.length !== 2) {
      return '';
    }
    return 'maps://navigation?saddr=&daddr=' + parts[0] + ',' + parts[1] + '&type=walk';
  }

  private navigationWant(uri: string): Want {
    return {
      bundleName: SYSTEM_MAP_BUNDLE,
      abilityName: SYSTEM_MAP_ABILITY,
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    };
  }

  private navigationTargets(item: A2uiFoodOption): FoodNavigationTarget[] {
    const targets: FoodNavigationTarget[] = [];
    const systemUri = this.systemNavigationUri(item);
    if (systemUri.length > 0) {
      targets.push({ name: '系统地图', want: this.navigationWant(systemUri) });
    }
    return targets;
  }

  private async openFoodNavigation(item: A2uiFoodOption): Promise<void> {
    const targets = this.navigationTargets(item);
    if (targets.length === 0) {
      this.foodNavigationStatus = this.navigationUnavailableText(item);
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let lastError = '';
    for (let index = 0; index < targets.length; index++) {
      const target = targets[index];
      try {
        await context.startAbility(target.want);
        this.foodNavigationStatus = '已请求' + target.name + '从当前位置导航';
        const uri: string = target.want.uri === undefined ? '' : target.want.uri;
        aiLogInfo('[AIPhone][FoodNavigation] provider=' + target.name + ' uriChars=' + uri.length.toString() + ' name=' + item.name);
        return;
      } catch (error) {
        const businessError = error as BusinessError;
        lastError = target.name + '：' + businessError.message;
        const code = businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString();
        aiLogError('[AIPhone][FoodNavigation] failed provider=' + target.name + ' code=' + code + ' message=' + businessError.message);
      }
    }
    this.foodNavigationStatus = '导航打开失败：' + lastError;
  }

  private isLocalFoodAction(action: A2uiAction): boolean {
    return action.id === 'food_show_all' || action.id === 'food_filter_1km';
  }

  private actionForFilter(action: A2uiAction): A2uiAction {
    const active = (action.id === 'food_show_all' && this.filterMode === 'all') ||
      (action.id === 'food_filter_1km' && this.filterMode === 'within_1km');
    if (!active) {
      return action;
    }
    return {
      id: action.id,
      label: action.label,
      prompt: action.prompt,
      kind: action.kind,
      variant: 'activated'
    };
  }

  private visibleActions(): A2uiAction[] {
    const next: A2uiAction[] = [];
    actionsOf(this.component).forEach((action: A2uiAction) => {
      next.push(this.actionForFilter(action));
    });
    return next;
  }

  private handleAction(action: A2uiAction): void {
    if (!this.isLocalFoodAction(action)) {
      this.onAction(action);
      return;
    }
    this.filterMode = action.id === 'food_filter_1km' ? 'within_1km' : 'all';
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width(58)
      Text(value)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private FoodDetailPanel(item: A2uiFoodOption) {
    Column() {
      this.DetailRow('来源', this.sourceTags(item).length > 0 ? this.sourceTags(item).join(' / ') : '未知')
      if (item.category.length > 0) {
        this.DetailRow('分类', item.category)
      }
      if (item.distance.length > 0) {
        this.DetailRow('距离', item.distance)
      }
      this.DetailRow('地址', item.address.length > 0 ? item.address : '暂无地址')
      this.DetailRow('坐标', this.locationText(item).length > 0 ? this.locationText(item) : 'provider 未返回')
      if (this.navigationUnavailableText(item).length > 0) {
        Text(this.navigationUnavailableText(item))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 8 })
      }
      if (this.foodNavigationStatus.length > 0) {
        Text(this.foodNavigationStatus)
          .fontSize(12)
          .fontColor(this.foodNavigationStatus.indexOf('失败') >= 0 || this.foodNavigationStatus.indexOf('缺少') >= 0 ? COLOR_ERROR : COLOR_ACCENT_DARK)
          .lineHeight(18)
          .margin({ top: 8 })
      }
      Button(this.canNavigate(item) ? '系统地图导航' : '导航不可用')
        .enabled(this.canNavigate(item) && !this.isBusy)
        .height(38)
        .width('100%')
        .fontSize(13)
        .fontColor(this.canNavigate(item) ? COLOR_BUTTON_TEXT : COLOR_MUTED)
        .backgroundColor(this.canNavigate(item) ? COLOR_ACCENT_DEEP : COLOR_CARD_RAISED)
        .borderRadius(10)
        .border({ width: 1, color: this.canNavigate(item) ? COLOR_ACCENT : COLOR_CARD_EDGE })
        .margin({ top: 10 })
        .onClick(() => {
          this.openFoodNavigation(item);
        })
      Text('只拉起路线规划，不下单不支付')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD_INSET)
    .borderRadius(10)
    .border({ width: { left: 3 }, color: this.cardBorder(item) })
    .margin({ top: 10 })
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

      ActionBarView({
        actions: this.visibleActions(),
        isBusy: this.isBusy,
        onAction: (action: A2uiAction) => {
          this.handleAction(action);
        }
      })

      if (this.visibleFoods().length === 0 && this.foods().length > 0 && this.filterMode === 'within_1km') {
        Column() {
          Text('1 公里内暂无可展示店铺')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('当前结果里没有距离字段小于等于 1000 米的真实店铺。')
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
        .margin({ top: 10 })
      } else if (this.visibleFoods().length === 0) {
        Text('暂无可展示餐饮')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.visibleFoods(), (item: A2uiFoodOption) => {
          Column() {
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
                    .fontColor(this.cardAccent(item))
                    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                    .backgroundColor(this.sourceSoft(this.primarySource(item)))
                    .borderRadius(8)
                    .border({ width: 1, color: this.cardBorder(item) })
                }
              }
              .width('100%')

              if (this.sourceTags(item).length > 0) {
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.sourceTags(item), (tag: string) => {
                    Text(tag)
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.sourceAccent(tag))
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.sourceSoft(tag))
                      .borderRadius(7)
                      .border({ width: 1, color: this.sourceLine(tag) })
                      .margin({ right: 6, top: 7 })
                  }, (tag: string) => item.name + '-' + tag)
                }
                .width('100%')
              }

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

              Row() {
                Text(this.expandedFoodKey === this.foodRowKey(item) ? '收起' : '详情')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.cardAccent(item))
                Blank()
                  .layoutWeight(1)
                if (this.canNavigate(item)) {
                  Text('可导航')
                    .fontSize(12)
                    .fontColor(COLOR_ACCENT_DARK)
                }
              }
              .width('100%')
              .margin({ top: 10 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor(this.cardBackground(item))
            .borderRadius(16)
            .border({ width: 1, color: this.cardBorder(item) })
            .shadow({ radius: 20, color: this.cardGlow(item), offsetX: 0, offsetY: 9 })
            .onClick(() => {
              const rowKey = this.foodRowKey(item);
              this.expandedFoodKey = this.expandedFoodKey === rowKey ? '' : rowKey;
            })

            if (this.expandedFoodKey === this.foodRowKey(item)) {
              this.FoodDetailPanel(item)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 10 })
        }, (item: A2uiFoodOption) => this.foodRowKey(item) + '-' + this.renderTick.toString())
      }
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
