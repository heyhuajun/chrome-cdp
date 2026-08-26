# chrome-cdp

> Lightweight Chrome with CDP + VNC for agent automation

## 🎯 用途

为 AI Agent 提供浏览器自动化能力的 Docker 镜像：
- **CDP 9222** 端口供 Playwright / Puppeteer / opencli 程序化控制
- **VNC 6080/5900** 端口供人类远程登录管理
- **~500MB** 镜像体积（对比 cdp-chrome-pro 3.57GB 节省 86%）

## 🏗️ 架构

```
┌─────────────────────────────────────────┐
│  chrome-cdp 容器                        │
│                                         │
│  Xvfb :99 ─┬─ x11vnc → 5900             │  VNC 客户端
│            └─ noVNC  → 6080             │  Web VNC
│                                         │
│  Chrome (单实例, X11 模式)              │
│    --remote-debugging-port=9222         │  CDP
│    --user-data-dir=/profiles            │
│                                         │
│  opencli                                │  CLI 工具
└─────────────────────────────────────────┘
```

## 🚀 快速开始

### 1. 用 Docker Hub 镜像（推荐）

```bash
docker run -d \
    --name chrome-cdp \
    --restart unless-stopped \
    -p 6080:6080 \
    -p 5900:5900 \
    -p 9222:9222 \
    -v chrome-cdp-profiles:/profiles \
    xy111a/chrome-cdp:latest
```

### 2. 用 docker-compose

```bash
git clone https://github.com/xy111a/chrome-cdp.git
cd chrome-cdp
docker compose up -d
```

### 3. 自己构建

```bash
git clone https://github.com/xy111a/chrome-cdp.git
cd chrome-cdp
docker build -t xy111a/chrome-cdp:latest .
```

## 🔌 使用方式

### Web VNC 远程管理

打开浏览器访问：
```
http://localhost:6080
```

可以在 Web 上看到 Chrome 桌面，手动登录网站、调试等。

### CDP 协议调用（Agent 自动化）

#### Playwright

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://localhost:9222")
    page = browser.contexts[0].new_page()
    page.goto("https://example.com")
    print(page.title())
    browser.close()
```

#### opencli

```bash
# opencli 装在容器内，进入容器使用
docker exec -it chrome-cdp opencli github trending -f json

# 或者从宿主机调用（需要 opencli 在宿主机也装了）
opencli --cdp-url http://localhost:9222 zhihu hot -f table
```

#### 原始 CDP WebSocket

```python
import json
import websocket  # pip install websocket-client

# 1. 获取 WebSocket URL
import urllib.request
with urllib.request.urlopen("http://localhost:9222/json/version") as r:
    ws_url = json.loads(r.read())["webSocketDebuggerUrl"]

# 2. WebSocket 连
ws = websocket.create_connection(ws_url)

# 3. 发送 CDP 命令
ws.send(json.dumps({"id": 1, "method": "Page.navigate", "params": {"url": "https://example.com"}}))
print(ws.recv())
```

## 📊 端口

| 端口 | 服务 | 用途 |
|---|---|---|
| **6080** | noVNC | 浏览器访问 Web VNC（推荐） |
| **5900** | x11vnc | VNC 客户端直连 |
| **9222** | Chrome DevTools Protocol | Agent 程序化控制 |

## 🛠️ 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `PROFILES_DIR` | `/profiles` | Chrome profile 目录（cookie、历史记录） |
| `WINDOW_SIZE` | `1280,720` | 虚拟显示尺寸（宽,高） |
| `CHROME_FLAGS` | 空 | 额外 Chrome 启动参数 |
| `TZ` | `Asia/Shanghai` | 时区 |

### 示例：自定义窗口大小

```bash
docker run -d --name chrome-cdp \
    -e WINDOW_SIZE=1920,1080 \
    -p 6080:6080 -p 9222:9222 \
    xy111a/chrome-cdp:latest
```

### 示例：增加 Chrome 参数

```bash
docker run -d --name chrome-cdp \
    -e CHROME_FLAGS="--disable-web-security --user-agent=Mozilla/5.0..." \
    -p 6080:6080 -p 9222:9222 \
    xy111a/chrome-cdp:latest
```

## 🔄 多 Agent 并行部署

为多个 Agent 提供独立 Chrome 实例，**避免资源挤兑**：

```bash
# 方式 1：手动启动多个容器
docker run -d --name chrome-agent-1 -p 6080:6080 -p 9222:9222 xy111a/chrome-cdp:latest
docker run -d --name chrome-agent-2 -p 6081:6080 -p 9223:9222 xy111a/chrome-cdp:latest
docker run -d --name chrome-agent-3 -p 6082:6080 -p 9224:9222 xy111a/chrome-cdp:latest
```

```bash
# 方式 2：docker-compose scale
# (单实例绑定固定端口，scale 需要动态端口)
docker compose up -d --scale chrome-cdp=3
```

## 🆚 与 cdp-chrome-pro 对比

| 维度 | cdp-chrome-pro（旧） | chrome-cdp（新） |
|---|---|---|
| **镜像体积** | 3.57GB | ~500MB |
| **Chrome 版本** | 146.0.7680.177 | 146+ （跟随 stable） |
| **Slot 数量** | 3 个动态 | 1 个固定 |
| **Cookie 共享** | ✅ 跨 slot 共享 | ❌（不需要） |
| **Context Manager API** | ✅ 8000 端口 | ❌ 移除 |
| **CDP 端口** | 9222/19223/19224 | 9222 |
| **VNC** | ✅ 6080 | ✅ 6080 |
| **opencli** | ✅ | ✅ |
| **内存占用** | 300-500MB / 1 slot | 200-300MB |
| **启动进程数** | 60+ | 15 |

## 🧰 故障排查

### 容器启动后 9222 不通

```bash
# 看 Chrome 日志
docker logs chrome-cdp
docker exec chrome-cdp cat /var/log/chrome.log
```

### VNC 进不去

```bash
# 确认 6080/5900 在宿主机能访问
curl -I http://localhost:6080/
nc -zv localhost 5900
```

### CDP 连接被拒

Chrome 146+ 默认拒绝 HTTP 探测（CSRF 防护），但 WebSocket 协议不受影响。如果用 `curl http://localhost:9222/json/version` 失败是正常的，**用 WebSocket 客户端**（Playwright/Puppeteer）连接即可。

### 容器内 Chrome 卡住

```bash
# 看 Chrome 进程状态
docker exec chrome-cdp ps aux | grep chrome

# 强制重启容器
docker restart chrome-cdp
```

## 📜 License

MIT © heyhuajun

## 🔗 相关链接

- [Chrome DevTools Protocol 文档](https://chromedevtools.github.io/devtools-protocol/)
- [Playwright connectOverCDP](https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp)
- [opencli - Make any website your CLI](https://github.com/jackwener/opencli)
