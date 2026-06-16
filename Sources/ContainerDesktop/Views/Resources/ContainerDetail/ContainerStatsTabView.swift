import Charts
import SwiftUI

struct ContainerStatsTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var statsHistoryStore: ContainerStatsHistoryStore
    var container: ContainerSummary

    @State private var selectedSample: ContainerStatsSample?

    private let maxVisibleSamples = 1_200

    private var historySamples: [ContainerStatsSample] {
        statsHistoryStore.samples(for: container.id)
    }

    var body: some View {
        let samples = historySamples
        let visibleSamples = samples.downsampled(maxCount: maxVisibleSamples)
        let displaySample = selectedSample ?? samples.last

        VStack(alignment: .leading, spacing: 12) {
            toolbar(displaySample: displaySample, sampleCount: samples.count)

            if container.state != "running" {
                StatusBanner(
                    text: language.resolved == .zhHans ? "容器未运行，Stats 会继续展示最近 24 小时缓存。" : "The container is not running; cached stats from the last 24 hours remain visible.",
                    systemImage: "pause.circle",
                    tint: .secondary
                )
            }

            if let error = statsHistoryStore.errorMessage?.nilIfBlank {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            if let selectedSample {
                StatsHoverSummary(sample: selectedSample)
            }

            if samples.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CPUChart(
                        samples: visibleSamples,
                        allSamples: samples,
                        selectedSample: $selectedSample
                    )
                    MemoryChart(
                        samples: visibleSamples,
                        allSamples: samples,
                        selectedSample: $selectedSample
                    )
                    IOChart(
                        title: "Disk read/write",
                        samples: visibleSamples,
                        allSamples: samples,
                        firstLabel: "Read",
                        secondLabel: "Write",
                        first: \.blockReadBytes,
                        second: \.blockWriteBytes,
                        firstColor: CDTheme.dockerBlue,
                        secondColor: CDTheme.ember,
                        selectedSample: $selectedSample
                    )
                    IOChart(
                        title: "Network I/O",
                        samples: visibleSamples,
                        allSamples: samples,
                        firstLabel: "Received",
                        secondLabel: "Sent",
                        first: \.networkRxBytes,
                        second: \.networkTxBytes,
                        firstColor: CDTheme.dockerBlue,
                        secondColor: CDTheme.ember,
                        selectedSample: $selectedSample
                    )
                }
            }
        }
    }

    private func toolbar(displaySample: ContainerStatsSample?, sampleCount: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                statsSummary(displaySample: displaySample, sampleCount: sampleCount)
                Spacer(minLength: 8)
                toolbarActions
            }

            VStack(alignment: .leading, spacing: 8) {
                statsSummary(displaySample: displaySample, sampleCount: sampleCount)
                toolbarActions
            }
        }
    }

    @ViewBuilder
    private func statsSummary(displaySample: ContainerStatsSample?, sampleCount: Int) -> some View {
        if let sample = displaySample {
            HStack(spacing: 12) {
                metricLabel(title: "CPU", value: String(format: "%.1f%%", sample.cpuPercent))
                metricLabel(title: "Memory", value: "\(sample.snapshot.memoryUsageDisplay) / \(sample.snapshot.memoryLimitDisplay)")
                metricLabel(title: "PIDs", value: "\(sample.snapshot.numProcesses)")
                metricLabel(title: language.resolved == .zhHans ? "样本" : "Samples", value: "\(sampleCount)")
            }
        } else {
            Text(language.resolved == .zhHans ? "等待 stats 数据..." : "Waiting for stats data...")
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 8) {
            Label(
                statsHistoryStore.isMonitoring
                    ? (language.resolved == .zhHans ? "后台记录中" : "Recording")
                    : (language.resolved == .zhHans ? "未记录" : "Paused"),
                systemImage: statsHistoryStore.isMonitoring ? "dot.radiowaves.left.and.right" : "pause.circle"
            )
            .foregroundStyle(statsHistoryStore.isMonitoring ? CDTheme.lime : .secondary)

            if let lastSampledAt = statsHistoryStore.lastSampledAt {
                Text(lastSampledAt.formatted(date: .omitted, time: .standard))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await statsHistoryStore.sampleNow(containerIDs: [container.id], forcePersist: true)
                }
            } label: {
                if statsHistoryStore.isSampling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(statsHistoryStore.isSampling)
            .help(language.t(.refresh))
        }
        .fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if statsHistoryStore.isSampling || statsHistoryStore.isMonitoring {
                ProgressView()
            }
            ContentUnavailableView(
                language.resolved == .zhHans ? "暂无 Stats 历史" : "No stats history",
                systemImage: "chart.xyaxis.line",
                description: Text(language.resolved == .zhHans ? "后台记录采到样本后会显示最近 24 小时趋势。" : "The last 24 hours of trends will appear once background recording captures samples.")
            )
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func metricLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
    var allSamples: [ContainerStatsSample]
    @Binding var selectedSample: ContainerStatsSample?

    private var activeSample: ContainerStatsSample? {
        selectedSample ?? allSamples.last
    }

    var body: some View {
        StatsChartCard(title: "CPU usage", value: String(format: "%.1f%%", activeSample?.cpuPercent ?? 0)) {
            Chart {
                ForEach(samples) { sample in
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

                if let selectedSample {
                    RuleMark(x: .value("Selected", selectedSample.date))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    PointMark(
                        x: .value("Selected time", selectedSample.date),
                        y: .value("Selected CPU", selectedSample.cpuPercent)
                    )
                    .foregroundStyle(CDTheme.dockerBlue)
                    .symbolSize(48)
                }
            }
            .chartYScale(domain: 0...max(20, (allSamples.map(\.cpuPercent).max() ?? 0) * 1.25))
            .statsHoverOverlay(samples: allSamples, selectedSample: $selectedSample)
        }
    }
}

private struct MemoryChart: View {
    var samples: [ContainerStatsSample]
    var allSamples: [ContainerStatsSample]
    @Binding var selectedSample: ContainerStatsSample?

    private var activeSample: ContainerStatsSample? {
        selectedSample ?? allSamples.last
    }

    var body: some View {
        let value = activeSample.map {
            "\($0.snapshot.memoryUsageDisplay) / \($0.snapshot.memoryLimitDisplay)"
        } ?? "-"

        StatsChartCard(title: "Memory usage", value: value) {
            Chart {
                ForEach(samples) { sample in
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

                if let selectedSample {
                    RuleMark(x: .value("Selected", selectedSample.date))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    PointMark(
                        x: .value("Selected time", selectedSample.date),
                        y: .value("Selected memory", selectedSample.memoryUsageBytes)
                    )
                    .foregroundStyle(CDTheme.cyan)
                    .symbolSize(48)
                }
            }
            .chartYScale(domain: 0...max(1, allSamples.map(\.memoryLimitBytes).max() ?? 1))
            .statsHoverOverlay(samples: allSamples, selectedSample: $selectedSample)
        }
    }
}

private struct IOChart: View {
    var title: String
    var samples: [ContainerStatsSample]
    var allSamples: [ContainerStatsSample]
    var firstLabel: String
    var secondLabel: String
    var first: KeyPath<ContainerStatsSample, Double>
    var second: KeyPath<ContainerStatsSample, Double>
    var firstColor: Color
    var secondColor: Color
    @Binding var selectedSample: ContainerStatsSample?

    private var activeSample: ContainerStatsSample? {
        selectedSample ?? allSamples.last
    }

    var body: some View {
        let value = activeSample.map {
            "\(bytes($0[keyPath: first])) / \(bytes($0[keyPath: second]))"
        } ?? "-"
        let maxY = allSamples.map { max($0[keyPath: first], $0[keyPath: second]) }.max() ?? 0

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

                if let selectedSample {
                    RuleMark(x: .value("Selected", selectedSample.date))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    PointMark(
                        x: .value("Selected time", selectedSample.date),
                        y: .value(firstLabel, selectedSample[keyPath: first])
                    )
                    .foregroundStyle(firstColor)
                    .symbolSize(42)
                    PointMark(
                        x: .value("Selected time", selectedSample.date),
                        y: .value(secondLabel, selectedSample[keyPath: second])
                    )
                    .foregroundStyle(secondColor)
                    .symbolSize(42)
                }
            }
            .chartYScale(domain: 0...max(1, maxY * 1.08))
            .statsHoverOverlay(samples: allSamples, selectedSample: $selectedSample)
        }
    }

    private func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}

