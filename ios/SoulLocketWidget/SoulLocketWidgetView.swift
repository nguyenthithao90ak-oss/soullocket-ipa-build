import WidgetKit
import SwiftUI
import UIKit

struct WidgetTheme {
    let gradient: [Color]
    let textColor: Color
    let secondaryTextColor: Color
    let accentColor: Color
    let chipBackground: Color
    let chipBorder: Color

    static func from(_ bgTheme: String) -> WidgetTheme {
        switch bgTheme {
        case "dark":
            return WidgetTheme(
                gradient: [Color(hex: "0F172A"), Color(hex: "1E1E38"), Color(hex: "0F172A")],
                textColor: .white,
                secondaryTextColor: Color.white.opacity(0.78),
                accentColor: Color(hex: "FF8FB1"),
                chipBackground: Color.white.opacity(0.10),
                chipBorder: Color.white.opacity(0.14)
            )
        case "white":
            return WidgetTheme(
                gradient: [Color(hex: "FFFFFF"), Color(hex: "F8FAFC"), Color(hex: "F1F5F9")],
                textColor: Color(hex: "1F2937"),
                secondaryTextColor: Color(hex: "4B5563"),
                accentColor: Color(hex: "D6336C"),
                chipBackground: Color.white.opacity(0.88),
                chipBorder: Color(hex: "E2E8F0")
            )
        case "blue":
            return WidgetTheme(
                gradient: [Color(hex: "E0F2FE"), Color(hex: "BAE6FD"), Color(hex: "7DD3FC")],
                textColor: Color(hex: "0F3D7A"),
                secondaryTextColor: Color(hex: "215B9C"),
                accentColor: Color(hex: "1565C0"),
                chipBackground: Color.white.opacity(0.80),
                chipBorder: Color(hex: "93C5FD")
            )
        case "orange":
            return WidgetTheme(
                gradient: [Color(hex: "FEF3C7"), Color(hex: "FDBA74"), Color(hex: "F97316")],
                textColor: Color(hex: "7C2D12"),
                secondaryTextColor: Color(hex: "B45309"),
                accentColor: Color(hex: "EA580C"),
                chipBackground: Color.white.opacity(0.74),
                chipBorder: Color(hex: "FDBA74")
            )
        case "purple":
            return WidgetTheme(
                gradient: [Color(hex: "F3E8FF"), Color(hex: "E9D5FF"), Color(hex: "D8B4FE")],
                textColor: Color(hex: "5B217A"),
                secondaryTextColor: Color(hex: "7C3AED"),
                accentColor: Color(hex: "8B5CF6"),
                chipBackground: Color.white.opacity(0.76),
                chipBorder: Color(hex: "C084FC")
            )
        case "green":
            return WidgetTheme(
                gradient: [Color(hex: "ECFDF5"), Color(hex: "A7F3D0"), Color(hex: "6EE7B7")],
                textColor: Color(hex: "065F46"),
                secondaryTextColor: Color(hex: "0F766E"),
                accentColor: Color(hex: "10B981"),
                chipBackground: Color.white.opacity(0.74),
                chipBorder: Color(hex: "86EFAC")
            )
        case "red":
            return WidgetTheme(
                gradient: [Color(hex: "FFF5F5"), Color(hex: "FED7D7"), Color(hex: "FB7185")],
                textColor: Color(hex: "9F1239"),
                secondaryTextColor: Color(hex: "BE123C"),
                accentColor: Color(hex: "E11D48"),
                chipBackground: Color.white.opacity(0.76),
                chipBorder: Color(hex: "FCA5A5")
            )
        case "premium":
            return WidgetTheme(
                gradient: [Color(hex: "FF5FA2"), Color(hex: "FFB86B"), Color(hex: "67E8F9"), Color(hex: "7C3AED")],
                textColor: .white,
                secondaryTextColor: Color.white.opacity(0.84),
                accentColor: Color(hex: "FFF1B5"),
                chipBackground: Color.white.opacity(0.16),
                chipBorder: Color.white.opacity(0.24)
            )
        case "cosmic":
            return WidgetTheme(
                gradient: [Color(hex: "0F0C20"), Color(hex: "15102A"), Color(hex: "1F1A3A")],
                textColor: Color(hex: "FFFFD700"),
                secondaryTextColor: Color(hex: "FFD700"),
                accentColor: Color(hex: "FFFFD700"),
                chipBackground: Color.black.opacity(0.4),
                chipBorder: Color(hex: "FFFFD700").opacity(0.35)
            )
        case "pink":
            fallthrough
        default:
            return WidgetTheme(
                gradient: [Color(hex: "FFF0F5"), Color(hex: "FFD3E0"), Color(hex: "FFB7CE")],
                textColor: Color(hex: "831843"),
                secondaryTextColor: Color(hex: "9D174D"),
                accentColor: Color(hex: "FF4D73"),
                chipBackground: Color.white.opacity(0.82),
                chipBorder: Color(hex: "FBCFE8")
            )
        }
    }
}

