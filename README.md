# MacAss

A native MacBook notch shelf for file and text drag-and-drop, clipboard history, tasks and subtasks, a focus timer (+5/+10/+15 minutes), Apple Music / Spotify controls, and task planning through a local server. SwiftUI + AppKit, macOS 14+, no third-party dependencies. MIT licensed.

## Run

Install command-line tools with `xcode-select --install`, then:

```sh
git clone --branch fix/planning-and-panel https://github.com/kiteminer/mac-ass.git
cd mac-ass
bash scripts/build.sh
open build/MacAss.app
```

After the PR is merged, you can clone `main`. Move the built app to Applications if desired. Run tests with `swift test`. The macOS workflow also provides a ZIP under Artifacts → MacAss-macOS.

Hover over the notch to expand the panel. From Music, click **Focus** to open the shelf; dropping a file opens it immediately. Pin the panel to keep it open. Enable clipboard history and player control in Settings.

For **Plan list**, select Ollama or MLX / OpenAI-compatible, enter a loopback server address and your exact model name. Start the server separately. If it is unavailable, the app reports failure without adding tasks. The first timer starts automatically when the queue was empty.

[Configuration, limitations, and Mac verification](docs/USAGE.md)
