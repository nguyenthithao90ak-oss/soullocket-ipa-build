import WidgetKit
import SwiftUI

let appGroupID = "group.WidgetCoupleProvider"

struct CoupleWidgetData {
    var name1: String
    var name2: String
    var daysText: String
    var status1: String
    var status2: String
    var isOnline1: Bool
    var isOnline2: Bool
    var weather1: String
    var weather2: String
    var stars1: String
    var stars2: String
    var bgTheme: String
    var heartAnimated: Bool
    var heartStyleKey: String
    var heartColorKey: String
    var avatar1Path: String?
    var avatar2Path: String?
    var diaryImagePaths: [String]
    var showDiaryOnWidget: Bool
    var startDateRaw: String
    var dayUnitText: String
    var battery1: Int  // -1 = unknown
    var battery2: Int  // -1 = unknown
    var isCharging1: Bool
    var isCharging2: Bool
    var soulMergeMessage: String
    var soulMergeSenderName: String
    var widgetStyleKey: String = "classic"
    var widgetStickerKey: String = "none"
    var photoFrameKey: String = "rounded"
    var diaryLayoutKey: String = "single"
    var loveDateText: String = ""

    func resolvedDaysText(referenceDate: Date = Date()) -> String {
        var unit = dayUnitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? widgetText("comm_ngy_41ec10")
            : dayUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        unit = unit.replacingOccurrences(of: " yêu", with: "")
                   .replacingOccurrences(of: " of love", with: "")

        let raw = startDateRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return daysText.replacingOccurrences(of: " yêu", with: "")
                           .replacingOccurrences(of: " of love", with: "")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var startDate = formatter.date(from: raw)
        if startDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startDate = formatter.date(from: raw)
        }
        if startDate == nil {
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.dateFormat = "yyyy-MM-dd"
            startDate = fallbackFormatter.date(from: raw)
        }
        guard let startDate else {
            return daysText
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfAnchor = calendar.startOfDay(for: startDate)
        let days = max(0, calendar.dateComponents([.day], from: startOfAnchor, to: startOfToday).day ?? 0)
        return "\(days) \(unit)"
    }

    static func preview() -> CoupleWidgetData {
        CoupleWidgetData(name1: widgetText("p3_sleep_default_me"),
            name2: widgetText("p3_sleep_default_partner"),
            daysText: "259 " + widgetText("comm_ngy_41ec10"),
            status1: "", status2: "", isOnline1: false, isOnline2: false,
            weather1: "", weather2: "", stars1: "", stars2: "", bgTheme: "pink",
            heartAnimated: false, heartStyleKey: "❤️", heartColorKey: "rose",
            avatar1Path: nil, avatar2Path: nil, diaryImagePaths: [],
            showDiaryOnWidget: false, startDateRaw: "",
            dayUnitText: widgetText("comm_ngy_41ec10"), battery1: -1, battery2: -1,
            isCharging1: false, isCharging2: false, soulMergeMessage: "", soulMergeSenderName: "Soul Merge")
    }

    static func load() -> CoupleWidgetData {
        let defaults = UserDefaults(suiteName: appGroupID)

        let diaryPathsJSON = defaults?.string(forKey: "diaryImagePaths") ?? "[]"
        let diaryPaths: [String]
        if let data = diaryPathsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            diaryPaths = decoded
        } else {
            diaryPaths = []
        }

        let battery1Raw = defaults?.integer(forKey: "battery1") ?? -1
        let battery2Raw = defaults?.integer(forKey: "battery2") ?? -1

        return CoupleWidgetData(
            name1: defaults?.string(forKey: "name1") ?? widgetText("p3_sleep_default_me"),
            name2: defaults?.string(forKey: "name2") ?? widgetText("p3_sleep_default_partner"),
            daysText: defaults?.string(forKey: "daysText") ?? ("0 " + widgetText("comm_ngy_41ec10")),
            status1: defaults?.string(forKey: "status1") ?? "",
            status2: defaults?.string(forKey: "status2") ?? "",
            isOnline1: defaults?.bool(forKey: "isOnline1") ?? false,
            isOnline2: defaults?.bool(forKey: "isOnline2") ?? false,
            weather1: defaults?.string(forKey: "weather1") ?? "",
            weather2: defaults?.string(forKey: "weather2") ?? "",
            stars1: defaults?.string(forKey: "stars1") ?? "--",
            stars2: defaults?.string(forKey: "stars2") ?? "--",
            bgTheme: defaults?.string(forKey: "bgTheme") ?? "pink",
            heartAnimated: defaults?.bool(forKey: "heartAnimated") ?? false,
            heartStyleKey: defaults?.string(forKey: "heartStyleKey") ?? "❤️",
            heartColorKey: defaults?.string(forKey: "heartColorKey") ?? "rose",
            avatar1Path: defaults?.string(forKey: "avatar1Path"),
            avatar2Path: defaults?.string(forKey: "avatar2Path"),
            diaryImagePaths: diaryPaths,
            showDiaryOnWidget: defaults?.bool(forKey: "showDiaryOnWidget") ?? false,
            startDateRaw: defaults?.string(forKey: "startDateRaw") ?? "",
            dayUnitText: defaults?.string(forKey: "dayUnitText") ?? widgetText("comm_ngy_41ec10"),
            battery1: battery1Raw == 0 && !(defaults?.object(forKey: "battery1") != nil) ? -1 : battery1Raw,
            battery2: battery2Raw == 0 && !(defaults?.object(forKey: "battery2") != nil) ? -1 : battery2Raw,
            isCharging1: defaults?.bool(forKey: "isCharging1") ?? false,
            isCharging2: defaults?.bool(forKey: "isCharging2") ?? false,
            soulMergeMessage: defaults?.string(forKey: "soulMergeMessage") ?? widgetText("widget_sync_empty"),
            soulMergeSenderName: defaults?.string(forKey: "soulMergeSenderName") ?? "Soul Merge",
            widgetStyleKey: WidgetAppearanceDesign.style(defaults?.string(forKey: "widgetStyleKey") ?? "classic"),
            widgetStickerKey: WidgetAppearanceDesign.sticker(defaults?.string(forKey: "widgetStickerKey") ?? "none"),
            photoFrameKey: WidgetAppearanceDesign.frame(defaults?.string(forKey: "photoFrameKey") ?? "rounded"),
            diaryLayoutKey: WidgetAppearanceDesign.layout(defaults?.string(forKey: "diaryLayoutKey") ?? "single"),
            loveDateText: defaults?.string(forKey: "loveDateText") ?? ""
        )
    }
}