struct HeartPalette {
    let primary: Color
    let secondary: Color
    let glow: Color

    static func from(_ colorKey: String) -> HeartPalette {
        switch colorKey {
        case "ruby":
            return HeartPalette(
                primary: Color(hex: "E11D48"),
                secondary: Color(hex: "FB7185"),
                glow: Color(hex: "FFE4E6")
            )
        case "violet":
            return HeartPalette(
                primary: Color(hex: "8B5CF6"),
                secondary: Color(hex: "C084FC"),
                glow: Color(hex: "F3E8FF")
            )
        case "ocean":
            return HeartPalette(
                primary: Color(hex: "0EA5E9"),
                secondary: Color(hex: "67E8F9"),
                glow: Color(hex: "E0F2FE")
            )
        case "sunset":
            return HeartPalette(
                primary: Color(hex: "F97316"),
                secondary: Color(hex: "FBBF24"),
                glow: Color(hex: "FFF7C2")
            )
        case "gold":
            return HeartPalette(
                primary: Color(hex: "EAB308"),
                secondary: Color(hex: "FDE68A"),
                glow: Color(hex: "FFFBEA")
            )
        case "rose":
            fallthrough
        default:
            return HeartPalette(
                primary: Color(hex: "FF4D73"),
                secondary: Color(hex: "FF8FB1"),
                glow: Color(hex: "FFE4EC")
            )
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

struct AvatarView: View {
    let path: String?
    let name: String
    let size: CGFloat
    let accentColor: Color

    var body: some View {
        Group {
            if let path, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.22))
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle().stroke(Color.white.opacity(0.88), lineWidth: max(1.2, size * 0.04))
        )
        .shadow(color: Color.black.opacity(0.12), radius: size * 0.10, y: size * 0.08)
    }
}

struct OnlineDot: View {
    let isOnline: Bool

    var body: some View {
        Circle()
            .fill(isOnline ? Color(hex: "22C55E") : Color.gray.opacity(0.7))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
    }
}

struct InfoChip: View {
    let label: String
    let theme: WidgetTheme

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundColor(theme.secondaryTextColor)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.chipBackground)
            .overlay(
                Capsule().stroke(theme.chipBorder, lineWidth: 0.8)
            )
            .clipShape(Capsule())
    }
}

