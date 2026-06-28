import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Code file editor")
struct CodeFileEditorViewTests {
    @Test("file names infer CodeEditorView language configurations")
    func fileNamesInferCodeEditorViewLanguageConfigurations() {
        assertLanguage("Dockerfile", language: .dockerfile, configurationName: "Dockerfile")
        assertLanguage("/tmp/app/Dockerfile.dev", language: .dockerfile, configurationName: "Dockerfile")
        assertLanguage("app.py", language: .python, configurationName: "Python")
        assertLanguage("entrypoint.sh", language: .bash, configurationName: "Shell")
        assertLanguage("compose.yaml", language: .yaml, configurationName: "YAML")
        assertLanguage("config.json", language: .json, configurationName: "JSON")
        assertLanguage("config.toml", language: .toml, configurationName: "TOML")
        assertLanguage("main.swift", language: .swift, configurationName: "Swift")
        assertLanguage("web/app.tsx", language: .tsx, configurationName: "TSX")
        assertLanguage("script.jsx", language: .jsx, configurationName: "JSX")
        assertLanguage("go.mod", language: .goMod, configurationName: "Go Module")
        assertLanguage("query.sql", language: .sql, configurationName: "SQLite")
        assertLanguage("unknown.containerdesktop", language: .plainText, configurationName: "Text")
    }

    @Test("unknown file types keep plain text content path")
    func unknownFileTypesKeepPlainTextContentPath() {
        let language = CodeFileEditorLanguage.language(for: "notes.containerdesktop")
        let configuration = language.languageConfiguration

        #expect(language == .plainText)
        #expect(configuration.name == "Text")
        #expect(configuration.reservedIdentifiers.isEmpty)
    }

    @Test("preview panel uses SwiftUI CodeEditorView editor")
    func previewPanelUsesSwiftUICodeEditorViewEditor() throws {
        let editorSource = try readSource(
            "Sources/ContainerDesktop/Views/Resources/ContainerDetail/CodeFileEditorView.swift"
        )
        let panelSource = try readSource(
            "Sources/ContainerDesktop/Views/Resources/ContainerDetail/MonospaceTextViews.swift"
        )

        #expect(editorSource.contains("import CodeEditorView"))
        #expect(editorSource.contains("import LanguageSupport"))
        #expect(editorSource.contains("struct CodeFileEditorView: View"))
        #expect(editorSource.contains("@Environment(\\.colorScheme)"))
        #expect(editorSource.contains("CodeEditor("))
        #expect(editorSource.contains("CodeEditor.Position()"))
        #expect(editorSource.contains("Set<TextLocated<Message>>()"))
        #expect(editorSource.contains("language: language.languageConfiguration"))
        #expect(editorSource.contains("\\.codeEditorTheme"))
        #expect(editorSource.contains("\\.codeEditorLayoutConfiguration"))
        #expect(editorSource.contains("CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: wrapsLines)"))
        #expect(editorSource.contains("\\.codeEditorIndentationConfiguration"))
        #expect(editorSource.contains("CodeFileEditorEditabilityBridge(isEditable: isEditable)"))
        #expect(editorSource.contains("text.isEditable = isEditable"))
        #expect(editorSource.contains("text.isSelectable = true"))
        #expect(panelSource.contains("CodeFileEditorView("))
        #expect(panelSource.contains("fileName: fileName ?? title"))

        #expect(!editorSource.contains("import Highlighter"))
        #expect(!editorSource.contains("NSTextView"))
        #expect(!editorSource.contains("NSRulerView"))
        #expect(!editorSource.contains("CodeEditorLineNumberRulerView"))
        #expect(!editorSource.contains("CodeSyntaxHighlighter"))
        #expect(!editorSource.contains("WKWebView"))
        #expect(!editorSource.contains("CodeMirror"))
    }

    @Test("package uses CodeEditorView and removes HighlighterSwift")
    func packageUsesCodeEditorViewAndRemovesHighlighterSwift() throws {
        let packageSource = try readSource("Package.swift")

        #expect(packageSource.contains("https://github.com/mchakravarty/CodeEditorView.git"))
        #expect(packageSource.contains("exact: \"0.15.4\""))
        #expect(packageSource.contains(".product(name: \"CodeEditorView\", package: \"CodeEditorView\")"))
        #expect(packageSource.contains(".product(name: \"LanguageSupport\", package: \"CodeEditorView\")"))
        #expect(!packageSource.contains("HighlighterSwift"))
        #expect(!packageSource.contains(".product(name: \"Highlighter\""))
        #expect(!packageSource.contains("CodeEditSourceEditor"))
        #expect(!packageSource.contains("CodeEditLanguages"))
    }

