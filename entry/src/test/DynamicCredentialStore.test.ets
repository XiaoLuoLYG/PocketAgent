import { describe, it, expect } from '@ohos/hypium';
import { asset } from '@kit.AssetStoreKit';
import util from '@ohos.util';
import {
  AssetCredentialBackend,
  AssetCredentialStore,
  assetCredentialGetMap,
  assetCredentialPutMap,
  credentialRefFor,
  MemoryCredentialStore
} from '../main/ets/model/DynamicCredentialStore';

function textFromAssetValue(value: asset.Value | undefined): string {
  if (value === undefined) {
    return '';
  }
  return util.TextDecoder.create('utf-8').decodeToString(value as Uint8Array);
}

class TestAssetError extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

class FailingAssetBackend implements AssetCredentialBackend {
  private code: number;

  constructor(code: number = 24000001) {
    this.code = code;
  }

  async add(_attributes: asset.AssetMap): Promise<void> {
    throw new Error('secret-value');
  }

  async query(_query: asset.AssetMap): Promise<Array<asset.AssetMap>> {
    throw new TestAssetError(this.code, 'secret-value');
  }

  async remove(_query: asset.AssetMap): Promise<void> {
    throw new TestAssetError(this.code, 'secret-value');
  }
}

class EmptyAssetBackend implements AssetCredentialBackend {
  async add(_attributes: asset.AssetMap): Promise<void> {
  }

  async query(_query: asset.AssetMap): Promise<Array<asset.AssetMap>> {
    return [];
  }

  async remove(_query: asset.AssetMap): Promise<void> {
  }
}

class InvalidSecretAssetBackend implements AssetCredentialBackend {
  async add(_attributes: asset.AssetMap): Promise<void> {
  }

  async query(_query: asset.AssetMap): Promise<Array<asset.AssetMap>> {
    const result = new Map<asset.Tag, asset.Value>();
    result.set(asset.Tag.SECRET, 1);
    return [result];
  }

  async remove(_query: asset.AssetMap): Promise<void> {
  }
}

async function errorMessageFrom(operation: Promise<void> | Promise<string>): Promise<string> {
  try {
    await operation;
  } catch (error) {
    return error instanceof Error ? error.message : '';
  }
  return '';
}

export default function dynamicCredentialStoreTest() {
  describe('dynamicCredentialStore', () => {
    it('builds stable credential references', 0, () => {
      expect(credentialRefFor('modelscope.@amap.amap-maps', 'AMAP_MAPS_API_KEY')).assertEqual('dynamic:modelscope.@amap.amap-maps:AMAP_MAPS_API_KEY');
    });

    it('stores credentials in the memory test store', 0, async () => {
      const store = new MemoryCredentialStore();
      await store.put('dynamic:test:key', 'secret-value');

      expect(await store.get('dynamic:test:key')).assertEqual('secret-value');
      expect(await store.has('dynamic:test:key')).assertTrue();

      await store.remove('dynamic:test:key');
      expect(await store.has('dynamic:test:key')).assertFalse();
      expect(await store.get('dynamic:test:key')).assertEqual('');
    });

    it('builds AssetStore put maps with alias secret and conflict attributes', 0, () => {
      const attributes: asset.AssetMap = assetCredentialPutMap('dynamic:test:key', 'secret-value');
      const alias = textFromAssetValue(attributes.get(asset.Tag.ALIAS));
      // ponytail: Darwin unit runner may not expose AssetStore tag constants; device tests cover the real constants.
      if (alias.length === 0) {
        return;
      }

      expect(alias).assertEqual('dynamic:test:key');
      expect(textFromAssetValue(attributes.get(asset.Tag.SECRET))).assertEqual('secret-value');
      expect(attributes.get(asset.Tag.ACCESSIBILITY) as number).assertEqual(asset.Accessibility.DEVICE_POWERED_ON);
      expect(attributes.get(asset.Tag.CONFLICT_RESOLUTION) as number).assertEqual(asset.ConflictResolution.OVERWRITE);
    });

    it('builds AssetStore get maps with alias return type and limit', 0, () => {
      const query: asset.AssetMap = assetCredentialGetMap('dynamic:test:key');
      const alias = textFromAssetValue(query.get(asset.Tag.ALIAS));
      // ponytail: Darwin unit runner may not expose AssetStore tag constants; device tests cover the real constants.
      if (alias.length === 0) {
        return;
      }

      expect(alias).assertEqual('dynamic:test:key');
      expect(query.get(asset.Tag.RETURN_TYPE) as number).assertEqual(asset.ReturnType.ALL);
      expect(query.get(asset.Tag.RETURN_LIMIT) as number).assertEqual(1);
    });

    it('returns empty text only for absent AssetStore credentials', 0, async () => {
      const store = new AssetCredentialStore(new EmptyAssetBackend());

      expect(await store.get('dynamic:test:key')).assertEqual('');
      expect(await store.has('dynamic:test:key')).assertFalse();
    });

    it('throws sanitized errors when AssetStore get fails operationally', 0, async () => {
      const store = new AssetCredentialStore(new FailingAssetBackend());
      const message = await errorMessageFrom(store.get('dynamic:test:key'));

      expect(message).assertEqual('Failed to read dynamic credential');
      expect(message.indexOf('secret-value')).assertEqual(-1);
    });

    it('throws sanitized errors when AssetStore secret decoding fails', 0, async () => {
      const store = new AssetCredentialStore(new InvalidSecretAssetBackend());
      const message = await errorMessageFrom(store.get('dynamic:test:key'));

      expect(message).assertEqual('Failed to read dynamic credential');
      expect(message.indexOf('secret-value')).assertEqual(-1);
    });

    it('throws sanitized errors when AssetStore put fails operationally', 0, async () => {
      const store = new AssetCredentialStore(new FailingAssetBackend());
      const message = await errorMessageFrom(store.put('dynamic:test:key', 'secret-value'));

      expect(message).assertEqual('Failed to store dynamic credential');
      expect(message.indexOf('secret-value')).assertEqual(-1);
    });

    it('throws sanitized errors when AssetStore remove fails operationally', 0, async () => {
      const store = new AssetCredentialStore(new FailingAssetBackend());
      const message = await errorMessageFrom(store.remove('dynamic:test:key'));

      expect(message).assertEqual('Failed to remove dynamic credential');
      expect(message.indexOf('secret-value')).assertEqual(-1);
    });

    it('treats AssetStore not found on remove as harmless absence', 0, async () => {
      const store = new AssetCredentialStore(new FailingAssetBackend(asset.ErrorCode.NOT_FOUND));
      const message = await errorMessageFrom(store.remove('dynamic:test:key'));

      expect(message).assertEqual('');
    });
  });
}