private let widgetHeartEmojiPool: [String] = [
    "\u{1F90D}", // 🤍
    "\u{1F90E}", // 🤎
    "\u{2665}\u{FE0F}", // ♥️
    "\u{2763}\u{FE0F}", // ❣️
    "\u{2764}\u{FE0F}", // ❤️
    "\u{1F49E}", // 💞
    "\u{1F5A4}", // 🖤
    "\u{1F49F}", // 💟
    "\u{2764}\u{FE0F}\u{200D}\u{1F525}", // ❤️‍🔥
    "\u{1FA77}", // 🩷
    "\u{1FA76}", // 🩶
    "\u{1FA75}", // 🩵
    "\u{1F498}", // 💘
    "\u{2764}\u{FE0F}\u{200D}\u{1FA79}", // ❤️‍🩹
    "\u{1F493}", // 💓
    "\u{1F497}", // 💗
    "\u{1F496}", // 💖
    "\u{1F49D}", // 💝
    "\u{1F48C}", // 💌
    "\u{1F48B}", // 💋
    "\u{1FAF6}", // 🫶
    "\u{1FAC0}", // 🫀
    "\u{1F4AB}\u{1F497}", // 💫💗
    "\u{2661}\u{2726}", // ♡✦
    "\u{2727}\u{2665}\u{FE0E}", // ✧♥︎
    "\u{2765}\u{221E}", // ❥∞
    "\u{10E6}\u{2661}", // ღ♡
    "\u{263E}\u{2661}", // ☾♡
    "\u{2661}\u{1FABD}", // ♡🪽
    "\u{2726}\u{1F498}" // ✦💘
]

private func resolveHeartEmoji(_ styleKey: String) -> String {
    let normalized = styleKey.trimmingCharacters(in: .whitespacesAndNewlines)
    return widgetHeartEmojiPool.contains(normalized) ? normalized : "\u{2764}\u{FE0F}"
}

struct HeartClusterView: View {
    let styleKey: String
    let animated: Bool
    let palette: HeartPalette
    let size: CGFloat
    let referenceDate: Date

    private var styleSeed: Int {
        styleKey.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
    }

    private var tick: Int {
        Int(referenceDate.timeIntervalSince1970 / 6.0)
    }

    private var motion: Double {
        Double(tick) + (Double(styleSeed % 37) * 0.22)
    }

    private var pulse: CGFloat {
        guard animated else { return 1.0 }
        let value = 1.0 + (sin(motion * 0.95) * 0.08) + (cos(motion * 0.50) * 0.03)
        return CGFloat(min(1.12, max(0.88, value)))
    }

    private var drift: CGFloat {
        guard animated else { return 0.0 }
        return CGFloat((sin(motion * 0.88) * -2.9) + (cos(motion * 0.34) * 0.8))
    }

    private var sway: CGFloat {
        guard animated else { return 0.0 }
        return CGFloat((cos(motion * 0.73) * 4.2) + (sin(motion * 0.29) * 1.0))
    }

    private var activeEmoji: String {
        let base = resolveHeartEmoji(styleKey)
        guard animated else { return base }
        var pool = widgetHeartEmojiPool
        if !pool.contains(base) {
            pool.insert(base, at: 0)
        }
        let index = abs((tick * 17) + styleSeed + Int(size.rounded())) % max(1, pool.count)
        return pool[index]
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        (value / 72.0) * size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(
                            colors: [
                                palette.glow.opacity(animated ? 0.92 : 0.82),
                                palette.primary.opacity(animated ? 0.20 : 0.12),
                                Color.clear
                            ]
                        ),
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.60
                    )
                )
            if animated {
                Circle()
                    .fill(palette.secondary.opacity(0.28))
                    .frame(width: scaled(10), height: scaled(10))
                    .offset(x: scaled(20 - (sway * 0.35)), y: scaled(-17 + (drift * 0.35)))
                Circle()
                    .fill(palette.glow.opacity(0.92))
                    .frame(width: scaled(7), height: scaled(7))
                    .offset(x: scaled(-18 + (sway * 0.25)), y: scaled(18))
            }

            Text(activeEmoji)
                .font(.system(size: scaled(42)))
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.primary, palette.secondary, palette.glow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulse)
                .offset(x: scaled(sway * 0.35), y: scaled(drift))
                .shadow(
                    color: palette.primary.opacity(animated ? 0.28 : 0.16),
                    radius: size * 0.18,
                    y: 3
                )
        }
        .frame(width: size, height: size)
        .shadow(color: palette.primary.opacity(animated ? 0.30 : 0.16), radius: size * 0.24, y: 3)
    }
}

struct DiaryCenterPreview: View {
    let paths: [String]
    let theme: WidgetTheme
    let width: CGFloat
    let height: CGFloat

