import SwiftUI

extension UserDefaults {
    nonisolated(unsafe) static let containerDesktopShared: UserDefaults = {
        let defaults = UserDefaults(suiteName: AppPaths.bundleIdentifier) ?? .standard
        for key in [
            "containerdesktop.appearance",
            "containerdesktop.language",
            "containerdesktop.dockerCompatibilityTerminal.style",
        ] where defaults.object(forKey: key) == nil {
            if let existingValue = UserDefaults.standard.object(forKey: key) {
                defaults.set(existingValue, forKey: key)
            }
        }
        return defaults
    }()
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .system: language.t(.themeSystem)
        case .light: language.t(.themeLight)
        case .dark: language.t(.themeDark)
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en

    var id: String { rawValue }

    static var resolvedSystem: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("zh") ? .zhHans : .en
    }

    var resolved: AppLanguage {
        self == .system ? Self.resolvedSystem : self
    }

    var displayName: String {
        switch self {
        case .system: "跟随系统 / System"
        case .zhHans: "简体中文"
        case .en: "English"
        }
    }

    func t(_ key: L10nKey) -> String {
        let language = resolved
        switch language {
        case .system:
            return Self.resolvedSystem.t(key)
        case .zhHans:
            return key.zh
        case .en:
            return key.en
        }
    }

    func itemCount(_ count: Int) -> String {
        resolved == .zhHans ? "显示 \(count) 项" : "Showing \(count) items"
    }
}

enum L10nKey {
    case appSubtitle
    case search
    case refresh
    case settings
    case openSettings
    case startSystem
    case stopSystem
    case engineRunning
    case engineStopped
    case containerMissing
    case systemNotRunning
    case running
    case noVersionInfo
    case cliMissing
    case systemStopped
    case dashboard
    case containers
    case machines
    case images
    case volumes
    case networks
    case compose
    case observability
    case registries
    case commandConverter
    case system
    case help
    case about
    case overview
    case manageContainers
    case manageMachines
    case imageRegistry
    case storage
    case virtualNetworks
    case composeWorkflow
    case observabilityWorkflow
    case registryLogins
    case commandConverterWorkflow
    case engineConfig
    case helpWorkflow
    case aboutWorkflow
    case localResources
    case workflows
    case admin
    case recentCompose
    case noComposeProjects
    case dashboardSubtitle
    case containersSubtitle
    case machinesSubtitle
    case imagesSubtitle
    case volumesSubtitle
    case networksSubtitle
    case composeSubtitle
    case observabilitySubtitle
    case registriesSubtitle
    case commandConverterSubtitle
    case systemSubtitle
    case helpSubtitle
    case aboutSubtitle
    case noContainers
    case noMachines
    case noImages
    case noVolumes
    case noNetworks
    case noRegistries
    case noCompose
    case pull
    case create
    case createMachine
    case delete
    case inspect
    case logs
    case name
    case status
    case image
    case tag
    case imageID
    case created
    case size
    case actions
    case details
    case theme
    case themeSystem
    case themeLight
    case themeDark
    case language
    case appPreferences
    case configSavedHint
    case filter
    case columns
    case onlyRunning
    case createVolume
    case createNetwork
    case volumeName
    case volumeSize
    case type
    case driver
    case source
    case mode
    case subnet
    case plugin
    case modified
    case services
    case commandOutput
    case addProject
    case reload
    case build
    case up
    case down
    case remove
    case defaults
    case save
    case configPath
    case environment
    case version
    case runtimeProperties
    case general
    case resources
    case networkSettings
    case kernel
    case runtime
    case appSettings
    case containerDefaults
    case builder
    case machine
    case homeMount
    case defaultMachine
    case emptyInstallCompose
    case loginInstructions
}

