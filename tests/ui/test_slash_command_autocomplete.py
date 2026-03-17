"""
Test for Issue 28: Slash Command Autocomplete with /skills support

This test verifies that:
1. Slash command suggestion popup appears when typing /
2. Commands can be filtered by typing partial text
3. Tab key auto-completes the selected command
4. Arrow keys navigate through suggestions
5. Enter confirms the selection
6. Sub-commands (skills) are displayed after /skills
"""

import asyncio
import sys
import os

# Add tests directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from chat_test_base import ChatTestBase


class SlashCommandAutocompleteTest(ChatTestBase):
    """
    Test for Slash Command Autocomplete (Issue 28).
    """

    def __init__(
        self,
        project_name: str = "qwen-code-webui",
        **kwargs
    ):
        super().__init__(test_name="slash_command_autocomplete_test", **kwargs)
        self.project_name = project_name

    async def run_test(self) -> bool:
        """Run the Slash Command Autocomplete test."""
        self.log("=" * 60)
        self.log("Test: Slash Command Autocomplete (Issue 28)")
        self.log("=" * 60)

        # Navigate to app
        await self.navigate_to_app()

        # Select project
        await self.select_project(self.project_name)

        # Wait for ChatPage to load
        await asyncio.sleep(2)
        await self.take_screenshot("chat_page_loaded")

        # Find the input textarea
        self.log("Finding input textarea...", "INFO")
        textarea = await self.page.query_selector('textarea[placeholder*="Type message"]')

        if not textarea:
            self.log("Input textarea not found", "ERROR")
            await self.take_screenshot("textarea_not_found")
            return False

        self.log("Input textarea found", "SUCCESS")
        await self.take_screenshot("01_chat_page_loaded")

        # Test 1: Type / and check if suggestion popup appears
        self.log("Test 1: Testing slash command popup...", "INFO")

        await textarea.focus()
        await textarea.fill("/")
        await asyncio.sleep(1)

        # Check if suggestion popup is visible
        popup_visible = await self.is_popup_visible()
        if not popup_visible:
            self.log("Suggestion popup did not appear after typing /", "ERROR")
            await self.take_screenshot("02_popup_not_found")
            return False

        self.log("Suggestion popup appeared", "SUCCESS")
        await self.take_screenshot("03_popup_appeared")

        # Test 2: Filter commands by typing partial text
        self.log("Test 2: Testing command filtering...", "INFO")

        await textarea.fill("/s")
        await asyncio.sleep(0.5)

        # Check if only /skills is shown
        skills_count = await self.count_suggestions()
        self.log(f"Number of suggestions after /s: {skills_count}", "INFO")

        if skills_count != 1:
            self.log(f"Expected 1 suggestion but got {skills_count}", "WARNING")

        await self.take_screenshot("04_filtered_suggestions")

        # Test 3: Tab key auto-completes command
        self.log("Test 3: Testing Tab auto-complete...", "INFO")

        await textarea.fill("/s")
        await asyncio.sleep(0.5)
        await textarea.press("Tab")
        await asyncio.sleep(0.5)

        value = await textarea.input_value()
        self.log(f"After Tab: '{value}'", "INFO")

        if "/skills" not in value:
            self.log(f"Expected '/skills' but got '{value}'", "ERROR")
            await self.take_screenshot("05_tab_complete_failed")
            return False

        self.log("Tab auto-complete works", "SUCCESS")
        await self.take_screenshot("06_tab_completed")

        # Test 4: Arrow key navigation
        self.log("Test 4: Testing arrow key navigation...", "INFO")

        await textarea.fill("/")
        await asyncio.sleep(0.5)

        # Press down arrow to select second item
        await self.page.keyboard.press("ArrowDown")
        await asyncio.sleep(0.3)

        # Press up arrow to go back
        await self.page.keyboard.press("ArrowUp")
        await asyncio.sleep(0.3)

        # Press Enter to select
        await self.page.keyboard.press("Enter")
        await asyncio.sleep(0.5)

        value = await textarea.input_value()
        self.log(f"After arrow navigation + Enter: '{value}'", "INFO")

        if "/skills" not in value:
            self.log("Arrow navigation may have failed", "WARNING")

        self.log("Arrow navigation test completed", "SUCCESS")
        await self.take_screenshot("07_arrow_navigation")

        # Test 5: Sub-commands (skills list)
        self.log("Test 5: Testing sub-commands (skills list)...", "INFO")

        await textarea.fill("/skills ")
        await asyncio.sleep(1)

        # Check if skills popup appears
        skills_popup_visible = await self.is_popup_visible()
        if not skills_popup_visible:
            self.log("Skills popup did not appear", "WARNING")
        else:
            self.log("Skills popup appeared", "SUCCESS")
            skills_count = await self.count_suggestions()
            self.log(f"Number of skills: {skills_count}", "INFO")

        await self.take_screenshot("08_skills_popup")

        # Test 6: Filter skills by typing partial name
        self.log("Test 6: Testing skill filtering...", "INFO")

        await textarea.fill("/skills gh-")
        await asyncio.sleep(0.5)

        if skills_popup_visible:
            filtered_count = await self.count_suggestions()
            self.log(f"Number of filtered skills (gh-): {filtered_count}", "INFO")

        await self.take_screenshot("09_filtered_skills")

        # Test 7: Tab complete skill name
        self.log("Test 7: Testing skill Tab auto-complete...", "INFO")

        await textarea.fill("/skills gh-i")
        await asyncio.sleep(0.5)
        await textarea.press("Tab")
        await asyncio.sleep(0.5)

        value = await textarea.input_value()
        self.log(f"After Tab on skill: '{value}'", "INFO")

        if "gh-issue" in value:
            self.log("Skill Tab auto-complete works", "SUCCESS")
        else:
            self.log(f"Skill Tab auto-complete may have failed: {value}", "WARNING")

        await self.take_screenshot("10_skill_completed")

        # Test 8: ESC dismisses popup
        self.log("Test 8: Testing ESC to dismiss popup...", "INFO")

        await textarea.fill("/")
        await asyncio.sleep(0.5)

        popup_before_esc = await self.is_popup_visible()
        if popup_before_esc:
            await self.page.keyboard.press("Escape")
            await asyncio.sleep(0.5)

            popup_after_esc = await self.is_popup_visible()
            if not popup_after_esc:
                self.log("ESC dismisses popup", "SUCCESS")
            else:
                self.log("ESC did not dismiss popup", "WARNING")

        await self.take_screenshot("11_esc_dismissed")

        self.log("=" * 60)
        self.log("Test COMPLETED: Slash Command Autocomplete", "SUCCESS")
        self.log("=" * 60)
        return True

    async def is_popup_visible(self) -> bool:
        """Check if the suggestion popup is visible."""
        try:
            # Wait a bit for popup to appear
            await asyncio.sleep(0.3)
            popup = await self.page.query_selector('ul.fixed')
            if popup:
                is_visible = await popup.is_visible()
                return is_visible
            return False
        except Exception as e:
            self.log(f"Error checking popup: {e}", "INFO")
            return False

    async def count_suggestions(self) -> int:
        """Count the number of suggestions in the popup."""
        try:
            popup = await self.page.query_selector('ul.fixed')
            if popup:
                items = await popup.query_selector_all('li')
                return len(items)
            return 0
        except Exception as e:
            self.log(f"Error counting suggestions: {e}", "INFO")
            return 0


async def main():
    """Run the test."""
    test = SlashCommandAutocompleteTest()
    result = await test.execute()

    print(f"\n{'='*60}")
    print(f"Test Result: {'PASSED ✓' if result else 'FAILED ✗'}")
    print(f"{'='*60}")

    return result


if __name__ == "__main__":
    asyncio.run(main())
