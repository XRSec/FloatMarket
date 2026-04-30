# 百度股市通逻辑设计说明

这份文档分三部分：

1. 先说明当前 `FloatMarket` 里百度股市通相关逻辑是怎么跑的。
2. 再说明百度页面前端自己的 `web-socket.js / web-socket-utils.js` 真实做法。
3. 最后给出一套更适合我们项目的设计方案。

---

## 1. 当前本地逻辑梳理

### 1.1 当前入口在哪里

当前百度股市通相关逻辑主要分布在这几个文件：

- `FloatMarket/Data/BaiduGlobalIndexProvider.swift`
- `FloatMarket/Data/AppModels.swift`
- `FloatMarket/MenuBar/MarketStore.swift`

职责大致是：

- `BaiduGlobalIndexProvider.swift`
  负责百度的 HTTP 请求、WSS 订阅、WSS 消息解析。
- `AppModels.swift`
  负责本地"指数交易时段"的静态规则。
- `MarketStore.swift`
  负责调度刷新、维护整体状态、合并快照。

### 1.2 当前 HTTP 逻辑（已迁移到自选 API）

**⚠️ 重要变更：** 当前已不再使用基于 `area` 分组的公开接口。原有接口已失效。

原有失效接口：
- `GET /vapi/v1/globalindexrank` ❌ （需要 `acs-token`，无法获取）
- `GET /api/getbanner` ❌ （需要 `acs-token`，无法获取）
- `GET /sapi/v1/marketquote?bizType=marketStatus` ❌ （需要 `acs-token`，无法获取）

**新的实现方式：**

当前实现改为基于百度自选 API（`selfselect`），流程如下：

1. **获取自选列表**
   - 接口：`GET /selfselect/gethomeinfo`
   - 认证：请求头 `Cookie: BDUSS=...`（用户在设置页手动填写）
   - 返回：`code + market + type + name` 的自选项目列表

2. **获取行情数据**
   - 接口：`POST /selfselect/gettrenddata`
   - 参数：自选项目的 `code` 和 `market`
   - 返回：最新价、昨收、涨跌方向、趋势数据

3. **数据映射**
   - 不再按 `area` 分组
   - 直接使用百度自选返回的项目列表
   - 每个项目独立确定其 transport plan（HTTP / WSS / 混合）

这个改变意味着：
- `area` 字段不再用于数据获取和刷新逻辑
- 监控页面的"地区"分类也不再必要
- 本地 watchlist 仅作为展示配置，不决定数据刷新权限
- 百度自选列表才是数据权限的真实来源

### 1.3 当前 WSS 逻辑

当前实现里，百度 WSS 入口是：

- 地址：`wss://finance-ws.pae.baidu.com`

当前本地只给这些市场构造订阅：

- `us`
- `hk`
- `ab`

并且要求：

- `sourceKind == .baiduGlobalIndex`
- 不是 `foreign`
- `baiduShouldUseStreamNow == true`

`baiduShouldUseStreamNow` 目前不是看百度接口，而是看本地静态交易时间表。

也就是说，当前 WSS 是否启用，主要取决于：

1. 这个品种是否属于本地认定的可订阅市场。
2. 本地静态交易时段是否判断"正在交易"。

### 1.4 当前交易时段来源

这里需要特别说明一下：

- 当前项目里"开盘时间 / 收盘时间"的主要来源不是百度远端接口。
- 现在真正生效的是本地代码里的 `IndexMarketSchedule`。
- 如果用户在设置页给某个指数填了自定义时间，还会叠加 `customOpenTime / customCloseTime` 覆盖默认值。

也就是说，当前我们知道"现在算不算开盘"，主要是靠本地规则判断出来的，不是靠百度返回的实时 market status。

当前内置在 `IndexMarketSchedule` 里的默认时段大致包括：

