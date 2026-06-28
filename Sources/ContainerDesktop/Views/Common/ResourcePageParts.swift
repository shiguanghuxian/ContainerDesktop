import AppKit
import SwiftUI

struct ResourceToolbar<Actions: View>: View {
    @Binding var searchText: String
    var placeholder: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .frame(maxWidth: 360)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }

            Spacer()
            actions
        }
        .padding(.vertical, 6)
    }
}

struct ResourceTable<Header: View, Rows: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(CDTheme.tableHeaderSurface)

            Divider()
            rows
        }
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

struct ResourceTableHeaderLabel: View {
    var title: String
    var width: CGFloat?
    var alignment: Alignment = .leading

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

struct ResourceTableRow<Content: View>: View {
    var isSelected: Bool
    var onActivate: (() -> Void)?
    var activationHelp: String?
    private var content: Content
    @State private var isHovering = false

    init(
        isSelected: Bool = false,
        onActivate: (() -> Void)? = nil,
        activationHelp: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.onActivate = onActivate
        self.activationHelp = activationHelp
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            rowContent

            Divider()
                .padding(.leading, 14)
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        ZStack {
            rowBackground

            if let onActivate {
                Button(action: onActivate) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text(activationHelp ?? "Open"))
                .help(activationHelp ?? "")
            }

            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 54)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return CDTheme.selectionSurface }
        if isHovering { return CDTheme.hoverSurface }
        return .clear
    }
}

struct ResourceStatusDot: View {
    var tint: Color
    var isHollow = false

    var body: some View {
        Image(systemName: isHollow ? "circle" : "circle.fill")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 20)
    }
}

struct RowActionButton: View {
    var systemImage: String
    var tint: Color = CDTheme.dockerBlue
    var isLoading = false
    var isDisabled = false
    var help: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDisabled ? .secondary : tint)
                        .frame(width: 28, height: 28)
                }
            }
            .background((isDisabled ? Color.secondary : tint).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .help(help ?? "")
    }
}

struct RowActionMenuButton<Content: View>: View {
    var systemImage: String
    var tint: Color = CDTheme.dockerBlue
    var isDisabled = false
    var help: String?
    private let content: () -> Content

    init(
        systemImage: String,
        tint: Color = CDTheme.dockerBlue,
        isDisabled: Bool = false,
        help: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.isDisabled = isDisabled
        self.help = help
        self.content = content
    }

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDisabled ? .secondary : tint)
                .frame(width: 28, height: 28)
                .background((isDisabled ? Color.secondary : tint).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(isDisabled)
        .help(help ?? "")
    }
}

struct CopyableIPAddressText: View {
    @Environment(\.appLanguage) private var language
    var value: String
    var font: Font = .callout.monospaced()
    var foregroundStyle: AnyShapeStyle = AnyShapeStyle(.secondary)
    var textSelectionEnabled = false
    var lineLimit = 1
    var minimumScaleFactor: CGFloat = 0.82
    var copyButtonSize: CGFloat = 22

    private var copyValue: String? {
        IPAddressCopy.normalized(value)
    }

