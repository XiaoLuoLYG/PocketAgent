export const A2UI_VERSION: string = 'v0.9.1';
export const A2UI_MIME: string = 'application/a2ui+json';

export const A2UI_COMPONENT_SURFACE_ROOT: string = 'SurfaceRoot';
export const A2UI_COMPONENT_COLUMN: string = 'Column';
export const A2UI_COMPONENT_ROW: string = 'Row';
export const A2UI_COMPONENT_TEXT: string = 'Text';
export const A2UI_COMPONENT_ACTION_BAR: string = 'ActionBar';
export const A2UI_COMPONENT_ERROR_NOTICE: string = 'ErrorNotice';
export const A2UI_COMPONENT_THINKING_STREAM: string = 'ThinkingStream';
export const A2UI_COMPONENT_THINKING_CARD: string = 'ThinkingCard';
export const A2UI_COMPONENT_TRAIN_OPTIONS: string = 'TrainOptions';
export const A2UI_COMPONENT_FLIGHT_BOARD: string = 'FlightBoard';
export const A2UI_COMPONENT_TRAVEL_OPTIONS: string = 'TravelOptions';
export const A2UI_COMPONENT_FOOD_CHOICES: string = 'FoodChoices';
export const A2UI_COMPONENT_SOCIAL_INBOX: string = 'SocialInbox';
export const A2UI_COMPONENT_CONFIRM_PANEL: string = 'ConfirmPanel';
export const A2UI_COMPONENT_INFO_ROWS: string = 'InfoRows';

export interface A2uiAction {
  id: string;
  label: string;
  prompt: string;
  variant: string;
  kind: string;
}

export interface A2uiLabelValueData {
  label: string;
  value: string;
}

export interface A2uiTrainData {
  trainCode: string;
  from: string;
  to: string;
  depart: string;
  arrive: string;
  duration: string;
  seats: string;
  status: string;
  business: string;
  first: string;
  second: string;
  noSeat: string;
  hardSeat: string;
  sleeperSoft: string;
}

export interface A2uiFlightData {
  flightNo: string;
  airline: string;
  dep: string;
  arr: string;
  depTime: string;
  arrTime: string;
  status: string;
  price: string;
}

export interface A2uiTravelOptionData {
  id: string;
  source: string;
  sourceTag: string;
  title: string;
  from: string;
  to: string;
  depart: string;
  arrive: string;
  duration: string;
  price: string;
  availability: string;
  status: string;
  detail: string;
}

export interface A2uiFoodData {
  name: string;
  category: string;
  address: string;
  distance: string;
  location?: string;
  sourceTags?: string[];
}

export interface A2uiSocialMessageData {
  id: string;
  platform: string;
  conversationId: string;
  conversationTitle: string;
  senderName: string;
  preview: string;
  receivedAt: string;
  source: string;
  status: string;
}

export interface A2uiSocialReplyData {
  id: string;
  targetMessageId: string;
  platform: string;
  conversationId: string;
  text: string;
  status: string;
  error: string;
  sentAt: string;
}

export interface A2uiSocialData {
  messages: A2uiSocialMessageData[];
  replies: A2uiSocialReplyData[];
  diagnostics: A2uiLabelValueData[];
}

export interface A2uiSummaryData {
  text: string;
  toolName: string;
  dataLabel: string;
  count: number;
}

export interface A2uiTripData {
  rows: A2uiLabelValueData[];
}

export interface A2uiRowGroupsData {
  train: A2uiLabelValueData[];
  flight: A2uiLabelValueData[];
  food: A2uiLabelValueData[];
}

export interface A2uiToolRequestData {
  toolId: string;
  prompt: string;
  actionId: string;
}

export interface A2uiRuntimeDataModel {
  rows: A2uiLabelValueData[];
  trains: A2uiTrainData[];
  flights: A2uiFlightData[];
  travelOptions: A2uiTravelOptionData[];
  foods: A2uiFoodData[];
  social: A2uiSocialData;
  thoughts: string[];
  summary: A2uiSummaryData;
  trip: A2uiTripData;
  rowGroups: A2uiRowGroupsData;
  toolRequest: A2uiToolRequestData;
  toolRequests?: A2uiToolRequestData[];
}

