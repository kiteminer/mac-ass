# MacAss

A compact MacBook notch workspace: focus timer, task queue and subtasks, file/text drag-and-drop, text clipboard history, Spotify / Apple Music, and local task planning. macOS 14+, SwiftUI + AppKit. MIT licensed.

```sh
xcode-select --install  # once, if command-line tools are missing
git clone --branch fix/stable-notch-shell https://github.com/kiteminer/mac-ass.git
cd mac-ass
bash scripts/build.sh
open build/MacAss.app
```

Hover at the notch to open. Move away to close, pin to keep open, Escape to close and unpin. Focus, Music, Files and Clipboard have separate views inside the same compact panel. New task supports Return; Auto plan runs after dismissal. Queue → Start switches tasks; Subtasks adds checkable steps. Standard Command-C/V/X/A/Z shortcuts work in text fields.

In Settings, use Ollama at `http://127.0.0.1:11434`, Check connection, then choose the exact model from Models and Save. If you already use `ollama run`, keep Ollama running. Otherwise start `ollama serve`. MLX servers can use the compatible protocol and their own port.

Tests: `swift test`. The macOS workflow provides the app ZIP and screenshots of populated views. Build artifacts are ad-hoc signed, not notarized.

[Usage and limitations](docs/USAGE.md) · [Fixes and verification](docs/REBUILD.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)
