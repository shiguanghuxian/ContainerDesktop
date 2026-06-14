const translations = {
  zh: {
    "nav.features": "能力",
    "nav.install": "安装",
    "nav.requirements": "要求",
    "nav.source": "源码",
    "hero.eyebrow": "面向 apple/container 的原生控制台",
    "hero.title": "ContainerDesktop",
    "hero.copy": "把容器、Machine、镜像、Compose、Registry、日志和系统配置收束到一个 macOS 桌面工作台里。",
    "hero.download": "下载 0.1.0",
    "hero.source": "查看 GitHub 源码",
    "hero.metric1": "macOS 26+",
    "hero.metric2": "Apple silicon",
    "hero.metric3": "SwiftUI 原生",
    "mission.kicker": "CLI-first, desktop-fast",
    "mission.title": "保留命令透明性，补齐桌面操作效率。",
    "mission.copy": "ContainerDesktop 不隐藏底层命令。它把 apple/container 的 JSON 输出、长任务、交互式终端和配置文件编辑组织成可扫描、可重复执行的桌面工作流。",
    "shot.kicker": "真实运行截图",
    "shot.title": "一个窗口覆盖日常容器管理。",
    "shot.caption": "Dashboard、侧栏资源导航、状态栏和资源管理页面来自当前真实运行的 ContainerDesktop。",
    "features.kicker": "控制面板",
    "features.title": "为 apple/container 的完整工作流而设计。",
    "features.containers.title": "容器详情",
    "features.containers.copy": "启动、停止、日志、Inspect JSON、Stats、Files 和 SwiftTerm Exec 终端集中在详情页。",
    "features.machines.title": "Container Machine",
    "features.machines.copy": "创建和管理轻量 Linux Machine，支持原始 Inspect、日志和内置 Shell。",
    "features.compose.title": "Compose 编排",
    "features.compose.copy": "添加 compose 文件，展开服务和容器，执行 build、up、down，并查看任务输出。",
    "features.registries.title": "Registry 工作台",
    "features.registries.copy": "登录镜像仓库，浏览 Docker Hub 与 Registry v2 tags，查看 tag 元数据并直接 Pull。",
    "features.observability.title": "观测与日志",
    "features.observability.copy": "聚合容器日志、boot 日志、系统日志和 stats 快照，适合排障和状态巡检。",
    "features.converter.title": "Docker 命令转换",
    "features.converter.copy": "把常见 Docker 命令改写为 container / container-compose 命令，迁移时少猜参数。",
    "install.kicker": "独立分发",
    "install.title": "从 GitHub Releases 获取安装包。",
    "install.step1": "打开 Release 0.1.0，下载最新的 zip 或 dmg 产物。",
    "install.step2": "解压并移动到 Applications，首次打开时按 macOS 安全提示确认。",
    "install.step3": "安装 apple/container；Compose 工作流再安装 container-compose。",
    "requirements.kicker": "运行要求",
    "requirements.title": "为现代 macOS 容器运行时准备。",
    "requirements.macos": "26 或更新版本",
    "footer.copy": "独立分发的 macOS 桌面控制台。",
    "footer.release": "Release 0.1.0"
  },
  en: {
    "nav.features": "Features",
    "nav.install": "Install",
    "nav.requirements": "Requirements",
    "nav.source": "Source",
    "hero.eyebrow": "Native console for apple/container",
    "hero.title": "ContainerDesktop",
    "hero.copy": "A macOS workbench for containers, Machines, images, Compose, registries, logs, and runtime configuration.",
    "hero.download": "Download 0.1.0",
    "hero.source": "View source on GitHub",
    "hero.metric1": "macOS 26+",
    "hero.metric2": "Apple silicon",
    "hero.metric3": "Native SwiftUI",
    "mission.kicker": "CLI-first, desktop-fast",
    "mission.title": "Keep command transparency. Add desktop speed.",
    "mission.copy": "ContainerDesktop does not hide the underlying commands. It turns apple/container JSON output, long-running tasks, interactive terminals, and configuration editing into scannable desktop workflows.",
    "shot.kicker": "Live application screenshot",
    "shot.title": "Daily container management in one window.",
    "shot.caption": "Dashboard, resource navigation, status bar, and management pages are captured from a real running ContainerDesktop session.",
    "features.kicker": "Control surface",
    "features.title": "Designed for the full apple/container workflow.",
    "features.containers.title": "Container details",
    "features.containers.copy": "Start, stop, logs, raw Inspect JSON, Stats, Files, and a SwiftTerm Exec terminal live in the detail page.",
    "features.machines.title": "Container Machine",
    "features.machines.copy": "Create and manage lightweight Linux Machines with raw Inspect, logs, and an embedded shell.",
    "features.compose.title": "Compose orchestration",
    "features.compose.copy": "Add compose files, expand services and containers, run build, up, and down, then inspect task output.",
    "features.registries.title": "Registry workbench",
    "features.registries.copy": "Login to registries, browse Docker Hub and Registry v2 tags, inspect tag metadata, and pull directly.",
    "features.observability.title": "Observability",
    "features.observability.copy": "Combine container logs, boot logs, system logs, and stats snapshots for troubleshooting and status checks.",
    "features.converter.title": "Docker command converter",
    "features.converter.copy": "Rewrite common Docker commands into container / container-compose commands with less parameter guessing.",
    "install.kicker": "Independent distribution",
    "install.title": "Get the package from GitHub Releases.",
    "install.step1": "Open Release 0.1.0 and download the latest zip or dmg artifact.",
    "install.step2": "Extract it, move it to Applications, and approve the first-launch macOS security prompt.",
    "install.step3": "Install apple/container; install container-compose for Compose workflows.",
    "requirements.kicker": "Runtime requirements",
    "requirements.title": "Built for the modern macOS container runtime.",
    "requirements.macos": "26 or newer",
    "footer.copy": "Independently distributed macOS desktop console.",
    "footer.release": "Release 0.1.0"
  }
};

const toggle = document.querySelector("[data-lang-toggle]");
const currentLabel = document.querySelector("[data-lang-current]");
const storedLanguage = localStorage.getItem("containerdesktop-site-language");
let activeLanguage = storedLanguage === "en" ? "en" : "zh";

function applyLanguage(language) {
  activeLanguage = language;
  document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.dataset.i18n;
    const value = translations[language][key];
    if (value) {
      node.textContent = value;
    }
  });
  currentLabel.textContent = language === "zh" ? "English" : "中文";
  localStorage.setItem("containerdesktop-site-language", language);
}

toggle.addEventListener("click", () => {
  applyLanguage(activeLanguage === "zh" ? "en" : "zh");
});

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
      }
    });
  },
  { threshold: 0.12 }
);

document.querySelectorAll(".reveal").forEach((node) => observer.observe(node));
applyLanguage(activeLanguage);
