# A2UI Notes

A2UI is the message format PocketAgent uses to convert model and tool output into native HarmonyOS task surfaces.

## Goals

- Keep the model output declarative.
- Render through a fixed native component catalog.
- Stream partial updates safely.
- Keep tool calls query-only and explicit.
- Reject unknown components or legacy payloads.

## Message transport

Responses use newline-delimited JSON:

```jsonl
{"version":"v0.9.1","createSurface":{"surfaceId":"surface_train","root":"root","title":"Train search","intent":"travel.train","status":"thinking","sendDataModel":true}}
{"version":"v0.9.1","updateComponents":{"surfaceId":"surface_train","components":[{"id":"root","component":"SurfaceRoot","child":"layout","title":"Train search","status":"ready"},{"id":"layout","component":"Column","children":["summary","results"]},{"id":"summary","component":"InfoRows","title":"Search summary","dataPath":"/rows"},{"id":"results","component":"TrainOptions","title":"Options","dataPath":"/trains"}]}}
{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface_train","path":"/trains","value":[{"trainCode":"G1","from":"Beijing South","to":"Shanghai Hongqiao","depart":"09:00","arrive":"13:28","duration":"4h 28m","seats":"Available","status":"success"}]}}
```

Each envelope must contain exactly one of:

- `createSurface`
- `updateComponents`
- `updateDataModel`
- `deleteSurface`

## Catalog

Foundation components:

- `SurfaceRoot`
- `Column`
- `Row`
- `Text`
- `ActionBar`
- `ErrorNotice`

Task components:

- `ThinkingStream`
- `TrainOptions`
- `FlightBoard`
- `FoodChoices`
- `ConfirmPanel`
- `InfoRows`

Unknown component names are parser errors. Components can bind to the surface data model with JSON Pointer style paths such as `/rows`, `/trains`, `/flights`, `/foods`, `/thoughts`, and `/toolRequest`.

## Tool boundary

The local gateway exposes registered tool IDs:

- `train.search`
- `flight.search`
- `food.search`

Tool results must return A2UI surfaces. Provider errors, missing keys, empty results, and invalid inputs also return A2UI error or confirmation surfaces. They should not fall back to legacy UI payloads or opaque text blobs.
