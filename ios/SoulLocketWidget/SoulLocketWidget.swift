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
    var relationshipTimeZone: String = ""
    var weatherBackground = WidgetWeatherSnapshot()

    var relationshipCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: relationshipTimeZone) ?? .current
        return calendar
    }

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

        // startDate là ngày đã chọn, không phải instant UTC. Dùng Gregorian
        // ngay cả khi máy đặt Phật lịch/Hijri, và lấy hôm nay theo vùng đã chọn.
        guard relationshipTimeZone.isEmpty || TimeZone(identifier: relationshipTimeZone) != nil,
              raw.count >= 10 else { return daysText }
        let key = String(raw.prefix(10))
        guard key.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else {
            return daysText
        }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return daysText }
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard anchor.isValidDate(in: civil),
              let startOfAnchor = civil.date(from: anchor),
              let startOfToday = civil.date(from: relationshipCalendar.dateComponents(
                [.year, .month, .day], from: referenceDate
              )) else { return daysText }
        let days = max(0, civil.dateComponents([.day], from: startOfAnchor, to: startOfToday).day ?? 0)
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
            loveDateText: defaults?.string(forKey: "loveDateText") ?? "",
            relationshipTimeZone: defaults?.string(forKey: "relationshipTimeZone") ?? "",
            weatherBackground: WidgetWeatherSnapshot.load(defaults)
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
        // Múi giờ lệch 45 phút có nửa đêm nằm giữa hai mốc 30 phút UTC.
        let calendar = data.relationshipCalendar
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let last = dates.last, midnight <= last {
            dates.append(midnight)
            dates = Array(Set(dates)).sorted()
        }
        if data.weatherBackground.proExpiresAtMs > 0 {
            let expiry = Date(timeIntervalSince1970: data.weatherBackground.proExpiresAtMs / 1000)
            if expiry > now, let last = dates.last, expiry <= last { dates.append(expiry) }
        }
        let entries = Array(Set(dates)).sorted().map { CoupleEntry(date: $0, data: data) }
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
        .configurationDisplayName(Text("widget_avatar_days_name", tableName: "WidgetStrings"))
        .description(Text("widget_avatar_days_desc", tableName: "WidgetStrings"))
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
        .configurationDisplayName(Text("widget_soul_merge_name", tableName: "WidgetStrings"))
        .description(Text("widget_soul_merge_desc", tableName: "WidgetStrings"))
        .supportedFamilies([.accessoryRectangular])
    }
}
