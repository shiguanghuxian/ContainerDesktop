import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Machine models")
struct MachineModelsTests {
    @Test("machine detail tabs include files")
    func machineDetailTabsIncludeFiles() {
        #expect(MachineDetailTab.allCases.contains(.files))
        #expect(MachineDetailTab.files.title(language: .en) == "Files")
        #expect(MachineDetailTab.files.systemImage == "folder")
    }

    @Test("generates valid machine names from image references")
    func generatesValidMachineNames() {
        #expect(MachineNameGenerator.automaticName(for: "ubuntu:24.04") == "ubuntu-24-04")
        #expect(MachineNameGenerator.automaticName(for: "docker.io/library/alpine:latest") == "alpine-latest")
        #expect(MachineNameGenerator.automaticName(for: "localhost:5000/team/image:1.2.3") == "image-1-2-3")
        #expect(MachineNameGenerator.automaticName(for: "local/ubuntu-machine:latest") == "ubuntu-machine-latest")
        #expect(MachineNameGenerator.automaticName(for: "ubuntu:24.04", existingIDs: ["ubuntu-24-04"]) == "ubuntu-24-04-2")
    }

    @Test("machine image presets stay machine compatible")
    func machineImagePresetsStayMachineCompatible() {
        #expect(FormPresetOptions.machineImages.contains("alpine:3.22"))
        #expect(FormPresetOptions.machineImages.contains("alpine:3.21"))
        #expect(FormPresetOptions.machineImages.contains("alpine:3.20"))
        #expect(FormPresetOptions.machineImages.contains("alpine:latest"))
        #expect(FormPresetOptions.machineImages.contains("local/ubuntu-machine:latest"))
        #expect(FormPresetOptions.machineImages.contains("local/debian-machine:latest"))
        #expect(!FormPresetOptions.machineImages.contains("nginx:latest"))
        #expect(!FormPresetOptions.machineImages.contains("redis:latest"))
        #expect(!FormPresetOptions.machineImages.contains("ubuntu:24.04"))
        #expect(!FormPresetOptions.machineImages.contains("debian:bookworm"))
        #expect(FormPresetOptions.machineImagePreset(reference: "alpine:3.22")?.requiresLocalBuild == false)
        #expect(FormPresetOptions.machineImagePreset(reference: "local/ubuntu-machine:latest")?.requiresLocalBuild == true)
        #expect(FormPresetOptions.machineImagePreset(reference: " local/debian-machine:latest ")?.requiresLocalBuild == true)
        #expect(FormPresetOptions.machineImagePreset(reference: "alpine:3.22")?.buildRecipe == nil)
        #expect(FormPresetOptions.machineImagePreset(reference: "local/ubuntu-machine:latest")?.buildRecipe?.dockerfile.contains("FROM ubuntu:24.04") == true)
        #expect(FormPresetOptions.machineImagePreset(reference: "local/debian-machine:latest")?.buildRecipe?.dockerfile.contains("FROM debian:bookworm") == true)
    }

    @Test("builds machine configuration updates from current state")
    func buildsMachineConfigurationUpdates() {
        let summary = MachineSummary(
            id: "dev",
            status: "running",
            isDefault: false,
            ipAddress: nil,
            cpus: 4,
            memory: 8_589_934_592,
            diskSize: nil,
            createdDate: nil
        )
        let summaryUpdate = MachineConfigurationUpdate(machine: summary)

        #expect(summaryUpdate.cpus == 4)
        #expect(summaryUpdate.memory == nil)
        #expect(summaryUpdate.homeMount == .rw)
        #expect(!summaryUpdate.hasChanges(comparedTo: summaryUpdate))
        #expect(MachineConfigurationUpdate(cpus: 4, memory: "8G", homeMount: .rw).hasChanges(comparedTo: summaryUpdate))
        #expect(MachineConfigurationUpdate(cpus: 6, homeMount: .rw).hasChanges(comparedTo: summaryUpdate))
        #expect(MachineConfigurationUpdate(cpus: 4, homeMount: .ro).hasChanges(comparedTo: summaryUpdate))

        let inspection = MachineInspection(
            id: "dev",
            image: .init(reference: "alpine:3.22", descriptor: nil),
            platform: .init(os: "linux", architecture: "arm64", variant: nil),
            userSetup: .init(username: "user", uid: 501, gid: 20),
            status: "running",
            startedDate: nil,
            createdDate: nil,
            containerId: nil,
            cpus: 6,
            memory: 4_294_967_296,
            homeMount: "ro",
            diskSize: nil,
            ipAddress: nil
        )
        let inspectedUpdate = MachineConfigurationUpdate(machine: summary, inspection: inspection)

        #expect(inspectedUpdate.cpus == 6)
        #expect(inspectedUpdate.memory == nil)
        #expect(inspectedUpdate.homeMount == .ro)
    }

    @Test("decodes machine list JSON")
    func decodesMachineList() throws {
        let json = """
        [
          {
            "id": "dev",
            "status": "running",
            "default": true,
            "ipAddress": "192.168.64.10",
            "cpus": 4,
            "memory": 8589934592,
            "diskSize": 17179869184,
            "createdDate": "2026-06-12T08:30:00Z"
          }
        ]
        """

        let machines = try JSONDecoder.containerDesktop.decode([MachineSummary].self, from: Data(json.utf8))
        #expect(machines.count == 1)
        #expect(machines[0].id == "dev")
        #expect(machines[0].isDefault)
        #expect(machines[0].isRunning)
        #expect(machines[0].ipAddressText == "192.168.64.10")
    }

    @Test("decodes machine inspect JSON")
    func decodesMachineInspect() throws {
        let json = """
        [
          {
            "id": "dev",
            "image": {
              "reference": "alpine:latest",
              "descriptor": {
                "digest": "sha256:abc",
                "mediaType": "application/vnd.oci.image.manifest.v1+json"
              }
            },
            "platform": {
              "os": "linux",
              "architecture": "arm64"
            },
            "userSetup": {
              "username": "zuoxiupeng",
              "uid": 501,
              "gid": 20
            },
            "status": "running",
            "startedDate": "2026-06-12T08:35:00Z",
            "createdDate": "2026-06-12T08:30:00Z",
            "containerId": "dev-abc123",
            "cpus": 4,
            "memory": 8589934592,
            "homeMount": "rw",
            "diskSize": 17179869184,
            "ipAddress": "192.168.64.10"
          }
        ]
        """

        let machines = try JSONDecoder.containerDesktop.decode([MachineInspection].self, from: Data(json.utf8))
        #expect(machines.count == 1)
        #expect(machines[0].image.referenceText == "alpine:latest")
        #expect(machines[0].platformText == "linux/arm64")
        #expect(machines[0].userSetup.home == "/home/zuoxiupeng")
        #expect(machines[0].diskSizeDisplay != "—")
    }
}