    var body: some View {
        HStack(spacing: 4) {
            ipText

            if let copyValue {
                Button {
                    copy(copyValue)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CDTheme.dockerBlue)
                        .frame(width: copyButtonSize, height: copyButtonSize)
                        .background(CDTheme.dockerBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "复制 IP" : "Copy IP")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var ipText: some View {
        let text = Text(value)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineLimit(lineLimit)
            .truncationMode(.middle)
            .minimumScaleFactor(minimumScaleFactor)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

        if textSelectionEnabled {
            text.textSelection(.enabled)
        } else {
            text
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct ContainerBrowserPortInlineMenuButton: View {
    @Environment(\.appLanguage) private var language
    var targets: [ContainerBrowserPortTarget]
    var isDisabled = false

    var body: some View {
        if !targets.isEmpty {
            Menu {
                ContainerBrowserPortMenuItems(targets: targets)
            } label: {
                Label(language.resolved == .zhHans ? "端口操作" : "Port Actions", systemImage: "ellipsis.circle")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(isDisabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(CDTheme.dockerBlue))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(CDTheme.dockerBlue.opacity(isDisabled ? 0.05 : 0.10), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(CDTheme.dockerBlue.opacity(isDisabled ? 0.10 : 0.18))
                    }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(isDisabled)
            .help(isDisabled
                ? (language.resolved == .zhHans ? "容器未运行，端口不可访问" : "The container is not running.")
                : (language.resolved == .zhHans ? "打开网站或复制端口连接信息" : "Open websites or copy port connection details"))
        }
    }
}

struct ContainerBrowserPortMenuButton: View {
    @Environment(\.appLanguage) private var language
    var targets: [ContainerBrowserPortTarget]
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        if isLoading {
            RowActionButton(
                systemImage: "ellipsis.circle",
                tint: CDTheme.dockerBlue,
                isLoading: true,
                isDisabled: true,
                help: language.resolved == .zhHans ? "正在读取端口映射" : "Loading port mappings"
            ) {}
        } else if !targets.isEmpty {
            RowActionMenuButton(
                systemImage: "ellipsis.circle",
                tint: CDTheme.dockerBlue,
                help: language.resolved == .zhHans ? "打开网站或复制端口连接信息" : "Open websites or copy port connection details"
            ) {
                ContainerBrowserPortMenuItems(targets: targets)
            }
        } else if let errorMessage {
            RowActionButton(
                systemImage: "ellipsis.circle",
                tint: .secondary,
                isDisabled: true,
                help: errorMessage
            ) {}
        }
    }
}

struct ContainerBrowserPortMenuItems: View {
    @Environment(\.appLanguage) private var language
    var targets: [ContainerBrowserPortTarget]

    var body: some View {
        let hostTargets = menuTargets(for: .host)
        let containerTargets = menuTargets(for: .container)

        if !hostTargets.isEmpty {
            Section {
                targetButtons(hostTargets)
            } header: {
                Text(language.resolved == .zhHans ? "宿主机" : "Host")
            }
        }

        if !containerTargets.isEmpty {
            Section {
                targetButtons(containerTargets)
            } header: {
                Text(language.resolved == .zhHans ? "容器 IP" : "Container IP")
            }
        }
    }

    @ViewBuilder
    private func targetButtons(_ targets: [ContainerBrowserPortTarget]) -> some View {
        ForEach(targets) { target in
            Button {
                execute(target)
            } label: {
                Label(menuTitle(for: target), systemImage: target.systemImage)
            }
            .help(helpText(for: target))
        }
    }

    private func menuTargets(for source: ContainerBrowserPortTargetSource) -> [ContainerBrowserPortTarget] {
        targets
            .filter { $0.source == source }
            .sorted {
                if $0.containerPort != $1.containerPort {
                    return $0.containerPort < $1.containerPort
                }
                if $0.action.menuOrder != $1.action.menuOrder {
                    return $0.action.menuOrder < $1.action.menuOrder
                }
                return $0.endpointText < $1.endpointText
            }
    }

    private func menuTitle(for target: ContainerBrowserPortTarget) -> String {
        let verb: String
        switch target.action {
        case .openURL:
            verb = language.resolved == .zhHans ? "打开" : "Open"
        case .copyURL:
            verb = language.resolved == .zhHans ? "复制 URL" : "Copy URL"
        case .copyAddress:
            verb = language.resolved == .zhHans ? "复制地址" : "Copy address"
        case .copyConnectionString:
            verb = language.resolved == .zhHans ? "复制连接串" : "Copy connection string"
        case .copyEnvironmentSnippet:
            verb = language.resolved == .zhHans ? "复制环境变量" : "Copy env snippet"
        case .copyCLICommand:
            verb = language.resolved == .zhHans ? "复制客户端命令" : "Copy client command"
        case .copyHealthCheckCommand:
            verb = language.resolved == .zhHans ? "复制检查命令" : "Copy check command"
        }

        return "\(verb) · \(target.title) · \(target.endpointText)"
    }

    private func execute(_ target: ContainerBrowserPortTarget) {
        switch target.action {
        case .openURL:
            if let url = target.url {
                NSWorkspace.shared.open(url)
            }
        case .copyURL, .copyAddress, .copyConnectionString, .copyEnvironmentSnippet, .copyCLICommand, .copyHealthCheckCommand:
            if let value = target.copyValue {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
        }
    }

    private func helpText(for target: ContainerBrowserPortTarget) -> String {
        target.url?.absoluteString ?? target.copyValue ?? target.endpointText
    }
}

struct ExternalTerminalDestinationMenuItems: View {
    @Environment(\.appLanguage) private var language
    var onSelect: (ExternalTerminalDestination) -> Void

    var body: some View {
        ForEach(ExternalTerminalDestination.allCases) { destination in
            Button {
                onSelect(destination)
            } label: {
                Label(destination.title(language: language), systemImage: destination.systemImage)
            }
        }
    }
}

struct DestructiveRowActionButton: View {
    var systemImage: String = "trash"
    var isLoading = false
    var isDisabled = false
    var help: String?
    var action: () -> Void

    var body: some View {
        RowActionButton(
            systemImage: systemImage,
            tint: .red,
            isLoading: isLoading,
            isDisabled: isDisabled,
            help: help,
            action: action
        )
    }
}