    private var cornerRadius: CGFloat {
        min(width, height) * 0.20
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.chipBackground)

            if let firstPath = paths.first, let image = UIImage(contentsOfFile: firstPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: min(width, height) * 0.34, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(theme.chipBorder, lineWidth: 0.9)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
}

struct WidgetCenterVisualView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme
    let palette: HeartPalette
    let heartSize: CGFloat
    let diaryWidth: CGFloat
    let diaryHeight: CGFloat

    var body: some View {
        if data.heartAnimated {
            TimelineView(.periodic(from: .now, by: 6)) { context in
                HeartClusterView(
                    styleKey: data.heartStyleKey,
                    animated: true,
                    palette: palette,
                    size: heartSize,
                    referenceDate: context.date
                )
            }
        } else if data.showDiaryOnWidget {
            DiaryCenterPreview(
                paths: data.diaryImagePaths,
                theme: theme,
                width: diaryWidth,
                height: diaryHeight
            )
        } else {
            HeartClusterView(
                styleKey: data.heartStyleKey,
                animated: false,
                palette: palette,
                size: heartSize,
                referenceDate: Date()
            )
        }
    }
}

struct InteractiveWidgetCenterVisualView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme
    let palette: HeartPalette
    let heartSize: CGFloat
    let diaryWidth: CGFloat
    let diaryHeight: CGFloat

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: SendQuickActionIntent(actionType: "heart")) {
                WidgetCenterVisualView(
                    data: data,
                    theme: theme,
                    palette: palette,
                    heartSize: heartSize,
                    diaryWidth: diaryWidth,
                    diaryHeight: diaryHeight
                )
            }
            .buttonStyle(.plain)
        } else {
            WidgetCenterVisualView(
                data: data,
                theme: theme,
                palette: palette,
                heartSize: heartSize,
                diaryWidth: diaryWidth,
                diaryHeight: diaryHeight
            )
        }
    }
}

struct PremiumAuroraBackdrop: View {
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: "FF92C4").opacity(0.42),
                                    Color(hex: "FFD78B").opacity(0.20),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 6,
                            endRadius: size.width * 0.44
                        )
                    )
                    .frame(width: size.width * 0.82, height: size.width * 0.82)
                    .offset(x: -size.width * 0.26, y: -size.height * 0.28)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: "87EAFF").opacity(0.34),
                                    Color(hex: "7B6DFF").opacity(0.16),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 4,
                            endRadius: size.width * 0.36
                        )
                    )
                    .frame(width: size.width * 0.66, height: size.width * 0.66)
                    .offset(x: size.width * 0.26, y: -size.height * 0.14)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    accentColor.opacity(0.22),
                                    Color.white.opacity(0.06),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 4,
                            endRadius: size.width * 0.30
                        )
                    )
                    .frame(width: size.width * 0.58, height: size.width * 0.58)
                    .offset(x: size.width * 0.06, y: size.height * 0.24)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        .clear,
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

