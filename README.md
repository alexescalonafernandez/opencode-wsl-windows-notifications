# OpenCode WSL Windows Notifications

Reusable notification bridge for **OpenCode running inside WSL2 on Windows 11**.

The goal is simple: when OpenCode is working in WSL and needs attention, Windows should show a native notification that remains available in **Notification Center**.

This repository documents a tested setup using:

- OpenCode in WSL2
- `@mohak34/opencode-notifier@0.2.8`
- Windows PowerShell 5.1
- BurntToast 1.1.0
- a small PowerShell bridge script

## Why this exists

OpenCode can spend time running tools or AI agents while its terminal is in the background. Useful attention points include:

- a permission request
- a question that requires a decision
- completion of the main task
- completion of a subagent
- a session error
- a plan ready for review

On the tested Windows 11 + WSL2 environment, the notifier plugin loaded and processed events correctly, but its automatic WSL notification route did not produce visible Windows notifications. A PowerShell + BurntToast custom command provided a reliable fallback with notifications that persist in Windows Notification Center.

## Architecture

```text
OpenCode (WSL2)
      |
      | OpenCode event
      v
@mohak34/opencode-notifier
      |
      | custom command
      v
powershell.exe
      |
      | -ExecutionPolicy Bypass (process only)
      v
OpenCodeNotify.ps1
      |
      v
BurntToast
      |
      v
Windows 11 Notification Platform
      |-- popup toast
      `-- Notification Center history
```

## Tested baseline

Validated on 2026-08-25 with:

| Component | Tested value |
| --- | --- |
| Host OS | Windows 11 |
| Guest | WSL2 / Ubuntu 24.04 |
| Windows PowerShell | 5.1.26100.9168 |
| PowerShell execution policy | `LocalMachine = AllSigned` |
| BurntToast | 1.1.0 |
| OpenCode notifier | 0.2.8 |

The setup deliberately uses `-ExecutionPolicy Bypass` only for the PowerShell process launched for a notification. It does **not** require changing the persistent machine or user execution policy.

## Event and behavior status

| Event / behavior | Status | Notes |
| --- | --- | --- |
| `complete` | ✅ Validated | Main session completion produced one toast |
| `permission` | ✅ Validated | Toast appeared while OpenCode was waiting for approval |
| `question` | ✅ Validated | Toast appeared while OpenCode was waiting for an answer |
| `subagent_complete` | ✅ Validated | Subagent and main-session completion were correctly distinguished |
| `error` | 🟡 Configured | Not intentionally forced during validation |
| `plan_exit` | 🟡 Configured | Specific OpenCode tool event; not intentionally forced |
| `suppressWhenFocused` | ❌ Not effective in tested WSL + Windows Terminal setup | Plugin runs as Linux inside WSL and cannot reliably identify the host Windows Terminal focus state |
| `minDuration = 10` | ✅ Validated for main completion | A ~2 s task produced no completion toast; a >10 s task produced a completion toast, while `permission` still notified immediately |

## Recommended WSL defaults

The repository configuration currently uses:

```json
"suppressWhenFocused": false,
"minDuration": 10
```

`minDuration: 10` reduces noise from trivial completion events while preserving attention events such as permission requests. The threshold behavior has been validated for the main `complete` event. A subagent-specific duration test can be used if stricter evidence is required for `subagent_complete`.

## Focus suppression note

The repository intentionally keeps:

```json
"suppressWhenFocused": false
```

for the WSL baseline.

A controlled test with `suppressWhenFocused: true` still produced a toast while the OpenCode tab was focused in Windows Terminal.

The reason is architectural: OpenCode and the notifier plugin run as Linux processes inside WSL, so the plugin follows its Linux focus-detection path. The native Windows `GetForegroundWindow()` path is not selected. A normal WSL shell hosted by Windows Terminal does not expose a Linux X11/Wayland window ID for the host terminal window, and the plugin deliberately fails open by continuing to notify when focus cannot be established.

See [`docs/validation.md`](docs/validation.md) and [`docs/troubleshooting.md`](docs/troubleshooting.md) for the observed behavior and upstream references.

A future enhancement could move focus filtering into the Windows-side PowerShell bridge, but a naive implementation would treat the whole Windows Terminal window as focused and could not reliably distinguish the OpenCode tab from another tab. This is therefore not enabled by default.

## Repository layout

```text
.
├── README.md
├── config/
│   ├── opencode-notifier.json
│   └── opencode-plugin-snippet.json
├── docs/
│   ├── setup.md
│   ├── troubleshooting.md
│   └── validation.md
└── scripts/
    └── OpenCodeNotify.ps1
```

## Quick start

1. Follow [`docs/setup.md`](docs/setup.md).
2. Copy [`scripts/OpenCodeNotify.ps1`](scripts/OpenCodeNotify.ps1) to your Windows user profile.
3. Add the notifier plugin to OpenCode using [`config/opencode-plugin-snippet.json`](config/opencode-plugin-snippet.json).
4. Adapt [`config/opencode-notifier.json`](config/opencode-notifier.json) with your Windows user/profile path.
5. Run the controlled tests in [`docs/validation.md`](docs/validation.md).
6. If anything fails, use [`docs/troubleshooting.md`](docs/troubleshooting.md).

## Upstream projects

- OpenCode: https://opencode.ai/
- opencode-notifier: https://github.com/mohak34/opencode-notifier
- BurntToast: https://github.com/Windos/BurntToast

## Scope

This repository is a workstation setup/reference project. It does not modify OpenCode, WSL, gentle-ai, or project repositories. The PowerShell bridge is local infrastructure whose only responsibility is translating notifier events into persistent Windows toasts.
