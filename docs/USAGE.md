# Usage

## Workspace

The transparent host window stays fixed at the screen's top edge. Only the visible notch surface animates. The menu bar outside the physical camera housing stays transparent and click-through. A narrow strip below the camera shows countdown progress without covering status items.

Hover at the notch to open. Pin keeps it open; Escape closes and unpins. Focus, Music, Files, Clipboard, Queue, Subtasks, New task and Settings occupy bounded views in the same window. Lists use Previous/Next pages. Text drafts survive collapse and display reconfiguration.

New task → Add task uses your chosen duration, or No timer. Return submits. Auto plan extracts independent actions from free text in the input language, estimates durations, and runs in the background. A completion/failure message and sound report the result; the panel does not need to stay open. Errors restore your text to New task. Existing active work is preserved. Queue → Start pauses the current task with its remaining time; Complete advances to the next task. Timer expiry does not mark tasks complete.

## Local server

For Ollama, keep your existing `ollama run` session running or start `ollama serve`. Select Ollama, use `http://127.0.0.1:11434`, Check connection, choose the exact installed name in Models, and Save. The initial model name is only a configurable value, not a download. A working model-list endpoint does not guarantee that a particular model can generate a valid plan. HTTP errors now include the server's error message.

MLX / compatible servers use their own local port, for example `http://127.0.0.1:8080`. Enter only the origin; the app adds `/v1`. Planning accepts only loopback addresses and does not send shelf files or clipboard history. Model output has bounded task counts, titles and durations. Meaning and estimates still depend on the installed model.

## Clipboard, files and music

Text clipboard history is opt-in for existing preferences and on by default for fresh installs. Clipboard → Enable captures the current text immediately; Capture current clipboard retries manually. History stays in memory and clears on quit. Known confidential markers and selected password managers are excluded; do not use this as universal protection for secrets.

Shelf files are copied into `~/Library/Application Support/MacAss/Shelf`: regular files up to 100 MB, at most 100 items. Removing an item deletes only its managed copy. Drag a card into another application. Tasks and saved items persist in Application Support, without app-level encryption.

Music automatically chooses a running Spotify or Apple Music player, preferring active playback. Allow the Automation prompt. Spotify artwork is loaded over HTTPS from the URL supplied by Spotify. Browser players and Apple Music artwork are not supported. Music can be disabled in Settings → Music & privacy.

## Build

Run `bash scripts/build.sh`, then `open build/MacAss.app`. Move it to Applications if desired. Local builds are ad-hoc signed and not notarized. Close older running copies before testing a new build. `swift test` runs core and store tests with isolated pasteboards and temporary state. CI's explicit `--verify-scene` flag uses synthetic data in a temporary directory and does not read the user's saved tasks.
