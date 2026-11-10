# MacAss usage

A native shelf around the MacBook notch with tasks, subtasks, a focus timer, file/text drag-and-drop, clipboard history, and Apple Music / Spotify controls. Requires macOS 14+. Built with SwiftUI and AppKit, without third-party dependencies. MIT licensed.

## Build and run

Install Xcode Command Line Tools (`xcode-select --install`), then:

```sh
git clone --branch feature/notch-shelf https://github.com/kiteminer/mac-ass.git
cd mac-ass
bash scripts/build.sh
open build/MacAss.app
```

Move `build/MacAss.app` to Applications if desired. Run tests with `swift test`. GitHub Actions packages a ZIP under Artifacts → MacAss-macOS. Builds are ad-hoc signed, not notarized. If macOS blocks a build you have verified, use Open Anyway in System Settings.

## Controls

- Hover over the notch to expand. Click the top strip to collapse or expand; the pin keeps the panel open. The menu bar icon opens the shelf and settings. Displays without a notch use a top-center panel.
- **Add** creates tasks with the selected duration or no timer. Parentheses create subtasks. The first task starts immediately; the next starts after **Complete**. Expiry does not complete a task. Pause and +5/+10/+15 minute controls are available directly.
- From Music, click **Tasks & clipboard** or the current task card. Dragging a file opens the shelf automatically. Enable Apple Music / Spotify control in Settings and grant Automation permission. Browser players, system-wide playback integration, and album artwork are not supported yet.
- Drop a file or text onto the shelf, then drag it into Finder, email, or a messenger. Files are copied into the shelf: regular files up to 100 MB, at most 100 items, no folders. Removing an item does not delete the original.
- Text clipboard history is opt-in, keeps up to 40 entries, and clears on quit. Shelf items and tasks persist in `~/Library/Application Support/MacAss`. The app does not encrypt this data; do not save secrets. Known confidential clipboard markers and some password managers are excluded, but this is not universal protection.

## Local planning

Select Ollama (`http://127.0.0.1:11434`) or MLX / OpenAI-compatible (for example `http://127.0.0.1:8080`). Start your server separately. Enter its exact installed model identifier; the initial value is `qwen3.8:27b-mlx`. The app neither checks its availability nor downloads it. MLX files alone do not imply Ollama compatibility: select the protocol of the server actually hosting your model. Enter only the origin, without `/v1`.

Paste `clean up, update resume (add tools, update workplace), go shopping, home first` and click **Plan list**. Requests go only to loopback, without clipboard history or shelf files. The shelf remains usable during planning and you can cancel. Results append to the queue and start only when it was empty.

The planner returns only known task IDs and estimated durations. Validation checks completeness, duplicates, the 5–180 minute range, and the home-first rule. Explicit durations such as `20 min` are preserved. There are at most two requests of up to 100 seconds each. On failure, the original list uses 25-minute defaults. No commands, file access, or independent actions are available to the planner. Duration estimates and semantic ordering depend on the model. Separate ambiguous tasks with commas; location detection uses simple keyword rules.

## Verify on a Mac

Check expansion/collapse and text input; Spaces and fullscreen windows; external display changes; drag-and-drop in both directions; timer pause, sleep, and restart; denied music permissions; an unavailable server; and planning cancellation. These interactions require a real macOS session. Notch placement uses screen geometry rather than a fixed MacBook resolution.
