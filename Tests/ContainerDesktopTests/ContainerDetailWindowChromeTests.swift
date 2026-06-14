import Testing

@Suite("Container detail window chrome")
struct ContainerDetailWindowChromeTests {
    @Test("main window uses stable hidden title chrome")
    func mainWindowUsesStableHiddenTitleChrome() throws {
        let appSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift",
            encoding: .utf8
        )

        #expect(appSource.contains("applyMainWindowChrome"))
        #expect(appSource.contains("hostingController.sizingOptions = []"))
        #expect(appSource.contains("mainHostingController?.sizingOptions = []"))
        #expect(appSource.contains("window.title = \"\""))
        #expect(appSource.contains("window.setAccessibilityTitle(Self.mainWindowTitle)"))
        #expect(appSource.contains("window.titleVisibility = .hidden"))
        #expect(appSource.contains("window.titlebarAppearsTransparent = true"))
        #expect(appSource.contains("window.toolbarStyle = .unifiedCompact"))
        #expect(appSource.contains("window.titlebarSeparatorStyle = .none"))
        #expect(appSource.contains("window.toolbar = nil"))
        #expect(!appSource.contains("NSToolbar(identifier: Self.mainToolbarIdentifier)"))
    }

    @Test("container detail files layout does not force a wide window")
    func containerDetailFilesLayoutDoesNotForceWideWindow() throws {
        let filesSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerFilesTabView.swift",
            encoding: .utf8
        )
        let headerSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerDetailHeaderView.swift",
            encoding: .utf8
        )

        #expect(!filesSource.contains(".frame(minWidth: 640"))
        #expect(!filesSource.contains(".frame(width: 400"))
        #expect(filesSource.contains("responsiveFileBrowser"))
        #expect(filesSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(headerSource.contains("GridItem(.adaptive(minimum: 170"))
        #expect(headerSource.contains("ViewThatFits(in: .horizontal)"))
    }

    @Test("top bar remains full width above detail content")
    func topBarRemainsFullWidthAboveDetailContent() throws {
        let chromeSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/AppChrome.swift",
            encoding: .utf8
        )
        let contentSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/ContentView.swift",
            encoding: .utf8
        )

        #expect(chromeSource.contains("ZStack(alignment: .bottomLeading)"))
        #expect(chromeSource.contains(".frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .center)"))
        #expect(chromeSource.contains(".frame(maxWidth: .infinity, minHeight: 52, idealHeight: 52, maxHeight: 52, alignment: .leading)"))
        #expect(chromeSource.contains("CDTheme.dockerBlue"))
        #expect(!chromeSource.contains(".padding(.top, 8)"))
        #expect(!contentSource.contains("TechBackdrop().ignoresSafeArea()"))
        #expect(contentSource.contains("TechBackdrop()"))
    }
}
