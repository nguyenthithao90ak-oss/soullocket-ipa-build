import SwiftUI
import WidgetKit

enum UtilityWidgetKind: Equatable {
    case cycle, calendar, event, sleep
    var titleKey: String {
        switch self {
        case .cycle: return "p3_health_header_cycle"
        case .calendar: return "home_lchchung_ac8882"
        case .event: return "p8_events_title"
        case .sleep: return "widget_title_sleep"
        }
    }
    var symbol: String {
        switch self {
        case .cycle: return "drop.fill"
        case .calendar: return "calendar"
        case .event: return "gift.fill"
        case .sleep: return "moon.stars.fill"
        }
    }
    var action: String {
        switch self {
        case .cycle: return "cycle"
        case .calendar: return "calendar"
        case .event: return "soul_events"
        case .sleep: return "sleep"
        }
    }
    var artwork: String {
        switch self {
        case .cycle: return "widget_cycle"
        case .calendar: return "widget_calendar"
        case .event: return "widget_gift"
        case .sleep: return "widget_moon"
        }
    }
    /// Nền dùng đúng palette widget đôi (WidgetThemeBackdrop); artwork vẫn riêng từng loại.
    func palette(for themeKey: String) -> [Color] {
        (WidgetAppearanceDesign.palettes[WidgetAppearanceDesign.theme(themeKey)] ?? []).map { Color(hex: $0) }
    }
    /// Chữ giống tên/nhãn của widget đôi iOS (WidgetTheme.textColor).
    func ink(for themeKey: String) -> Color {
        WidgetTheme.from(WidgetAppearanceDesign.theme(themeKey)).textColor
    }
}

/// Màu nhấn/thẻ theo theme widget đôi, cùng công thức WidgetThemeDesign Flutter và Android.
enum UtilityThemeColors {
    /// Khớp WidgetTheme.accentColor (màu số ngày của widget đôi iOS).
    static let accentHex: [String: String] = [
        "pink": "FF4D73", "dark": "FF8FB1", "white": "D6336C", "blue": "1565C0",
        "orange": "EA580C", "purple": "8B5CF6", "green": "10B981", "red": "FFF0DC",
        "premium": "FFF1B5", "cosmic": "FFF0BD",
    ]
    static func isDark(_ theme: String) -> Bool {
        ["dark", "red", "premium", "cosmic"].contains(WidgetAppearanceDesign.theme(theme))
    }
    private static func accentValue(_ theme: String) -> String {
        accentHex[WidgetAppearanceDesign.theme(theme)] ?? "FF4D73"
    }
    static func accent(_ theme: String) -> Color { Color(hex: accentValue(theme)) }
    static func track(_ theme: String) -> Color {
        mix(accentValue(theme), "FFFFFF", isDark(theme) ? 0.52 : 0.72)
    }
    static func card(_ theme: String) -> Color {
        isDark(theme) ? Color.black.opacity(0.22) : Color.white.opacity(0.48)
    }
    static func avatar(_ theme: String) -> Color {
        if isDark(theme) { return Color.white.opacity(0.14) }
        let first = WidgetAppearanceDesign.palettes[WidgetAppearanceDesign.theme(theme)]?.first ?? "FFF3E5"
        return mix(first, "FFFFFF", 0.52)
    }
    /// Số đếm sự kiện: màu theme pha nhẹ màu riêng như widget đôi pha màu tim.
    static func days(_ theme: String, tintHex: String) -> Color {
        mix(accentValue(theme), tintHex, isDark(theme) ? 0.28 : 0.36)
    }
    static func mix(_ from: String, _ to: String, _ t: Double) -> Color {
        func rgb(_ hex: String) -> (Double, Double, Double) {
            let value = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
            return (Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255))
        }
        let a = rgb(from), b = rgb(to)
        return Color(red: (a.0 + (b.0 - a.0) * t) / 255,
                     green: (a.1 + (b.1 - a.1) * t) / 255,
                     blue: (a.2 + (b.2 - a.2) * t) / 255)
    }
}

