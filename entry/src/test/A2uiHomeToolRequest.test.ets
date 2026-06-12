import { describe, it, expect } from '@ohos/hypium';
import { resolveA2uiHomeToolRequest } from '../main/ets/pages/A2uiHome/A2uiHomeToolRequest';
import {
  A2uiComponent,
  A2uiFlightData,
  A2uiFoodData,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiRowGroupsData,
  A2uiSummaryData,
  A2uiSurfaceState,
  A2uiToolRequestData,
  A2uiTrainData,
  A2uiTripData
} from '../main/ets/model/A2uiTypes';

function surfaceWithToolRequest(toolId: string, prompt: string, actionId: string): A2uiSurfaceState {
  const rows: A2uiLabelValueData[] = [];
  const thoughts: string[] = [];
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
  const trains: A2uiTrainData[] = [];
  const flights: A2uiFlightData[] = [];
  const foods: A2uiFoodData[] = [];
  const summary: A2uiSummaryData = {
    text: '',
    toolName: '',
    dataLabel: '',
    count: 0
  };
  const request: A2uiToolRequestData = {
    toolId: toolId,
    prompt: prompt,
    actionId: actionId
  };
  const model: A2uiRuntimeDataModel = {
    rows: rows,
    trains: trains,
    flights: flights,
    foods: foods,
    thoughts: thoughts,
    summary: summary,
    trip: trip,
    rowGroups: rowGroups,
    toolRequest: request
  };
  const components: A2uiComponent[] = [];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'calling_tool',
    components: components,
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

export default function a2uiHomeToolRequestTest() {
  describe('a2uiHomeToolRequest', () => {
    it('uses the model tool request when present', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('train.search', '查明天北京到上海高铁', 'model_tool_request'),
        '用户原始请求',
        ''
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('train.search');
      expect(resolved.prompt).assertEqual('查明天北京到上海高铁');
      expect(resolved.actionId).assertEqual('model_tool_request');
    });

    it('falls back to user prompt and action id when model omits them', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(
        surfaceWithToolRequest('food.search', '', ''),
        '附近有什么吃的',
        'retry_food'
      );

      expect(resolved.hasTool).assertTrue();
      expect(resolved.toolId).assertEqual('food.search');
      expect(resolved.prompt).assertEqual('附近有什么吃的');
      expect(resolved.actionId).assertEqual('retry_food');
    });

    it('reports no tool when the data model has no tool id', 0, () => {
      const resolved = resolveA2uiHomeToolRequest(surfaceWithToolRequest('', '', ''), '原始请求', '');

      expect(resolved.hasTool).assertFalse();
      expect(resolved.toolId).assertEqual('');
    });
  });
}