- 美股：`09:30 - 16:00 America/New_York`
- 日经：`09:00 - 11:30`，`12:30 - 15:00 Asia/Tokyo`
- 港股：`09:30 - 12:00`，`13:00 - 16:00`
- A 股：`09:30 - 11:30`，`13:00 - 15:00`
- 其他指数类似

当前已经内置的 symbol 和默认时段主要有：

- `IXIC` -> Nasdaq
- `DJI / SPX` -> 美股大盘
- `FTSE` -> 英国富时 100
- `CAC` -> 法国 CAC40
- `NK225` -> 日经 225
- `HSI` -> 恒生指数
- `KOSPI` -> 韩国综合指数
- `000001 / 399001` -> A 股
- `DAX` -> 德国 DAX

所以结论是：

- 我们现在是有默认交易时段数据的。
- 这些默认值来自本地代码，不依赖百度远端接口。
- 不过它们是"静态默认表"，适合做调度优化，不适合被理解成绝对真相。

本地规则会结合：

- 默认交易时段
- 当前时间
- 是否已有 snapshot
- 用户自定义开盘时间
- 用户自定义收盘时间

最后产出：

- `trading`
- `openingSoon`
- `waiting`
- `recentlyClosed`
- `closed`

并且给出 `shouldRefresh`。

### 1.5 当前问题的本质

当前实现能工作，但有几个结构性问题：

#### 问题 A：把"静态市场时段"当成了主要真相

这对日经、港股午休、节假日、临时停市、盘前盘后都不够稳。

#### 问题 B：把"数据源状态"做成了单值

百度其实是混合源：

- 有些品种只能 HTTP
- 有些品种可 WSS
- 有些品种当前时段只能 HTTP，盘中才 WSS

但当前 UI 和 store 很容易把整个百度源显示成一个状态，这会误伤：

- 纳指收盘
- 日经开盘但只走 HTTP

这种"同源内不同品种走不同通道"的场景。

#### 问题 C：HTTP 响应类型没有被抽象成"按品类分 adapter"

目前只有：

- 指数 adapter
- 外汇 adapter

但百度前端自己的分类不止这两个，它还有：

- `fund`
- `foreign`
- `futures`
- `block`

而且这些类在前端是明确被当成"轮询型"处理的。

#### 问题 D：远端状态接口没有进入决策链

目前本地已经知道百度前端存在市场状态接口，但我们没有纳入统一决策。

---

## 2. 百度前端真实逻辑

我从百度页面 sourcemap 里抽到了这几个原始文件：

- `webpack://finance-pc/./src/utils/web-socket.js`
- `webpack://finance-pc/./src/utils/web-socket-utils.js`
- `webpack://finance-pc/./src/api/home.js`

### 2.1 百度前端怎么判断是否能开 WSS

`web-socket.js` 里的核心思路不是"支持 WSS 就一直连"，而是三层判断：

1. 先按金融类型分类。
2. 再按市场分类。
3. 再按交易状态决定当前是否允许 WSS。

它明确写了这条规则：

- `fund / foreign / futures / block` 使用轮询方式

也就是说，这四类在百度自己的前端里，就是默认不走 WSS。

### 2.2 百度前端如何拿交易状态

`src/api/home.js` 里有：

- `getMarketStatus()`
- 实际请求：
  - `/sapi/v1/marketquote?bizType=marketStatus`

然后 `web-socket.js` 会每 30 秒轮询一次这个接口。

它看的是每个 `financeType + market` 下的：

- `tradeStatus`
- `websocketEnabled`

只有当：

- `websocketEnabled == 1`
- 且 `tradeStatus` 在以下集合里

才会认为当前允许 WSS：

- `TRADE`
- `POSMT`
- `PRETR`
- `OCALL`

也就是说，百度自己并不是只看"开盘 / 收盘"。
它还区分：

- 盘前
- 盘后
- 集合竞价

### 2.3 百度前端怎么决定"轮询 + WSS 是否并存"

`web-socket-utils.js` 很重要，它说明百度前端本来就支持混合模式。