extension L10nKey {
    var zh: String {
        switch self {
        case .appSubtitle: "Apple container 控制台"
        case .search: "搜索"
        case .refresh: "刷新"
        case .settings: "设置"
        case .openSettings: "打开设置"
        case .startSystem: "启动 System"
        case .stopSystem: "停止 System"
        case .engineRunning: "Engine running"
        case .engineStopped: "Engine stopped"
        case .containerMissing: "container 未安装"
        case .systemNotRunning: "container system 未运行"
        case .running: "运行中"
        case .noVersionInfo: "暂无版本信息。"
        case .cliMissing: "CLI 缺失"
        case .systemStopped: "System 未启动"
        case .dashboard: "Dashboard"
        case .containers: "Containers"
        case .machines: "Machines"
        case .images: "Images"
        case .volumes: "Volumes"
        case .networks: "Networks"
        case .compose: "Compose"
        case .observability: "观测"
        case .registries: "Registries"
        case .commandConverter: "Docker 转换"
        case .system: "System"
        case .help: "帮助"
        case .about: "关于"
        case .overview: "概览"
        case .manageContainers: "运行与管理"
        case .manageMachines: "Linux 环境"
        case .imageRegistry: "镜像仓库"
        case .storage: "持久化存储"
        case .virtualNetworks: "虚拟网络"
        case .composeWorkflow: "多容器编排"
        case .observabilityWorkflow: "日志与资源"
        case .registryLogins: "镜像登录"
        case .commandConverterWorkflow: "迁移助手"
        case .engineConfig: "引擎与配置"
        case .helpWorkflow: "使用指南"
        case .aboutWorkflow: "应用信息"
        case .localResources: "本地资源"
        case .workflows: "工作流"
        case .admin: "管理"
        case .recentCompose: "最近 Compose"
        case .noComposeProjects: "尚未添加项目。"
        case .dashboardSubtitle: "查看本机容器运行时、资源和 Compose 状态。"
        case .containersSubtitle: "启动、停止、删除容器，查看日志和资源快照。"
        case .machinesSubtitle: "管理由 OCI 镜像创建的持久 Linux Machine。"
        case .imagesSubtitle: "拉取、检查、删除本地 OCI 镜像。"
        case .volumesSubtitle: "管理持久化数据卷和匿名卷。"
        case .networksSubtitle: "创建和检查 macOS 26+ 容器网络。"
        case .composeSubtitle: "通过 Container-Compose 管理多容器项目。"
        case .observabilitySubtitle: "集中查看容器日志、CPU、内存、网络和 I/O 快照。"
        case .registriesSubtitle: "查看和管理镜像仓库登录状态。"
        case .commandConverterSubtitle: "将常用 Docker 命令转换为 apple/container 命令，并快速复制迁移模板。"
        case .systemSubtitle: "管理 container system、版本、磁盘和默认配置。"
        case .helpSubtitle: "快速了解常用工作流、快捷入口和排障方法。"
        case .aboutSubtitle: "了解 \(AppBranding.displayName)、运行环境和项目能力边界。"
        case .noContainers: "没有容器"
        case .noMachines: "没有 Machine"
        case .noImages: "没有镜像"
        case .noVolumes: "没有存储卷"
        case .noNetworks: "没有网络"
        case .noRegistries: "没有登录的仓库"
        case .noCompose: "没有 Compose 项目"
        case .pull: "拉取"
        case .create: "创建"
        case .createMachine: "创建 Machine"
        case .delete: "删除"
        case .inspect: "详情"
        case .logs: "日志"
        case .name: "名称"
        case .status: "状态"
        case .image: "镜像"
        case .tag: "标签"
        case .imageID: "Image ID"
        case .created: "创建时间"
        case .size: "大小"
        case .actions: "操作"
        case .details: "详情"
        case .theme: "主题"
        case .themeSystem: "跟随系统"
        case .themeLight: "浅色"
        case .themeDark: "深色"
        case .language: "语言"
        case .appPreferences: "应用偏好"
        case .configSavedHint: "保存配置不会自动重启服务。执行 container system stop && container system start 后新配置生效。"
        case .filter: "筛选"
        case .columns: "列"
        case .onlyRunning: "仅运行中"
        case .createVolume: "创建卷"
        case .createNetwork: "创建网络"
        case .volumeName: "卷名称"
        case .volumeSize: "大小"
        case .type: "类型"
        case .driver: "驱动"
        case .source: "来源"
        case .mode: "模式"
        case .subnet: "子网"
        case .plugin: "插件"
        case .modified: "修改时间"
        case .services: "服务"
        case .commandOutput: "命令输出"
        case .addProject: "添加项目"
        case .reload: "重载"
        case .build: "构建"
        case .up: "启动"
        case .down: "停止"
        case .remove: "移除"
        case .defaults: "默认值"
        case .save: "保存"
        case .configPath: "配置路径"
        case .environment: "环境"
        case .version: "版本"
        case .runtimeProperties: "运行时属性"
        case .general: "通用"
        case .resources: "资源"
        case .networkSettings: "网络"
        case .kernel: "内核"
        case .runtime: "运行时"
        case .appSettings: "应用设置"
        case .containerDefaults: "容器默认值"
        case .builder: "构建器"
        case .machine: "虚拟机"
        case .homeMount: "Home 挂载"
        case .defaultMachine: "默认"
        case .emptyInstallCompose: "安装 container-compose 后才能运行 up、down 和 build。"
        case .loginInstructions: "登录说明"
        }
    }

