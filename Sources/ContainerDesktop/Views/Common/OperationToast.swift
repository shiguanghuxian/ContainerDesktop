import SwiftUI

struct OperationToast: View {
    @Environment(\.appLanguage) private var language
    var feedback: RuntimeOperationFeedback
    var onDismiss: () -> Void

    private var tint: Color {
        switch feedback.phase {
        case .running: CDTheme.dockerBlue
        case .succeeded: CDTheme.lime
        case .failed: CDTheme.ember
        }
    }

    private var title: String {
        switch feedback.phase {
        case .running: language.resolved == .zhHans ? "正在执行" : "Running"
        case .succeeded: language.resolved == .zhHans ? "操作完成" : "Completed"
        case .failed: language.resolved == .zhHans ? "操作失败" : "Failed"
        }
    }

    private var systemImage: String {
        switch feedback.phase {
        case .running: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(feedback.message)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if feedback.phase != .running {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "关闭提示" : "Dismiss")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 360, idealWidth: 460, maxWidth: 580, minHeight: 60)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(CDTheme.panelSurface)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 4)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.42))
        }
        .shadow(color: CDTheme.panelShadow, radius: 24, x: 0, y: 14)
    }

    @ViewBuilder
    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.12))
                .frame(width: 34, height: 34)
            if feedback.phase == .running {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}
