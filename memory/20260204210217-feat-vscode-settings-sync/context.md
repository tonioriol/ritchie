---
title: "feat-vscode-settings-sync VS Code Settings Sync (Remote Tunnel)"
status: done
created: 2026-02-04
---

# feat-vscode-settings-sync VS Code Settings Sync (Remote Tunnel)

## TASK

Document how to keep VS Code settings, extensions, and keybindings in sync when using a Remote Tunnel / server-backed VS Code environment.

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/apps/vscode.yaml`
* `/Users/tr0n/Code/ritchie/charts/vscode/values.yaml`

## PLAN

Remote Tunnel uses your local VS Code UI, so **Settings Sync works normally** (Microsoft or GitHub account). The remote pod only runs the VS Code server and CLI.

### Recommended: Settings Sync (built-in)

1. Local VS Code: Command Palette → **“Settings Sync: Turn On”**.
2. Choose **GitHub** or **Microsoft** and sign in.
3. Once connected to the tunnel, your settings, extensions, and keybindings will sync as usual.

### Fallback: Profiles export/import (GitHub Gist)

1. Command Palette → **“Profiles: Export Profile”** → **GitHub Gist**.
2. Copy the Gist URL/ID.
3. In the tunnel-connected VS Code: **“Profiles: Import Profile”** → **GitHub Gist** → paste URL/ID.

### Alternative: Manual one-time copy

If you don’t want an extension or token, you can manually copy:

1. Local VS Code: open **Settings (JSON)** and **Keyboard Shortcuts (JSON)** and copy the contents.
2. Code-server: open the same JSON files and paste the contents.
3. Local VS Code: open **Snippets** and copy any custom snippets.
4. Code-server: create the same snippets and paste the content.
5. Install extensions manually from the Extensions view.

### Notes

- Some desktop-only extensions won’t work in a server environment; disable them if needed.
- Secrets are **not** synced. Keep secrets in server-side env/Secrets (e.g., a Kubernetes Secret).

## EVENT LOG

## Next Steps

- [x] ~~Update this doc if the cluster’s VS Code deployment model changes (tunnel vs in-cluster code-server).~~ — **obsolete** (2026-11-08): standing reminder, not a step

### 2026-11-08 17:00 — Stale open steps closed out against live state

- The only open line was a standing maintenance reminder, not a step.
