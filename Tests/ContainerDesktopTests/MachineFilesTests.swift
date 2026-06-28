import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Machine files")
struct MachineFilesTests {
    @Test("machine files use shared code preview editor")
    func machineFilesUseSharedCodePreviewEditor() throws {
        let source = try String(
            contentsOfFile: "Sources/ContainerDesktop/Views/Resources/MachineDetail/MachineFilesTabView.swift",
            encoding: .utf8
        )

        #expect(source.contains("FilePreviewCodePanel("))
        #expect(source.contains("FileBrowserFolderInfoPanel("))
        #expect(source.contains("if let selectedFile = store.selectedFile, !selectedFile.isDirectory"))
        #expect(source.contains("previewFontSize"))
        #expect(source.contains("fileName: selectedFile.path"))
        #expect(source.contains("isEditable: store.isSelectedFileEditable"))
        #expect(!source.contains("TextEditor(text: $store.filePreviewText)"))
    }

    @Test("machine file list uses machine run")
    func machineFileListUsesMachineRun() async throws {
        let fake = try FakeMachineFilesCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        let entries = try await client.listMachineFiles(id: "dev", path: "/etc")

        #expect(entries.count == 1)
        #expect(entries.first?.name == "hosts")
        #expect(entries.first?.path == "/etc/hosts")
        let log = try fake.commandLog()
        #expect(log.contains("arg[0]=machine\narg[1]=run\narg[2]=-n\narg[3]=dev\narg[4]=-i\narg[5]=--\narg[6]=sh\narg[7]=-s"))
        #expect(log.contains("stdin=dir='/etc'"))
        #expect(!log.contains("arg[4]=--root"))
    }

    @Test("machine file list normalizes root entry paths")
    func machineFileListNormalizesRootEntryPaths() async throws {
        let fake = try FakeMachineFilesCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        let entries = try await client.listMachineFiles(id: "dev", path: "/")

        #expect(entries.first?.path == "/etc")
        let log = try fake.commandLog()
        #expect(log.contains("entry_path=\"/$name\""))
    }

    @Test("machine file content can run as root")
    func machineFileContentCanRunAsRoot() async throws {
        let fake = try FakeMachineFilesCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        let contents = try await client.machineFileContent(id: "dev", path: "/etc/hosts", asRoot: true)

        #expect(contents == "127.0.0.1 localhost\n")
        let log = try fake.commandLog()
        #expect(log.contains("arg[0]=machine\narg[1]=run\narg[2]=-n\narg[3]=dev\narg[4]=--root\narg[5]=-i\narg[6]=--\narg[7]=sh\narg[8]=-s"))
        #expect(log.contains("stdin=cat -- '/etc/hosts'"))
    }

    @Test("machine file write uses stdin script")
    func machineFileWriteUsesStdinScript() async throws {
        let fake = try FakeMachineFilesCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        try await client.writeMachineFile(id: "dev", path: "/etc/hosts", contents: "hello\n", asRoot: true)

        let log = try fake.commandLog()
        #expect(log.contains("arg[0]=machine\narg[1]=run\narg[2]=-n\narg[3]=dev\narg[4]=--root\narg[5]=-i\narg[6]=--\narg[7]=sh\narg[8]=-s"))
        #expect(log.contains("stdin=printf '%s' 'hello"))
        #expect(log.contains("> '/etc/hosts'"))
    }

    @Test("machine file mutations use stdin scripts")
    func machineFileMutationsUseStdinScripts() async throws {
        let fake = try FakeMachineFilesCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        try await client.createMachineDirectory(id: "dev", path: "/tmp/new", asRoot: false)
        try await client.renameMachinePath(id: "dev", source: "/tmp/new", destination: "/tmp/renamed", asRoot: true)
        try await client.deleteMachinePath(id: "dev", path: "/tmp/renamed", asRoot: true)

        let log = try fake.commandLog()
        #expect(log.contains("stdin=mkdir -p -- '/tmp/new'"))
        #expect(log.contains("stdin=mv -- '/tmp/new' '/tmp/renamed'"))
        #expect(log.contains("stdin=rm -rf -- '/tmp/renamed'"))
        #expect(log.contains("arg[4]=--root\narg[5]=-i\narg[6]=--\narg[7]=sh\narg[8]=-s"))
    }

