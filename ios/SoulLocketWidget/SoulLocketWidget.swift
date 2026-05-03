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
    var widgetStyleKey: String
    var heartAnimated: Bool
    var heartStyleKey: String
    var heartColorKey: String
    var loveDateText: String
    var avatar1Path: String?
    var avatar2Path: String?
    var diaryImagePaths: [String]
    var showDiaryOnWidget: Bool

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
            widgetStyleKey: defaults?.string(forKey: "widgetStyleKey") ?? "classic",
            heartAnimated: defaults?.bool(forKey: "heartAnimated") ?? true,
            heartStyleKey: defaults?.string(forKey: "heartStyleKey") ?? "❤️",
            heartColorKey: defaults?.string(forKey: "heartColorKey") ?? "rose",
            loveDateText: defaults?.string(forKey: "loveDateText") ?? "",
            avatar1Path: defaults?.string(forKey: "avatar1Path"),
            avatar2Path: defaults?.string(forKey: "avatar2Path"),
            diaryImagePaths: diaryPaths,
            showDiaryOnWidget: defaults?.bool(forKey: "showDiaryOnWidget") ?? false
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
        let entry = CoupleEntry(date: Date(), data: CoupleWidgetData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

@main
struct SoulLocketWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetCoupleProvider()
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