它的逻辑是：

1. `subscribeJudge(list, cb, isNeedOutMarket)`
   先判断这批品种里哪些能走 WSS，哪些必须轮询。
2. 返回：
   - `list`: 可以走 WSS 的子集
   - `isNeedTraining`: 是否仍需要轮询
3. 上层再决定：
   - 只轮询
   - 只 WSS
   - 轮询 + WSS 同时存在

这个设计很关键。

它不是"整个百度源只选一个通道"，而是"按品种拆 lane"。

### 2.4 百度前端的具体分流规则

从 `subscribeJudge` 可以总结出：

#### 永远 HTTP

- `fund`
- `foreign`
- `futures`
- `block`

#### 条件性 WSS

- `ab`
- `us`
- `hk`

但也不是所有类型都可以：

- `hk` 主要是指数场景
- `ab / us` 也会检查 `financeType` 和 `subType`

#### 其他市场

- 默认回到轮询

这也解释了为什么：

- `NK225`
- `DAX`
- `CAC`
- `KOSPI`

这种全球指数，不应该被简单地归入"百度指数都走 WSS"。

### 2.5 百度前端的 WSS 状态机

它的状态机大概是：

- `CONNECTING`
- `CONNECTED`
- `DISCONNECT`
- `DISABLED`

消息状态则有：

- `CONNECTED`
- `DISCONNECT`
- `RECONNECT`
- `MSG`
- `ERROR`
- `NO_TRADING`

其中 `NO_TRADING` 很关键。

这说明百度前端自己就认为：

- "当前没有交易，不开 WSS"

是一个正常状态，不应该被等同于异常。

这正好对应我们现在 UI 上最容易误报的一类问题。

---

## 3. 建议的设计方案

下面是我建议的设计，不是"修一个 bug"，而是把百度这条线真正建模清楚。

---

## 4. 设计目标

我建议这套逻辑满足五个目标：

1. 同一个 source 内允许不同品种走不同 transport。
2. 本地静态时段只能做兜底，不能做唯一真相。
3. HTTP / WSS / marketStatus 必须拆成三个独立层。
4. "无交易"必须是正常状态，不是异常状态。
5. 各金融类型必须按 adapter 分层，不能继续写死在一个 provider 里堆 if。

---

## 5. 推荐的核心模型

### 5.1 InstrumentCapability

先不要直接问"现在要不要开 WSS"，而是先定义"这个品种理论上支持什么"。

```swift
struct BaiduInstrumentCapability {
    let snapshotKind: SnapshotKind
    let supportsWebSocket: Bool
    let supportsPrePostMarketStream: Bool
    let marketStatusKey: MarketStatusKey?
}
```

建议按类别建能力表：

- `global index (us/hk/ab)`:
  - HTTP: yes
  - WSS: yes
  - marketStatus: yes
- `global index (jp/eu/kr/other)`:
  - HTTP: yes
  - WSS: no
  - marketStatus: optional / unknown
- `foreign`:
  - HTTP: yes
  - WSS: no
- `fund / futures / block`:
  - HTTP: yes
  - WSS: no

### 5.2 MarketStatusSource

再单独定义"交易状态来源"。

```swift
enum MarketStatusSource {
    case remote(BaiduMarketStatus)
    case quoteField(BaiduQuoteStatus)
    case localSchedule(IndexMarketTiming)
    case unknown
}
```

优先级建议是：

1. 远端 `marketStatus` 接口
2. quote / wss 自带状态字段
3. 本地静态交易时段
4. unknown

原因很简单：

- 远端更实时
- quote 字段能反映当前页面真实状态
- 本地 schedule 只能兜底

### 5.3 TransportPlan

有了能力和状态，再生成运输计划。

```swift
struct BaiduTransportPlan {
    let shouldPollHTTP: Bool
    let shouldUseWebSocket: Bool
    let shouldDoHybrid: Bool
    let pollingInterval: TimeInterval
}
```

