import { describe, it, expect } from '@ohos/hypium';
import {
  AccessibilityIngestProvider,
  NotificationIngestProvider,
  SocialMessageStore,
  WechatReplyAutomation,
  buildSocialDiagnosticsRows,
  probeSocialCapabilities
} from '../main/ets/model/SocialBridge';

export default function socialBridgeTest() {
  describe('socialBridge', () => {
    it('keeps only real captured social messages and deduplicates repeats', 0, () => {
      const store = new SocialMessageStore(24 * 60 * 60 * 1000, 3);
      const first = store.ingest({
        platform: 'wechat',
        conversationTitle: 'Alice',
        senderName: 'Alice',
        preview: '晚上一起吃饭吗',
        receivedAt: '2026-06-11T08:30:00.000Z',
        source: 'notification'
      });
      const duplicate = store.ingest({
        platform: 'wechat',
        conversationTitle: 'Alice',
        senderName: 'Alice',
        preview: '晚上一起吃饭吗',
        receivedAt: '2026-06-11T08:30:20.000Z',
        source: 'notification'
      });

      expect(first.accepted).assertTrue();
      expect(duplicate.accepted).assertFalse();
      expect(store.messages()[0].id).assertEqual(first.message.id);
      expect(store.messages().length).assertEqual(1);
    });

    it('evicts old and overflow messages from local short term storage', 0, () => {
      const store = new SocialMessageStore(60 * 1000, 2);
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'Old',
        senderName: 'Old',
        preview: '过期消息',
        receivedAt: '2026-06-11T08:00:00.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:00.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'A',
        senderName: 'A',
        preview: '第一条',
        receivedAt: '2026-06-11T08:02:01.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:01.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'B',
        senderName: 'B',
        preview: '第二条',
        receivedAt: '2026-06-11T08:02:02.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:02.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'C',
        senderName: 'C',
        preview: '第三条',
        receivedAt: '2026-06-11T08:02:03.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:03.000Z');

      expect(store.messages().length).assertEqual(2);
      expect(store.messages()[0].conversationTitle).assertEqual('C');
      expect(store.messages()[1].conversationTitle).assertEqual('B');
    });

    it('reports unavailable ingest providers without creating synthetic messages', 0, () => {
      const notification = new NotificationIngestProvider(false, '缺少通知控制权限');
      const accessibility = new AccessibilityIngestProvider(false, '辅助权限未授权');

      expect(notification.capture().messages.length).assertEqual(0);
      expect(notification.capture().ok).assertFalse();
      expect(accessibility.capture().messages.length).assertEqual(0);
      expect(accessibility.capture().error).assertEqual('辅助权限未授权');
    });

    it('fails reply dispatch explicitly when WeChat automation is unavailable', 0, () => {
      const automation = new WechatReplyAutomation(false, '辅助自动化未授权');
      const result = automation.send({
        targetMessageId: 'wechat-1',
        platform: 'wechat',
        conversationId: 'wechat-alice',
        text: '可以'
      });

      expect(result.status).assertEqual('failed');
      expect(result.error).assertEqual('辅助自动化未授权');
      expect(result.text).assertEqual('可以');
    });

    it('builds diagnostics rows from capability probe without hiding unavailable paths', 0, () => {
      const capabilities = probeSocialCapabilities({
        notificationBridgeAvailable: false,
        accessibilityAvailable: true,
        wechatInstalled: false,
        lastCapture: '无真实消息',
        lastSend: '未发送'
      });
      const rows = buildSocialDiagnosticsRows(capabilities);

      expect(rows[0].value).assertEqual('不可用');
      expect(rows[1].value).assertEqual('可用');
      expect(rows[2].value).assertEqual('未检测到');
    });
  });
}
