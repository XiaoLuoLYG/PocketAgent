import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';

const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';
const SESSION_PREFIX = 'voice-input-';
const PCM_CHUNK_BYTES = 640;
// ponytail: safety cap; press-to-talk owns normal finish.
const VOICE_INPUT_TIMEOUT_MS = 20000;
const VOICE_INPUT_FINISH_GRACE_MS = 2000;

export interface VoiceInputResult {
  text: string;
}

export interface VoiceInputSession {
  result: Promise<VoiceInputResult>;
  stop: () => Promise<VoiceInputResult>;
}

export interface VoicePermissionResultLike {
  permissions: string[];
  authResults: number[];
}

interface VoiceInputErrorLike {
  code?: number | string;
  message?: string;
}

export function voiceInputPermissionGranted(result: VoicePermissionResultLike): boolean {
  if (result.authResults.length === 0) {
    return false;
  }
  if (result.permissions.length === 0) {
    return result.authResults[0] === 0;
  }
  const index = result.permissions.indexOf(MICROPHONE_PERMISSION);
  return index >= 0 && result.authResults.length > index && result.authResults[index] === 0;
}

export function voiceInputErrorMessage(error: Error | VoiceInputErrorLike | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message.length > 0 ? error.message : '语音识别失败';
  }
  if (typeof error === 'string') {
    return error.length > 0 ? error : '语音识别失败';
  }
  if (typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  if (error === null || error === undefined) {
    return '语音识别失败';
  }
  const code = error.code === undefined ? '' : error.code.toString();
  const message = error.message === undefined ? '' : error.message.trim();
  if (code.length > 0 && message.length > 0) {
    return code + ': ' + message;
  }
  if (message.length > 0) {
    return message;
  }
  return code.length > 0 ? code : '语音识别失败';
}

export async function recognizeVoiceInputOnce(context: common.UIAbilityContext): Promise<VoiceInputResult> {
  const session = await createVoiceInputSession(context, (_text: string) => {}, true);
  return session.result;
}

export async function startVoiceInputSession(
  context: common.UIAbilityContext,
  onResult: (text: string) => void = (_text: string) => {}
): Promise<VoiceInputSession> {
  return createVoiceInputSession(context, onResult, false);
}

async function createVoiceInputSession(
  context: common.UIAbilityContext,
  onResult: (text: string) => void,
  autoFinish: boolean
): Promise<VoiceInputSession> {
  let engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  let capturer: audio.AudioCapturer | null = null;
  try {
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, [MICROPHONE_PERMISSION]);
    if (!voiceInputPermissionGranted({
      permissions: permission.permissions,
      authResults: permission.authResults
    })) {
      throw new Error('麦克风权限未授权');
    }
    engine = await speechRecognizer.createEngine({
      language: 'zh-CN',
      online: 1,
      extraParams: {
        locate: 'CN',
        recognizerMode: 'long'
      }
    });
    capturer = await audio.createAudioCapturer(voiceAudioCapturerOptions());
    return recognizeWithCapturer(engine, capturer, onResult, autoFinish);
  } catch (error) {
    await releaseCapturer(capturer);
    shutdownEngine(engine);
    throw new Error(voiceInputErrorMessage(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined));
  }
}

function voiceAudioCapturerOptions(): audio.AudioCapturerOptions {
  return {
    streamInfo: {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    },
    capturerInfo: {
      source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
      capturerFlags: 0
    }
  };
}

