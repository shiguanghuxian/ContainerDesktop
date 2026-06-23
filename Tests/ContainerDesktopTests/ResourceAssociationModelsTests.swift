import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Resource associations")
struct ResourceAssociationModelsTests {
    @Test("container associations connect image compose volumes networks ports and operations")
    func containerAssociationsConnectResources() {
        let container = Self.makeContainer(
            id: "demo-web-1",
            imageName: "docker.io/library/nginx:latest",
            labels: [
                "com.docker.compose.project": "demo",
                "com.docker.compose.service": "web",
            ]
        )
        let inspect = """
        {
          "Mounts": [
            { "Type": "volume", "Name": "web-data", "Destination": "/usr/share/nginx/html" }
          ],
          "NetworkSettings": {
            "Networks": {
              "demo-net": {}
            }
          },
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" }
            ]
          }
        }
        """
        let operation = AppOperationRecord(
            id: UUID(),
            domain: .container,
            title: "Restart",
            target: "demo-web-1",
            commandPreview: "container stop demo-web-1 && container start demo-web-1",
            status: .failed,
            output: "failed",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            finishedAt: Date(timeIntervalSince1970: 1_700_000_003)
        )

        let associations = ContainerResourceAssociations.make(
            container: container,
            inspectText: inspect,
            images: [Self.makeImage(reference: container.imageName)],
            volumes: [Self.makeVolume(name: "web-data")],
            networks: [Self.makeNetwork(name: "demo-net")],
            composeProjects: [Self.makeComposeProject()],
            browserPortTargets: ContainerBrowserPortTarget.targets(from: inspect, container: container),
            operations: [operation],
            language: .zhHans
        )

        #expect(associations.sections.map(\.id).contains("image"))
        #expect(associations.sections.map(\.id).contains("compose"))
        #expect(associations.sections.map(\.id).contains("volumes"))
        #expect(associations.sections.map(\.id).contains("networks"))
        #expect(associations.sections.map(\.id).contains("ports"))
        #expect(associations.sections.map(\.id).contains("operations"))
        #expect(associations.sections.flatMap(\.items).contains {
            $0.action == .route(.volume(name: "web-data", tab: nil))
        })
        #expect(associations.sections.flatMap(\.items).contains {
            $0.action == .route(.network(name: "demo-net", tab: nil))
        })
        #expect(associations.sections.flatMap(\.items).contains {
            $0.action == .copy("http://127.0.0.1:8080")
        })
    }

    @Test("image and volume associations expose in-use and file shortcuts")
    func imageAndVolumeAssociationsExposeShortcuts() {
        let image = Self.makeImage(reference: "docker.io/library/redis:7")
        let container = Self.makeContainer(id: "redis-dev", imageName: image.reference, labels: [:])
        let imageAssociations = ImageResourceAssociations.make(
            image: image,
            containers: [container],
            operations: [],
            language: .en
        )

        #expect(imageAssociations.sections.first(where: { $0.id == "containers" })?.items.first?.action == .route(.container(id: "redis-dev", tab: nil)))
        #expect(imageAssociations.sections.first(where: { $0.id == "copy" })?.items.contains {
            $0.action == .copy("docker.io/library/redis:7")
        } == true)

        let volume = Self.makeVolume(name: "redis-data")
        let volumeAssociations = VolumeResourceAssociations.make(
            volume: volume,
            operations: [],
            language: .zhHans
        )

        #expect(volumeAssociations.sections.first?.items.contains {
            $0.action == .route(.volume(name: "redis-data", tab: .files))
        } == true)
        #expect(volumeAssociations.sections.first?.items.contains {
            $0.action == .copy(volume.source)
        } == true)
    }

    private static func makeContainer(
        id: String,
        imageName: String,
        labels: [String: String]
    ) -> ContainerSummary {
        ContainerSummary(
            configuration: .init(
                id: id,
                image: .init(reference: imageName),
                platform: .init(os: "linux", architecture: "arm64"),
                resources: .init(cpus: 1, memoryInBytes: 536_870_912),
                creationDate: nil,
                labels: labels
            ),
            status: .init(
                state: "running",
                networks: [.init(ipv4Address: "192.168.64.20")],
                startedDate: nil
            )
        )
    }

    private static func makeImage(reference: String) -> ImageSummary {
        ImageSummary(
            configuration: .init(
                name: reference,
                creationDate: nil,
                descriptor: .init(digest: "sha256:image")
            ),
            variants: [
                .init(
                    platform: .init(os: "linux", architecture: "arm64", variant: nil),
                    digest: "sha256:variant",
                    size: 2_048,
                    config: nil
                ),
            ]
        )
    }

    private static func makeVolume(name: String) -> VolumeSummary {
        VolumeSummary(configuration: .init(
            name: name,
            driver: "local",
            format: "apfs",
            source: "/var/lib/container/volumes/\(name)",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            labels: [:],
            options: [:],
            sizeInBytes: 2_048
        ))
    }

    private static func makeNetwork(name: String) -> NetworkSummary {
        NetworkSummary(
            configuration: .init(
                name: name,
                creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                mode: "nat",
                ipv4Subnet: "10.10.0.0/24",
                ipv6Subnet: nil,
                labels: [:],
                plugin: "container-network-vmnet",
                options: [:]
            ),
            status: .init(ipv4Subnet: "10.10.0.0/24")
        )
    }

    private static func makeComposeProject() -> ComposeProject {
        ComposeProject(
            path: URL(fileURLWithPath: "/tmp/demo/compose.yaml"),
            name: "demo",
            services: [
                .init(name: "web", image: "docker.io/library/nginx:latest"),
            ],
            volumes: ["web-data"],
            networks: ["demo-net"],
            lastModified: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
