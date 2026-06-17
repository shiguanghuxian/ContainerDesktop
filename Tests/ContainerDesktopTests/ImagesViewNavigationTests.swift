import Foundation
import Testing

@Suite("Images view navigation")
struct ImagesViewNavigationTests {
    @Test("image row opens detail while sidebar action opens drawer by entry")
    func imageRowOpensDetailWhileSidebarActionOpensDrawerByEntry() throws {
        let source = try imagesViewSource()

        let rowActionRange = try #require(source.range(of: "selectEntry(entry)"))
        let rowSnippetStart = source.index(rowActionRange.lowerBound, offsetBy: -80, limitedBy: source.startIndex) ?? source.startIndex
        let rowSnippetEnd = source.index(rowActionRange.upperBound, offsetBy: 80, limitedBy: source.endIndex) ?? source.endIndex
        let rowSnippet = String(source[rowSnippetStart..<rowSnippetEnd])
        #expect(rowSnippet.contains("Button {"))
        #expect(rowSnippet.contains("} label:"))

        let sidebarRange = try #require(source.range(of: "systemImage: \"sidebar.right\""))
        let sidebarSnippet = String(source[sidebarRange.lowerBound...].prefix(420))
        #expect(sidebarSnippet.contains("openEntryDrawer(entry)"))
        #expect(sidebarSnippet.contains("打开仓库 tag 概览抽屉"))
        #expect(!sidebarSnippet.contains("selectEntry(entry)"))
    }

    @Test("images view keeps task drawer separate from image overview drawer")
    func imagesViewKeepsTaskDrawerSeparateFromImageOverviewDrawer() throws {
        let source = try imagesViewSource()

        #expect(source.contains("private enum ImageDrawerSelection: Equatable"))
        #expect(source.contains("case tasks"))
        #expect(source.contains("case image(String)"))
        #expect(source.contains("case repositoryGroup(String)"))
        #expect(source.contains("private var drawerContent: some View"))
        #expect(source.contains("ImageTasksDrawer("))
        #expect(source.contains("DetailDrawer("))
        #expect(source.contains("ImageDrawerOverview(image: drawerImage)"))
        #expect(source.contains("ImageRepositoryGroupDrawerOverview(group: drawerRepositoryGroup)"))
        #expect(source.contains("rawText: imageRawSummary(drawerImage)"))
        #expect(source.contains("rawText: repositoryGroupRawSummary(drawerRepositoryGroup)"))
        #expect(source.contains("private var drawerWidth: CGFloat"))
        #expect(!source.contains("@State private var showTasksDrawer"))
    }

    @Test("images view has refresh and batch delete selection controls")
    func imagesViewHasRefreshAndBatchDeleteSelectionControls() throws {
        let source = try imagesViewSource()

        #expect(source.contains("@State private var selectedImageReferences = Set<String>()"))
        #expect(source.contains("private struct ImageDeleteRequest"))
        #expect(source.contains("refreshImages()"))
        #expect(source.contains("await runtimeStore.refreshAll()"))
        #expect(source.contains("Label(language.t(.refresh), systemImage: \"arrow.clockwise\")"))
        #expect(source.contains("filteredImagesSelectionButton"))
        #expect(source.contains("toggleFilteredImageSelection()"))
        #expect(source.contains("imageSelectionButton(for: entry)"))
        #expect(source.contains("confirmDeleteSelectedImages()"))
        #expect(source.contains("private var selectedExistingImageReferences: [String] {\n        filteredImageReferences"))
        #expect(source.contains("删除所选"))
        #expect(source.contains("runtimeStore.deleteImages(resolvedReferences)"))
        #expect(source.contains("selectedImageReferences.subtract(result.deletedReferences)"))
        #expect(source.contains("imageDeleteCommandPreview(for: resolvedReferences)"))
    }

    @Test("images view has registry filter controls")
    func imagesViewHasRegistryFilterControls() throws {
        let source = try imagesViewSource()

        #expect(source.contains("@State private var selectedRegistryFilter = ImageRegistryFilterOption.allID"))
        #expect(source.contains("ImageRegistryFilterOptions.make("))
        #expect(source.contains("$0.registryIdentity.id == selectedRegistryFilter"))
        #expect(source.contains("registryFilterMenuButton"))
        #expect(source.contains("registryFilterMenuItems"))
        #expect(source.contains("selectedRegistryFilter = ImageRegistryFilterOption.allID"))
        #expect(source.contains("selectedRegistryFilter = option.id"))
        #expect(source.contains("currentRegistryFilterTitle"))
        #expect(source.contains("全部注册中心"))
        #expect(source.contains("pruneSelectedRegistryFilter()"))
    }

    @Test("images view has display mode and grouped reference selection")
    func imagesViewHasDisplayModeAndGroupedReferenceSelection() throws {
        let source = try imagesViewSource()

        #expect(source.contains("@AppStorage(ImageListDisplayMode.defaultsKey, store: .containerDesktopShared)"))
        #expect(source.contains("toolbarFilterControls"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("displayModeMenuButton"))
        #expect(source.contains("compactFilterMenuButton"))
        #expect(source.contains("ImageToolbarMenuButton"))
        #expect(source.contains("imageListDisplayModeRaw = mode.rawValue"))
        #expect(source.contains(".frame(width: 220)"))
        #expect(source.contains(".frame(minWidth: 300, idealWidth: 340, maxWidth: 420)"))
        #expect(!source.contains(".frame(width: 140)"))
        #expect(!source.contains(".frame(width: 180)"))
        #expect(source.contains("ImageListEntry.make("))
        #expect(source.contains("ImageRepositoryGroup.make(images: registryFilteredImages)"))
        #expect(source.contains("referenceSelectionRequest"))
        #expect(source.contains("confirmationDialog("))
        #expect(source.contains("requestImageAction(.tag, for: entry)"))
        #expect(source.contains("requestImageAction(.delete, for: entry)"))
        #expect(source.contains("ImageRepositoryTagRow"))
    }

    private func imagesViewSource() throws -> String {
        try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Resources/ImagesView.swift",
            encoding: .utf8
        )
    }
}