function recognizeWithCapturer(
  engine: speechRecognizer.SpeechRecognitionEngine,
  capturer: audio.AudioCapturer,
  onResult: (text: string) => void,
  autoFinish: boolean
): VoiceInputSession {
  let stopVoiceInput: () => Promise<VoiceInputResult> = () => Promise.reject(new Error('语音识别未开始'));
  const resultPromise = new Promise<VoiceInputResult>((resolve: (value: VoiceInputResult) => void, reject: (reason?: Error) => void) => {
    let done = false;
    let sessionId = SESSION_PREFIX + Date.now().toString();
    let pending = new Uint8Array(0);
    let finalText = '';
    let timeoutId = -1;
    let finishTimeoutId = -1;
    let finishRequested = false;
    let finalResultSeen = false;

    const readData = (buffer: ArrayBuffer): void => {
      if (done) {
        return;
      }
      try {
        pending = writeAudioFrames(engine, sessionId, pending, new Uint8Array(buffer));
      } catch (error) {
        fail(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined);
      }
    };

    const detach = (): void => {
      try {
        capturer.off('readData', readData);
      } catch (_error) {
      }
    };

    const clearTimers = (): void => {
      clearTimeout(timeoutId);
      clearTimeout(finishTimeoutId);
    };

    const finish = (text: string): void => {
      if (done) {
        return;
      }
      done = true;
      clearTimers();
      detach();
      releaseCapturer(capturer).finally(() => {
        shutdownEngine(engine);
      });
      resolve({ text });
    };

    const fail = (error: Error | VoiceInputErrorLike | string | number | boolean | null | undefined): void => {
      if (done) {
        return;
      }
      done = true;
      clearTimers();
      detach();
      releaseCapturer(capturer).finally(() => {
        shutdownEngine(engine);
      });
      reject(new Error(voiceInputErrorMessage(error)));
    };

    const requestFinish = (timeoutMessage: string): Promise<VoiceInputResult> => {
      if (done || finishRequested) {
        return resultPromise;
      }
      finishRequested = true;
      clearTimeout(timeoutId);
      detach();
      if (finalResultSeen) {
        finish(finalText);
        return resultPromise;
      }
      try {
        engine.finish(sessionId);
      } catch (error) {
        fail(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined);
        return resultPromise;
      }
      finishTimeoutId = setTimeout(() => {
        fail(new Error(timeoutMessage));
      }, VOICE_INPUT_FINISH_GRACE_MS);
      return resultPromise;
    };

    stopVoiceInput = () => requestFinish('语音识别结束超时');

    timeoutId = setTimeout(() => {
      requestFinish('语音识别超时');
    }, VOICE_INPUT_TIMEOUT_MS);

    engine.setListener({
      onStart(startSessionId: string, _eventMessage: string): void {
        sessionId = startSessionId;
        try {
          capturer.on('readData', readData);
        } catch (error) {
          fail(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined);
          return;
        }
        capturer.start().catch((error: Error | VoiceInputErrorLike | string | number | boolean | null | undefined) => {
          fail(error);
        });
      },
      onEvent(_eventSessionId: string, eventCode: number, _eventMessage: string): void {
        if (autoFinish && eventCode === 3) {
          requestFinish('语音识别结束超时');
        }
      },
      onResult(_resultSessionId: string, result: speechRecognizer.SpeechRecognitionResult): void {
        finalText = result.result;
        finalResultSeen = result.isLast;
        onResult(finalText);
        if (autoFinish && result.isLast) {
          finish(finalText);
        }
      },
      onComplete(_completeSessionId: string, _eventMessage: string): void {
        finalResultSeen = true;
        if (autoFinish || finishRequested) {
          finish(finalText);
        }
      },
      onError(_errorSessionId: string, errorCode: number, errorMessage: string): void {
        fail({
          code: errorCode,
          message: errorMessage
        });
      }
    });
    try {
      engine.startListening({
        sessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      });
    } catch (error) {
      fail(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined);
    }
  });
  return {
    result: resultPromise,
    stop: () => stopVoiceInput()
  };
}

function writeAudioFrames(
  engine: speechRecognizer.SpeechRecognitionEngine,
  sessionId: string,
  pending: Uint8Array,
  input: Uint8Array
): Uint8Array {
  const audioBytes = new Uint8Array(pending.length + input.length);
  audioBytes.set(pending);
  audioBytes.set(input, pending.length);

  let offset = 0;
  while (offset + PCM_CHUNK_BYTES <= audioBytes.length) {
    try {
      engine.writeAudio(sessionId, audioBytes.subarray(offset, offset + PCM_CHUNK_BYTES));
    } catch (error) {
      throw new Error(voiceInputErrorMessage(error as Error | VoiceInputErrorLike | string | number | boolean | null | undefined));
    }
    offset += PCM_CHUNK_BYTES;
  }
  return audioBytes.subarray(offset);
}

async function releaseCapturer(capturer: audio.AudioCapturer | null): Promise<void> {
  if (capturer === null) {
    return;
  }
  try {
    await capturer.stop();
  } catch (_error) {
  }
  try {
    await capturer.release();
  } catch (_error) {
  }
}

function shutdownEngine(engine: speechRecognizer.SpeechRecognitionEngine | null): void {
  if (engine === null) {
    return;
  }
  try {
    engine.shutdown();
  } catch (_error) {
  }
}
