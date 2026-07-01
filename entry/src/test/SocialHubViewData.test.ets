import { describe, it, expect } from '@ohos/hypium';
import {
  socialHubKindLabel,
  socialHubPlatformLabel,
  socialHubPrimaryText
} from '../main/ets/pages/A2uiHome/components/SocialHubViewData';
import { normalizeSocialHubItem } from '../main/ets/model/SocialHubTypes';

export default function socialHubViewDataTest() {
  describe('socialHubViewData', () => {
    it('labels known platforms', 0, () => {
      expect(socialHubPlatformLabel('x')).assertEqual('X');
      expect(socialHubPlatformLabel('slack')).assertEqual('Slack');
      expect(socialHubPlatformLabel('wecom')).assertEqual('企业微信');
    });

    it('labels post kind as public post', 0, () => {
      expect(socialHubKindLabel('post')).assertEqual('公开 post');
    });

    it('uses real item text without inventing empty content', 0, () => {
      const item = normalizeSocialHubItem({
        id: 'x-1',
        platform: 'x',
        kind: 'post',
        text: '真实内容'
      });
      const emptyItem = normalizeSocialHubItem({
        id: 'x-2',
        platform: 'x',
        kind: 'post',
        text: ''
      });

      expect(socialHubPrimaryText(item)).assertEqual('真实内容');
      expect(socialHubPrimaryText(emptyItem)).assertEqual('没有正文');
    });
  });
}
