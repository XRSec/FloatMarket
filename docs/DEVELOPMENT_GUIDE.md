# Development Guide / 开发文档

## 1. Product Goal

FloatMarket is a floating macOS market board focused on fast-glance monitoring.

浮市的目标是做一个适合快速扫盘的 macOS 悬浮行情看板。

Core priorities:

- Fast read at a glance
- Stable runtime with fallback engines
- Easy source replacement
- Practical controls for proxy, theme, and watchlist order

核心优先级：

- 一眼可读
- 运行稳定且有回退引擎
- 数据源方便替换
- 代理、主题、监控顺序可直接调

## 2. Architecture

### App Layer

- `FloatMarket.swift`: app entry
- `MainScene.swift`: floating window, control center window, menu bar extra
- `MainView.swift`: floating window UI

### State Layer

- `Menu Bar Button/MenuBarButton.swift`
  - `MarketStore`
  - settings persistence
  - quote merging
  - proxy testing
  - stream state tracking

### Data Layer

- `Export/MyExportDocument.swift`
  - app models
  - settings models
  - scheduling models
- `Export/ExportCommands.swift`
  - HTTP fallback engine
  - WebSocket streaming engine
  - proxy-aware session creation

### UI Control Layer

- `Settings/`
- `Panes/`
- `Sidebar/`
- `About Window/`

## 3. Data Strategy

### Global Indices

- Source: Baidu Gushitong public endpoints
- Strategy:
  - use cached values when market is closed
  - skip unnecessary refreshes after close
  - promote indices opening within 30 minutes

### OKX / Gate

- Primary engine: WebSocket
- Backup engine: HTTP
- Manual refresh: force HTTP snapshot
- Auto refresh:
  - Baidu always checked by interval
  - OKX/Gate only use HTTP when WebSocket is disconnected

## 4. Proxy Strategy

- Supported proxy types:
  - HTTP
  - SOCKS5
- Current implementation uses `URLSessionConfiguration.connectionProxyDictionary`
- Proxy affects:
  - REST requests
  - WebSocket requests

## 5. Localization Strategy

- Current bilingual support is implemented in-app, not through `.strings` resources
- App language options:
  - Follow System
  - Chinese
  - English
- `MarketStore.text(zh, en)` is used for lightweight UI translation

Recommended future upgrade:

- move strings to dedicated localization resources when the text surface becomes much larger

## 6. Build And Verify

Build:

```bash
xcodebuild -project FloatMarket.xcodeproj -scheme FloatMarket -configuration Debug build
```

Run built app:

```bash
open ~/Library/Developer/Xcode/DerivedData/FloatMarket-*/Build/Products/Debug/FloatMarket.app
```

## 7. Recommended Next Steps

- Replace temporary exchange badges with official logo assets
- Add drag-reorder interaction in watchlist editor
- Add exchange-specific symbol templates and validation
- Add market holiday calendars for more accurate index scheduling
- Add test coverage for schedule sorting and proxy session generation
