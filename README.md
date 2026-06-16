# Container Desktop

[简体中文](README_zh.md) | English

Container Desktop is a macOS desktop console for [apple/container](https://github.com/apple/container). It wraps the local `container` and `container-compose` CLIs with a native SwiftUI interface, so daily container, image, machine, Compose, registry, and observability workflows can be handled from one window without hiding the underlying commands.

## Highlights

- Dashboard for runtime readiness, resource counts, disk usage, and quick actions.
- Containers management with start, stop, restart, delete, logs, inspect JSON, stats, file browser, file copy, export, and an interactive Exec terminal.
- Container Machine management with create, boot, stop, delete, set default, raw inspect JSON, logs, and interactive shell access.
- Images management with pull, build, tag, push, import, export, delete, task history, and local inspect.
- Volumes and networks management, including volume file browsing, upload/download, clone, empty, and safe delete flows.
- Compose project management with project lists, expandable service/container rows, build/up/down/delete operations, task drawer, and container detail navigation.
- Registries page for login/logout and browsing Docker Hub or Registry v2 tags, with a separate tag detail drawer and direct Pull actions.
- Observability page for live container logs, boot logs, system logs, and stats snapshots.
- Docker command converter that rewrites common Docker commands into `apple/container` equivalents.
- System page for runtime version, properties, disk usage, safe cleanup, start/stop, and `config.toml` settings access.
- Bilingual UI with Simplified Chinese, English, and system language mode.

## Requirements

- macOS 26 or newer.
- Apple silicon (`arm64`), matching the expected apple/container runtime environment.
- Xcode / Xcode Command Line Tools with Swift 6.2 or newer.
- `container` CLI installed and available on `PATH`.
- `container-compose` CLI for Compose workflows.

Start the runtime before using resource pages:

```bash
container system start
container system status
```

If the app detects missing CLIs or a stopped system, the System page shows the current environment state and recovery actions.

## Quick Start

```bash
git clone https://github.com/shiguanghuxian/ContainerDesktop.git
cd ContainerDesktop

swift package resolve
swift test
script/build_and_run.sh
```

`script/build_and_run.sh` builds the SwiftPM executable, creates `dist/ContainerDesktop.app`, and opens it as a normal macOS app bundle.

Useful development commands:

```bash
swift build
swift test
git diff --check
script/build_and_run.sh --verify
script/build_and_run.sh --logs
script/build_and_run.sh --telemetry
```

## How To Use

1. Open Container Desktop and check the environment card in the sidebar or Dashboard.
2. If `container` is available but the system is stopped, start it from Dashboard or System.
3. Pull or build an image from Images, or browse tags from Registries.
4. Run a container from Containers, then open the detail page for Logs, Inspect, Exec, Files, and Stats.
5. Create Machines from the Machines page when you need a lightweight Linux VM-style environment backed by apple/container Machine images.
6. Add a Compose file in Compose, expand a project row to inspect services and matched containers, then use the task drawer for operation history.
7. Use Observability when you need a wider view of logs and stats across containers.
8. Use System for runtime properties, cache cleanup, and configuration.

## Feature Details

### Containers

The Containers page lists all containers from `container list --all --format json`. Row actions cover lifecycle commands, terminal launch, quick drawer details, and deletion. The full detail page provides:

- Logs and boot logs.
- Raw inspect JSON.
- Exec terminal backed by SwiftTerm and `container exec -it`.
- Container file browser with read, write, rename, delete, upload, download, and directory creation flows.
- One-shot stats snapshots.

### Machines

Container Machines are managed through `container machine ...` commands. The app supports creation with recommended Machine-compatible images, custom image references, image validation for executable `/sbin/init`, boot/stop/delete, default machine selection, raw JSON inspect, logs, and shell access through `container machine run`.

### Images

Images are loaded from `container image list --format json`. The page supports pull, build, tag, push, import, export, delete, dangling image cleanup, inspect drawers, and an image task drawer for operation output and history.

### Compose

Compose projects are persisted by the app and executed with `container-compose`. The Compose page parses compose files, shows project/service structure, matches runtime containers by Compose labels and names, and exposes build/up/down workflows with operation options and task output.

### Registries

Registry login/logout uses the official `container registry` commands. Credentials are handled by the container CLI and macOS Keychain; Container Desktop does not persist passwords. The browser can search Docker Hub, query Registry v2 tags for a specific server/repository, inspect tag metadata in a secondary drawer, copy full image references, and pull selected tags.

### Volumes And Networks

Volumes and networks are listed through the CLI and can be created, inspected, and deleted. Volume browsing uses temporary container commands to list and manipulate files in a volume while keeping destructive operations explicit.

### Observability

Observability combines `container logs`, `container system logs`, and `container stats --no-stream` into a single UI for filtered logs, live streams, boot logs, and stats summaries.

### Docker Command Converter

The converter is a local parser/formatter for common Docker commands. It helps migrate day-to-day commands such as `docker run`, `docker ps`, `docker pull`, `docker compose up`, and prune commands into their `container` / `container-compose` equivalents.

## Build And Release

Development app bundle:

```bash
script/build_and_run.sh
```

Verification run:

```bash
script/build_and_run.sh --verify
```

Release package:

```bash
script/package_release.sh --version 1.0.0
```

The release script runs tests by default, builds with `swift build -c release`, creates a `.app` bundle, signs it, verifies the bundle, and can emit zip and dmg artifacts under `dist/release`.

Common release options:

```bash
script/package_release.sh --version 1.0.0 --build 100
script/package_release.sh --version 1.0.0 --identity "Developer ID Application: Your Name (TEAMID)"
script/package_release.sh --version 1.0.0 --notarize --notary-profile profile-name
script/package_release.sh --version 1.0.0 --skip-tests --no-dmg
```

For notarization, provide a Developer ID signing identity and either `NOTARY_PROFILE` or `APPLE_ID`, `APPLE_TEAM_ID`, and `APP_SPECIFIC_PASSWORD`.

## Technology Stack

- Swift 6.2 and Swift Package Manager.
- SwiftUI for the main macOS UI.
- AppKit interop for window management, pasteboard, menu integration, and terminal hosting behavior where needed.
- Observation (`@Observable`, `@Bindable`) for app stores and view state.
- SwiftTerm for VT100/Xterm terminal rendering in Exec and Machine shell tabs.
- Yams for Compose YAML parsing.
- TOMLKit for apple/container `config.toml` editing.
- Foundation `Process` wrappers through `CommandRunner` for CLI execution.
- Swift Testing for unit and model tests.

## Architecture

Container Desktop is intentionally CLI-first:

1. Views present native macOS workflows using SwiftUI.
2. Stores such as `RuntimeStore`, `ComposeProjectStore`, `RegistryBrowserStore`, and detail stores own state and async operations.
3. Service clients translate user actions into `container`, `container-compose`, Docker Hub, or Registry v2 requests.
4. CLI commands return JSON when available; models decode that JSON into typed Swift structs.
5. Long-running command output is captured into operation history drawers so the UI remains responsive.
6. Interactive shells use a pseudo-terminal session and feed bytes into SwiftTerm instead of rendering ANSI output as plain text.

This keeps behavior transparent: when something fails, the same underlying command can usually be copied or reproduced in Terminal.

## Safety And Privacy

- Registry passwords are passed to `container registry login --password-stdin` and are not saved by Container Desktop.
- Registry browser credentials are only used for the current query and are not persisted by the app.
- Safe cleanup removes stopped containers and dangling images; it does not delete volumes.
- Destructive actions use confirmation prompts.
- Machine creation validates custom images before creation to catch images without executable `/sbin/init`.

## Tests

Run all automated tests:

```bash
swift test
```

Manual workflow fixtures live under:

```text
Tests/Manual/container-image-compose/
```

That directory includes Compose fixtures, helper scripts, and a manual test plan for container, image, and Compose workflows.

## Project Layout

```text
Sources/ContainerDesktop/
  App/          macOS app entry, main window, menu wiring
  Models/       Codable models, command options, view models
  Services/     CLI clients, parsers, process and registry clients
  Stores/       Observable application state and async operations
  Support/      theme, preferences, paths, tokenizers, utilities
  Views/        SwiftUI pages, drawers, detail pages, shared controls
Tests/
  ContainerDesktopTests/ automated tests
  Manual/                manual workflow fixtures and plans
script/
  build_and_run.sh       development app bundle runner
  package_release.sh     release packaging, signing, dmg/zip, notarization
```

## Troubleshooting

- No resources are shown: run `container system status`, then start the runtime with `container system start`.
- Compose actions are unavailable: install `container-compose` and confirm it is on `PATH`.
- Exec terminal does not open: make sure the container is running and has `sh`.
- Registry login looks unchanged: refresh Registries; Docker Hub may be displayed as `Docker Hub` with the real server shown as secondary text.
- Build dependencies fail behind a network proxy: configure your shell proxy before running SwiftPM commands, for example:

```bash
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897
```

## License

No license file is currently included in this repository. Add one before distributing binaries or accepting external contributions.
