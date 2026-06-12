import SwiftUI

struct StatusPill: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay {
                    Capsule()
                        .strokeBorder(tint.opacity(0.24))
                }
        }
    }
}
