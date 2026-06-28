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

    @Test("compose view explains terminal auto registration")
    func composeViewExplainsTerminalAutoRegistration() throws {
        let source = try composeViewSource()

        #expect(source.contains("未启用兼容 shim 的普通系统终端创建或启动的 Compose 项目不会自动出现在这里"))
        #expect(source.contains("Docker 兼容终端和兼容系统终端中的 docker compose 命令会自动登记"))
        #expect(source.contains("regular system terminal without the compatibility shim do not appear here automatically"))
        #expect(source.contains("docker compose commands in the Docker Compatibility Terminal and compatible system terminals are registered automatically"))
        #expect(source.contains("StatusBanner(text: composeRegistrationHintText, systemImage: \"info.circle\""))
    }

    @Test("compose project delete offers project-only and container cleanup choices")
    func composeProjectDeleteOffersProjectOnlyAndContainerCleanupChoices() throws {
        let source = try composeViewSource()

        #expect(source.contains("Button(language.resolved == .zhHans ? \"仅移除项目\" : \"Remove project only\""))
        #expect(source.contains("composeRemoveWithContainersButtonTitle(count: matchedContainers.count)"))
        #expect(source.contains("removeComposeProjectOnly(project)"))
        #expect(source.contains("removeComposeProjectAndContainers(project)"))
        #expect(source.contains("composeMatchedContainers(for: project)"))
        #expect(source.contains("runtimeStore.stopContainers(runningContainerIDs)"))
        #expect(source.contains("runtimeStore.deleteContainers(containerIDs)"))
        #expect(source.contains("不会删除 compose 文件、容器、镜像、卷或网络"))
        #expect(source.contains("删除 Compose 项目 \\(project.name) 已中止"))
        #expect(source.contains("cleanupRemovedComposeProject(project)"))
    }

    private func composeViewSource() throws -> String {
        try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Compose/ComposeView.swift",
            encoding: .utf8
        )
    }
}
