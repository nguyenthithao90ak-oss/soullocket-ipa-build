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

    func resolvedDaysText(referenceDate: Date = Date()) -> String {
        let unit = dayUnitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "ngày"
            : dayUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = startDateRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return daysText
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
            name1: defaults?.string(forKey: "name1") ?? "Bạn",
            name2: defaults?.string(forKey: "name2") ?? "Người ấy",
            daysText: defaults?.string(forKey: "daysText") ?? "0 ngày",
            status1: defaults?.string(forKey: "status1") ?? "",
            status2: defaults?.string(forKey: "status2") ?? "",
            isOnline1: defaults?.bool(forKey: "isOnline1") ?? false,
            isOnline2: defaults?.bool(forKey: "isOnline2") ?? false,
            weather1: defaults?.string(forKey: "weather1") ?? "",
            weather2: defaults?.string(forKey: "weather2") ?? "",
            stars1: defaults?.string(forKey: "stars1") ?? "--",
            stars2: defaults?.string(forKey: "stars2") ?? "--",
            bgTheme: defaults?.string(forKey: "bgTheme") ?? "pink",
            heartAnimated: defaults?.bool(forKey: "heartAnimated") ?? true,
            heartStyleKey: defaults?.string(forKey: "heartStyleKey") ?? "❤️",
            heartColorKey: defaults?.string(forKey: "heartColorKey") ?? "rose",
            avatar1Path: defaults?.string(forKey: "avatar1Path"),
            avatar2Path: defaults?.string(forKey: "avatar2Path"),
            diaryImagePaths: diaryPaths,
            showDiaryOnWidget: defaults?.bool(forKey: "showDiaryOnWidget") ?? false,
            startDateRaw: defaults?.string(forKey: "startDateRaw") ?? "",
            dayUnitText: defaults?.string(forKey: "dayUnitText") ?? "ngày",
            battery1: battery1Raw == 0 && !(defaults?.object(forKey: "battery1") != nil) ? -1 : battery1Raw,
            battery2: battery2Raw == 0 && !(defaults?.object(forKey: "battery2") != nil) ? -1 : battery2Raw,
            isCharging1: defaults?.bool(forKey: "isCharging1") ?? false,
            isCharging2: defaults?.bool(forKey: "isCharging2") ?? false
        )
    }
}

struct CoupleEntry: TimelineEntry {
    let date: Date
    let data: CoupleWidgetData
}

struct CoupleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), data: CoupleWidgetData.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) {
        completion(CoupleEntry(date: Date(), data: CoupleWidgetData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        let now = Date()
        let entry = CoupleEntry(date: now, data: CoupleWidgetData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

@main
struct SoulLocketWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetCoupleProvider()
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            SoulLocketLiveActivity()
        }
        #endif
    }
}


struct WidgetCoupleProvider: Widget {
    let kind: String = "WidgetCoupleProvider"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            SoulLocketWidgetView(entry: entry)
        }
        .configurationDisplayName("SoulLocket")
        .description("Hiển thị thông tin cặp đôi của bạn.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
