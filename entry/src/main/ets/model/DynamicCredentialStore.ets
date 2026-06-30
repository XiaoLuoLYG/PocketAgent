import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';
import util from '@ohos.util';
import { utf8Bytes } from './Utf8Bytes';

export interface CredentialStore {
  put(ref: string, value: string): Promise<void>;
  get(ref: string): Promise<string>;
  has(ref: string): Promise<boolean>;
  remove(ref: string): Promise<void>;
}

export function credentialRefFor(manifestId: string, credentialName: string): string {
  return 'dynamic:' + manifestId + ':' + credentialName;
}

export class MemoryCredentialStore implements CredentialStore {
  private values: Map<string, string> = new Map<string, string>();

  async put(ref: string, value: string): Promise<void> {
    this.values.set(ref, value);
  }

  async get(ref: string): Promise<string> {
    const value = this.values.get(ref);
    return value === undefined ? '' : value;
  }

  async has(ref: string): Promise<boolean> {
    return (await this.get(ref)).length > 0;
  }

  async remove(ref: string): Promise<void> {
    this.values.delete(ref);
  }
}

export interface AssetCredentialBackend {
  add(attributes: asset.AssetMap): Promise<void>;
  query(query: asset.AssetMap): Promise<Array<asset.AssetMap>>;
  remove(query: asset.AssetMap): Promise<void>;
}

function bytesOf(value: string): Uint8Array {
  return utf8Bytes(value);
}

function textFromBytes(value: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(value);
}

function aliasBytes(ref: string): Uint8Array {
  return bytesOf(ref);
}

function makeAssetMap(): asset.AssetMap {
  return new Map<asset.Tag, asset.Value>();
}

function aliasMap(ref: string): asset.AssetMap {
  const query = makeAssetMap();
  query.set(asset.Tag.ALIAS, aliasBytes(ref));
  return query;
}

export function assetCredentialPutMap(ref: string, value: string): asset.AssetMap {
  const attributes = aliasMap(ref);
  attributes.set(asset.Tag.SECRET, bytesOf(value));
  attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_POWERED_ON);
  attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
  return attributes;
}

export function assetCredentialGetMap(ref: string): asset.AssetMap {
  const query = aliasMap(ref);
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
  query.set(asset.Tag.RETURN_LIMIT, 1);
  return query;
}

function assetCredentialRemoveMap(ref: string): asset.AssetMap {
  return aliasMap(ref);
}

function isAssetNotFoundError(error: BusinessError): boolean {
  return error.code === asset.ErrorCode.NOT_FOUND;
}

export class AssetCredentialStore implements CredentialStore {
  private backend: AssetCredentialBackend | null;

  constructor(backend?: AssetCredentialBackend) {
    this.backend = backend === undefined ? null : backend;
  }

  async put(ref: string, value: string): Promise<void> {
    try {
      const attributes = assetCredentialPutMap(ref, value);
      if (this.backend === null) {
        await asset.add(attributes);
      } else {
        await this.backend.add(attributes);
      }
    } catch (_error) {
      throw new Error('Failed to store dynamic credential');
    }
  }

  async get(ref: string): Promise<string> {
    try {
      const query = assetCredentialGetMap(ref);
      const result = this.backend === null ? await asset.query(query) : await this.backend.query(query);
      if (result.length === 0) {
        return '';
      }
      const secret = result[0].get(asset.Tag.SECRET);
      if (secret === undefined) {
        return '';
      }
      if (!(secret instanceof Uint8Array)) {
        throw new Error('Invalid dynamic credential secret');
      }
      return textFromBytes(secret);
    } catch (error) {
      const businessError = error as BusinessError;
      if (isAssetNotFoundError(businessError)) {
        return '';
      }
      throw new Error('Failed to read dynamic credential');
    }
  }

  async has(ref: string): Promise<boolean> {
    return (await this.get(ref)).length > 0;
  }

  async remove(ref: string): Promise<void> {
    try {
      const query = assetCredentialRemoveMap(ref);
      if (this.backend === null) {
        await asset.remove(query);
      } else {
        await this.backend.remove(query);
      }
    } catch (error) {
      const businessError = error as BusinessError;
      if (isAssetNotFoundError(businessError)) {
        return;
      }
      throw new Error('Failed to remove dynamic credential');
    }
  }
}
