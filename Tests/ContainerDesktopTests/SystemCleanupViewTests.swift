import Foundation
import Testing

@Suite("System cleanup view")
struct SystemCleanupViewTests {
    @Test("system page wires cleanup plan into confirmation and runtime store")
    func systemPageWiresCleanupPlanIntoConfirmationAndRuntimeStore() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/System/SystemView.swift")

        #expect(source.contains("@State private var cleanupPlan = SystemCleanupPlan.safeDefault"))
        #expect(source.contains("cleanupConfirmationTitle"))
        #expect(source.contains("cleanupConfirmationMessage"))
        #expect(source.contains("Task { await runtimeStore.cleanupCache(plan: plan) }"))
        #expect(source.contains("plan: $cleanupPlan"))
        #expect(source.contains("cleanupPlan.includesVolumes"))
        #expect(source.contains("未使用卷"))
    }

    @Test("system page uses balanced dashboard sections")
    func systemPageUsesBalancedDashboardSections() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/System/SystemView.swift")

        #expect(source.contains("private var systemDashboardWideLayout: some View"))
        #expect(source.contains("private var systemDashboardTopRow: some View"))
        #expect(source.contains("private var systemDashboardMiddleRow: some View"))
        #expect(source.contains("private var systemDashboardBottomRow: some View"))
        #expect(source.contains("private var systemDashboardSingleColumnLayout: some View"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("systemDashboardTopRow"))
        #expect(source.contains("systemDashboardMiddleRow"))
        #expect(source.contains("systemDashboardBottomRow"))
        #expect(source.contains("environmentPanel"))
        #expect(source.contains("componentVersionsPanel"))
        #expect(source.contains("cleanupPanel"))
        #expect(source.contains("configPanel"))
        #expect(source.contains("runtimePropertiesPanel"))
        #expect(!source.contains("systemPanelMinimumColumnWidth"))
        #expect(!source.contains(".frame(minWidth: 640"))
    }

    @Test("system cards keep compact action and version controls")
    func systemCardsKeepCompactActionAndVersionControls() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/System/SystemView.swift")

        #expect(source.contains("PanelView(title: localized(\"组件版本\""))
        #expect(source.contains("} content: {"))
        #expect(source.contains("componentVersionHeaderControls"))
        #expect(source.contains("componentVersionExpandButton"))
        #expect(source.contains("componentVersionCheckButton"))
        #expect(source.contains("SystemActionPanel("))
        #expect(source.contains("StatusPill("))
        #expect(source.contains("Grid(alignment: .leading"))
    }

    @Test("cleanup panel exposes category selection controls and volume warning")
    func cleanupPanelExposesCategorySelectionControlsAndVolumeWarning() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/System/SystemCleanupPanel.swift")

        #expect(source.contains("cleanupWorkspace"))
        #expect(source.contains(".frame(width: 260"))
        #expect(source.contains("ForEach(SystemCleanupCategory.allCases)"))
        #expect(source.contains("SystemCleanupCategory.safeDefaults"))
        #expect(source.contains("Set(SystemCleanupCategory.allCases)"))
        #expect(source.contains("plan.categories = []"))
        #expect(source.contains("CleanupCategoryRow("))
        #expect(source.contains("category.isVolumeDestructive"))
        #expect(source.contains("category.commandPreview"))
        #expect(source.contains("plan.estimatedReclaimableDisplay(in: diskUsage)"))
        #expect(source.contains(".disabled(isRunning || !hasSelection)"))
    }

    @Test("about page describes explicit volume cleanup")
    func aboutPageDescribesExplicitVolumeCleanup() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/Support/AboutView.swift")

        #expect(source.contains("未使用卷需要用户手动勾选确认"))
        #expect(source.contains("unused volumes require an explicit user selection"))
    }

    private func readSource(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
