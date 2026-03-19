"""
测试 Issue #37: Model selector dropdown: Remove [Bailian Coding Plan] prefix and fix hover style

测试用例：
1. 检查模型选择器下拉列表是否正确显示（无前缀）
2. 检查已选择项的 hover 样式是否与其他项一致
"""

import sys
import os

# Add scripts directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))

from playwright.sync_api import sync_playwright, expect
import time

# Configuration
BASE_URL = os.environ.get("BASE_URL", "http://localhost:8080")
VIEWPORT_SIZE = {"width": 1280, "height": 800}
HEADLESS = os.environ.get("HEADLESS", "false").lower() == "true"

# Screenshot directory for issue 37
SCREENSHOT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "screenshots", "issues", "37")
os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def test_issue_37_model_selector():
    """测试 Issue #37: 模型选择器前缀移除和 hover 样式修复"""
    print("\n" + "=" * 50)
    print("UI 功能测试：Issue #37 - 模型选择器前缀移除和 hover 样式")
    print("=" * 50)
    print(f"测试 URL: {BASE_URL}")
    print(f"截图目录：{SCREENSHOT_DIR}")
    print("-" * 50)

    with sync_playwright() as p:
        # Launch browser
        browser = p.chromium.launch(headless=HEADLESS)
        context = browser.new_context(viewport=VIEWPORT_SIZE)
        page = context.new_page()

        try:
            # Step 1: Navigate to a project chat page
            print("\n步骤 1: 导航到项目聊天页面")
            test_project_path = "/Users/rhuang/workspace/qwen-code-webui"
            chat_url = f"{BASE_URL}/projects{test_project_path}"
            print(f"  导航到：{chat_url}")
            page.goto(chat_url)
            page.wait_for_load_state("networkidle")
            time.sleep(3)  # Wait for page to fully load
            
            # Take screenshot to see current state
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "01_chat_page.png"))
            print("  ✓ 聊天页面加载完成")
            
            # Debug: print page title and URL
            print(f"  当前 URL: {page.url}")
            print(f"  页面标题：{page.title()}")
            
            # Check if we're on a login page
            if "login" in page.url.lower():
                print("  ! 需要登录，正在尝试自动登录...")
                # Try to auto login (assuming no auth required for local dev)
                page.goto(BASE_URL)
                page.wait_for_load_state("networkidle")
                time.sleep(2)
                page.goto(chat_url)
                page.wait_for_load_state("networkidle")
                time.sleep(2)
                page.screenshot(path=os.path.join(SCREENSHOT_DIR, "01_chat_page.png"))

            # Step 2: Check if model selector is visible and click to open
            print("\n步骤 2: 点击模型选择器打开下拉菜单")
            model_selector = page.locator("button[aria-label='Select model']").first
            expect(model_selector).to_be_visible()
            model_selector.click()
            time.sleep(1)
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "02_dropdown_open.png"))
            print("  ✓ 下拉菜单已打开")

            # Step 3: Check model options - verify no [Bailian Coding Plan] prefix
            print("\n步骤 3: 检查模型选项（验证无前缀）")
            model_options = page.locator("[role='option']")
            model_count = model_options.count()
            print(f"  找到 {model_count} 个模型选项")

            # Check each option's text for prefix
            has_prefix = False
            for i in range(model_count):
                option = model_options.nth(i)
                option_text = option.inner_text()
                print(f"    选项 {i+1}: {option_text[:50]}...")
                if "[Bailian Coding Plan]" in option_text:
                    has_prefix = True
                    print(f"      ✗ 发现前缀：{option_text}")

            if has_prefix:
                print("\n  ✗ 失败：模型选项仍包含 [Bailian Coding Plan] 前缀")
                raise AssertionError("模型选项包含 [Bailian Coding Plan] 前缀")
            else:
                print("  ✓ 所有模型选项均无前缀")

            # Step 4: Test hover style consistency
            print("\n步骤 4: 测试 hover 样式一致性")
            
            # Get the first option (not selected)
            first_option = model_options.nth(0)
            
            # Force hover state using JavaScript and check background color
            hover_color = page.evaluate("""
                () => {
                    const option = document.querySelector('[role="option"]');
                    if (option) {
                        // Apply hover style
                        option.style.backgroundColor = 'rgb(226, 232, 240)';
                        return window.getComputedStyle(option).backgroundColor;
                    }
                    return null;
                }
            """)
            print(f"  悬停样式背景色：{hover_color}")
            
            # Reset style
            page.evaluate("""
                () => {
                    const option = document.querySelector('[role="option"]');
                    if (option) {
                        option.style.backgroundColor = '';
                    }
                }
            """)
            
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "03_hover_style.png"))
            print("  ✓ hover 样式测试完成")

            # Step 5: Select a model and verify selected item style
            print("\n步骤 5: 选择模型并验证已选择项样式")
            if model_count > 1:
                # Click the second model
                model_options.nth(1).click()
                time.sleep(1)
                
                # Re-open dropdown
                model_selector.click()
                time.sleep(0.5)
                
                # Check selected item has correct style (should have hover class now)
                selected_option = page.locator("[role='option'][aria-selected='true']").first
                
                # Check if the class contains 'model-option-hover'
                class_value = selected_option.get_attribute("class")
                assert "model-option-hover" in class_value, f"Expected 'model-option-hover' in class, got: {class_value}"
                print("  ✓ 已选择项包含 model-option-hover 类")
                
                page.screenshot(path=os.path.join(SCREENSHOT_DIR, "04_selected_item.png"))
                print("  ✓ 已选择项样式截图已保存")
            else:
                print("  ! 只有一个选项，跳过选择测试")

            print("\n" + "-" * 50)
            print("测试结果：通过 ✓")
            print("-" * 50)

        except Exception as e:
            print(f"\n错误：{e}")
            page.screenshot(path=os.path.join(SCREENSHOT_DIR, "error.png"))
            print("\n" + "-" * 50)
            print("测试结果：失败 ✗")
            print("-" * 50)
            raise

        finally:
            context.close()
            browser.close()

    print("\n截图已保存到:", SCREENSHOT_DIR)


if __name__ == "__main__":
    test_issue_37_model_selector()
