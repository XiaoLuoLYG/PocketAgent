import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_STREAM,
  A2uiAction,
  A2uiComponent,
  A2uiLabelValueData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState
} from '../../../model/A2uiTypes';

export interface A2uiStyleLabCase {
  id: string;
  title: string;
  description: string;
  surface: A2uiSurfaceState;
}

function action(id: string, label: string, variant: string = 'secondary'): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: 'style-lab action ' + id,
    variant: variant,
    kind: 'client'
  };
}

function modelJson(rows: A2uiLabelValueData[] = [], thoughts: string[] = []): string {
  const model: A2uiRuntimeDataModel = {
    rows: rows,
    trains: [],
    flights: [],
    travelOptions: [],
    foods: [],
    social: {
      messages: [],
      replies: [],
      diagnostics: []
    },
    thoughts: thoughts,
    summary: {
      text: '',
      toolName: '',
      dataLabel: '',
      count: 0
    },
    trip: {
      rows: []
    },
    rowGroups: {
      train: [],
      flight: [],
      food: []
    },
    toolRequest: {
      toolId: '',
      prompt: '',
      actionId: ''
    }
  };
  return JSON.stringify(model);
}

function surface(
  id: string,
  title: string,
  status: string,
  components: A2uiComponent[],
  dataModelJson: string = modelJson()
): A2uiSurfaceState {
  return {
    surfaceId: 'style_lab_' + id,
    rootId: 'root',
    title: title,
    intent: 'style_lab',
    status: status,
    components: components,
    dataModelJson: dataModelJson,
    error: status === 'error' ? title : '',
    sequence: 1
  };
}

function cloneActions(actions: A2uiAction[] | undefined): A2uiAction[] {
  const next: A2uiAction[] = [];
  if (actions === undefined) {
    return next;
  }
  actions.forEach((item: A2uiAction) => {
    next.push({
      id: item.id,
      label: item.label,
      prompt: item.prompt,
      variant: item.variant,
      kind: item.kind
    });
  });
  return next;
}

function cloneComponents(components: A2uiComponent[]): A2uiComponent[] {
  const next: A2uiComponent[] = [];
  components.forEach((component: A2uiComponent) => {
    next.push({
      id: component.id,
      component: component.component,
      child: component.child,
      children: component.children === undefined ? [] : component.children.slice(),
      title: component.title,
      text: component.text,
      body: component.body,
      status: component.status,
      tone: component.tone,
      variant: component.variant,
      path: component.path,
      dataPath: component.dataPath,
      actions: cloneActions(component.actions)
    });
  });
  return next;
}

export function cloneA2uiStyleLabSurface(surface: A2uiSurfaceState): A2uiSurfaceState {
  return {
    surfaceId: surface.surfaceId,
    rootId: surface.rootId,
    title: surface.title,
    intent: surface.intent,
    status: surface.status,
    components: cloneComponents(surface.components),
    dataModelJson: surface.dataModelJson,
    error: surface.error,
    sequence: surface.sequence
  };
}

