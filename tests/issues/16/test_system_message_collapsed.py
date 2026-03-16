"""
Test Issue #16: System messages should be collapsed by default

This test verifies that system messages (init, result, etc.) display only
the header by default, without showing preview content, to maximize the
chat area for user conversations.
"""

import asyncio
from playwright.async_api import async_playwright
from pathlib import Path

# Configuration
BASE_URL = "http://localhost:8080"
SCREENSHOT_DIR = Path(__file__).parent.parent.parent.parent / "screenshots" / "issues" / "16"


async def test_system_message_collapsed():
    """Test that system messages are collapsed by default."""
    async with async_playwright() as p:
        # Launch browser
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context(viewport={"width": 1280, "height": 800})
        page = await context.new_page()

        test_results = []
        screenshots = []

        try:
            # Step 1: Navigate to the application
            print("Step 1: Navigate to the application...")
            await page.goto(BASE_URL, wait_until="networkidle")
            await page.wait_for_timeout(2000)

            # Take screenshot of initial state
            screenshot_path = SCREENSHOT_DIR / "01_project_selector.png"
            await page.screenshot(path=str(screenshot_path))
            screenshots.append(str(screenshot_path))
            print(f"  Screenshot saved: {screenshot_path}")

            # Step 2: Check if we're on project selector page
            print("Step 2: Check for project selector...")
            project_buttons = await page.locator('button:has-text("/")').all()
            print(f"  Found {len(project_buttons)} project buttons")

            if len(project_buttons) > 0:
                # Click the first project to enter chat
                print("  Clicking first project...")
                await project_buttons[0].click()
                await page.wait_for_timeout(3000)

                # Take screenshot after selecting project
                screenshot_path = SCREENSHOT_DIR / "02_chat_page.png"
                await page.screenshot(path=str(screenshot_path))
                screenshots.append(str(screenshot_path))

                # Step 3: Check for textarea (chat input)
                print("Step 3: Check for chat input...")
                textarea = page.locator('textarea').first
                if await textarea.count() > 0:
                    print("  Found chat input textarea")

                    # Send a test message
                    await textarea.fill("Hello, this is a test message")
                    await page.wait_for_timeout(500)

                    # Take screenshot before sending
                    screenshot_path = SCREENSHOT_DIR / "03_before_send.png"
                    await page.screenshot(path=str(screenshot_path))
                    screenshots.append(str(screenshot_path))

                    # Click send button
                    send_btn = page.locator('button[type="submit"]').first
                    if await send_btn.count() > 0:
                        await send_btn.click()
                        print("  Message sent, waiting for response...")
                        await page.wait_for_timeout(5000)

                        # Take screenshot after sending
                        screenshot_path = SCREENSHOT_DIR / "04_after_send.png"
                        await page.screenshot(path=str(screenshot_path))
                        screenshots.append(str(screenshot_path))

                # Step 4: Check for system messages
                print("Step 4: Check for system messages...")
                await page.wait_for_timeout(2000)

                # Look for system message elements (blue background)
                system_messages = await page.locator('[class*="bg-blue-50"], [class*="bg-blue-900"]').all()
                print(f"  Found {len(system_messages)} potential system message(s)")

                for i, msg in enumerate(system_messages):
                    msg_text = await msg.text_content() or ""
                    print(f"  Message {i+1} preview: {msg_text[:100]}...")

                    # Check if this is a system message (contains System, Result, Error, or init)
                    # Also check for ⚙ icon which indicates system messages
                    is_system_msg = ("System" in msg_text or "Result" in msg_text or 
                                    "init" in msg_text or "Error" in msg_text or
                                    "⚙" in msg_text)

                    if is_system_msg:
                        print(f"  System message {i+1} identified")

                        # Check if collapsed (has ▶ indicator and no preview content visible)
                        has_collapse_indicator = "▶" in msg_text
                        # Check for preview content (border-l-2 class indicates preview)
                        preview_elements = await msg.locator('.border-l-2').count()
                        has_preview = preview_elements > 0

                        # Take screenshot of this message
                        screenshot_path = SCREENSHOT_DIR / f"05_system_msg_{i+1}.png"
                        await msg.screenshot(path=str(screenshot_path))
                        screenshots.append(str(screenshot_path))

                        if has_collapse_indicator and not has_preview:
                            test_results.append({
                                "step": f"System message {i+1} collapsed",
                                "status": "PASS",
                                "details": "Message shows collapse indicator (▶) without preview content"
                            })
                            print(f"  ✓ System message {i+1} is properly collapsed")
                        elif not has_preview:
                            test_results.append({
                                "step": f"System message {i+1} state",
                                "status": "PASS",
                                "details": "Message has no preview content visible"
                            })
                            print(f"  ✓ System message {i+1} has no preview visible")
                        else:
                            test_results.append({
                                "step": f"System message {i+1} collapsed",
                                "status": "FAIL",
                                "details": f"has_collapse_indicator={has_collapse_indicator}, has_preview={has_preview}"
                            })
                            print(f"  ✗ System message {i+1} may show preview content")

                if len(system_messages) == 0:
                    print("  No system messages found")
                    test_results.append({
                        "step": "Find system messages",
                        "status": "INFO",
                        "details": "No system messages found - may need Qwen CLI configured"
                    })

            else:
                print("  No project buttons found")
                test_results.append({
                    "step": "Project selector",
                    "status": "INFO",
                    "details": "No projects available to select"
                })

            # Final screenshot
            screenshot_path = SCREENSHOT_DIR / "06_final_state.png"
            await page.screenshot(path=str(screenshot_path))
            screenshots.append(str(screenshot_path))

        except Exception as e:
            test_results.append({
                "step": "Test execution",
                "status": "FAIL",
                "details": str(e)
            })
            print(f"  Error: {e}")

        finally:
            await browser.close()

        # Print test report
        print("\n" + "=" * 50)
        print("UI Test Report - Issue #16")
        print("=" * 50)
        print(f"Test URL: {BASE_URL}")
        print(f"Test Steps: {len(test_results)}")
        passed = sum(1 for r in test_results if r["status"] == "PASS")
        failed = sum(1 for r in test_results if r["status"] == "FAIL")
        info = sum(1 for r in test_results if r["status"] == "INFO")
        print(f"Passed: {passed}, Failed: {failed}, Info: {info}")
        print("-" * 50)

        for result in test_results:
            status_icon = "✓" if result["status"] == "PASS" else ("ℹ" if result["status"] == "INFO" else "✗")
            print(f"  {status_icon} {result['step']}: {result['details']}")

        print("-" * 50)
        print("Screenshots:")
        for s in screenshots:
            print(f"  - {s}")
        print("=" * 50)

        return failed == 0


if __name__ == "__main__":
    asyncio.run(test_system_message_collapsed())