这一步才是真正的调度决策层。

---

## 6. 推荐的决策顺序

建议把当前逻辑改成固定四步：

### 第一步：从自选列表获取项目

从百度自选 API 获取的项目已经包含：

- `code`（代码）
- `market`（市场，如 `us`, `hk`, `ab`）
- `type`（金融类型）
- `name`（名称）

不再需要按 `area` 预先分组。

### 第二步：查能力表

确定：

- 是否支持 WSS
- HTTP 应该走哪个 endpoint
- 是否可用 marketStatus 远端状态

### 第三步：查实时状态

状态来源优先顺序：

1. `marketStatus`
2. HTTP quote 自带字段
3. WSS quote 自带字段
4. 本地 `IndexMarketSchedule`

### 第四步：生成 transport plan

建议规则如下：

#### 规则 A：永远轮询类

对于这些类型，始终：

- `shouldPollHTTP = true`
- `shouldUseWebSocket = false`

包括：

- `foreign`
- `fund`
- `futures`
- `block`

#### 规则 B：条件性流式类

对于支持 WSS 的 `ab/us/hk` 指数：

- 交易中：`HTTP + WSS`
- 临近开盘：`HTTP`
- 刚收盘：`HTTP`
- 关闭时段：`standby`
- WSS 断线：`HTTP fallback`

这里我建议是 `HTTP + WSS` 并存，而不是二选一。

理由：

- HTTP 是对账快照
- WSS 是增量低延迟
- 两者职责不同

#### 规则 C：不支持流式的全球指数

例如：

- `NK225`
- `DAX`
- `CAC`
- `KOSPI`

建议永远只走 HTTP。

但刷新频率随时段变化：

- 交易中：高频
- 临近开盘：中频
- 刚收盘：短时中频
- 深度闭市：低频或暂停

---

## 7. 推荐的状态机

不要再把百度源状态压成一个 `connected/disconnected`。

建议拆成 lane 状态：

```swift
enum BaiduLaneState {
    case polling
    case streaming
    case hybrid
    case standby
    case degraded
    case failed
}
```

语义建议如下：

- `polling`
  - 当前只有 HTTP 在工作
- `streaming`
  - 当前只有 WSS 在工作
- `hybrid`
  - HTTP 和 WSS 都在工作
- `standby`
  - 当前没到交易时段，或者没有可开流的品种
- `degraded`
  - WSS 掉了，但 HTTP 还活着
- `failed`
  - HTTP 和 WSS 都不可用

这样：

- 纳指收盘
- 日经 HTTP 正常

不应该显示 `异常`，而应该显示：

- 百度源：`polling` 或 `standby + polling`

---

## 8. 推荐的轮询节奏

我建议不要所有 HTTP 一把梭都 15 秒。

应该按"状态 + 品类"分档。

### 8.1 市场状态轮询

`marketStatus`:

- 30 秒一次

这和百度前端自己的节奏一致。

### 8.2 快照轮询

#### 交易中

- 指数：3 到 5 秒
- 外汇：3 到 5 秒
- 基金 / 板块 / 期货：5 到 10 秒

#### 临近开盘 / 临近午盘复开

- 10 到 15 秒

#### 刚收盘

- 15 秒，持续 3 到 5 分钟

#### 深度闭市

- 60 到 300 秒，或者直接暂停

---

## 9. 推荐的数据合并策略

HTTP 和 WSS 不应该互相覆盖成"谁最后来谁赢"。

建议按字段合并。

### 9.1 Snapshot 记录中区分来源

```swift
struct QuoteSnapshot {
    let identity: QuoteIdentity
    let transport: QuoteTransport
    let quote: QuotePayload
    let marketPhase: MarketPhase
    let fetchedAt: Date
}
```

### 9.2 合并规则

- WSS 优先覆盖：
  - 最新价
  - 涨跌额
  - 涨跌幅
  - trade status