private struct StatsHoverSummary: View {
    var sample: ContainerStatsSample

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metric("Time", sample.date.formatted(date: .abbreviated, time: .standard))
                metric("CPU", String(format: "%.1f%%", sample.cpuPercent))
                metric("Memory", "\(sample.snapshot.memoryUsageDisplay) / \(sample.snapshot.memoryLimitDisplay)")
                metric("Disk", "\(bytes(sample.blockReadBytes)) / \(bytes(sample.blockWriteBytes))")
                metric("Network", "\(bytes(sample.networkRxBytes)) / \(bytes(sample.networkTxBytes))")
            }

            VStack(alignment: .leading, spacing: 8) {
                metric("Time", sample.date.formatted(date: .abbreviated, time: .standard))
                HStack(spacing: 12) {
                    metric("CPU", String(format: "%.1f%%", sample.cpuPercent))
                    metric("Memory", "\(sample.snapshot.memoryUsageDisplay) / \(sample.snapshot.memoryLimitDisplay)")
                    metric("Disk", "\(bytes(sample.blockReadBytes)) / \(bytes(sample.blockWriteBytes))")
                    metric("Network", "\(bytes(sample.networkRxBytes)) / \(bytes(sample.networkTxBytes))")
                }
            }
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
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

private extension View {
    func statsHoverOverlay(
        samples: [ContainerStatsSample],
        selectedSample: Binding<ContainerStatsSample?>
    ) -> some View {
        chartOverlay { chartProxy in
            GeometryReader { geometryProxy in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            guard let plotFrame = chartProxy.plotFrame else { return }
                            let plotAreaFrame = geometryProxy[plotFrame]
                            let xPosition = point.x - plotAreaFrame.origin.x
                            guard xPosition >= 0,
                                  xPosition <= plotAreaFrame.width,
                                  let date: Date = chartProxy.value(atX: xPosition) else {
                                return
                            }
                            selectedSample.wrappedValue = samples.nearest(to: date)
                        case .ended:
                            selectedSample.wrappedValue = nil
                        }
                    }
            }
        }
    }
}
