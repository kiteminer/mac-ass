# Notch shell rebuild

## References used

DynamicNotchKit: https://github.com/MrKai77/DynamicNotchKit
Cyclop: https://github.com/akalikbergenov/cyclop

MIT source is included with full notices, not copied from a closed-source app. The app bundles those notices.

## Defects addressed

1. Double top inset detached the panel from the camera housing: one top-anchored coordinate system now drives placement.
2. NSHostingView automatic sizing fought explicit panel dimensions: sizing options are disabled and the host frame is stable.
3. Every timer update scheduled window sizing: the host is no longer resized by data updates.
4. Two hover mechanisms raced: the vendored PointerWatcher is the single hover authority.
5. Resizing hover targets caused flicker: hit regions are separate from the fixed host window.
6. Transparent host space intercepted other apps: interactivity is limited to the actual visible body.
7. Wide headers covered menu icons: only the camera column is opaque in the menu bar.
8. Fixed 650-point bodies wasted space: all views use one 330-point content area.
9. Expanded disclosures overflowed: queue, subtasks and clipboard use separate bounded views.
10. Deleting the final item could strand a page: page bounds are clamped to the current item count.
11. Queue did not offer an action: Start and Delete are explicit controls.
12. Switching tasks would lose remaining time: suspended tasks retain exact remaining seconds.
13. Invalid manual input was erased: submission returns success before clearing drafts.
14. Invalid planning input dismissed the panel: validation occurs before dismissing or marking the request busy.
15. Failed plans lost source text: the original input is restored for retry.
16. Clipboard enable ignored already-copied text: enabling captures immediately.
17. Clipboard capture stopped in menu tracking: timers use the common run-loop modes.
18. Errors looked like generic connection problems: model HTTP error details are surfaced.
19. Drafts lived inside a rebuilt view: they now belong to the persistent store.
20. Verification covered only empty windows: CI captures populated focus, queue, subtasks, files, clipboard, music, compose, settings, busy and compact states.

## Evidence and scope

Geometry tests cover offset displays, the top anchor, compact width and page deletion. Store tests cover repeated creation/completion, clipboard capture, sensitive markers, subtasks, queue operations and rejected requests. Network tests distinguish actual model-generated tasks from fallback data. CI runs the packaged app and captures each populated view for visual inspection.

Synthetic screenshots verify layout, not a particular Spotify account or the user's local model. Physical hardware, Automation permission choices and actual model quality remain environment-specific checks.
