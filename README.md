# AI-docker-Isolated

带独立代理网关的 Ubuntu 浏览器桌面、指纹浏览器与 AI CLI 开发环境。

基于 `lscr.io/linuxserver/webtop:ubuntu-xfce`（Ubuntu + XFCE + Selkies）。
默认语言为英语 `en_US.UTF-8`，时区为 `America/Los_Angeles`，自动处理夏令时。
本项目是共享宿主机内核的容器，不是独立虚拟机；当前浏览器安装包要求 **Linux x86_64 / amd64**。

## 预装内容

| 软件 | 安装来源 | 说明 |
| --- | --- | --- |
| AdsPower 8.9.23 | 官方 Linux deb | 需要自行登录，浏览器内核可能还需下载 |
| Ant Browser 1.8.0 | 官方 Release ZIP 内的 deb | 不附带浏览器内核，需按官方说明另行配置 |
| VirtualBrowser 2.4.0 | 官方 Release deb | 需要自行登录或完成产品配置 |
| Claude Code | 官方原生安装脚本 stable 分支 | `claude`，需自行认证 |
| Codex CLI 0.167.0 | 官方 npm 包 `@openai/codex` | `codex`，需自行认证 |
| Pi Agent 1.5.2 | 官方 npm 包 `@earendil-works/pi-coding-agent` | `pi`，需自行认证 |
| Node.js 24 / npm / Git | 官方 Node 镜像与 Ubuntu 软件源 | 提供命令行开发环境 |
| Cockpit Tools 1.3.81 | 官方 Linux deb，验证 SHA-256 | AI 账号管理桌面工具，非 Cockpit 服务器面板 |
| Agent Board | 官方源码固定提交 `c2a4e7e` + pnpm 依赖 | 默认 SQLite，也可显式配置 PostgreSQL |
| Antigravity IDE 2.6.0 | Google 官方 Linux x64 tarball，固定 SHA-256 | 桌面 IDE，命令 `antigravity-ide` |
| Antigravity CLI 1.5.6 | 官方独立 CLI，验证 manifest SHA-512 | 终端命令 `agy`，需自行登录 |
| Magpie 0.1.3962 | 官方 Linux GUI 二进制，验证 SHA-256 | 同时提供 CLI、TUI 和 Web 模式 |

以上是 Dockerfile 的安装目标，不代表已通过图形启动或账号登录验证。
不自动添加 `--no-sandbox`；遇到浏览器沙箱报错需要单独诊断。
Pi 使用官方 npm 安装方式并禁用依赖安装脚本，Node.js 24 满足其运行要求。

## 启动

前提：Linux Docker Engine、Compose v2、`/dev/net/tun`，以及宿主机可从 Docker 网桥访问的
SOCKS5 代理端口 `10810`。仅监听宿主机 `127.0.0.1` 的代理不能直接供容器使用。

```bash
git clone https://github.com/mengfei0053/AI-docker-Isolated.git
cd AI-docker-Isolated
cp .env.example .env
# 按需修改 .env 中的 PROJECTS_DIR，默认使用 ./workspace。
docker compose up -d --build
```

`PROJECTS_DIR` 会以读写方式挂载到 `/projects`，仅选择允许容器修改的目录。
桌面运行用户为 `abc`，UID/GID 默认 1000，具有容器内免密 sudo 权限。
项目名中的 Isolated 不代表虚拟机级安全：当前放宽了桌面的 seccomp/AppArmor，
并保留内网直连，不适合恶意代码或不可信多租户。

通过 **`https://<服务器IP>:3001`** 打开桌面并接受自签名证书。
现代浏览器的视频功能需要 HTTPS，3000 端口主要用于配合反向代理。
桌面终端中使用 `claude` 或 `codex`；GUI 应用从应用菜单启动。
`./config` 持久化桌面用户的主目录、应用配置及 CLI 登录数据，禁止提交到版本库。
安装软件和登录可能需要额外磁盘、内存和联网，实际占用不保证固定。

**安全警告：** 当前端口发布到所有网卡且没有配置登录保护。
只在可信网络使用，公网访问前务必添加认证和访问限制。
Webtop 桌面具有容器内管理权限，不适合运行恶意软件或不可信用户代码。

## 构建时联网

运行时透明代理不会作用于镜像拉取和 Docker 构建步骤。
基础镜像拉取失败需配置 Docker daemon / BuildKit 的代理；
仅在命令行设置 HTTP_PROXY 不能保证 Docker daemon 使用代理。
不要为此随意重启宿主机 Docker，以免影响其他服务。

RUN 步骤可以显式传入宿主机可达的代理地址（不能用构建容器的 127.0.0.1）：

