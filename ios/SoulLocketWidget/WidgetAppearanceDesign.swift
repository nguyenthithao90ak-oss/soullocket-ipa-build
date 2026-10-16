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
        "weather_premium": ["DCE7F1", "F7F3FA", "DCEDED"],
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
    var weather = WidgetWeatherSnapshot()
    var referenceDate = Date()
    var body: some View {
        let normalized = weather.allowedTheme(key, at: referenceDate)
        GeometryReader { proxy in
            ZStack {
                if normalized == "weather_premium" {
                    WidgetWeatherBackdrop(weather: weather, alternate: alternate)
                } else {
                LinearGradient(colors: (WidgetAppearanceDesign.palettes[normalized] ?? []).map { Color(hex: $0) },
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Image("widget_theme_" + normalized + (alternate ? "_twinkle" : ""))
                    .resizable().renderingMode(.original)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
    }
}

struct WidgetHomeBackground: ViewModifier {
    let key: String
    let alternate: Bool
    var weather = WidgetWeatherSnapshot()
    var referenceDate = Date()
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                WidgetThemeBackdrop(key: key, alternate: alternate, weather: weather, referenceDate: referenceDate)
            }
        } else {
            content.background(WidgetThemeBackdrop(key: key, alternate: alternate, weather: weather, referenceDate: referenceDate))
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

/// Snapshot local dùng chung giữa widget đôi và các widget tiện ích.
struct WidgetWeatherSnapshot {
    var left = "unknown"
    var right = "unknown"
    var proEnabled = false
    var proExpiresAtMs: Double = 0
    static let palettes: [String: [String]] = [
        "unknown": ["DCE7F1", "F7F3FA", "DCEDED"],
        "sunny": ["FFC96B", "FFF0C9", "F5CBDD"],
        "cloudy": ["B5CBE0", "E8E6F2", "B9D9D7"],
        "rain": ["7FA5CF", "BEC8E4", "9FCACD"],
        "lightning": ["6D639F", "9C8CC0", "F0C47D"],
        "cold": ["A8D8E9", "E0F1FA", "BBC7EC"],
    ]
    static func normalize(_ raw: String?) -> String {
        guard let raw = raw, palettes[raw] != nil else { return "unknown" }
        return raw
    }
    static func load(_ defaults: UserDefaults?) -> WidgetWeatherSnapshot {
        WidgetWeatherSnapshot(left: normalize(defaults?.string(forKey: "weatherState1")),
            right: normalize(defaults?.string(forKey: "weatherState2")),
            proEnabled: defaults?.bool(forKey: "weatherPremiumEnabled") ?? false,
            proExpiresAtMs: defaults?.double(forKey: "weatherPremiumExpiresAtMs") ?? 0)
    }
    func allowedTheme(_ key: String, at date: Date) -> String {
        let theme = WidgetAppearanceDesign.theme(key)
        if theme != "weather_premium" { return theme }
        return proEnabled && (proExpiresAtMs == 0 || proExpiresAtMs > date.timeIntervalSince1970 * 1000)
            ? theme : "pink"
    }
    var colors: [Color] {
        let first = Self.palettes[left] ?? Self.palettes["unknown"]!
        let second = Self.palettes[right] ?? Self.palettes["unknown"]!
        return (0..<3).map { index in
            let a = UInt32(first[index], radix: 16) ?? 0
            let b = UInt32(second[index], radix: 16) ?? 0
            let t = index == 1 ? 0.5 : 0.28
            func channel(_ shift: UInt32) -> Double {
                let x = Double((a >> shift) & 255), y = Double((b >> shift) & 255)
                return (x + (y - x) * t) / 255
            }
            return Color(red: channel(16), green: channel(8), blue: channel(0))
        }
    }
}

struct WidgetWeatherBackdrop: View {
    let weather: WidgetWeatherSnapshot
    let alternate: Bool
    var artworkOpacity: Double = 1
    var body: some View {
        ZStack {
            LinearGradient(colors: weather.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            WidgetWeatherArtwork(weather: weather, alternate: alternate).opacity(artworkOpacity)
        }
    }
}

struct WidgetWeatherArtwork: View {
    let weather: WidgetWeatherSnapshot
    let alternate: Bool
    @Environment(\.layoutDirection) private var direction
    var body: some View {
        Canvas { context, size in
            let half = size.width / 2
            let states = direction == .rightToLeft ? [weather.right, weather.left] : [weather.left, weather.right]
            for index in 0..<2 {
                var part = context
                part.clip(to: Path(CGRect(x: CGFloat(index) * half, y: 0, width: half, height: size.height)))
                part.translateBy(x: CGFloat(index) * half, y: 0)
                drawState(context: &part, size: CGSize(width: half, height: size.height), state: states[index])
            }
        }.accessibilityHidden(true)
    }
    private func drawState(context: inout GraphicsContext, size: CGSize, state: String) {
        let w = size.width, h = size.height
        let u = max(0.5, min(1.5, min(w / 150, h / 180)))
        let palette = WidgetWeatherSnapshot.palettes[state] ?? WidgetWeatherSnapshot.palettes["unknown"]!
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: palette[0]).opacity(0.72), Color(hex: palette[1]).opacity(0.52), Color(hex: palette[2]).opacity(0.68)]),
            startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        let glowPoint = CGPoint(x: state == "lightning" ? w * 0.76 : w * 0.28,
            y: state == "cold" ? h * 0.72 : h * 0.18)
        context.fill(Path(ellipseIn: CGRect(x: glowPoint.x - max(w, h) * 0.64,
            y: glowPoint.y - max(w, h) * 0.64, width: max(w, h) * 1.28, height: max(w, h) * 1.28)),
            with: .radialGradient(Gradient(colors: [weatherAccent(state, bright: true).opacity(0.22), weatherAccent(state, bright: false).opacity(0.04), .clear]),
                center: glowPoint, startRadius: 0, endRadius: max(w, h) * 0.64))
        let cx = w * 0.22, cy = h * 0.16 + (alternate ? 3 * u : 0)
        func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2))
        }
        func cloud(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) -> Path {
            var p = Path()
            p.addPath(circle(x-14*scale, y+4*scale, 12*scale))
            p.addPath(circle(x, y-3*scale, 16*scale))
            p.addPath(circle(x+15*scale, y+5*scale, 11*scale))
            p.addRoundedRect(in: CGRect(x:x-24*scale,y:y,width:48*scale,height:16*scale),
                cornerSize: CGSize(width:8*scale,height:8*scale))
            return p
        }
        let stroke = StrokeStyle(lineWidth: 1.8*u, lineCap: .round, lineJoin: .round)
        switch state {
        case "sunny":
            context.fill(circle(cx, cy, 34*u), with: .radialGradient(Gradient(colors: [Color(hex:"FFFFF0").opacity(0.72), Color(hex:"FFFFCF67").opacity(0.24), .clear]), center: CGPoint(x:cx,y:cy), startRadius:0, endRadius:34*u))
            var rays = Path()
            for index in 0..<12 {
                let angle = Double(index) * Double.pi / 6 + (alternate ? 0.10 : 0)
                let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                rays.move(to:CGPoint(x:cx+dx*22*u,y:cy+dy*22*u)); rays.addLine(to:CGPoint(x:cx+dx*31*u,y:cy+dy*31*u))
            }
            context.stroke(rays,with:.color(Color(hex:"FFC45C").opacity(0.66)),style:StrokeStyle(lineWidth:2.2*u,lineCap:.round))
            context.fill(circle(cx, cy, 16*u), with: .radialGradient(Gradient(colors: [Color(hex:"FFFFF1A8"), Color(hex:"F5B948")]), center: CGPoint(x:cx-4*u,y:cy-5*u), startRadius:0, endRadius:20*u))
            context.fill(circle(cx-4*u, cy-5*u, 4*u), with: .color(.white.opacity(0.28)))
        case "cloudy":
            drawCloud(context: &context, x: cx+8*u, y: cy+u, scale: u, muted: false, storm: false)
            drawCloud(context: &context, x: w*0.82, y: h*0.78, scale: u*0.62, muted: true, storm: false)
            drawMist(context: &context, y: h*0.84, scale: u, color: .white, opacity: 0.16)
        case "rain", "lightning":
            drawCloud(context: &context, x: cx+8*u, y: cy+u, scale: u, muted: false, storm: true)
            if state == "lightning" { drawCloud(context: &context, x: w*0.80, y: h*0.30, scale: u*0.52, muted: true, storm: true) }
            var drops = Path()
            for index in 0..<18 {
                let column = index % 6, row = index / 6
                let x = w*(0.06+CGFloat(column)*0.18)+(row % 2 == 0 ? 3*u : 0)
                let y = h*(0.34+CGFloat(row)*0.22)+(alternate ? 6*u : 0)
                drops.move(to:CGPoint(x:x,y:y)); drops.addLine(to:CGPoint(x:x-4*u,y:y+(row == 0 ? 8 : 12)*u))
            }
            context.stroke(drops,with:.color(Color(hex:"3978B4").opacity(state == "lightning" ? 0.54 : 0.42)),style:StrokeStyle(lineWidth:1.9*u,lineCap:.round))
            drawMist(context: &context, y: state == "lightning" ? h*0.91 : h*0.88, scale: u, color: state == "lightning" ? Color(hex:"F5D89E") : Color(hex:"B9E4E5"), opacity: state == "lightning" ? 0.14 : 0.20)
            if state == "lightning" {
                let x=w*0.82,y=h*0.21
                var bolt=Path(); bolt.move(to:CGPoint(x:x,y:y))
                bolt.addLine(to:CGPoint(x:x-10*u,y:y+20*u)); bolt.addLine(to:CGPoint(x:x+u,y:y+17*u))
                bolt.addLine(to:CGPoint(x:x-7*u,y:y+38*u))
                context.stroke(bolt,with:.color(Color(hex:"FFE29A").opacity(0.34)),style:StrokeStyle(lineWidth:10*u,lineCap:.round,lineJoin:.round))
                context.stroke(bolt,with:.color(Color(hex:"FFF4C5").opacity(alternate ? 0.98 : 0.88)),style:StrokeStyle(lineWidth:3*u,lineCap:.round,lineJoin:.round))
            }
        case "cold":
            var flakes=Path()
            for point in [CGPoint(x:cx,y:cy),CGPoint(x:w*0.82,y:h*0.26),CGPoint(x:w*0.14,y:h*0.74),CGPoint(x:w*0.82,y:h*0.78),CGPoint(x:w*0.42,y:h*0.54)] {
                for index in 0..<3 {
                    let angle=Double(index)*Double.pi/3
                    let radius = (index % 2 == 0 ? 8 : 5.5)*u
                    let dx=CGFloat(cos(angle))*radius,dy=CGFloat(sin(angle))*radius
                    flakes.move(to:CGPoint(x:point.x-dx,y:point.y-dy)); flakes.addLine(to:CGPoint(x:point.x+dx,y:point.y+dy))
                    let bx = dx*0.56, by = dy*0.56
                    flakes.move(to:CGPoint(x:point.x-bx,y:point.y-by)); flakes.addLine(to:CGPoint(x:point.x-bx-dy*0.22,y:point.y-by+dx*0.22))
                    flakes.move(to:CGPoint(x:point.x+bx,y:point.y+by)); flakes.addLine(to:CGPoint(x:point.x+bx+dy*0.22,y:point.y+by-dx*0.22))
                }
            }
            context.stroke(flakes,with:.color(Color(hex:"4F9FC3").opacity(0.48)),style:stroke)
            drawMist(context: &context, y: h*0.82, scale: u, color: Color(hex:"F4FCFF"), opacity: 0.24)
        default: break
        }
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [.white.opacity(0.08), .clear, .black.opacity(0.025)]), startPoint: .zero, endPoint: CGPoint(x:w,y:h)))
    }

    private func weatherAccent(_ state: String, bright: Bool) -> Color {
        switch state {
        case "sunny": return Color(hex: bright ? "FFFFF0" : "FFFFB946")
        case "cloudy": return Color(hex: bright ? "F8FCFF" : "EDF5FF")
        case "rain": return Color(hex: bright ? "D4F3FF" : "6B9FD2")
        case "lightning": return Color(hex: bright ? "FFF7D1" : "FFD36D")
        case "cold": return Color(hex: bright ? "F1FFFF" : "B9F1FF")
        default: return Color(hex: bright ? "FFFFFF" : "EFFFFB")
        }
    }

    private func drawCloud(context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat, muted: Bool, storm: Bool) {
        func c(_ dx: CGFloat, _ dy: CGFloat, _ radius: CGFloat) -> Path { Path(ellipseIn: CGRect(x:x+dx*scale-radius*scale,y:y+dy*scale-radius*scale,width:radius*2*scale,height:radius*2*scale)) }
        let body = storm ? Color(hex:"E7EDF9").opacity(muted ? 0.28 : 0.66) : Color.white.opacity(muted ? 0.34 : 0.72)
        let shadow = (storm ? Color(hex:"465878") : Color(hex:"657B99")).opacity(storm ? 0.30 : 0.15)
        let circles = [(CGFloat(-16),CGFloat(5),CGFloat(13)),(CGFloat(-2),CGFloat(-5),CGFloat(18)),(CGFloat(16),CGFloat(4),CGFloat(12))]
        for (dx,dy,r) in circles { context.fill(c(dx+1,dy+2,r),with:.color(shadow)) }
        var shadowBase = Path()
        shadowBase.addRoundedRect(in: CGRect(x:x-26*scale,y:y+scale,width:52*scale,height:18*scale), cornerSize:CGSize(width:9*scale,height:9*scale))
        context.fill(shadowBase,with:.color(shadow))
        for (dx,dy,r) in circles { context.fill(c(dx,dy,r),with:.color(body)) }
        var bodyBase = Path()
        bodyBase.addRoundedRect(in: CGRect(x:x-26*scale,y:y-2*scale,width:52*scale,height:18*scale), cornerSize:CGSize(width:9*scale,height:9*scale))
        context.fill(bodyBase,with:.color(body))
        context.fill(c(-7,-10,5),with:.color(.white.opacity(muted ? 0.18 : storm ? 0.24 : 0.38)))
    }

    private func drawMist(context: inout GraphicsContext, y: CGFloat, scale: CGFloat, color: Color, opacity: Double) {
        let width = 210*scale, height = 30*scale
        context.fill(Path(ellipseIn:CGRect(x:-width/2,y:y-height/2,width:width,height:height)),with:.radialGradient(Gradient(colors:[color.opacity(opacity),.clear]),center:CGPoint(x:0,y:y),startRadius:0,endRadius:width/2))
    }
}
