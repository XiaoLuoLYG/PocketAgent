import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction, A2uiTrainData } from '../main/ets/model/A2uiTypes';
import {
  A2UI_TRAIN_ACTION_FILTER_AVAILABLE,
  A2UI_TRAIN_ACTION_SHOW_MORE,
  A2UI_TRAIN_ACTION_SORT_FASTEST,
  A2UI_TRAIN_INITIAL_VISIBLE,
  A2uiTrainViewState,
  nextTrainViewStateForAction,
  trainActionForState,
  visibleTrainOptions
} from '../main/ets/pages/A2uiHome/state/A2uiTrainOptionsState';

function train(code: string, duration: string, second: string, depart: string = '09:00'): A2uiTrainData {
  return {
    trainCode: code,
    from: '北京南',
    to: '上海虹桥',
    depart: depart,
    arrive: '13:00',
    duration: duration,
    seats: second.length > 0 ? '二等座' + second : '',
    status: 'success',
    business: '',
    first: '',
    second: second,
    noSeat: '',
    hardSeat: '',
    sleeperSoft: ''
  };
}

function action(id: string, label: string): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: id,
    kind: 'client',
    variant: 'secondary'
  };
}

export default function a2uiTrainOptionsStateTest() {
  describe('a2uiTrainOptionsState', () => {
    it('renders the first six trains by default', 0, () => {
      const trains: A2uiTrainData[] = [
        train('G1', '4小时1分', '有'),
        train('G2', '4小时2分', '有'),
        train('G3', '4小时3分', '有'),
        train('G4', '4小时4分', '有'),
        train('G5', '4小时5分', '有'),
        train('G6', '4小时6分', '有'),
        train('G7', '4小时7分', '有')
      ];
      const state: A2uiTrainViewState = {
        showAll: false,
        fastestFirst: false,
        availableOnly: false
      };

      expect(visibleTrainOptions(trains, state).length).assertEqual(A2UI_TRAIN_INITIAL_VISIBLE);
      expect(visibleTrainOptions(trains, state)[5].trainCode).assertEqual('G6');
    });

    it('renders all trains after expanding', 0, () => {
      const trains: A2uiTrainData[] = [
        train('G1', '4小时1分', '有'),
        train('G2', '4小时2分', '有'),
        train('G3', '4小时3分', '有'),
        train('G4', '4小时4分', '有'),
        train('G5', '4小时5分', '有'),
        train('G6', '4小时6分', '有'),
        train('G7', '4小时7分', '有')
      ];
      const state: A2uiTrainViewState = {
        showAll: true,
        fastestFirst: false,
        availableOnly: false
      };

      expect(visibleTrainOptions(trains, state).length).assertEqual(7);
    });

    it('sorts trains locally by shortest duration', 0, () => {
      const trains: A2uiTrainData[] = [
        train('G100', '5小时10分', '有'),
        train('G2', '4小时28分', '有'),
        train('G88', '6小时', '有')
      ];
      const state: A2uiTrainViewState = {
        showAll: true,
        fastestFirst: true,
        availableOnly: false
      };

      expect(visibleTrainOptions(trains, state)[0].trainCode).assertEqual('G2');
    });

    it('sorts trains by departure time when fastest sorting is off', 0, () => {
      const trains: A2uiTrainData[] = [
        train('G100', '5小时10分', '有', '11:20'),
        train('G2', '4小时28分', '有', '07:32'),
        train('G88', '6小时', '有', '09:40')
      ];
      const state: A2uiTrainViewState = {
        showAll: true,
        fastestFirst: false,
        availableOnly: false
      };

      expect(visibleTrainOptions(trains, state)[0].trainCode).assertEqual('G2');
      expect(visibleTrainOptions(trains, state)[1].trainCode).assertEqual('G88');
      expect(visibleTrainOptions(trains, state)[2].trainCode).assertEqual('G100');
    });

    it('filters trains locally to available seats', 0, () => {
      const trains: A2uiTrainData[] = [
        train('G100', '5小时10分', '无'),
        train('G2', '4小时28分', '3'),
        train('G88', '6小时', '--')
      ];
      const state: A2uiTrainViewState = {
        showAll: true,
        fastestFirst: false,
        availableOnly: true
      };

      expect(visibleTrainOptions(trains, state).length).assertEqual(1);
      expect(visibleTrainOptions(trains, state)[0].trainCode).assertEqual('G2');
    });

    it('keeps local action labels stable and maps active state to variants', 0, () => {
      const showMore = trainActionForState(action(A2UI_TRAIN_ACTION_SHOW_MORE, '多展示一些'), true, false, false);
      const filter = trainActionForState(action(A2UI_TRAIN_ACTION_FILTER_AVAILABLE, '只看有票'), false, false, true);
      const fastest = trainActionForState(action(A2UI_TRAIN_ACTION_SORT_FASTEST, '选最快的'), false, true, false);

      expect(showMore.label).assertEqual('展示全部');
      expect(showMore.variant).assertEqual('activated');
      expect(fastest.label).assertEqual('选最快的');
      expect(fastest.variant).assertEqual('activated');
      expect(filter.label).assertEqual('只看有票');
      expect(filter.variant).assertEqual('activated');
    });

    it('marks inactive local actions as deactivated', 0, () => {
      const showMore = trainActionForState(action(A2UI_TRAIN_ACTION_SHOW_MORE, '多展示一些'), false, false, false);
      const filter = trainActionForState(action(A2UI_TRAIN_ACTION_FILTER_AVAILABLE, '只看有票'), false, false, false);

      expect(showMore.variant).assertEqual('deactivated');
      expect(filter.variant).assertEqual('deactivated');
    });

    it('toggles local train view flags from action ids', 0, () => {
      const base: A2uiTrainViewState = {
        showAll: false,
        fastestFirst: true,
        availableOnly: false
      };

      expect(nextTrainViewStateForAction(base, action(A2UI_TRAIN_ACTION_SORT_FASTEST, '选最快的')).fastestFirst)
        .assertFalse();
      expect(nextTrainViewStateForAction(base, action(A2UI_TRAIN_ACTION_SHOW_MORE, '展示全部')).showAll)
        .assertTrue();
      expect(nextTrainViewStateForAction(base, action(A2UI_TRAIN_ACTION_FILTER_AVAILABLE, '只看有票')).availableOnly)
        .assertTrue();
    });
  });
}
