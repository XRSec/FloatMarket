import Foundation
import SwiftUI

enum MarketInstrumentKind: String, Codable, CaseIterable, Identifiable {
    case globalIndex
    case spot
    case perpetual

    var id: String { rawValue }
}

enum DataSourceKind: String, Codable, CaseIterable, Identifiable {
    case baiduGlobalIndex
    case sinaGlobalIndex
    case okxSpotMarket
    case okxSpot
    case gateSpotMarket
    case gateSpot
    case binanceSpot
    case binancePerp

    var id: String { rawValue }

    var instrumentKind: MarketInstrumentKind {
        switch self {
        case .baiduGlobalIndex, .sinaGlobalIndex:
            return .globalIndex
        case .okxSpotMarket, .gateSpotMarket, .binanceSpot:
            return .spot
        case .okxSpot, .gateSpot, .binancePerp:
            return .perpetual
        }
    }

    var title: String {
        switch self {
        case .baiduGlobalIndex:
            return NSLocalizedString("Baidu Gushitong", comment: "")
        case .sinaGlobalIndex:
            return NSLocalizedString("Sina Finance", comment: "")
        case .okxSpotMarket:
            return NSLocalizedString("OKX Spot", comment: "")
        case .okxSpot:
            return NSLocalizedString("OKX Perpetual", comment: "")
        case .gateSpotMarket:
            return NSLocalizedString("Gate Spot", comment: "")
        case .gateSpot:
            return NSLocalizedString("Gate Perpetual", comment: "")
        case .binanceSpot:
            return NSLocalizedString("Binance Spot", comment: "")
        case .binancePerp:
            return NSLocalizedString("Binance Perpetual", comment: "")
        }
    }

    var symbolExample: String {
        switch self {
        case .baiduGlobalIndex:
            return "IXIC"
        case .sinaGlobalIndex:
            return "IXIC"
        case .okxSpotMarket:
            return "ETH-USDT"
        case .okxSpot:
            return "ETH-USDT-SWAP"
        case .gateSpotMarket:
            return "ETH_USDT"
        case .gateSpot:
            return "ETH_USDT"
        case .binanceSpot:
            return "ETHUSDT"
        case .binancePerp:
            return "ETHUSDT"
        }
    }
}

enum FloatingThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    var title: String {
        switch self {
        case .system:
            return NSLocalizedString("Follow System", comment: "")
        case .dark:
            return NSLocalizedString("Dark", comment: "")
        case .light:
            return NSLocalizedString("Light", comment: "")
        }
    }
}

enum FloatingBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case graphite
    case aurora
    case paper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphite:
            return NSLocalizedString("Graphite", comment: "")
        case .aurora:
            return NSLocalizedString("Aurora", comment: "")
        case .paper:
            return NSLocalizedString("Paper", comment: "")
        }
    }
}

enum FloatingTextPalette: String, Codable, CaseIterable, Identifiable {
    case followTheme
    case ice
    case amber
    case mint
    case rose
    case lavender
    case gold
    case sky
    case coral

    var id: String { rawValue }
}

enum PriceColorStyle: String, Codable, CaseIterable, Identifiable {
    case redUpGreenDown
    case greenUpRedDown

    var id: String { rawValue }
}

extension FloatingThemeMode {
    func resolvedColorScheme(systemColorScheme: ColorScheme) -> ColorScheme {
        preferredColorScheme ?? systemColorScheme
    }
}

extension FloatingBackgroundStyle {
    func gradientColors(for colorScheme: ColorScheme, isCollapsed: Bool) -> [Color] {
        switch (colorScheme, self, isCollapsed) {
        case (.dark, .graphite, true):
            return [
                Color(red: 0.24, green: 0.25, blue: 0.30),
                Color(red: 0.19, green: 0.20, blue: 0.24)
            ]
        case (.dark, .graphite, false):
            return [
                Color(red: 0.18, green: 0.19, blue: 0.22),
                Color(red: 0.13, green: 0.14, blue: 0.17)
            ]
        case (.dark, .aurora, true):
            return [
                Color(red: 0.18, green: 0.23, blue: 0.31),
                Color(red: 0.12, green: 0.17, blue: 0.24)
            ]
        case (.dark, .aurora, false):
            return [
                Color(red: 0.14, green: 0.18, blue: 0.24),
                Color(red: 0.09, green: 0.12, blue: 0.17)
            ]
        case (.dark, .paper, true):
            return [
                Color(red: 0.27, green: 0.24, blue: 0.22),
                Color(red: 0.20, green: 0.18, blue: 0.16)
            ]
        case (.dark, .paper, false):
            return [
                Color(red: 0.20, green: 0.18, blue: 0.16),
                Color(red: 0.15, green: 0.13, blue: 0.12)
            ]
        case (.light, .graphite, true):
            return [
                Color(red: 0.98, green: 0.98, blue: 0.99),
                Color(red: 0.94, green: 0.95, blue: 0.96)
            ]
        case (.light, .graphite, false):
            return [
                Color(red: 0.97, green: 0.97, blue: 0.98),
                Color(red: 0.93, green: 0.94, blue: 0.95)
            ]
        case (.light, .aurora, true):
            return [
                Color(red: 0.97, green: 0.99, blue: 1.00),
                Color(red: 0.91, green: 0.95, blue: 0.99)
            ]
        case (.light, .aurora, false):
            return [
                Color(red: 0.95, green: 0.98, blue: 1.00),
                Color(red: 0.89, green: 0.93, blue: 0.98)
            ]
        case (.light, .paper, true):
            return [
                Color(red: 1.00, green: 0.98, blue: 0.96),
                Color(red: 0.97, green: 0.94, blue: 0.91)
            ]
        case (.light, .paper, false):
            return [
                Color(red: 0.99, green: 0.97, blue: 0.94),
                Color(red: 0.96, green: 0.93, blue: 0.89)
            ]
        @unknown default:
            return [
                Color(red: 0.97, green: 0.97, blue: 0.98),
                Color(red: 0.93, green: 0.94, blue: 0.95)
            ]
        }
    }
}

