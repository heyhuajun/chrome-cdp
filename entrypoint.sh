#!/bin/bash
# =============================================================
# entrypoint.sh - chrome-cdp 启动脚本
# =============================================================
# 启动顺序：
#   1. 清理残留锁
#   2. 启动 Xvfb 虚拟显示
#   3. 启动 x11vnc（VNC 服务）
#   4. 启动 noVNC（Web VNC）
#   5. 启动 Chrome（X11 模式 + CDP 9222）
# =============================================================
set -e

PROFILES_DIR=${PROFILES_DIR:-/profiles}
# WINDOW_SIZE 格式: "WIDTH,HEIGHT"（用户友好），Xvfb 需要 "WxHxD"
WINDOW_SIZE=${WINDOW_SIZE:-1280,720}
WIDTH=$(echo $WINDOW_SIZE | cut -d, -f1)
HEIGHT=$(echo $WINDOW_SIZE | cut -d, -f2)
CHROME_FLAGS=${CHROME_FLAGS:-""}

echo "=========================================="
echo "  chrome-cdp 启动中..."
echo "=========================================="
echo "  Display:       :99"
echo "  noVNC:         http://localhost:6080"
echo "  VNC:           localhost:5900"
echo "  CDP:           http://localhost:9222"
echo "  Profiles:      $PROFILES_DIR"
echo "  Window size:   ${WIDTH}x${HEIGHT}"
echo "=========================================="

# ============================================
# 1. 清理残留锁
# ============================================
mkdir -p "$PROFILES_DIR"
rm -f /tmp/.X99-lock || true
rm -f "$PROFILES_DIR"/SingletonLock \
      "$PROFILES_DIR"/SingletonSocket \
      "$PROFILES_DIR"/SingletonCookie || true

# ============================================
# 2. 启动 Xvfb 虚拟显示
# ============================================
echo "[1/4] 启动 Xvfb 虚拟显示..."
Xvfb :99 -screen 0 ${WIDTH}x${HEIGHT}x24 -ac -nolisten tcp &
XVFB_PID=$!
sleep 2

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb 启动失败"
    exit 1
fi

# ============================================
# 3. 启动 VNC 套件
# ============================================
echo "[2/4] 启动 x11vnc..."
x11vnc -display :99 -forever -shared -nopw -rfbport 5900 &
X11VNC_PID=$!
sleep 1

echo "[2/4] 启动 noVNC（Web VNC）..."
websockify --web=/usr/share/novnc 6080 localhost:5900 &
NOVNC_PID=$!
sleep 1

# ============================================
# 4. 启动 Chrome
# ============================================
echo "[3/4] 启动 Chrome（X11 模式）..."

export DISPLAY=:99
export HOME="$PROFILES_DIR"

CHROME_CMD="google-chrome \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --disable-software-rasterizer \
    --window-size=${WIDTH},${HEIGHT} \
    --remote-debugging-port=9222 \
    --remote-debugging-address=0.0.0.0 \
    --remote-allow-origins=* \
    --user-data-dir=${PROFILES_DIR} \
    --no-first-run"

# 预装扩展（如果存在）
EXTENSIONS_DIR="/app/extensions"
if [ -d "$EXTENSIONS_DIR" ]; then
    for ext_dir in "$EXTENSIONS_DIR"/*/; do
        if [ -f "${ext_dir}manifest.json" ]; then
            CHROME_CMD="$CHROME_CMD --load-extension=${ext_dir}"
        fi
    done
fi

CHROME_CMD="$CHROME_CMD ${CHROME_FLAGS}"

echo "执行: $CHROME_CMD"
$CHROME_CMD > /var/log/chrome.log 2>&1 &
CHROME_PID=$!

# ============================================
# 5. 等待 Chrome 起来
# ============================================
echo "[4/4] 等待 Chrome 启动..."
sleep 3

# 验证 Chrome 是否在跑
if ! kill -0 $CHROME_PID 2>/dev/null; then
    echo "ERROR: Chrome 启动失败，查看日志："
    cat /var/log/chrome.log
    exit 1
fi

# 验证 CDP 9222 是否在听
for i in 1 2 3 4 5; do
    if curl -sf http://localhost:9222/json/version >/dev/null 2>&1; then
        echo ""
        echo "=========================================="
        echo "  ✅ chrome-cdp 启动成功！"
        echo "=========================================="
        echo "  🌐 noVNC (Web VNC):  http://localhost:6080"
        echo "  🖥️  VNC 客户端:       localhost:5900"
        echo "  🔌 CDP (Agent 调用): http://localhost:9222"
        echo "  💻 opencli:           opencli --help"
        echo "=========================================="
        echo ""
        break
    fi
    echo "  等待 CDP 端口... (${i}/5)"
    sleep 2
done

# ============================================
# 6. 优雅退出处理
# ============================================
cleanup() {
    echo "收到退出信号，关闭进程..."
    kill $CHROME_PID 2>/dev/null || true
    kill $NOVNC_PID 2>/dev/null || true
    kill $X11VNC_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# ============================================
# 7. 阻塞保持容器运行
# ============================================
echo "容器运行中，按 Ctrl+C 退出..."
wait
