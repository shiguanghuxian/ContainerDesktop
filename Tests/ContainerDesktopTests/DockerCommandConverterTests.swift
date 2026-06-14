import Testing
@testable import ContainerDesktop

@Suite("Docker command converter")
struct DockerCommandConverterTests {
    @Test("converts container list and logs")
    func convertsContainerListAndLogs() {
        #expect(DockerCommandConverter.convert("docker ps -a").commandText == "container list --all")
        #expect(DockerCommandConverter.convert("docker logs -f --tail 100 web").commandText == "container logs --follow -n 100 web")
        #expect(DockerCommandConverter.convert("docker container logs --tail=20 web").commandText == "container logs -n 20 web")
    }

    @Test("converts image commands")
    func convertsImageCommands() {
        #expect(DockerCommandConverter.convert("docker images").commandText == "container image list")
        #expect(DockerCommandConverter.convert("docker pull nginx:latest").commandText == "container image pull nginx:latest")
        #expect(DockerCommandConverter.convert("docker rmi demo:latest").commandText == "container image delete demo:latest")
        #expect(DockerCommandConverter.convert("docker image rm demo:latest").commandText == "container image delete demo:latest")
    }

    @Test("converts system prune to safe cleanup")
    func convertsSystemPruneToSafeCleanup() {
        let result = DockerCommandConverter.convert("docker system prune")

        #expect(result.status == .warning)
        #expect(result.commandText == "container prune\ncontainer image prune")
        #expect(result.notes.contains { $0.contains("不会删除 volume") })
    }

    @Test("converts compose commands")
    func convertsComposeCommands() {
        let dockerCompose = DockerCommandConverter.convert("docker compose up -d")
        let legacyCompose = DockerCommandConverter.convert("docker-compose down")

        #expect(dockerCompose.commandText == "container-compose up -d")
        #expect(legacyCompose.commandText == "container-compose down")
        #expect(dockerCompose.status == .warning)
    }

    @Test("handles multi-line commands and prompts")
    func handlesMultilineCommandsAndPrompts() {
        let result = DockerCommandConverter.convert("""
        $ docker ps -a
        docker pull alpine:latest
        """)

        #expect(result.commandText == "container list --all\ncontainer image pull alpine:latest")
    }

    @Test("reports invalid shell quoting")
    func reportsInvalidShellQuoting() {
        let result = DockerCommandConverter.convert("docker run 'nginx")

        #expect(result.status == .invalid)
        #expect(result.commandText.isEmpty)
    }
}