    var en: String {
        switch self {
        case .appSubtitle: "Apple container console"
        case .search: "Search"
        case .refresh: "Refresh"
        case .settings: "Settings"
        case .openSettings: "Open Settings"
        case .startSystem: "Start System"
        case .stopSystem: "Stop System"
        case .engineRunning: "Engine running"
        case .engineStopped: "Engine stopped"
        case .containerMissing: "container missing"
        case .systemNotRunning: "container system stopped"
        case .running: "Running"
        case .noVersionInfo: "No version information."
        case .cliMissing: "CLI missing"
        case .systemStopped: "System stopped"
        case .dashboard: "Dashboard"
        case .containers: "Containers"
        case .machines: "Machines"
        case .images: "Images"
        case .volumes: "Volumes"
        case .networks: "Networks"
        case .compose: "Compose"
        case .observability: "Observe"
        case .registries: "Registries"
        case .commandConverter: "Docker Convert"
        case .system: "System"
        case .help: "Help"
        case .about: "About"
        case .overview: "Overview"
        case .manageContainers: "Run and manage"
        case .manageMachines: "Linux environments"
        case .imageRegistry: "Image registry"
        case .storage: "Persistent storage"
        case .virtualNetworks: "Virtual networks"
        case .composeWorkflow: "Multi-container apps"
        case .observabilityWorkflow: "Logs and metrics"
        case .registryLogins: "Registry logins"
        case .commandConverterWorkflow: "Migration helper"
        case .engineConfig: "Engine and config"
        case .helpWorkflow: "User guide"
        case .aboutWorkflow: "App info"
        case .localResources: "Local Resources"
        case .workflows: "Workflows"
        case .admin: "Admin"
        case .recentCompose: "Recent Compose"
        case .noComposeProjects: "No projects added."
        case .dashboardSubtitle: "Review local runtime, resources, and Compose status."
        case .containersSubtitle: "Start, stop, delete, inspect logs, and view resource snapshots."
        case .machinesSubtitle: "Manage persistent Linux machines created from OCI images."
        case .imagesSubtitle: "Pull, inspect, and remove local OCI images."
        case .volumesSubtitle: "Manage persistent and anonymous volumes."
        case .networksSubtitle: "Create and inspect macOS 26+ container networks."
        case .composeSubtitle: "Manage multi-container apps with Container-Compose."
        case .observabilitySubtitle: "Review container logs, CPU, memory, network, and I/O snapshots in one place."
        case .registriesSubtitle: "View and manage image registry logins."
        case .commandConverterSubtitle: "Convert common Docker commands to apple/container commands and copy migration templates quickly."
        case .systemSubtitle: "Manage system service, versions, disk usage, and defaults."
        case .helpSubtitle: "Learn common workflows, shortcuts, and troubleshooting paths."
        case .aboutSubtitle: "Review \(AppBranding.displayName), runtime environment, and product scope."
        case .noContainers: "No containers"
        case .noMachines: "No Machines"
        case .noImages: "No images"
        case .noVolumes: "No volumes"
        case .noNetworks: "No networks"
        case .noRegistries: "No registry logins"
        case .noCompose: "No Compose projects"
        case .pull: "Pull"
        case .create: "Create"
        case .createMachine: "Create Machine"
        case .delete: "Delete"
        case .inspect: "Inspect"
        case .logs: "Logs"
        case .name: "Name"
        case .status: "Status"
        case .image: "Image"
        case .tag: "Tag"
        case .imageID: "Image ID"
        case .created: "Created"
        case .size: "Size"
        case .actions: "Actions"
        case .details: "Details"
        case .theme: "Theme"
        case .themeSystem: "Use system setting"
        case .themeLight: "Light"
        case .themeDark: "Dark"
        case .language: "Language"
        case .appPreferences: "App Preferences"
        case .configSavedHint: "Saving config does not restart the service. Run container system stop && container system start for changes to take effect."
        case .filter: "Filter"
        case .columns: "Columns"
        case .onlyRunning: "Only running"
        case .createVolume: "Create Volume"
        case .createNetwork: "Create Network"
        case .volumeName: "Volume name"
        case .volumeSize: "Size"
        case .type: "Type"
        case .driver: "Driver"
        case .source: "Source"
        case .mode: "Mode"
        case .subnet: "Subnet"
        case .plugin: "Plugin"
        case .modified: "Modified"
        case .services: "Services"
        case .commandOutput: "Command Output"
        case .addProject: "Add Project"
        case .reload: "Reload"
        case .build: "Build"
        case .up: "Up"
        case .down: "Down"
        case .remove: "Remove"
        case .defaults: "Defaults"
        case .save: "Save"
        case .configPath: "Config Path"
        case .environment: "Environment"
        case .version: "Version"
        case .runtimeProperties: "Runtime Properties"
        case .general: "General"
        case .resources: "Resources"
        case .networkSettings: "Network"
        case .kernel: "Kernel"
        case .runtime: "Runtime"
        case .appSettings: "App Settings"
        case .containerDefaults: "Container Defaults"
        case .builder: "Builder"
        case .machine: "Machine"
        case .homeMount: "Home Mount"
        case .defaultMachine: "Default"
        case .emptyInstallCompose: "Install container-compose before running up, down, or build."
        case .loginInstructions: "Login Instructions"
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .system
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}