```bash
docker compose build \
  --build-arg HTTP_PROXY=http://<宿主机可达IP>:10810 \
  --build-arg HTTPS_PROXY=http://<宿主机可达IP>:10810
```

这些构建参数不会被固化为运行时代理环境变量。

## 运行时代理边界

代理移到独立 `proxy-gateway` 服务，桌面共享其网络命名空间，
但不再拥有 NET_ADMIN、NET_RAW 或 TUN 设备，不能自行修改路由和防火墙。
网关先设置 OUTPUT 默认 DROP，再配置路由；桌面仅在网关健康后启动。
公网 IPv4 经 tun2socks 到宿主机 10810，IPv6 在命名空间内禁用。
普通 UDP/TCP 53 请求被转至网关 DNS 转发器，再以 TCP 经 TUN 查询 1.1.1.1，
避免 Docker 内置 DNS 由宿主机直连查询；不保证内网域名解析仍可用。

按要求仍放行 10/8、172.16/12、192.168/16 内网直连，不是“全部流量经过代理”。
内网代理、路由器或其他转发服务仍可成为间接公网出口，暂不纳入保证范围。
SOCKS 服务端是否再按规则直连也由宿主机代理配置决定。
安全边界不覆盖内核漏洞、宿主机管理员或 Docker socket 访问。

启动后运行 `bash scripts/test-network.sh` 检查直连阻断与模拟代理断开；
脚本仅临时阻断当前网关访问 10810，不关闭宿主机代理。
网关被 recreate 后请一并 recreate 桌面，避免桌面留在旧网络命名空间。
请在自己的宿主机和代理配置上执行动态测试，不应假设不同部署都具有相同结果。

```bash
docker exec ai-docker-isolated cat /etc/os-release
docker exec -u abc ai-docker-isolated claude --version
docker exec -u abc ai-docker-isolated codex --version
docker exec ai-docker-isolated curl --max-time 20 --noproxy '*' https://api.ipify.org
```

出口 IP 一致只验证该次 HTTP 请求，不证明 DNS、UDP、IPv6 或代理断开时无泄漏。

## WebRTC 策略（固化在 Dockerfile）

`policies/webrtc.json` 设置 `WebRtcIPHandling=disable_non_proxied_udp`，
构建时复制到 Chromium 和 Google Chrome 的系统 managed policy 目录。
它限制 WebRTC 网络路径，不等于关闭 WebRTC API，也不等于禁用所有 UDP。
DNS 继续由代理网关转发到 Cloudflare 1.1.1.1，无需更改桌面 Dockerfile。

重建并重新创建桌面容器后生效（会中断当前桌面会话）：

```bash
docker compose build webtop
docker compose up -d --no-deps webtop
```

在普通 Chromium 中打开 `chrome://policy`，点击 Reload policies，
确认 `WebRtcIPHandling` 的值正确且状态为 OK。
AdsPower、VirtualBrowser、Ant 的自带浏览器内核可能不读取这些目录，
需在各产品配置档中另设 WebRTC 禁用并进行 ICE 候选测试；不能视为已统一禁用。
桌面用户具有 sudo 权限，可修改系统策略，因此这不是防恶意程序的安全边界。

## 新增工具：Cockpit Tools 与 Agent Board

Cockpit Tools 从应用菜单或桌面启动，命令为 `cockpit-tools`。
默认数据在 `~/.cockpit_tools`（即 `/config/.cockpit_tools`），包含敏感账号资料，
与其管理的 CLI 配置一起保存在持久化主目录中。

Agent Board 安装在 `/opt/agent-board`，命令为 `agent-board`，桌面提供服务器启动图标。
没有创建或修改宿主机数据库，也没有复制宿主机看板的账号、数据库凭据或数据。
直接运行 `agent-board` 即可使用 SQLite，数据库默认为 `/config/.local/share/agent-board/agent-board.db`。如需 PostgreSQL，先准备独立数据库，再创建只有本人可读的配置文件：

```bash
mkdir -p ~/.config/agent-board
chmod 700 ~/.config/agent-board
# 编辑 ~/.config/agent-board/env，填写自己的数据库连接：
# DATABASE_URL='postgresql://USER:PASSWORD@HOST:5432/agent_board'
chmod 600 ~/.config/agent-board/env
agent-board
```

该文件作为可信 shell 配置加载，请勿放入不可信命令。
默认仅监听容器内 `127.0.0.1:8791`，运行后在容器浏览器打开该地址。启动器默认设置 `AGENT_BOARD_ALLOWED_ROOTS=/projects`，允许经 `/config/projects` 符号链接访问的挂载项目；可在可信配置中显式覆盖。
默认文件数据位于 `/config/.local/share/agent-board`。SQLite 备份请停止服务后复制数据库文件；PostgreSQL 内容须另行备份。切换 `DATABASE_URL` 不会自动迁移数据，PostgreSQL 连接失败也不会回退 SQLite。
本镜像已提供 Claude/Codex/Pi；各 CLI 需自行认证，Cursor 等其他 runner 需自行安装。
启动器直接使用 Node/tsx，不在启动时下载 pnpm；看板不是仅静态网页，需保持服务进程运行。

