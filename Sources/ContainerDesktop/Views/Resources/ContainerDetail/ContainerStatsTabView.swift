import Charts
import SwiftUI

struct ContainerStatsTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ContainerDetailStore
    var container: ContainerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if container.state != "running" {
                StatusBanner(
                    text: language.resolved == .zhHans ? "容器未运行，Stats 可能没有数据。" : "The container is not running; stats may be unavailable.",
                    systemImage: "pause.circle",
                    tint: .secondary
                )
            }

            if let error = store.statsError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            if store.statsSamples.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CPUChart(samples: store.statsSamples)
                    MemoryChart(samples: store.statsSamples)
                    IOChart(
                        title: "Disk read/write",
                        samples: store.statsSamples,
                        firstLabel: "Read",
                        secondLabel: "Write",
                        first: \.blockReadBytes,
                        second: \.blockWriteBytes,
                        firstColor: CDTheme.dockerBlue,
                        secondColor: CDTheme.ember
                    )
                    IOChart(
                        title: "Network I/O",
                        samples: store.statsSamples,
                        firstLabel: "Received",
                        secondLabel: "Sent",
                        first: \.networkRxBytes,
                        second: \.networkTxBytes,
                        firstColor: CDTheme.dockerBlue,
                        secondColor: CDTheme.ember
                    )
                }
            }
        }
        .task {
            store.startStatsPolling()
        }
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                statsSummary
                Spacer(minLength: 8)
                toolbarActions
            }

            VStack(alignment: .leading, spacing: 8) {
                statsSummary
                toolbarActions
            }
        }
    }

    @ViewBuilder
    private var statsSummary: some View {
        if let stats = store.currentStats {
            HStack(spacing: 12) {
                metricLabel(title: "CPU", value: String(format: "%.1f%%", store.statsSamples.last?.cpuPercent ?? 0))
                metricLabel(title: "Memory", value: "\(stats.memoryUsageDisplay) / \(stats.memoryLimitDisplay)")
                metricLabel(title: "PIDs", value: "\(stats.numProcesses)")
            }
        } else {
            Text(language.resolved == .zhHans ? "等待 stats 数据..." : "Waiting for stats data...")
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 8) {
            if store.isStatsPolling {
                Label(language.resolved == .zhHans ? "实时刷新" : "Live", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(CDTheme.lime)
            }

            Button {
                Task { await store.refreshStatsOnce() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(language.t(.refresh))
        }
        .fixedSize()
    }

    private func metricLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

private struct CPUChart: View {
    var samples: [ContainerStatsSample]

    var body: some View {
        StatsChartCard(title: "CPU usage", value: String(format: "%.1f%%", samples.last?.cpuPercent ?? 0)) {
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("CPU", sample.cpuPercent)
                )
                .foregroundStyle(CDTheme.dockerBlue.opacity(0.18))
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("CPU", sample.cpuPercent)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CDTheme.dockerBlue)
            }
            .chartYScale(domain: 0...max(20, (samples.map(\.cpuPercent).max() ?? 0) * 1.25))
        }
    }
}

private struct MemoryChart: View {
    var samples: [ContainerStatsSample]

    var body: some View {
        let latest = samples.last
        let value = latest.map {
            "\(ByteCountFormatter.string(fromByteCount: $0.snapshot.memoryUsageBytes, countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: $0.snapshot.memoryLimitBytes, countStyle: .memory))"
        } ?? "—"

        StatsChartCard(title: "Memory usage", value: value) {
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("Memory", sample.memoryUsageBytes)
                )
                .foregroundStyle(CDTheme.cyan.opacity(0.18))
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Memory", sample.memoryUsageBytes)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(CDTheme.cyan)
            }
            .chartYScale(domain: 0...max(1, latest?.memoryLimitBytes ?? 1))
        }
    }
}

private struct IOChart: View {
    var title: String
    var samples: [ContainerStatsSample]
    var firstLabel: String
    var secondLabel: String
    var first: KeyPath<ContainerStatsSample, Double>
    var second: KeyPath<ContainerStatsSample, Double>
    var firstColor: Color
    var secondColor: Color

    var body: some View {
        let latest = samples.last
        let value = latest.map {
            "\(bytes($0[keyPath: first])) / \(bytes($0[keyPath: second]))"
        } ?? "—"

        StatsChartCard(title: title, value: value) {
            Chart {
                ForEach(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value(firstLabel, sample[keyPath: first])
                    )
                    .foregroundStyle(firstColor)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value(secondLabel, sample[keyPath: second])
                    )
                    .foregroundStyle(secondColor)
                    .interpolationMethod(.catmullRom)
                }
            }
        }
    }

    private func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}

private struct StatsChartCard<Content: View>: View {
    var title: String
    var value: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Text(value)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            content
                .frame(height: 190)
        }
        .padding(14)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
