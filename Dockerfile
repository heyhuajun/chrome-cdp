# =============================================================
# chrome-cdp: Lightweight Chrome with CDP + VNC
# =============================================================
# 
# 用途: 给 Agent 用 CDP 协议控制的 Chrome 容器
# 特点: 
#   - 镜像体积小 (~500MB，对比 cdp-chrome-pro 3.57GB)
#   - 单 Chrome 实例（不引入 3-slot 复杂度）
#   - 完整 VNC 远程管理（noVNC web + VNC 客户端）
#   - CDP 9222 直连（Playwright/Puppeteer/opencli 都用）
#   - 内置 opencli CLI 工具
#
# 构建: docker build -t heyhuajun/chrome-cdp:latest .
# 跑:   docker run -d -p 6080:6080 -p 9222:9222 heyhuajun/chrome-cdp:latest
# =============================================================

FROM debian:13-slim

# ============================================
# 元数据
# ============================================
LABEL org.opencontainers.image.title="chrome-cdp" \
      org.opencontainers.image.description="Lightweight Chrome with CDP + VNC for agent automation" \
      org.opencontainers.image.source="https://github.com/heyhuajun/chrome-cdp" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="heyhuajun"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:99 \
    CHROME_VERSION=stable

# ============================================
# 1. 基础系统工具
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        apt-transport-https \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libc6 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libexpat1 \
        libfontconfig1 \
        libgbm1 \
        libgcc-s1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libstdc++6 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxrandr2 \
        libxrender1 \
        libxss1 \
        libxtst6 \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 2. X11 虚拟显示 + VNC 套件
# ============================================
# 选这套而不是 selkies，因为：
#   - selkies 走 WebRTC，不支持 CDP 9222
#   - Xvfb+x11vnc+novnc 才能让 Chrome 在 X11 模式下支持 CDP
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        python3 \
        python3-pip \
        python3-numpy \
        socat \
        novnc \
        websockify \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 3. Google Chrome 稳定版
# ============================================
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 4. Node.js + opencli（最新版）
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        nodejs \
        npm \
    && npm install -g @jackwener/opencli \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# 5. 应用配置
# ============================================
WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
COPY config/ /app/config/
RUN chmod +x /app/entrypoint.sh

# ============================================
# 6. 健康检查（指向 CDP 9222）
# ============================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -sf http://localhost:9222/json/version >/dev/null 2>&1 || exit 1

# ============================================
# 7. 端口声明
# ============================================
# 6080 - noVNC (Web VNC)
# 5900 - x11vnc (VNC 客户端)
# 9222 - Chrome DevTools Protocol (CDP)
EXPOSE 6080 5900 9222

# ============================================
# 8. Profiles 数据卷（持久化 cookie/history）
# ============================================
VOLUME ["/profiles"]

# ============================================
# 9. 启动
# ============================================
ENTRYPOINT ["/app/entrypoint.sh"]
