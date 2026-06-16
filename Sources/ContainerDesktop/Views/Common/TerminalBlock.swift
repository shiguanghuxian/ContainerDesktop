import SwiftUI

struct TerminalBlock: View {
    var text: String
    var minHeight: CGFloat = 180

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "无输出。" : text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color(red: 0.80, green: 0.94, blue: 0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .thinScrollBars()
        .frame(minHeight: minHeight)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.07),
                    Color(red: 0.07, green: 0.09, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.cyan.opacity(0.20))
        }
    }
}
