import { describe, it, expect } from '@ohos/hypium';
import { buildToolGatewayUrl, defaultToolGatewayUrl, isLocalToolGatewayUrl } from '../main/ets/model/ToolGatewayClient';

export default function toolGatewayClientTest() {
  describe('toolGatewayClient', () => {
    it('defaults to the in-app local tool route', 0, () => {
      expect(defaultToolGatewayUrl()).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(defaultToolGatewayUrl())).assertTrue();
      expect(buildToolGatewayUrl(defaultToolGatewayUrl())).assertEqual('local://aiphone-tools');
    });

    it('still supports explicit HTTP tool gateways', 0, () => {
      expect(isLocalToolGatewayUrl('http://127.0.0.1:8787')).assertFalse();
      expect(buildToolGatewayUrl('http://127.0.0.1:8787')).assertEqual('http://127.0.0.1:8787/api/aiphone/tool');
    });

    it('does not create a tool-specific override for provider tools', 0, () => {
      const endpoint = buildToolGatewayUrl(defaultToolGatewayUrl());
      expect(endpoint).assertEqual('local://aiphone-tools');
      expect(isLocalToolGatewayUrl(endpoint)).assertTrue();
    });
  });
}