struct CoupleEntry: TimelineEntry {
    let date: Date
    let data: CoupleWidgetData
}

struct CoupleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), data: CoupleWidgetData.preview())
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) {
        completion(CoupleEntry(date: Date(), data: context.isPreview ? CoupleWidgetData.preview() : CoupleWidgetData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        let now = Date()
        let data = CoupleWidgetData.load()
        // Mốc 30 phút: WidgetKit quản lý lịch render, không chạy timer liên tục.
        let start = floor(now.timeIntervalSince1970 / 1800) * 1800
        var dates = [now]
        for index in 1...12 {
            dates.append(Date(timeIntervalSince1970: start + Double(index) * 1800))
        }
        let entries = dates.map { CoupleEntry(date: $0, data: data) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// ─── Entry Point Launcher để tránh load metadata iOS 16 Live Activity trên iOS 15 ───
@main
struct SoulLocketWidgetLauncher {
    static func main() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            SoulLocketWidgetBundle16.main()
            return
        }
        #endif
        SoulLocketWidgetBundle15.main()
    }
}

// ─── iOS 16.1+ Widget Bundle (Includes Live Activity) ────────────────────────
#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct SoulLocketWidgetBundle16: WidgetBundle {
    var body: some Widget {
        WidgetCoupleProvider()
        SoulLocketUtilityWidgets().body
        WidgetCoupleAccessoryAvatarProvider()
        WidgetSoulMergeAccessoryProvider()
        SoulLocketLiveActivity()
    }
}
#endif

// ─── iOS 15 Widget Bundle (No Live Activity) ───────────────────────────────
struct SoulLocketWidgetBundle15: WidgetBundle {
    var body: some Widget {
        WidgetCoupleProvider()
        SoulLocketUtilityWidgets().body
        if #available(iOS 16.0, *) {
            WidgetCoupleAccessoryAvatarProvider()
            WidgetSoulMergeAccessoryProvider()
        }
    }
}

struct SoulLocketUtilityWidgets: WidgetBundle {
    var body: some Widget {
        WidgetCycleProvider()
        WidgetCalendarProvider()
        WidgetSoulEventProvider()
        WidgetSleepProvider()
    }
}

struct WidgetCoupleProvider: Widget {
    let kind: String = "WidgetCoupleProvider"

    private var families: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemSmall, .systemMedium, .systemLarge]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            if #available(iOS 16.0, *) {
                SoulLocketWidgetView16(entry: entry)
            } else {
                SoulLocketWidgetView15(entry: entry)
            }
        }
        .configurationDisplayName(Text("home_cpi_d525b0", tableName: "WidgetStrings"))
        .description(Text("settings_widget_desc_mobile", tableName: "WidgetStrings"))
        .supportedFamilies(families)
        .contentMarginsDisabled()
    }
}

@available(iOS 16.0, *)
struct WidgetCoupleAccessoryAvatarProvider: Widget {
    let kind: String = "WidgetCoupleAccessoryAvatarProvider"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            LockScreenWidgetAvatarView(data: entry.data, date: entry.date)
        }
        .configurationDisplayName("SoulLocket: Avatar & Ngày")
        .description("Hiện số ngày yêu ở giữa cùng ảnh đại diện 2 người.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@available(iOS 16.0, *)
struct WidgetSoulMergeAccessoryProvider: Widget {
    let kind: String = "WidgetSoulMergeAccessoryProvider"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            LockScreenSoulMergeWidgetView(data: entry.data)
        }
        .configurationDisplayName("SoulLocket: Soul Merge")
        .description("Hiển thị tin nhắn Soul Merge mới nhất từ người kia.")
        .supportedFamilies([.accessoryRectangular])
    }
}
