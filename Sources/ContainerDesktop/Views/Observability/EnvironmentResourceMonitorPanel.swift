import SwiftUI

struct EnvironmentResourceMonitorPanel: View {
    @Environment(\.appLanguage) private var language
    var snapshot: EnvironmentResourceSnapshot?
    var hostProcesses: [HostProcessResourceSnapshot]
    var errorMessage: String?
    var compact: Bool = false

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "环境资源监控" : "Environment Resources",
            subtitle: language.resolved == .zhHans ? "apple/container 与 Compose 运行时消耗" : "apple/container and Compose runtime usage",
            systemImage: "gauge.with.dots.needle.bottom.50percent"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let errorMessage = errorMessage?.nilIfBlank {
                    StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                }

                if let snapshot {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 136 : 150), spacing: 10)], spacing: 10) {
                        ResourceMetricTile(
                            title: "CPU",
                            value: String(format: "%.1f%%", snapshot.cpuPercent),
                            detail: language.resolved == .zhHans ? "容器聚合" : "containers"
                        )
                        ResourceMetricTile(
                            title: "Memory",
                            value: ByteCountFormatter.string(fromByteCount: snapshot.memoryUsageBytes, countStyle: .memory),
                            detail: snapshot.memoryLimitBytes > 0 ? snapshot.memoryDisplay : (language.resolved == .zhHans ? "无上限数据" : "no limit data")
                        )
                        ResourceMetricTile(
                            title: "Network",
                            value: ContainerResourceSample.bytesPerSecond(snapshot.networkRxBytesPerSecond + snapshot.networkTxBytesPerSecond),
                            detail: snapshot.networkRateDisplay
                        )
                        ResourceMetricTile(
                            title: "Block I/O",
                            value: ContainerResourceSample.bytesPerSecond(snapshot.blockReadBytesPerSecond + snapshot.blockWriteBytesPerSecond),
                            detail: snapshot.blockIORateDisplay
                        )
                        ResourceMetricTile(
                            title: "PIDs",
                            value: "\(snapshot.numProcesses)",
                            detail: "\(snapshot.runningContainerCount)/\(snapshot.containerCount) running"
                        )
                        ResourceMetricTile(
                            title: language.resolved == .zhHans ? "宿主进程" : "Host processes",
                            value: String(format: "%.1f%%", snapshot.hostProcessCPUPercent),
                            detail: "\(snapshot.hostMemoryDisplay) RSS"
                        )
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                        Text(snapshot.date.formatted(date: .omitted, time: .standard))
                        Spacer()
                        Text("\(hostProcesses.count) processes")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    EmptyStateView(
                        title: language.resolved == .zhHans ? "等待资源数据" : "Waiting for resource data",
                        message: language.resolved == .zhHans ? "监控启动后会显示 CPU、内存、网络与 I/O。" : "CPU, memory, network, and I/O appear once monitoring starts.",
                        systemImage: "chart.xyaxis.line"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct ResourceMetricTile: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