struct SleepWidgetPerson {
    var name = "", state = "unknown", source = "unknown"
    var start: Double = 0, end: Double = 0, duration: Double = 0, updated: Double = 0
    func effectiveState(at date: Date) -> String {
        if state == "disabled" { return state }
        let now = date.timeIntervalSince1970 * 1000
        if state == "recorded" {
            return source == "healthkit" && start > 0 && end > start && end <= now && duration > 0 && duration <= end-start ? "recorded" : "unknown"
        }
        guard source == "manual" || source == "screen_estimate", ["manual","estimated","active","inactive","unknown"].contains(state) else { return "unknown" }
        if state == "manual" || state == "estimated" {
            guard start > 0 && start <= now && now-start <= 86400000 else { return "unknown" }
        }
        let limit: Double = source == "manual" ? 86400000 : 900000
        return updated > 0 && now >= updated && now - updated <= limit ? state : "unknown"
    }
    static func load() -> [SleepWidgetPerson] {
        guard let json = UserDefaults(suiteName: appGroupID)?.string(forKey: "sleep_snapshot_v2"),
              let bytes = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              (root["version"] as? Int) == 2,
              let uid = root["uid"] as? String, !uid.isEmpty,
              let houseId = root["houseId"] as? String, !houseId.isEmpty,
              let people = root["people"] as? [[String: Any]], people.count == 2 else {
            return [SleepWidgetPerson(), SleepWidgetPerson()]
        }
        return people.map { p in
            SleepWidgetPerson(name: p["name"] as? String ?? "", state: p["state"] as? String ?? "unknown", source: p["source"] as? String ?? "unknown",
                start: (p["start"] as? NSNumber)?.doubleValue ?? 0, end: (p["end"] as? NSNumber)?.doubleValue ?? 0,
                duration: (p["duration"] as? NSNumber)?.doubleValue ?? 0, updated: (p["updated"] as? NSNumber)?.doubleValue ?? 0)
        }
    }
}