    @MainActor
    @Test("machine files load lazily")
    func machineFilesLoadLazily() async throws {
        let fake = try FakeMachineFilesCLI()
        let store = MachineDetailStore(
            machineID: "dev",
            client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))
        )

        #expect(try fake.commandLog().isEmpty)

        await store.loadFilesIfNeeded()
        await store.loadFilesIfNeeded()

        #expect(store.fileEntries.count == 1)
        #expect(try fake.commandLog().components(separatedBy: "arg[0]=machine").count == 2)
    }

    @MainActor
    @Test("root toggle reloads files and clears preview state")
    func rootToggleReloadsFilesAndClearsPreviewState() async throws {
        let fake = try FakeMachineFilesCLI()
        let store = MachineDetailStore(
            machineID: "dev",
            client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))
        )

        await store.loadFilesIfNeeded()
        store.selectedFile = store.fileEntries.first
        store.isSelectedFileEditable = true
        store.filePreviewText = "changed"

        await store.setFileUsesRoot(true)

        #expect(store.fileUsesRoot)
        #expect(store.selectedFile == nil)
        #expect(!store.isSelectedFileEditable)
        #expect(store.filePreviewText.isEmpty)
        #expect(try fake.commandLog().contains("arg[4]=--root\narg[5]=-i\narg[6]=--"))
    }

    @MainActor
    @Test("missing machine file path reports readable error")
    func missingMachineFilePathReportsReadableError() async throws {
        let fake = try FakeMachineFilesCLI()
        let store = MachineDetailStore(
            machineID: "dev",
            client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))
        )

        await store.loadFiles(path: "/missing")

        #expect(store.fileEntries.isEmpty)
        #expect(store.fileError?.contains("path is not a directory: /missing") == true)
    }

    @MainActor
    @Test("large machine files do not become editable")
    func largeMachineFilesDoNotBecomeEditable() async throws {
        let fake = try FakeMachineFilesCLI()
        let store = MachineDetailStore(
            machineID: "dev",
            client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))
        )
        let entry = ContainerFileEntry(
            name: "large.log",
            path: "/var/log/large.log",
            kind: .regularFile,
            mode: "-rw-r--r--",
            owner: "root",
            group: "root",
            size: 1_000_001,
            modifiedAt: nil,
            linkTarget: nil
        )

        await store.openFileEntry(entry)

        #expect(store.selectedFile == entry)
        #expect(!store.isSelectedFileEditable)
        #expect(store.filePreviewText.isEmpty)
        #expect(store.fileStatusText?.contains("1 MB") == true)
        #expect(try fake.commandLog().isEmpty)
    }
}

private struct FakeMachineFilesCLI {
    let directory: URL
    let logURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        logURL = directory.appending(path: "commands.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "".write(to: logURL, atomically: true, encoding: .utf8)

        let executable = directory.appending(path: "container")
        try """
        #!/usr/bin/env bash
        set -euo pipefail
        log="\(logURL.path)"
        index=0
        for arg in "$@"; do
          printf 'arg[%s]=%s\\n' "$index" "$arg" >> "$log"
          index=$((index + 1))
        done
        printf '%s\\n' '---' >> "$log"

        if [ "$1" = "machine" ] && [ "$2" = "run" ] && [ "$3" = "-n" ] && [ "$4" = "dev" ]; then
          script=$(cat)
          printf 'stdin=%s\\n' "$script" >> "$log"
          if [[ "$script" == *"dir='/'"* ]]; then
            printf 'etc\\t/etc\\tdirectory\\tdrwxr-xr-x\\troot\\troot\\t4096\\t1781233546\\t\\n'
            exit 0
          fi
          if [[ "$script" == *"dir='/missing'"* ]]; then
            echo "path is not a directory: /missing" >&2
            exit 2
          fi
          if [[ "$script" == *"cat --"* ]]; then
            printf '127.0.0.1 localhost\\n'
            exit 0
          fi
          if [[ "$script" == *"printf '%s'"* ]] || [[ "$script" == *"mkdir -p"* ]] || [[ "$script" == *"mv --"* ]] || [[ "$script" == *"rm -rf"* ]]; then
            exit 0
          fi
          printf 'hosts\\t/etc/hosts\\tregular file\\t-rw-r--r--\\troot\\troot\\t42\\t1781233546\\t\\n'
          exit 0
        fi

        if [ "$1" = "machine" ] && [ "$2" = "run" ] && [ "$3" = "-n" ] && [ "$4" = "dev" ] && [ "$5" = "--root" ]; then
          script=$(cat)
          printf 'stdin=%s\\n' "$script" >> "$log"
          if [[ "$script" == *"cat --"* ]]; then
            printf '127.0.0.1 localhost\\n'
            exit 0
          fi
          if [[ "$script" == *"printf '%s'"* ]] || [[ "$script" == *"mv --"* ]] || [[ "$script" == *"rm -rf"* ]]; then
            exit 0
          fi
          printf 'hosts\\t/etc/hosts\\tregular file\\t-rw-r--r--\\troot\\troot\\t42\\t1781233546\\t\\n'
          exit 0
        fi

        echo "unexpected command: $*" >&2
        exit 64
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }

    func commandLog() throws -> String {
        try String(contentsOf: logURL, encoding: .utf8)
    }
}
