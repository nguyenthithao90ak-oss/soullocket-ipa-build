import AppIntents
import WidgetKit
import Foundation

@available(iOS 17.0, *)
public struct SendQuickActionIntent: AppIntent {
    public static var title: LocalizedStringResource = .init(
        "widget_quick_heart_title", defaultValue: "Send a quick heart", table: "WidgetStrings")
    public static var description = IntentDescription(LocalizedStringResource(
        "widget_quick_heart_description",
        defaultValue: "Send a quick heart to your partner right from the widget.",
        table: "WidgetStrings"))

    @Parameter(title: LocalizedStringResource(
        "widget_quick_action", defaultValue: "Action", table: "WidgetStrings"))
    public var actionType: String

    public init() {
        self.actionType = "heart"
    }

    public init(actionType: String) {
        self.actionType = actionType
    }

    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.WidgetCoupleProvider"
        let defaults = UserDefaults(suiteName: appGroupID)
        let timestamp = Int(Date().timeIntervalSince1970)
        let actionString = "\(actionType)_\(timestamp)"
        
        defaults?.set(actionString, forKey: "pendingWidgetAction")
        defaults?.synchronize()
        
        // Cập nhật lại các tiện ích khác nếu có
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}
