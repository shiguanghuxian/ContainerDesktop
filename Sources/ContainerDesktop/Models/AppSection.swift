import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case containers
    case images
    case volumes
    case networks
    case compose
    case registries
    case system

    var id: String { rawValue }

    var title: String {
        title(language: .system)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .dashboard: return language.t(.dashboard)
        case .containers: return language.t(.containers)
        case .images: return language.t(.images)
        case .volumes: return language.t(.volumes)
        case .networks: return language.t(.networks)
        case .compose: return language.t(.compose)
        case .registries: return language.t(.registries)
        case .system: return language.t(.system)
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .containers: return "shippingbox"
        case .images: return "photo.stack"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .compose: return "square.stack.3d.up"
        case .registries: return "key.icloud"
        case .system: return "gearshape.2"
        }
    }

    var subtitle: String {
        subtitle(language: .system)
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .dashboard: return language.t(.overview)
        case .containers: return language.t(.manageContainers)
        case .images: return language.t(.imageRegistry)
        case .volumes: return language.t(.storage)
        case .networks: return language.t(.virtualNetworks)
        case .compose: return language.t(.composeWorkflow)
        case .registries: return language.t(.registryLogins)
        case .system: return language.t(.engineConfig)
        }
    }
}
