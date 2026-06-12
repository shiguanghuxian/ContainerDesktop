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
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "关闭详情" : "Close details")
            }
            .padding(16)

            Picker("", selection: $mode) {
                ForEach(DetailDrawerMode.allCases) { item in
                    Text(item == .raw ? rawLabel : item.title(language: language)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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
        }
        .frame(width: 430)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(CDTheme.dockerBlue.opacity(0.55))
                .frame(width: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 22, x: -8, y: 0)
    }
}

struct DrawerPageLayout<Content: View, Drawer: View>: View {
    var isDrawerPresented: Bool
    @ViewBuilder var content: Content
    @ViewBuilder var drawer: Drawer

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView {
                content
                    .padding(20)
                    .padding(.trailing, isDrawerPresented ? 430 : 0)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if isDrawerPresented {
                drawer
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }
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

struct DetailInfoCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
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
    }
}
