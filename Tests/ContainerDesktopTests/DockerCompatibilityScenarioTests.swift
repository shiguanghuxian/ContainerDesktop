import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Docker compatibility real-world scenarios")
struct DockerCompatibilityScenarioTests {
    private struct Scenario {
        var input: String
        var expectedStatus: DockerCommandConversionStatus
        var expectedCommandText: String
        var expectedNotesContain: [String] = []
    }

    private struct InvocationScenario {
        var executable: String
        var arguments: [String]
        var expectedStatus: DockerCommandConversionStatus
        var expectedCommandText: String
        var expectedNotesContain: [String] = []
    }

    @Test("scenario fixture directory exists")
    func scenarioFixtureDirectoryExists() {
        let root = Self.scenarioRoot
        let expectedFiles = [
            "README.md",
            "image-build/Dockerfile",
            "image-build/.dockerignore",
            "image-build/app/package.json",
            "scripts/multi-step-image-pipeline.sh",
            "scripts/build-and-run-local.sh",
            "compose/simple/compose.yaml",
            "compose/build/compose.yaml",
            "compose/profiles/compose.yaml",
            "compose/profiles/.env",
        ]

        for file in expectedFiles {
            #expect(FileManager.default.fileExists(atPath: root.appending(path: file).path))
        }
    }

    @Test("converts image build package and registry scenarios")
    func convertsImageBuildPackageAndRegistryScenarios() {
        let scenarios = [
            Scenario(
                input: "docker build --file Dockerfile --tag registry.example.com/team/demo:1.0 --build-arg VERSION=1.0 --label org.opencontainers.image.source=https://example.test/repo --progress=plain .",
                expectedStatus: .converted,
                expectedCommandText: "container build -f Dockerfile -t registry.example.com/team/demo:1.0 --build-arg VERSION=1.0 -l org.opencontainers.image.source=https://example.test/repo --progress=plain ."
            ),
            Scenario(
                input: "docker image build --tag local/demo:dev --file Dockerfile .",
                expectedStatus: .converted,
                expectedCommandText: "container build -t local/demo:dev -f Dockerfile ."
            ),
            Scenario(
                input: "docker buildx build --platform linux/arm64 --push -t registry.example.com/team/demo:arm64 .",
                expectedStatus: .warning,
                expectedCommandText: "container build --platform linux/arm64 --push -t registry.example.com/team/demo:arm64 .",
                expectedNotesContain: ["Buildx", "--push"]
            ),
            Scenario(
                input: "docker tag local/demo:dev registry.example.com/team/demo:dev",
                expectedStatus: .converted,
                expectedCommandText: "container image tag local/demo:dev registry.example.com/team/demo:dev"
            ),
            Scenario(
                input: "docker push registry.example.com/team/demo:dev",
                expectedStatus: .converted,
                expectedCommandText: "container image push registry.example.com/team/demo:dev"
            ),
            Scenario(
                input: "docker login --username ci --password-stdin registry.example.com",
                expectedStatus: .converted,
                expectedCommandText: "container registry login --username ci --password-stdin registry.example.com"
            ),
            Scenario(
                input: "docker save -o /tmp/demo.tar local/demo:dev\ndocker load -i /tmp/demo.tar",
                expectedStatus: .converted,
                expectedCommandText: "container image save -o /tmp/demo.tar local/demo:dev\ncontainer image load -i /tmp/demo.tar"
            ),
        ]

        assertScenarios(scenarios)
    }

    @Test("converts local run and shell script scenarios")
    func convertsLocalRunAndShellScriptScenarios() {
        let scenarios = [
            Scenario(
                input: "docker run --rm --detach --name demo-web --publish 8080:80 --env NODE_ENV=production --volume /tmp/app:/app --workdir /app local/demo:dev npm start",
                expectedStatus: .converted,
                expectedCommandText: "container run --rm -d --name demo-web -p 8080:80 -e NODE_ENV=production -v /tmp/app:/app -w /app local/demo:dev npm start"
            ),
            Scenario(
                input: "docker run -it --rm --name debug local/demo:dev sh",
                expectedStatus: .converted,
                expectedCommandText: "container run -i -t --rm --name debug local/demo:dev sh"
            ),
            Scenario(
                input: "docker run --rm alpine:latest sh -lc 'printf --env'",
                expectedStatus: .converted,
                expectedCommandText: "container run --rm alpine:latest sh -lc 'printf --env'"
            ),
            Scenario(
                input: """
                docker build -t local/script-app:latest .
                docker run --rm --name script-app local/script-app:latest sh -lc 'echo ok'
                docker logs --tail=50 script-app
                docker stop script-app
                docker rm -f script-app
                """,
                expectedStatus: .converted,
                expectedCommandText: """
                container build -t local/script-app:latest .
                container run --rm --name script-app local/script-app:latest sh -lc 'echo ok'
                container logs -n 50 script-app
                container stop script-app
                container delete -f script-app
                """
            ),
        ]

        assertScenarios(scenarios)
    }

