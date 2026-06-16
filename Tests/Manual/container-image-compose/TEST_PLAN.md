# Container Desktop 容器 / 镜像 / Compose 手工测试计划

本文档用于手工验证 Container Desktop 的三个主要功能：容器、镜像、Compose。

测试资源都使用 `cd-manual-*` 或 `cdmanualcompose` 前缀。测试结束后运行：

```sh
Tests/Manual/container-image-compose/scripts/cleanup.sh
```

## 0. 测试前检查

1. 启动 Container Desktop。
2. 确认左下角显示 `Engine running`。
3. 打开终端确认：

```sh
container --version
container system status
container-compose version
```

期望：

- `container` 可用。
- `container-compose` 可用。
- 系统状态为 running。

## 1. 容器功能测试

### 1.1 运行容器

页面：`Containers`

操作：

1. 点击 `运行容器`。
2. 关闭 `自动命名`。
3. 名称输入：`cd-manual-container`
4. 镜像选择：`alpine:latest`
5. 命令选择：`自定义`
6. 命令输入：

```sh
sh -c "echo cd-manual-container-log-ok; sleep 3600"
```

7. 保持 `-d` 开启，点击 `运行`。

期望：

- 列表出现 `cd-manual-container`。
- 状态为 `running`。
- IP 有值。
- 底部统计的 Containers 数量增加。

CLI 对照：

```sh
container ls --all --format json | grep cd-manual-container
container logs -n 20 cd-manual-container
container stats --format json --no-stream cd-manual-container
```

### 1.2 容器详情

操作：

1. 点击 `cd-manual-container` 行。
2. 查看详情页的概览、日志、Stats、Exec、文件相关功能。
3. 在 Exec 中执行：

```sh
printf cd-manual-exec-ok
```

4. 文件测试可读取：

```sh
/etc/os-release
```

期望：

- 概览展示镜像、状态、IP、资源信息。
- 日志包含 `cd-manual-container-log-ok`。
- Stats 有 CPU、内存、网络或进程数据。
- Exec 输出 `cd-manual-exec-ok`。
- 文件读取能显示 `/etc/os-release` 内容。

### 1.3 停止、启动、导出、删除

操作：

1. 返回 Containers 列表。
2. 点击停止按钮。
3. 状态变为 `stopped`。
4. 确认 `归档/导出` 按钮可用。
5. 点击归档按钮，导出到临时路径，例如 `/tmp/cd-manual-container-filesystem.tar`。
6. 点击启动按钮。
7. 状态重新变为 `running`。
8. 停止后删除 `cd-manual-container`。

期望：

- running 状态下导出按钮不可用，并提示“停止容器后可导出文件系统”。
- stopped 状态下可以导出，tar 文件生成且非空。
- 删除后列表中不再出现 `cd-manual-container`。

CLI 对照：

```sh
test -s /tmp/cd-manual-container-filesystem.tar
container ls --all --format json | grep cd-manual-container || true
```

## 2. 镜像功能测试

### 2.1 拉取与查看镜像

页面：`Images`

操作：

1. 点击 `拉取`。
2. 选择 `alpine:latest`，点击拉取。
3. 在镜像列表搜索 `alpine`。
4. 打开详情抽屉。

期望：

- `docker.io/library/alpine:latest` 出现在列表。
- 详情能展示 tag、digest、平台、大小等信息。

CLI 对照：

```sh
container image ls --format json | grep alpine
container image inspect alpine:latest
```

### 2.2 构建镜像

页面：`Images`

使用目录：

```text
Tests/Manual/container-image-compose/fixtures/image-build
```

操作：

1. 点击 `更多` -> `构建`。
2. 构建目录选择上面的 `fixtures/image-build`。
3. Dockerfile 留空，使用默认 `Dockerfile`。
4. tag 输入：`localhost/containerdesktop/cd-manual-image:latest`
5. `--progress` 选择 `plain`。
6. 点击 `构建`。

期望：

- 镜像任务显示成功。
- 列表出现 `localhost/containerdesktop/cd-manual-image:latest`。
- 打开详情能看到 label `containerdesktop.manual=image-build`。

CLI 对照：

```sh
container image inspect localhost/containerdesktop/cd-manual-image:latest
```

### 2.3 Tag、导出、导入、删除

操作：

1. 对 `localhost/containerdesktop/cd-manual-image:latest` 打开更多菜单。
2. Tag 为：`localhost/containerdesktop/cd-manual-image:copy`
3. 导出 `localhost/containerdesktop/cd-manual-image:copy` 到：

```text
/tmp/cd-manual-image.tar
```

4. 删除 `localhost/containerdesktop/cd-manual-image:copy`。
5. 从 `/tmp/cd-manual-image.tar` 导入。
6. 确认 `copy` tag 恢复。
7. 删除 `latest` 和 `copy` 两个测试镜像。

期望：

- tag 创建成功。
- 导出 tar 非空。
- 删除后列表不再显示 copy。
- 导入后 copy 恢复。
- 最终测试镜像都被删除。

CLI 对照：

```sh
test -s /tmp/cd-manual-image.tar
container image ls --format json | grep cd-manual-image || true
```

### 2.4 Push 说明

Push 会把镜像上传到 registry，属于外部副作用测试。除非你准备了自己的本地或私有 registry，不建议在常规手工测试里执行。

如果要测：

1. 先登录目标 registry。
2. 给镜像打上目标 registry tag。
3. 在 Images 页打开 Push，选择合适的 scheme。
4. 确认远端 registry 收到镜像。

## 3. Compose 功能测试

### 3.1 添加项目

页面：`Compose`

使用文件：

```text
Tests/Manual/container-image-compose/fixtures/compose/compose.yml
```

操作：

1. 点击 `添加项目`。
2. 选择上面的 `compose.yml`。

期望：

- 列表出现项目 `cdmanualcompose`。
- 服务数为 `1`。
- Vol / Net 为 `0 / 0`。
- 状态初始为 `—` 或 `0/1`。

### 3.2 Build

操作：

1. 点击项目行的 build 按钮。
2. 等待 Compose 任务完成。

期望：

- 任务历史显示 build 成功。
- 镜像列表出现 `localhost/containerdesktop/cd-manual-compose:latest`。

CLI 对照：

```sh
container image ls --format json | grep cd-manual-compose
```

### 3.3 Up 与服务状态

操作：

1. 点击项目行的 up 按钮。
2. 等待完成。
3. 打开项目详情抽屉。

期望：

- 容器列表出现 `cdmanualcompose-app`。
- Compose 项目状态显示 `1/1`。
- 服务状态为 `running`。
- 服务日志包含 `cd-manual-compose-log-ok`。

CLI 对照：

```sh
container ls --all --format json | grep cdmanualcompose-app
container logs -n 20 cdmanualcompose-app
```

### 3.4 Down 与清理

操作：

1. 点击项目行的 down 按钮。
2. 等待完成。

期望：

- `container-compose down` 的语义是停止容器，不一定删除容器。
- `cdmanualcompose-app` 状态应为 `stopped`。
- Compose 项目状态显示 `0/1` 或 stopped。

CLI 对照：

```sh
container ls --all --format json | grep cdmanualcompose-app
```

最终清理：

```sh
Tests/Manual/container-image-compose/scripts/cleanup.sh
```

## 4. 完整回归检查

完成以上测试后执行：

```sh
swift test
script/build_and_run.sh --verify
Tests/Manual/container-image-compose/scripts/cleanup.sh
```

期望：

- 单元测试通过。
- 应用能重新构建启动。
- `cd-manual-*` 和 `cdmanualcompose` 资源无残留。
