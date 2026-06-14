import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
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

    var id: String { rawValue }

    var title: String {
        title(language: .system)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .dashboard: return language.t(.dashboard)
        case .containers: return language.t(.containers)
        case .machines: return language.t(.machines)
        case .images: return language.t(.images)
        case .volumes: return language.t(.volumes)
        case .networks: return language.t(.networks)
        case .compose: return language.t(.compose)
        case .observability: return language.t(.observability)
        case .registries: return language.t(.registries)
        case .commandConverter: return language.t(.commandConverter)
        case .system: return language.t(.system)
        case .help: return language.t(.help)
        case .about: return language.t(.about)
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .containers: return "shippingbox"
        case .machines: return "desktopcomputer"
        case .images: return "photo.stack"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .compose: return "square.stack.3d.up"
        case .observability: return "waveform.path.ecg"
        case .registries: return "key.icloud"
        case .commandConverter: return "arrow.left.arrow.right.square"
        case .system: return "gearshape.2"
        case .help: return "questionmark.circle"
        case .about: return "info.circle"
        }
    }

    var subtitle: String {
        subtitle(language: .system)
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .dashboard: return language.t(.overview)
        case .containers: return language.t(.manageContainers)
        case .machines: return language.t(.manageMachines)
        case .images: return language.t(.imageRegistry)
        case .volumes: return language.t(.storage)
        case .networks: return language.t(.virtualNetworks)
        case .compose: return language.t(.composeWorkflow)
        case .observability: return language.t(.observabilityWorkflow)
        case .registries: return language.t(.registryLogins)
        case .commandConverter: return language.t(.commandConverterWorkflow)
        case .system: return language.t(.engineConfig)
        case .help: return language.t(.helpWorkflow)
        case .about: return language.t(.aboutWorkflow)
        }
    }
}
