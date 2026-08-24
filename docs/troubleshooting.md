# Troubleshooting

Use this guide to isolate failures layer by layer.

## Diagnostic model

Treat the setup as separate layers:

```text
OpenCode
  -> opencode-notifier
  -> custom command
  -> powershell.exe
  -> OpenCodeNotify.ps1
  -> BurntToast
  -> Windows Notification Platform
```

Do not change several layers at once. Identify the first broken boundary.

## 1. Plugin state changes but no Windows notification appears

Check:

```bash
cat ~/.config/opencode/opencode-notifier-state.json
```

A state such as:

```json
{"turn":7}
```

that changes while OpenCode is used is evidence that the notifier plugin is loading and processing activity.

If the state changes but no Windows toast appears, investigate the Windows delivery path rather than OpenCode itself.

## 2. Verify WSL -> Windows executable interoperability

```bash
command -v powershell.exe
```

Then:

```bash
powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

If these fail, fix WSL/Windows executable interoperability before debugging BurntToast.

## 3. Verify WSL can display Windows UI

A simple diagnostic popup:

```bash
powershell.exe -NoProfile -Command '$wshell = New-Object -ComObject Wscript.Shell; $wshell.Popup("Hello from WSL", 5, "OpenCode notification test", 64)'
```

If this appears, WSL can invoke Windows GUI functionality.

This popup is only a diagnostic. It is modal-ish and is not the final notification transport.

## 4. Why not use `NotifyIcon.ShowBalloonTip()` as the final solution?

The following approach can display a non-blocking balloon:

```bash
powershell.exe -NoProfile -Command 'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::EnableVisualStyles(); $notify = New-Object System.Windows.Forms.NotifyIcon; $notify.Icon = [System.Drawing.SystemIcons]::Information; $notify.Visible = $true; $notify.ShowBalloonTip(5000, "OpenCode test", "Hello from WSL", [System.Windows.Forms.ToolTipIcon]::Info); Start-Sleep -Milliseconds 5500; $notify.Dispose()'
```

On the validated Windows 11 machine the balloon appeared and disappeared correctly, but it did **not** remain in Windows Notification Center.

That is why this repository uses BurntToast instead.

## 5. BurntToast cannot be imported because the module is not digitally signed

Typical error:

```text
BurntToast.psm1 cannot be loaded ... is not digitally signed.
```

Inspect the policy:

```bash
powershell.exe -NoProfile -Command 'Get-ExecutionPolicy -List | Format-Table -AutoSize'
```

The validated machine had:

```text
LocalMachine  AllSigned
```

Do **not** weaken the persistent machine policy just for notifications.

Test BurntToast with a process-scoped bypass:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'Import-Module BurntToast -Force; New-BurntToastNotification -Text "OpenCode test","Hello from WSL"'
```

The `-ExecutionPolicy Bypass` option applies to that PowerShell process. The repository's notifier configuration uses the same approach when launching `OpenCodeNotify.ps1`.

No persistent `Set-ExecutionPolicy` command is required by this setup.

## 6. BurntToast appears and remains in Notification Center

This is the desired transport behavior.

If the direct BurntToast test works but OpenCode still does not notify, test the bridge script directly as described in [`setup.md`](setup.md).

If the bridge works directly, re-check:

- the script path in `~/.config/opencode/opencode-notifier.json`;
- doubled backslashes in the JSON Windows path;
- `command.enabled: true`;
- the target event's `command: true`;
- that OpenCode was restarted after configuration changes.

## 7. Native opencode-notifier WSL notifications do not appear

On the validated machine:

- the plugin loaded successfully;
- its state counter advanced;
- disabling the icon did not make native notifications appear;
- PowerShell interoperability worked;
- direct Windows GUI worked;
- BurntToast worked.

This isolated the failure to the plugin's automatic/native WSL notification delivery path on that workstation.

The working fallback is therefore:

```text
opencode-notifier
  -> powershell.exe custom command
  -> OpenCodeNotify.ps1
  -> BurntToast
```

The baseline configuration deliberately sets:

```json
"notification": false
```

so the failing native backend is not used.

## 8. Clicking a toast briefly opens PowerShell

BurntToast notifications launched through Windows PowerShell may be attributed to **Windows PowerShell** in Notification Center. Clicking the notification can briefly activate/open a shell that then closes.

This does not affect the attention-notification use case. Return to the existing OpenCode terminal to answer permissions or questions.

Giving the notification a dedicated application identity would require additional Windows registration/AppUserModelID work and is outside the baseline setup.

## 9. The toast says `OpenCode - <folder name>`

This is expected.

With:

```json
"showProjectName": true,
"showFullPath": false
```

`{projectName}` is based on the directory/project from which OpenCode was started.

Starting OpenCode from a home directory may therefore show the home-directory name. Start OpenCode from the actual repository/project directory for a more useful notification title.

## 10. Two notifications appear after a delegated task

If a subagent finishes and then the main session finishes, two notifications are expected:

```text
Subagent completed
```

and later:

```text
Task completed
```

These are different events, not duplicates.

If this becomes noisy in real workflows, tune `subagent_complete`, focus suppression, and/or minimum duration after the basic setup has been validated.

## 11. No permission toast appears

Make sure the tested action actually requires approval. For a controlled test, use a temporary project-level OpenCode configuration with:

```json
{
  "permission": {
    "bash": "ask"
  }
}
```

Then request a harmless shell command and leave the permission prompt unanswered while checking Notification Center.

## 12. No question toast appears

The model must use OpenCode's question mechanism/tool. A normal prose sentence that happens to contain a question may not represent the same event.

Use the controlled prompt from [`validation.md`](validation.md).

## 13. `plan_exit` does not fire when switching Plan -> Build manually

This was observed during validation and is expected for the tested path.

Finishing a Plan response or manually pressing `Tab` to switch agents did not produce `plan_exit`. Treat it as a specific tool event rather than a generic "left Plan mode" signal.

If the normal workflow never invokes that tool, the event can remain optional.
