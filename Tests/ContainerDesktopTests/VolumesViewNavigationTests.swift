import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Volumes view navigation")
struct VolumesViewNavigationTests {
    @Test("volumes view exposes demo data sort filter and source copy affordances")
    func volumesViewExposesDemoDataSortFilterAndSourceCopyAffordances() throws {
        let source = try volumesViewSource()
        let overview = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeOverviewTabView.swift")

        #expect(source.contains("enum VolumeKindFilter"))
        #expect(source.contains("enum VolumeSortOption"))
        #expect(source.contains("runtimeStore.createDemoVolumes()"))
        #expect(overview.contains("CopyableVolumeSourceRow"))
        #expect(source.contains("复制测试命令"))
        #expect(source.contains("deleteReferenceHint(for:"))
        #expect(source.contains("Label(language.t(.refresh), systemImage: \"arrow.clockwise\")"))
        #expect(source.contains("await runtimeStore.refreshAll()"))
        #expect(source.contains("runtimeStore.isRefreshing"))
    }

    @Test("volume browser service supports container backed volume listing")
    func volumeBrowserServiceSupportsContainerBackedVolumeListing() throws {
        let source = try String(
            contentsOfFile: "Sources/ContainerDesktop/Services/VolumeBrowserService.swift",
            encoding: .utf8
        )

        #expect(source.contains("func list(volumeName: String, sourcePath: String"))
        #expect(source.contains("runSingleVolumeCommand(volumeName: volumeName"))
        #expect(source.contains("isHostBacked: false"))
        #expect(source.contains("func writeDemoFiles(volumeName: String, sourcePath: String)"))
    }

    @Test("volume row opens detail while sidebar action opens drawer")
    func volumeRowOpensDetailWhileSidebarActionOpensDrawer() throws {
        let source = try volumesViewSource()

        #expect(source.contains("@State private var detailName: String?"))
        #expect(source.contains("VolumeDetailPage("))
        #expect(source.contains("private func volumeRowMainButton(_ volume: VolumeSummary) -> some View"))
        #expect(source.contains("private func openVolumeDetail(_ volume: VolumeSummary, selectedTab: VolumeDetailTab = .overview)"))

        let rowButtonRange = try #require(source.range(of: "private func volumeRowMainButton"))
        let rowButtonSnippet = String(source[rowButtonRange.lowerBound...].prefix(1_300))
        #expect(rowButtonSnippet.contains("Button {"))
        #expect(rowButtonSnippet.contains("openVolumeDetail(volume)"))
        #expect(rowButtonSnippet.contains("Open volume details"))

        let folderRange = try #require(source.range(of: "打开本地卷文件夹"))
        let folderSnippet = String(source[folderRange.lowerBound...].prefix(360))
        #expect(folderSnippet.contains("openVolumeLocalFolder(volume)"))
        #expect(!folderSnippet.contains("openVolumeDetail(volume, selectedTab: .files)"))
        #expect(source.contains("private func openVolumeLocalFolder(_ volume: VolumeSummary)"))
        #expect(source.contains("NSWorkspace.shared.open(sourceURL)"))
        #expect(source.contains("sourceURL.deletingLastPathComponent()"))

        let sidebarRange = try #require(source.range(of: "systemImage: \"sidebar.right\""))
        let sidebarSnippet = String(source[sidebarRange.lowerBound...].prefix(420))
        #expect(sidebarSnippet.contains("selectVolume(volume)"))
        #expect(sidebarSnippet.contains("打开卷概览抽屉"))
        #expect(!sidebarSnippet.contains("openVolumeDetail(volume)"))
    }

    @Test("volume drawer stays lightweight and files live in detail page")
    func volumeDrawerStaysLightweightAndFilesLiveInDetailPage() throws {
        let source = try volumesViewSource()
        let files = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeFilesTabView.swift")

        #expect(source.contains("VolumeOverviewTabView(volume: selectedVolume)"))
        #expect(source.contains("VolumeMetadataTabView(volume: selectedVolume)"))
        #expect(!source.contains("VolumeDetailOverview("))
        #expect(!source.contains("VolumeFilesTabView("))
        #expect(files.contains("struct VolumeFilesTabView"))
        #expect(files.contains("@Bindable var browserStore: VolumeBrowserStore"))
        #expect(files.contains("真实卷内文件没有宿主机路径"))
        #expect(files.contains("卷内文件通过临时容器挂载读取和操作"))
        #expect(files.contains("docker.io/library/alpine:3.22"))
        #expect(files.contains("private var isFileActionDisabled"))
        #expect(files.contains("browserStore.isFileOperationRunning"))
        #expect(files.contains("isDisabled: isFileActionDisabled"))
        #expect(files.contains("VolumeFileRow("))
        #expect(files.contains("isDisabled: isFileActionDisabled"))
    }

    @Test("volume detail page contains header tabs files metadata and inspect")
    func volumeDetailPageStructure() throws {
        let page = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeDetailPage.swift")
        let header = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeDetailHeaderView.swift")
        let tabBar = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeDetailTabBar.swift")
        let overview = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeOverviewTabView.swift")
        let metadata = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeMetadataTabView.swift")
        let inspect = try readSource("Sources/ContainerDesktop/Views/Resources/VolumeDetail/VolumeInspectTabView.swift")

        #expect(VolumeDetailTab.allCases.contains(.files))
        #expect(page.contains("VolumeDetailHeaderView("))
        #expect(page.contains("VolumeDetailTabBar(selection: $detailStore.selectedTab)"))
        #expect(page.contains("VolumeOverviewTabView(volume: volume)"))
        #expect(page.contains("VolumeFilesTabView("))
        #expect(page.contains("VolumeMetadataTabView(volume: volume)"))
        #expect(page.contains("VolumeInspectTabView(store: detailStore)"))
        #expect(header.contains("SecondaryPageBackBar("))
        #expect(tabBar.contains("ForEach(VolumeDetailTab.allCases)"))
        #expect(overview.contains("不直接解析 volume.img"))
        #expect(metadata.contains("没有标签。"))
        #expect(inspect.contains("ReadOnlyMonospaceTextView("))
        #expect(inspect.contains("copy(store.visibleInspectText)"))
    }

    private func volumesViewSource() throws -> String {
        try readSource("Sources/ContainerDesktop/Views/Resources/VolumesView.swift")
    }

    private func readSource(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
