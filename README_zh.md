# Container Desktop

简体中文 | [English](README.md)

Container Desktop 是面向 [apple/container](https://github.com/apple/container) 的 macOS 桌面控制台。它用原生 SwiftUI 界面封装本机 `container` 和 `container-compose` CLI，让容器、镜像、Machine、Compose、Registry、日志和系统配置等日常工作流集中在一个窗口中完成，同时保留底层命令的透明性。

## 功能亮点

- Dashboard 展示运行时就绪状态、资源数量、磁盘占用和常用快捷操作。
- Containers 管理容器启动、停止、重启、删除、日志、Inspect JSON、Stats、文件浏览、文件复制、导出和交互式 Exec 终端。
- Container Machine 管理创建、启动、停止、删除、设为默认、原始 JSON Inspect、日志和交互式 Shell。
- Images 管理镜像拉取、构建、打标签、推送、导入、导出、删除、任务历史和 Inspect。
- Volumes / Networks 管理存储卷与网络，支持卷文件浏览、上传、下载、克隆、清空和安全删除。
- Compose 管理项目列表、服务/容器展开行、build/up/down/delete、任务抽屉和容器详情跳转。
- Registries 管理登录/退出登录，浏览 Docker Hub 和 Registry v2 tag，使用独立详情抽屉查看 tag 元数据并直接 Pull。
- Observability 集中查看容器日志、boot 日志、系统日志和 stats 快照。
- Docker 命令转换器可把常见 Docker 命令改写为 `apple/container` 命令。
- System 页面管理运行时版本、属性、磁盘使用、安全清理、启动/停止和 `config.toml` 设置入口。
- 支持简体中文、英文和跟随系统语言。

## 运行要求

- macOS 26 或更新版本。
- Apple silicon (`arm64`)，符合 apple/container 当前运行时环境要求。
- Xcode / Xcode Command Line Tools，Swift 6.2 或更新版本。
- 已安装 `container` CLI，并且在 `PATH` 中可用。
- Compose 工作流需要安装 `container-compose` CLI。

使用资源页面前先启动运行时：

```bash
container system start
container system status
```

如果应用检测到 CLI 缺失或 system 未运行，System 页面会展示当前环境状态和恢复操作。

## 快速开始

```bash
git clone https://github.com/shiguanghuxian/ContainerDesktop.git
cd ContainerDesktop

swift package resolve
swift test
script/build_and_run.sh
```

`script/build_and_run.sh` 会构建 SwiftPM 可执行文件，生成 `dist/ContainerDesktop.app`，并以标准 macOS app bundle 形式打开。

常用开发命令：

```bash
swift build
swift test
git diff --check
script/build_and_run.sh --verify
script/build_and_run.sh --logs
script/build_and_run.sh --telemetry
```

## 使用流程

1. 打开 Container Desktop，在侧边栏或 Dashboard 检查运行环境状态。
2. 如果 `container` 已安装但 system 未运行，从 Dashboard 或 System 启动。
3. 在 Images 拉取或构建镜像，也可以在 Registries 浏览远程 tag。
4. 在 Containers 运行容器，进入详情页查看 Logs、Inspect、Exec、Files、Stats。
5. 需要轻量 Linux VM 风格环境时，在 Machines 创建和管理 Container Machine。
6. 在 Compose 添加 compose 文件，展开项目行查看服务和匹配容器，通过任务抽屉查看操作输出。
7. 需要跨容器日志和指标视图时，使用 Observability。
8. 在 System 查看运行时属性、执行安全清理和进入配置设置。

## 功能说明

### 容器

Containers 页面使用 `container list --all --format json` 加载容器列表。列表行支持生命周期操作、打开终端、快速详情抽屉和删除。完整详情页提供：

- 普通日志和 boot 日志。
- 原始 Inspect JSON。
- 基于 SwiftTerm 和 `container exec -it` 的 Exec 终端。
- 容器文件浏览，支持读取、写入、重命名、删除、上传、下载和创建目录。
- 单次 Stats 快照。

### Machines

Container Machine 通过 `container machine ...` 命令管理。应用支持使用推荐 Machine 镜像或自定义镜像引用创建 Machine，并在创建前验证镜像是否包含可执行的 `/sbin/init`。详情页支持 boot/stop/delete、设为默认、原始 JSON Inspect、日志和通过 `container machine run` 打开 Shell。

### 镜像

Images 页面通过 `container image list --format json` 加载本地镜像。支持 pull、build、tag、push、import、export、delete、清理 dangling 镜像、Inspect 抽屉和镜像任务抽屉。

### Compose

Compose 项目由应用保存，执行时调用 `container-compose`。Compose 页面会解析 compose 文件，展示项目和服务结构，并通过 Compose labels 与容器名称匹配运行时容器。支持 build/up/down 工作流、操作选项和任务输出。

### Registries

Registry 登录/退出登录使用官方 `container registry` 命令。凭据由 container CLI 和 macOS 钥匙串处理，Container Desktop 不保存密码。浏览器支持 Docker Hub 搜索、指定 server/repository 查询 Registry v2 tags、在第二个右侧抽屉查看 tag 元数据、复制完整镜像引用和拉取选中 tag。

### Volumes 和 Networks

Volumes 和 Networks 通过 CLI 列表、创建、Inspect 和删除。卷文件浏览通过临时容器命令读取和操作卷内文件，破坏性操作会保持显式确认。

### Observability

Observability 将 `container logs`、`container system logs` 和 `container stats --no-stream` 聚合为统一界面，支持过滤日志、实时流、boot 日志和 stats 汇总。

### Docker 命令转换器

转换器是本地解析和格式化工具，用于迁移常见 Docker 命令，例如 `docker run`、`docker ps`、`docker pull`、`docker compose up` 和 prune 命令，输出对应的 `container` / `container-compose` 命令。

## 构建和发布

开发运行：

```bash
script/build_and_run.sh
```

验证运行：

```bash
script/build_and_run.sh --verify
```

生成发布包：

```bash
script/package_release.sh --version 1.0.0
```

发布脚本默认运行测试，使用 `swift build -c release` 构建，生成 `.app` bundle，执行签名和校验，并可在 `dist/release` 下输出 zip 和 dmg。

常用发布选项：

```bash
script/package_release.sh --version 1.0.0 --build 100
script/package_release.sh --version 1.0.0 --identity "Developer ID Application: Your Name (TEAMID)"
script/package_release.sh --version 1.0.0 --notarize --notary-profile profile-name
script/package_release.sh --version 1.0.0 --skip-tests --no-dmg
```

如需 notarization，需要 Developer ID 签名身份，并提供 `NOTARY_PROFILE`，或提供 `APPLE_ID`、`APPLE_TEAM_ID`、`APP_SPECIFIC_PASSWORD`。

## 技术栈

- Swift 6.2 和 Swift Package Manager。
- SwiftUI 构建 macOS 主界面。
- AppKit interop 用于窗口管理、剪贴板、菜单集成和终端托管等 SwiftUI 边界能力。
- Observation (`@Observable`, `@Bindable`) 管理 store 和视图状态。
- SwiftTerm 渲染 Exec 和 Machine Shell 的 VT100/Xterm 终端。
- Yams 解析 Compose YAML。
- TOMLKit 编辑 apple/container `config.toml`。
- 基于 Foundation `Process` 的 `CommandRunner` 执行 CLI。
- Swift Testing 编写单元和模型测试。

## 实现原理

Container Desktop 采用 CLI-first 设计：

1. Views 用 SwiftUI 提供原生 macOS 工作流。
2. `RuntimeStore`、`ComposeProjectStore`、`RegistryBrowserStore` 和详情 store 管理状态与异步操作。
3. Service client 将用户动作转换为 `container`、`container-compose`、Docker Hub 或 Registry v2 请求。
4. CLI 能输出 JSON 的地方优先使用 JSON，再解码成 Swift 类型模型。
5. 长耗时命令输出会写入任务历史抽屉，避免阻塞主界面。
6. 交互式 Shell 使用伪终端会话并把字节流交给 SwiftTerm，而不是把 ANSI 输出当普通文本渲染。

这种设计让行为更透明：出现问题时，通常可以把底层命令复制到 Terminal 中复现和排查。

## 安全和隐私

- Registry 密码通过 `container registry login --password-stdin` 传给 CLI，Container Desktop 不保存。
- Registry 浏览器中的临时凭据只用于当前查询，不持久化。
- 安全清理只删除已停止容器和 dangling 镜像，不删除 volumes。
- 删除等破坏性操作都有确认提示。
- 自定义 Machine 镜像在创建前会校验 `/sbin/init`，避免普通容器镜像启动失败后才暴露问题。

## 测试

运行全部自动测试：

```bash
swift test
```

手工测试 fixture 位于：

```text
Tests/Manual/container-image-compose/
```

该目录包含 Compose fixture、辅助脚本，以及容器、镜像、Compose 工作流的手工测试计划。

## 项目结构

```text
Sources/ContainerDesktop/
  App/          macOS app 入口、主窗口和菜单
  Models/       Codable 模型、命令选项、视图模型
  Services/     CLI client、解析器、进程和 Registry client
  Stores/       Observable 应用状态和异步操作
  Support/      主题、偏好设置、路径、命令解析和工具函数
  Views/        SwiftUI 页面、抽屉、详情页和通用控件
Tests/
  ContainerDesktopTests/ 自动化测试
  Manual/                手工测试 fixture 和计划
script/
  build_and_run.sh       开发期 app bundle 构建和运行
  package_release.sh     发布打包、签名、dmg/zip、notarization
```

## 排障

- 页面没有资源：先运行 `container system status`，再用 `container system start` 启动运行时。
- Compose 操作不可用：安装 `container-compose` 并确认它在 `PATH` 中。
- Exec 终端打不开：确认容器正在运行且容器内存在 `sh`。
- Registry 登录后列表看起来没变化：刷新 Registries；Docker Hub 会显示为 `Docker Hub`，真实 server 会显示在副标题。
- 依赖下载遇到网络代理问题：运行 SwiftPM 命令前可设置本机代理，例如：

```bash
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897
```

## License

当前仓库还没有包含 License 文件。正式分发二进制或接受外部贡献前，建议先补充明确的开源许可证。