struct PremiumCosmicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Blob 1 (Gold/Amber)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.28),
                                    Color(hex: "B59410").opacity(0.12),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 6,
                            endRadius: size.width * 0.44
                        )
                    )
                    .frame(width: size.width * 0.82, height: size.width * 0.82)
                    .offset(x: -size.width * 0.26, y: -size.height * 0.28)

                // Blob 2 (Soft Gold)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: "FDE68A").opacity(0.24),
                                    Color(hex: "FFB86B").opacity(0.10),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 4,
                            endRadius: size.width * 0.36
                        )
                    )
                    .frame(width: size.width * 0.66, height: size.width * 0.66)
                    .offset(x: size.width * 0.26, y: -size.height * 0.14)

                // Blob 3 (Cream Gold)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: "FFFBEB").opacity(0.20),
                                    Color(hex: "EAB308").opacity(0.08),
                                    .clear
                                ]
                            ),
                            center: .center,
                            startRadius: 4,
                            endRadius: size.width * 0.30
                        )
                    )
                    .frame(width: size.width * 0.58, height: size.width * 0.58)
                    .offset(x: size.width * 0.06, y: size.height * 0.24)

                // Stars/Sparkles scattered
                Group {
                    Image(systemName: "star.fill")
                        .font(.system(size: 6))
                        .foregroundColor(Color.white.opacity(0.45))
                        .position(x: size.width * 0.2, y: size.height * 0.25)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.white.opacity(0.35))
                        .position(x: size.width * 0.75, y: size.height * 0.3)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 5))
                        .foregroundColor(Color.white.opacity(0.4))
                        .position(x: size.width * 0.3, y: size.height * 0.7)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.white.opacity(0.35))
                        .position(x: size.width * 0.85, y: size.height * 0.75)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "FFD700").opacity(0.65))
                        .position(x: size.width * 0.65, y: size.height * 0.2)
                }

                // Glowing gold border
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: "FFD700").opacity(0.78), lineWidth: 2.2)
                    .padding(1.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

struct WidgetBackgroundDecorations: View {
    let bgTheme: String
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isDark = bgTheme == "dark"

            ZStack {
                if bgTheme != "premium" {
                    if !isDark && bgTheme != "white" {
                        // Top Right glow circle
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [accentColor.opacity(0.18), accentColor.opacity(0.04), .clear]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: size.width * 0.35
                                )
                            )
                            .frame(width: size.width * 0.7, height: size.width * 0.7)
                            .position(x: size.width * 0.9, y: size.height * 0.1)

                        // Bottom Left glow circle
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.1), .clear]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: size.width * 0.28
                                )
                            )
                            .frame(width: size.width * 0.56, height: size.width * 0.56)
                            .position(x: size.width * 0.1, y: size.height * 0.9)
                    }

                    if isDark {
                        // Dark theme subtle glows & stars
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [accentColor.opacity(0.10), .clear]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: size.width * 0.35
                                )
                            )
                            .frame(width: size.width * 0.7, height: size.width * 0.7)
                            .position(x: size.width * 0.85, y: size.height * 0.2)

                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.2))
                            .position(x: size.width * 0.8, y: size.height * 0.25)

                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color.white.opacity(0.15))
                            .position(x: size.width * 0.15, y: size.height * 0.75)
                    }

                    if bgTheme == "white" {
                        // White theme soft blue blob
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [Color(hex: "E0F2FE").opacity(0.55), .clear]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: size.width * 0.3
                                )
                            )
                            .frame(width: size.width * 0.6, height: size.width * 0.6)
                            .position(x: size.width * 0.85, y: size.height * 0.15)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct PersonCard: View {
    let name: String
    let status: String
    let isOnline: Bool
    let weather: String
    let stars: String
    let avatarPath: String?
    let theme: WidgetTheme
    let avatarSize: CGFloat
    let battery: Int       // -1 = unknown
    let isCharging: Bool

    private var batteryLabel: String? {
        guard battery >= 0 else { return nil }
        let icon = isCharging ? "⚡" : (battery <= 20 ? "🔋" : "🔋")
        return "\(icon) \(battery)%"
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(path: avatarPath, name: name, size: avatarSize, accentColor: theme.accentColor)
                OnlineDot(isOnline: isOnline)
                    .offset(x: 2, y: 2)
            }

            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let label = batteryLabel {
                InfoChip(label: label, theme: theme)
            } else if !weather.isEmpty {
                InfoChip(label: weather, theme: theme)
            }

            if stars != "--" && !stars.isEmpty {
                InfoChip(label: "★ \(stars)", theme: theme)
            } else if !status.isEmpty {
                Text(status)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
            }
        }
    }
}

struct SoulLocketWidgetView: View {
    let entry: CoupleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let theme = WidgetTheme.from(entry.data.bgTheme)