struct UtilityWidgetData {
    var values: [String: String] = [:]
    var themeKey = "pink"
    var weatherBackground = WidgetWeatherSnapshot()
    var cycleEnabled = false
    var calendarEnabled = false
    var calendarPayloadVersion = 0
    var calendarDateKey = ""
    var calendarUid = ""
    var calendarHouseId = ""
    var calendarTimeZone = ""
    var calendarLocale = "en"
    var animated = false
    var sleepers = [SleepWidgetPerson(), SleepWidgetPerson()]
    var hasEvent = false
    func text(_ key: String) -> String { values[key] ?? "" }
    func calendarDaysRemaining(at date: Date) -> Int? {
        guard calendarDateKey.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else { return nil }
        let parts = calendarDateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...2100).contains(parts[0]),
              calendarTimeZone.isEmpty || TimeZone(identifier: calendarTimeZone) != nil else { return nil }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendarTimeZone.isEmpty ? .current : TimeZone(identifier: calendarTimeZone)!
        let today = local.dateComponents([.year, .month, .day], from: date)
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let target = civil.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let start = civil.date(from: today) else { return nil }
        let check = civil.dateComponents([.year, .month, .day], from: target)
        guard check.year == parts[0], check.month == parts[1], check.day == parts[2] else { return nil }
        return civil.dateComponents([.day], from: start, to: target).day
    }
    func calendarCountdown(at date: Date) -> String {
        guard let days = calendarDaysRemaining(at: date), days >= 0 else { return "" }
        if days == 0 { return text("calendar_today_label") }
        if days == 1 { return text("calendar_tomorrow_label") }
        return text("calendar_days_left_template").replacingOccurrences(of: "{days}", with: String(days))
    }
    static func load() -> UtilityWidgetData {
        let defaults = UserDefaults(suiteName: appGroupID)
        let keys = ["cycle_phase_label", "cycle_next_period_in", "cycle_tip", "cycle_progress",
            "cycle_next_period_days", "cycle_target_label", "cycle_expected_date", "cycle_estimate_label",
            "calendar_countdown", "calendar_next_date", "calendar_events_text",
            "se_title", "se_date", "se_days", "se_label", "se_color", "se_target_date",
            "sleep_my_name", "sleep_partner_name", "sleep_my_status", "sleep_partner_status",
            "sleep_my_time", "sleep_partner_time", "sleep_summary"]
        var data = UtilityWidgetData()
        data.themeKey = WidgetAppearanceDesign.theme(defaults?.string(forKey: "bgTheme") ?? "pink")
        data.weatherBackground = WidgetWeatherSnapshot.load(defaults)
        for key in keys { data.values[key] = defaults?.string(forKey: key) ?? "" }
        data.sleepers = SleepWidgetPerson.load()
        data.hasEvent = defaults?.bool(forKey: "se_has_event") ?? false
        data.cycleEnabled = defaults?.bool(forKey: "cycle_enabled") ?? false
        data.calendarEnabled = defaults?.bool(forKey: "calendar_enabled") ?? false
        data.calendarPayloadVersion = defaults?.integer(forKey: "calendar_payload_version") ?? 0
        data.calendarDateKey = defaults?.string(forKey: "calendar_next_date_key") ?? ""
        if let snapshotText = defaults?.string(forKey: "calendar_snapshot_v2"),
           let bytes = snapshotText.data(using: .utf8),
           let snapshot = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
           snapshot["version"] as? Int == 2 {
            data.calendarPayloadVersion = 2
            data.calendarEnabled = snapshot["enabled"] as? Bool ?? false
            data.calendarDateKey = snapshot["dateKey"] as? String ?? ""
            data.calendarUid = snapshot["uid"] as? String ?? ""
            data.calendarHouseId = snapshot["houseId"] as? String ?? ""
            data.calendarTimeZone = snapshot["timeZone"] as? String ?? ""
            data.calendarLocale = snapshot["locale"] as? String ?? "en"
            data.values["calendar_today_label"] = snapshot["todayLabel"] as? String ?? ""
            data.values["calendar_tomorrow_label"] = snapshot["tomorrowLabel"] as? String ?? ""
            data.values["calendar_days_left_template"] = snapshot["daysLeftTemplate"] as? String ?? ""
            data.values["calendar_countdown"] = snapshot["countdown"] as? String ?? ""
            data.values["calendar_next_date"] = snapshot["nextDate"] as? String ?? ""
            data.values["calendar_events_text"] = snapshot["events"] as? String ?? ""
        }
        data.animated = defaults?.bool(forKey: "heartAnimated") ?? false
        return data
    }
    static func preview() -> UtilityWidgetData {
        var data = UtilityWidgetData()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let eventDate = Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        let civil = Calendar.current.dateComponents([.year, .month, .day], from: eventDate)
        let eventKey = String(format: "%04d-%02d-%02d", civil.year ?? 2026, civil.month ?? 1, civil.day ?? 1)
        data.themeKey = "pink"
        data.cycleEnabled = true
        data.calendarEnabled = true
        data.calendarPayloadVersion = 2
        let gregorian = Calendar(identifier: .gregorian)
        let calendarCivil = gregorian.dateComponents([.year, .month, .day], from: tomorrow)
        data.calendarDateKey = String(format: "%04d-%02d-%02d", calendarCivil.year ?? 2026, calendarCivil.month ?? 1, calendarCivil.day ?? 1)
        data.calendarUid = "preview-user"
        data.calendarHouseId = "preview-house"
        data.hasEvent = true
        data.sleepers = [SleepWidgetPerson(name: widgetText("p3_sleep_default_me"), state: "recorded", source: "healthkit", start: Date().timeIntervalSince1970 * 1000 - 30000000, end: Date().timeIntervalSince1970 * 1000 - 600000, duration: 27300000),
            SleepWidgetPerson(name: widgetText("p3_sleep_default_partner"), state: "unknown", source: "unknown")]
        data.values = ["cycle_phase_label": widgetText("p3_health_phase_period"),
            "cycle_next_period_in": widgetText("p3_health_next_period"),
            "cycle_next_period_days": "12",
            "cycle_progress": "0.65", "calendar_countdown": widgetText("milestone_tomorrow"),
            "calendar_today_label": widgetText("milestone_today"),
            "calendar_tomorrow_label": widgetText("milestone_tomorrow"),
            "calendar_days_left_template": widgetText("milestone_days_left"),
            "calendar_next_date": DateFormatter.localizedString(from: tomorrow, dateStyle: .medium, timeStyle: .none),
            "calendar_events_text": widgetText("p8_events_title"),
            "se_title": widgetText("home_knim_4f6aeb"), "se_days": "12",
            "se_date": DateFormatter.localizedString(from: eventDate, dateStyle: .medium, timeStyle: .none),
            "se_target_date": eventKey,
            "se_label": widgetText("p8_events_days_remaining_label"),
            "sleep_my_name": widgetText("p3_sleep_default_me"),
            "sleep_partner_name": widgetText("p3_sleep_default_partner"),
            "sleep_my_status": widgetText("p3_sleep_sleeping"),
            "sleep_partner_status": widgetText("p3_sleep_sleeping"),
            "sleep_summary": widgetText("p3_sleep_both_sleeping")]
        return data
    }
}

