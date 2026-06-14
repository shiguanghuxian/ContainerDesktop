import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Machine models")
struct MachineModelsTests {
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
        #expect(!FormPresetOptions.machineImages.contains("nginx:latest"))
        #expect(!FormPresetOptions.machineImages.contains("redis:latest"))
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
