import Testing
@testable import ContainerDesktop

@Suite("Container command options")
struct ContainerCommandOptionsTests {
    @Test("builds full container run arguments")
    func buildsFullContainerRunArguments() {
        let options = ContainerRunOptions(
            name: "web",
            image: "nginx:latest",
            command: ["nginx", "-g", "daemon off;"],
            detached: true,
            interactive: true,
            tty: true,
            removeWhenStopped: true,
            cpus: "2",
            memory: "1g",
            platform: "linux/arm64",
            workdir: "/app",
            env: ["NODE_ENV=production"],
            labels: ["app=web"],
            ports: ["8080:80/tcp"],
            volumes: ["data:/data"],
            networks: ["app-net"]
        )

        #expect(options.arguments == [
            "run",
            "-d",
            "-i",
            "-t",
            "--rm",
            "--name", "web",
            "-c", "2",
            "-m", "1g",
            "--platform", "linux/arm64",
            "-w", "/app",
            "-e", "NODE_ENV=production",
            "-l", "app=web",
            "-p", "8080:80/tcp",
            "-v", "data:/data",
            "--network", "app-net",
            "nginx:latest",
            "nginx",
            "-g",
            "daemon off;",
        ])
    }

    @Test("builds image operation arguments")
    func buildsImageOperationArguments() {
        let build = ImageBuildOptions(
            contextPath: "/tmp/app",
            dockerfilePath: "/tmp/app/Containerfile",
            tag: "example/app:latest",
            cpus: "4",
            memory: "2g",
            noCache: true,
            pull: true,
            platforms: ["linux/arm64"],
            buildArgs: ["VERSION=1"],
            labels: ["org.example=app"]
        )

        #expect(build.arguments == [
            "build",
            "--no-cache",
            "--pull",
            "-f", "/tmp/app/Containerfile",
            "-t", "example/app:latest",
            "-c", "4",
            "-m", "2g",
            "--platform", "linux/arm64",
            "--build-arg", "VERSION=1",
            "-l", "org.example=app",
            "/tmp/app",
        ])

        #expect(ImageSaveOptions(references: ["example/app:latest"], outputPath: "/tmp/app.tar").arguments == [
            "image", "save", "-o", "/tmp/app.tar", "example/app:latest",
        ])

        #expect(ImageLoadOptions(inputPath: "/tmp/app.tar", force: true).arguments == [
            "image", "load", "-f", "-i", "/tmp/app.tar",
        ])

        #expect(ImagePushOptions(reference: "example/app:latest", scheme: "auto", progress: "plain", platform: "linux/arm64").arguments == [
            "image", "push", "--scheme", "auto", "--progress", "plain", "--platform", "linux/arm64", "example/app:latest",
        ])
    }

    @Test("builds advanced image build arguments")
    func buildsAdvancedImageBuildArguments() {
        let build = ImageBuildOptions(
            contextPath: "/tmp/app",
            tag: "example/app:latest",
            progress: "plain",
            quiet: true,
            platforms: ["linux/arm64"],
            architectures: ["arm64"],
            operatingSystems: ["linux"],
            secrets: ["id=npm,src=/tmp/npmrc"],
            dns: ["1.1.1.1"],
            dnsSearch: ["svc.local"],
            dnsOptions: ["ndots:1"],
            dnsDomain: "local"
        )

        #expect(build.arguments == [
            "build",
            "-q",
            "-t", "example/app:latest",
            "--progress", "plain",
            "--dns-domain", "local",
            "--platform", "linux/arm64",
            "-a", "arm64",
            "--os", "linux",
            "--secret", "id=npm,src=/tmp/npmrc",
            "--dns", "1.1.1.1",
            "--dns-search", "svc.local",
            "--dns-option", "ndots:1",
            "/tmp/app",
        ])
    }

    @Test("builds advanced image archive arguments")
    func buildsAdvancedImageArchiveArguments() {
        let save = ImageSaveOptions(
            references: ["example/app:latest", "example/worker:latest"],
            outputPath: "/tmp/images.tar",
            platform: "linux/arm64",
            os: "linux",
            arch: "arm64"
        )

        #expect(save.arguments == [
            "image", "save",
            "-o", "/tmp/images.tar",
            "--platform", "linux/arm64",
            "--os", "linux",
            "-a", "arm64",
            "example/app:latest",
            "example/worker:latest",
        ])

        #expect(ImageLoadOptions(inputPath: "/tmp/images.tar", force: true).arguments == [
            "image", "load", "-f", "-i", "/tmp/images.tar",
        ])
    }

    @Test("builds volume create arguments")
    func buildsVolumeCreateArguments() {
        let options = VolumeCreateOptions(
            name: "data",
            size: "10g",
            options: ["type=virtiofs"],
            labels: ["app=web"]
        )

        #expect(options.arguments == [
            "volume", "create",
            "--label", "app=web",
            "--opt", "type=virtiofs",
            "-s", "10g",
            "data",
        ])
    }
}
