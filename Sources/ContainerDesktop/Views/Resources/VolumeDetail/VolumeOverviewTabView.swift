import AppKit
import SwiftUI

struct VolumeOverviewTabView: View {
    @Environment(\.appLanguage) private var language
    var volume: VolumeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailSection(title: language.resolved == .zhHans ? "存储卷" : "Volume") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: volume.name)
                    DetailInfoRow(title: language.t(.type), value: volume.typeText)
                    DetailInfoRow(title: language.t(.driver), value: volume.driver)
                    DetailInfoRow(title: "Format", value: volume.format)
                    CopyableVolumeSourceRow(title: language.t(.source), value: volume.source)
                    DetailInfoRow(title: language.t(.created), value: volume.createdText)
                    DetailInfoRow(title: language.t(.size), value: volume.sizeDisplay)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "文件浏览" : "File Browsing") {
                DetailInfoCard {
                    Label(
                        language.resolved == .zhHans
                            ? "Files 标签页会通过临时容器挂载卷来读取真实 Apple volume，不直接解析 volume.img。"
                            : "The Files tab reads Apple volumes by mounting them in a transient container instead of parsing volume.img directly.",
                        systemImage: "info.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct CopyableVolumeSourceRow: View {
    @Environment(\.appLanguage) private var language
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 22, height: 22)
                    .background(CDTheme.dockerBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "复制源目录路径" : "Copy source path")
        }
        .font(.callout)
    }
}
