import SwiftUI

enum DetailDrawerMode: String, CaseIterable, Identifiable {
    case overview
    case raw

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            language.resolved == .zhHans ? "概览" : "Overview"
        case .raw:
            language.resolved == .zhHans ? "原始数据" : "Raw"
        }
    }
}

struct DetailDrawer<Overview: View>: View {
    @Environment(\.appLanguage) private var language
    @Binding var mode: DetailDrawerMode
    var title: String
    var subtitle: String
    var systemImage: String
    var rawText: String
    var rawLabel: String = "JSON"
    var onClose: () -> Void
    @ViewBuilder var overview: Overview

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                onClose: onClose
            )

            ThemedSegmentedPicker(
                options: DetailDrawerMode.allCases,
                selection: $mode,
                title: { $0 == .raw ? rawLabel : $0.title(language: language) }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                Group {
                    switch mode {
                    case .overview:
                        overview
                    case .raw:
                        TerminalBlock(text: rawText, minHeight: 420)
                    }
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .drawerSurface(width: 430)
    }
}

struct DrawerHeader: View {
    @Environment(\.appLanguage) private var language
    var title: String
    var subtitle: String
    var systemImage: String
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: systemImage, tint: CDTheme.dockerBlue, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            DrawerCloseButton(action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CDTheme.panelSurface)
    }
}

private struct DrawerCloseButton: View {
    @Environment(\.appLanguage) private var language
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(language.resolved == .zhHans ? "关闭" : "Close", systemImage: "xmark")
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "关闭详情（Esc）" : "Close details (Esc)")
        .keyboardShortcut(.escape, modifiers: [])
    }
}

private struct DrawerSurfaceModifier: ViewModifier {
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width)
            .frame(maxHeight: .infinity, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(CDTheme.panelSurface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(CDTheme.hairline)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(CDTheme.dockerBlue.opacity(0.45))
                    .frame(width: 2)
            }
            .shadow(color: CDTheme.panelShadow, radius: 24, x: -8, y: 0)
    }
}

extension View {
    func drawerSurface(width: CGFloat) -> some View {
        modifier(DrawerSurfaceModifier(width: width))
    }
}

struct DrawerPageLayout<Content: View, Drawer: View>: View {
    var isDrawerPresented: Bool
    var onDismiss: (() -> Void)? = nil
    var drawerWidth: CGFloat = 430
    @ViewBuilder var content: Content
    @ViewBuilder var drawer: Drawer

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    content
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .thinScrollBars()
                .frame(width: proxy.size.width, height: proxy.size.height)

                if isDrawerPresented {
                    HStack(spacing: 0) {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onDismiss?()
                            }
                        Spacer()
                            .frame(width: drawerWidth + 32)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transition(.opacity)
                    .zIndex(1)

                    drawer
                        .frame(width: drawerWidth, height: max(proxy.size.height - 32, 0), alignment: .top)
                        .padding(.trailing, 16)
                        .padding(.vertical, 16)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .animation(.snappy(duration: 0.22), value: isDrawerPresented)
    }
}

struct DetailSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
    }
}

struct DetailInfoRow: View {
    var title: String
    var value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(monospaced ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

struct CopyableIPAddressInfoRow: View {
    var title: String
    var value: String
    var monospaced = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            CopyableIPAddressText(
                value: value,
                font: monospaced ? .callout.monospaced() : .callout,
                foregroundStyle: AnyShapeStyle(.primary),
                textSelectionEnabled: true,
                lineLimit: 2,
                minimumScaleFactor: 0.75
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

struct DetailInfoCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

struct PageScrollContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .thinScrollBars()
    }
}