    @Test("converts docker compose scenarios")
    func convertsDockerComposeScenarios() {
        let scenarios = [
            Scenario(
                input: "docker compose -f compose.yaml --env-file .env up -d --build",
                expectedStatus: .warning,
                expectedCommandText: "container-compose -f compose.yaml --env-file .env up -d --build",
                expectedNotesContain: ["container-compose"]
            ),
            Scenario(
                input: "docker compose --project-name demo -f compose.yaml run --rm web sh -lc 'npm test'",
                expectedStatus: .warning,
                expectedCommandText: "container-compose --project-name demo -f compose.yaml run --rm web sh -lc 'npm test'",
                expectedNotesContain: ["container-compose"]
            ),
            Scenario(
                input: "docker-compose -p legacy -f docker-compose.yml build --pull",
                expectedStatus: .warning,
                expectedCommandText: "container-compose -p legacy -f docker-compose.yml build --pull",
                expectedNotesContain: ["container-compose"]
            ),
        ]

        assertScenarios(scenarios)
    }

    @Test("converts script argv without losing quoted values")
    func convertsScriptArgvWithoutLosingQuotedValues() {
        let scenarios = [
            InvocationScenario(
                executable: "docker",
                arguments: ["build", "--file", "Dockerfile.prod", "--tag", "local/script-app:latest", "--build-arg", "APP_ENV=production", "."],
                expectedStatus: .converted,
                expectedCommandText: "container build -f Dockerfile.prod -t local/script-app:latest --build-arg APP_ENV=production ."
            ),
            InvocationScenario(
                executable: "docker",
                arguments: ["run", "--rm", "--env", "GREETING=hello world", "local/script-app:latest", "sh", "-lc", "printf \"$GREETING\""],
                expectedStatus: .converted,
                expectedCommandText: "container run --rm -e 'GREETING=hello world' local/script-app:latest sh -lc 'printf \"$GREETING\"'"
            ),
        ]

        for scenario in scenarios {
            let result = DockerCommandConverter.convertInvocation(
                executable: scenario.executable,
                arguments: scenario.arguments
            )
            #expect(result.status == scenario.expectedStatus)
            #expect(result.commandText == scenario.expectedCommandText)
            for note in scenario.expectedNotesContain {
                #expect(result.notes.contains { $0.contains(note) })
            }
        }
    }

    @Test("reports risky or unsupported Docker-only behavior")
    func reportsRiskyOrUnsupportedDockerOnlyBehavior() {
        let scenarios = [
            Scenario(
                input: "docker run --network host --add-host host.docker.internal:host-gateway alpine:latest true",
                expectedStatus: .warning,
                expectedCommandText: "container run --network host --add-host host.docker.internal:host-gateway alpine:latest true",
                expectedNotesContain: ["host network", "--add-host"]
            ),
            Scenario(
                input: "docker push --all-tags registry.example.com/team/demo",
                expectedStatus: .unsupported,
                expectedCommandText: "",
                expectedNotesContain: ["--all-tags", "逐个 tag"]
            ),
            Scenario(
                input: "docker swarm init",
                expectedStatus: .unsupported,
                expectedCommandText: "",
                expectedNotesContain: ["Swarm", "Compose"]
            ),
        ]

        assertScenarios(scenarios)
    }

    private static var scenarioRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "DockerCompatibilityScenarios")
    }

    private func assertScenarios(_ scenarios: [Scenario]) {
        for scenario in scenarios {
            let result = DockerCommandConverter.convert(scenario.input)
            #expect(result.status == scenario.expectedStatus)
            #expect(result.commandText == scenario.expectedCommandText)
            for note in scenario.expectedNotesContain {
                #expect(result.notes.contains { $0.contains(note) })
            }
        }
    }
}