struct UtilityWidgetEntry: TimelineEntry {
    let date: Date
    let data: UtilityWidgetData
}

struct UtilityWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UtilityWidgetEntry {
        UtilityWidgetEntry(date: Date(), data: .preview())
    }
    func getSnapshot(in context: Context, completion: @escaping (UtilityWidgetEntry) -> Void) {
        completion(UtilityWidgetEntry(date: Date(), data: context.isPreview ? .preview() : .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UtilityWidgetEntry>) -> Void) {
        let now = Date(), data = UtilityWidgetData.load()
        var dates = (0...12).map { now.addingTimeInterval(Double($0) * 1800) }
        // Entry hết hạn giúp trạng thái cũ chuyển thành chưa biết, không chờ app mở.
        for p in data.sleepers where p.updated > 0 && p.state != "recorded" && p.state != "disabled" {
            let expiry = Date(timeIntervalSince1970: (p.updated + (p.source == "manual" ? 86400000 : 900000) + 1) / 1000)
            if expiry > now && expiry < now.addingTimeInterval(21600) { dates.append(expiry) }
        }
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        if midnight < now.addingTimeInterval(21600) { dates.append(midnight) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: data.calendarTimeZone) ?? .current
        if let zoneMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           zoneMidnight < now.addingTimeInterval(21600) { dates.append(zoneMidnight) }
        if data.weatherBackground.proExpiresAtMs > 0 {
            let expiry = Date(timeIntervalSince1970: data.weatherBackground.proExpiresAtMs / 1000)
            if expiry > now && expiry < now.addingTimeInterval(21600) { dates.append(expiry) }
        }
        let entries = Array(Set(dates)).sorted().map { UtilityWidgetEntry(date: $0, data: data) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct WidgetUtilityView: View {
    let kind: UtilityWidgetKind
    let data: UtilityWidgetData
    let date: Date
    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var alternate: Bool { WidgetAppearanceDesign.alternate(at: date, enabled: data.animated && !reduceMotion) }
    private var enabled: Bool {
        kind == .cycle ? data.cycleEnabled : data.calendarPayloadVersion == 2 &&
            !data.calendarUid.isEmpty && !data.calendarHouseId.isEmpty &&
            (data.calendarDaysRemaining(at: date) ?? -1) >= 0 &&
            data.calendarEnabled && !data.text("calendar_next_date").isEmpty
    }
    private var progress: Double {
        let value = Double(data.text("cycle_progress")) ?? 0
        return value.isFinite ? max(0, min(1, value)) : 0
    }
    private var cycleDays: String {
        let value = data.text("cycle_next_period_days").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "—" : value
    }
    private func line(_ value: String, size: CGFloat = 12, lines: Int = 1) -> some View {
        Text(value).font(.system(size: size, weight: .semibold, design: .rounded))
            .lineLimit(lines).minimumScaleFactor(0.65).foregroundColor(kind.ink(for: data.themeKey))
    }
    @ViewBuilder private func planContent(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if enabled {
                if kind == .cycle {
                    if small {
                        VStack(spacing: 4) {
                            CycleDayRing(days: cycleDays, progress: progress, diameter: min(52, max(40, height - 91)), ink: kind.ink(for: data.themeKey),
                                accent: UtilityThemeColors.accent(data.themeKey), track: UtilityThemeColors.track(data.themeKey))
                            line(cycleTarget, size: 9, lines: 1)
                            line(data.text("cycle_phase_label"), size: 10)
                        }.frame(maxWidth: .infinity)
                    } else {
                        HStack(alignment: .center, spacing: 10) {
                            CycleDayRing(days: cycleDays, progress: progress, diameter: large ? 94 : min(72, max(48, height - 74)), ink: kind.ink(for: data.themeKey),
                                accent: UtilityThemeColors.accent(data.themeKey), track: UtilityThemeColors.track(data.themeKey))
                            VStack(alignment: .leading, spacing: 5) {
                                line(cycleTarget, size: large ? 12 : 10, lines: 2)
                                line(data.text("cycle_phase_label"), size: large ? 22 : height < 155 ? 14 : 16, lines: 2)
                                line(data.text("cycle_expected_date").isEmpty ? data.text("cycle_next_period_in") : data.text("cycle_expected_date"), size: large ? 12 : 9, lines: 2)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if large {
                        line(data.text("cycle_estimate_label").isEmpty ? widgetText("cycle_ui_estimate") : data.text("cycle_estimate_label"), size: 10, lines: 2).opacity(0.8)
                    }
                } else {
                    line(data.calendarCountdown(at: date), size: large ? 26 : small ? 15 : 20, lines: 2)
                    line(data.text("calendar_next_date"), size: 11).opacity(0.8)
                    line(data.text("calendar_events_text"), size: large ? 14 : 10, lines: large ? 3 : 2)
                }
            } else {
                WidgetArtwork(name: kind.artwork).frame(height: large ? 58 : 28).frame(maxWidth: .infinity)
                line(widgetText(kind == .cycle ? "util_health_enable_cycle_tracking" : "widget_sync_empty"), size: 11, lines: 3)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(small ? 8 : 10).background(UtilityThemeColors.card(data.themeKey).clipShape(RoundedRectangle(cornerRadius: 16)))
    }
    private var cycleTarget: String {
        let value = data.text("cycle_target_label")
        return value.isEmpty ? widgetText("cycle_ui_until_next_period") : value
    }
    @ViewBuilder var body: some View {
        if kind == .sleep || kind == .event {
            WidgetSleepEventView(kind: kind, data: data, date: date)
        } else {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        WidgetArtwork(name: kind.artwork).frame(width: 26, height: 22)
                            .rotationEffect(.degrees(kind == .cycle && alternate ? 4 : 0))
                        line(widgetText(kind.titleKey))
                        Spacer(minLength: 0)
                    }
                    if large { WidgetArtwork(name: kind.artwork).frame(height: 74).frame(maxWidth: .infinity).padding(.top, 4)
                            .rotationEffect(.degrees(kind == .cycle && alternate ? -4 : 0)) }
                    planContent(height: proxy.size.height)
                }.padding(large ? 16 : small ? 9 : 12).frame(width: proxy.size.width, height: proxy.size.height)
            }.clipShape(RoundedRectangle(cornerRadius: 24))
                .modifier(WidgetUtilityBackground(kind: kind, themeKey: data.themeKey, alternate: alternate, weather: data.weatherBackground, referenceDate: date))
                .animation(data.animated && !reduceMotion ? .easeInOut(duration: 0.4) : nil, value: alternate)
                .widgetURL(URL(string: "soullocket://widget?action=" + kind.action)).privacySensitive()
                .environment(\.layoutDirection, kind == .calendar ?
                    (data.calendarLocale.hasPrefix("ar") ? .rightToLeft : .leftToRight) : layoutDirection)
        }
    }
}

private struct CycleDayRing: View {
    let days: String
    let progress: Double
    let diameter: CGFloat
    let ink: Color
    let accent: Color
    let track: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(track, lineWidth: diameter >= 90 ? 8 : 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: diameter >= 90 ? 8 : 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(diameter >= 90 ? 4 : 3)
            VStack(spacing: 2) {
                Text(days)
                    .font(.system(size: diameter >= 90 ? 25 : diameter >= 70 ? 20 : 16, weight: .heavy, design: .rounded))
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(widgetText("p3_health_days_remaining"))
                    .font(.system(size: diameter >= 90 ? 8 : 7, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }.padding(.horizontal, diameter >= 90 ? 11 : 9)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days + " " + widgetText("p3_health_days_remaining"))
    }
}

struct WidgetCycleProvider: Widget {
    let kind = "WidgetCycleProvider"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UtilityWidgetProvider()) { entry in
            WidgetUtilityView(kind: .cycle, data: entry.data, date: entry.date)
        }.configurationDisplayName(Text("p3_health_header_cycle", tableName: "WidgetStrings"))
            .description(Text("widget_home_desc", tableName: "WidgetStrings"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}
struct WidgetCalendarProvider: Widget {
    let kind = "WidgetCalendarProvider"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UtilityWidgetProvider()) { entry in
            WidgetUtilityView(kind: .calendar, data: entry.data, date: entry.date)
        }.configurationDisplayName(Text("home_lchchung_ac8882", tableName: "WidgetStrings"))
            .description(Text("widget_home_desc", tableName: "WidgetStrings"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}
struct WidgetSoulEventProvider: Widget {
    let kind = "WidgetSoulEventProvider"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UtilityWidgetProvider()) { entry in
            WidgetUtilityView(kind: .event, data: entry.data, date: entry.date)
        }.configurationDisplayName(Text("p8_events_title", tableName: "WidgetStrings"))
            .description(Text("p7_event_widget_desc", tableName: "WidgetStrings"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}
struct WidgetSleepProvider: Widget {
    let kind = "WidgetSleepProvider"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UtilityWidgetProvider()) { entry in
            WidgetUtilityView(kind: .sleep, data: entry.data, date: entry.date)
        }.configurationDisplayName(Text("widget_title_sleep", tableName: "WidgetStrings"))
            .description(Text("widget_home_desc", tableName: "WidgetStrings"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge]).contentMarginsDisabled()
    }
}

private func sleepStateKey(_ state: String) -> String {
    switch state {
    case "manual": return "sleep_state_manual"
    case "estimated": return "sleep_state_estimated"
    case "recorded": return "sleep_state_recorded"
    case "disabled": return "sleep_state_disabled"
    case "active": return "p3_sleep_active"
    case "inactive": return "p3_sleep_offline"
    default: return "sleep_state_unknown"
    }
}
private func sleepDurationText(_ duration: Double) -> String {
    let minutes = Int(max(0, duration) / 60000)
    return widgetText("sleep_duration")
        .replacingOccurrences(of: "{hours}", with: String(minutes / 60))
        .replacingOccurrences(of: "{minutes}", with: String(minutes % 60))
}
private struct WidgetUtilityBackdrop: View {
    let kind: UtilityWidgetKind
    let themeKey: String
    let alternate: Bool
    let weather: WidgetWeatherSnapshot
    let referenceDate: Date
    var body: some View {
        ZStack(alignment: .topTrailing) {
            let allowedTheme = weather.allowedTheme(themeKey, at: referenceDate)
            if allowedTheme == "weather_premium" {
                WidgetWeatherBackdrop(weather: weather, alternate: alternate,
                    artworkOpacity: kind == .sleep ? 0.22 : 0.18)
            } else {
            LinearGradient(colors: kind.palette(for: allowedTheme), startPoint:.topLeading,endPoint:.bottomTrailing)
            // Lớp họa tiết chủ đề chung chỉ ở mức nhẹ; nền ngủ/sự kiện vẫn giữ bản sắc riêng.
            Image("widget_theme_" + allowedTheme + (alternate ? "_twinkle" : ""))
                .resizable().renderingMode(.original).opacity(kind == .sleep ? 0.22 : 0.18)
            }
            WidgetArtwork(name:kind.artwork).frame(width:105,height:105)
                .opacity(kind == .sleep ? 0.08 : 0.14).padding(12)
        }.clipShape(RoundedRectangle(cornerRadius:24))
    }
}
private struct WidgetUtilityBackground: ViewModifier {
    let kind: UtilityWidgetKind
    let themeKey: String
    let alternate: Bool
    let weather: WidgetWeatherSnapshot
    let referenceDate: Date
    @ViewBuilder func body(content:Content)->some View {
        if #available(iOSApplicationExtension 17.0,*) { content.containerBackground(for:.widget) { WidgetUtilityBackdrop(kind:kind, themeKey:themeKey, alternate:alternate, weather:weather, referenceDate:referenceDate) } }
        else { content.background(WidgetUtilityBackdrop(kind:kind, themeKey:themeKey, alternate:alternate, weather:weather, referenceDate:referenceDate)) }
    }
}
struct WidgetSleepEventView: View {
    let kind:UtilityWidgetKind, data:UtilityWidgetData, date:Date
    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var alternate: Bool { WidgetAppearanceDesign.alternate(at:date, enabled:data.animated && !reduceMotion) }
    private var small:Bool { family == .systemSmall }
    private var large:Bool { family == .systemLarge }
    private var ink:Color { kind.ink(for: data.themeKey) }
    private func line(_ value:String,size:CGFloat=12,lines:Int=1)->some View {
        Text(value).font(.system(size:size,weight:.semibold,design:.rounded)).foregroundColor(ink).lineLimit(lines).minimumScaleFactor(0.7)
    }
    private func person(_ p:SleepWidgetPerson,index:Int)->some View {
        let state=p.effectiveState(at:date)
        return VStack(alignment:.leading,spacing:large ? 6 : 4) {
            HStack(spacing:6) {
                WidgetArtwork(name:index == 0 ? "widget_avatar_warm" : "widget_avatar_cream")
                    .frame(width:large ? 32 : 27,height:large ? 32 : 27)
                    .background(UtilityThemeColors.avatar(data.themeKey).clipShape(RoundedRectangle(cornerRadius:10)))
                line(p.name.isEmpty ? widgetText(index == 0 ? "p3_sleep_default_me" : "p3_sleep_default_partner") : p.name,size:large ? 15 : 11)
            }
            line(widgetText(sleepStateKey(state)),size:large ? 14 : 10,lines:2)
            if state == "recorded" {
                line(sleepDurationText(p.duration),size:large ? 24 : 18,lines:2)
                if large && p.end > 0 { Text(Date(timeIntervalSince1970:p.end/1000),style:.date).font(.system(size:11)).foregroundColor(ink.opacity(0.7)) }
            } else if state == "manual" && p.start > 0 {
                Text(Date(timeIntervalSince1970:p.start/1000),style:.timer).font(.system(size:large ? 24 : 16,weight:.bold,design:.rounded)).foregroundColor(ink)
            }
            if !small {
                line(p.source == "healthkit" ? "Apple Health" : widgetText(p.source == "manual" ? "sleep_source_manual" : p.source == "screen_estimate" ? "sleep_source_estimate" : "sleep_sync_hint"),size:9,lines:large ? 2 : 1).opacity(0.65)
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
         .padding(large ? 12 : 8).background(UtilityThemeColors.card(data.themeKey).clipShape(RoundedRectangle(cornerRadius:16)))
    }
    private func smallPerson(_ p:SleepWidgetPerson,index:Int)->some View {
        let state=p.effectiveState(at:date)
        return HStack(spacing:7) {
            WidgetArtwork(name:index == 0 ? "widget_avatar_warm" : "widget_avatar_cream")
                .frame(width:22,height:26).background(UtilityThemeColors.avatar(data.themeKey).clipShape(RoundedRectangle(cornerRadius:8)))
            VStack(alignment:.leading,spacing:3) {
                line(p.name.isEmpty ? widgetText(index == 0 ? "p3_sleep_default_me" : "p3_sleep_default_partner") : p.name,size:10)
                line(widgetText(sleepStateKey(state)),size:8)
                if state == "recorded" { line(sleepDurationText(p.duration),size:12) }
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(7).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading)
            .background(UtilityThemeColors.card(data.themeKey).clipShape(RoundedRectangle(cornerRadius:13)))
    }
    private var eventAccent:Color {
        let hex=data.text("se_color").replacingOccurrences(of:"#",with:"")
        let tint = hex.count == 6 && Int(hex,radix:16) != nil ? hex : "984C36"
        return UtilityThemeColors.days(data.themeKey, tintHex: tint)
    }
    private var eventDays:String {
        let pieces=data.text("se_target_date").split(separator:"-").compactMap{Int($0)}
        let calendar=Calendar(identifier:.gregorian)
        guard pieces.count == 3,let target=calendar.date(from:DateComponents(year:pieces[0],month:pieces[1],day:pieces[2])) else { return data.text("se_days").isEmpty ? "—" : data.text("se_days") }
        let count=calendar.dateComponents([.day],from:calendar.startOfDay(for:date),to:target).day ?? 0
        return count < 0 ? "—" : count == 0 ? widgetText("p8_events_today_upper") : String(count)
    }
    var body:some View {
        GeometryReader { proxy in
            VStack(alignment:.leading,spacing:large ? 12 : 6) {
                HStack(spacing:6) { WidgetArtwork(name:kind.artwork).frame(width:24,height:20);line(widgetText(kind.titleKey),size:12);Spacer(minLength:0) }
                if kind == .sleep {
                    if large { WidgetArtwork(name:"widget_moon" + (alternate ? "_twinkle" : "")).frame(height:44).frame(maxWidth:.infinity) }
                    if small {
                        VStack(spacing:5) { smallPerson(data.sleepers[0],index:0); smallPerson(data.sleepers[1],index:1) }
                    } else {
                        HStack(alignment:.top,spacing:8) { person(data.sleepers[0],index:0); person(data.sleepers[1],index:1) }
                    }
                    if large { line(widgetText("sleep_tracking_info_ios"),size:10,lines:3).opacity(0.65) }
                } else if data.hasEvent {
                    if large { WidgetArtwork(name:"widget_gift" + (alternate ? "_twinkle" : "")).frame(height:74).frame(maxWidth:.infinity) }
                    line(data.text("se_title"),size:large ? 20 : 14,lines:large ? 2 : 1)
                    HStack(alignment:.center,spacing:12) {
                        VStack(alignment:.leading,spacing:3) {
                            Text(eventDays).font(.system(size:large ? 50 : small ? 28 : 33,weight:.heavy,design:.rounded)).foregroundColor(eventAccent).lineLimit(1).minimumScaleFactor(0.6)
                            line(eventDays == "—" ? widgetText("widget_sync_empty") : eventDays == widgetText("p8_events_today_upper") ? "✦" : widgetText("p8_events_days_remaining_label"),size:10,lines:2).opacity(0.7)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        if !small { WidgetArtwork(name:"widget_gift" + (alternate ? "_twinkle" : "")).frame(width:large ? 48 : 54,height:54) }
                    }.frame(maxHeight: .infinity)
                    line(data.text("se_date"),size:11).opacity(0.65)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetArtwork(name:"widget_gift").frame(height:small ? 34 : 48).frame(maxWidth:.infinity).padding(.bottom, 4)
                        line(widgetText("p8_events_empty_title"),size:12,lines:2)
                        line(widgetText("widget_sync_empty"),size:10,lines:2)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }.padding(large ? 16 : 12).frame(width:proxy.size.width,height:proxy.size.height)
        }.clipShape(RoundedRectangle(cornerRadius:24))
         .modifier(WidgetUtilityBackground(kind:kind, themeKey:data.themeKey, alternate:alternate))
         .animation(data.animated && !reduceMotion ? .easeInOut(duration:0.4) : nil, value:alternate)
         .widgetURL(URL(string:"soullocket://widget?action="+kind.action)).privacySensitive()
    }
}
