import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiFoodData, A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const PLACES_SEARCH_URL: string = 'https://places.googleapis.com/v1/places:searchText';
const PLACES_BASE_URL: string = 'https://places.googleapis.com/v1/places/';
const PLACES_FIELD_MASK: string = 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.googleMapsUri,places.currentOpeningHours.openNow';
const PLACE_DETAIL_FIELD_MASK: string = 'id,displayName,formattedAddress,location,rating,googleMapsUri,currentOpeningHours.openNow';

interface MapsTextSearchPayload {
  places?: MapsPlacePayload[];
}

interface MapsTextSearchRequest {
  textQuery: string;
  languageCode: string;
  maxResultCount: number;
}

interface MapsPlacePayload {
  id?: string;
  formattedAddress?: string;
  rating?: number;
  googleMapsUri?: string;
  currentOpeningHours?: MapsOpeningHours;
  displayName?: MapsDisplayName;
  location?: MapsLocation;
}

interface MapsDisplayName {
  text?: string;
}

interface MapsLocation {
  latitude?: number;
  longitude?: number;
}

interface MapsOpeningHours {
  openNow?: boolean;
}

interface GoogleApiError {
  message?: string;
  status?: string;
}

interface GoogleApiErrorPayload {
  error?: GoogleApiError;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function encodeParam(value: string): string {
  return encodeURIComponent(value);
}

export function mapsTextSearchBody(query: string): MapsTextSearchRequest {
  return {
    textQuery: query,
    languageCode: 'zh-CN',
    maxResultCount: 10
  };
}

function placeTitle(place: MapsPlacePayload): string {
  const title = place.displayName === undefined ? '' : textOf(place.displayName.text);
  return title.length > 0 ? title : textOf(place.id);
}

function placeRows(place: MapsPlacePayload): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [
    { label: 'Place ID', value: textOf(place.id) },
    { label: 'Address', value: textOf(place.formattedAddress) },
    { label: 'Rating', value: textOf(place.rating) }
  ];
  const mapLocation = placeMapLocation(place);
  if (mapLocation.length > 0) {
    rows.push({ label: 'Map Location', value: mapLocation });
  }
  if (place.currentOpeningHours !== undefined) {
    rows.push({ label: 'Open now', value: textOf(place.currentOpeningHours.openNow) });
  }
  if (textOf(place.googleMapsUri).length > 0) {
    rows.push({ label: 'Maps URL', value: textOf(place.googleMapsUri) });
  }
  return rows;
}

function placeMapLocation(place: MapsPlacePayload): string {
  if (place.location === undefined) {
    return '';
  }
  const latitude = place.location.latitude;
  const longitude = place.location.longitude;
  if (latitude === undefined || longitude === undefined || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return '';
  }
  return latitude.toString() + ',' + longitude.toString();
}

function resultRowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  return '';
}

function foodLocationFromMapLocation(location: string): string {
  const parts = location.split(',');
  if (parts.length !== 2) {
    return '';
  }
  const latitude = Number(parts[0].trim());
  const longitude = Number(parts[1].trim());
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return '';
  }
  return longitude.toString() + ',' + latitude.toString();
}

export function mapsFoodRecordFromResult(result: DynamicGenericToolResult): A2uiFoodData {
  const rating = resultRowValue(result, 'Rating');
  return {
    name: result.title,
    category: rating.length > 0 ? 'Google Places · 评分 ' + rating : 'Google Places',
    address: resultRowValue(result, 'Address'),
    distance: '',
    location: foodLocationFromMapLocation(resultRowValue(result, 'Map Location')),
    sourceTags: ['Google Maps']
  };
}

function placeResult(toolId: string, place: MapsPlacePayload, summary: string): DynamicGenericToolResult {
  const id = textOf(place.id);
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: placeTitle(place),
    status: 'success',
    summary: summary,
    rows: placeRows(place),
    rawPreview: 'placeId=' + id
  };
}