extension FloatingTextPalette {
    func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .followTheme:
            return .primary
        case .ice:
            return colorScheme == .dark ? Color(red: 0.85, green: 0.96, blue: 1.0) : Color(red: 0.12, green: 0.35, blue: 0.48)
        case .amber:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.90, blue: 0.70) : Color(red: 0.56, green: 0.34, blue: 0.08)
        case .mint:
            return colorScheme == .dark ? Color(red: 0.82, green: 1.0, blue: 0.93) : Color(red: 0.10, green: 0.42, blue: 0.32)
        case .rose:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.78, blue: 0.84) : Color(red: 0.72, green: 0.10, blue: 0.28)
        case .lavender:
            return colorScheme == .dark ? Color(red: 0.88, green: 0.82, blue: 1.0) : Color(red: 0.38, green: 0.22, blue: 0.72)
        case .gold:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.84, blue: 0.40) : Color(red: 0.62, green: 0.42, blue: 0.02)
        case .sky:
            return colorScheme == .dark ? Color(red: 0.72, green: 0.90, blue: 1.0) : Color(red: 0.08, green: 0.42, blue: 0.72)
        case .coral:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.76, blue: 0.66) : Color(red: 0.72, green: 0.26, blue: 0.10)
        }
    }

    func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        primaryTextColor(for: colorScheme).opacity(colorScheme == .dark ? 0.72 : 0.76)
    }

    func tertiaryTextColor(for colorScheme: ColorScheme) -> Color {
        primaryTextColor(for: colorScheme).opacity(colorScheme == .dark ? 0.48 : 0.52)
    }
}

extension PriceColorStyle {
    func upColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .redUpGreenDown:
            return colorScheme == .dark
                ? Color(red: 0.91, green: 0.46, blue: 0.44)
                : Color(red: 0.90, green: 0.34, blue: 0.34)
        case .greenUpRedDown:
            return colorScheme == .dark
                ? Color(red: 0.39, green: 0.80, blue: 0.57)
                : Color(red: 0.27, green: 0.83, blue: 0.54)
        }
    }

    func downColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .redUpGreenDown:
            return colorScheme == .dark
                ? Color(red: 0.39, green: 0.80, blue: 0.57)
                : Color(red: 0.27, green: 0.83, blue: 0.54)
        case .greenUpRedDown:
            return colorScheme == .dark
                ? Color(red: 0.91, green: 0.46, blue: 0.44)
                : Color(red: 0.90, green: 0.34, blue: 0.34)
        }
    }

    func neutralColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.72) : Color.black.opacity(0.62)
    }
}

enum CollapsedDisplayMode: String, Codable, CaseIterable, Identifiable {
    case priceOnly
    case symbolAndPrice

    var id: String { rawValue }
}

enum ProxyType: String, Codable, CaseIterable, Identifiable {
    case http
    case socks5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .http:
            return "HTTP"
        case .socks5:
            return "SOCKS5"
        }
    }
}

enum BaiduArea: String, Codable, CaseIterable, Identifiable {
    case america
    case asia
    case europeafrica
    case foreign
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .america:
            return NSLocalizedString("Americas", comment: "")
        case .asia:
            return NSLocalizedString("Asia", comment: "")
        case .europeafrica:
            return NSLocalizedString("Europe & Africa", comment: "")
        case .foreign:
            return NSLocalizedString("Foreign Exchange", comment: "")
        case .all:
            return NSLocalizedString("All", comment: "")
        }
    }
}

enum LogLevel: String, Codable {
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .info:
            return Color(red: 0.34, green: 0.73, blue: 0.98)
        case .warning:
            return Color(red: 0.98, green: 0.72, blue: 0.25)
        case .error:
            return Color(red: 0.96, green: 0.37, blue: 0.35)
        }
    }
}

struct AppLocalizationOption: Identifiable, Hashable {
    let code: String
    let displayName: String

    var id: String { code }
}

enum AppLocalizationCatalog {
    private static let selfNameKey = "Language Self Name"

