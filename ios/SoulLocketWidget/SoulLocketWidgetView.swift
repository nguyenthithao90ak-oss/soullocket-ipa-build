import WidgetKit
import SwiftUI
import UIKit
import ImageIO

func downsampleImage(at path: String, to size: CGSize) -> UIImage? {
    let url = URL(fileURLWithPath: path)
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
        return nil
    }
    
    let maxDimension = max(size.width, size.height) * 2.0 // scale = 2.0 (Retina quality)
    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension
    ] as CFDictionary
    
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
        return nil
    }
    return UIImage(cgImage: downsampledImage)
}


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
                gradient: [Color(hex: "202338"),Color(hex: "35324F"),Color(hex: "2B4754")],
                textColor: .white,
                secondaryTextColor: Color.white.opacity(0.78),
                accentColor: Color(hex: "FF8FB1"),
                chipBackground: Color.white.opacity(0.10),
                chipBorder: Color.white.opacity(0.14)
            )
        case "white":
            return WidgetTheme(
                gradient: [Color(hex: "FFFFFF"),Color(hex: "F4F0FF"),Color(hex: "E2F0F6")],
                textColor: Color(hex: "1F2937"),
                secondaryTextColor: Color(hex: "4B5563"),
                accentColor: Color(hex: "D6336C"),
                chipBackground: Color.white.opacity(0.88),
                chipBorder: Color(hex: "E2E8F0")
            )
        case "blue":
            return WidgetTheme(
                gradient: [Color(hex: "F5FBFF"),Color(hex: "D8EAFF"),Color(hex: "DDDFFA")],
                textColor: Color(hex: "0F3D7A"),
                secondaryTextColor: Color(hex: "215B9C"),
                accentColor: Color(hex: "1565C0"),
                chipBackground: Color.white.opacity(0.80),
                chipBorder: Color(hex: "93C5FD")
            )
        case "orange":
            return WidgetTheme(
                gradient: [Color(hex: "FFF7DE"),Color(hex: "FFDFBF"),Color(hex: "F5D3DC")],
                textColor: Color(hex: "7C2D12"),
                secondaryTextColor: Color(hex: "B45309"),
                accentColor: Color(hex: "EA580C"),
                chipBackground: Color.white.opacity(0.74),
                chipBorder: Color(hex: "FDBA74")
            )
        case "purple":
            return WidgetTheme(
                gradient: [Color(hex: "FFF1FA"),Color(hex: "E8D8F7"),Color(hex: "D7E8FA")],
                textColor: Color(hex: "5B217A"),
                secondaryTextColor: Color(hex: "7C3AED"),
                accentColor: Color(hex: "8B5CF6"),
                chipBackground: Color.white.opacity(0.76),
                chipBorder: Color(hex: "C084FC")
            )
        case "green":
            return WidgetTheme(
                gradient: [Color(hex: "FFF9DF"),Color(hex: "DDF2DF"),Color(hex: "C8E8E2")],
                textColor: Color(hex: "065F46"),
                secondaryTextColor: Color(hex: "0F766E"),
                accentColor: Color(hex: "10B981"),
                chipBackground: Color.white.opacity(0.74),
                chipBorder: Color(hex: "86EFAC")
            )
        case "red":
            return WidgetTheme(
                gradient: [Color(hex: "60213D"),Color(hex: "973D52"),Color(hex: "B9676A")],
                textColor: Color(hex: "FFF0DC"),
                secondaryTextColor: Color.white.opacity(0.80),
                accentColor: Color(hex: "FFF0DC"),
                chipBackground: Color.black.opacity(0.20),
                chipBorder: Color.white.opacity(0.35)
            )
        case "premium":
            return WidgetTheme(
                gradient: [Color(hex: "FF5FA2"),Color(hex: "FFB86B"),Color(hex: "67E8F9"),Color(hex: "7C3AED")],
                textColor: .white,
                secondaryTextColor: Color.white.opacity(0.84),
                accentColor: Color(hex: "FFF1B5"),
                chipBackground: Color.white.opacity(0.16),
                chipBorder: Color.white.opacity(0.24)
            )
        case "cosmic":
            return WidgetTheme(
                gradient: [Color(hex: "17142F"),Color(hex: "322952"),Color(hex: "514563")],
                textColor: Color(hex: "FFF0BD"),
                secondaryTextColor: Color(hex: "FFD700"),
                accentColor: Color(hex: "FFF0BD"),
                chipBackground: Color.black.opacity(0.4),
                chipBorder: Color(hex: "FFF0BD").opacity(0.35)
            )
        case "pink":
            fallthrough
        default:
            return WidgetTheme(
                gradient: [Color(hex: "FFF3E5"),Color(hex: "FFDDE7"),Color(hex: "DAD8FF")],
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
    var warm: Bool = true
    var body: some View {
        Group {
            if let path, let image = downsampleImage(at: path, to: CGSize(width: size, height: size)) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                WidgetArtwork(name: warm ? "widget_avatar_warm" : "widget_avatar_cream")
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2))
        .accessibilityLabel(name)
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

@available(iOS 16.0, *)
struct SoulLocketWidgetView16: View {
    let entry: CoupleEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        let theme = WidgetTheme.from(entry.data.bgTheme)
        if family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline {
            LockScreenWidgetView(data: entry.data, family: family, theme: theme, date: entry.date)
        } else if entry.data.widgetStyleKey == "soulevent" {
            WidgetUtilityView(kind: .event, data: UtilityWidgetData.load(), date: entry.date)
        } else {
            WidgetCoupleHomeView(data: entry.data, theme: theme, date: entry.date, family: family)
        }
    }
}

