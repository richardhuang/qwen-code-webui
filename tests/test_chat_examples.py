"""
Example tests using ChatTestBase

This file demonstrates how to use the ChatTestBase class
for testing chat functionality.
"""

import asyncio
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from chat_test_base import ChatTestBase, DuplicateToolNameTest, run_chat_test


class CustomChatTest(ChatTestBase):
    """
    Example custom test that demonstrates the full capabilities
    of ChatTestBase.
    """
    
    def __init__(self, **kwargs):
        super().__init__(test_name="custom_chat_test", **kwargs)
    
    async def run_test(self) -> bool:
        """Run a custom chat test."""
        # Step 1: Navigate to app
        await self.navigate_to_app()
        
        # Step 2: Select project
        project_selected = await self.select_project("qwen-code-webui")
        if not project_selected:
            self.log("Could not select project, using default", "WARNING")
        
        # Step 3: Enable WebUI Components
        await self.enable_webui_components()
        
        # Step 4: Enable YOLO mode
        await self.enable_yolo_mode()
        
        # Step 5: Send a message
        await self.send_message("what files are in the current directory?")
        
        # Step 6: Wait for a tool to execute
        tool_found = await self.wait_for_tool("list_directory", timeout=20)
        
        # Step 7: Take screenshot of the response
        await self.take_screenshot("final_response", full_page=True)
        
        # Step 8: Check for issues
        duplicates = await self.check_duplicate_tool_names()
        
        # Step 9: Get tool call content for debugging
        toolcall_content = await self.get_toolcall_content()
        for i, content in enumerate(toolcall_content):
            self.log(f"Tool call {i}: {content[:100]}...")
        
        # Return test result
        if duplicates:
            self.log(f"Found duplicates: {duplicates}", "ERROR")
            return False
        
        if not tool_found:
            self.log("Expected tool not found", "WARNING")
        
        return True


class ToolExecutionTest(ChatTestBase):
    """
    Test that verifies a specific tool executes correctly.
    """
    
    def __init__(self, tool_name: str, test_command: str, **kwargs):
        super().__init__(test_name=f"tool_{tool_name}_test", **kwargs)
        self.tool_name = tool_name
        self.test_command = test_command
    
    async def run_test(self) -> bool:
        """Run the tool execution test."""
        await self.navigate_to_app()
        await self.select_project("qwen-code-webui")
        await self.enable_webui_components()
        await self.enable_yolo_mode()
        await self.send_message(self.test_command)
        
        tool_found = await self.wait_for_tool(self.tool_name, timeout=30)
        await self.take_screenshot("result", full_page=True)
        
        if tool_found:
            self.log(f"Tool {self.tool_name} executed successfully", "SUCCESS")
            return True
        else:
            self.log(f"Tool {self.tool_name} not found", "ERROR")
            return False


# Test runner
async def main():
    """Run all example tests."""
    print("=" * 60)
    print("Running Chat Tests")
    print("=" * 60)
    
    tests = [
        ("Duplicate Tool Name Test", DuplicateToolNameTest, {
            "test_command": "list open issues",
            "expected_tool": "run_shell_command",
            "project_name": "qwen-code-webui"
        }),
        ("Tool Execution Test", ToolExecutionTest, {
            "tool_name": "list_directory",
            "test_command": "list files in current directory"
        }),
    ]
    
    results = []
    for name, test_class, kwargs in tests:
        print(f"\n{'='*60}")
        print(f"Running: {name}")
        print(f"{'='*60}")
        
        result = await run_chat_test(test_class, **kwargs)
        results.append((name, result))
        
        print(f"\n{name}: {'PASSED ✓' if result else 'FAILED ✗'}")
    
    # Summary
    print(f"\n{'='*60}")
    print("Test Summary")
    print(f"{'='*60}")
    
    passed = sum(1 for _, r in results if r)
    total = len(results)
    
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")
    
    print(f"\nTotal: {passed}/{total} passed")
    
    return all(r for _, r in results)


if __name__ == "__main__":
    result = asyncio.run(main())
    sys.exit(0 if result else 1)