    static var availableOptions: [AppLocalizationOption] {
        let codes = Bundle.main.localizations
            .filter { $0 != "Base" }
            .reduce(into: [String]()) { result, code in
                if !result.contains(code) {
                    result.append(code)
                }
            }

        return codes
            .map { AppLocalizationOption(code: $0, displayName: displayName(for: $0)) }
            .sorted { lhs, rhs in
                if lhs.code == "en" { return true }
                if rhs.code == "en" { return false }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    static var currentSelectedCode: String {
        let rawCode = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first
        return normalizedCode(from: rawCode) ?? "auto"
    }

    static func normalizedCode(from rawCode: String?) -> String? {
        guard let rawCode else { return nil }
        return availableOptions
            .map(\.code)
            .first { rawCode == $0 || rawCode.hasPrefix($0 + "-") }
    }

    static func displayName(for code: String) -> String {
        if let bundle = bundle(for: code) {
            let value = NSLocalizedString(selfNameKey, tableName: nil, bundle: bundle, value: selfNameKey, comment: "")
            if value != selfNameKey {
                return value
            }
        }

        return Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }

    private static func bundle(for code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}

struct EndpointConfiguration: Codable, Equatable {
    var primaryURL: String
    var backupURL: String = ""
    var timeout: Double = 8
    var primaryWebSocketURL: String = ""
    var backupWebSocketURL: String = ""
    var bduss: String = ""
    var useProxy = false

    enum CodingKeys: String, CodingKey {
        case primaryURL
        case backupURL
        case timeout
        case primaryWebSocketURL
        case backupWebSocketURL
        case bduss
        case useProxy
    }

    var candidateBaseURLs: [String] {
        [primaryURL, backupURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, element in
                if !result.contains(element) {
                    result.append(element)
                }
            }
    }

    var candidateWebSocketURLs: [String] {
        [primaryWebSocketURL, backupWebSocketURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, element in
                if !result.contains(element) {
                    result.append(element)
                }
            }
    }

    var trimmedBDUSS: String {
        bduss.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasBDUSS: Bool {
        !trimmedBDUSS.isEmpty
    }
}

struct WatchItemTemplate: Identifiable, Hashable {
    let sourceKind: DataSourceKind
    let displayName: String
    let symbol: String
    let area: BaiduArea?
    let defaultURL: String?

    var id: String { "\(sourceKind.rawValue):\(symbol)" }
}

enum WatchItemTemplateCatalog {
    static let defaultWatchlistTemplates: [WatchItemTemplate] = [
        baiduNasdaq,
        baiduFTSE,
        baiduNikkei,
        baiduDAX,
        okxETH,
        okxBTC,
        gateETH,
        gateBTC,
    ]

    static func templates(for sourceKind: DataSourceKind) -> [WatchItemTemplate] {
        allTemplates.filter { $0.sourceKind == sourceKind }
    }

    static func template(for sourceKind: DataSourceKind, symbol: String, area: BaiduArea?) -> WatchItemTemplate? {
        templates(for: sourceKind).first {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame &&
            $0.area == area
        }
    }

    static func defaultQuickLinkURL(sourceKind: DataSourceKind, symbol: String, area: BaiduArea? = nil) -> String? {
        template(for: sourceKind, symbol: symbol, area: area)?.defaultURL
    }

    static func sinaQuoteListCode(for symbol: String) -> String? {
        switch symbol.uppercased() {
        case "DJI":
            return "gb_$dji"
        case "INX":
            return "gb_$inx"
        case "IXIC":
            return "gb_$ixic"
        case "FTSE":
            return "znb_UKX"
        case "DAX":
            return "znb_DAX"
        case "NK225":
            return "znb_NKY"
        case "TOPIX":
            return "znb_TOPIX"
        case "KOSPI":
            return "znb_KOSPI"
        default:
            return nil
        }
    }

    private static let baiduNasdaq = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Nasdaq", comment: ""),
        symbol: "IXIC",
        area: .america,
        defaultURL: "https://gushitong.baidu.com/index/us-IXIC"
    )
    private static let baiduDowJones = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Dow Jones", comment: ""),
        symbol: "DJI",
        area: .america,
        defaultURL: "https://gushitong.baidu.com/index/us-DJI"
    )
    private static let baiduSP500 = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("S&P 500", comment: ""),
        symbol: "SPX",
        area: .america,
        defaultURL: "https://gushitong.baidu.com/index/us-SPX"
    )
    private static let baiduFTSE = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("FTSE 100", comment: ""),
        symbol: "FTSE",
        area: .europeafrica,
        defaultURL: "https://gushitong.baidu.com/globalIndex/uk-FTSE"
    )
    private static let baiduCAC = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("CAC 40", comment: ""),
        symbol: "CAC",
        area: .europeafrica,
        defaultURL: "https://gushitong.baidu.com/globalIndex/fr-CAC"
    )
    private static let baiduNikkei = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Nikkei 225", comment: ""),
        symbol: "NK225",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/globalIndex/jp-NK225"
    )
    private static let baiduHangSeng = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Hang Seng", comment: ""),
        symbol: "HSI",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/globalIndex/hk-HSI"
    )
    private static let baiduKOSPI = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("KOSPI", comment: ""),
        symbol: "KOSPI",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/globalIndex/kr-KOSPI"
    )
    private static let baiduShanghai = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Shanghai Composite", comment: ""),
        symbol: "000001",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/index/ab-000001"
    )
    private static let baiduShenzhen = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("Shenzhen Component", comment: ""),
        symbol: "399001",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/index/ab-399001"
    )
    private static let baiduA50 = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("FTSE China A50", comment: ""),
        symbol: "XIN9.LOC-FTX",
        area: .asia,
        defaultURL: "https://gushitong.baidu.com/globalIndex/sg-XIN9.LOC-FTX"
    )
    private static let baiduDollarIndex = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("US Dollar Index", comment: ""),
        symbol: "DINIW",
        area: .foreign,
        defaultURL: "https://gushitong.baidu.com/forex/global-DINIW"
    )
    private static let baiduUSDCNY = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("USD/CNY", comment: ""),
        symbol: "USDCNY",
        area: .foreign,
        defaultURL: "https://gushitong.baidu.com/forex/global-USDCNY"
    )
    private static let baiduUSDCNH = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("USD/CNH", comment: ""),
        symbol: "USDCNH",
        area: .foreign,
        defaultURL: "https://gushitong.baidu.com/forex/global-USDCNH"
    )
    private static let baiduEURCNY = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("EUR/CNY", comment: ""),
        symbol: "EURCNY",
        area: .foreign,
        defaultURL: "https://gushitong.baidu.com/forex/global-EURCNY"
    )
    private static let baiduUSDGBP = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("USD/GBP", comment: ""),
        symbol: "USDGBP",
        area: .foreign,
        defaultURL: "https://gushitong.baidu.com/forex/global-USDGBP"
    )
    private static let baiduDAX = WatchItemTemplate(
        sourceKind: .baiduGlobalIndex,
        displayName: NSLocalizedString("German DAX", comment: ""),
        symbol: "DAX",
        area: .europeafrica,
        defaultURL: "https://gushitong.baidu.com/globalIndex/de-DAX"
    )

    private static let sinaDJI = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("Dow Jones", comment: ""),
        symbol: "DJI",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=gb_$dji"
    )
    private static let sinaINX = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("S&P 500", comment: ""),
        symbol: "INX",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=gb_$inx"
    )
    private static let sinaNasdaq = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("Nasdaq", comment: ""),
        symbol: "IXIC",
        area: nil,
        defaultURL: "https://gu.sina.cn/quotes/us/IXIC"
    )
    private static let sinaFTSE = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("FTSE 100", comment: ""),
        symbol: "FTSE",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=znb_UKX"
    )
    private static let sinaNikkei = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("Nikkei 225", comment: ""),
        symbol: "NK225",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=znb_NKY"
    )
    private static let sinaDAX = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("German DAX", comment: ""),
        symbol: "DAX",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=znb_DAX"
    )
    private static let sinaTOPIX = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("TOPIX", comment: ""),
        symbol: "TOPIX",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=znb_TOPIX"
    )
    private static let sinaKOSPI = WatchItemTemplate(
        sourceKind: .sinaGlobalIndex,
        displayName: NSLocalizedString("KOSPI", comment: ""),
        symbol: "KOSPI",
        area: nil,
        defaultURL: "https://w.sinajs.cn/list=znb_KOSPI"
    )

    private static let okxETH = WatchItemTemplate(
        sourceKind: .okxSpot,
        displayName: NSLocalizedString("ETH Perpetual", comment: ""),
        symbol: "ETH-USDT-SWAP",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-swap/eth-usdt-swap"
    )
    private static let okxBTC = WatchItemTemplate(
        sourceKind: .okxSpot,
        displayName: NSLocalizedString("BTC Perpetual", comment: ""),
        symbol: "BTC-USDT-SWAP",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-swap/btc-usdt-swap#workspaceId=1775038896923"
    )
    private static let okxSOL = WatchItemTemplate(
        sourceKind: .okxSpot,
        displayName: NSLocalizedString("SOL Perpetual", comment: ""),
        symbol: "SOL-USDT-SWAP",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-swap/sol-usdt-swap"
    )
    private static let okxXRP = WatchItemTemplate(
        sourceKind: .okxSpot,
        displayName: NSLocalizedString("XRP Perpetual", comment: ""),
        symbol: "XRP-USDT-SWAP",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-swap/xrp-usdt-swap"
    )
    private static let okxDOGE = WatchItemTemplate(
        sourceKind: .okxSpot,
        displayName: NSLocalizedString("DOGE Perpetual", comment: ""),
        symbol: "DOGE-USDT-SWAP",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-swap/doge-usdt-swap"
    )
    private static let okxSpotBTC = WatchItemTemplate(
        sourceKind: .okxSpotMarket,
        displayName: "BTC",
        symbol: "BTC-USDT",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-spot/btc-usdt"
    )
    private static let okxSpotETH = WatchItemTemplate(
        sourceKind: .okxSpotMarket,
        displayName: "ETH",
        symbol: "ETH-USDT",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-spot/eth-usdt"
    )
    private static let okxSpotSOL = WatchItemTemplate(
        sourceKind: .okxSpotMarket,
        displayName: "SOL",
        symbol: "SOL-USDT",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-spot/sol-usdt"
    )
    private static let okxSpotXRP = WatchItemTemplate(
        sourceKind: .okxSpotMarket,
        displayName: "XRP",
        symbol: "XRP-USDT",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-spot/xrp-usdt"
    )
    private static let okxSpotDOGE = WatchItemTemplate(
        sourceKind: .okxSpotMarket,
        displayName: "DOGE",
        symbol: "DOGE-USDT",
        area: nil,
        defaultURL: "https://www.okx.com/zh-hans/trade-spot/doge-usdt"
    )
    private static let gateETH = WatchItemTemplate(
        sourceKind: .gateSpot,
        displayName: NSLocalizedString("ETH Perpetual", comment: ""),
        symbol: "ETH_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/futures/USDT/ETH_USDT"
    )
    private static let gateBTC = WatchItemTemplate(
        sourceKind: .gateSpot,
        displayName: NSLocalizedString("BTC Perpetual", comment: ""),
        symbol: "BTC_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/futures/USDT/BTC_USDT"
    )
    private static let gateSOL = WatchItemTemplate(
        sourceKind: .gateSpot,
        displayName: NSLocalizedString("SOL Perpetual", comment: ""),
        symbol: "SOL_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/futures/USDT/SOL_USDT"
    )
    private static let gateXRP = WatchItemTemplate(
        sourceKind: .gateSpot,
        displayName: NSLocalizedString("XRP Perpetual", comment: ""),
        symbol: "XRP_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/futures/USDT/XRP_USDT"
    )
    private static let gateDOGE = WatchItemTemplate(
        sourceKind: .gateSpot,
        displayName: NSLocalizedString("DOGE Perpetual", comment: ""),
        symbol: "DOGE_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/futures/USDT/DOGE_USDT"
    )
    private static let gateSpotBTC = WatchItemTemplate(
        sourceKind: .gateSpotMarket,
        displayName: "BTC",
        symbol: "BTC_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/trade/BTC_USDT"
    )
    private static let gateSpotETH = WatchItemTemplate(
        sourceKind: .gateSpotMarket,
        displayName: "ETH",
        symbol: "ETH_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/trade/ETH_USDT"
    )
    private static let gateSpotSOL = WatchItemTemplate(
        sourceKind: .gateSpotMarket,
        displayName: "SOL",
        symbol: "SOL_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/trade/SOL_USDT"
    )
    private static let gateSpotXRP = WatchItemTemplate(
        sourceKind: .gateSpotMarket,
        displayName: "XRP",
        symbol: "XRP_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/trade/XRP_USDT"
    )
    private static let gateSpotDOGE = WatchItemTemplate(
        sourceKind: .gateSpotMarket,
        displayName: "DOGE",
        symbol: "DOGE_USDT",
        area: nil,
        defaultURL: "https://www.gate.com/zh/trade/DOGE_USDT"
    )
    private static let binanceETH = WatchItemTemplate(
        sourceKind: .binancePerp,
        displayName: NSLocalizedString("ETH Perpetual", comment: ""),
        symbol: "ETHUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/futures/ethusdt"
    )
    private static let binanceBTC = WatchItemTemplate(
        sourceKind: .binancePerp,
        displayName: NSLocalizedString("BTC Perpetual", comment: ""),
        symbol: "BTCUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/futures/btcusdt"
    )
    private static let binanceSOL = WatchItemTemplate(
        sourceKind: .binancePerp,
        displayName: NSLocalizedString("SOL Perpetual", comment: ""),
        symbol: "SOLUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/futures/solusdt"
    )
    private static let binanceXRP = WatchItemTemplate(
        sourceKind: .binancePerp,
        displayName: NSLocalizedString("XRP Perpetual", comment: ""),
        symbol: "XRPUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/futures/xrpusdt"
    )
    private static let binanceDOGE = WatchItemTemplate(
        sourceKind: .binancePerp,
        displayName: NSLocalizedString("DOGE Perpetual", comment: ""),
        symbol: "DOGEUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/futures/dogeusdt"
    )
    private static let binanceSpotBTC = WatchItemTemplate(
        sourceKind: .binanceSpot,
        displayName: "BTC",
        symbol: "BTCUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/trade/BTC_USDT"
    )
    private static let binanceSpotETH = WatchItemTemplate(
        sourceKind: .binanceSpot,
        displayName: "ETH",
        symbol: "ETHUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/trade/ETH_USDT"
    )
    private static let binanceSpotSOL = WatchItemTemplate(
        sourceKind: .binanceSpot,
        displayName: "SOL",
        symbol: "SOLUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/trade/SOL_USDT"
    )
    private static let binanceSpotXRP = WatchItemTemplate(
        sourceKind: .binanceSpot,
        displayName: "XRP",
        symbol: "XRPUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/trade/XRP_USDT"
    )
    private static let binanceSpotDOGE = WatchItemTemplate(
        sourceKind: .binanceSpot,
        displayName: "DOGE",
        symbol: "DOGEUSDT",
        area: nil,
        defaultURL: "https://www.binance.com/zh-CN/trade/DOGE_USDT"
    )

    static let allTemplates: [WatchItemTemplate] = [
        baiduNasdaq, baiduDowJones, baiduSP500, baiduFTSE, baiduCAC, baiduNikkei, baiduHangSeng, baiduKOSPI, baiduShanghai, baiduShenzhen, baiduA50, baiduDAX,
        baiduDollarIndex, baiduUSDCNY, baiduUSDCNH, baiduEURCNY, baiduUSDGBP,
        sinaDJI, sinaINX, sinaNasdaq, sinaFTSE, sinaNikkei, sinaDAX, sinaTOPIX, sinaKOSPI,
        okxSpotBTC, okxSpotETH, okxSpotSOL, okxSpotXRP, okxSpotDOGE,
        okxETH, okxBTC, okxSOL, okxXRP, okxDOGE,
        gateSpotBTC, gateSpotETH, gateSpotSOL, gateSpotXRP, gateSpotDOGE,
        gateETH, gateBTC, gateSOL, gateXRP, gateDOGE,
        binanceSpotBTC, binanceSpotETH, binanceSpotSOL, binanceSpotXRP, binanceSpotDOGE,
        binanceETH, binanceBTC, binanceSOL, binanceXRP, binanceDOGE,
    ]
}

