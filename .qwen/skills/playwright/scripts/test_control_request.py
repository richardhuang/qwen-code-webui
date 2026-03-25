#!/usr/bin/env python3
"""
Test script for control request functionality
Tests that tool approval dialog appears when AI tries to execute a command in default mode
"""

import asyncio
import sys
import os
import time
from playwright.async_api import async_playwright

# Configuration
FRONTEND_URL = os.environ.get('FRONTEND_URL', 'http://localhost:3000')
TIMEOUT = int(os.environ.get('TIMEOUT', 60000))  # 60 seconds default

async def test_control_request():
    """Test that control request dialog appears"""
    print(f"Testing control request functionality at {FRONTEND_URL}")
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()
        
        try:
            # Navigate to the app
            print("Navigating to app...")
            await page.goto(FRONTEND_URL, wait_until='networkidle', timeout=30000)
            
            # Wait for the page to load
            await page.wait_for_timeout(2000)
            
            # Take initial screenshot
            screenshots_dir = os.path.join(os.path.dirname(__file__), '..', '..', '..', '..', 'screenshots')
            os.makedirs(screenshots_dir, exist_ok=True)
            
            await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_1_initial.png'))
            print("Initial screenshot saved")
            
            # Check if we need to select a project first
            print("Checking for project selection...")
            
            # Wait for projects to load
            await page.wait_for_timeout(2000)
            
            # Look for project buttons (they have folder icons and project paths)
            project_button_selectors = [
                'button:has-text("/Users")',
                'button:has-text("workspace")',
                'button[class*="border"]',  # Project buttons have border class
            ]
            
            project_clicked = False
            for selector in project_button_selectors:
                try:
                    buttons = await page.query_selector_all(selector)
                    if buttons and len(buttons) > 0:
                        print(f"Found {len(buttons)} buttons with selector: {selector}")
                        # Click the first project button
                        await buttons[0].click()
                        await page.wait_for_timeout(2000)
                        await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_2_project_selected.png'))
                        print("Project selected")
                        project_clicked = True
                        break
                except Exception as e:
                    print(f"Error finding buttons: {e}")
            
            if not project_clicked:
                print("No project buttons found, taking screenshot...")
                await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_no_projects.png'))
            
            # Find the input field and type a message
            print("Finding input field...")
            input_selectors = [
                'textarea[placeholder*="message"]',
                'textarea[placeholder*="Ask"]',
                'textarea[placeholder*="Type"]',
                'textarea',
            ]
            
            input_field = None
            for selector in input_selectors:
                try:
                    input_field = await page.wait_for_selector(selector, timeout=3000)
                    if input_field:
                        print(f"Found input with selector: {selector}")
                        break
                except:
                    pass
            
            if not input_field:
                print("Could not find input field, taking screenshot...")
                await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_no_input.png'))
                return False
            
            # Type a message that will trigger a tool call
            message = "Execute hostname command"
            print(f"Typing message: {message}")
            await input_field.fill(message)
            await page.wait_for_timeout(500)
            
            # Take screenshot before sending
            await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_3_before_send.png'))
            
            # Find and click send button
            print("Finding send button...")
            send_selectors = [
                'button:has-text("Send")',
                'button[type="submit"]',
                'button:has(svg)',  # Button with icon
            ]
            
            send_button = None
            for selector in send_selectors:
                try:
                    send_button = await page.wait_for_selector(selector, timeout=2000)
                    if send_button:
                        # Check if button is enabled
                        is_disabled = await send_button.get_attribute('disabled')
                        if not is_disabled:
                            print(f"Found send button with selector: {selector}")
                            break
                        else:
                            send_button = None
                except:
                    pass
            
            if send_button:
                await send_button.click()
                print("Message sent, waiting for response...")
            else:
                # Try pressing Enter
                print("No send button found, trying Enter key...")
                await input_field.press('Enter')
            
            # Wait for the control request dialog to appear
            print("Waiting for control request dialog...")
            
            # Look for the dialog with various selectors
            dialog_selectors = [
                'text="Tool Approval Required"',
                'text="Approve"',
                'text="Reject"',
                '[class*="ControlRequest"]',
                'button:has-text("Approve")',
            ]
            
            dialog_found = False
            start_time = time.time()
            
            while time.time() - start_time < 60:  # Wait up to 60 seconds
                for selector in dialog_selectors:
                    try:
                        element = await page.wait_for_selector(selector, timeout=1000)
                        if element:
                            dialog_found = True
                            print(f"Found dialog with selector: {selector}")
                            break
                    except:
                        pass
                
                if dialog_found:
                    break
                    
                await page.wait_for_timeout(2000)
                elapsed = int(time.time() - start_time)
                if elapsed % 10 == 0:
                    print(f"Waiting for dialog... ({elapsed}s)")
                    await page.screenshot(path=os.path.join(screenshots_dir, f'control_test_waiting_{elapsed}s.png'))
            
            if dialog_found:
                print("SUCCESS: Control request dialog appeared!")
                
                # Take screenshot of the dialog
                await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_4_dialog.png'))
                print("Dialog screenshot saved")
                
                # Test keyboard shortcut - press Enter to approve
                print("Testing keyboard shortcut: pressing Enter to approve...")
                await page.keyboard.press('Enter')
                print("Pressed Enter key")
                
                # Wait for response
                await page.wait_for_timeout(5000)
                await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_5_after_approve.png'))
                print("After approve screenshot saved")
                
                return True
            else:
                print("FAILED: Control request dialog did not appear within 60 seconds")
                await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_failed.png'))
                return False
                
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()
            await page.screenshot(path=os.path.join(screenshots_dir, 'control_test_error.png'))
            return False
        finally:
            await browser.close()

if __name__ == '__main__':
    result = asyncio.run(test_control_request())
    sys.exit(0 if result else 1)