## Antigravity IDE 与 CLI

本项目安装完整代码编辑器 **Antigravity IDE** 和独立终端 Agent **agy**，
不额外安装官网的 Antigravity App。IDE 下载包来自官方下载页，CLI 来自官方更新清单。
IDE 的 SHA-256 为下载后固定的完整性校验值；CLI SHA-512 与官方 manifest 比对。

- 桌面双击 Antigravity IDE，或执行 `antigravity-ide /projects`。
- `antigravity` 是 IDE 命令的兼容别名，方便查找旧命令的集成工具。
- 在项目目录执行 `agy`，不是用 IDE 的文件启动命令冒充 CLI。
- 两者需要自行认证；安装成功不代表账号、订阅或地区权限可用。
- IDE 默认配置/扩展存放在 `/config/.config/Antigravity IDE` 和
  `/config/.antigravity-ide`；CLI 默认 HOME 为 `/config`，其用户配置随主目录持久化。
- `/opt/antigravity-ide` 与 `/usr/local/bin/agy` 为镜像内容；更新建议修改版本并重建，
  不自动加 `--no-sandbox` 或运行官方安装器的登录/后台更新步骤。

## Pi Agent

在桌面终端中进入项目后执行 `pi`，例如 `cd /projects/你的项目 && pi`。
使用 `/login` 配置支持的账号或 API 凭据；不复制宿主机的 Pi 登录和扩展。
默认用户 `abc` 的 HOME 为 `/config`，Pi 全局配置、认证、会话和扩展目录
`~/.pi/agent` 对应 `/config/.pi/agent`，随主目录持久化并纳入 config 备份。
不要使用 `sudo pi`，否则配置可能写入未持久化的 `/root`。
项目内 `.pi` 配置保存在项目目录，是否持久化取决于项目位于 `/projects` 或 `/config`。

## Magpie

桌面图标或终端 `magpie` 打开桌面应用；`magpie tui` 使用终端界面，
`magpie --help` 查看全部命令。同一官方 GUI 程序已包含这些入口，不需要另装 CLI 包。
Linux GUI 使用 WebKitGTK 4.1（当前 Webtop 依赖中已提供）。

默认设置、提供商密钥和配置档位于 `~/.config/magpie`，即持久化的
`/config/.config/magpie`。不要将该目录上传到公开仓库。
本项目不自动启动 Magpie，不导入提供商、不修改 Claude/Codex 的现有认证和模型配置，
也不对宿主机额外开放 Magpie 的网关或 Web 管理端口。
使用 Magpie 切换模型时可能改写相关 Agent 配置，建议先备份，并避免与 Cockpit Tools
同时修改同一个 Agent 的配置。

## 备份用户数据

先保存工作，再执行 `bash scripts/backup-config.sh`。
脚本短暂停止桌面，备份整个 `config`（不跟随指向 `/projects` 的软链接），
验证 zstd 和 tar 可读性，生成 SHA-256 文件，然后恢复原来运行的桌面。
默认保存到 `$HOME/backups/docker-webtop/`，目录权限 700、文件权限 600。
包含浏览器及 CLI 登录凭据；不要公开上传。此备份不包含 `/projects` 的其他项目，
也不包含容器可写层内手动安装的软件和未挂载数据。

## 官方来源

- [Webtop](https://github.com/linuxserver/docker-webtop)
- [AdsPower 下载](https://www.adspower.com/download)
- [Ant Browser 1.8.0](https://github.com/black-ant/Ant-Browser/releases/tag/V1.8.0)
- [VirtualBrowser 2.4.0](https://github.com/Virtual-Browser/VirtualBrowser/releases/tag/2.4.0)
- [Claude Code](https://github.com/anthropics/claude-code)
- [Codex](https://github.com/openai/codex)
- [Cockpit Tools 1.3.81](https://github.com/jlcodes99/cockpit-tools/releases/tag/v1.3.81)
- [Agent Board 固定源码](https://github.com/mengfei0053/agent-board/tree/c2a4e7e1e233db32ef0395875a794785d6eda503)
- [Antigravity 官方下载](https://antigravity.google/download/)
- [Antigravity 官方入门与 CLI 安装](https://antigravity.google/docs/getting-started/)
- [Magpie 官方项目](https://github.com/yetone/magpie)
- [Magpie 0.1.3962 官方安装包](https://github.com/yetone/magpie-releases/releases/tag/v0.1.3962)