struct WatchItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var enabled = true
    var displayName: String
    var sourceKind: DataSourceKind
    var symbol: String
    var area: BaiduArea?
    var customOpenTime: String? = nil
    var customCloseTime: String? = nil
    var customURL: String? = nil

    var resolvedQuickLinkURL: String? {
        if let customURL, !customURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customURL
        }
        return Self.defaultQuickLinkURL(sourceKind: sourceKind, symbol: symbol, area: area)
    }

    init(template: WatchItemTemplate) {
        id = UUID()
        enabled = true
        displayName = template.displayName
        sourceKind = template.sourceKind
        symbol = template.symbol
        area = template.area
        customOpenTime = nil
        customCloseTime = nil
        customURL = template.defaultURL
    }

    static let defaults: [WatchItem] = WatchItemTemplateCatalog.defaultWatchlistTemplates.map(WatchItem.init(template:))

    static func defaultQuickLinkURL(sourceKind: DataSourceKind, symbol: String, area: BaiduArea? = nil) -> String? {
        WatchItemTemplateCatalog.defaultQuickLinkURL(sourceKind: sourceKind, symbol: symbol, area: area)
    }
}

struct AppSettings: Codable, Equatable {
    var autoRefresh = true
    var refreshInterval: Double = 15
    var keepWindowFloating = true
    var snapToScreenEdge = true
    var snapThreshold: Double = 240
    var snapMargin: Double = 10
    var showProviderTags = true
    var showMarketStatus = true
    var floatingFontSize: Double = 14
    var miniWindowFontSize: Double = 16
    var backgroundOpacity: Double = 0.92
    var miniWindowBackgroundOpacity: Double = 0.92
    var floatingWidth: Double = 250
    var floatingMaxHeight: Double = 600
    var floatingThemeMode: FloatingThemeMode = .system
    var floatingBackgroundStyle: FloatingBackgroundStyle = .graphite
    var floatingTextPalette: FloatingTextPalette = .followTheme
    var priceColorStyle: PriceColorStyle = .redUpGreenDown
    var collapsedDisplayMode: CollapsedDisplayMode = .priceOnly
    var miniWindowItemIDs: [UUID] = []
    var proxyEnabled = false
    var proxyType: ProxyType = .http
    var proxyHost = "127.0.0.1"
    var proxyPort = 7890
    var proxyTestURL = "https://www.gstatic.com/generate_204"
    var baiduConfig = EndpointConfiguration(
        primaryURL: "https://finance.pae.baidu.com",
        primaryWebSocketURL: "wss://finance-ws.pae.baidu.com"
    )
    var sinaConfig = EndpointConfiguration(primaryURL: "https://w.sinajs.cn")
    var okxConfig = EndpointConfiguration(
        primaryURL: "https://www.okx.com",
        backupURL: "",
        timeout: 8,
        primaryWebSocketURL: "wss://ws.okx.com:8443/ws/v5/public",
        backupWebSocketURL: ""
    )
    var gateConfig = EndpointConfiguration(
        primaryURL: "https://api.gateio.ws",
        backupURL: "https://fx-api.gateio.ws",
        timeout: 8,
        primaryWebSocketURL: "wss://fx-ws.gateio.ws/v4/ws/usdt",
        backupWebSocketURL: ""
    )
    var binanceConfig = EndpointConfiguration(
        primaryURL: "https://fapi.binance.com",
        backupURL: "",
        timeout: 8,
        primaryWebSocketURL: "wss://fstream.binance.com/stream",
        backupWebSocketURL: ""
    )
    var watchlist = WatchItem.defaults

