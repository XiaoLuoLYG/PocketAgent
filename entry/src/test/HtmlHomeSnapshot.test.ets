import { describe, it, expect } from '@ohos/hypium';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { isHtmlHomeActionAllowed } from '../main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy';
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

    it('tolerates partial travel and food rows', 0, () => {
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
      const doc = createHtmlHomeDocument({
        surface: surface('food', 'ready', [root('partialTravel'), travel, food],
          '{"travelOptions":[{}],"foods":[{}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });

      expect(doc.version).assertEqual(1);
      expect(doc.source).assertEqual('tool');
      expect(JSON.stringify(doc).length).assertLarger(0);
    });

    it('adds food map block actions', 0, () => {
      const food: A2uiComponent = {
        id: 'food',
        component: 'FoodChoices',
        dataPath: '/foods'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('food', 'ready', [root('food'), food],
          '{"foods":[{"name":"Coffee","category":"Cafe","address":"Road","distance":"800m","location":"22,113"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc.blocks);

      expect(serialized.indexOf('html_pin_food')).assertLarger(-1);
      expect(serialized.indexOf('html_open_food_map')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"name":"Coffee"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"address":"Road"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"location":"22,113"')).assertLarger(-1);
      expect(doc.blocks[0].actions[0].prompt.indexOf('"distance":"800m"')).assertLarger(-1);
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

    it('adds generic mail AI reply draft action to QQ thread result blocks', 0, () => {
      const results: A2uiComponent = {
        id: 'mail_results',
        component: 'GenericToolResults',
        title: 'Mail',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('mail', 'ready', [root('mail_results'), results],
          '{"genericToolResults":[{"sourceTag":"QQ Mail","toolName":"mail.thread","title":"QQ message","status":"success","summary":"QQ Mail thread retrieved.","rows":[{"label":"Provider","value":"qq"},{"label":"Account","value":"qq-account"},{"label":"Message ID","value":"qq-1"},{"label":"Thread ID","value":"thread-qq-1"},{"label":"From","value":"Sender <sender@example.com>"}],"rawPreview":""}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const actions = JSON.stringify(doc.blocks[0].actions);

      expect(doc.kind).assertEqual('gmail');
      expect(doc.blocks[0].kind).assertEqual('generic-tool-result');
      expect(actions.indexOf('mail.ai.reply.draft')).assertLarger(-1);
      expect(actions.indexOf('AI 回复草稿')).assertLarger(-1);
      expect(actions.indexOf('mail.draft.create')).assertLarger(-1);
      expect(actions.indexOf('"provider":"qq"')).assertLarger(-1);
      expect(actions.indexOf('qq-1')).assertLarger(-1);
      expect(actions.indexOf('sender@example.com')).assertLarger(-1);
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

    it('adds Google Maps open action to real Places result blocks', 0, () => {
      const results: A2uiComponent = {
        id: 'maps_results',
        component: 'GenericToolResults',
        title: 'Google Maps',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('dynamic_tool', 'ready', [root('maps_results'), results],
          '{"genericToolResults":[{"sourceTag":"Google Places API","toolName":"maps.place.search","title":"Coffee Lab","status":"success","summary":"Google Places result for: 深圳咖啡","rows":[{"label":"Place ID","value":"place-123"},{"label":"Map Location","value":"22.609878,114.029506"},{"label":"Maps URL","value":"https://maps.google.com/?cid=123"}],"rawPreview":"placeId=place-123"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const actions = JSON.stringify(doc.blocks[0].actions);

      expect(doc.blocks[0].kind).assertEqual('generic-tool-result');
      expect(actions.indexOf('maps.open.web')).assertLarger(-1);
      expect(actions.indexOf('打开 Google Maps')).assertLarger(-1);
      expect(actions.indexOf('https://maps.google.com/?cid=123')).assertLarger(-1);
    });

    it('captures SocialHub items, connections, and local draft state', 0, () => {
      const hub: A2uiComponent = {
        id: 'social_hub',
        component: 'SocialHub',
        title: '社交工作台',
        dataPath: '/socialHub/items'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('social', 'ready', [root('social_hub'), hub],
          '{"socialHub":{"items":[{"id":"x-1","platform":"x","kind":"post","author":"OpenAI","handle":"@openai","text":"Hello from X","timestamp":"2026-07-01T01:00:00.000Z","url":"https://x.com/openai/status/1","channel":"timeline","threadId":"thread-x-1","unread":true}],"selected":{},"draft":{"itemId":"x-1","platform":"x","text":"Thanks for the update","status":"error","error":"local draft only; not sent","localOnly":true,"sent":false},"connections":[{"platform":"x","status":"connected","displayName":"X","accountId":"openai","message":"X connected"},{"platform":"slack","status":"needs_auth","displayName":"Slack","accountId":"","message":"Slack token required"},{"platform":"wecom","status":"error","displayName":"企业微信","accountId":"corp-1","message":"WeCom callback unavailable"}]}}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const serialized = JSON.stringify(doc);

      expect(doc.kind).assertEqual('social');
      expect(doc.blocks[0].kind).assertEqual('social-hub-item');
      expect(doc.blocks[4].kind).assertEqual('social-hub-draft');
      expect(serialized.indexOf('Hello from X')).assertLarger(-1);
      expect(serialized.indexOf('Thanks for the update')).assertLarger(-1);
      expect(serialized.indexOf('local draft only; not sent')).assertLarger(-1);
      expect(serialized.indexOf('Slack token required')).assertLarger(-1);
      expect(serialized.indexOf('WeCom callback unavailable')).assertLarger(-1);
      expect(serialized.indexOf('social_hub_select_item')).assertLarger(-1);
      expect(serialized.indexOf('social_hub_draft_reply')).assertLarger(-1);
      expect(serialized.indexOf('social_hub_open_source')).assertLarger(-1);
      expect(serialized.indexOf('social_select_message')).assertEqual(-1);
      expect(serialized.indexOf('SocialInbox')).assertEqual(-1);
    });

    it('adds allowed media playback actions to video result blocks', 0, () => {
      const results: A2uiComponent = {
        id: 'media_results',
        component: 'GenericToolResults',
        title: '媒体视频',
        dataPath: '/genericToolResults'
      };
      const pageUrl = 'https://www.bilibili.com/video/BV1h57y6pE5o';
      const doc = createHtmlHomeDocument({
        surface: surface('dynamic_tool', 'ready', [root('media_results'), results],
          '{"genericToolResults":[{"sourceTag":"哔哩哔哩","toolName":"media.video.search","title":"Qwen Max B 站介绍","status":"success","summary":"video result","rows":[{"label":"BVID","value":"BV1h57y6pE5o"},{"label":"Playback URL","value":"https://www.bilibili.com/video/BV1h57y6pE5o"}],"rawPreview":"bvid=BV1h57y6pE5o"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const actions = JSON.stringify(doc.blocks[0].actions);
      const allowed: A2uiAction = {
        id: 'media.open.web',
        label: '跳转',
        prompt: pageUrl,
        variant: 'primary',
        kind: 'client'
      };
      const blocked: A2uiAction = {
        id: 'media.open.web',
        label: '播放',
        prompt: 'https://evil.example/video/7123',
        variant: 'primary',
        kind: 'client'
      };

      expect(doc.kind).assertEqual('media');
      expect(doc.blocks[0].kind).assertEqual('generic-tool-result');
      expect(doc.blocks[0].mediaEmbed?.embedUrl).assertEqual('https://player.bilibili.com/player.html?bvid=BV1h57y6pE5o&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true');
      expect(doc.blocks[0].mediaEmbed?.pageUrl).assertEqual(pageUrl);
      expect(actions.indexOf('media.open.web')).assertLarger(-1);
      expect(actions.indexOf(pageUrl)).assertLarger(-1);
      expect(isHtmlHomeActionAllowed(doc, allowed)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, blocked)).assertFalse();

      const youtubeDoc = createHtmlHomeDocument({
        surface: surface('media', 'ready', [root('media_results'), results],
          '{"genericToolResults":[{"sourceTag":"YouTube Data API","toolName":"media.video.search","title":"Qwen Max YouTube","status":"success","summary":"video result","rows":[{"label":"Video ID","value":"abc123"},{"label":"Watch URL","value":"https://www.youtube.com/watch?v=abc123"}],"rawPreview":"videoId=abc123"}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      expect(youtubeDoc.blocks[0].mediaEmbed?.embedUrl).assertEqual('https://www.youtube.com/embed/abc123?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local');
    });

    it('keeps non-media generic tool results as dynamic tools', 0, () => {
      const results: A2uiComponent = {
        id: 'generic_results',
        component: 'GenericToolResults',
        dataPath: '/genericToolResults'
      };
      const doc = createHtmlHomeDocument({
        surface: surface('dynamic_tool', 'ready', [root('generic_results'), results],
          '{"genericToolResults":[{"sourceTag":"Fixture","toolName":"fixture.search","title":"Plain result","status":"success","summary":"plain","rows":[{"label":"URL","value":"https://example.com/video/not-media"}],"rawPreview":""}]}'),
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });

      expect(doc.kind).assertEqual('dynamic-tools');
      expect(doc.blocks.length).assertEqual(1);
      expect(doc.blocks[0].kind).assertEqual('generic-tool-result');
      expect(doc.blocks[0].mediaEmbed === undefined).assertTrue();
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
