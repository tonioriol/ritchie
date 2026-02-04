# VS Code Settings Sync (Remote Tunnel)

Remote Tunnel uses your local VS Code UI, so **Settings Sync works normally** (Microsoft or GitHub account). The remote pod only runs the VS Code server and CLI.

## Recommended: Settings Sync (built-in)

1. Local VS Code: Command Palette → **“Settings Sync: Turn On”**.
2. Choose **GitHub** or **Microsoft** and sign in.
3. Once connected to the tunnel, your settings, extensions, and keybindings will sync as usual.

## Fallback: Profiles export/import (GitHub Gist)

1. Command Palette → **“Profiles: Export Profile”** → **GitHub Gist**.
2. Copy the Gist URL/ID.
3. In the tunnel-connected VS Code: **“Profiles: Import Profile”** → **GitHub Gist** → paste URL/ID.

## Alternative: Manual one-time copy

If you don’t want an extension or token, you can manually copy:

1. Local VS Code: open **Settings (JSON)** and **Keyboard Shortcuts (JSON)** and copy the contents.
2. Code-server: open the same JSON files and paste the contents.
3. Local VS Code: open **Snippets** and copy any custom snippets.
4. Code-server: create the same snippets and paste the content.
5. Install extensions manually from the Extensions view.

## Notes

- Some desktop-only extensions won’t work in a server environment; disable them if needed.
- Secrets are **not** synced. Keep secrets in server-side env/Secrets (e.g., Kubernetes Secret in `tools`).
