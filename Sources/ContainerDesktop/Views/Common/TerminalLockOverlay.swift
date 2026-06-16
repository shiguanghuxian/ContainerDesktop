import SwiftUI

struct TerminalLockOverlay: View {
    var title: String
    var message: String
    var connectTitle: String
    var isConnectDisabled = false
    var onConnect: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)

            VStack(spacing: 12) {
                Label(title, systemImage: "lock.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Button {
                    onConnect()
                } label: {
                    Label(connectTitle, systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnectDisabled)
                .help(connectTitle)
            }
            .padding(18)
            .frame(maxWidth: 380)
            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.16))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