function errorResult(toolId: string, title: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: title,
    status: 'error',
    summary: message.substring(0, 240),
    rows: [{ label: 'Error', value: message.substring(0, 160) }],
    rawPreview: 'error=' + message.substring(0, 320)
  };
}

export function mapsMissingApiKeyResult(toolId: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: toolId,
    title: '缺少 Google Maps API Key',
    status: 'error',
    summary: '缺少 GOOGLE_MAPS_API_KEY；不会改用 food.search 或模拟地点。',
    rows: [{ label: 'Missing', value: 'GOOGLE_MAPS_API_KEY' }],
    rawPreview: 'missing=GOOGLE_MAPS_API_KEY'
  };
}

export function mapsMissingPlaceIdResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Google Places API',
    toolName: 'maps.place.details',
    title: '缺少 Google Maps Place ID',
    status: 'error',
    summary: '缺少字段：placeId',
    rows: [{ label: 'Missing', value: 'placeId' }],
    rawPreview: 'missing=placeId'
  };
}

export function mapsTextSearchResultsFromPayload(rawJson: string, query: string): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as MapsTextSearchPayload;
  const places = Array.isArray(payload.places) ? payload.places : [];
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < places.length; index++) {
    results.push(placeResult('maps.place.search', places[index], 'Google Places result for: ' + query));
  }
  if (results.length === 0) {
    return [{
      sourceTag: 'Google Places API',
      toolName: 'maps.place.search',
      title: '没有找到地点',
      status: 'success',
      summary: 'Google Places API 查询成功，但没有返回可展示地点。',
      rows: [{ label: 'Query', value: query }],
      rawPreview: 'empty places'
    }];
  }
  return results;
}

async function requestJson(method: http.RequestMethod, url: string, apiKey: string, fieldMask: string, body: Object | null): Promise<Object> {
  const request = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': fieldMask
    };
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    aiLogInfo('[AIPhone][MapsApiHttpStart] url=' + url.substring(0, 180));
    const response = await request.request(url, options);
    const text = responseText(response.result);
    const payload = text.length > 0 ? JSON.parse(text) as Object : new Object();
    if (response.responseCode < 200 || response.responseCode >= 300) {
      const errorPayload = payload as GoogleApiErrorPayload;
      const message = errorPayload.error === undefined ? '' : textOf(errorPayload.error.message);
      const status = errorPayload.error === undefined ? '' : textOf(errorPayload.error.status);
      throw new Error(message.length > 0 ? message : (status.length > 0 ? status : 'HTTP ' + response.responseCode.toString()));
    }
    return payload;
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][MapsApiHttpError] error=' + message.substring(0, 220));
    throw new Error(message);
  } finally {
    request.destroy();
  }
}

export async function callMapsPlaceSearch(query: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [mapsMissingApiKeyResult('maps.place.search')];
  }
  try {
    const payload = await requestJson(http.RequestMethod.POST, PLACES_SEARCH_URL, apiKey.trim(), PLACES_FIELD_MASK, mapsTextSearchBody(query));
    return mapsTextSearchResultsFromPayload(JSON.stringify(payload), query);
  } catch (error) {
    return [errorResult('maps.place.search', 'Google Places API 调用失败', error instanceof Error ? error.message : JSON.stringify(error))];
  }
}

export async function callMapsPlaceDetails(placeId: string, apiKey: string): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [mapsMissingApiKeyResult('maps.place.details')];
  }
  if (placeId.trim().length === 0) {
    return [mapsMissingPlaceIdResult()];
  }
  try {
    const payload = await requestJson(http.RequestMethod.GET, PLACES_BASE_URL + encodeParam(placeId.trim()), apiKey.trim(), PLACE_DETAIL_FIELD_MASK, null) as MapsPlacePayload;
    return [placeResult('maps.place.details', payload, 'Google Places details returned by the real API.')];
  } catch (error) {
    return [errorResult('maps.place.details', 'Google Places API 调用失败', error instanceof Error ? error.message : JSON.stringify(error))];
  }
}
