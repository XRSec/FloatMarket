# Market Transport Planner

This document describes how FloatMarket chooses between HTTP snapshot polling and WebSocket streaming.

## Goal

WebSocket is the preferred realtime transport whenever a watch item can use it reliably. HTTP is still kept as the snapshot and fallback transport:

- bootstrap the first visible quote after launch or window reopen
- refresh items that do not support WebSocket
- backfill after WebSocket disconnects
- calibrate after WebSocket reconnects
- sync Baidu self-select visibility and quotes through `/selfselect/gethomeinfo`

This keeps fast price movement on WSS while avoiding unnecessary HTTP overwrites for already-connected streams.

## Parent Components

`MarketStore` owns transport planning and orchestration:

- starts and stops `MarketStreamController`
- schedules HTTP refreshes
- tracks stream states
- decides which watch items are eligible for each refresh reason
- merges snapshots into UI state

`MarketDataClient` owns HTTP fetching:

- receives an already-selected list of `WatchItem`
- fans out to provider-specific HTTP methods
- returns `QuoteSnapshot` and `LogEntry`

`MarketStreamController` owns WebSocket loops:

- starts one stream task per stream-capable source group
- reports stream state to `MarketStore`
- emits realtime snapshots as they arrive

Provider files own protocol details and decoding:

- `BaiduGlobalIndexProvider.swift`
- `SinaGlobalIndexProvider.swift`
- `OKXProvider.swift`
- `GateProvider.swift`
- `BinanceProvider.swift`

## Transport Plans

`MarketStore` classifies each enabled item into one of three plans:

| Plan | Meaning | Scheduled HTTP |
| --- | --- | --- |
| `httpOnly` | The item cannot currently use WSS, or WSS is disconnected. | Yes |
| `streamPrimary` | WSS is supported and currently preferred/active. | No |
| `standby` | The stream source intentionally has nothing to subscribe right now. | No |

Launch, window reopen, and manual snapshot refresh are allowed to request all enabled items. Scheduled refresh is stricter and only polls `httpOnly` items.

## Baidu Rules

Baidu is a mixed transport source:

- HTTP uses only `/selfselect/gethomeinfo`.
- The old public HTTP endpoints such as global index rank and foreign banner are no longer used.
- WSS remains the preferred realtime lane for supported index subscriptions.
- Foreign exchange and unsupported Baidu categories stay HTTP-only.
- Baidu WSS preference is time-aware through local market schedules.

The Baidu HTTP parser intentionally accepts a broad self-select JSON shape because different favorite categories can return slightly different field names. It maps both direct codes and prefixed codes, for example `us-IXIC` also matches local `IXIC`.

## Refresh Reasons

`MarketStore` refreshes different item sets depending on why the refresh was requested:

- `launch`: all enabled items, so the UI can populate quickly
- `ticker-reopened`: all enabled items, so stale windows rehydrate
- manual refresh: all enabled items
- `scheduled`: only items planned as `httpOnly`
- stream disconnected: stream-capable items for that stream group
- stream connected: stream-capable items for that stream group, used as a one-shot calibration

Stream state changes restart the scheduled refresh loop so the HTTP fallback set matches the latest WSS state.

## Current Tradeoffs

The planner lives in `MarketStore` because it depends on UI-owned state such as `quotesByID`, stream states, and settings. If the transport rules become more complex, the next clean step is extracting it into a dedicated `MarketTransportPlanner` type with pure inputs:

- enabled watch items
- stream states
- existing snapshot IDs
- current date
- settings/config capability

That would make the transport policy easier to unit test without spinning up the store.

## Future Improvements

- Add an explicit snapshot transport marker so HTTP snapshots cannot overwrite fresher WSS ticks when requests race.
- Cache Baidu self-select membership separately from Baidu quote values.
- Split Baidu into `BaiduSelfSelectProvider`, `BaiduQuoteMapper`, and `BaiduStreamProvider` when the response shape is stable enough.
- Move exchange-specific symbol normalization into provider-owned mappers instead of UI helpers.
- Replace hard-coded stream task fields in `MarketStreamController` with a small provider registry if more WSS sources are added.
