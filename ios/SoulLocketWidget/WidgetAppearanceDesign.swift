import SwiftUI
import WidgetKit

/// Cùng danh mục đã lưu và cùng SVG với Flutter/Android, không dùng font emoji.
enum WidgetAppearanceDesign {
    static let hearts: [String: String] = [
        "❤️": "widget_heart_red",
        "🧡": "widget_heart_orange",
        "💛": "widget_heart_gold",
        "💚": "widget_heart_green",
        "💙": "widget_heart_blue",
        "💜": "widget_heart_purple",
        "🖤": "widget_heart_black",
        "🤍": "widget_heart_white",
        "🤎": "widget_heart_brown",
        "♥️": "widget_heart_classic",
        "❣️": "widget_heart_exclamation",
        "💕": "widget_heart_pair",
        "💞": "widget_heart_orbit",
        "💓": "widget_heart_beat",
        "💗": "widget_heart_growing",
        "💖": "widget_heart_sparkle",
        "💘": "widget_heart_arrow",
        "💝": "widget_heart_gift",
        "💟": "widget_heart_badge",
        "❤️‍🔥": "widget_heart_flame",
        "❤️‍🩹": "widget_heart_healing",
        "💌": "widget_heart_letter",
        "💋": "widget_heart_kiss",
        "🫶": "widget_heart_hands",
        "🫀": "widget_heart_anatomical",
        "💫💗": "widget_heart_comet",
        "✧♥︎": "widget_heart_outline",
        "❥∞": "widget_heart_infinity",
        "🩷": "widget_heart_pink",
        "🩶": "widget_heart_gray",
        "🩵": "widget_heart_cyan",
    ]
    static let stickers: Set<String> = ["bears", "bunnies", "cats", "letter", "gift", "moon"]
    static let frames: Set<String> = ["rounded", "heart", "polaroid"]
    static let layouts: Set<String> = ["single", "duo", "grid"]
    static let styles: Set<String> = ["classic", "countdown", "soulevent"]
    static let palettes: [String: [String]] = [
        "pink": ["FFF3E5", "FFDDE7", "DAD8FF"],
        "dark": ["202338", "35324F", "2B4754"],
        "white": ["FFFFFF", "F4F0FF", "E2F0F6"],
        "blue": ["F5FBFF", "D8EAFF", "DDDFFA"],
        "orange": ["FFF7DE", "FFDFBF", "F5D3DC"],
        "purple": ["FFF1FA", "E8D8F7", "D7E8FA"],
        "green": ["FFF9DF", "DDF2DF", "C8E8E2"],
        "red": ["60213D", "973D52", "B9676A"],
        "premium": ["FF5FA2", "FFB86B", "67E8F9", "7C3AED"],
        "cosmic": ["17142F", "322952", "514563"],
    ]
    static func heart(_ key: String) -> String { hearts[key] ?? "widget_heart_red" }
    static func theme(_ key: String) -> String { palettes[key] == nil ? "pink" : key }
    static func sticker(_ key: String) -> String { stickers.contains(key) ? key : "none" }
    static func frame(_ key: String) -> String { frames.contains(key) ? key : "rounded" }
    static func layout(_ key: String) -> String { layouts.contains(key) ? key : "single" }
    static func style(_ key: String) -> String { styles.contains(key) ? key : "classic" }
    // WidgetKit chỉ chuyển khung theo timeline; không dùng timer mỗi vài giây.
    static func alternate(at date: Date, enabled: Bool) -> Bool {
        enabled && Int(date.timeIntervalSince1970 / 1800).isMultiple(of: 2)
    }
}

func widgetText(_ key: String) -> String {
    NSLocalizedString(key, tableName: "WidgetStrings", bundle: .main, comment: "")
}

struct WidgetArtwork: View {
    let name: String
    var body: some View {
        Image(name).resizable().renderingMode(.original).scaledToFit()
            .accessibilityHidden(true)
    }
}

struct WidgetThemeBackdrop: View {
    let key: String
    let alternate: Bool
    var body: some View {
        let normalized = WidgetAppearanceDesign.theme(key)
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: (WidgetAppearanceDesign.palettes[normalized] ?? []).map { Color(hex: $0) },
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Image("widget_theme_" + normalized + (alternate ? "_twinkle" : ""))
                    .resizable().renderingMode(.original)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
    }
}

struct WidgetHomeBackground: ViewModifier {
    let key: String
    let alternate: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                WidgetThemeBackdrop(key: key, alternate: alternate)
            }
        } else {
            content.background(WidgetThemeBackdrop(key: key, alternate: alternate))
        }
    }
}

/// Giống mặt nạ khung tim của Flutter và Android, không cắt theo hình chữ nhật.
struct WidgetPhotoFrameShape: Shape {
    let key: String
    func path(in rect: CGRect) -> Path {
        if key == "heart" {
            let w = rect.width, h = rect.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.23))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.97),
                control1: CGPoint(x: -w * 0.08, y: -h * 0.22),
                control2: CGPoint(x: -w * 0.16, y: h * 0.48))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.23),
                control1: CGPoint(x: w * 1.16, y: h * 0.48),
                control2: CGPoint(x: w * 1.08, y: -h * 0.22))
            p.closeSubpath()
            return p.offsetBy(dx: rect.minX, dy: rect.minY)
        }
        return Path(roundedRect: rect, cornerRadius: rect.width * (key == "polaroid" ? 6.0/168 : 24.0/168))
    }
}
