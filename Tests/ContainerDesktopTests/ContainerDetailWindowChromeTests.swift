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
        #expect(appSource.contains("private static let mainWindowTitle = AppBranding.displayName"))
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
        #expect(chromeSource.contains("Text(AppBranding.displayName)"))
        #expect(chromeSource.contains(".frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .center)"))
        #expect(chromeSource.contains(".frame(maxWidth: .infinity, minHeight: 52, idealHeight: 52, maxHeight: 52, alignment: .leading)"))
        #expect(chromeSource.contains("CDTheme.dockerBlue"))
        #expect(!chromeSource.contains(".padding(.top, 8)"))
        #expect(!contentSource.contains("TechBackdrop().ignoresSafeArea()"))
        #expect(contentSource.contains("TechBackdrop()"))
    }

    @Test("custom drag regions support double click window zoom")
    func customDragRegionsSupportDoubleClickWindowZoom() throws {
        let helperSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Common/WindowDragZoomRegion.swift",
            encoding: .utf8
        )
        let chromeSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/AppChrome.swift",
            encoding: .utf8
        )
        let terminalTabsSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/DockerCompatibilityTerminal/DockerCompatibilityTerminalTabsView.swift",
            encoding: .utf8
        )

        #expect(helperSource.contains("struct WindowDragZoomRegion"))
        #expect(helperSource.contains("WindowDragGesture()"))
        #expect(helperSource.contains(".allowsWindowActivationEvents(true)"))
        #expect(helperSource.contains("performZoom(nil)"))
        #expect(chromeSource.contains("WindowDragZoomRegion()"))
        #expect(!chromeSource.contains(".simultaneousGesture(WindowDragGesture())"))
        #expect(terminalTabsSource.contains("private var dragRegion: some View {\n        WindowDragZoomRegion()"))
        #expect(!terminalTabsSource.contains(".gesture(WindowDragGesture())"))

        let tabItemStart = try #require(terminalTabsSource.range(of: "private func tabItem"))
        let addTabButtonStart = try #require(terminalTabsSource.range(of: "private var addTabButton"))
        let dragRegionStart = try #require(terminalTabsSource.range(of: "private var dragRegion"))
        let tabItemSource = String(terminalTabsSource[tabItemStart.lowerBound..<addTabButtonStart.lowerBound])
        let addTabButtonSource = String(terminalTabsSource[addTabButtonStart.lowerBound..<dragRegionStart.lowerBound])
        #expect(!tabItemSource.contains("WindowDragZoomRegion"))
        #expect(!addTabButtonSource.contains("WindowDragZoomRegion"))
    }

    @Test("runtime operation feedback uses centered snackbar")
    func runtimeOperationFeedbackUsesCenteredSnackbar() throws {
        let contentSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/ContentView.swift",
            encoding: .utf8
        )
        let toastSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Common/OperationToast.swift",
            encoding: .utf8
        )

        #expect(contentSource.contains(".overlay(alignment: .bottom)"))
        #expect(contentSource.contains("OperationToast(feedback: feedback)"))
        #expect(contentSource.contains("runtimeStore.dismissOperationFeedback()"))
        #expect(contentSource.contains(".padding(.bottom, 46)"))
        #expect(!contentSource.contains(".overlay(alignment: .bottomLeading)"))
        #expect(!contentSource.contains("StatusPill(title: busyMessage"))
        #expect(toastSource.contains("minWidth: 360"))
        #expect(toastSource.contains("ProgressView()"))
        #expect(toastSource.contains("操作完成"))
        #expect(toastSource.contains("操作失败"))
    }
}
