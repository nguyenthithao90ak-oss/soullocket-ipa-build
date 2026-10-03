import SwiftUI
import WidgetKit
import UIKit

struct WidgetDiaryCollage: View {
    let images: [UIImage]
    let layoutKey: String
    let frameKey: String
    let theme: WidgetTheme
    let themeKey: String

    private func tile(_ index: Int, radius: CGFloat) -> some View {
        GeometryReader { proxy in
            Image(uiImage: images[index % images.count])
                .resizable().scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    var body: some View {
        GeometryReader { proxy in
            let gap = proxy.size.width * 6.0 / 168
            let inset = proxy.size.width * 4.0 / 168
            let radius = proxy.size.width * (layoutKey == "grid" ? 14 : layoutKey == "duo" ? 16 : 18) / 168
            let edge = proxy.size.width * 0.033
            ZStack {
                LinearGradient(colors: [HeartPalette.from(themeKey).secondary, Color.white.opacity(0.8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Group {
                    if layoutKey == "grid" {
                        VStack(spacing: gap) {
                            HStack(spacing: gap) { tile(0, radius: radius); tile(1, radius: radius) }
                            HStack(spacing: gap) { tile(2, radius: radius); tile(3, radius: radius) }
                        }
                    } else if layoutKey == "duo" {
                        HStack(spacing: gap) { tile(0, radius: radius); tile(1, radius: radius) }
                    } else {
                        tile(0, radius: radius)
                    }
                }
                .padding(.leading, inset)
                .padding(.trailing, edge)
                .padding(.top, edge)
                .padding(.bottom, frameKey == "polaroid" ? proxy.size.height * 0.22 : edge)
            }
            .clipShape(WidgetPhotoFrameShape(key: frameKey))
        }
    }
}

/// Tim/sticker/ảnh không tự thay kiểu; ảnh lỗi trở lại đúng mẫu đã chọn.
struct WidgetCenterArtwork: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme
    let date: Date
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var images: [UIImage] {
        guard data.showDiaryOnWidget && data.widgetStyleKey != "countdown" else { return [] }
        let count = data.diaryLayoutKey == "grid" ? 4 : data.diaryLayoutKey == "duo" ? 2 : 1
        // Giới hạn giải mã, không tải ảnh gốc 12 tấm trong extension.
        return data.diaryImagePaths.prefix(count).compactMap {
            downsampleImage(at: $0, to: CGSize(width: size, height: size * 1.45))
        }
    }

    var body: some View {
        let photos = images
        let alternate = WidgetAppearanceDesign.alternate(at: date,
            enabled: data.heartAnimated && !reduceMotion)
        Group {
            if !photos.isEmpty {
                ZStack(alignment: .bottomTrailing) {
                    WidgetDiaryCollage(images: photos, layoutKey: data.diaryLayoutKey,
                        frameKey: data.photoFrameKey, theme: theme, themeKey: data.heartColorKey)
                        .aspectRatio(data.photoFrameKey == "heart" ? 1 : 168.0 / 244, contentMode: .fit)
                        .frame(width: size, height: size)
                    if data.widgetStickerKey != "none" {
                        WidgetArtwork(name: "widget_" + data.widgetStickerKey + (alternate ? "_twinkle" : ""))
                            .frame(width: size * 0.37, height: size * 0.37)
                    }
                }
            } else if data.widgetStickerKey != "none" {
                WidgetArtwork(name: "widget_" + data.widgetStickerKey + (alternate ? "_twinkle" : ""))
                    .id(data.widgetStickerKey + (alternate ? "_twinkle" : ""))
            } else {
                WidgetArtwork(name: WidgetAppearanceDesign.heart(data.heartStyleKey))
                    .padding(size * 0.09)
                    .scaleEffect(alternate ? 1.035 : 1)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion || !data.heartAnimated ? nil : .easeInOut(duration: 0.4), value: alternate)
    }
}

struct WidgetCoupleHomeView: View {
    let data: CoupleWidgetData
    let theme: WidgetTheme
    let date: Date
    let family: WidgetFamily
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func person(path: String?, name: String, size: CGFloat, warm: Bool, small: Bool, showName: Bool) -> some View {
        VStack(spacing: showName ? 3 : 0) {
            AvatarView(path: path, name: name, size: size,
                accentColor: theme.accentColor, warm: warm)
            if showName {
            Text(name).font(.system(size: small ? 10 : 12, weight: .bold, design: .rounded))
                .foregroundColor(theme.textColor).lineLimit(1).minimumScaleFactor(0.6)
                .frame(height: small ? 14 : family == .systemLarge ? 18 : 14)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func center(size: CGFloat, small: Bool) -> some View {
        if data.showDiaryOnWidget && data.widgetStyleKey != "countdown" {
            Link(destination: URL(string: "soullocket://widget?action=diary")!) {
                WidgetCenterArtwork(data: data, theme: theme, date: date, size: size)
            }
        } else if #available(iOSApplicationExtension 17.0, *), !small {
            Button(intent: SendQuickActionIntent(actionType: "heart")) {
                WidgetCenterArtwork(data: data, theme: theme, date: date, size: size)
            }.buttonStyle(.plain)
        } else {
            WidgetCenterArtwork(data: data, theme: theme, date: date, size: size)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let small = family == .systemSmall
            let large = family == .systemLarge
            let countdown = data.widgetStyleKey == "countdown"
            let padding: CGFloat = large ? 12 : 8
            let centerSize: CGFloat = small ? 28 : large ? 72 : 44
            let counterHeight: CGFloat = small ? 28 : large ? 46 : 28
            let gap: CGFloat = large ? 8 : small ? 6 : 4
            let names: CGFloat = countdown ? 0 : large ? 18 : 14
            let avatarGap: CGFloat = countdown ? 0 : 3
            let footer: CGFloat = large ? 92 : 0
            let dateHeight: CGFloat = countdown && !data.loveDateText.isEmpty ? (large ? 16 : 12) : 0
            let avatarSize = max(20, min(small ? 64 : large ? 132 : 96,
                min((proxy.size.width - padding * 2 - centerSize - gap * 2) / 2,
                    proxy.size.height - padding * 2 - counterHeight - names - avatarGap
                        - gap * (large ? 4 : 2) - (dateHeight > 0 ? gap : 0) - dateHeight - footer)))

            VStack(spacing: gap) {
                Text(data.resolvedDaysText(referenceDate: date))
                    .font(.system(size: large ? 34 : small ? 19 : 27,
                        weight: .heavy, design: .rounded))
                    .foregroundColor(theme.accentColor).lineLimit(1).minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity).frame(height: counterHeight)
                    .background(theme.chipBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(theme.chipBorder, lineWidth: 1))
                HStack(spacing: gap) {
                    person(path: data.avatar1Path, name: data.name1,
                        size: avatarSize, warm: true, small: small, showName: !countdown)
                    center(size: centerSize, small: small)
                    person(path: data.avatar2Path, name: data.name2,
                        size: avatarSize, warm: false, small: small, showName: !countdown)
                }
                if dateHeight > 0 {
                    Text(data.loveDateText).font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(height: dateHeight)
                }
                if large {
                    Spacer(minLength: 0)
                    StatusSection(data: data, theme: theme)
                        .frame(maxHeight: footer)
                }
                Spacer(minLength: 0)
            }
            .padding(padding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .modifier(WidgetHomeBackground(key: data.bgTheme,
            alternate: WidgetAppearanceDesign.alternate(at: date,
                enabled: data.heartAnimated && !reduceMotion)))
        .widgetURL(URL(string: "soullocket://widget?action=love"))
        .privacySensitive()
    }
}
