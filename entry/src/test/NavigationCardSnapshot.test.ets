import { describe, it, expect } from '@ohos/hypium';
import { A2uiFlightData, A2uiFoodData, A2uiTrainData, A2uiTravelOptionData } from '../main/ets/model/A2uiTypes';
import {
  CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
  NAVIGATION_CARD_PIN_ACTION_ID,
  MemoryNavigationCardSnapshotStore,
  NavigationCardSnapshot,
  NavigationCardSnapshotBuildResult,
  buildEmptyNavigationCardBindingData,
  buildNavigationCardBindingData,
  canCreateNavigationCardFromFlightOption,
  canCreateNavigationCardFromFoodOption,
  canCreateNavigationCardFromTrainOption,
  canCreateNavigationCardFromTravelOption,
  navigationCardPinActionFromFoodOption,
  navigationCardFormEventFromMessage,
  navigationCardSnapshotFromFlightOption,
  navigationCardSnapshotExpired,
  navigationCardSnapshotFromFoodOption,
  navigationCardSnapshotFromTrainOption,
  navigationCardSnapshotFromTravelOption,
  resolveNavigationCardMapUri,
  sanitizeNavigationCardSourceTags
} from '../main/ets/model/NavigationCardSnapshot';

function foodOptionWithLocation(): A2uiFoodData {
  return {
    name: '喜茶(深圳坂田华创里店)',
    category: '饮品店',
    address: '深圳市龙岗区坂田街道华创里',
    distance: '860米',
    location: '116.397470,39.908823',
    sourceTags: ['高德', '高德', '', '腾讯地图']
  };
}

function trainOption(): A2uiTrainData {
  return {
    trainCode: 'G79',
    from: '北京南',
    to: '上海虹桥',
    depart: '10:00',
    arrive: '14:18',
    duration: '4小时18分',
    seats: '二等座有票',
    status: '可查',
    business: '',
    first: '有',
    second: '有',
    noSeat: '',
    hardSeat: '',
    sleeperSoft: ''
  };
}

function flightOptionWithAirport(): A2uiFlightData {
  return {
    flightNo: 'CA1831',
    airline: '中国国航',
    dep: '北京首都机场',
    arr: '上海虹桥机场',
    depTime: '2026-06-25 08:30:00',
    arrTime: '2026-06-25 10:45:00',
    status: '计划',
    price: '720'
  };
}

function travelTrainOption(): A2uiTravelOptionData {
  return {
    id: 'train-G79',
    source: 'train',
    sourceTag: '高铁 · 12306',
    title: 'G79',
    from: '北京南',
    to: '上海虹桥',
    depart: '10:00',
    arrive: '14:18',
    duration: '4小时18分',
    price: '',
    availability: '二等座有票',
    status: '可查',
    detail: ''
  };
}

function readySnapshot(): NavigationCardSnapshot {
  const result = navigationCardSnapshotFromFoodOption(foodOptionWithLocation(), {
    surfaceId: 'surface_food',
    toolId: 'food.search',
    updatedAt: 1770000000000,
    expiresAt: 1770003600000
  });
  if (result.snapshot === undefined) {
    return {
      kind: CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION,
      status: 'error',
      cardStyle: 'destination',
      transport: '',
      title: '',
      subtitle: '',
      address: '',
      location: '',
      targetName: '',
      departureTime: '',
      arrivalTime: '',
      routeText: '',
      serviceText: '',
      sourceTags: [],
      mapUri: '',
      surfaceId: '',
      toolId: '',
      updatedAt: 0,
      expiresAt: 0,
      error: 'fixture failed'
    };
  }
  return result.snapshot;
}

