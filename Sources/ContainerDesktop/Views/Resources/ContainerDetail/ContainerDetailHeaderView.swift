import SwiftUI

struct ContainerDetailHeaderView: View {
    @Environment(\.appLanguage) private var language
    var container: ContainerSummary
    var inspectText: String
    var parentTitle: String
    var onBack: () -> Void
    var onStartStop: () -> Void
    var onRestart: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SecondaryPageBackBar(
                parentTitle: parentTitle,
                detailTitle: container.id,
                onBack: onBack
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    titleBlock
                        .layoutPriority(2)

                    Spacer(minLength: 12)

                    statusBlock
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock

                    HStack(alignment: .center, spacing: 12) {
                        statusBlock
                        Spacer(minLength: 0)
                        actionButtons
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 10)], spacing: 10) {
                detailChip(title: language.t(.image), value: container.imageName, systemImage: "cube")
                detailChip(title: "IP", value: container.primaryIP, systemImage: "network")
                detailChip(title: "Platform", value: container.platformName, systemImage: "desktopcomputer")
                detailChip(title: "Resources", value: "\(container.cpuCount) CPU / \(container.memoryDisplay)", systemImage: "cpu")
            }
        }
        .padding(16)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: "shippingbox", tint: CDTheme.dockerBlue, size: 48)

            VStack(alignment: .leading, spacing: 8) {
                Text(container.id)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(String(container.id.prefix(12)), systemImage: "number")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Label(container.imageName, systemImage: "cube")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Label(portSummary, systemImage: "point.3.connected.trianglepath.dotted")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language.t(.status).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            StatusPill(
                title: container.state,
                systemImage: container.state == "running" ? "bolt.fill" : "bolt.slash",
                tint: container.state == "running" ? CDTheme.lime : .secondary
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onStartStop) {
                Image(systemName: container.state == "running" ? "stop.fill" : "play.fill")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .help(container.state == "running" ? "Stop" : "Start")

            Button(action: onRestart) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.bordered)
            .help("Restart")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .help(language.t(.delete))
        }
        .fixedSize()
    }

    private func detailChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var portSummary: String {
        let values = Self.extractPortStrings(from: inspectText)
        if values.isEmpty { return "No ports" }
        return values.prefix(3).joined(separator: ", ")
    }

    private static func extractPortStrings(from text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let value = try? JSONDecoder.containerDesktop.decode(JSONValue.self, from: data) else {
            return []
        }
        return extractPortStrings(from: value)
    }

    private static func extractPortStrings(from value: JSONValue) -> [String] {
        let object: [String: JSONValue]?
        switch value {
        case .array(let values):
            if case .object(let first)? = values.first {
                object = first
            } else {
                object = nil
            }
        case .object(let raw):
            object = raw
        default:
            object = nil
        }

        guard let configuration = object?["configuration"],
              case .object(let config) = configuration,
              let publishedPorts = config["publishedPorts"],
              case .array(let ports) = publishedPorts else {
            return []
        }

        return ports.compactMap { port in
            guard case .object(let item) = port else { return nil }
            let hostPort = item["hostPort"]?.plainText ?? item["host"]?.plainText
            let containerPort = item["containerPort"]?.plainText ?? item["port"]?.plainText
            let proto = item["protocol"]?.plainText ?? "tcp"
            if let hostPort, let containerPort {
                return "\(hostPort):\(containerPort)/\(proto)"
            }
            return containerPort.map { "\($0)/\(proto)" }
        }
    }
}

private extension JSONValue {
    var plainText: String? {
        switch self {
        case .string(let value): value
        case .number(let value):
            value.rounded() == value ? String(Int64(value)) : String(value)
        case .bool(let value): String(value)
        default: nil
        }
    }
}
