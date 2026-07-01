import { describe, it, expect } from '@ohos/hypium';
import { parseA2uiEnvelope, parseA2uiJsonl, parseA2uiJsonlChunk } from '../main/ets/model/A2uiParser';
import { A2uiSurfaceStore } from '../main/ets/model/A2uiSurfaceStore';
import {
  componentById,
  dynamicToolConnect,
  foodOptions,
  genericToolResults,
  labelValues,
  resolveData,
  toolRequest,
  trainOptions,
  travelOptions
} from '../main/ets/model/A2uiData';
import { SocialHubItemData } from '../main/ets/model/SocialHubTypes';
import {
  appendThinkingStream,
  extractA2uiJsonlFromModelChunk,
  modelThinkCloseSeen,
  normalizeAssistantDebugDisplay,
  parseSseReasoningContent,
  splitModelThinkFromContent
} from '../main/ets/model/LocalModelClient';

export default function a2uiParserTest() {
  describe('a2uiParser', () => {
    it('builds a surface from A2UI JSONL envelopes', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"travel","root":"root","title":"北京到上海","intent":"travel","status":"thinking"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"travel","components":[{"id":"train","component":"TrainOptions","title":"高铁候选","dataPath":"/trains","actions":[{"id":"client_show_more","label":"多展示一些","prompt":"client_show_more","variant":"primary","kind":"client"}]},{"id":"root","component":"SurfaceRoot","child":"train","title":"北京到上海","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"travel","path":"/trains","value":[{"trainCode":"G1","from":"北京南","to":"上海虹桥","depart":"06:30","arrive":"11:24","duration":"04:54","seats":"二等 有","status":"计划","business":"","first":"","second":"有","noSeat":"","hardSeat":"","sleeperSoft":""}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const surface = store.getSurface();
      const train = componentById(surface, 'train');
      expect(parsed.error).assertEqual('');
      expect(surface.surfaceId).assertEqual('travel');
      expect(surface.rootId).assertEqual('root');
      expect(surface.components.length).assertEqual(2);
      expect(train !== null).assertTrue();
      if (train !== null) {
        expect(trainOptions(surface, train)[0].trainCode).assertEqual('G1');
      }
    });

    it('buffers components until root arrives', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"测试"}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"s","components":[{"id":"body","component":"Text","text":"先到达"}]}}'));

      expect(componentById(store.getSurface(), 'root') === null).assertTrue();
      expect(store.getSurface().status).assertEqual('thinking');

      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"SurfaceRoot","child":"body","title":"测试","status":"ready"}]}}'));

      expect(componentById(store.getSurface(), 'root') !== null).assertTrue();
    });

    it('updates nested data model paths', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"测试"}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"SurfaceRoot","child":"info"},{"id":"info","component":"InfoRows","dataPath":"/trip/rows"}]}}'));
      store.apply(parseA2uiEnvelope('{"updateDataModel":{"surfaceId":"s","path":"/trip/rows","value":[{"label":"日期","value":"2026-06-10"}]}}'));

      const info = componentById(store.getSurface(), 'info');
      expect(info !== null).assertTrue();
      if (info !== null) {
        expect(labelValues(store.getSurface(), info)[0].value).assertEqual('2026-06-10');
      }
    });

    it('accepts unified travel options from train and flight sources', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"travel","root":"root","title":"北京到上海出行方案","intent":"travel","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"travel","components":[{"id":"root","component":"SurfaceRoot","child":"options","title":"北京到上海出行方案","status":"ready"},{"id":"options","component":"TravelOptions","title":"推荐方案","dataPath":"/travelOptions","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"travel","path":"/travelOptions","value":[{"id":"train-G1","source":"train","sourceTag":"高铁 · 12306","title":"G1","from":"北京南","to":"上海虹桥","depart":"09:00","arrive":"13:28","duration":"4小时28分","price":"","availability":"二等座有票","status":"success","detail":"设备本机直连 12306 返回"},{"id":"flight-MU5101","source":"flight","sourceTag":"飞机 · 飞常准","title":"MU5101","from":"BJS","to":"SHA","depart":"10:00","arrive":"12:10","duration":"","price":"¥680","availability":"","status":"计划","detail":"设备本机直连飞常准返回"}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const surface = store.getSurface();
      const options = componentById(surface, 'options');
      expect(parsed.error).assertEqual('');
      expect(options !== null).assertTrue();
      expect(surface.dataModelJson.indexOf('高铁 · 12306')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('飞机 · 飞常准')).assertLarger(-1);
      if (options !== null) {
        expect(travelOptions(surface, options)[0].sourceTag).assertEqual('高铁 · 12306');
        expect(travelOptions(surface, options)[1].sourceTag).assertEqual('飞机 · 飞常准');
      }
    });

    it('preserves food source tags for aggregated delivery results', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"food","root":"root","title":"外卖聚合","intent":"food","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"food","components":[{"id":"root","component":"SurfaceRoot","child":"foods","title":"外卖聚合","status":"ready"},{"id":"foods","component":"FoodChoices","title":"聚合结果","dataPath":"/foods","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"food","path":"/foods","value":[{"name":"茶百道","category":"奶茶","address":"南山科技园","distance":"120米","sourceTags":["高德","美团","淘宝闪购"]}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const surface = store.getSurface();
      const foods = componentById(surface, 'foods');
      expect(parsed.error).assertEqual('');
      expect(foods !== null).assertTrue();
      if (foods !== null) {
        const firstFood = foodOptions(surface, foods)[0];
        const tags: string[] = firstFood.sourceTags === undefined ? [] : firstFood.sourceTags;
        expect(tags[0]).assertEqual('高德');
        expect(tags[2]).assertEqual('淘宝闪购');
      }
    });

    it('stores model requested tool calls in data model', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"测试"}}'));
      store.apply(parseA2uiEnvelope('{"updateDataModel":{"surfaceId":"s","path":"/toolRequest","value":{"toolId":"train.search","prompt":"查高铁","actionId":"model_tool_request"}}}'));

      const request = toolRequest(store.getSurface());
      expect(request.toolId).assertEqual('train.search');
      expect(request.prompt).assertEqual('查高铁');
      expect(request.actionId).assertEqual('model_tool_request');
    });

    it('recovers model tool request args from compact single-object output', 0, () => {
      const compact =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"main","root":"root","title":"正在搜索 Gmail","intent":"gmail","status":"calling_tool","sendDataModel":true},"updateComponents":{"components":{"root":{"component":"SurfaceRoot","child":"thinking"}}},"updateDataModel":{"path":"/thoughts","merge":[["正在补充英文邮件关键词"]]},"updateDataModel":{"path":"/toolRequest","merge":[{"toolId":"gmail.mail.search","prompt":"帮我用 Gmail 搜索最近和我论文相关的邮件，帮我查看录取结果","actionId":"model_tool_request","args":{"query":"newer_than:365d {\\"paper\\" \\"manuscript\\" \\"submission\\" \\"admission decision\\" \\"decision letter\\" \\"offer letter\\" \\"accepted\\"} -category:promotions -in:draft","pageSize":10}}]}}';
      const extracted = extractA2uiJsonlFromModelChunk(compact + '\n');
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const argsJson = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.mail.search');
      expect(argsJson.indexOf('paper')).assertLarger(-1);
      expect(argsJson.indexOf('admission decision')).assertLarger(-1);
    });

    it('recovers model tool request args from updateDataModel toolRequest output', 0, () => {
      const compact =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"gmail-reply","root":"root","title":"正在创建 Gmail 回复草稿","intent":"gmail","status":"calling_tool","sendDataModel":false},"updateComponents":{"components":{"root":{"component":"SurfaceRoot","child":"thinking"},"thinking":{"component":"ThinkingStream","title":"Appless Phone 正在处理","body":"正在为选中的 Gmail 线程生成回复正文","status":"calling_tool","dataPath":"/thoughts"}}},"updateDataModel":{"/thoughts":["正在读取按钮携带的真实线程上下文"]},"updateDataModel":{"toolRequest":{"toolId":"gmail.draft.create","prompt":"Create a Gmail reply draft for the selected thread","actionId":"model_tool_request","args":{"threadId":"thread-123","to":["committee@example.edu"],"subject":"Re: Admission decision","body":"Thanks for the update.","replyMode":"reply"}}}}';
      const extracted = extractA2uiJsonlFromModelChunk(compact + '\n');
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const argsJson = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.draft.create');
      expect(argsJson.indexOf('thread-123')).assertLarger(-1);
      expect(argsJson.indexOf('committee@example.edu')).assertLarger(-1);
      expect(argsJson.indexOf('Thanks for the update.')).assertLarger(-1);
    });

    it('recovers a single updateDataModel toolRequest envelope before strict parsing', 0, () => {
      const compact =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_model","toolRequest":{"toolId":"gmail.draft.create","prompt":"Create a Gmail reply draft for the selected thread","actionId":"model_tool_request","args":{"threadId":"thread-789","to":["committee@example.edu"],"subject":"Re: Admission decision","body":"Thank you for letting me know.","replyMode":"reply"}}}}';
      const extracted = extractA2uiJsonlFromModelChunk(compact + '\n');
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const argsJson = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.draft.create');
      expect(argsJson.indexOf('thread-789')).assertLarger(-1);
      expect(argsJson.indexOf('Thank you for letting me know.')).assertLarger(-1);
    });

    it('recovers shorthand Gmail draft form updates from model output', 0, () => {
      const compact =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"main","root":"root","title":"写邮件","intent":"gmail","status":"ready","sendDataModel":{"toolId":"gmail.draft.create"}}}\n' +
        '{"version":"v0.9.1","updateComponents":{"components":{"root":{"component":"SurfaceRoot","child":"draftForm"},"draftForm":{"component":"Column","children":["toField","subjectField","bodyField"]},"toField":{"component":"Text","text":"To"},"subjectField":{"component":"Text","text":"Subject"},"bodyField":{"component":"Text","text":"Body"}}}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"/form/to":["alice@example.com"]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"/form/body":"我收到了"}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"/form/subject":"邮件确认"}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(compact);
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const dataModelJson = store.getSurface().dataModelJson;

      expect(parsed.error).assertEqual('');
      expect(dataModelJson.indexOf('alice@example.com')).assertLarger(-1);
      expect(dataModelJson.indexOf('我收到了')).assertLarger(-1);
      expect(dataModelJson.indexOf('邮件确认')).assertLarger(-1);
    });

    it('recovers model tool request args from top-level toolRequest output', 0, () => {
      const compact =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"gmail-reply","root":"root","title":"正在创建 Gmail 回复草稿","intent":"gmail","status":"calling_tool","sendDataModel":false},"updateComponents":{"components":{"root":{"component":"SurfaceRoot","child":"thinking"}}},"updateDataModel":{"path":"/thoughts","value":["正在撰写回复"]},"toolRequest":{"toolId":"gmail.draft.create","prompt":"Create a Gmail reply draft for the selected thread","actionId":"model_tool_request","args":{"threadId":"thread-456","to":["advisor@example.edu"],"subject":"Re: Manuscript review","body":"Thank you for the guidance.","replyMode":"reply"}}}';
      const extracted = extractA2uiJsonlFromModelChunk(compact + '\n');
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const argsJson = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.draft.create');
      expect(argsJson.indexOf('thread-456')).assertLarger(-1);
      expect(argsJson.indexOf('advisor@example.edu')).assertLarger(-1);
      expect(argsJson.indexOf('Thank you for the guidance.')).assertLarger(-1);
    });

    it('recovers model tool request args nested in createSurface sendDataModel', 0, () => {
      const compact =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"main","root":"root","title":"撰写 Gmail 邮件","intent":"gmail","status":"ready","sendDataModel":{"/thoughts":"正在准备撰写 Gmail 邮件","/toolRequest":{"toolId":"gmail.draft.create","prompt":"帮我写一封邮件给 alice@example.com 说我收到了","actionId":"model_tool_request","args":{"to":["alice@example.com"],"subject":"邮件主题","body":"我收到了","replyMode":"single"}}}}}';
      const extracted = extractA2uiJsonlFromModelChunk(compact + '\n');
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const argsJson = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.draft.create');
      expect(argsJson.indexOf('alice@example.com')).assertLarger(-1);
      expect(argsJson.indexOf('我收到了')).assertLarger(-1);
      expect(argsJson.indexOf('single')).assertLarger(-1);
    });

    it('accepts dynamic tool components and stores dynamic tool data', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"dynamic","root":"root","title":"动态工具","intent":"dynamic_tool","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"dynamic","components":[{"id":"root","component":"SurfaceRoot","children":["connect","results"],"title":"动态工具","status":"ready"},{"id":"connect","component":"ToolConnectCard","title":"Amap Maps","dataPath":"/dynamicToolConnect","status":"needs_auth"},{"id":"results","component":"GenericToolResults","title":"工具结果","dataPath":"/genericToolResults","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"dynamic","path":"/dynamicToolConnect","value":{"toolId":"maps.weather","manifestId":"modelscope.@amap.amap-maps","displayName":"Amap Maps","sourceUrl":"https://modelscope.cn/mcp/servers/%40amap/amap-maps","status":"needs_auth","message":"API key required","credentialName":"AMAP_MAPS_API_KEY","credentialRef":"dynamic:modelscope.@amap.amap-maps:AMAP_MAPS_API_KEY","registrationUrl":"https://lbs.amap.com/","actions":[]}}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"dynamic","path":"/genericToolResults","value":[{"sourceTag":"MCP · fixture","toolName":"fixture.search","title":"Fixture result","status":"success","summary":"One real fixture row returned.","rows":[{"label":"Result","value":"Fixture row"}],"rawPreview":"{\\"ok\\":true}"}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const surface = store.getSurface();
      expect(parsed.error).assertEqual('');
      expect(componentById(surface, 'connect')?.component).assertEqual('ToolConnectCard');
      expect(componentById(surface, 'results')?.component).assertEqual('GenericToolResults');
      expect(dynamicToolConnect(surface).credentialName).assertEqual('AMAP_MAPS_API_KEY');
      expect(genericToolResults(surface)[0].rows[0].value).assertEqual('Fixture row');
    });

    it('normalizes partial dynamic tool result data for renderer safety', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"dynamic-partial","root":"root","title":"动态工具","intent":"dynamic_tool","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"dynamic-partial","components":[{"id":"root","component":"SurfaceRoot","child":"results","title":"动态工具","status":"ready"},{"id":"results","component":"GenericToolResults","title":"工具结果","dataPath":"/genericToolResults","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"dynamic-partial","path":"/genericToolResults","value":[{"title":"Partial result","rows":[{"label":"Only label"},{}]}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const results = genericToolResults(store.getSurface());
      expect(parsed.error).assertEqual('');
      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('Partial result');
      expect(results[0].sourceTag).assertEqual('');
      expect(results[0].summary).assertEqual('');
      expect(results[0].rawPreview).assertEqual('');
      expect(results[0].rows.length).assertEqual(1);
      expect(results[0].rows[0].label).assertEqual('Only label');
      expect(results[0].rows[0].value).assertEqual('');
    });

    it('rejects the removed SocialInbox component', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"social","root":"root","title":"社交收件箱","intent":"social","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"social","components":[{"id":"root","component":"SurfaceRoot","child":"inbox","title":"社交收件箱","status":"ready"},{"id":"inbox","component":"SocialInbox","title":"微信消息","dataPath":"/social/messages","status":"ready"}]}}\n';
      const parsed = parseA2uiJsonl(stream);

      expect(parsed.error.indexOf('SocialInbox')).assertLarger(-1);
    });

    it('accepts SocialHub components bound to socialHub items', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"social-hub","root":"root","title":"Social Hub","intent":"social","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"social-hub","components":[{"id":"root","component":"SurfaceRoot","child":"hub","title":"Social Hub","status":"ready"},{"id":"hub","component":"SocialHub","title":"Social Hub","dataPath":"/socialHub/items","status":"ready"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"social-hub","path":"/socialHub/items","value":[{"id":"slack-1","platform":"slack","kind":"message","author":"Lin","text":"standup moved","channel":"#core"}]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const hub = componentById(store.getSurface(), 'hub');
      const items = resolveData(store.getSurface(), '/socialHub/items') as SocialHubItemData[];
      expect(parsed.error).assertEqual('');
      expect(hub !== null).assertTrue();
      expect(items.length).assertEqual(1);
      expect(items[0].platform).assertEqual('slack');
      expect(items[0].text).assertEqual('standup moved');
    });

    it('extracts model A2UI from think blocks and markdown fences', 0, () => {
      const content =
        '<think>private reasoning</think>\n' +
        '```json\n' +
        '{"version":"v0.9.1","createSurface":{"surfaceId":"s","root":"root","title":"你好"}}\n' +
        '```\n' +
        'done\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(extracted.jsonl.indexOf('<think>')).assertEqual(-1);
      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(1);
    });

    it('streams model think tags separately from A2UI content', 0, () => {
      const first = splitModelThinkFromContent('<think>正在分析路', false, '');
      const second = splitModelThinkFromContent('线</think>\n{"version":"v0.9.1","createSurface":{"surfaceId":"s","root":"root","title":"你好"}}\n', first.inThink, first.tagRemainder);
      const extracted = extractA2uiJsonlFromModelChunk(first.content + second.content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(first.think).assertEqual('正在分析路');
      expect(second.think).assertEqual('线');
      expect(second.content.indexOf('<think>')).assertEqual(-1);
      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(1);
    });

    it('extracts think blocks from qwen think tags', 0, () => {
      const openTag = '<' + 'think' + '>';
      const closeTag = '</' + 'think' + '>';
      const split = splitModelThinkFromContent(openTag + '正在确认工具' + closeTag + '\n{"version":"v0.9.1"}');

      expect(split.think).assertEqual('正在确认工具');
      expect(split.content.indexOf('{"version"')).assertLarger(-1);
      expect(split.inThink).assertFalse();
    });

    it('normalizes flat model A2UI objects after a qwen close think tag', 0, () => {
      const content =
        '</think>\n\n' +
        '{"version":"v0.9.1","surfaceId":"main","root":"main-root","title":"欢迎消息","intent":"greeting","status":"ready","sendDataModel":{"path":"/greeting","value":{"content":"您好"}}}\n' +
        '{"version":"v0.9.1","surfaceId":"main","root":"main-root","component":"InfoRows","title":"问候信息","dataPath":"/greeting","status":"ready","actions":[]}\n';
      const split = splitModelThinkFromContent(content);
      const extracted = extractA2uiJsonlFromModelChunk(split.content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertLarger(2);
      expect(parsed.envelopes[0].createSurface?.surfaceId).assertEqual('main');
      expect(parsed.envelopes[1].updateDataModel?.path).assertEqual('/greeting');
      expect(parsed.envelopes[2].updateComponents?.components[0].id).assertEqual('main-root');
    });

    it('unwraps model A2UI content envelopes', 0, () => {
      const content =
        '{"version":"v0.9.1","content":{"createSurface":{"surfaceId":"main","root":"root","title":"查看最近重要邮件","intent":"gmail","status":"calling_tool"}}}\n' +
        '{"version":"v0.9.1","content":{"updateDataModel":{"/toolRequest":{"toolId":"gmail.mail.search","prompt":"帮我看 Gmail 里最新的重要邮件","actionId":"model_tool_request","args":{"query":"is:important newer_than:30d","pageSize":10}}}}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes[0].createSurface?.surfaceId).assertEqual('main');
      expect(parsed.envelopes[1].updateDataModel?.path).assertEqual('/toolRequest');
    });

    it('rebuilds split sendDataModel toolRequest and args from compact model output', 0, () => {
      const content =
        '{"createSurface":{"surfaceId":"surface_model","root":"SurfaceRoot","title":"搜索Gmail邮件","intent":"gmail","status":"calling_tool","sendDataModel":{"/thoughts":"开始处理用户的Gmail搜索请求","/toolRequest":"gmail.mail.search","/args":{"query":"newer_than:365d {\\"eccv\\" \\"ECCV\\" \\"论文\\"} -category:promotions -in:draft","pageSize":10,"intentSummary":"搜索最近与ECCV论文相关的Gmail邮件"}}}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const serializedArgs = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.mail.search');
      expect(request.actionId).assertEqual('model_tool_request');
      expect(serializedArgs.indexOf('ECCV')).assertLarger(-1);
      expect(serializedArgs.indexOf('pageSize')).assertLarger(-1);
    });

    it('recovers Gmail query from compact model output that misplaced args in rows text', 0, () => {
      const content =
        '{"createSurface":{"surfaceId":"surface_model","root":"SurfaceRoot","title":"搜索Gmail邮件","intent":"gmail","status":"calling_tool","sendDataModel":{"/thoughts":"开始处理用户的Gmail搜索请求","/toolRequest":"gmail.mail.search","/rows":"[{\'query\':\'newer_than:365d {\\"eccv\\" \\"ECCV\\" \\"提交论文\\"}\\" -category:promotions -in:draft\'}]"}}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const serializedArgs = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.mail.search');
      expect(serializedArgs.indexOf('ECCV')).assertLarger(-1);
      expect(serializedArgs.indexOf('newer_than:365d')).assertLarger(-1);
    });

    it('preserves tool args from flat compact surface sendDataModel output', 0, () => {
      const content =
        '{"surfaceId":"surface_model","root":"root","title":"正在搜索 Gmail","intent":"gmail","status":"calling_tool","sendDataModel":{"/toolRequest":{"toolId":"gmail.mail.search","args":{"query":"newer_than:365d {\\"ECCV\\" \\"European Conference on Computer Vision\\" \\"论文提交\\"} -category:promotions -in:draft","pageSize":20}}}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });
      const request = toolRequest(store.getSurface());
      const serializedArgs = JSON.stringify(request.args);

      expect(parsed.error).assertEqual('');
      expect(request.toolId).assertEqual('gmail.mail.search');
      expect(request.prompt.length).assertEqual(0);
      expect(request.actionId.length).assertEqual(0);
      expect(serializedArgs.indexOf('European Conference on Computer Vision')).assertLarger(-1);
      expect(serializedArgs.indexOf('"pageSize":20')).assertLarger(-1);
    });

    it('detects redacted thinking close tag', 0, () => {
      expect(modelThinkCloseSeen('分析完成</think>\n{"version":"v0.9.1"}')).assertTrue();
      expect(modelThinkCloseSeen('还在思考中')).assertFalse();
    });

    it('appends thinking stream without truncating to summaries', 0, () => {
      let thoughts = appendThinkingStream([], '正在分析');
      thoughts = appendThinkingStream(thoughts, '用户请求');
      thoughts = appendThinkingStream(thoughts, '并准备生成 A2UI');

      expect(thoughts.length).assertEqual(1);
      expect(thoughts[0]).assertEqual('正在分析用户请求并准备生成 A2UI');
    });

    it('extracts OpenAI reasoning content from SSE chunks', 0, () => {
      const chunk = 'data: {"choices":[{"delta":{"reasoning_content":"正在确认查询条件"}}]}\n\n' +
        'data: {"choices":[{"delta":{"content":"{\\"version\\":\\"v0.9.1\\"}"}}]}\n\n';

      expect(parseSseReasoningContent(chunk)).assertEqual('正在确认查询条件');
    });

    it('extracts JSON objects even when the model splits them across lines', 0, () => {
      const content =
        '{"version":"v0.9.1","createSurface":{\n' +
        '"surfaceId":"s","root":"root","title":"你好","intent":"general","status":"ready","sendDataModel":true}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(1);
      expect(parsed.envelopes[0].createSurface?.surfaceId).assertEqual('s');
    });

    it('recovers later complete envelopes after a malformed model object', 0, () => {
      const content =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"s","root":"root","title":"AIPhone","status":"ready","send\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"SurfaceRoot","child":"hello"},{"id":"hello","component":"Text","text":"你好"}]}}\n';
      const extracted = extractA2uiJsonlFromModelChunk(content);
      const parsed = parseA2uiJsonl(extracted.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(1);
      expect(parsed.envelopes[0].updateComponents?.surfaceId).assertEqual('s');
    });

    it('rejects unknown components', 0, () => {
      const parsed = parseA2uiJsonl('{"updateComponents":{"surfaceId":"s","components":[{"id":"html","component":"HtmlWidget"}]}}\n');

      expect(parsed.error.length > 0).assertTrue();
    });

    it('accepts ThinkingCard component', 0, () => {
      const stream =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"thinking","root":"root","title":"思考中","status":"thinking"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"thinking","components":[{"id":"root","component":"SurfaceRoot","child":"think","status":"thinking"},{"id":"think","component":"ThinkingCard","title":"正在理解你的请求","body":"思考流写入中","status":"thinking","dataPath":"/thoughts"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"thinking","path":"/thoughts","value":["正在拆解请求"]}}\n';
      const parsed = parseA2uiJsonl(stream);
      const store = new A2uiSurfaceStore();

      parsed.envelopes.forEach(envelope => {
        store.apply(envelope);
      });

      const surface = store.getSurface();
      expect(parsed.error).assertEqual('');
      expect(surface.components.length).assertEqual(2);
      expect(componentById(surface, 'think')?.component).assertEqual('ThinkingCard');
    });

    it('rejects old aiphone ui envelopes', 0, () => {
      const parsed = parseA2uiJsonl('{"version":"aiphone.ui.v2","surface":{"id":"old"}}\n');

      expect(parsed.error.length > 0).assertTrue();
    });

    it('keeps partial JSONL remainder for streaming chunks', 0, () => {
      const first = parseA2uiJsonlChunk('{"createSurface":{"surfaceId":"s"', '');

      expect(first.envelopes.length).assertEqual(0);
      expect(first.remainder.length > 0).assertTrue();

      const second = parseA2uiJsonlChunk(',"root":"root"}}\n', first.remainder);
      expect(second.envelopes.length).assertEqual(1);
      expect(second.remainder).assertEqual('');
      expect(second.error).assertEqual('');
    });

    it('keeps longer thoughts when tool stub tries to overwrite', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"Test"}}'));
      store.apply(parseA2uiEnvelope(
        '{"updateDataModel":{"surfaceId":"s","path":"/thoughts","value":["用户需要查询明天北京到上海高铁票，并准备调用 train.search"]}}'
      ));
      store.apply(parseA2uiEnvelope(
        '{"updateDataModel":{"surfaceId":"s","path":"/thoughts","value":["正在识别请求约束","正在等待 12306 返回"]}}'
      ));

      expect(store.getSurface().dataModelJson.indexOf('用户需要查询明天北京到上海高铁票')).assertLarger(-1);
    });

    it('preserves thoughts when createSurface switches surfaceId', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"surface_model_thinking","root":"root","title":"思考中","status":"thinking"}}'
      ));
      store.apply(parseA2uiEnvelope(
        '{"updateDataModel":{"surfaceId":"surface_model_thinking","path":"/thoughts","value":["正在分析用户请求"]}}'
      ));
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"surface_model","root":"root","title":"正在准备查询","status":"calling_tool"}}'
      ));

      const surface = store.getSurface();
      expect(surface.surfaceId).assertEqual('surface_model');
      expect(surface.dataModelJson.indexOf('正在分析用户请求')).assertLarger(-1);
    });

    it('merges createSurface on same surfaceId without clearing components', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"First","status":"thinking"}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"SurfaceRoot","child":"body","title":"First","status":"ready"},{"id":"body","component":"Text","text":"hello","status":"ready"}]}}'));
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"Second","status":"ready"}}'));

      const surface = store.getSurface();
      expect(surface.title).assertEqual('Second');
      expect(surface.components.length).assertEqual(2);
      expect(componentById(surface, 'body') !== null).assertTrue();
    });

    it('clears stale thoughts when a same-surface request starts a new data model', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"surface_model","root":"root","title":"旧工具","status":"ready","sendDataModel":true}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"surface_model","components":[{"id":"root","component":"SurfaceRoot","child":"thinking","title":"旧工具","status":"ready"},{"id":"thinking","component":"ThinkingStream","title":"旧工具","dataPath":"/thoughts","status":"ready"}]}}'));
      store.apply(parseA2uiEnvelope(
        '{"updateDataModel":{"surfaceId":"surface_model","path":"/thoughts","value":["正在识别出行约束","正在等待 12306 和飞常准返回一段更长的旧文案"]}}'
      ));

      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"surface_model","root":"root","title":"正在搜索外卖","status":"calling_tool","sendDataModel":true}}'));
      store.apply(parseA2uiEnvelope(
        '{"updateDataModel":{"surfaceId":"surface_model","path":"/thoughts","value":["正在等待外卖来源返回"]}}'
      ));

      const surface = store.getSurface();
      expect(surface.dataModelJson.indexOf('外卖来源')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('12306')).assertEqual(-1);
      expect(surface.dataModelJson.indexOf('飞常准')).assertEqual(-1);
    });

    it('keeps food results when a same-surface partial stream changes status to ready', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"surface_food","root":"root","title":"外卖聚合搜索","intent":"food","status":"calling_tool","sendDataModel":true}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"surface_food","components":[{"id":"root","component":"SurfaceRoot","child":"results","title":"外卖聚合搜索","status":"calling_tool"},{"id":"results","component":"FoodChoices","title":"外卖聚合搜索","dataPath":"/foods","status":"calling_tool"}]}}'));
      store.apply(parseA2uiEnvelope('{"updateDataModel":{"surfaceId":"surface_food","path":"/foods","value":[{"name":"坂田基地咖啡店","category":"咖啡","address":"深圳坂田基地附近","distance":"300米","sourceTags":["高德"]}]}}'));

      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"surface_food","root":"root","title":"外卖聚合搜索","intent":"food","status":"ready","sendDataModel":true}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"surface_food","components":[{"id":"root","component":"SurfaceRoot","child":"results","title":"外卖聚合搜索","status":"ready"},{"id":"results","component":"FoodChoices","title":"外卖聚合搜索","dataPath":"/foods","status":"ready"}]}}'));

      const surface = store.getSurface();
      const food = componentById(surface, 'results');
      expect(food !== null).assertTrue();
      if (food !== null) {
        expect(foodOptions(surface, food)[0].name).assertEqual('坂田基地咖啡店');
      }
    });

    it('apply failure does not wipe existing surface state', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"Test"}}'));
      store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"SurfaceRoot","child":"body","title":"Test","status":"ready"},{"id":"body","component":"Text","text":"keep","status":"ready"}]}}'));
      const failed = store.apply(parseA2uiEnvelope('{"updateComponents":{"surfaceId":"wrong","components":[{"id":"x","component":"Text","text":"x"}]}}'));

      expect(failed.ok).assertFalse();
      expect(store.getSurface().surfaceId).assertEqual('s');
      expect(store.getSurface().components.length).assertEqual(2);
    });

    it('normalizes assistant debug when opening think tag is missing', 0, () => {
      const raw = '正在确认出行日期</think>\n{"version":"v0.9.1"}\n';
      const normalized = normalizeAssistantDebugDisplay(raw);

      expect(normalized.indexOf('<think>')).assertEqual(0);
      expect(normalized.indexOf('</think>')).assertLarger(0);
    });
  });
}
