# Docker Compatibility Scenarios

This directory contains realistic Docker usage fixtures for the Docker compatibility terminal.

The Swift tests in `Tests/ContainerDesktopTests/DockerCompatibilityScenarioTests.swift` use these
scenarios to keep command conversion behavior aligned with common user workflows:

- image build, tag, package, load, login, and push
- local image build and run scripts
- multi-step shell scripts that call `docker`
- Docker Compose projects with build contexts, env files, profiles, and project names
- unsupported or risky Docker-only options that must surface a friendly note

These fixtures are intentionally small and side-effect free. They are not executed by `swift test`;
the tests validate the Docker-to-container command conversion layer that the terminal shim uses.
