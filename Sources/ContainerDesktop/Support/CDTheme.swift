import AppKit
import SwiftUI

enum CDTheme {
    static let cornerRadius: CGFloat = 8
    static let panelRadius: CGFloat = 8
    static let dockerBlue = Color(red: 0.11, green: 0.39, blue: 0.93)
    static let dockerBlueLight = Color(red: 0.23, green: 0.58, blue: 1.00)
    static let cyan = Color(red: 0.06, green: 0.66, blue: 0.88)
    static let ink = Color(red: 0.04, green: 0.06, blue: 0.10)
    static let sidebar = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let sidebarElevated = Color(red: 0.08, green: 0.11, blue: 0.18)
    static let surface = appBackground
    static let graphite = Color(red: 0.16, green: 0.18, blue: 0.21)
    static let ember = Color(red: 0.92, green: 0.39, blue: 0.17)
    static let lime = Color(red: 0.22, green: 0.68, blue: 0.33)
    static let violet = Color(red: 0.44, green: 0.34, blue: 0.86)

    static let appBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.975, green: 0.988, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.085, alpha: 1)
    )
    static let panelSurface = adaptiveColor(
        light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.96),
        dark: NSColor(calibratedRed: 0.055, green: 0.085, blue: 0.130, alpha: 0.96)
    )
    static let elevatedSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.990, green: 0.996, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.070, green: 0.105, blue: 0.160, alpha: 1)
    )
    static let inputSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.980, green: 0.992, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.060, green: 0.095, blue: 0.145, alpha: 1)
    )
    static let tableHeaderSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.955, green: 0.978, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.065, green: 0.105, blue: 0.170, alpha: 1)
    )
    static let hoverSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.925, green: 0.968, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.085, green: 0.135, blue: 0.205, alpha: 1)
    )
    static let rowStripeSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.970, green: 0.988, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.050, green: 0.080, blue: 0.125, alpha: 1)
    )
    static let statusBarSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.990, green: 0.997, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.040, green: 0.065, blue: 0.100, alpha: 1)
    )
    static let codeSurface = adaptiveColor(
        light: NSColor(calibratedRed: 0.985, green: 0.994, blue: 1.000, alpha: 1),
        dark: NSColor(calibratedRed: 0.045, green: 0.070, blue: 0.105, alpha: 1)
    )

    static var hairline: Color {
        adaptiveColor(
            light: NSColor(calibratedRed: 0.760, green: 0.840, blue: 0.955, alpha: 0.70),
            dark: NSColor(calibratedRed: 0.210, green: 0.360, blue: 0.560, alpha: 0.74)
        )
    }

    static var separator: Color {
        adaptiveColor(
            light: NSColor(calibratedRed: 0.700, green: 0.800, blue: 0.925, alpha: 0.82),
            dark: NSColor(calibratedRed: 0.240, green: 0.390, blue: 0.600, alpha: 0.82)
        )
    }

    static var panelShadow: Color {
        adaptiveColor(
            light: NSColor(calibratedRed: 0.120, green: 0.260, blue: 0.480, alpha: 0.10),
            dark: NSColor(calibratedRed: 0.000, green: 0.000, blue: 0.000, alpha: 0.30)
        )
    }

    static var selectionSurface: Color {
        dockerBlue.opacity(0.10)
    }

    static var highlightWash: Color {
        adaptiveColor(
            light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.64),
            dark: NSColor(calibratedRed: 0.120, green: 0.180, blue: 0.260, alpha: 0.42)
        )
    }

    static func nativeCodeBackgroundColor() -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.isDarkMode
                ? NSColor(calibratedRed: 0.045, green: 0.070, blue: 0.105, alpha: 1)
                : NSColor(calibratedRed: 0.985, green: 0.994, blue: 1.000, alpha: 1)
        }
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkMode ? dark : light
        })
    }
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct TechBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CDTheme.appBackground

            LinearGradient(
                colors: [
                    CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.16 : 0.055),
                    Color.clear,
                    CDTheme.cyan.opacity(colorScheme == .dark ? 0.10 : 0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                var path = Path()
                let step: CGFloat = 40

                var x: CGFloat = 0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }

                var y: CGFloat = 0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }

                context.stroke(path, with: .color(CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.050 : 0.028)), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
        }
    }
}

struct GlassPanelModifier: ViewModifier {
    var accent: Color?
    var isSelected = false

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: CDTheme.panelRadius)
                        .fill(CDTheme.panelSurface)
                    RoundedRectangle(cornerRadius: CDTheme.panelRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CDTheme.highlightWash,
                                    CDTheme.dockerBlue.opacity(0.020),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if let accent {
                        Rectangle()
                            .fill(accent)
                            .frame(width: isSelected ? 4 : 2)
                            .padding(.vertical, 10)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CDTheme.panelRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CDTheme.panelRadius)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle((accent ?? CDTheme.dockerBlue).opacity(0.58))
                            : AnyShapeStyle(CDTheme.hairline)
                    )
            }
            .shadow(color: CDTheme.panelShadow, radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glassPanel(accent: Color? = nil, isSelected: Bool = false) -> some View {
        modifier(GlassPanelModifier(accent: accent, isSelected: isSelected))
    }
}

struct IconTile: View {
    var systemImage: String
    var tint: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(tint.opacity(0.20))
                    }
            }
    }
}

struct CDSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? CDTheme.dockerBlue : .secondary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(configuration.isPressed ? CDTheme.hoverSurface : CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isEnabled ? CDTheme.separator : CDTheme.hairline)
            }
            .opacity(isEnabled ? 1 : 0.58)
    }
}

struct ThemedSegmentedPicker<Option: Hashable>: View {
    var options: [Option]
    @Binding var selection: Option
    var title: (Option) -> String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.callout.weight(isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 28)
                        .background(isSelected ? CDTheme.dockerBlue : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.hairline)
        }
    }
}
