import { describe, it, expect } from '@ohos/hypium';
import { flightOptions, foodOptions, foodVisualSourceTag, trainOptions } from '../main/ets/model/A2uiData';
import {
  A2uiComponent,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiRowGroupsData,
  A2uiRuntimeDataModel,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTrainData,
  A2uiTravelOptionData,
  A2uiTripData
} from '../main/ets/model/A2uiTypes';
import { emptySocialHub } from '../main/ets/model/SocialHubTypes';

function businessSurface(): A2uiSurfaceState {
  const trains: A2uiTrainData[] = [{
    trainCode: 'G1',
    from: '北京南',
    to: '上海虹桥',
    depart: '09:00',
    arrive: '13:28',
    duration: '4小时28分',
    seats: '二等座有票',
    status: 'success',
    business: '',
    first: '',
    second: '有',
    noSeat: '',
    hardSeat: '',
    sleeperSoft: ''
  }];
  const flights: A2uiFlightData[] = [{
    flightNo: 'MU2157',
    airline: '东方航空',
    dep: '北京',
    arr: '上海',
    depTime: '10:00',
    arrTime: '12:10',
    status: '计划',
    price: '580'
  }];
  const foods: A2uiFoodData[] = [{
    name: '测试餐厅',
    category: '中餐',
    address: '测试路 1 号',
    distance: '300米'
  }];
  const travelOptions: A2uiTravelOptionData[] = [];
  const rows: A2uiLabelValueData[] = [];
  const thoughts: string[] = [];
  const summary: A2uiSummaryData = {
    text: '',
    toolName: '',
    dataLabel: '',
    count: 0
  };
  const tripRows: A2uiLabelValueData[] = [];
  const trip: A2uiTripData = {
    rows: tripRows
  };
  const trainRows: A2uiLabelValueData[] = [];
  const flightRows: A2uiLabelValueData[] = [];
  const foodRows: A2uiLabelValueData[] = [];
  const rowGroups: A2uiRowGroupsData = {
    train: trainRows,
    flight: flightRows,
    food: foodRows
  };
  const toolRequest: A2uiToolRequestData = {
    toolId: '',
    prompt: '',
    actionId: ''
  };
  const model: A2uiRuntimeDataModel = {
    rows: rows,
    trains: trains,
    flights: flights,
    travelOptions: travelOptions,
    foods: foods,
    thoughts: thoughts,
    summary: summary,
    trip: trip,
    rowGroups: rowGroups,
    form: {},
    toolRequest: toolRequest,
    dynamicToolConnect: {
      toolId: '',
      prompt: '',
      manifestId: '',
      displayName: '',
      sourceUrl: '',
      status: '',
      message: '',
      credentialName: '',
      credentialRef: '',
      registrationUrl: '',
      actions: []
    },
    genericToolResults: [],
    socialHub: emptySocialHub()
  };
  const components: A2uiComponent[] = [];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '工具结果',
    intent: 'travel',
    status: 'ready',
    components: components,
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

export default function a2uiBusinessDataTest() {
  describe('a2uiBusinessData', () => {
    it('reads train flight and food data by component dataPath', 0, () => {
      const surface = businessSurface();
      const trainComponent: A2uiComponent = { id: 'train', component: 'TrainOptions', dataPath: '/trains' };
      const flightComponent: A2uiComponent = { id: 'flight', component: 'FlightBoard', dataPath: '/flights' };
      const foodComponent: A2uiComponent = { id: 'food', component: 'FoodChoices', dataPath: '/foods' };

      expect(trainOptions(surface, trainComponent)[0].trainCode).assertEqual('G1');
      expect(flightOptions(surface, flightComponent)[0].flightNo).assertEqual('MU2157');
      expect(foodOptions(surface, foodComponent)[0].name).assertEqual('测试餐厅');
    });

    it('uses provider color only for single-source food cards', 0, () => {
      expect(foodVisualSourceTag(['高德'])).assertEqual('高德');
      expect(foodVisualSourceTag(['高德', '高德'])).assertEqual('高德');
      expect(foodVisualSourceTag(['高德', '腾讯地图'])).assertEqual('');
      expect(foodVisualSourceTag([])).assertEqual('');
    });
  });
}