export default function navigationCardSnapshotTest() {
  describe('navigationCardSnapshot', () => {
    it('creates a navigation destination snapshot from a real coordinate-backed food row', 0, () => {
      const result: NavigationCardSnapshotBuildResult = navigationCardSnapshotFromFoodOption(foodOptionWithLocation(), {
        surfaceId: 'surface_food',
        toolId: 'food.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertTrue();
      expect(result.error).assertEqual('');
      expect(result.snapshot === undefined).assertFalse();
      if (result.snapshot !== undefined) {
        expect(result.snapshot.kind).assertEqual(CARD_SNAPSHOT_KIND_NAVIGATION_DESTINATION);
        expect(result.snapshot.status).assertEqual('ready');
        expect(result.snapshot.cardStyle).assertEqual('destination');
        expect(result.snapshot.title).assertEqual('喜茶(深圳坂田华创里店)');
        expect(result.snapshot.address).assertEqual('深圳市龙岗区坂田街道华创里');
        expect(result.snapshot.location).assertEqual('116.397470,39.908823');
        expect(result.snapshot.targetName).assertEqual('喜茶(深圳坂田华创里店)');
        expect(result.snapshot.sourceTags.join('/')).assertEqual('高德/腾讯地图');
        expect(result.snapshot.mapUri).assertEqual('petalmaps://poidetail?center=39.908823,116.397470&z=16&marker=39.908823,116.397470&name=%E5%96%9C%E8%8C%B6%28%E6%B7%B1%E5%9C%B3%E5%9D%82%E7%94%B0%E5%8D%8E%E5%88%9B%E9%87%8C%E5%BA%97%29&utm_source=com.example.aiphonedemo');
      }
    });

    it('rejects food rows without real coordinates', 0, () => {
      const item = foodOptionWithLocation();
      item.location = '';
      const result = navigationCardSnapshotFromFoodOption(item, {
        surfaceId: 'surface_food',
        toolId: 'food.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('缺少真实坐标，不能生成导航卡片');
      expect(result.snapshot === undefined).assertTrue();
    });

    it('deduplicates and limits source tags without inventing providers', 0, () => {
      expect(sanitizeNavigationCardSourceTags(['高德', '高德', '', '腾讯地图', '百度地图', '美团', '淘宝闪购']).join('/'))
        .assertEqual('高德/腾讯地图/百度地图/美团');
    });

    it('exposes a stable local pin action only for coordinate-backed food rows', 0, () => {
      const item = foodOptionWithLocation();
      expect(canCreateNavigationCardFromFoodOption(item)).assertTrue();
      expect(navigationCardPinActionFromFoodOption(item).id).assertEqual(NAVIGATION_CARD_PIN_ACTION_ID);
      expect(navigationCardPinActionFromFoodOption(item).kind).assertEqual('client');
      expect(navigationCardPinActionFromFoodOption(item).label).assertEqual('固定为导航卡片');

      item.location = '';
      expect(canCreateNavigationCardFromFoodOption(item)).assertFalse();
      expect(navigationCardPinActionFromFoodOption(item).id).assertEqual('');
    });

    it('maps ready, expired, error, and empty states to stable binding data', 0, () => {
      const ready = buildNavigationCardBindingData(readySnapshot(), 1770000100000);
      expect(ready.status).assertEqual('ready');
      expect(ready.cardStyle).assertEqual('destination');
      expect(ready.title).assertEqual('喜茶(深圳坂田华创里店)');
      expect(ready.sourceText).assertEqual('高德 / 腾讯地图');
      expect(ready.primaryAction).assertEqual('open_map');
      expect(ready.secondaryAction).assertEqual('open_agent');

      const expired = buildNavigationCardBindingData(readySnapshot(), 1770007200000);
      expect(expired.status).assertEqual('expired');
      expect(expired.primaryAction).assertEqual('open_agent');
      expect(expired.message).assertEqual('导航卡片已过期，请回到 Appless Phone 刷新真实结果');

      const failed: NavigationCardSnapshot = readySnapshot();
      failed.status = 'error';
      failed.error = '地图 provider 未返回真实坐标';
      const error = buildNavigationCardBindingData(failed, 1770000100000);
      expect(error.status).assertEqual('error');
      expect(error.primaryAction).assertEqual('open_agent');
      expect(error.message).assertEqual('地图 provider 未返回真实坐标');

      const empty = buildEmptyNavigationCardBindingData();
      expect(empty.status).assertEqual('empty');
      expect(empty.primaryAction).assertEqual('open_agent');
      expect(empty.message).assertEqual('从 Appless Phone 对话生成导航卡片');
    });

    it('detects expiry by absolute timestamp', 0, () => {
      expect(navigationCardSnapshotExpired(readySnapshot(), 1770003599999)).assertFalse();
      expect(navigationCardSnapshotExpired(readySnapshot(), 1770003600000)).assertTrue();
    });

    it('creates a travel departure card from train rows', 0, () => {
      const result = navigationCardSnapshotFromTrainOption(trainOption(), {
        surfaceId: 'surface_train',
        toolId: 'train.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertTrue();
      expect(canCreateNavigationCardFromTrainOption(trainOption())).assertTrue();
      expect(result.snapshot === undefined).assertFalse();
      if (result.snapshot !== undefined) {
        expect(result.snapshot.cardStyle).assertEqual('travel');
        expect(result.snapshot.transport).assertEqual('train');
        expect(result.snapshot.title).assertEqual('G79');
        expect(result.snapshot.routeText).assertEqual('北京南 → 上海虹桥');
        expect(result.snapshot.targetName).assertEqual('北京南站');
        expect(result.snapshot.location).assertEqual('116.37639,39.86583');
        expect(result.snapshot.departureTime).assertEqual('10:00');
        expect(result.snapshot.serviceText).assertEqual('高铁 · 12306');
        expect(result.snapshot.mapUri).assertEqual('petalmaps://poidetail?center=39.86583,116.37639&z=16&marker=39.86583,116.37639&name=%E5%8C%97%E4%BA%AC%E5%8D%97%E7%AB%99&utm_source=com.example.aiphonedemo');
      }
    });

    it('creates a travel departure card from integrated travel options', 0, () => {
      const result = navigationCardSnapshotFromTravelOption(travelTrainOption(), {
        surfaceId: 'surface_travel',
        toolId: 'travel.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertTrue();
      expect(canCreateNavigationCardFromTravelOption(travelTrainOption())).assertTrue();
      if (result.snapshot !== undefined) {
        expect(result.snapshot.cardStyle).assertEqual('travel');
        expect(result.snapshot.transport).assertEqual('train');
        expect(result.snapshot.sourceTags.join('/')).assertEqual('高铁 · 12306');
        expect(result.snapshot.mapUri).assertEqual('petalmaps://poidetail?center=39.86583,116.37639&z=16&marker=39.86583,116.37639&name=%E5%8C%97%E4%BA%AC%E5%8D%97%E7%AB%99&utm_source=com.example.aiphonedemo');
      }
    });

    it('creates flight departure cards only when a real airport coordinate is present', 0, () => {
      const readyFlight = navigationCardSnapshotFromFlightOption(flightOptionWithAirport(), {
        surfaceId: 'surface_flight',
        toolId: 'flight.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });
      expect(readyFlight.ok).assertTrue();
      expect(canCreateNavigationCardFromFlightOption(flightOptionWithAirport())).assertTrue();
      if (readyFlight.snapshot !== undefined) {
        expect(readyFlight.snapshot.cardStyle).assertEqual('travel');
        expect(readyFlight.snapshot.transport).assertEqual('flight');
        expect(readyFlight.snapshot.targetName).assertEqual('北京首都机场');
        expect(readyFlight.snapshot.location).assertEqual('116.58444,40.08000');
        expect(readyFlight.snapshot.departureTime).assertEqual('2026-06-25 08:30:00');
        expect(readyFlight.snapshot.mapUri).assertEqual('petalmaps://poidetail?center=40.08000,116.58444&z=16&marker=40.08000,116.58444&name=%E5%8C%97%E4%BA%AC%E9%A6%96%E9%83%BD%E6%9C%BA%E5%9C%BA&utm_source=com.example.aiphonedemo');
      }

      const codeOnly = flightOptionWithAirport();
      codeOnly.dep = 'BJS';
      const rejected = navigationCardSnapshotFromFlightOption(codeOnly, {
        surfaceId: 'surface_flight',
        toolId: 'flight.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });
      expect(rejected.ok).assertFalse();
      expect(rejected.error).assertEqual('缺少真实出发站或机场坐标，不能生成出行卡片');
      expect(canCreateNavigationCardFromFlightOption(codeOnly)).assertFalse();
    });

    it('rejects train departure cards when the departure station has no real coordinate', 0, () => {
      const item = trainOption();
      item.from = '不存在枢纽';
      const result = navigationCardSnapshotFromTrainOption(item, {
        surfaceId: 'surface_train',
        toolId: 'train.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });

      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('缺少真实出发站或机场坐标，不能生成出行卡片');
      expect(canCreateNavigationCardFromTrainOption(item)).assertFalse();
    });

    it('maps travel snapshot fields to form binding data', 0, () => {
      const result = navigationCardSnapshotFromTravelOption(travelTrainOption(), {
        surfaceId: 'surface_travel',
        toolId: 'travel.search',
        updatedAt: 1770000000000,
        expiresAt: 1770003600000
      });
      expect(result.snapshot === undefined).assertFalse();
      if (result.snapshot !== undefined) {
        const binding = buildNavigationCardBindingData(result.snapshot, 1770000100000);
        expect(binding.cardStyle).assertEqual('travel');
        expect(binding.transport).assertEqual('train');
        expect(binding.routeText).assertEqual('北京南 → 上海虹桥');
        expect(binding.targetName).assertEqual('北京南站');
        expect(binding.departureTime).assertEqual('10:00');
        expect(binding.sourceText).assertEqual('');
        expect(binding.destinationUri).assertEqual('petalmaps://poidetail?center=39.86583,116.37639&z=16&marker=39.86583,116.37639&name=%E5%8C%97%E4%BA%AC%E5%8D%97%E7%AB%99&utm_source=com.example.aiphonedemo');
        expect(binding.primaryAction).assertEqual('open_map');
      }
    });

    it('upgrades legacy travel map links to coordinate-backed POI links for existing desktop cards', 0, () => {
      const legacy: NavigationCardSnapshot = readySnapshot();
      legacy.cardStyle = 'travel';
      legacy.transport = 'train';
      legacy.title = 'G79';
      legacy.address = '北京南站';
      legacy.location = '北京南站';
      legacy.targetName = '北京南站';
      legacy.mapUri = 'petalmaps://navigation?daddr=%E5%8C%97%E4%BA%AC%E5%8D%97%E7%AB%99&language=zh&type=drive&utm_source=com.example.aiphonedemo';

      const binding = buildNavigationCardBindingData(legacy, 1770000100000);
      const expected = 'petalmaps://poidetail?center=39.86583,116.37639&z=16&marker=39.86583,116.37639&name=%E5%8C%97%E4%BA%AC%E5%8D%97%E7%AB%99&utm_source=com.example.aiphonedemo';
      expect(binding.destinationUri).assertEqual(expected);
      expect(resolveNavigationCardMapUri('travel', 'train', '北京南站', '北京南站', legacy.mapUri)).assertEqual(expected);
    });

    it('stores one current snapshot and registered form ids in memory tests', 0, async () => {
      const store = new MemoryNavigationCardSnapshotStore();
      await store.saveSnapshot(readySnapshot());
      await store.addFormId('form-1');
      await store.addFormId('form-1');
      await store.addFormId('form-2');
      await store.removeFormId('form-1');

      const snapshot = await store.getSnapshot();
      expect(snapshot === null).assertFalse();
      if (snapshot !== null) {
        expect(snapshot.title).assertEqual('喜茶(深圳坂田华创里店)');
      }
      expect((await store.getFormIds()).join(',')).assertEqual('form-2');
    });

    it('accepts only supported card form events', 0, () => {
      expect(navigationCardFormEventFromMessage('open_map')).assertEqual('open_map');
      expect(navigationCardFormEventFromMessage('open_agent')).assertEqual('open_agent');
      expect(navigationCardFormEventFromMessage('refresh')).assertEqual('refresh');
      expect(navigationCardFormEventFromMessage('pay')).assertEqual('');
      expect(navigationCardFormEventFromMessage('{"action":"open_map"}')).assertEqual('open_map');
    });
  });
}
