# Container Desktop Manual Tests

这里放 Container Desktop 容器、镜像、Compose 三个主要功能的手工测试计划和测试资源：

- `TEST_PLAN.md`：完整测试步骤。
- `fixtures/container`：容器挂载/文件测试用数据。
- `fixtures/image-build`：Images 页构建镜像用的 Dockerfile。
- `fixtures/compose`：Compose 页添加项目用的 `compose.yml` 和构建上下文。
- `scripts/cleanup.sh`：清理测试资源。
- `scripts/cli-smoke.sh`：可选的 CLI 对照冒烟测试。

建议先阅读 `TEST_PLAN.md`，按 UI 步骤测试；需要快速核对底层 CLI 时再运行：

```sh
Tests/Manual/container-image-compose/scripts/cli-smoke.sh
```
