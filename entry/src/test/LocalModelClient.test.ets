import { describe, it, expect } from '@ohos/hypium';
import { buildChatCompletionsUrl, resolveSystemPrompt } from '../main/ets/model/LocalModelClient';
import { configureLocalModelSettingsFromRawJson, defaultLocalModelSettings } from '../main/ets/model/LocalModelSettings';

export default function localModelClientTest() {
  describe('localModelClient', () => {
    it('uses the same system prompt for every user query', 0, () => {
      const baseline = resolveSystemPrompt('');
      expect(baseline.length > 0).assertTrue();
      expect(baseline.indexOf('A2UI v0.9.1 JSONL') >= 0).assertTrue();
      expect(baseline.indexOf('示例 A，寒暄') >= 0).assertTrue();
      expect(baseline.indexOf('示例 B，实时查高铁') >= 0).assertTrue();
      expect(baseline.indexOf('示例 C，非实时整理规划思路') >= 0).assertTrue();
      expect(baseline.indexOf('示例 E，查看 Gmail') >= 0).assertTrue();
      expect(baseline.indexOf('示例 H，Gmail 学术复合搜索') >= 0).assertTrue();
      expect(baseline.indexOf('示例 G，Gmail AI 回复草稿') >= 0).assertTrue();
      expect(baseline.indexOf('麦当劳官方 MCP 查询结果') >= 0).assertTrue();
      expect(baseline.indexOf('禁止创建订单、支付、自动领券') >= 0).assertTrue();
      expect(baseline.indexOf('gmail.mail.search|gmail.thread.read|gmail.draft.create|gmail.draft.apply|gmail.open.web|gmail.message.send') >= 0).assertTrue();
      expect(baseline.indexOf('calendar.events.search|calendar.event.create|calendar.event.update')).assertLarger(-1);
      expect(baseline.indexOf('maps.place.search|maps.place.details')).assertLarger(-1);
      expect(baseline.indexOf('calendar.event.delete')).assertEqual(-1);
      expect(baseline.indexOf('maps.route.plan')).assertEqual(-1);
      expect(baseline.indexOf('模型阶段禁止编造 Gmail 邮件') >= 0).assertTrue();
      expect(baseline.indexOf('media.video.search')).assertLarger(-1);
      expect(baseline.indexOf('youtube.video.search')).assertLarger(-1);
      expect(baseline.indexOf('YouTube')).assertLarger(-1);
      expect(baseline.indexOf('B 站')).assertLarger(-1);
      expect(baseline.indexOf('模型阶段禁止编造 YouTube、B 站或媒体聚合视频')).assertLarger(-1);
      expect(baseline.indexOf('args.sources')).assertLarger(-1);
      expect(baseline.indexOf('同一句同时出现 YouTube/油管 和 B站/Bilibili/哔哩哔哩')).assertLarger(-1);
      expect(baseline.indexOf('模型阶段禁止编造 Google Calendar 日程')).assertLarger(-1);
      expect(baseline.indexOf('Google Maps 搜索')).assertLarger(-1);
      expect(baseline.indexOf('dynamic.search|mail.search|mail.thread.read|mail.draft.create|gmail.mail.search') >= 0).assertTrue();
      expect(baseline.indexOf('youtube.video.search|youtube.mine.playlists|youtube.mine.subscriptions')).assertLarger(-1);
      expect(baseline.indexOf('"args"') >= 0).assertTrue();
      expect(baseline.indexOf('Mail/Gmail 查询必须由你生成 args.query') >= 0).assertTrue();
      expect(baseline.indexOf('YouTube 搜索必须由你生成 args.query') >= 0).assertTrue();
      expect(baseline.indexOf('通用邮箱能力使用 mail.search') >= 0).assertTrue();
      expect(baseline.indexOf('用户只说邮件或收件箱时选择 mail.search') >= 0).assertTrue();
      expect(baseline.indexOf('mail.search|mail.thread.read|mail.draft.create') >= 0).assertTrue();
      expect(baseline.indexOf('gmail.ai.reply.draft') >= 0).assertTrue();
      expect(baseline.indexOf('Thanks for sharing the update.')).assertLarger(-1);
      expect(baseline.indexOf('客户端禁止把论文、录取、导师等词写成本地规则') >= 0).assertTrue();
      expect(baseline.indexOf('中文意图必须扩展英文同义词')).assertLarger(-1);
      expect(baseline.indexOf('manuscript')).assertLarger(-1);
      expect(baseline.indexOf('submission')).assertLarger(-1);
      expect(baseline.indexOf('decision letter')).assertLarger(-1);
      expect(baseline.indexOf('offer letter')).assertLarger(-1);
      expect(baseline.indexOf('admitted')).assertLarger(-1);
      expect(baseline.indexOf('camera-ready')).assertLarger(-1);
      expect(baseline.indexOf('\\"paper\\"')).assertLarger(-1);
      expect(baseline.indexOf('\\"admission decision\\"')).assertLarger(-1);
      expect(baseline.indexOf('不要把所有示例词都塞进同一个查询')).assertLarger(-1);
      expect(baseline.indexOf('帮我搜索最近和我论文相关的邮件，帮我查看录取结果')).assertEqual(-1);
      expect(resolveSystemPrompt('你好')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我查明天北京到上海高铁票')).assertEqual(baseline);
      expect(resolveSystemPrompt('帮我看 Gmail 里最新的重要邮件')).assertEqual(baseline);
      expect(resolveSystemPrompt('我想明天从北京去上海，帮我整理可查的出行选项')).assertEqual(baseline);
    });

    it('builds DashScope compatible chat completion URLs without double appending paths', 0, () => {
      expect(buildChatCompletionsUrl('https://dashscope.aliyuncs.com/compatible-mode/v1')).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(buildChatCompletionsUrl('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions')).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
    });

    it('defaults to DashScope qwen-max and reads its local rawfile key', 0, () => {
      configureLocalModelSettingsFromRawJson('{"DASHSCOPE_API_KEY":"test-key"}');
      const settings = defaultLocalModelSettings();
      expect(settings.provider).assertEqual('DashScope');
      expect(settings.baseUrl).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(settings.model).assertEqual('qwen-max');
      expect(settings.apiKey).assertEqual('test-key');
      expect(settings.customParametersJson).assertEqual('{"enable_thinking":false}');
      configureLocalModelSettingsFromRawJson('{}');
    });
  });
}
