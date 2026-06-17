enum DockerCompatibilityTerminalStrings {
    static func windowTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "Docker 兼容终端" : "Docker Compatibility Terminal"
    }

    static func settingsWindowTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端设置" : "Terminal Settings"
    }

    static func settingsHeaderSubtitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "调整终端语言和外观。" : "Adjust the terminal language and appearance."
    }

    static func settingsMenuTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端设置…" : "Terminal Settings..."
    }

    static func openMainApp(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "打开主应用" : "Open Main App"
    }

    static func quitTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "退出 Docker 兼容终端" : "Quit Docker Compatibility Terminal"
    }

    static func editMenuTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "编辑" : "Edit"
    }

    static func shellMenuTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "Shell" : "Shell"
    }

    static func newTab(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "新建 Tab" : "New Tab"
    }

    static func closeTab(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "关闭 Tab" : "Close Tab"
    }

    static func nextTab(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "下一个 Tab" : "Next Tab"
    }

    static func previousTab(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "上一个 Tab" : "Previous Tab"
    }

    static func copy(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "复制" : "Copy"
    }

    static func paste(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "粘贴" : "Paste"
    }

    static func selectAll(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "全选" : "Select All"
    }

    static func clearSelection(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "取消选择" : "Clear Selection"
    }

    static func routeDescription(_ language: AppLanguage) -> String {
        language.resolved == .zhHans
            ? "此窗口内的 docker/docker-compose 会自动转到 container/container-compose"
            : "docker/docker-compose in this window route to container/container-compose"
    }

    static func copyShimPath(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "复制 shim PATH" : "Copy shim PATH"
    }

    static func clearTerminal(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "清屏" : "Clear"
    }

    static func restartTerminal(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "重启终端" : "Restart terminal"
    }

    static func disconnect(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "断开" : "Disconnect"
    }

    static func terminalSettings(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端设置" : "Terminal settings"
    }

    static func traceTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "日志" : "Trace"
    }

    static func traceHelp(_ language: AppLanguage) -> String {
        language.resolved == .zhHans
            ? "重连后显示每次 docker 到 container 的转换"
            : "Reconnect to print each docker to container conversion"
    }

    static func disconnectedStatus(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "已断开" : "Disconnected"
    }

    static func connectingStatus(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "连接中" : "Connecting"
    }

    static func connectedStatus(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "已连接" : "Connected"
    }

    static func failedStatus(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "失败" : "Failed"
    }

    static func disconnectedTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端已断开" : "Terminal disconnected"
    }

    static func disconnectedMessage(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "点击连接重新创建兼容终端。" : "Connect to create a new compatibility terminal."
    }

    static func connect(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "连接" : "Connect"
    }

    static func failedTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端启动失败" : "Terminal failed"
    }

    static func reconnect(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "重新连接" : "Reconnect"
    }

    static func expandControls(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "展开终端控制" : "Expand terminal controls"
    }

    static func collapseControls(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "收起终端控制" : "Collapse terminal controls"
    }

    static func invalidServiceSelection(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "请选择一个文件夹或文件。" : "Select a folder or file."
    }

    static func openTerminalHelp(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "打开 Docker 兼容终端" : "Open Docker compatibility terminal"
    }

    static func languageTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "语言" : "Language"
    }

    static func languageSubtitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端界面语言" : "Terminal interface language"
    }

    static func styleSectionTitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "终端样式" : "Terminal styles"
    }

    static func styleSectionSubtitle(_ language: AppLanguage) -> String {
        language.resolved == .zhHans ? "仅影响 Docker 兼容终端窗口。" : "Only affects the Docker compatibility terminal window."
    }
}
