#!/usr/bin/env python3
"""
basic-usage.py - chrome-cdp 基础使用示例

演示：
  1. 连接 chrome-cdp 容器的 CDP 9222 端口
  2. 用 Playwright 浏览网页
  3. 截图、提取数据

依赖：
  pip install playwright
"""

from playwright.sync_api import sync_playwright
import sys

CDP_URL = "http://localhost:9222"  # chrome-cdp 默认 CDP 端口

def main():
    with sync_playwright() as p:
        # 1. 通过 CDP 连接到 chrome-cdp 容器
        print(f"连接到 {CDP_URL} ...")
        browser = p.chromium.connect_over_cdp(CDP_URL)
        print(f"✅ 连接成功，浏览器版本: {browser.version}")

        # 2. 获取或创建 context
        if browser.contexts:
            context = browser.contexts[0]
        else:
            context = browser.new_context()
        page = context.new_page()

        # 3. 浏览网页
        print("访问 https://example.com ...")
        page.goto("https://example.com", wait_until="networkidle")
        title = page.title()
        print(f"✅ 页面标题: {title}")

        # 4. 截图
        page.screenshot(path="example.png")
        print("✅ 截图已保存到 example.png")

        # 5. 提取数据
        heading = page.locator("h1").first.text_content()
        print(f"✅ H1 内容: {heading}")

        # 6. 关闭（注意：不要真的关闭浏览器，否则 chrome-cdp 容器要重启）
        # browser.close()
        print("\n⚠️  注意：不要调用 browser.close()，否则 chrome-cdp 容器内的 Chrome 会退出")
        print("    直接退出脚本即可，Chrome 继续在容器里运行")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)