- HTTP 优先提供：
  - 静态元数据
  - 不在 WSS 消息中的字段
  - 冷启动首帧
- WSS 断线后：
  - 保留最后一帧
  - 立即触发 HTTP fallback

---

## 10. 推荐的模块拆分

如果后面你要继续让我实现，我建议不是继续堆在 `BaiduGlobalIndexProvider.swift` 里，而是拆成下面几块：

### 10.1 `BaiduCapabilityRegistry`

负责回答：

- 这个品种属于什么金融类型
- 支持什么 transport
- 用哪个 snapshot adapter

### 10.2 `BaiduMarketStatusProvider`

负责：

- 调 `marketStatus`
- 缓存 30 秒
- 提供 `tradeStatus / websocketEnabled`
- 失败时返回 `unknown`

### 10.3 `BaiduSnapshotProvider`

负责：

- 不同 endpoint 的 adapter
- 指数 / 外汇 / 未来的基金 / 期货 / 板块
- `ResultCode / 空结果 / 403 / decode error` 统一归一化

### 10.4 `BaiduStreamProvider`

负责：

- WSS connect / heartbeat / reconnect
- 只处理支持流式的品种
- 输出标准化增量快照

### 10.5 `BaiduTransportPlanner`

负责：

- 输入：
  - capability
  - remote market status
  - local schedule
  - current snapshot availability
- 输出：
  - 当前应该 `poll / stream / hybrid / standby`

这个 planner 才应该是整个百度逻辑的中枢。

---

## 11. 推荐的错误模型

现在的问题之一，是很多失败都被打成"解码失败"。

建议统一成：

```swift
enum BaiduDataError {
    case requestFailed(Error)
    case rejected(resultCode: String)
    case emptyResult
    case decodeFailed(Error)
    case unsupportedCategory
    case marketStatusUnavailable
    case authenticationRequired    // 需要 BDUSS 认证
    case invalidCredentials         // BDUSS 无效或过期
}
```

UI 上再映射成：

- 正常
- 待机
- 降级
- 失败

而不是直接把技术错误原样上屏。

---

## 12. 这套设计最重要的结论

如果只保留一句话，我建议你把百度股市通这条线理解成：

**它不是一个"百度源"，而是一组"按金融类型、市场、交易状态动态切换 transport 的 lane"。**

换句话说：

- `HTTP` 不是 `WSS` 的备胎
- `WSS` 也不是"只要支持就必须开"
- 两者都应该服从：
  - 品类能力
  - 远端交易状态
  - 本地兜底时段

---

## 13. 我建议的最终实现原则

最后给一个我最推荐的版本：

1. 远端 `marketStatus` 作为动态真相（暂不可用，待后续解决 `acs-token` 问题）。
2. 本地 `IndexMarketSchedule` 作为当前唯一稳定的兜底真相。
3. `fund / foreign / futures / block` 永远按轮询 lane 设计。
4. `ab/us/hk` 指数按条件进入 `hybrid`。
5. `jp/eu/kr` 等全球指数默认 `HTTP-only`。
6. 状态展示从"source 单状态"升级成"lane 状态聚合"。
7. 错误从"请求/解码日志"升级成"归一化状态 + 技术详情日志"。

---

## 14. 对当前项目的直接落地顺序

如果下一步要开始改代码，我建议按这个顺序来：

1. 先引入 `BaiduTransportPlanner`
2. 再接入 `marketStatus` provider
3. 再把 snapshot provider 按品类拆 adapter
4. 最后改 UI 状态展示

这样风险最小，也最容易一段一段验证。

---

## 15. 现在更现实的版本：自选 API 方案

结合百度自选 API 的实际情况，设计需要按照以下思路：

- 公开全球指数接口这条路已经不稳定，因为需要 `acs-token`。
- `getquotation / marketStatus / getbanner` 这类接口不是直接 403，就是依赖浏览器态。
- **当前最现实的入口是：**
  - `GET /selfselect/gethomeinfo` - 获取我的自选列表
  - `POST /selfselect/gettrenddata` - 获取自选项目行情
