#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// Khớp hợp đồng của live_activities: payload nằm trong App Group theo UUID.
@available(iOS 16.1, *)
public struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        public var appGroupId: String?
    }

    public var id = UUID()

    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

@available(iOS 16.1, *)
private struct LiveActivityCoupleData {
    let title: String
    let days: Int
    let avatar1Path: String?
    let avatar2Path: String?

    init(attributes: LiveActivitiesAppAttributes, state: LiveActivitiesAppAttributes.ContentState) {
        let defaults = state.appGroupId == appGroupID ? UserDefaults(suiteName: appGroupID) : nil
        title = defaults?.string(forKey: attributes.prefixedKey("title")) ?? ""
        days = max(0, defaults?.integer(forKey: attributes.prefixedKey("days")) ?? 0)
        avatar1Path = Self.avatarPath("avatar1", attributes: attributes, defaults: defaults)
        avatar2Path = Self.avatarPath("avatar2", attributes: attributes, defaults: defaults)
    }

    private static func avatarPath(
        _ key: String, attributes: LiveActivitiesAppAttributes, defaults: UserDefaults?
    ) -> String? {
        // Chỉ dùng ảnh widget đã đồng bộ đúng URL; không lấy nhầm ảnh cũ khi đổi ảnh/nhà.
        guard let expectedURL = defaults?.string(forKey: attributes.prefixedKey(key))?
                .trimmingCharacters(in: .whitespacesAndNewlines), !expectedURL.isEmpty,
              let cachedURL = defaults?.string(forKey: "\(key)Url")?
                .trimmingCharacters(in: .whitespacesAndNewlines), cachedURL == expectedURL,
              let path = defaults?.string(forKey: "\(key)Path"), !path.isEmpty,
              let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }

        let file = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let container = groupContainer.resolvingSymlinksInPath().standardizedFileURL
        guard file.path.hasPrefix(container.path + "/") else { return nil }
        return file.path
    }
}

private struct LiveActivityAvatar: View {
    let path: String?
    let size: CGFloat
    let fallbackColor: Color

    var body: some View {
        if let path = path, let image = downsampleImage(at: path, to: CGSize(width: size, height: size)) {
            Image(uiImage: image).resizable().frame(width: size, height: size).clipShape(Circle())
        } else {
            Circle().fill(fallbackColor).frame(width: size, height: size)
        }
    }
}

@available(iOS 16.1, *)
struct SoulLocketLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = LiveActivityCoupleData(attributes: context.attributes, state: context.state)
            // Giao diện hiển thị trên Màn hình khóa (Lock Screen) và Thông báo (Banner)
            HStack(spacing: 16) {
                LiveActivityAvatar(path: data.avatar1Path, size: 50, fallbackColor: Color(hexStr: "FF4D73"))
                
                VStack {
                    Text(data.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    HStack {
                        Text("💞").font(.system(size: 16))
                        Text("\(data.days) \(widgetText("comm_ngy_41ec10"))")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .foregroundColor(Color(hexStr: "FF4D73"))
                        Text("💞").font(.system(size: 16))
                    }
                }
                
                LiveActivityAvatar(path: data.avatar2Path, size: 50, fallbackColor: Color(hexStr: "FF8FB1"))
            }
            .padding()
            .activityBackgroundTint(Color(hexStr: "FFEEF5"))
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            let data = LiveActivityCoupleData(attributes: context.attributes, state: context.state)
            return DynamicIsland {
                // Giao diện mở rộng khi giữ ngón tay trên Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityAvatar(path: data.avatar1Path, size: 40, fallbackColor: Color(hexStr: "FF4D73"))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityAvatar(path: data.avatar2Path, size: 40, fallbackColor: Color(hexStr: "FF8FB1"))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("💞").font(.system(size: 14))
                        Text("\(data.days) \(widgetText("comm_ngy_41ec10"))")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(Color(hexStr: "FF4D73"))
                        Text("💞").font(.system(size: 14))
                    }
                }
            } compactLeading: {
                Text("💞").foregroundColor(Color(hexStr: "FF4D73"))
            } compactTrailing: {
                Text("\(data.days)")
                    .accessibilityLabel("\(data.days) \(widgetText("comm_ngy_41ec10"))")
                    .font(.system(.caption2, design: .rounded))
                    .bold()
                    .foregroundColor(Color(hexStr: "FF4D73"))
            } minimal: {
                Text("💞").foregroundColor(Color(hexStr: "FF4D73"))
            }
        }
    }
}

// Extension helper cho màu Color từ mã Hex để dùng thống nhất trong hệ thống giao diện
fileprivate extension Color {
    init(hexStr: String) {
        let sanitized = hexStr.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
#endif

