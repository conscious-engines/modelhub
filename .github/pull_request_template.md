## Description
Provide a clear description of the changes made and the motivation behind them.

## Related Issues
Closes #[issue-number] (if applicable)

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation / Refactoring

## Design & UI Changes (if applicable)
If you made visual changes to the menu bar or popovers:
- Describe the visual modifications.
- Attach screenshots or screen recordings (GIF/MP4) demonstrating the change.

## How Has This Been Tested?
Please describe the tests that you ran to verify your changes:
- [ ] App compiled cleanly under Xcode 16.x / macOS 15.0+
- [ ] Checked for leakages or CPU overhead when opening the menu
- [ ] Local scans verify models correctly

## Checklist:
- [ ] My code follows the code style and guidelines outlined in `CONTRIBUTING.md`.
- [ ] I have commented my code, particularly in hard-to-understand areas.
- [ ] I have kept the SwiftUI-free AppKit architecture for menu item custom views intact.
- [ ] My changes do not bypass deletion safety checks (models are sent to Trash).
