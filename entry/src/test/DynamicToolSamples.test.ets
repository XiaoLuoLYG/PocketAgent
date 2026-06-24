import { describe, it, expect } from '@ohos/hypium';
import {
  configureDefaultDynamicToolSamplesForTests,
  sampleManifestForToolId,
  sampleManifestIds
} from '../main/ets/model/DynamicToolSamples';
import { DynamicToolManifest } from '../main/ets/model/DynamicToolTypes';

export default function dynamicToolSamplesTest() {
  describe('dynamicToolSamples', () => {
    it('finds a high-frequency weather sample', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const manifest = sampleManifestForToolId('weather.query') as DynamicToolManifest;

      expect(manifest === null).assertFalse();
      expect(manifest.displayName.length).assertLarger(0);
      expect(manifest.requiredCredentials[0].name).assertEqual('AMAP_MAPS_API_KEY');
      expect(manifest.requiredCredentials[0].placement).assertEqual('query');
      expect(manifest.transports[0].type).assertEqual('http_api');
      expect(manifest.transports[0].credentialParam).assertEqual('key');
      expect(manifest.transports[0].fixedQuery).assertEqual('extensions=base&output=json');
      expect(manifest.transports[0].forecastQuery).assertEqual('extensions=all&output=json');
    });

    it('finds an unsupported npx sample', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const manifest = sampleManifestForToolId('ppt.generate') as DynamicToolManifest;

      expect(manifest === null).assertFalse();
      expect(manifest.transports[0].type).assertEqual('stdio');
      expect(manifest.transports[0].command).assertEqual('npx');
    });

    it('finds a hosted statistics sample without placeholder auth headers', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const manifest = sampleManifestForToolId('statistics.search') as DynamicToolManifest;

      expect(manifest === null).assertFalse();
      expect(manifest.transports[0].type).assertEqual('streamable_http');
      expect(Object.keys(manifest.transports[0].headers).indexOf('Authorization')).assertEqual(-1);
    });

    it('lists stable sample ids', 0, () => {
      configureDefaultDynamicToolSamplesForTests();
      const ids = sampleManifestIds();

      expect(ids.indexOf('modelscope.fixture.echo')).assertLarger(-1);
      expect(ids.indexOf('modelscope.@amap.amap-maps')).assertLarger(-1);
    });
  });
}