    @Test("container machine and volume keep shared preview panel wiring")
    func detailFilePagesKeepSharedPreviewPanelWiring() throws {
        let container = try readSource(
            "Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerFilesTabView.swift"
        )
        let machine = try readSource(
            "Sources/ContainerDesktop/Views/Resources/MachineDetail/MachineFilesTabView.swift"
        )
        let volume = try readSource(
            "Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeFilesTabView.swift"
        )

        #expect(container.contains("FilePreviewCodePanel("))
        #expect(container.contains("fileName: selectedFile.path"))
        #expect(container.contains("FileBrowserFolderInfoPanel("))
        #expect(container.contains("if let selectedFile = store.selectedFile, !selectedFile.isDirectory"))
        #expect(container.contains("path: store.filePath"))
        #expect(container.contains("entries: store.fileEntries"))
        #expect(container.contains("isEditable: true"))
        #expect(container.contains("store.saveSelectedFile()"))
        #expect(machine.contains("FilePreviewCodePanel("))
        #expect(machine.contains("fileName: selectedFile.path"))
        #expect(machine.contains("FileBrowserFolderInfoPanel("))
        #expect(machine.contains("if let selectedFile = store.selectedFile, !selectedFile.isDirectory"))
        #expect(machine.contains("path: store.filePath"))
        #expect(machine.contains("entries: store.fileEntries"))
        #expect(machine.contains("isEditable: store.isSelectedFileEditable"))
        #expect(volume.contains("FilePreviewCodePanel("))
        #expect(volume.contains("fileName: selectedFile.url.path"))
        #expect(volume.contains("FileBrowserFolderInfoPanel("))
        #expect(volume.contains("if let selectedFile = browserStore.selectedFile, !selectedFile.isDirectory"))
        #expect(volume.contains("path: browserStore.snapshot?.displayPath ?? \"/\""))
        #expect(volume.contains("entries: browserStore.snapshot?.entries ?? []"))
        #expect(volume.contains("isEditable: false"))
    }

    @Test("folder info counts container entries and visible file bytes")
    func folderInfoCountsContainerEntriesAndVisibleFileBytes() {
        let info = FileBrowserFolderInfo(
            path: "/app",
            entries: [
                containerEntry(name: "config", kind: .directory, size: 4_096),
                containerEntry(name: "main.swift", kind: .regularFile, size: 120),
                containerEntry(name: "current", kind: .symlink, size: 8),
            ]
        )

        #expect(info.path == "/app")
        #expect(info.totalCount == 3)
        #expect(info.directoryCount == 1)
        #expect(info.fileCount == 2)
        #expect(info.visibleFileBytes == 128)
    }

    @Test("folder info supports empty volume directories")
    func folderInfoSupportsEmptyVolumeDirectories() {
        let info = FileBrowserFolderInfo(path: "/", entries: [VolumeFileEntry]())

        #expect(info.path == "/")
        #expect(info.totalCount == 0)
        #expect(info.directoryCount == 0)
        #expect(info.fileCount == 0)
        #expect(info.visibleFileBytes == 0)
    }

    @Test("folder info counts volume entries without recursive directory sizes")
    func folderInfoCountsVolumeEntriesWithoutRecursiveDirectorySizes() {
        let info = FileBrowserFolderInfo(
            path: "/data",
            entries: [
                volumeEntry(name: "logs", isDirectory: true, size: 9_999),
                volumeEntry(name: "app.log", isDirectory: false, size: 2_048),
                volumeEntry(name: "README.md", isDirectory: false, size: nil),
            ],
            sourceText: "Host-backed directory"
        )

        #expect(info.totalCount == 3)
        #expect(info.directoryCount == 1)
        #expect(info.fileCount == 2)
        #expect(info.visibleFileBytes == 2_048)
        #expect(info.sourceText == "Host-backed directory")
    }

    private func assertLanguage(
        _ fileName: String,
        language expectedLanguage: CodeFileEditorLanguage,
        configurationName expectedConfigurationName: String
    ) {
        let language = CodeFileEditorLanguage.language(for: fileName)

        #expect(language == expectedLanguage)
        #expect(language.languageConfiguration.name == expectedConfigurationName)
    }

    private func readSource(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    private func containerEntry(
        name: String,
        kind: ContainerFileKind,
        size: Int64
    ) -> ContainerFileEntry {
        ContainerFileEntry(
            name: name,
            path: "/app/\(name)",
            kind: kind,
            mode: kind == .directory ? "drwxr-xr-x" : "-rw-r--r--",
            owner: "root",
            group: "root",
            size: size,
            modifiedAt: nil,
            linkTarget: nil
        )
    }

    private func volumeEntry(
        name: String,
        isDirectory: Bool,
        size: Int64?
    ) -> VolumeFileEntry {
        VolumeFileEntry(
            name: name,
            url: URL(fileURLWithPath: "/data/\(name)", isDirectory: isDirectory),
            isDirectory: isDirectory,
            size: size,
            modifiedAt: nil,
            isHostBacked: true
        )
    }
}
