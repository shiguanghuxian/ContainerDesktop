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
    static let surface = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let graphite = Color(red: 0.16, green: 0.18, blue: 0.21)
    static let ember = Color(red: 0.92, green: 0.39, blue: 0.17)
    static let lime = Color(red: 0.22, green: 0.68, blue: 0.33)
    static let violet = Color(red: 0.44, green: 0.34, blue: 0.86)

    static var hairline: Color {
        Color.primary.opacity(0.08)
    }

    static var separator: Color {
        Color.primary.opacity(0.12)
    }
}

struct TechBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor

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

                context.stroke(path, with: .color(Color.primary.opacity(0.025)), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
        }
    }

    private var baseColor: Color {
        colorScheme == .dark ? Color(red: 0.035, green: 0.045, blue: 0.065) : CDTheme.surface
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
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
                    RoundedRectangle(cornerRadius: CDTheme.panelRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.primary.opacity(0.018),
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
            .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
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
