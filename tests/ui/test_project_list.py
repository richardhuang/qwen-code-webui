"""
测试项目列表显示功能

测试用例：
1. 访问首页检查项目列表是否正确显示
"""

import sys
import os
from playwright.sync_api import sync_playwright

# Configuration
BASE_URL = os.environ.get("BASE_URL", "http://192.168.31.159:3000")
VIEWPORT_SIZE = {"width": 1280, "height": 800}
HEADLESS = os.environ.get("HEADLESS", "false").lower() == "true"

# Screenshot directory
SCREENSHOT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "screenshots")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def test_project_list():
    """测试项目列表显示"""
    print("\n" + "=" * 50)
    print("UI 功能测试：项目列表显示")
    print("=" * 50)
    print(f"测试 URL: {BASE_URL}")
    print(f"截图目录: {SCREENSHOT_DIR}")
    print("-" * 50)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=HEADLESS)
        context = browser.new_context(viewport=VIEWPORT_SIZE)
        page = context.new_page()

        try:
            # Step 1: Navigate to home page
            print("\n步骤 1: 访问首页")
            page.goto(BASE_URL, timeout=30000)
            page.wait_for_load_state("networkidle", timeout=10000)
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "test_project_list_01.png"))
            print("  ✓ 截图保存: test_project_list_01.png")

            # Step 2: Check for project list
            print("\n步骤 2: 检查项目列表")
            
            # Wait a bit for the page to fully render
            time.sleep(2)
            
            # Check if there are any project cards or project items
            project_selectors = [
                ".project-card",
                ".project-item", 
                "[data-testid='project-card']",
                ".project-list-item",
                "a[href^='/projects/']"
            ]
            
            found_projects = False
            for selector in project_selectors:
                count = page.locator(selector).count()
                if count > 0:
                    print(f"  ✓ 找到 {count} 个项目 (selector: {selector})")
                    found_projects = True
                    break
            
            if not found_projects:
                # Check page content for clues
                page_content = page.content()
                print("  ⚠ 未找到项目元素，检查页面内容...")
                
                # Look for any links that might be projects
                all_links = page.locator("a").all()
                project_links = [a for a in all_links if "/projects/" in (a.get_attribute("href") or "")]
                if project_links:
                    print(f"  ✓ 找到 {len(project_links)} 个项目链接")
                    found_projects = True
                else:
                    print("  ✗ 未找到任何项目链接")
                    # Print page text for debugging
                    page_text = page.inner_text("body")
                    print(f"\n页面内容预览:\n{page_text[:500]}...")
            
            # Take final screenshot
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "test_project_list_02.png"), full_page=True)
            print("  ✓ 截图保存: test_project_list_02.png (full page)")

            print("\n" + "-" * 50)
            if found_projects:
                print("测试结果: ✓ 通过 - 项目列表正常显示")
            else:
                print("测试结果: ✗ 失败 - 项目列表未显示")
            print("-" * 50)

        except Exception as e:
            print(f"\n✗ 测试失败: {e}")
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "test_project_list_error.png"))
            raise
        finally:
            browser.close()


if __name__ == "__main__":
    import time
    test_project_list()