- **认证最小闭环是：**
  - 设置里输入 `BDUSS`
  - 请求头带 `Cookie: BDUSS=...`

这意味着百度这条线不应该再按"公共全球指数源"去设计，而应该按"登录态自选源"去设计。

同时也意味着：

- **不再需要按 `area` 分组** - 自选 API 已经提供了完整的项目列表
- 监控页面的"地区"分类也不再必要
- 新调度应该围绕"自选成员列表"和"transport 覆盖关系"来组织

### 15.1 新的职责划分

我建议把职责改成下面四层：

1. `BaiduFavoritesProvider`
   - 负责调用 `gethomeinfo`
   - 拿到"我的自选"列表
   - 产出远端 `code + market + type + name`

2. `BaiduQuoteProvider`
   - 负责调用 `gettrenddata`
   - 输入是一批自选项目
   - 输出最新价、昨收、涨跌方向、趋势串

3. `BaiduTransportPlanner`
   - 决定某个项目现在走：
     - `http`
     - `wss`
     - `http + wss`
     - `standby`
   - 它不直接发请求，只做规划

4. `BaiduWatchlistMapper`
   - 负责把本地 watch item 和百度自选项目对齐
   - 允许"本地手动添加，但只有远端自选命中的项才算可刷新"

### 15.2 本地 watchlist 应该怎么理解

你现在说"也不需要手动添加百度股市通的指数了，当然也可以"，我建议最终语义是：

- 本地 watchlist 继续保留
  - 因为它承载排序、显示名、开收盘自定义、小窗固定这些 UI 属性
- 但百度数据是否可刷新，不再只看本地有没有这个 symbol
- 还要看它是否存在于当前 `gethomeinfo` 返回的自选列表

也就是：

- 本地 item = 展示配置
- 百度自选 = 数据权限与远端可见性

这样设计的好处是：

- 你仍然可以本地提前放一个 `NK225`
- 但如果百度自选里没有它，就显示为"未在百度自选中"
- 一旦你在百度网页里加进自选，客户端下次同步就自动激活

### 15.3 开盘时间怎么处理

开盘时间接口目前需要 `acs-token`，无法直接获取。最稳妥的策略不是硬攻，而是把"开盘判断"从核心依赖降成调度优化：

1. 本地 `IndexMarketSchedule` 继续保留
   - 作为当前唯一稳定的交易时段来源
   - 具体代码来源就是 `FloatMarket/Data/AppModels.swift`
   - 如果用户给某个指数设置了 `customOpenTime / customCloseTime`，就以用户配置优先
2. 但它不再决定"HTTP 能不能刷"
   - HTTP 默认可以按定时任务持续刷新
3. 它主要决定两件事
   - WSS 现在该不该开
   - 当前这轮 HTTP 有没有资格被优化跳过
4. 如果未来拿得到远端 `marketStatus`
   - 再把它升级成更高优先级的动态真相

换句话说，现阶段不要把"拿不到远端 marketStatus"当成失败，而应该把它当成系统的标准运行模式。

### 15.4 HTTP 和 WSS 的推荐规则

在自选 API 前提下，我建议这样分：

1. `gethomeinfo`
   - 低频请求
   - 作用：同步"我的自选"成员关系
   - 刷新时机：
     - 应用启动
     - 设置保存后
     - 每 5 到 10 分钟一次

2. `gettrenddata`
   - 中频请求
   - 作用：拿最新价和趋势
   - 刷新时机：
     - 默认按全局轮询间隔执行
     - 不再强依赖"是否开盘"才能发
     - 只有在"WSS 已覆盖的项目不需要 HTTP，剩余 HTTP-only 项目也全部不在交易时段"时，才允许跳过本轮刷新