    static let `default` = AppSettings()

    enum CodingKeys: String, CodingKey {
        case autoRefresh
        case refreshInterval
        case keepWindowFloating
        case snapToScreenEdge
        case snapThreshold
        case snapMargin
        case showProviderTags
        case showMarketStatus
        case floatingFontSize
        case miniWindowFontSize
        case backgroundOpacity
        case miniWindowBackgroundOpacity
        case floatingWidth
        case floatingMaxHeight
        case floatingThemeMode
        case floatingBackgroundStyle
        case floatingTextPalette
        case priceColorStyle
        case collapsedDisplayMode
        case miniWindowItemIDs
        case proxyEnabled
        case proxyType
        case proxyHost
        case proxyPort
        case proxyTestURL
        case baiduConfig
        case sinaConfig
        case okxConfig
        case gateConfig
        case binanceConfig
        case watchlist
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .default

        autoRefresh = try container.decodeIfPresent(Bool.self, forKey: .autoRefresh) ?? autoRefresh
        refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? refreshInterval
        keepWindowFloating = try container.decodeIfPresent(Bool.self, forKey: .keepWindowFloating) ?? keepWindowFloating
        snapToScreenEdge = try container.decodeIfPresent(Bool.self, forKey: .snapToScreenEdge) ?? snapToScreenEdge
        snapThreshold = try container.decodeIfPresent(Double.self, forKey: .snapThreshold) ?? snapThreshold
        snapMargin = try container.decodeIfPresent(Double.self, forKey: .snapMargin) ?? snapMargin
        showProviderTags = try container.decodeIfPresent(Bool.self, forKey: .showProviderTags) ?? showProviderTags
        showMarketStatus = try container.decodeIfPresent(Bool.self, forKey: .showMarketStatus) ?? showMarketStatus
        floatingFontSize = try container.decodeIfPresent(Double.self, forKey: .floatingFontSize) ?? floatingFontSize
        miniWindowFontSize = try container.decodeIfPresent(Double.self, forKey: .miniWindowFontSize) ?? miniWindowFontSize
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? backgroundOpacity
        miniWindowBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .miniWindowBackgroundOpacity) ?? miniWindowBackgroundOpacity
        floatingWidth = try container.decodeIfPresent(Double.self, forKey: .floatingWidth) ?? floatingWidth
        floatingMaxHeight = try container.decodeIfPresent(Double.self, forKey: .floatingMaxHeight) ?? floatingMaxHeight
        floatingThemeMode = try container.decodeIfPresent(FloatingThemeMode.self, forKey: .floatingThemeMode) ?? floatingThemeMode
        floatingBackgroundStyle = try container.decodeIfPresent(FloatingBackgroundStyle.self, forKey: .floatingBackgroundStyle) ?? floatingBackgroundStyle
        floatingTextPalette = try container.decodeIfPresent(FloatingTextPalette.self, forKey: .floatingTextPalette) ?? floatingTextPalette
        priceColorStyle = try container.decodeIfPresent(PriceColorStyle.self, forKey: .priceColorStyle) ?? priceColorStyle
        collapsedDisplayMode = try container.decodeIfPresent(CollapsedDisplayMode.self, forKey: .collapsedDisplayMode) ?? collapsedDisplayMode
        miniWindowItemIDs = try container.decodeIfPresent([UUID].self, forKey: .miniWindowItemIDs) ?? miniWindowItemIDs
        proxyEnabled = try container.decodeIfPresent(Bool.self, forKey: .proxyEnabled) ?? proxyEnabled
        proxyType = try container.decodeIfPresent(ProxyType.self, forKey: .proxyType) ?? proxyType
        proxyHost = try container.decodeIfPresent(String.self, forKey: .proxyHost) ?? proxyHost
        proxyPort = try container.decodeIfPresent(Int.self, forKey: .proxyPort) ?? proxyPort
        let decodedProxyTestURL = try container.decodeIfPresent(String.self, forKey: .proxyTestURL) ?? proxyTestURL
        proxyTestURL = Self.normalizedProxyTestURL(decodedProxyTestURL)
        baiduConfig = try decodeEndpointConfiguration(from: container, key: .baiduConfig, fallback: baiduConfig, legacyProxyEnabled: proxyEnabled)
        sinaConfig = try decodeEndpointConfiguration(from: container, key: .sinaConfig, fallback: sinaConfig, legacyProxyEnabled: proxyEnabled)
        okxConfig = try decodeEndpointConfiguration(from: container, key: .okxConfig, fallback: okxConfig, legacyProxyEnabled: proxyEnabled)
        gateConfig = try decodeEndpointConfiguration(from: container, key: .gateConfig, fallback: gateConfig, legacyProxyEnabled: proxyEnabled)
        binanceConfig = try decodeEndpointConfiguration(from: container, key: .binanceConfig, fallback: binanceConfig, legacyProxyEnabled: proxyEnabled)
        watchlist = try container.decodeIfPresent([WatchItem].self, forKey: .watchlist) ?? watchlist
        watchlist = watchlist.map { item in
            guard item.customURL == nil,
                  let defaultQuickLinkURL = WatchItem.defaultQuickLinkURL(sourceKind: item.sourceKind, symbol: item.symbol)
            else {
                return item
            }

            var updatedItem = item
            updatedItem.customURL = defaultQuickLinkURL
            return updatedItem
        }
    }

    private static func normalizedProxyTestURL(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AppSettings.default.proxyTestURL
        }

        if trimmed == "http://www.gstatic.com/generate_204" {
            return "https://www.gstatic.com/generate_204"
        }

        return trimmed
    }

    private func decodeEndpointConfiguration(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys,
        fallback: EndpointConfiguration,
        legacyProxyEnabled: Bool
    ) throws -> EndpointConfiguration {
        guard container.contains(key) else { return fallback }

        var decoded = try container.decodeIfPresent(EndpointConfiguration.self, forKey: key) ?? fallback
        let nested = try container.nestedContainer(keyedBy: EndpointConfiguration.CodingKeys.self, forKey: key)
        if !nested.contains(.useProxy) {
            decoded.useProxy = legacyProxyEnabled
        }
        return decoded
    }
}

