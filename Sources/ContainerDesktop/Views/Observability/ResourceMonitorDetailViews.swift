import Charts
import SwiftUI

struct ResourceMonitorChartsPanel: View {
    @Environment(\.appLanguage) private var language
    var history: [EnvironmentResourceSnapshot]

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "实时趋势" : "Live Trends",
            subtitle: language.resolved == .zhHans ? "最近 \(history.count) 个样本" : "Last \(history.count) samples",
            systemImage: "chart.xyaxis.line"
        ) {
            if history.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "暂无趋势数据" : "No trend data",
                    message: language.resolved == .zhHans ? "启动实时监控后会持续绘制趋势。" : "Start live monitoring to draw trends.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ResourceTrendChart(
                        title: "CPU",
                        value: String(format: "%.1f%%", history.last?.cpuPercent ?? 0),
                        history: history,
                        primaryLabel: "CPU",
                        primary: \.cpuPercent,
                        primaryColor: CDTheme.dockerBlue,
                        yUnit: "%"
                    )
                    ResourceTrendChart(
                        title: "Memory",
                        value: history.last.map { ByteCountFormatter.string(fromByteCount: $0.memoryUsageBytes, countStyle: .memory) } ?? "—",
                        history: history,
                        primaryLabel: "Memory",
                        primary: { Double($0.memoryUsageBytes) },
                        primaryColor: CDTheme.cyan,
                        yUnit: "bytes"
                    )
                    DualResourceTrendChart(
                        title: "Network",
                        value: history.last?.networkRateDisplay ?? "—",
                        history: history,
                        firstLabel: "RX",
                        first: \.networkRxBytesPerSecond,
                        secondLabel: "TX",
                        second: \.networkTxBytesPerSecond
                    )
                    DualResourceTrendChart(
                        title: "Block I/O",
                        value: history.last?.blockIORateDisplay ?? "—",
                        history: history,
                        firstLabel: "Read",
                        first: \.blockReadBytesPerSecond,
                        secondLabel: "Write",
                        second: \.blockWriteBytesPerSecond
                    )
                }
            }
        }
    }
}

struct ContainerResourceSamplesPanel: View {
    @Environment(\.appLanguage) private var language
    var samples: [ContainerResourceSample]
    var sort: ObservabilityStatsSort

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "容器资源" : "Container Resources",
            subtitle: language.resolved == .zhHans ? "按当前范围聚合和排序" : "Scoped and sorted by current filters",
            systemImage: "shippingbox"
        ) {
            if samples.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "暂无容器资源数据" : "No container resource data",
                    message: language.resolved == .zhHans ? "运行容器并刷新或开启实时监控。" : "Run containers and refresh or start live monitoring.",
                    systemImage: "shippingbox"
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(samples.sortedForObservability(by: sort)) { sample in
                        ContainerResourceSampleRow(sample: sample)
                        if sample.id != samples.sortedForObservability(by: sort).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct HostProcessResourcesPanel: View {
    @Environment(\.appLanguage) private var language
    var processes: [HostProcessResourceSnapshot]

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "宿主进程" : "Host Processes",
            subtitle: language.resolved == .zhHans ? "apple/container 与 container-compose 相关进程" : "apple/container and container-compose processes",
            systemImage: "cpu"
        ) {
            if processes.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "暂无宿主进程数据" : "No host process data",
                    message: language.resolved == .zhHans ? "采样后会显示 container 服务和临时 CLI 进程。" : "Samples show container services and temporary CLI processes.",
                    systemImage: "cpu"
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(processes) { process in
                        HostProcessResourceRow(process: process)
                        if process.id != processes.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct ContainerResourceSampleRow: View {
    var sample: ContainerResourceSample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(sample.id)
                    .font(.callout.weight(.semibold).monospaced())
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f%% CPU", sample.cpuPercent))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CDTheme.dockerBlue)
                Text("\(sample.numProcesses) proc")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    metric("Memory", "\(sample.memoryUsageDisplay) / \(sample.memoryLimitDisplay)")
                    metric("Network", sample.networkRateDisplay)
                }
                GridRow {
                    metric("Block I/O", sample.blockIORateDisplay)
                    metric("Updated", sample.date.formatted(date: .omitted, time: .standard))
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct HostProcessResourceRow: View {
    var process: HostProcessResourceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(process.displayName)
                    .font(.callout.weight(.semibold).monospaced())
                    .lineLimit(1)
                Text(process.category.title)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(CDTheme.dockerBlue.opacity(0.12), in: Capsule())
                    .foregroundStyle(CDTheme.dockerBlue)
                Spacer()
                Text("PID \(process.pid)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                metric("CPU", String(format: "%.1f%%", process.cpuPercent))
                metric("RSS", process.memoryDisplay)
                Text(process.arguments)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 10)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
        }
        .frame(minWidth: 64, alignment: .leading)
    }
}

private struct ResourceTrendChart: View {
    var title: String
    var value: String
    var history: [EnvironmentResourceSnapshot]
    var primaryLabel: String
    var primary: (EnvironmentResourceSnapshot) -> Double
    var primaryColor: Color
    var yUnit: String

    init(
        title: String,
        value: String,
        history: [EnvironmentResourceSnapshot],
        primaryLabel: String,
        primary: KeyPath<EnvironmentResourceSnapshot, Double>,
        primaryColor: Color,
        yUnit: String
    ) {
        self.title = title
        self.value = value
        self.history = history
        self.primaryLabel = primaryLabel
        self.primary = { $0[keyPath: primary] }
        self.primaryColor = primaryColor
        self.yUnit = yUnit
    }

    init(
        title: String,
        value: String,
        history: [EnvironmentResourceSnapshot],
        primaryLabel: String,
        primary: @escaping (EnvironmentResourceSnapshot) -> Double,
        primaryColor: Color,
        yUnit: String
    ) {
        self.title = title
        self.value = value
        self.history = history
        self.primaryLabel = primaryLabel
        self.primary = primary
        self.primaryColor = primaryColor
        self.yUnit = yUnit
    }

    var body: some View {
        ResourceChartCard(title: title, value: value) {
            Chart(history) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value(primaryLabel, primary(point))
                )
                .foregroundStyle(primaryColor.opacity(0.16))
                LineMark(
                    x: .value("Time", point.date),
                    y: .value(primaryLabel, primary(point))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(primaryColor)
            }
            .chartYScale(domain: 0...max(1, (history.map(primary).max() ?? 0) * 1.25))
        }
    }
}

private struct DualResourceTrendChart: View {
    var title: String
    var value: String
    var history: [EnvironmentResourceSnapshot]
    var firstLabel: String
    var first: KeyPath<EnvironmentResourceSnapshot, Double>
    var secondLabel: String
    var second: KeyPath<EnvironmentResourceSnapshot, Double>

    var body: some View {
        ResourceChartCard(title: title, value: value) {
            Chart {
                ForEach(history) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(firstLabel, point[keyPath: first])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(CDTheme.dockerBlue)

                    LineMark(
                        x: .value("Time", point.date),
                        y: .value(secondLabel, point[keyPath: second])
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(CDTheme.ember)
                }
            }
            .chartYScale(domain: 0...max(1, history.map { max($0[keyPath: first], $0[keyPath: second]) }.max() ?? 0))
        }
    }
}

private struct ResourceChartCard<Content: View>: View {
    var title: String
    var value: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            content
                .frame(height: 160)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