3. 百度 WSS
   - 只给确认支持的项目开
   - 只在本地规则判断为交易中时开
   - 没有可开流项目时进入 `standby`
   - 断流后做一次 `gettrenddata` 补快照

这里再强调一次新的主视角：

- HTTP/WSS 的规划单位不再是 `area`
- 而是"当前自选里的每一个 item"
- 每个 item 都有自己的 transport 结论：
  - `streamCovered`
  - `httpOnly`
  - `dual`
  - `standby`

### 15.5 一条更贴近你现在想法的调度规则

如果把这套逻辑写成一句更直接的话，我建议是：

1. 每轮定时器先从自选列表准备项目（不再按 `area` 分组）
2. 把其中"当前可走 WSS 且已被 WSS 覆盖"的项目记为 `streamCovered`
3. 把剩下必须依赖 HTTP 的项目记为 `httpResidual`
4. 默认对 `httpResidual` 做 `gettrenddata`
5. 只有当 `httpResidual` 非空且全部处于本地非交易时段时，才跳过这轮 HTTP
6. 如果 `httpResidual` 为空
   - 说明这轮所有项目都已经被 WSS 覆盖
   - 这时 HTTP 可以不跑，或者只保留低频兜底同步

这样能同时满足三件事：

- HTTP 不会因为"开盘判断不准"而完全停掉
- WSS 能继续承担盘中的实时覆盖
- 非交易时段又不会对纯 HTTP 项目做无意义高频刷新

### 15.6 一个更贴近当前现实的状态机

我建议百度源状态不要再只显示"已连接/已断开"，而是下面几个：

- `favoritesMissing`
  - 没填 `BDUSS`
- `favoritesSyncing`
  - 正在拉 `gethomeinfo`
- `favoritesReady`
  - 已同步到自选，可进行 HTTP/WSS 规划
- `polling`
  - 当前只有 HTTP 在工作
- `hybrid`
  - 当前同时有 HTTP 和 WSS
- `standby`
  - 当前没有应开流项目，但系统正常
- `degraded`
  - 自选已同步，但报价接口失败
- `failed`
  - `BDUSS` 无效或请求被彻底拒绝

这样"纳指收盘了，不需要 wss；日经开盘了，但是日经是 http"就会自然落在 `polling`，而不是误显示成异常。

### 15.7 最推荐的落地顺序

按现在这个新前提，我建议实现顺序改成：

1. 设置页增加 `BDUSS` 输入
2. 引入 `gethomeinfo` 同步层
3. 把百度 item 刷新资格改成"本地启用 + 远端自选命中"
4. 把 HTTP 报价入口逐步切到 `gettrenddata`
5. 移除监控页面的"地区"分类（不再使用 `area` 分组）
6. 最后再收敛 WSS 规划和 UI 状态机

这个顺序比一上来硬改 WSS 更稳，因为它先把"能不能拿到有效数据"这个前提打牢了。

### 15.8 关键改变总结

| 方面 | 旧方案（已废弃） | 新方案（当前） |
|------|-----------------|----------------|
| 数据来源 | 公开 API（`/vapi/v1/globalindexrank`） | 自选 API（`/selfselect/gethomeinfo` + `gettrenddata`） |
| 认证方式 | 无（公开接口） | BDUSS Cookie（用户手动填写） |
| 项目分组 | 按 `area` 分组（美股/港股/亚洲等） | 直接使用自选列表（无需分组） |
| 监控页面地区 | 显示地区分类 | 移除地区分类（不再需要） |
| 调度单位 | 按 `area` | 按自选项目 |
| 权限判断 | 本地配置 | 本地配置 + 远端自选列表 |

---

## 16. 当前已知的技术债

1. **marketStatus 接口不可用** - 需要 `acs-token`，短期内无法解决
2. **area 字段遗留** - 可保留用于向后兼容，但不应再用于核心逻辑
3. **监控页面重构** - 需要移除地区分类，改为自选项目列表展示