enum StreamConnectionState: String {
    case standby
    case disconnected
    case connecting
    case connected

    var isConnected: Bool {
        self == .connected
    }
}

struct LogEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var level: LogLevel
    var message: String
    var timestamp = Date()
}

struct QuoteSnapshot: Identifiable, Equatable {
    let id: UUID
    let item: WatchItem
    let price: Double?
    let change: Double?
    let changePercent: Double?
    let sourceLabel: String
    let marketStatus: String?
    let fetchedAt: Date
    let usedBaseURL: String

    init(
        id: UUID,
        item: WatchItem,
        price: Double?,
        change: Double?,
        changePercent: Double?,
        sourceLabel: String,
        marketStatus: String?,
        fetchedAt: Date,
        usedBaseURL: String
    ) {
        self.id = id
        self.item = item
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.sourceLabel = sourceLabel
        self.marketStatus = marketStatus
        self.fetchedAt = fetchedAt
        self.usedBaseURL = usedBaseURL
    }

    var symbolCaption: String {
        switch item.sourceKind.instrumentKind {
        case .globalIndex:
            return item.symbol.uppercased()
        case .spot:
            switch item.sourceKind {
            case .okxSpotMarket:
                return item.symbol.uppercased().replacingOccurrences(of: "-", with: "/")
            case .gateSpotMarket:
                return item.symbol.uppercased().replacingOccurrences(of: "_", with: "/")
            case .binanceSpot:
                if item.symbol.uppercased().hasSuffix("USDT") {
                    let base = item.symbol.uppercased().replacingOccurrences(of: "USDT", with: "")
                    return "\(base)/USDT"
                }
                return item.symbol.uppercased()
            case .baiduGlobalIndex, .sinaGlobalIndex, .okxSpot, .gateSpot, .binancePerp:
                return item.symbol.uppercased()
            }
        case .perpetual:
            switch item.sourceKind {
            case .okxSpotMarket, .gateSpotMarket, .binanceSpot:
                return item.symbol.uppercased()
            case .okxSpot:
                if item.symbol.uppercased().hasSuffix("-SWAP") {
                    return item.symbol
                        .uppercased()
                        .replacingOccurrences(of: "-SWAP", with: "")
                        .replacingOccurrences(of: "-", with: "/") + " " + NSLocalizedString("Perpetual", comment: "")
                }
                return item.symbol.uppercased()
            case .gateSpot:
                return item.symbol.uppercased().replacingOccurrences(of: "_", with: "/") + " " + NSLocalizedString("Perpetual", comment: "")
            case .binancePerp:
                if item.symbol.uppercased().hasSuffix("USDT") {
                    let base = item.symbol.uppercased().replacingOccurrences(of: "USDT", with: "")
                    return "\(base)/USDT \(NSLocalizedString("Perpetual", comment: ""))"
                }
                return item.symbol.uppercased() + " " + NSLocalizedString("Perpetual", comment: "")
            case .baiduGlobalIndex, .sinaGlobalIndex:
                return item.symbol.uppercased()
            }
        }
    }

