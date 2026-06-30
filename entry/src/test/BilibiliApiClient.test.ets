import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult } from '../main/ets/model/DynamicToolTypes';
import {
  bilibiliApiSearchUrl,
  bilibiliPlayerUrl,
  bilibiliSearchUrl,
  bilibiliVideoResultsFromSearchHtml,
  bilibiliVideoResultsFromSearchPayload
} from '../main/ets/model/BilibiliApiClient';

export default function bilibiliApiClientTest() {
  describe('bilibiliApiClient', () => {
    it('builds search and player URLs without credentials', 0, () => {
      const searchUrl: string = bilibiliSearchUrl('qwen max 官方介绍');
      const apiUrl: string = bilibiliApiSearchUrl('qwen max 官方介绍');

      expect(searchUrl.indexOf('https://search.bilibili.com/video?')).assertEqual(0);
      expect(searchUrl.indexOf('keyword=qwen%20max%20%E5%AE%98%E6%96%B9%E4%BB%8B%E7%BB%8D')).assertLarger(-1);
      expect(apiUrl.indexOf('https://api.bilibili.com/x/web-interface/search/all/v2?')).assertEqual(0);
      expect(bilibiliPlayerUrl('BV1h57y6pE5o')).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
    });

    it('maps Bilibili API JSON into playable generic tool rows', 0, () => {
      const payload: string = '{"code":0,"message":"OK","data":{"result":[{"result_type":"video","data":[{"bvid":"BV1h57y6pE5o","title":"Qwen <em class=\\"keyword\\">Max</em> 官方介绍","pic":"//i1.hdslb.com/bfs/archive/cover.jpg"}]}]}}';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchPayload(payload, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].rows[1].value).assertEqual('BV1h57y6pE5o');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
    });

    it('maps Bilibili search HTML into playable generic tool rows', 0, () => {
      const html: string = 'http:\\u002F\\u002Fwww.bilibili.com\\u002Fvideo\\u002Fav116698019534672","BV1h57y6pE5o","Qwen \\u003Cem class=\\"keyword\\"\\u003EMax\\u003C\\u002Fem\\u003E 官方介绍","desc","\\u002F\\u002Fi1.hdslb.com\\u002Fbfs\\u002Farchive\\u002Fcover.jpg",98359';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml(html, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].rows[1].label).assertEqual('BVID');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
    });

    it('maps current Bilibili pinia search payloads into playable generic tool rows', 0, () => {
      const html: string = '<script>window.__pinia=(function(a,b,c,d,e,f){return {result:[{bvid:d,title:e,pic:f},{bvid:"BV2222222222",title:b,pic:b}]}}("",0,null,"BV1h57y6pE5o","Qwen \\u003Cem class=\\"keyword\\"\\u003EMax\\u003C\\u002Fem\\u003E 官方介绍","\\u002F\\u002Fi1.hdslb.com\\u002Fbfs\\u002Farchive\\u002Fcover.jpg"))</script>';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml(html, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].rows[1].value).assertEqual('BV1h57y6pE5o');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
    });

    it('returns empty-result rows without fake videos', 0, () => {
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml('<html></html>', 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].status).assertEqual('success');
      expect(results[0].title).assertEqual('没有找到 B 站视频');
      expect(results[0].rows[0].value).assertEqual('qwen max');
    });
  });
}
