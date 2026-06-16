import SwiftUI

struct VolumeCloneSheet: View {
    @Environment(\.appLanguage) private var language
    var sourceVolume: VolumeSummary
    @Binding var name: String
    @Binding var size: String
    var isRunning: Bool
    var onCancel: () -> Void
    var onClone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CDTheme.dockerBlue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.resolved == .zhHans ? "克隆存储卷" : "Clone Volume")
                        .font(.headline)
                    Text(sourceVolume.name)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField(language.resolved == .zhHans ? "目标卷名称" : "Target volume name", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker(language.t(.volumeSize), selection: $size) {
                    Text(language.resolved == .zhHans ? "默认" : "Default").tag("")
                    ForEach(FormPresetOptions.volumeSizes, id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                .labelsHidden()
            }

            Text(language.resolved == .zhHans
                ? "将创建一个新的 apple/container 卷，并复制源卷目录中的现有内容。运行中的容器不会被自动停止。"
                : "Creates a new apple/container volume and copies the current source directory contents. Running containers are not stopped automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(language.resolved == .zhHans ? "取消" : "Cancel", action: onCancel)
                    .help(language.resolved == .zhHans ? "取消克隆卷" : "Cancel volume clone")
                Button(language.resolved == .zhHans ? "克隆" : "Clone", action: onClone)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || name.trimmed.isEmpty)
                    .help(language.resolved == .zhHans ? "克隆存储卷" : "Clone volume")
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
