import SwiftUI

struct SidebarAuthorInfoView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme

    @State private var isPopoverPresented = false
    @State private var isTriggerHovering = false
    @State private var isPopoverHovering = false
    @State private var dismissTask: Task<Void, Never>?

    private let authorName = "时光弧线"
    private let authorEmail = "zuoxiupeng@live.com"
    private let authorGitHub = "github.com/shiguanghuxian"

    var body: some View {
        Button {
            togglePopover()
        } label: {
            compactEntry
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isTriggerHovering = hovering
            if hovering {
                showPopover()
            } else {
                scheduleDismiss()
            }
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            popoverContent
                .onHover { hovering in
                    isPopoverHovering = hovering
                    if hovering {
                        cancelDismiss()
                    } else {
                        scheduleDismiss()
                    }
                }
        }
        .onChange(of: isPopoverPresented) { _, presented in
            if !presented {
                isPopoverHovering = false
                cancelDismiss()
            }
        }
        .onDisappear {
            cancelDismiss()
        }
        .help(language.resolved == .zhHans ? "查看作者信息" : "View author details")
        .accessibilityLabel(authorSummaryText)
    }

    private var compactEntry: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CDTheme.cyan)
                .frame(width: 12)

            Text(authorSummaryTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(CDTheme.cyan)
                .lineLimit(1)

            Text("·")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
                .lineLimit(1)

            Text(authorName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 4)

            Image(systemName: isPopoverPresented ? "chevron.down" : "info.circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(secondaryText)
                .frame(width: 10)
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entryBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(CDTheme.separator.opacity(0.52))
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(CDTheme.cyan)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(authorName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text(authorSummaryTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CDTheme.cyan)
                        .lineLimit(1)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: URL(string: "mailto:\(authorEmail)")!) {
                    authorLinkLabel(text: authorEmail, systemImage: "envelope")
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "发送邮件给作者" : "Email the author")

                Link(destination: URL(string: "https://\(authorGitHub)")!) {
                    authorLinkLabel(text: authorGitHub, systemImage: "link")
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "打开作者 GitHub 主页" : "Open the author's GitHub profile")
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }

    private func authorLinkLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 16)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(secondaryText)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(linkBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(CDTheme.separator.opacity(0.75))
        }
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    private var authorSummaryTitle: String {
        language.resolved == .zhHans ? "作者信息" : "Author"
    }

    private var authorSummaryText: String {
        "\(authorSummaryTitle) \(authorName)"
    }

    private var entryBackground: Color {
        if isPopoverPresented || isTriggerHovering {
            return CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.16 : 0.08)
        }
        return colorScheme == .dark ? CDTheme.sidebarElevated : CDTheme.panelSurface
    }

    private var linkBackground: Color {
        colorScheme == .dark ? CDTheme.sidebarElevated : CDTheme.inputSurface
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.58) : .secondary
    }

    private func togglePopover() {
        if isPopoverPresented {
            isPopoverPresented = false
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        cancelDismiss()
        isPopoverPresented = true
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            if !isTriggerHovering && !isPopoverHovering {
                isPopoverPresented = false
            }
        }
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }
}
