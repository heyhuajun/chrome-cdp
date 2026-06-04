# 架构设计

## 容器内部架构

```
┌─────────────────────────────────────────────────────────────┐
│  chrome-cdp 容器 (基于 debian:13-slim)                       │
│                                                              │
│  ┌──────────────┐                                            │
│  │   Xvfb :99   │ ← 1280x720x24 虚拟显示                    │
│  └──────┬───────┘                                            │
│         │ DISPLAY=:99                                        │
│         ↓                                                    │
│  ┌──────────────┐        ┌──────────────┐                   │
│  │  x11vnc :5900│←───────│  noVNC :6080 │ ← Web VNC        │
│  └──────────────┘        └──────────────┘                   │
│         ↑                                                    │
│         │ DISPLAY=:99                                        │
│  ┌──────┴────────────────────────────────┐                  │
│  │  Google Chrome (单实例)               │                  │
│  │    --remote-debugging-port=9222       │ ← CDP            │
│  │    --user-data-dir=/profiles          │                  │
│  └──────┬────────────────────────────────┘                  │
│         │                                                    │
│  ┌──────┴──────┐                                            │
│  │ /profiles/  │ ← Cookie, history, bookmarks                │
│  └─────────────┘                                            │
│                                                              │
│  ┌──────────────┐                                            │
│  │  opencli     │ ← CLI 工具 (CDP 封装)                     │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

## 启动顺序

1. **Xvfb** 启虚拟显示（`:99`，1280x720）
2. **x11vnc** 把 Xvfb 显示桥接到 VNC 5900 端口
3. **noVNC** 把 VNC 转 WebSocket，Web 端 6080 可访问
4. **Chrome** 以 `DISPLAY=:99` 启动 → 用 X11 渲染 → 同时开 CDP 9222

## 关键设计决策

### 1. 为什么用 X11 模式（不是 wayland / headless）？

- **CDP 9222 必须**：Chrome 在 wayland 模式下 `--remote-debugging-port` 被忽略
- **VNC 必备**：要远程登录管理（看截图、操作鼠标）
- **headless 不能 VNC**：headless 没有真实显示
- **X11 三件套（Xvfb + x11vnc + noVNC）** 是当前唯一能同时满足 VNC + CDP 的方案

### 2. 为什么不用 LinuxServer.io 官方镜像？

- 官方 lsio chrome 用 **selkies (WebRTC)** 替代传统 VNC
- selkies 不支持 CDP 9222（前面已验证）
- 自己用 debian:13-slim 装 Xvfb 套件更轻量、更可控

### 3. 为什么砍掉 cdp-chrome-pro 的 3-slot 架构？

- 实际生产中 **8000 API 调用 = 0**（之前已统计）
- 3-slot 复杂逻辑占内存 + 启动慢
- 多 Agent 隔离直接用 **多容器** 解决（每个 Agent 一个 chrome-cdp 容器）

## 数据流

### Agent 调用流程

```
Agent 代码
   ↓ (HTTP /json/version)
chrome-cdp 容器
   ↓ (返回 webSocketDebuggerUrl)
Agent 代码
   ↓ (WebSocket 连接)
chrome-cdp 容器
   ↓ (CDP 命令：Page.navigate, DOM.getDocument, ...)
chrome-cdp 容器
   ↓ (返回 JSON-RPC 响应)
Agent 代码
```

### VNC 远程管理流程

```
人类浏览器
   ↓ (HTTP ws://host:6080)
chrome-cdp noVNC
   ↓ (WebSocket)
chrome-cdp x11vnc
   ↓ (VNC 协议)
chrome-cdp Xvfb
   ↓ (X11 协议)
chrome-cdp Chrome
```

## 性能特征

| 维度 | 数值 |
|---|---|
| 镜像体积 | ~500MB |
| 启动时间 | ~10s（包含 Xvfb + x11vnc + Chrome 初始化） |
| 内存占用（空闲）| ~200MB |
| 内存占用（开 1 个 page）| ~300MB |
| 内存占用（多 page）| ~500-800MB |
| CPU 占用（空闲）| <1% |
| CPU 占用（复杂页面）| 5-15% |

## 安全考虑

- VNC 默认**无密码**（`-nopw`），仅适合内网/容器网络
- CDP 9222 默认监听 `0.0.0.0`，**任何能访问到 9222 端口的都能控制 Chrome**
- 生产环境建议：
  - 用防火墙限制 6080/5900/9222 仅内网访问
  - 或者用 SSH 端口转发
  - 或者放 reverse proxy 加认证
