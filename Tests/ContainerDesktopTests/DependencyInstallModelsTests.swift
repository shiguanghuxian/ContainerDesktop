import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Dependency install models")
struct DependencyInstallModelsTests {
    @Test("detects missing dependency targets in stable order")
    func detectsMissingDependencyTargets() {
        #expect(DependencyInstallTarget.missing(in: environment(container: true, compose: true)).isEmpty)
        #expect(DependencyInstallTarget.missing(in: environment(container: false, compose: true)) == [.container])
        #expect(DependencyInstallTarget.missing(in: environment(container: true, compose: false)) == [.containerCompose])
        #expect(DependencyInstallTarget.missing(in: environment(container: false, compose: false)) == [.container, .containerCompose])
    }

    @Test("builds install commands from official installation paths")
    func buildsInstallCommands() {
        let containerCommand = DependencyInstallTarget.container.displayCommand
        #expect(containerCommand.contains("https://api.github.com/repos/apple/container/releases/latest"))
        #expect(containerCommand.contains("sudo installer -pkg /tmp/apple-container.pkg -target /"))
        #expect(containerCommand.contains("container system start"))

        let composeCommand = DependencyInstallTarget.containerCompose.displayCommand
        #expect(composeCommand == "brew update && brew install container-compose")
    }

    private func environment(container: Bool, compose: Bool) -> EnvironmentProbe {
        EnvironmentProbe(
            macOSVersion: "26.0",
            architecture: "arm64",
            containerAvailable: container,
            containerComposeAvailable: compose,
            systemRunning: container,
            systemVersion: container ? "1.0.0" : nil,
            errorMessage: nil
        )
    }
}
