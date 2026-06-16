import { A2uiAction, A2uiTrainData } from '../../../model/A2uiTypes';

export const A2UI_TRAIN_INITIAL_VISIBLE: number = 6;
export const A2UI_TRAIN_ACTION_SHOW_MORE: string = 'client_show_more';
export const A2UI_TRAIN_ACTION_SORT_FASTEST: string = 'client_sort_fastest';
export const A2UI_TRAIN_ACTION_FILTER_AVAILABLE: string = 'client_filter_available';
export const A2UI_TRAIN_ACTION_ACTIVATED: string = 'activated';
export const A2UI_TRAIN_ACTION_DEACTIVATED: string = 'deactivated';

export interface A2uiTrainViewState {
  showAll: boolean;
  fastestFirst: boolean;
  availableOnly: boolean;
}

function numericValue(text: string): number {
  const value = Number.parseInt(text, 10);
  return value === value ? value : 0;
}

function hasAvailableSeatText(text: string): boolean {
  const value = text.trim();
  if (value.length === 0 || value === '--' || value === '无' || value === '候补' || value === '*') {
    return false;
  }
  if (value.indexOf('无') >= 0 && value.indexOf('有') < 0) {
    return false;
  }
  if (value.indexOf('有') >= 0) {
    return true;
  }
  return numericValue(value) > 0;
}

function trainHasAvailableSeat(item: A2uiTrainData): boolean {
  return hasAvailableSeatText(item.business) ||
    hasAvailableSeatText(item.first) ||
    hasAvailableSeatText(item.second) ||
    hasAvailableSeatText(item.noSeat) ||
    hasAvailableSeatText(item.hardSeat) ||
    hasAvailableSeatText(item.sleeperSoft) ||
    hasAvailableSeatText(item.seats);
}

function durationMinutes(duration: string): number {
  const text = duration.trim();
  if (text.length === 0) {
    return 999999;
  }
  const hourIndex = text.indexOf('小时') >= 0 ? text.indexOf('小时') : text.indexOf('时');
  let minutes = 0;
  if (hourIndex > 0) {
    minutes = minutes + numericValue(text.substring(0, hourIndex)) * 60;
    const minuteText = text.substring(hourIndex + (text.indexOf('小时') >= 0 ? 2 : 1));
    minutes = minutes + numericValue(minuteText);
    return minutes > 0 ? minutes : 999999;
  }
  const colonIndex = text.indexOf(':');
  if (colonIndex > 0) {
    minutes = numericValue(text.substring(0, colonIndex)) * 60 + numericValue(text.substring(colonIndex + 1));
    return minutes > 0 ? minutes : 999999;
  }
  if (text.indexOf('分') > 0) {
    minutes = numericValue(text);
    return minutes > 0 ? minutes : 999999;
  }
  return 999999;
}

function departMinutes(depart: string): number {
  const text = depart.trim();
  const colonIndex = text.indexOf(':');
  if (colonIndex <= 0) {
    return 999999;
  }
  return numericValue(text.substring(0, colonIndex)) * 60 + numericValue(text.substring(colonIndex + 1));
}

export function visibleTrainOptions(trains: A2uiTrainData[], state: A2uiTrainViewState): A2uiTrainData[] {
  let next: A2uiTrainData[] = trains.slice();
  if (state.availableOnly) {
    next = next.filter((item: A2uiTrainData) => trainHasAvailableSeat(item));
  }
  if (state.fastestFirst) {
    next = next.sort((left: A2uiTrainData, right: A2uiTrainData) => {
      return durationMinutes(left.duration) - durationMinutes(right.duration);
    });
  } else {
    next = next.sort((left: A2uiTrainData, right: A2uiTrainData) => {
      return departMinutes(left.depart) - departMinutes(right.depart);
    });
  }
  if (!state.showAll && next.length > A2UI_TRAIN_INITIAL_VISIBLE) {
    return next.slice(0, A2UI_TRAIN_INITIAL_VISIBLE);
  }
  return next;
}

function trainActionVariant(active: boolean): string {
  return active ? A2UI_TRAIN_ACTION_ACTIVATED : A2UI_TRAIN_ACTION_DEACTIVATED;
}

function trainActionLabel(action: A2uiAction): string {
  if (action.id === A2UI_TRAIN_ACTION_SHOW_MORE) {
    return '展示全部';
  }
  if (action.id === A2UI_TRAIN_ACTION_SORT_FASTEST) {
    return '选最快的';
  }
  if (action.id === A2UI_TRAIN_ACTION_FILTER_AVAILABLE) {
    return '只看有票';
  }
  return action.label;
}

function trainActionActive(action: A2uiAction, showAll: boolean, fastestFirst: boolean, availableOnly: boolean): boolean {
  if (action.id === A2UI_TRAIN_ACTION_SHOW_MORE) {
    return showAll;
  }
  if (action.id === A2UI_TRAIN_ACTION_SORT_FASTEST) {
    return fastestFirst;
  }
  if (action.id === A2UI_TRAIN_ACTION_FILTER_AVAILABLE) {
    return availableOnly;
  }
  return false;
}

export function trainActionForState(
  action: A2uiAction,
  showAll: boolean,
  fastestFirst: boolean,
  availableOnly: boolean
): A2uiAction {
  if (isLocalTrainAction(action)) {
    return {
      id: action.id,
      label: trainActionLabel(action),
      prompt: action.prompt,
      kind: action.kind,
      variant: trainActionVariant(trainActionActive(action, showAll, fastestFirst, availableOnly))
    };
  }
  return action;
}

export function isLocalTrainAction(action: A2uiAction): boolean {
  return action.id === A2UI_TRAIN_ACTION_SHOW_MORE ||
    action.id === A2UI_TRAIN_ACTION_SORT_FASTEST ||
    action.id === A2UI_TRAIN_ACTION_FILTER_AVAILABLE;
}

export function nextTrainViewStateForAction(state: A2uiTrainViewState, action: A2uiAction): A2uiTrainViewState {
  if (action.id === A2UI_TRAIN_ACTION_SHOW_MORE) {
    return {
      showAll: !state.showAll,
      fastestFirst: state.fastestFirst,
      availableOnly: state.availableOnly
    };
  }
  if (action.id === A2UI_TRAIN_ACTION_SORT_FASTEST) {
    return {
      showAll: state.showAll,
      fastestFirst: !state.fastestFirst,
      availableOnly: state.availableOnly
    };
  }
  if (action.id === A2UI_TRAIN_ACTION_FILTER_AVAILABLE) {
    return {
      showAll: state.showAll,
      fastestFirst: state.fastestFirst,
      availableOnly: !state.availableOnly
    };
  }
  return state;
}