        if #available(iOS 16.0, *), isLockScreen(family: family) {
            LockScreenWidgetView(data: entry.data, family: family)
        } else {
            ZStack {
                if #unavailable(iOSApplicationExtension 17.0) {
                    LinearGradient(
                        colors: theme.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    if entry.data.bgTheme == "premium" {
                        PremiumAuroraBackdrop(accentColor: theme.accentColor)
                    } else if entry.data.bgTheme == "cosmic" {
                        PremiumCosmicBackdrop()
                    } else {
                        WidgetBackgroundDecorations(bgTheme: entry.data.bgTheme, accentColor: theme.accentColor)
                    }
                }

                switch family {
                case .systemSmall:
                    SmallWidgetView(data: entry.data, theme: theme)
                case .systemMedium:
                    MediumWidgetView(data: entry.data, theme: theme)
                case .systemLarge:
                    LargeWidgetView(data: entry.data, theme: theme)
                default:
                    SmallWidgetView(data: entry.data, theme: theme)
                }
            }
            .modifier(WidgetContainerBackground(theme: theme, data: entry.data))
        }
    }

    @available(iOS 16.0, *)
    private func isLockScreen(family: WidgetFamily) -> Bool {
        return family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }
}

@available(iOS 16.0, *)
struct LockScreenWidgetView: View {
    let data: CoupleWidgetData
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Text(data.name1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.6)
                        Text(data.heartStyleKey)
                            .layoutPriority(1)
                        Text(data.name2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.6)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(data.resolvedDaysText())
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
                Spacer()
                if data.battery2 >= 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: data.isCharging2 ? "battery.100.bolt" : "battery.50")
                            .font(.system(size: 14))
                        Text("\(data.battery2)%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .opacity(0.7)
                }
            }
            .modifier(TransparentWidgetBackground())
        case .accessoryCircular:
            let numberStr = String(data.resolvedDaysText().split(separator: " ").first ?? "0")
            let days = Double(numberStr) ?? 0.0
            let nextMilestone = days < 100 ? 100.0 : (days < 365 ? 365.0 : ceil(days / 365.0) * 365.0)
            let progress = days > 0 ? (days / nextMilestone) : 0.0
            
            Gauge(value: progress) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
            } currentValueLabel: {
                Text(numberStr)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
            .modifier(TransparentWidgetBackground())
        case .accessoryInline:
            Text("\(data.name1) \(data.heartStyleKey) \(data.name2) - \(data.resolvedDaysText())")
        default:
            EmptyView()
        }
    }
}

struct TransparentWidgetBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            content
        }
    }
}

struct WidgetContainerBackground: ViewModifier {
    let theme: WidgetTheme
    let data: CoupleWidgetData

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(
                        colors: theme.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    if data.bgTheme == "premium" {
                        PremiumAuroraBackdrop(accentColor: theme.accentColor)
                    } else if data.bgTheme == "cosmic" {
                        PremiumCosmicBackdrop()
                    } else {
                        WidgetBackgroundDecorations(bgTheme: data.bgTheme, accentColor: theme.accentColor)
                    }
                }
            }
        } else {
            content
        }
    }
}

struct SmallWidgetView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme

    private var palette: HeartPalette {
        HeartPalette.from(data.heartColorKey)
    }

    var body: some View {
        VStack(spacing: 7) {
            InteractiveWidgetCenterVisualView(
                data: data,
                theme: theme,
                palette: palette,
                heartSize: 44,
                diaryWidth: 44,
                diaryHeight: 54
            )

            Text(data.resolvedDaysText(referenceDate: Date()))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)

            HStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(path: data.avatar1Path, name: data.name1, size: 42, accentColor: theme.accentColor)
                    OnlineDot(isOnline: data.isOnline1)
                        .offset(x: 2, y: 2)
                }

                ZStack(alignment: .bottomTrailing) {
                    AvatarView(path: data.avatar2Path, name: data.name2, size: 42, accentColor: theme.accentColor)
                    OnlineDot(isOnline: data.isOnline2)
                        .offset(x: 2, y: 2)
                }
            }

            Text("\(data.name1) & \(data.name2)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
    }
}

