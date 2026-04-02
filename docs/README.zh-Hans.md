# FloatMarket / 浮市

[English](./README.md) | [GitHub 仓库](https://github.com/XRSec/FloatMarket) | [开发文档](./DEVELOPMENT_GUIDE.md) | [工程规范](./ENGINEERING_STANDARDS.md)

FloatMarket 是一款面向 macOS 的悬浮行情看板，目标是让你在桌面上快速扫一眼就能知道市场状态。

它把全球指数、加密货币现货和永续合约整合到一个常驻悬浮窗里，同时提供独立的设置窗口，用来管理主题、布局、数据源、监控项和代理。

## 软件能做什么

- 提供一个适合盯盘的悬浮窗口。
- 支持迷你小窗和展开看板两种形态。
- 在同一份监控列表里同时追踪全球指数、现货和永续。
- 双击条目直接打开对应网页，默认快捷链接也支持自行修改。
- 把设置、监控项、代理和窗口外观保存到本地 JSON 文件。

## 主要特性

- 悬浮窗和小窗分别支持独立的字体大小与背景透明度。
- 支持中文、英文和跟随系统语言。
- 悬浮窗支持浅色、深色和跟随系统主题。
- 内置常见指数和热门币对模板，不需要手动从零录入。
- 支持 HTTP 与 SOCKS5 代理，并提供测试按钮。
- 采用菜单栏应用工作流，可快速打开设置、显示或隐藏悬浮窗、退出应用。

## 界面预览

<p align="center">
  <img src="./Floating%20Window.png" alt="Floating Window" width="31%" />
  <img src="./Settings%20View.png" alt="Settings View" width="31%" />
  <img src="./Appearance.png" alt="Appearance" width="31%" />
</p>
<p align="center">
  <img src="./Watchlist.png" alt="Watchlist" width="31%" />
  <img src="./Data%20Source.png" alt="Data Source" width="31%" />
  <img src="./Logs.png" alt="Logs" width="31%" />
</p>

## 支持的数据

### 全球指数

- `百度股市通`
- `新浪财经`

内置模板覆盖了常见标的，例如：

- `IXIC`
- `DJI`
- `SPX`
- `FTSE`
- `DAX`
- `CAC`
- `NK225`
- `HSI`
- `KOSPI`
- `000001`
- `399001`
- `DINIW`
- `USDCNY`
- `USDCNH`

### 加密货币

- `OKX`
  - 现货模板：`BTC`、`ETH`、`SOL`、`XRP`、`DOGE`
  - 永续模板：`BTC 永续`、`ETH 永续`、`SOL 永续`、`XRP 永续`、`DOGE 永续`
- `Gate`
  - 现货模板：`BTC`、`ETH`、`SOL`、`XRP`、`DOGE`
  - 永续模板：`BTC 永续`、`ETH 永续`、`SOL 永续`、`XRP 永续`、`DOGE 永续`
- `Binance`
  - 现货模板：`BTC`、`ETH`、`SOL`、`XRP`、`DOGE`
  - 永续模板：`BTC 永续`、`ETH 永续`、`SOL 永续`、`XRP 永续`、`DOGE 永续`

全球指数和仅支持快照的行情源使用定时轮询；WebSocket 行情默认不做定时刷新，只会在断连或重连后补一次 HTTP 快照同步。

## 使用体验

- 展开态悬浮窗会按区块分组显示：
  - `全球指数`
  - `现货`
  - `永续`
- 小窗可以固定指定条目，也可以自动回退到第一条可用行情。
- 全球指数区块支持在展开态里继续“展开 / 收起”。
- 设置窗口可调整：
  - 主题
  - 透明度
  - 宽度
  - 最大高度
  - 小窗显示模式
  - 数据源地址
  - 监控项
  - 代理测试
- 日志页会重点记录：
  - WebSocket 断连后的补快照
  - WebSocket 重连后的重同步
  - 请求失败、回退和解码错误

## 项目结构

```text
FloatMarket/
├── FloatMarket/
│   ├── About/
│   ├── Commands/
│   ├── Data/
│   ├── MenuBar/
│   ├── Panes/
│   ├── Settings/
│   ├── Sidebar/
│   ├── Utilities/
│   ├── Windowing/
│   ├── MainScene.swift
│   └── MainView.swift
├── docs/
├── dmg-assets/
├── scripts/
├── FloatMarket.xcodeproj
├── Makefile
├── README.md
└── README.zh-Hans.md
```

## 构建与运行

用 Xcode 打开项目：

```bash
open FloatMarket.xcodeproj
```

命令行构建 Debug：

```bash
make build-debug
```

启动 Debug 版本：

```bash
make debug
```

打包 DMG：

```bash
make dmg
```

## 配置与存储

- 设置文件保存在：
  - `~/Library/Application Support/FloatMarket/settings.json`
- 应用自带默认监控项模板。
- 默认模板添加后依然可以修改或删除。
- 每个监控项的快捷链接都有默认值，但用户可以自行覆盖。

## 自定义说明

### 如何添加自定义监控项

大多数情况下不用从空白条目开始，先选一个接近的预设再改会更快。

1. 从菜单栏或悬浮窗打开设置窗口。
2. 进入 `监控 / Watchlist` 页面。
3. 点击 `Add`，先选一个最接近的内置预设。
4. 在右侧详情里按需修改：
   - `Display Name`
   - `Source`
   - `Symbol / Contract`
   - 百度全球指数专用的 `Region`
   - `Quick Link URL`
5. 保持启用状态，这样它才会显示在悬浮窗里。
6. 如果需要，也可以顺手固定到 `Mini Window`。
7. 最后保存设置。

详情页顶部的 `Preset` 也可以当作快捷入口：先选模板，再覆盖其中你想改的字段。

### 如何添加自定义语言

自定义语言不是在设置页里直接新增，而是通过给应用添加新的语言包目录实现的。

目录路径放在：

- `FloatMarket/<语言代码>.lproj/`

建议至少包含这两个文件：

- `FloatMarket/<语言代码>.lproj/Localizable.strings`
- `FloatMarket/<语言代码>.lproj/InfoPlist.strings`

注意点：

- `Localizable.strings` 里必须提供 `Language Self Name`
- 目录名要符合 Apple 本地化规则，例如：
  - `en.lproj`
  - `zh-Hans.lproj`
  - `ja.lproj`
- 新语言目录加入后，需要重新构建应用

只要新的 `.lproj` 被打进应用包里，FloatMarket 就会自动读取它，并把它显示到应用菜单和设置页的语言列表中。

示例：

```text
FloatMarket/fr.lproj/
├── InfoPlist.strings
└── Localizable.strings
```

`Localizable.strings` 头部示例：

```text
"Language Self Name" = "Français";
```

## 开发补充

如果你要继续开发而不是只使用软件，可以看：

- [开发文档](./DEVELOPMENT_GUIDE.md)
- [工程规范](./ENGINEERING_STANDARDS.md)
- [DMG 资源说明](../dmg-assets/README.md)

## 开源协议

本项目采用 [MIT License](../LICENSE)。
