#!/usr/bin/env python3
"""
parallel-agents.py - 多 Agent 并行使用 chrome-cdp 示例

场景：
  多个 Agent 同时跑不同任务，各自从不同的 chrome-cdp 实例连接，
  互不干扰。

部署多个 chrome-cdp 实例：
  docker run -d --name chrome-1 -p 9222:9222 xy111a/chrome-cdp:latest
  docker run -d --name chrome-2 -p 9223:9222 xy111a/chrome-cdp:latest
  docker run -d --name chrome-3 -p 9224:9222 xy111a/chrome-cdp:latest

依赖：
  pip install playwright
"""

from playwright.sync_api import sync_playwright
import concurrent.futures
import time

# 三个独立 Chrome 实例的 CDP URL
CHROME_INSTANCES = [
    "http://localhost:9222",  # chrome-1
    "http://localhost:9223",  # chrome-2
    "http://localhost:9224",  # chrome-3
]


def agent_task(agent_id: int, cdp_url: str, task_url: str):
    """
    单个 Agent 任务：访问一个 URL 并返回 title
    """
    print(f"[Agent-{agent_id}] 启动，连接 {cdp_url}")
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(cdp_url)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = context.new_page()

        page.goto(task_url, wait_until="domcontentloaded", timeout=30000)
        title = page.title()
        print(f"[Agent-{agent_id}] ✅ {task_url} → {title}")

        return {"agent": agent_id, "url": task_url, "title": title}


def main():
    tasks = [
        (1, CHROME_INSTANCES[0], "https://www.google.com"),
        (2, CHROME_INSTANCES[1], "https://github.com"),
        (3, CHROME_INSTANCES[2], "https://news.ycombinator.com"),
    ]

    print(f"启动 {len(tasks)} 个 Agent 并行任务...")
    start = time.time()

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [
            executor.submit(agent_task, agent_id, cdp_url, url)
            for agent_id, cdp_url, url in tasks
        ]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]

    elapsed = time.time() - start
    print(f"\n✅ 全部完成，耗时 {elapsed:.2f}s")
    for r in results:
        print(f"  Agent-{r['agent']}: {r['title']}")


if __name__ == "__main__":
    main()
