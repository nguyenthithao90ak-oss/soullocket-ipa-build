#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// Định nghĩa cấu hình thuộc tính cho Live Activity dùng chung giữa Extension và Main App
@available(iOS 16.1, *)
public struct SoulLocketActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var endTime: Date
        public var label: String
    }

    public var title: String

    public init(title: String) {
        self.title = title
    }
}

@available(iOS 16.1, *)
struct SoulLocketLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SoulLocketActivityAttributes.self) { context in
            // Giao diện hiển thị trên Màn hình khóa (Lock Screen) và Thông báo (Banner)
            VStack(spacing: 8) {
                HStack {
                    Text("💞 SoulLocket")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color(hexStr: "FF4D73"))
                    Spacer()
                    Text(context.attributes.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(context.state.label)
                        .font(.system(.body, design: .rounded))
                        .bold()
                    Spacer()
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(Color(hexStr: "FF4D73"))
                        .monospacedDigit()
                }
            }
            .padding()
            .activityBackgroundTint(Color(hexStr: "FFEEF5"))
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Giao diện mở rộng khi giữ ngón tay trên Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text("💞")
                        Text("SoulLocket")
                            .font(.system(.body, design: .rounded))
                            .bold()
                            .foregroundColor(Color(hexStr: "FF8FB1"))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(.body, design: .rounded))
                        .bold()
                        .foregroundColor(Color(hexStr: "FF4D73"))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.label)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                }
            } compactLeading: {
                Text("💞")
            } compactTrailing: {
                // Đếm ngược thời gian thực trên thanh trạng thái Dynamic Island
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(.caption2, design: .rounded))
                    .bold()
                    .foregroundColor(Color(hexStr: "FF4D73"))
                    .monospacedDigit()
            } minimal: {
                Text("💞")
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

