#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// Định nghĩa cấu hình thuộc tính cho Live Activity dùng chung giữa Extension và Main App
@available(iOS 16.1, *)
public struct LiveActivitiesAppAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var avatar1: String
        public var avatar2: String
        public var days: Int
        public var title: String
    }
    public init() {}
}

@available(iOS 16.1, *)
struct SoulLocketLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Giao diện hiển thị trên Màn hình khóa (Lock Screen) và Thông báo (Banner)
            HStack(spacing: 16) {
                if let url = URL(string: context.state.avatar1), let imageData = try? Data(contentsOf: url), let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().frame(width: 50, height: 50).clipShape(Circle())
                } else {
                    Circle().fill(Color(hexStr: "FF4D73")).frame(width: 50, height: 50)
                }
                
                VStack {
                    Text(context.state.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    HStack {
                        Text("💞").font(.system(size: 16))
                        Text("\(context.state.days) Days")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .foregroundColor(Color(hexStr: "FF4D73"))
                        Text("💞").font(.system(size: 16))
                    }
                }
                
                if let url = URL(string: context.state.avatar2), let imageData = try? Data(contentsOf: url), let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().frame(width: 50, height: 50).clipShape(Circle())
                } else {
                    Circle().fill(Color(hexStr: "FF8FB1")).frame(width: 50, height: 50)
                }
            }
            .padding()
            .activityBackgroundTint(Color(hexStr: "FFEEF5"))
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Giao diện mở rộng khi giữ ngón tay trên Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    if let url = URL(string: context.state.avatar1), let imageData = try? Data(contentsOf: url), let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().frame(width: 40, height: 40).clipShape(Circle())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let url = URL(string: context.state.avatar2), let imageData = try? Data(contentsOf: url), let image = UIImage(data: imageData) {
                        Image(uiImage: image).resizable().frame(width: 40, height: 40).clipShape(Circle())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("💞").font(.system(size: 14))
                        Text("\(context.state.days) Days")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(Color(hexStr: "FF4D73"))
                        Text("💞").font(.system(size: 14))
                    }
                }
            } compactLeading: {
                Text("💞").foregroundColor(Color(hexStr: "FF4D73"))
            } compactTrailing: {
                Text("\(context.state.days)d")
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

