import Testing
@testable import ContainerDesktop

@Suite("Developer run templates")
struct DeveloperRunTemplateTests {
    @Test("templates prefill service defaults without real passwords")
    func templatesPrefillServiceDefaultsWithoutRealPasswords() {
        let postgres = DeveloperRunTemplate.postgres.options(containerName: "pg-dev")
        #expect(postgres.name == "pg-dev")
        #expect(postgres.image == "docker.io/library/postgres:16")
        #expect(postgres.ports == ["5432:5432/tcp"])
        #expect(postgres.env.contains("POSTGRES_HOST_AUTH_METHOD=trust"))
        #expect(postgres.volumes.contains("cd-postgres-data:/var/lib/postgresql/data"))

        let minio = DeveloperRunTemplate.minio.options()
        #expect(minio.ports == ["9000:9000/tcp", "9001:9001/tcp"])
        #expect(minio.env.contains("MINIO_ROOT_PASSWORD=<change-me>"))
        #expect(minio.command == ["server", "/data", "--console-address", ":9001"])

        let redpandaPreview = DeveloperRunTemplate.redpanda.commandPreview()
        #expect(redpandaPreview.contains("docker.io/redpandadata/redpanda:latest"))
        #expect(redpandaPreview.contains("--advertise-kafka-addr 127.0.0.1:9092"))
    }

    @Test("lookup and summaries expose common service catalog")
    func lookupAndSummariesExposeCommonCatalog() {
        #expect(DeveloperRunTemplate.template(id: "redis") == .redis)
        #expect(DeveloperRunTemplate.template(id: "missing") == nil)
        #expect(DeveloperRunTemplate.allCases.contains(.nginx))
        #expect(DeveloperRunTemplate.allCases.contains(.mongodb))
        #expect(DeveloperRunTemplate.allCases.contains(.opensearch))
        #expect(DeveloperRunTemplate.rabbitmq.summary(language: .zhHans).contains("端口 5672:5672/tcp, 15672:15672/tcp"))
    }
}