export type A2uiDataValue =
  A2uiRuntimeDataModel |
  A2uiLabelValueData[] |
  A2uiTrainData[] |
  A2uiFlightData[] |
  A2uiTravelOptionData[] |
  A2uiFoodData[] |
  A2uiSocialMessageData[] |
  A2uiSocialReplyData[] |
  A2uiSocialData |
  string[] |
  A2uiSummaryData |
  A2uiTripData |
  A2uiRowGroupsData |
  A2uiToolRequestData |
  A2uiToolRequestData[] |
  string |
  number |
  boolean |
  null;

export interface A2uiDataBinding {
  path: string;
}

export interface A2uiComponent {
  id: string;
  component: string;
  child?: string;
  children?: string[];
  title?: string;
  text?: string;
  body?: string;
  status?: string;
  tone?: string;
  variant?: string;
  path?: string;
  dataPath?: string;
  actions?: A2uiAction[];
}

export interface A2uiCreateSurface {
  surfaceId: string;
  root?: string;
  title?: string;
  intent?: string;
  status?: string;
  sendDataModel?: boolean;
}

export interface A2uiUpdateComponents {
  surfaceId: string;
  components: A2uiComponent[];
}

export interface A2uiUpdateDataModel {
  surfaceId: string;
  path: string;
  value: A2uiDataValue;
}

export interface A2uiDeleteSurface {
  surfaceId: string;
}

export interface A2uiEnvelope {
  version?: string;
  createSurface?: A2uiCreateSurface;
  updateComponents?: A2uiUpdateComponents;
  updateDataModel?: A2uiUpdateDataModel;
  deleteSurface?: A2uiDeleteSurface;
}

export interface A2uiSurfaceState {
  surfaceId: string;
  rootId: string;
  title: string;
  intent: string;
  status: string;
  components: A2uiComponent[];
  dataModelJson: string;
  error: string;
  sequence: number;
}

export interface A2uiApplyResult {
  ok: boolean;
  error: string;
}

export interface A2uiStreamParseResult {
  envelopes: A2uiEnvelope[];
  remainder: string;
  error: string;
}

export interface A2uiClientCapabilities {
  protocolVersion: string;
  catalogs: string[];
  components: string[];
  transport: string[];
}

export interface A2uiMessage {
  id: string;
  role: string;
  content: string;
}

export interface A2uiCallResult {
  ok: boolean;
  raw: string;
  error: string;
  requestDebug: string;
  assistantDebug: string;
  surface: A2uiSurfaceState;
}

export function emptyA2uiSurface(surfaceId: string = 'surface_main'): A2uiSurfaceState {
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: 'AIPhone',
    intent: 'general',
    status: 'idle',
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: 0
  };
}

export function defaultA2uiCapabilities(): A2uiClientCapabilities {
  return {
    protocolVersion: A2UI_VERSION,
    catalogs: ['aiphone.catalog.v1'],
    components: [
      A2UI_COMPONENT_SURFACE_ROOT,
      A2UI_COMPONENT_COLUMN,
      A2UI_COMPONENT_ROW,
      A2UI_COMPONENT_TEXT,
      A2UI_COMPONENT_ACTION_BAR,
      A2UI_COMPONENT_ERROR_NOTICE,
      A2UI_COMPONENT_THINKING_STREAM,
      A2UI_COMPONENT_THINKING_CARD,
      A2UI_COMPONENT_TRAIN_OPTIONS,
      A2UI_COMPONENT_FLIGHT_BOARD,
      A2UI_COMPONENT_TRAVEL_OPTIONS,
      A2UI_COMPONENT_FOOD_CHOICES,
      A2UI_COMPONENT_SOCIAL_INBOX,
      A2UI_COMPONENT_CONFIRM_PANEL,
      A2UI_COMPONENT_INFO_ROWS
    ],
    transport: ['jsonl', 'openai-compatible-sse']
  };
}