struct SoulLocketWidgetView15: View {
    let entry: CoupleEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        if entry.data.widgetStyleKey == "soulevent" {
            WidgetUtilityView(kind: .event, data: UtilityWidgetData.load(), date: entry.date)
        } else {
            WidgetCoupleHomeView(data: entry.data, theme: WidgetTheme.from(entry.data.bgTheme),
                date: entry.date, family: family)
        }
    }
}

@available(iOS 16.0, *)
struct LockScreenWidgetView: View {
    let data: CoupleWidgetData
    let family: WidgetFamily
    let theme: WidgetTheme
    let date: Date

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(spacing: 2) {
                // Top: Soul Merge branding
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Soul Merge")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(0.7)
                
                // Middle: Avatar + Name ❤️ Avatar + Name
                HStack(spacing: 4) {
                    // Person 1: avatar + name
                    HStack(spacing: 3) {
                        if let path = data.avatar1Path, let img = downsampleImage(at: path, to: CGSize(width: 36, height: 36)) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16))
                        }
                        Text(data.name1)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    
                    // Person 2: avatar + name
                    HStack(spacing: 3) {
                        if let path = data.avatar2Path, let img = downsampleImage(at: path, to: CGSize(width: 36, height: 36)) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16))
                        }
                        Text(data.name2)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Bottom: Days counter
                let numberStr = data.resolvedDaysText(referenceDate: date)
                Text(numberStr)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .modifier(TransparentWidgetBackground())
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                let numberStr = String(data.resolvedDaysText().split(separator: " ").first ?? "0")
                Text(numberStr)
                    .font(.system(size: 16, weight: .bold))
                    .minimumScaleFactor(0.5)
            }
            .modifier(TransparentWidgetBackground())
        case .accessoryInline:
            Text("💕 \(data.resolvedDaysText())")
        default:
            EmptyView()
        }
    }
}

@available(iOS 16.0, *)
struct LockScreenWidgetAvatarView: View {
    let data: CoupleWidgetData
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            // Avatar người 1
            AvatarView(path: data.avatar1Path, name: data.name1, size: 46, accentColor: .pink)
                .frame(width: 46, height: 46)
            
            // Số ngày ở giữa kèm tim
            VStack(spacing: 1) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                let numberStr = String(data.resolvedDaysText(referenceDate: date).split(separator: " ").first ?? "0")
                Text(numberStr)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(minWidth: 36)
            
            // Avatar người 2
            AvatarView(path: data.avatar2Path, name: data.name2, size: 46, accentColor: .pink)
                .frame(width: 46, height: 46)
        }
        .modifier(TransparentWidgetBackground())
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

struct DiaryPhotosView: View {
    let paths: [String]
    let theme: WidgetTheme

    private var displayPaths: [String] {
        Array(paths.prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(widgetText("home_knim_4f6aeb"))
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
        return isOnline ? widgetText("core_presence_online") : widgetText("home_angoffline_bbb3d5")
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

@available(iOS 16.0, *)
struct LockScreenSoulMergeWidgetView: View {
    let data: CoupleWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                // Avatar of sender
                if let path = senderAvatarPath, let img = downsampleImage(at: path, to: CGSize(width: 32, height: 32)) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                }
                Text(data.soulMergeSenderName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .opacity(0.6)
            }
            Text(data.soulMergeMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(2)
                .truncationMode(.tail)
                .opacity(0.85)
            Spacer(minLength: 0)
        }
        .padding(4)
    }

    private var senderAvatarPath: String? {
        // If sender name matches name1, use avatar1; otherwise avatar2
        let sender = data.soulMergeSenderName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let n1 = data.name1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if sender == n1 {
            return data.avatar1Path
        }
        return data.avatar2Path
    }
}