    var priceText: String {
        Self.priceFormatter.string(from: NSNumber(value: price ?? 0)) ?? "--"
    }

    var changeText: String {
        guard let change else { return "--" }
        let sign = change > 0 ? "+" : ""
        let formatted = Self.changeFormatter.string(from: NSNumber(value: change)) ?? "\(change)"
        return sign + formatted
    }

    var percentText: String {
        guard let changePercent else { return "--" }
        let sign = changePercent > 0 ? "+" : ""
        let formatted = Self.percentFormatter.string(from: NSNumber(value: changePercent)) ?? "\(changePercent)"
        return sign + formatted + "%"
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    private static let changeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct SourceFetchResult {
    var snapshots: [QuoteSnapshot] = []
    var logs: [LogEntry] = []
}

struct MarketRefreshResult {
    var snapshots: [QuoteSnapshot] = []
    var logs: [LogEntry] = []
}

struct IndexMarketTiming {
    enum Phase: Equatable {
        case openingSoon(minutes: Int)
        case trading
        case recentlyClosed(minutes: Int)
        case waiting(minutes: Int)
        case closed
    }

    let phase: Phase
    let nextOpen: Date?
    let shouldRefresh: Bool

    var statusText: String {
        switch phase {
        case let .openingSoon(minutes):
            return String(format: NSLocalizedString("Opening Soon In %d Min", comment: ""), minutes)
        case .trading:
            return NSLocalizedString("Trading", comment: "")
        case let .recentlyClosed(minutes):
            return String(format: NSLocalizedString("Closed %d Min Ago", comment: ""), minutes)
        case let .waiting(minutes):
            return String(format: NSLocalizedString("Opens In %d Min", comment: ""), minutes)
        case .closed:
            return NSLocalizedString("Closed", comment: "")
        }
    }

    var sortBucket: Int {
        switch phase {
        case .trading:
            return 0
        case .openingSoon:
            return 1
        case .recentlyClosed:
            return 2
        case .waiting:
            return 3
        case .closed:
            return 4
        }
    }

    var sortMinutes: Int {
        switch phase {
        case let .openingSoon(minutes), let .recentlyClosed(minutes), let .waiting(minutes):
            return minutes
        case .trading:
            return 0
        case .closed:
            return Int.max
        }
    }

    var isTrading: Bool {
        if case .trading = phase { return true }
        return false
    }

    var isOpeningWithinHour: Bool {
        if case let .openingSoon(minutes) = phase { return minutes <= 60 }
        return false
    }

    var isRecentlyClosedWithinHour: Bool {
        if case let .recentlyClosed(minutes) = phase { return minutes <= 60 }
        return false
    }
}

struct MarketClockTime: Equatable {
    let hour: Int
    let minute: Int

    var totalMinutes: Int {
        hour * 60 + minute
    }

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func parse(_ rawValue: String?) -> MarketClockTime? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return MarketClockTime(hour: hour, minute: minute)
    }
}

enum IndexMarketSchedule {
    case nasdaq
    case usBroadMarket
    case ftse100
    case cac40
    case nikkei225
    case hangSeng
    case kospi
    case chinaAShare
    case dax

    struct Session {
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int

        var startTotalMinutes: Int {
            startHour * 60 + startMinute
        }

        var endTotalMinutes: Int {
            endHour * 60 + endMinute
        }
    }

    static func forSymbol(_ symbol: String) -> IndexMarketSchedule? {
        switch symbol.uppercased() {
        case "IXIC":
            return .nasdaq
        case "DJI", "SPX":
            return .usBroadMarket
        case "FTSE":
            return .ftse100
        case "CAC":
            return .cac40
        case "NK225":
            return .nikkei225
        case "HSI":
            return .hangSeng
        case "KOSPI":
            return .kospi
        case "000001", "399001":
            return .chinaAShare
        case "DAX":
            return .dax
        default:
            return nil
        }
    }

    var timeZone: TimeZone {
        switch self {
        case .nasdaq:
            return TimeZone(identifier: "America/New_York") ?? .current
        case .usBroadMarket:
            return TimeZone(identifier: "America/New_York") ?? .current
        case .ftse100:
            return TimeZone(identifier: "Europe/London") ?? .current
        case .cac40:
            return TimeZone(identifier: "Europe/Paris") ?? .current
        case .nikkei225:
            return TimeZone(identifier: "Asia/Tokyo") ?? .current
        case .hangSeng:
            return TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        case .kospi:
            return TimeZone(identifier: "Asia/Seoul") ?? .current
        case .chinaAShare:
            return TimeZone(identifier: "Asia/Shanghai") ?? .current
        case .dax:
            return TimeZone(identifier: "Europe/Berlin") ?? .current
        }
    }

    var sessions: [Session] {
        switch self {
        case .nasdaq:
            return [Session(startHour: 9, startMinute: 30, endHour: 16, endMinute: 0)]
        case .usBroadMarket:
            return [Session(startHour: 9, startMinute: 30, endHour: 16, endMinute: 0)]
        case .ftse100:
            return [Session(startHour: 8, startMinute: 0, endHour: 16, endMinute: 30)]
        case .cac40:
            return [Session(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)]
        case .nikkei225:
            return [
                Session(startHour: 9, startMinute: 0, endHour: 11, endMinute: 30),
                Session(startHour: 12, startMinute: 30, endHour: 15, endMinute: 0)
            ]
        case .hangSeng:
            return [
                Session(startHour: 9, startMinute: 30, endHour: 12, endMinute: 0),
                Session(startHour: 13, startMinute: 0, endHour: 16, endMinute: 0)
            ]
        case .kospi:
            return [Session(startHour: 9, startMinute: 0, endHour: 15, endMinute: 30)]
        case .chinaAShare:
            return [
                Session(startHour: 9, startMinute: 30, endHour: 11, endMinute: 30),
                Session(startHour: 13, startMinute: 0, endHour: 15, endMinute: 0)
            ]
        case .dax:
            return [Session(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)]
        }
    }