const simpleSurface: A2uiSurfaceState = surface('simple', '简单文案卡片', 'ready', [
  { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
  { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['title', 'summary', 'actions'] },
  { id: 'title', component: A2UI_COMPONENT_TEXT, text: '今天先把轻组件排版放稳', variant: 'title' },
  {
    id: 'summary',
    component: A2UI_COMPONENT_TEXT,
    text: '这个用例只包含标题、正文和两个操作按钮，用来检查基础间距、字号、换行和按钮状态。',
    tone: 'muted'
  },
  {
    id: 'actions',
    component: A2UI_COMPONENT_ACTION_BAR,
    actions: [action('simple_confirm', '确认样式', 'primary'), action('simple_skip', '稍后再看')]
  }
]);

const infoRowsSurface: A2uiSurfaceState = surface(
  'info_rows',
  '信息行组件',
  'ready',
  [
    { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
    { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['intro', 'rows', 'actions'] },
    { id: 'intro', component: A2UI_COMPONENT_TEXT, text: '检查标签和值的对齐、长文本换行，以及窄屏下的可读性。' },
    { id: 'rows', component: A2UI_COMPONENT_INFO_ROWS, title: '行程摘要', dataPath: '/rows' },
    {
      id: 'actions',
      component: A2UI_COMPONENT_ACTION_BAR,
      actions: [action('rows_primary', '使用这组信息', 'primary'), action('rows_edit', '修改条件')]
    }
  ],
  modelJson([
    { label: '出发地', value: '北京南站' },
    { label: '目的地', value: '上海虹桥站' },
    { label: '时间', value: '明天上午 08:00 后，优先高铁直达' },
    { label: '备注', value: '这是一条比较长的备注，用来观察 value 区域在手机宽度下是否自然换行。' }
  ])
);

const thinkingSurface: A2uiSurfaceState = surface(
  'thinking',
  '思考流占位',
  'thinking',
  [
    { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
    { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['stream'] },
    { id: 'stream', component: A2UI_COMPONENT_THINKING_STREAM, title: '正在理解你的请求', dataPath: '/thoughts' }
  ],
  modelJson([], ['正在分析用户意图', '正在匹配候选组件', '准备更新原生画布'])
);

const thinkingCompleteSurface: A2uiSurfaceState = surface(
  'thinking_complete',
  '思维链完成态',
  'ready',
  [
    { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
    { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['stream'] },
    { id: 'stream', component: A2UI_COMPONENT_THINKING_STREAM, title: '思维链已完成', status: 'ready', dataPath: '/thoughts' }
  ],
  modelJson([], ['已识别用户想查询出行方案', '已确认需要实时工具查询', '已准备好继续展示最终结果'])
);

const actionDenseSurface: A2uiSurfaceState = surface('action_dense', '按钮换行压力', 'ready', [
  { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
  { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['summary', 'actions'] },
  { id: 'summary', component: A2UI_COMPONENT_TEXT, text: '这里放一排数量较多、长度不同的按钮，专门看 Flex wrap 的表现。' },
  {
    id: 'actions',
    component: A2UI_COMPONENT_ACTION_BAR,
    actions: [
      action('dense_a', '接受', 'primary'),
      action('dense_b', '换一组方案'),
      action('dense_c', '只看上午'),
      action('dense_d', '价格优先'),
      action('dense_e', '时间优先'),
      action('dense_f', '保存偏好'),
      action('dense_g', '清空选择', 'danger')
    ]
  }
]);

const errorSurface: A2uiSurfaceState = surface('error', '错误提示组件', 'error', [
  { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
  { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['notice'] },
  {
    id: 'notice',
    component: A2UI_COMPONENT_ERROR_NOTICE,
    title: '工具返回内容不完整',
    body: '缺少必要字段，当前页面展示降级提示。',
    actions: [action('error_retry', '重试', 'primary'), action('error_report', '查看详情')]
  }
]);

export const A2UI_STYLE_LAB_CASES: A2uiStyleLabCase[] = [
  {
    id: 'simple',
    title: 'Text + ActionBar',
    description: '基础标题、正文和两个按钮',
    surface: simpleSurface
  },
  {
    id: 'info_rows',
    title: 'InfoRows',
    description: '标签/数值信息行',
    surface: infoRowsSurface
  },
  {
    id: 'thinking',
    title: 'Thinking',
    description: '思考中，底部点保持呼吸',
    surface: thinkingSurface
  },
  {
    id: 'thinking_complete',
    title: 'Thoughts Done',
    description: '思维链展示态，底部点固定',
    surface: thinkingCompleteSurface
  },
  {
    id: 'action_dense',
    title: 'Dense Actions',
    description: '多按钮换行压力',
    surface: actionDenseSurface
  },
  {
    id: 'error',
    title: 'ErrorNotice',
    description: '错误提示降级态',
    surface: errorSurface
  }
];

export function defaultA2uiStyleLabCase(): A2uiStyleLabCase {
  return A2UI_STYLE_LAB_CASES[0];
}

export function findA2uiStyleLabCase(id: string): A2uiStyleLabCase {
  for (let index = 0; index < A2UI_STYLE_LAB_CASES.length; index++) {
    if (A2UI_STYLE_LAB_CASES[index].id === id) {
      return A2UI_STYLE_LAB_CASES[index];
    }
  }
  return defaultA2uiStyleLabCase();
}
