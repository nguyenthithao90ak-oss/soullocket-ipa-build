import AppIntents
import WidgetKit
import Foundation

@available(iOS 17.0, *)
public struct SendQuickActionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Thả tim nhanh"
    public static var description = IntentDescription("Gửi tim nhanh cho người ấy trực tiếp từ widget.")

    @Parameter(title: "Hành động")
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
