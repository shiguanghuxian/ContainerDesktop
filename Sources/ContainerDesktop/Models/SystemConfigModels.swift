import Foundation
import TOMLKit

struct SystemConfig: Codable, Hashable, Sendable {
    struct Build: Codable, Hashable, Sendable {
        var rosetta: Bool
        var cpus: Int
        var memory: String
        var image: String

        init(rosetta: Bool = true, cpus: Int = 2, memory: String = "2048mb", image: String = "ghcr.io/apple/container-builder-shim/builder:latest") {
            self.rosetta = rosetta
            self.cpus = cpus
            self.memory = memory
            self.image = image
        }
    }

    struct Container: Codable, Hashable, Sendable {
        var cpus: Int
        var memory: String

        init(cpus: Int = 4, memory: String = "1g") {
            self.cpus = cpus
            self.memory = memory
        }
    }

    struct DNS: Codable, Hashable, Sendable {
        var domain: String?
    }

    struct Kernel: Codable, Hashable, Sendable {
        var binaryPath: String
        var url: String

        init(binaryPath: String = "opt/kata/share/kata-containers/vmlinux-6.18.15-186", url: String = "https://github.com/kata-containers/kata-containers/releases/download/3.28.0/kata-static-3.28.0-arm64.tar.zst") {
            self.binaryPath = binaryPath
            self.url = url
        }
    }

    struct Machine: Codable, Hashable, Sendable {
        var cpus: Int?
        var memory: String?
        var homeMount: String?

        init(cpus: Int? = nil, memory: String? = nil, homeMount: String? = nil) {
            self.cpus = cpus
            self.memory = memory
            self.homeMount = homeMount
        }
    }

    struct Network: Codable, Hashable, Sendable {
        var subnet: String?
        var subnetv6: String?
    }

    struct Registry: Codable, Hashable, Sendable {
        var domain: String

        init(domain: String = "docker.io") {
            self.domain = domain
        }
    }

    struct Vminit: Codable, Hashable, Sendable {
        var image: String

        init(image: String = "ghcr.io/apple/containerization/vminit:latest") {
            self.image = image
        }
    }

    var build: Build
    var container: Container
    var dns: DNS
    var kernel: Kernel
    var machine: Machine
    var network: Network
    var registry: Registry
    var vminit: Vminit

    init(
        build: Build = .init(),
        container: Container = .init(),
        dns: DNS = .init(),
        kernel: Kernel = .init(),
        machine: Machine = .init(),
        network: Network = .init(),
        registry: Registry = .init(),
        vminit: Vminit = .init()
    ) {
        self.build = build
        self.container = container
        self.dns = dns
        self.kernel = kernel
        self.machine = machine
        self.network = network
        self.registry = registry
        self.vminit = vminit
    }

    enum CodingKeys: String, CodingKey {
        case build, container, dns, kernel, machine, network, registry, vminit
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        build = try container.decodeIfPresent(Build.self, forKey: .build) ?? .init()
        self.container = try container.decodeIfPresent(Container.self, forKey: .container) ?? .init()
        dns = try container.decodeIfPresent(DNS.self, forKey: .dns) ?? .init()
        kernel = try container.decodeIfPresent(Kernel.self, forKey: .kernel) ?? .init()
        machine = try container.decodeIfPresent(Machine.self, forKey: .machine) ?? .init()
        network = try container.decodeIfPresent(Network.self, forKey: .network) ?? .init()
        registry = try container.decodeIfPresent(Registry.self, forKey: .registry) ?? .init()
        vminit = try container.decodeIfPresent(Vminit.self, forKey: .vminit) ?? .init()
    }
}

extension SystemConfig {
    static let defaultFileText = """
    [build]
    rosetta = true
    cpus = 2
    memory = "2048mb"

    [container]
    cpus = 4
    memory = "1g"

    [registry]
    domain = "docker.io"
    """
}