struct MediumWidgetView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme

    private var palette: HeartPalette {
        HeartPalette.from(data.heartColorKey)
    }

    var body: some View {
        HStack(spacing: 0) {
            PersonCard(
                name: data.name1,
                status: data.status1,
                isOnline: data.isOnline1,
                weather: data.weather1,
                stars: data.stars1,
                avatarPath: data.avatar1Path,
                theme: theme,
                avatarSize: 76,
                battery: data.battery1,
                isCharging: data.isCharging1
            )
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                InteractiveWidgetCenterVisualView(
                    data: data,
                    theme: theme,
                    palette: palette,
                    heartSize: 64,
                    diaryWidth: 64,
                    diaryHeight: 78
                )

                Text(data.resolvedDaysText(referenceDate: Date()))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)

            PersonCard(
                name: data.name2,
                status: data.status2,
                isOnline: data.isOnline2,
                weather: data.weather2,
                stars: data.stars2,
                avatarPath: data.avatar2Path,
                theme: theme,
                avatarSize: 76,
                battery: data.battery2,
                isCharging: data.isCharging2
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct LargeWidgetView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme

    private var palette: HeartPalette {
        HeartPalette.from(data.heartColorKey)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                PersonCard(
                    name: data.name1,
                    status: data.status1,
                    isOnline: data.isOnline1,
                    weather: data.weather1,
                    stars: data.stars1,
                    avatarPath: data.avatar1Path,
                    theme: theme,
                    avatarSize: 76,
                    battery: data.battery1,
                    isCharging: data.isCharging1
                )
                .frame(maxWidth: .infinity)

                VStack(spacing: 5) {
                    InteractiveWidgetCenterVisualView(
                        data: data,
                        theme: theme,
                        palette: palette,
                        heartSize: 68,
                        diaryWidth: 68,
                        diaryHeight: 84
                    )

                    Text(data.resolvedDaysText(referenceDate: Date()))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.74)
                }
                .frame(maxWidth: .infinity)

                PersonCard(
                    name: data.name2,
                    status: data.status2,
                    isOnline: data.isOnline2,
                    weather: data.weather2,
                    stars: data.stars2,
                    avatarPath: data.avatar2Path,
                    theme: theme,
                    avatarSize: 76,
                    battery: data.battery2,
                    isCharging: data.isCharging2
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Rectangle()
                .fill(theme.chipBorder)
                .frame(height: 1)
                .padding(.horizontal, 16)

            if !data.diaryImagePaths.isEmpty {
                DiaryPhotosView(paths: data.diaryImagePaths, theme: theme)
            } else {
                StatusSection(data: data, theme: theme)
            }

            Spacer(minLength: 4)
        }
    }
}

struct DiaryPhotosView: View {
    let paths: [String]
    let theme: WidgetTheme

    private var displayPaths: [String] {
        Array(paths.prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Kỷ niệm gần đây")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(theme.secondaryTextColor)
                .padding(.horizontal, 16)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ],
                spacing: 4
            ) {
                ForEach(displayPaths.indices, id: \.self) { index in
                    DiaryPhotoTile(path: displayPaths[index], theme: theme)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

struct DiaryPhotoTile: View {
    let path: String
    let theme: WidgetTheme

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 55)
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.chipBackground)
                    Image(systemName: "photo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .frame(height: 55)
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.chipBorder, lineWidth: 0.8)
        )
    }
}

struct StatusSection: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme

    private func resolvedStatus(_ status: String, isOnline: Bool) -> String {
        if !status.isEmpty { return status }
        return isOnline ? "Đang online" : "Offline"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        OnlineDot(isOnline: data.isOnline1)
                        Text(data.name1)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(theme.textColor)

                    Text(resolvedStatus(data.status1, isOnline: data.isOnline1))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        OnlineDot(isOnline: data.isOnline2)
                        Text(data.name2)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(theme.textColor)

                    Text(resolvedStatus(data.status2, isOnline: data.isOnline2))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            if !data.weather1.isEmpty || !data.weather2.isEmpty {
                HStack {
                    if !data.weather1.isEmpty {
                        InfoChip(label: data.weather1, theme: theme)
                    }
                    Spacer()
                    if !data.weather2.isEmpty {
                        InfoChip(label: data.weather2, theme: theme)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

