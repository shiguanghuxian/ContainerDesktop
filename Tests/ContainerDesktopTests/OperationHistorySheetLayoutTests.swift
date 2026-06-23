import Foundation
import Testing

@Suite("Operation history sheet layout")
struct OperationHistorySheetLayoutTests {
    @Test("sheet keeps close header fixed and history scrollable")
    func sheetKeepsCloseHeaderFixedAndHistoryScrollable() throws {
        let content = try source("Sources/ContainerDesktop/Views/ContentView.swift")
        let drawer = try source("Sources/ContainerDesktop/Views/Common/DetailDrawer.swift")
        let sheet = try section(
            in: content,
            from: "private struct OperationHistorySheet",
            to: "\n}"
        )

        #expect(sheet.contains("DrawerHeader("))
        #expect(sheet.contains("onClose: { dismiss() }"))
        #expect(sheet.contains("Divider()"))
        #expect(sheet.contains("ScrollView {"))
        #expect(sheet.contains("OperationHistoryPanel("))
        #expect(sheet.contains(".thinScrollBars()"))
        #expect(sheet.contains(".frame(maxHeight: .infinity)"))

        #expect(drawer.contains("DrawerCloseButton(action: onClose)"))
        #expect(drawer.contains(".keyboardShortcut(.escape, modifiers: [])"))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    private func section(in source: String, from startMarker: String, to endMarker: String) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(source[start.upperBound...].range(of: endMarker))
        return String(source[start.lowerBound..<end.upperBound])
    }
}
