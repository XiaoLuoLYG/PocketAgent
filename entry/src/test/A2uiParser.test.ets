import { describe, it, expect } from '@ohos/hypium';
import { parseA2uiEnvelope, parseA2uiJsonl, parseA2uiJsonlChunk } from '../main/ets/model/A2uiParser';
import { A2uiSurfaceStore } from '../main/ets/model/A2uiSurfaceStore';
import { componentById, labelValues, toolRequest, trainOptions } from '../main/ets/model/A2uiData';
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

    it('stores model requested tool calls in data model', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope('{"createSurface":{"surfaceId":"s","root":"root","title":"测试"}}'));
      store.apply(parseA2uiEnvelope('{"updateDataModel":{"surfaceId":"s","path":"/toolRequest","value":{"toolId":"train.search","prompt":"查高铁","actionId":"model_tool_request"}}}'));

      const request = toolRequest(store.getSurface());
      expect(request.toolId).assertEqual('train.search');
      expect(request.prompt).assertEqual('查高铁');
      expect(request.actionId).assertEqual('model_tool_request');
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
