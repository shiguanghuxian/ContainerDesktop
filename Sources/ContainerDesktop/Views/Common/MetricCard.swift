import SwiftUI

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IconTile(systemImage: systemImage, tint: tint, size: 34)

                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Rectangle()
                    .fill(tint)
                    .frame(width: 34, height: 3)
                    .clipShape(Capsule())
                    .opacity(0.75)
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(accent: tint)
    }
}
