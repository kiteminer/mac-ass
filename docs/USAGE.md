# MacAss usage

A native shelf around the MacBook notch with tasks, subtasks, a focus timer, file/text drag-and-drop, clipboard history, and Apple Music / Spotify controls. Requires macOS 14+. Built with SwiftUI and AppKit, without third-party dependencies. MIT licensed.

## Build and run

Install Xcode Command Line Tools (`xcode-select --install`), then:

```sh
git clone --branch fix/planning-and-panel https://github.com/kiteminer/mac-ass.git
cd mac-ass
bash scripts/build.sh
open build/MacAss.app
```

Move `build/MacAss.app` to Applications if desired. Run tests with `swift test`. GitHub Actions packages a ZIP under Artifacts → MacAss-macOS. Builds are ad-hoc signed, not notarized. If macOS blocks a build you have verified, use Open Anyway in System Settings.

## Controls

- Hover over the notch to expand. Click the top strip to collapse or expand; the pin keeps the panel open. The menu bar icon opens the shelf and settings. Displays without a notch use a top-center panel.
- **Add** creates tasks with the selected duration or no timer. Parentheses create subtasks. The first task starts immediately; the next starts after **Complete**. Expiry does not complete a task. Pause and +5/+10/+15 minute controls are available directly.
- From Music, click **Focus** or the current task card. Dragging a file opens the shelf automatically. Enable Apple Music / Spotify control in Settings and grant Automation permission. Spotify artwork and track progress are supported. Browser players and system-wide playback integration are not supported.
- Drop a file or text onto the shelf, then drag it into Finder, email, or a messenger. Files are copied into the shelf: regular files up to 100 MB, at most 100 items, no folders. Removing an item does not delete the original.
- Text clipboard history is opt-in, keeps up to 40 entries, and clears on quit. Shelf items and tasks persist in `~/Library/Application Support/MacAss`. The app does not encrypt this data; do not save secrets. Known confidential clipboard markers and some password managers are excluded, but this is not universal protection.

## Local planning

Select Ollama (`http://127.0.0.1:11434`) or MLX / OpenAI-compatible (for example `http://127.0.0.1:8080`). Start your server separately. Enter its exact installed model identifier; the initial value is `qwen3.8:27b-mlx`. The app neither checks its availability nor downloads it. MLX files alone do not imply Ollama compatibility: select the protocol of the server actually hosting your model. Enter only the origin, without `/v1`.

Paste `clean up, update resume (add tools, update workplace), go shopping, home first` and click **Plan list**. Requests go only to loopback, without clipboard history or shelf files. The shelf remains usable during planning and you can cancel. Results append to the queue and start only when it was empty.

Auto plan extracts independent tasks and subtasks from free text in the input language, then estimates durations and order. Output is checked for bounded counts, titles and durations. Semantic correctness depends on the model. Failed requests no longer silently add an unsplit fallback task. Planning continues after the panel closes; completion or failure is shown on the next opening and signalled by a sound. Existing active tasks remain unchanged; new tasks enter the queue.

The panel sits below the menu bar to avoid obscuring status items. Collections use Previous/Next pages rather than scrolling. Clipboard capture is enabled for fresh installs; existing preferences remain respected.

## Verify on a Mac

Check expansion/collapse and text input; Spaces and fullscreen windows; external display changes; drag-and-drop in both directions; timer pause, sleep, and restart; denied music permissions; an unavailable server; and planning cancellation. These interactions require a real macOS session. Notch placement uses screen geometry rather than a fixed MacBook resolution.


## Everyday shortcuts and setup

Press Return in Add a task to create it. Add subtasks directly under the active task. Use Command-C/V/X/A and Command-Z/Shift-Command-Z for standard macOS editing. Clipboard entries have individual delete buttons. Escape closes and unpins the panel; moving away collapses it unless you explicitly pin it. Draft text remains available after collapse.

Music defaults to Automatic: the app checks running Spotify and Apple Music players and prefers the one playing. Allow the macOS Automation prompt to read and control playback. Spotify artwork is fetched from the artwork URL supplied by Spotify. Use Settings to select a player manually or disable music controls.

If you already use `ollama run`, keep Ollama running. In Settings select Ollama, leave `http://127.0.0.1:11434`, click Check connection, and choose the exact installed model from the menu. If no server is running, start `ollama serve` in Terminal. Return to Focus, enter a list, and click Plan list. No terminal chat session is required by the app.