    var defaultOpenTimeText: String {
        guard let firstSession = sessions.first else { return "--:--" }
        return MarketClockTime(hour: firstSession.startHour, minute: firstSession.startMinute).displayText
    }

    var defaultCloseTimeText: String {
        guard let lastSession = sessions.last else { return "--:--" }
        return MarketClockTime(hour: lastSession.endHour, minute: lastSession.endMinute).displayText
    }

    func isValid(customOpenTime rawOpenValue: String?, customCloseTime rawCloseValue: String?) -> Bool {
        guard !sessions.isEmpty else { return false }

        var resolved = sessions

        if let customOpenTime = MarketClockTime.parse(rawOpenValue) {
            guard Self.supportsPickerGranularity(customOpenTime) else {
                return false
            }
            let firstSession = resolved[0]
            guard customOpenTime.totalMinutes < firstSession.endTotalMinutes else {
                return false
            }
            resolved[0] = Session(
                startHour: customOpenTime.hour,
                startMinute: customOpenTime.minute,
                endHour: firstSession.endHour,
                endMinute: firstSession.endMinute
            )
        } else if let rawOpenValue,
                  !rawOpenValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if let customCloseTime = MarketClockTime.parse(rawCloseValue) {
            guard Self.supportsPickerGranularity(customCloseTime) else {
                return false
            }
            let lastIndex = resolved.count - 1
            let lastSession = resolved[lastIndex]
            guard customCloseTime.totalMinutes > lastSession.startTotalMinutes else {
                return false
            }
            resolved[lastIndex] = Session(
                startHour: lastSession.startHour,
                startMinute: lastSession.startMinute,
                endHour: customCloseTime.hour,
                endMinute: customCloseTime.minute
            )
        } else if let rawCloseValue,
                  !rawCloseValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        return resolved.allSatisfy { $0.startTotalMinutes < $0.endTotalMinutes }
    }

    private func resolvedSessions(customOpenTime rawOpenValue: String?, customCloseTime rawCloseValue: String?) -> [Session] {
        guard isValid(customOpenTime: rawOpenValue, customCloseTime: rawCloseValue) else {
            return sessions
        }

        var resolved = sessions

        if let customOpenTime = MarketClockTime.parse(rawOpenValue),
           let firstSession = resolved.first {
            resolved[0] = Session(
                startHour: customOpenTime.hour,
                startMinute: customOpenTime.minute,
                endHour: firstSession.endHour,
                endMinute: firstSession.endMinute
            )
        }

        if let customCloseTime = MarketClockTime.parse(rawCloseValue) {
            let lastIndex = resolved.count - 1
            let lastSession = resolved[lastIndex]
            resolved[lastIndex] = Session(
                startHour: lastSession.startHour,
                startMinute: lastSession.startMinute,
                endHour: customCloseTime.hour,
                endMinute: customCloseTime.minute
            )
        }

        return resolved
    }

    private static func supportsPickerGranularity(_ time: MarketClockTime) -> Bool {
        time.minute == 0 || time.minute == 30
    }

    func timing(
        now: Date = Date(),
        hasSnapshot: Bool,
        customOpenTime: String? = nil,
        customCloseTime: String? = nil
    ) -> IndexMarketTiming {
        let sessions = resolvedSessions(
            customOpenTime: customOpenTime,
            customCloseTime: customCloseTime
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue }

            for session in sessions {
                guard let start = calendar.date(
                    bySettingHour: session.startHour,
                    minute: session.startMinute,
                    second: 0,
                    of: day
                ), let end = calendar.date(
                    bySettingHour: session.endHour,
                    minute: session.endMinute,
                    second: 0,
                    of: day
                ) else {
                    continue
                }

                if now >= start && now <= end {
                    return IndexMarketTiming(phase: .trading, nextOpen: start, shouldRefresh: true)
                }

                if now < start {
                    let minutes = max(Int(start.timeIntervalSince(now) / 60), 0)
                    if dayOffset == 0 && minutes <= 60 {
                        return IndexMarketTiming(phase: .openingSoon(minutes: minutes), nextOpen: start, shouldRefresh: true)
                    }
                    if dayOffset == 0 && hasSnapshot {
                        return IndexMarketTiming(
                            phase: .waiting(minutes: minutes),
                            nextOpen: start,
                            shouldRefresh: minutes <= 60
                        )
                    }
                    return IndexMarketTiming(
                        phase: dayOffset == 0 ? .waiting(minutes: minutes) : .closed,
                        nextOpen: start,
                        shouldRefresh: !hasSnapshot
                    )
                }

                if dayOffset == 0, now > end {
                    let minutesSinceClose = max(Int(now.timeIntervalSince(end) / 60), 0)
                    if minutesSinceClose <= 60 {
                        return IndexMarketTiming(
                            phase: .recentlyClosed(minutes: minutesSinceClose),
                            nextOpen: nil,
                            shouldRefresh: hasSnapshot ? minutesSinceClose < 5 : true
                        )
                    }
                }
            }

            if dayOffset == 0, sessions.count > 1 {
                for pair in zip(sessions, sessions.dropFirst()) {
                    guard let breakStart = calendar.date(
                        bySettingHour: pair.0.endHour,
                        minute: pair.0.endMinute,
                        second: 0,
                        of: day
                    ), let breakEnd = calendar.date(
                        bySettingHour: pair.1.startHour,
                        minute: pair.1.startMinute,
                        second: 0,
                        of: day
                    ) else {
                        continue
                    }

                    if now > breakStart && now < breakEnd {
                        let minutesUntilReopen = max(Int(breakEnd.timeIntervalSince(now) / 60), 0)
                        let minutesSinceBreak = max(Int(now.timeIntervalSince(breakStart) / 60), 0)
                        if minutesUntilReopen <= 60 {
                            return IndexMarketTiming(
                                phase: .openingSoon(minutes: minutesUntilReopen),
                                nextOpen: breakEnd,
                                shouldRefresh: true
                            )
                        }
                        if minutesSinceBreak <= 60 {
                            return IndexMarketTiming(
                                phase: .recentlyClosed(minutes: minutesSinceBreak),
                                nextOpen: breakEnd,
                                shouldRefresh: hasSnapshot ? minutesSinceBreak < 5 : true
                            )
                        }
                        return IndexMarketTiming(
                            phase: .waiting(minutes: minutesUntilReopen),
                            nextOpen: breakEnd,
                            shouldRefresh: false
                        )
                    }
                }
            }
        }

        return IndexMarketTiming(phase: .closed, nextOpen: nil, shouldRefresh: !hasSnapshot)
    }
}
