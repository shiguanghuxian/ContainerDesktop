import Foundation
import Testing

@Suite("Compose view navigation")
struct ComposeViewNavigationTests {
    @Test("compose project rows can reveal compose file folders")
    func composeProjectRowsCanRevealComposeFileFolders() throws {
        let source = try composeViewSource()

        #expect(source.contains("import AppKit"))
        #expect(source.contains("private let projectActionColumnWidth: CGFloat = 244"))
        #expect(source.contains("systemImage: \"folder\""))
        #expect(source.contains("openProjectFolder(project)"))
        #expect(source.contains("NSWorkspace.shared.activateFileViewerSelecting([project.path])"))
        #expect(source.contains("NSWorkspace.shared.open(folderURL)"))
        #expect(source.contains("找不到 Compose 文件所在文件夹"))
        #expect(source.contains("ResourceTableHeaderLabel(title: language.t(.actions), width: projectActionColumnWidth"))
        #expect(source.contains(".frame(width: projectActionColumnWidth, alignment: .trailing)"))
    }

    private func composeViewSource() throws -> String {
        try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Compose/ComposeView.swift",
            encoding: .utf8
        )
    }
}
