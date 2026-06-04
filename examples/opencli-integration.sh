#!/bin/bash
# =============================================================
# opencli-integration.sh - 在 chrome-cdp 里用 opencli
# =============================================================
# 
# opencli 装在 chrome-cdp 容器内，封装了 CDP 调用，
# 让 CLI 直接抓取网站数据，无需写代码。
# =============================================================

CHROME_CONTAINER="chrome-cdp"

# ============================================
# 1. 基础用法
# ============================================
echo "=== 1. opencli help ==="
docker exec $CHROME_CONTAINER opencli --help 2>&1 | head -20

echo ""
echo "=== 2. GitHub Trending ==="
docker exec $CHROME_CONTAINER opencli github trending -f table 2>&1 | head -15

echo ""
echo "=== 3. 知乎热榜 ==="
docker exec $CHROME_CONTAINER opencli zhihu hot -f json 2>&1 | head -20

echo ""
echo "=== 4. Hacker News Top ==="
docker exec $CHROME_CONTAINER opencli hackernews top -f table 2>&1 | head -15

echo ""
echo "=== 5. 导出到 JSON 文件 ==="
docker exec $CHROME_CONTAINER opencli github trending -f json > /tmp/github-trending.json
echo "✅ 导出到 /tmp/github-trending.json:"
head -30 /tmp/github-trending.json
