# Setup

This guide recreates the tested **OpenCode in WSL2 -> persistent Windows 11 toast** setup.

## 1. Prerequisites

You need:

- Windows 11
- WSL2
- OpenCode installed and running inside WSL
- Windows PowerShell available from WSL as `powershell.exe`
- access to PowerShell Gallery to install BurntToast

Clone this repository inside WSL and enter it before following the commands below.

## 2. Verify WSL can invoke Windows PowerShell

From WSL:

```bash
command -v powershell.exe
```

A typical result is:

```text
/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe
```

Check the version:

```bash
powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

The validated machine used Windows PowerShell `5.1.26100.9168`.

## 3. Inspect the current execution policy

Do not change it just to make this setup work.

```bash
powershell.exe -NoProfile -Command 'Get-ExecutionPolicy -List | Format-Table -AutoSize'
```

```bash
powershell.exe -NoProfile -Command 'Get-ExecutionPolicy'
```

The validated machine had:

```text
LocalMachine  AllSigned
```

and an effective policy of `AllSigned`.

The notification bridge uses `-ExecutionPolicy Bypass` only on the short-lived PowerShell process that imports BurntToast. No persistent `Set-ExecutionPolicy` change is required.

## 4. Install BurntToast for the Windows user

Check the available version:

```bash
powershell.exe -NoProfile -Command 'Find-Module BurntToast | Select-Object Name,Version,Repository'
```

The validated version was `1.1.0`.

Install it for the current Windows user:

```bash
powershell.exe -NoProfile -Command 'Install-Module -Name BurntToast -Scope CurrentUser'
```

PowerShell may ask for confirmation. Review the prompt and accept if appropriate.

### Test BurntToast directly

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'Import-Module BurntToast -Force; New-BurntToastNotification -Text "OpenCode test","Hello from WSL"'
```

Success criteria:

1. a Windows toast appears;
2. after the popup disappears, the notification remains in Windows Notification Center.

## 5. Install the PowerShell bridge script

Discover the real Windows profile from WSL:

```bash
powershell.exe -NoProfile -Command '$env:USERPROFILE'
```

For example:

```text
C:\Users\your-user
```

Convert that profile to a WSL path and copy the script:

```bash
WIN_PROFILE="$(powershell.exe -NoProfile -Command '$env:USERPROFILE' | tr -d '\r')"
WIN_PROFILE_WSL="$(wslpath "$WIN_PROFILE")"
mkdir -p "$WIN_PROFILE_WSL/.opencode"
cp scripts/OpenCodeNotify.ps1 "$WIN_PROFILE_WSL/.opencode/OpenCodeNotify.ps1"
```

The resulting Windows-side file should be:

```text
<Windows user profile>\.opencode\OpenCodeNotify.ps1
```

### Test the bridge directly

Get its Windows path:

```bash
WIN_SCRIPT="$(wslpath -w "$WIN_PROFILE_WSL/.opencode/OpenCodeNotify.ps1")"
```

Then run:

```bash
powershell.exe \
  -NoProfile \
  -ExecutionPolicy Bypass \
  -File "$WIN_SCRIPT" \
  complete \
  "Manual integration test completed" \
  "test-project" \
  "Test session" \
  ""
```

Expected toast:

```text
OpenCode - test-project
Task completed
Test session
```

It should also remain in Notification Center.

## 6. Add opencode-notifier to OpenCode

Edit the OpenCode configuration inside WSL, normally:

```text
~/.config/opencode/opencode.json
```

Merge the plugin entry from [`../config/opencode-plugin-snippet.json`](../config/opencode-plugin-snippet.json) with any existing configuration:

```json
{
  "plugin": [
    "@mohak34/opencode-notifier@0.2.8"
  ]
}
```

The version is intentionally pinned to the baseline tested by this repository. You can upgrade later after validating a newer release.

Restart OpenCode after changing the configuration.

### Verify the exact installed/cached version

From WSL:

```bash
npm view @mohak34/opencode-notifier@0.2.8 version
```

OpenCode normally caches npm plugins below `~/.cache/opencode`. To locate the installed package:

```bash
find ~/.cache/opencode -type f \
  -path '*/@mohak34/opencode-notifier/package.json' \
  -print
```

Inspect the matching `package.json` and confirm the `version` field.

A successful plugin load can also create:

```text
~/.config/opencode/opencode-notifier-state.json
```

with state similar to:

```json
{"turn":1}
```

## 7. Install the notifier configuration

Copy the example:

```bash
mkdir -p ~/.config/opencode
cp config/opencode-notifier.json ~/.config/opencode/opencode-notifier.json
```

Then edit:

```bash
nano ~/.config/opencode/opencode-notifier.json
```

Replace:

```text
C:\Users\YOUR_WINDOWS_USER\.opencode\OpenCodeNotify.ps1
```

with the actual Windows path returned by:

```bash
powershell.exe -NoProfile -Command '$env:USERPROFILE'
```

Remember that backslashes inside JSON strings must be doubled. For example:

```json
"C:\\Users\\alex\\.opencode\\OpenCodeNotify.ps1"
```

The repository's recommended daily-use settings are:

```json
"suppressWhenFocused": false,
"minDuration": 10
```

`minDuration: 10` has been validated for both the main `complete` event and `subagent_complete`. The threshold is evaluated per session, so a short subagent can be filtered while a longer parent session still notifies. High-value events such as `permission` are not delayed by this completion-duration filter.

`suppressWhenFocused` remains `false` because focus detection was not effective for OpenCode running in WSL under Windows Terminal.

## 8. Restart OpenCode and smoke test

For an initial smoke test, temporarily set:

```json
"minDuration": 0
```

so a trivial completion is guaranteed to be eligible for notification.

Start OpenCode from a test directory and send:

```text
Reply only with: notification test completed
```

If the toast appears and remains in Notification Center, restore:

```json
"minDuration": 10
```

and continue with [`validation.md`](validation.md).

## 9. Project name in the toast

`{projectName}` is derived from the directory/project where OpenCode was started when `showFullPath` is `false`.

For example, starting OpenCode from:

```text
/home/user/work/my-project
```

produces a title similar to:

```text
OpenCode - my-project
```

This is useful when multiple OpenCode sessions are running for different projects.
