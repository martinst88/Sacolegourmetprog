import SwiftUI

enum AppTheme {
    static let background = Color(hex: "#EEE8E1")
    static let secondaryBackground = Color(hex: "#F7F1EA")
    static let cardBackground = Color(hex: "#FFFCF8").opacity(0.96)
    static let accent = Color(hex: "#1E5D58")
    static let brandBrown = Color(hex: "#6B432D")
    static let accentSoft = Color(hex: "#D9C4B0")
    static let highlight = Color(hex: "#B48A61")
    static let success = Color(hex: "#2F7669")
    static let warning = Color(hex: "#B78D57")
    static let danger = Color(hex: "#A95A49")
    static let textPrimary = Color(hex: "#2E241E")
    static let textSecondary = Color(hex: "#6A6159")
    static let border = Color(hex: "#D2BEAA")
    static let logoGlow = Color(hex: "#E3D5C7")

    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#7D7872"), Color(hex: "#D9C8B7"), Color(hex: "#F9F5F0")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let screenGradient = LinearGradient(
        colors: [Color(hex: "#E2D7CC"), Color(hex: "#F7F1EA"), Color(hex: "#D5CCC2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.98), Color(hex: "#F4EEE7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let red, green, blue: UInt64
        switch hex.count {
        case 6:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

struct PremiumCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: AppTheme.brandBrown.opacity(0.08), radius: 16, x: 0, y: 10)
        )
    }
}

struct ModuleTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.18), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.brandBrown.opacity(0.8))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

extension View {
    func brandScrollBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func brandPlainBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let systemImage: String

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: systemImage)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(color)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                        )
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
