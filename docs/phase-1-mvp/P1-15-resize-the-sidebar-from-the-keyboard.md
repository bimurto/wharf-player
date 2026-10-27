# P1-15: Resize the sidebar from the keyboard

**Status:** Built, needs manual check  
**Requirements:** P1-B2  
**Depends on:** P1-14  

## What

Match the Electron app's keyboard resizing.

## Acceptance criteria

- [ ] Focusing the divider and pressing left/right changes width by 20 pt (50 pt with Shift)
- [ ] Home and End jump to minimum and maximum
- [ ] Accessible label on the divider

## Notes

Done with a custom divider (`HStack` in `PlayerScreen`) replacing `HSplitView`; dragging now saves on release (P1-14).

SwiftUI's `HSplitView` has no keyboard resize; may need a custom divider.
