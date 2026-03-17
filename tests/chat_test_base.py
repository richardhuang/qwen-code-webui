"""
Base class for Chat UI testing with Playwright

This module provides a reusable framework for testing chat functionality
in the Qwen Code WebUI application.

Usage:
    from chat_test_base import ChatTestBase

    class MyTest(ChatTestBase):
        async def run_test(self):
            await self.setup()
            await self.select_project("my-project")
            await self.enable_webui_components()
            await self.enable_yolo_mode()
            await self.send_message("list files")
            await self.wait_for_tool("run_shell_command")
            # Add your assertions here
            await self.cleanup()

    if __name__ == "__main__":
        test = MyTest()
        result = asyncio.run(test.run_test())
"""

import asyncio
from playwright.async_api import async_playwright, Page, Browser, BrowserContext
import os
from datetime import datetime
from typing import Optional, List, Callable, Awaitable


class ChatTestBase:
    """
    Base class for Chat UI testing.
    
    Provides common functionality for:
    - Browser setup and teardown
    - Project selection
    - Settings configuration (WebUI Components, YOLO mode)
    - Message sending
    - Tool call waiting and verification
    - Screenshot capture
    """
    
    # Default configuration
    DEFAULT_BASE_URL = "http://localhost:3000"
    DEFAULT_VIEWPORT = {"width": 1280, "height": 800}
    DEFAULT_HEADLESS = False
    DEFAULT_TIMEOUT = 30000  # 30 seconds
    
    def __init__(
        self,
        test_name: str = "chat_test",
        base_url: Optional[str] = None,
        screenshot_dir: Optional[str] = None,
        headless: Optional[bool] = None,
    ):
        """
        Initialize the test base.
        
        Args:
            test_name: Name of the test (used for screenshot directory)
            base_url: URL of the application to test
            screenshot_dir: Directory to save screenshots
            headless: Whether to run browser in headless mode
        """
        self.test_name = test_name
        self.base_url = base_url or os.environ.get("BASE_URL", self.DEFAULT_BASE_URL)
        self.headless = headless if headless is not None else self.DEFAULT_HEADLESS
        
        # Set up screenshot directory
        if screenshot_dir:
            self.screenshot_dir = screenshot_dir
        else:
            # Default to tests/screenshots/{test_name}
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.screenshot_dir = os.path.join(project_root, "screenshots", test_name)
        
        # Ensure screenshot directory exists
        os.makedirs(self.screenshot_dir, exist_ok=True)
        
        # Browser state
        self.playwright = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None
        
        # Test state
        self.screenshot_counter = 0
        self.test_passed = False
        self.error_message: Optional[str] = None
    
    def get_screenshot_path(self, name: str) -> str:
        """Get full path for a screenshot file."""
        self.screenshot_counter += 1
        filename = f"{self.screenshot_counter:02d}_{name}.png"
        return os.path.join(self.screenshot_dir, filename)
    
    async def take_screenshot(self, name: str, full_page: bool = False) -> str:
        """
        Take a screenshot and save it.
        
        Args:
            name: Name for the screenshot
            full_page: Whether to capture the full page
            
        Returns:
            Path to the saved screenshot
        """
        path = self.get_screenshot_path(name)
        await self.page.screenshot(path=path, full_page=full_page)
        print(f"  📷 Screenshot saved: {path}")
        return path
    
    def log(self, message: str, level: str = "INFO"):
        """Log a message with timestamp."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        prefix = {"INFO": "ℹ️", "SUCCESS": "✓", "WARNING": "⚠️", "ERROR": "✗"}.get(level, "•")
        print(f"[{timestamp}] {prefix} {message}")
    
    async def setup(self):
        """
        Set up the browser and navigate to the application.
        
        Should be called at the beginning of the test.
        """
        self.log(f"Setting up test: {self.test_name}")
        self.log(f"Base URL: {self.base_url}")
        self.log(f"Screenshot dir: {self.screenshot_dir}")
        
        self.playwright = await async_playwright().start()
        self.browser = await self.playwright.chromium.launch(headless=self.headless)
        self.context = await self.browser.new_context(viewport=self.DEFAULT_VIEWPORT)
        self.page = await self.context.new_page()
        
        self.log("Browser started")
    
    async def cleanup(self):
        """
        Clean up browser resources.
        
        Should be called at the end of the test.
        """
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
        
        self.log("Browser closed")
    
    async def navigate_to_app(self):
        """Navigate to the application and wait for it to load."""
        self.log("Navigating to application...")
        await self.page.goto(self.base_url, wait_until="networkidle")
        await asyncio.sleep(3)  # Wait for React to render
        await self.take_screenshot("homepage")
        self.log("Application loaded", "SUCCESS")
    
    async def select_project(self, project_name: str) -> bool:
        """
        Select a project from the project list.
        
        Args:
            project_name: Name or partial path of the project to select
            
        Returns:
            True if project was selected, False otherwise
        """
        self.log(f"Selecting project: {project_name}")
        
        await asyncio.sleep(2)  # Wait for page to load
        
        # Look for project buttons
        project_buttons = await self.page.query_selector_all('button:has(svg[class*="h-5"])')
        
        target_button = None
        for btn in project_buttons:
            text = await btn.inner_text()
            if text and '/' in text and project_name in text:
                target_button = btn
                self.log(f"Found project: {text}")
                break
        
        if target_button:
            await target_button.click()
            await asyncio.sleep(3)
            await self.take_screenshot("project_selected")
            self.log(f"Project selected: {project_name}", "SUCCESS")
            return True
        else:
            self.log(f"Project not found: {project_name}", "WARNING")
            return False
    
    async def enable_webui_components(self) -> bool:
        """
        Enable the WebUI Components feature in settings.
        
        Returns:
            True if enabled successfully, False otherwise
        """
        self.log("Enabling WebUI Components...")
        
        # Find and click settings button
        settings_selectors = [
            'button[aria-label*="settings" i]',
            'button:has-text("Settings")',
        ]
        
        for selector in settings_selectors:
            btn = await self.page.query_selector(selector)
            if btn:
                await btn.click()
                await asyncio.sleep(1)
                break
        
        await self.take_screenshot("settings_opened")
        
        # Find and toggle WebUI Components
        toggle_selectors = [
            'button[role="switch"][aria-label*="WebUI Components"]',
            'button:has-text("WebUI Components")',
        ]
        
        for selector in toggle_selectors:
            toggle = await self.page.query_selector(selector)
            if toggle:
                aria_checked = await toggle.get_attribute('aria-checked')
                if aria_checked == 'false':
                    await toggle.click()
                    await asyncio.sleep(0.5)
                await self.take_screenshot("webui_components_enabled")
                await self.page.keyboard.press('Escape')
                await asyncio.sleep(1)
                self.log("WebUI Components enabled", "SUCCESS")
                return True
        
        self.log("Could not enable WebUI Components", "WARNING")
        return False
    
    async def enable_yolo_mode(self) -> bool:
        """
        Enable YOLO mode by cycling through permission modes.
        
        Returns:
            True if YOLO mode enabled, False otherwise
        """
        self.log("Enabling YOLO mode...")
        
        mode_selectors = [
            'button:has-text("normal mode")',
            'button:has-text("default mode")',
            'button:has-text("plan mode")',
            'button:has-text("yolo mode")',
            'button:has-text("Click to cycle")',
        ]
        
        mode_btn = None
        for selector in mode_selectors:
            mode_btn = await self.page.query_selector(selector)
            if mode_btn:
                break
        
        if mode_btn:
            for _ in range(5):  # Max 5 clicks to cycle
                text = await mode_btn.inner_text()
                if "yolo" in text.lower():
                    await self.take_screenshot("yolo_mode_enabled")
                    self.log("YOLO mode enabled", "SUCCESS")
                    return True
                
                await mode_btn.click()
                await asyncio.sleep(0.5)
                
                # Re-find button
                for selector in mode_selectors:
                    mode_btn = await self.page.query_selector(selector)
                    if mode_btn:
                        break
        
        self.log("Could not enable YOLO mode", "WARNING")
        return False
    
    async def send_message(self, message: str) -> bool:
        """
        Send a message in the chat input.
        
        Args:
            message: The message to send
            
        Returns:
            True if message was sent, False otherwise
        """
        self.log(f"Sending message: {message}")
        
        # Find chat input
        input_selectors = ['textarea', '[contenteditable="true"]', 'form textarea']
        
        chat_input = None
        for selector in input_selectors:
            try:
                chat_input = await self.page.wait_for_selector(selector, timeout=5000)
                if chat_input:
                    break
            except:
                continue
        
        if not chat_input:
            self.log("Could not find chat input", "ERROR")
            return False
        
        await chat_input.fill(message)
        await self.take_screenshot("message_typed")
        
        # Submit
        submit_btn = await self.page.query_selector('button[type="submit"]')
        if submit_btn:
            await submit_btn.click()
        else:
            await chat_input.press("Enter")
        
        self.log("Message sent", "SUCCESS")
        return True
    
    async def wait_for_tool(
        self,
        tool_name: str,
        timeout: int = 30,
        wait_after: int = 3
    ) -> bool:
        """
        Wait for a specific tool to appear in the chat.
        
        Args:
            tool_name: Name of the tool to wait for
            timeout: Maximum time to wait in seconds
            wait_after: Time to wait after tool appears
            
        Returns:
            True if tool was found, False if timeout
        """
        self.log(f"Waiting for tool: {tool_name}")
        
        for i in range(timeout):
            await asyncio.sleep(1)
            page_text = await self.page.inner_text('body')
            if tool_name in page_text:
                self.log(f"Found {tool_name} after {i+1}s", "SUCCESS")
                await asyncio.sleep(wait_after)
                return True
            if i % 5 == 4:  # Log every 5 seconds
                self.log(f"Still waiting... ({i+1}s)")
        
        self.log(f"Tool not found after {timeout}s: {tool_name}", "WARNING")
        return False
    
    async def get_toolcall_elements(self) -> List:
        """
        Get all tool call elements from the page.
        
        Returns:
            List of tool call elements
        """
        selectors = [
            '.toolcall-card',
            '.toolcall-container',
            '[class*="toolcall"]',
        ]
        
        elements = []
        for selector in selectors:
            found = await self.page.query_selector_all(selector)
            elements.extend(found)
        
        return list(set(elements))  # Remove duplicates
    
    async def check_duplicate_tool_names(self) -> List[str]:
        """
        Check for duplicate tool names in tool call headers.
        
        Returns:
            List of duplicate tool names found
        """
        self.log("Checking for duplicate tool names...")
        
        toolcall_elements = await self.get_toolcall_elements()
        duplicates = []
        
        for el in toolcall_elements:
            text = await el.inner_text()
            lines = text.split('\n')
            
            if len(lines) >= 2:
                first_line = lines[0].strip()
                second_line = lines[1].strip()
                
                if first_line and second_line and first_line == second_line:
                    duplicates.append(first_line)
                    self.log(f"Duplicate found: {first_line}", "WARNING")
        
        return duplicates
    
    async def get_toolcall_content(self) -> List[str]:
        """
        Get the text content of all tool call elements.
        
        Returns:
            List of tool call content strings
        """
        elements = await self.get_toolcall_elements()
        contents = []
        
        for el in elements:
            text = await el.inner_text()
            contents.append(text)
        
        return contents
    
    async def run_test(self) -> bool:
        """
        Run the test. Override this method in subclasses.
        
        Returns:
            True if test passed, False otherwise
        """
        raise NotImplementedError("Subclasses must implement run_test()")
    
    async def execute(self) -> bool:
        """
        Execute the test with setup and cleanup.
        
        Returns:
            True if test passed, False otherwise
        """
        try:
            await self.setup()
            self.test_passed = await self.run_test()
        except Exception as e:
            self.error_message = str(e)
            self.log(f"Test error: {e}", "ERROR")
            await self.take_screenshot("error")
            self.test_passed = False
        finally:
            await self.cleanup()
        
        return self.test_passed


class DuplicateToolNameTest(ChatTestBase):
    """
    Test for detecting duplicate tool name display in chat.
    
    This test verifies that tool names are not displayed twice
    in the same line (which was the issue in #17).
    """
    
    def __init__(
        self,
        test_command: str = "list open issues",
        expected_tool: str = "run_shell_command",
        project_name: str = "qwen-code-webui",
        **kwargs
    ):
        super().__init__(test_name="duplicate_tool_name_test", **kwargs)
        self.test_command = test_command
        self.expected_tool = expected_tool
        self.project_name = project_name
    
    async def run_test(self) -> bool:
        """Run the duplicate tool name test."""
        # Navigate to app
        await self.navigate_to_app()
        
        # Select project
        await self.select_project(self.project_name)
        
        # Enable WebUI Components
        await self.enable_webui_components()
        
        # Enable YOLO mode
        await self.enable_yolo_mode()
        
        # Send test message
        await self.send_message(self.test_command)
        
        # Wait for expected tool
        await self.wait_for_tool(self.expected_tool)
        
        # Take final screenshot
        await self.take_screenshot("response", full_page=True)
        
        # Check for duplicates
        duplicates = await self.check_duplicate_tool_names()
        
        if duplicates:
            self.log(f"FAIL: Found {len(duplicates)} duplicate tool names", "ERROR")
            return False
        else:
            self.log("PASS: No duplicate tool names found", "SUCCESS")
            return True


async def run_chat_test(test_class, **kwargs):
    """
    Convenience function to run a chat test.
    
    Args:
        test_class: The test class to instantiate and run
        **kwargs: Arguments to pass to the test class constructor
        
    Returns:
        True if test passed, False otherwise
    """
    test = test_class(**kwargs)
    return await test.execute()


if __name__ == "__main__":
    # Example usage
    result = asyncio.run(run_chat_test(DuplicateToolNameTest))
    print(f"\n{'='*60}")
    print(f"Test Result: {'PASSED ✓' if result else 'FAILED ✗'}")
    print(f"{'='*60}")