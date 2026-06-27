import { describe, it, expect } from '@ohos/hypium';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { A2uiAction, A2uiComponent, A2uiMessage, A2uiSurfaceState } from '../main/ets/model/A2uiTypes';

function surface(intent: string, status: string, components: A2uiComponent[], dataModelJson: string): A2uiSurfaceState {
  return {
    surfaceId: 'surface_test',
    rootId: 'root',
    title: 'Test surface',
    intent: intent,
    status: status,
    components: components,
    dataModelJson: dataModelJson,
    error: '',
    sequence: 1
  };
}

function root(child: string): A2uiComponent {
  return {
    id: 'root',
    component: 'SurfaceRoot',
    child: child
  };
}

export default function htmlHomeSnapshotTest() {
  describe('htmlHomeSnapshot', () => {
    it('creates a welcome document without a surface', 0, () => {
      const doc = createHtmlHomeDocument({
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });

      expect(doc.version).assertEqual(1);
      expect(doc.source).assertEqual('welcome');
      expect(doc.kind).assertEqual('welcome');
      expect(doc.title).assertEqual('Appless Phone');
      expect(doc.rawSurfaceRoot === null).assertTrue();
      expect(doc.generatedAt.length).assertLarger(0);
    });

    it('creates a pending document while awaiting the first surface', 0, () => {
      const messages: A2uiMessage[] = [
        { id: 'm1', role: 'user', content: 'find lunch near office' }
      ];
      const doc = createHtmlHomeDocument({
        messages: messages,
        isBusy: true,
        isAwaitingFirstSurface: true,
        inputText: 'find lunch near office'
      });

      expect(doc.source).assertEqual('pending');
      expect(doc.kind).assertEqual('thinking');
      expect(doc.subtitle).assertEqual('find lunch near office');
      expect(doc.timeline[0].subtitle).assertEqual('find lunch near office');
      expect(doc.history.length).assertEqual(1);
      expect(JSON.stringify(doc).indexOf('"isBusy":true')).assertLarger(-1);
    });

    it('does not expose assistant A2UI protocol in history', 0, () => {
      const messages: A2uiMessage[] = [
        { id: 'u1', role: 'user', content: '你好' },
        {
          id: 'a1',
          role: 'assistant',
          content: '<think></think> {"version":"v0.9.1","createSurface":{"surfaceId":"surface_model"}} {"updateComponents":{}}'
        }
      ];
      const doc = createHtmlHomeDocument({
        messages: messages,
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc.history);

      expect(serialized.indexOf('你好')).assertLarger(-1);
      expect(serialized.indexOf('createSurface')).assertEqual(-1);
      expect(serialized.indexOf('updateComponents')).assertEqual(-1);
      expect(serialized.indexOf('<think>')).assertEqual(-1);
    });

    it('maps a travel option and UI action', 0, () => {
      const action: A2uiAction = {
        id: 'travel_filter_train',
        label: 'Train',
        prompt: 'travel_filter_train',
        variant: 'secondary',
        kind: 'client'
      };
      const options: A2uiComponent = {
        id: 'options',
        component: 'TravelOptions',
        dataPath: '/travelOptions',
        actions: [action]
      };
      const doc = createHtmlHomeDocument({
        surface: surface('travel', 'ready', [root('options'), options],
          '{"travelOptions":[{"id":"train-G1","source":"train","sourceTag":"12306","title":"G1","from":"SZ","to":"SH","depart":"09:00","arrive":"13:28","duration":"4h28m","price":"","availability":"available","status":"success","detail":"provider row"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });

      expect(doc.source).assertEqual('tool');
      expect(doc.kind).assertEqual('travel');
      expect(doc.blocks.length).assertEqual(1);
      expect(doc.timeline.length).assertEqual(0);
      expect(doc.blocks[0].title).assertEqual('G1');
      expect(doc.blocks[0].source).assertEqual('12306');
      expect(doc.actions[0].id).assertEqual('travel_filter_train');
      expect(JSON.stringify(doc.blocks[0].actions).indexOf('html_pin_travel')).assertLarger(-1);
      expect(doc.blocks[0].actions.length).assertEqual(1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"index":0')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"id":"train-G1"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"source":"train"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"depart":"09:00"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"from":"SZ"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"to":"SH"')).assertLarger(-1);
    });

    it('maps train and flight rows into blocks', 0, () => {
      const action: A2uiAction = {
        id: 'travel_open',
        label: 'Open',
        prompt: 'open travel row',
        variant: 'primary',
        kind: 'prompt'
      };
      const trains: A2uiComponent = {
        id: 'trains',
        component: 'TrainOptions',
        dataPath: '/trains',
        actions: [action]
      };
      const flights: A2uiComponent = {
        id: 'flights',
        component: 'FlightBoard',
        title: '航班结果',
        dataPath: '/flights',
        actions: [action]
      };
      const doc = createHtmlHomeDocument({
        surface: surface('travel', 'ready', [root('trains'), trains, flights],
          '{"trains":[{"trainCode":"G123","from":"深圳北","to":"上海虹桥","depart":"09:00","arrive":"15:30","duration":"6h30m","seats":"二等座有票","status":"available","business":"","first":"2","second":"有","noSeat":"","hardSeat":"","sleeperSoft":""}],"flights":[{"flightNo":"CZ8888","airline":"南方航空","dep":"SZX","arr":"SHA","depTime":"10:20","arrTime":"12:45","status":"scheduled","price":"680"}],"summary":{"text":"北京到上海 2026-07-01 航班结果","toolName":"flight.search","dataLabel":"航班","count":1}}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc);

      expect(doc.kind).assertEqual('travel');
      expect(doc.blocks.length).assertEqual(2);
      expect(doc.timeline.length).assertEqual(0);
      expect(doc.blocks[0].kind).assertEqual('train-option');
      expect(doc.blocks[1].kind).assertEqual('flight-option');
      expect(serialized.indexOf('G123')).assertLarger(-1);
      expect(serialized.indexOf('二等座有票')).assertLarger(-1);
      expect(serialized.indexOf('CZ8888')).assertLarger(-1);
      expect(serialized.indexOf('680')).assertLarger(-1);
      expect(doc.actions[0].id).assertEqual('travel_open');
      expect(doc.blocks[0].actions[0].id).assertEqual('html_pin_train');
      expect(doc.blocks[1].actions[0].id).assertEqual('html_pin_flight');
      expect(JSON.stringify(doc.blocks[0].actions).indexOf('html_pin_train')).assertLarger(-1);
      expect(JSON.stringify(doc.blocks[1].actions).indexOf('html_pin_flight')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"trainCode":"G123"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"depart":"09:00"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"from":"深圳北"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"to":"上海虹桥"')).assertLarger(-1);
      expect(doc.blocks[1].actions[0].prompt.indexOf('"flightNo":"CZ8888"')).assertLarger(-1);
      expect(doc.blocks[1].actions[0].prompt.indexOf('"depTime":"10:20"')).assertLarger(-1);
      expect(doc.blocks[1].actions[0].prompt.indexOf('"dep":"SZX"')).assertLarger(-1);
      expect(doc.blocks[1].actions[0].prompt.indexOf('"arr":"SHA"')).assertLarger(-1);
      expect(doc.blocks[1].prompt).assertEqual('2026-07-01');
    });

    it('drops completed thinking blocks after real results arrive', 0, () => {
      const thinking: A2uiComponent = {
        id: 'thinking',
        component: 'ThinkingStream',
        title: 'AIPhone 正在处理',
        body: '等待工具返回',
        status: 'ready',
        dataPath: '/thoughts'
      };
      const food: A2uiComponent = {
        id: 'food',
        component: 'FoodChoices',
        dataPath: '/foods'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('food', 'ready', [root('food'), thinking, food],
          '{"foods":[{"name":"Coffee","category":"Cafe","address":"Road","distance":"800m","location":"22,113"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc.blocks);

      expect(serialized.indexOf('AIPhone 正在处理')).assertEqual(-1);
      expect(serialized.indexOf('Coffee')).assertLarger(-1);
    });

    it('tolerates partial travel food social rows', 0, () => {
      const emptyAction = {} as A2uiAction;
      const travel: A2uiComponent = {
        id: 'partialTravel',
        component: 'TravelOptions',
        dataPath: '/travelOptions',
        actions: [emptyAction]
      };
      const food: A2uiComponent = {
        id: 'partialFood',
        component: 'FoodChoices',
        dataPath: '/foods',
        actions: [emptyAction]
      };
      const social: A2uiComponent = {
        id: 'partialSocial',
        component: 'SocialInbox',
        dataPath: '/social/messages',
        actions: [emptyAction]
      };
      const doc = createHtmlHomeDocument({
        surface: surface('social', 'ready', [root('partialTravel'), travel, food, social],
          '{"travelOptions":[{}],"foods":[{}],"social":{"messages":[{}]}}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });

      expect(doc.version).assertEqual(1);
      expect(doc.source).assertEqual('tool');
      expect(JSON.stringify(doc).length).assertLarger(0);
    });

    it('adds social select and food map block actions', 0, () => {
      const food: A2uiComponent = {
        id: 'food',
        component: 'FoodChoices',
        dataPath: '/foods'
      };
      const social: A2uiComponent = {
        id: 'social',
        component: 'SocialInbox',
        dataPath: '/social/messages'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('social', 'ready', [root('social'), food, social],
          '{"foods":[{"name":"Coffee","category":"Cafe","address":"Road","distance":"800m","location":"22,113"}],"social":{"messages":[{"id":"msg-1","platform":"wechat","conversationId":"c1","conversationTitle":"Alice","senderName":"Alice","preview":"hi","receivedAt":"now","source":"notification","status":"new"}]}}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc.blocks);

      expect(serialized.indexOf('html_pin_food')).assertLarger(-1);
      expect(serialized.indexOf('html_open_food_map')).assertLarger(-1);
      expect(serialized.indexOf('social_select_message')).assertLarger(-1);
      expect(serialized.indexOf('msg-1')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"name":"Coffee"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"address":"Road"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"location":"22,113"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"distance":"800m"')).assertLarger(-1);
    });

    it('preserves social diagnostics and notification authorization action', 0, () => {
      const social: A2uiComponent = {
        id: 'social',
        component: 'SocialInbox',
        dataPath: '/social/messages'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('social', 'ready', [root('social'), social],
          '{"social":{"messages":[{"id":"msg-1","platform":"wechat","conversationId":"c1","conversationTitle":"Alice","senderName":"Alice","preview":"hi","receivedAt":"now","source":"notification","status":"new"}],"diagnostics":[{"label":"通知桥","value":"未授权"}]}}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc);

      expect(serialized.indexOf('通知桥')).assertLarger(-1);
      expect(serialized.indexOf('未授权')).assertLarger(-1);
      expect(serialized.indexOf('social_open_notification_settings')).assertLarger(-1);
    });

    it('adds Gmail AI reply draft action to real thread result blocks', 0, () => {
      const results: A2uiComponent = {
        id: 'gmail_results',
        component: 'GenericToolResults',
        title: 'Gmail',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('gmail', 'ready', [root('gmail_results'), results],
          '{"genericToolResults":[{"sourceTag":"Gmail API","toolName":"users.threads.get","title":"Admission decision","status":"success","summary":"Committee sent an update.","rows":[{"label":"Thread ID","value":"thread-123"},{"label":"From","value":"Committee <committee@example.edu>"},{"label":"Date","value":"Fri, 26 Jun 2026 09:00:00 +0800"}],"rawPreview":""}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const actions = JSON.stringify(doc.blocks[0].actions);

      expect(doc.kind).assertEqual('gmail');
      expect(doc.blocks[0].kind).assertEqual('generic-tool-result');
      expect(actions.indexOf('gmail.ai.reply.draft')).assertLarger(-1);
      expect(actions.indexOf('AI 回复草稿')).assertLarger(-1);
      expect(actions.indexOf('gmail.draft.create')).assertLarger(-1);
      expect(actions.indexOf('"args"')).assertLarger(-1);
      expect(actions.indexOf('thread-123')).assertLarger(-1);
      expect(actions.indexOf('committee@example.edu')).assertLarger(-1);
    });

    it('adds Gmail draft open action to draft result blocks', 0, () => {
      const results: A2uiComponent = {
        id: 'gmail_results',
        component: 'GenericToolResults',
        title: 'Gmail',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('gmail', 'ready', [root('gmail_results'), results],
          '{"genericToolResults":[{"sourceTag":"Gmail API","toolName":"users.drafts.create","title":"Gmail 草稿已创建","status":"success","summary":"已在真实 Gmail 账号中创建草稿；尚未发送。","rows":[{"label":"Draft ID","value":"draft-123"},{"label":"Thread ID","value":"thread-123"}],"rawPreview":"draftId=draft-123"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const actions = JSON.stringify(doc.blocks[0].actions);

      expect(doc.kind).assertEqual('gmail');
      expect(actions.indexOf('gmail.open.web')).assertLarger(-1);
      expect(actions.indexOf('跳转到Gmail')).assertLarger(-1);
      expect(actions.indexOf('https://mail.google.com/mail/u/0/#drafts')).assertLarger(-1);
    });

    it('maps dynamic tool provider status and source without crashing', 0, () => {
      const connect: A2uiComponent = {
        id: 'connect',
        component: 'ToolConnectCard',
        dataPath: '/dynamicToolConnect'
      };
      const results: A2uiComponent = {
        id: 'results',
        component: 'GenericToolResults',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('dynamic_tool', 'ready', [root('connect'), connect, results],
          '{"dynamicToolConnect":{"toolId":"maps.weather","prompt":"weather now","displayName":"Amap Maps","sourceUrl":"https://provider.example/mcp","status":"needs_auth","message":"API key required","credentialName":"API Key","credentialRef":"dynamic:maps:API Key","actions":[]},"genericToolResults":[{"sourceTag":"MCP fixture","toolName":"fixture.search","title":"Fixture result","status":"success","summary":"One row","rows":[{"label":"Result","value":"Fixture row"}],"rawPreview":"{\\"ok\\":true}"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc);

      expect(doc.source).assertEqual('tool');
      expect(doc.kind).assertEqual('dynamic-tools');
      expect(serialized.indexOf('Amap Maps')).assertLarger(-1);
      expect(serialized.indexOf('needs_auth')).assertLarger(-1);
      expect(serialized.indexOf('https://provider.example/mcp')).assertLarger(-1);
      expect(serialized.indexOf('dynamic:maps:API Key')).assertLarger(-1);
      expect(serialized.indexOf('Fixture row')).assertLarger(-1);
    });
  });
}
