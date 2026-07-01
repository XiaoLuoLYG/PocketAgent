import { describe, it, expect } from '@ohos/hypium';
import {
  voiceInputErrorMessage,
  voiceInputPermissionGranted
} from '../main/ets/model/VoiceInputBridge';

export default function voiceInputBridgeTest() {
  describe('voiceInputBridge', () => {
    it('accepts microphone permission only when Harmony grants it', 0, () => {
      expect(voiceInputPermissionGranted({
        permissions: ['ohos.permission.MICROPHONE'],
        authResults: [0]
      })).assertTrue();
      expect(voiceInputPermissionGranted({
        permissions: ['ohos.permission.MICROPHONE'],
        authResults: [-1]
      })).assertFalse();
      expect(voiceInputPermissionGranted({
        permissions: ['ohos.permission.CAMERA', 'ohos.permission.MICROPHONE'],
        authResults: [0, 0]
      })).assertTrue();
      expect(voiceInputPermissionGranted({
        permissions: [],
        authResults: [0]
      })).assertTrue();
      expect(voiceInputPermissionGranted({
        permissions: [],
        authResults: [-1]
      })).assertFalse();
      expect(voiceInputPermissionGranted({
        permissions: ['ohos.permission.CAMERA'],
        authResults: [0]
      })).assertFalse();
    });

    it('formats errors without leaking empty messages', 0, () => {
      expect(voiceInputErrorMessage(new Error('engine failed'))).assertEqual('engine failed');
      expect(voiceInputErrorMessage({ code: 1002200002, message: 'start failed' })).assertEqual('1002200002: start failed');
      expect(voiceInputErrorMessage({ code: 6800301 })).assertEqual('6800301');
      expect(voiceInputErrorMessage(null)).assertEqual('语音识别失败');
    });
  });
}
