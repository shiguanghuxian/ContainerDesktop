import Foundation
import Testing

@Suite("Images view navigation")
struct ImagesViewNavigationTests {
    @Test("image row opens detail while sidebar action opens drawer")
    func imageRowOpensDetailWhileSidebarActionOpensDrawer() throws {
        let source = try imagesViewSource()

        let selectImageCallCount = source.components(separatedBy: "selectImage(image)").count - 1
        #expect(selectImageCallCount == 1)

        let rowActionRange = try #require(source.range(of: "selectImage(image)"))
        let rowSnippetStart = source.index(rowActionRange.lowerBound, offsetBy: -80, limitedBy: source.startIndex) ?? source.startIndex
        let rowSnippetEnd = source.index(rowActionRange.upperBound, offsetBy: 80, limitedBy: source.endIndex) ?? source.endIndex
        let rowSnippet = String(source[rowSnippetStart..<rowSnippetEnd])
        #expect(rowSnippet.contains("Button {"))
        #expect(rowSnippet.contains("} label:"))

        let sidebarRange = try #require(source.range(of: "systemImage: \"sidebar.right\""))
        let sidebarSnippet = String(source[sidebarRange.lowerBound...].prefix(420))
        #expect(sidebarSnippet.contains("openImageDrawer(image)"))
        #expect(sidebarSnippet.contains("打开镜像概览抽屉"))
        #expect(!sidebarSnippet.contains("selectImage(image)"))
    }

    @Test("images view keeps task drawer separate from image overview drawer")
    func imagesViewKeepsTaskDrawerSeparateFromImageOverviewDrawer() throws {
        let source = try imagesViewSource()

        #expect(source.contains("private enum ImageDrawerSelection: Equatable"))
        #expect(source.contains("case tasks"))
        #expect(source.contains("case image(String)"))
        #expect(source.contains("private var drawerContent: some View"))
        #expect(source.contains("ImageTasksDrawer("))
        #expect(source.contains("DetailDrawer("))
        #expect(source.contains("ImageDrawerOverview(image: drawerImage)"))
        #expect(source.contains("rawText: imageRawSummary(drawerImage)"))
        #expect(source.contains("private var drawerWidth: CGFloat"))
        #expect(!source.contains("@State private var showTasksDrawer"))
    }

    private func imagesViewSource() throws -> String {
        try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Resources/ImagesView.swift",
            encoding: .utf8
        )
    }
}
