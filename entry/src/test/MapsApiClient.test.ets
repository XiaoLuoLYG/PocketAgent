import { describe, it, expect } from '@ohos/hypium';
import { mapsFoodRecordFromResult, mapsTextSearchBody, mapsTextSearchResultsFromPayload } from '../main/ets/model/MapsApiClient';

export default function mapsApiClientTest() {
  describe('mapsApiClient', () => {
    it('builds text search body for POI search', 0, () => {
      const body = mapsTextSearchBody('深圳坂田华为基地附近的咖啡店');
      expect(JSON.stringify(body)).assertEqual('{"textQuery":"深圳坂田华为基地附近的咖啡店","languageCode":"zh-CN","maxResultCount":10}');
    });

    it('maps Places payload into generic results', 0, () => {
      const payload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"googleMapsUri":"https://maps.google.com/?cid=123","location":{"latitude":22.609878,"longitude":114.029506}}]}';
      const results = mapsTextSearchResultsFromPayload(payload, '深圳咖啡');
      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('Google Places API');
      expect(results[0].toolName).assertEqual('maps.place.search');
      expect(results[0].title).assertEqual('Coffee Lab');
      expect(results[0].rows[0].value).assertEqual('place-123');
      expect(JSON.stringify(results[0].rows).indexOf('"label":"Map Location","value":"22.609878,114.029506"')).assertLarger(-1);
    });

    it('maps Google Places results into food records with food coordinate order', 0, () => {
      const payload = '{"places":[{"id":"place-123","displayName":{"text":"Coffee Lab"},"formattedAddress":"深圳市龙岗区坂田","rating":4.6,"location":{"latitude":22.609878,"longitude":114.029506}}]}';
      const food = mapsFoodRecordFromResult(mapsTextSearchResultsFromPayload(payload, '深圳咖啡')[0]);
      const tags = food.sourceTags === undefined ? [] : food.sourceTags;

      expect(food.name).assertEqual('Coffee Lab');
      expect(food.location).assertEqual('114.029506,22.609878');
      expect(tags[0]).assertEqual('Google Maps');
    });
  });
}
