# Validation

This document records the controlled tests used to validate the notification bridge.

## Baseline test settings

During event validation, keep:

```json
"suppressWhenFocused": false,
"minDuration": 0
```

This avoids hiding notifications while testing individual event transport. Focus suppression and minimum-duration tuning were tested separately and are documented below.

Before each scenario, clear Windows Notification Center so the number of resulting notifications is unambiguous.

## Validation matrix

| Event / behavior | Status | Expected behavior |
| --- | --- | --- |
| `complete` | ✅ Validated | One toast after the main OpenCode session finishes |
| `permission` | ✅ Validated | One toast while OpenCode is blocked waiting for approval |
| `question` | ✅ Validated | One toast while OpenCode is blocked waiting for an answer |
| `subagent_complete` | ✅ Validated | One toast when the subagent finishes; main completion may produce a separate `complete` toast |
| `error` | 🟡 Configured | Not intentionally forced; expected to use the same custom-command transport |
| `plan_exit` | 🟡 Configured | Specific tool event; not intentionally forced |
| `suppressWhenFocused` | ❌ Not effective in tested WSL + Windows Terminal setup | Toast still appeared while the OpenCode tab was focused |
| `minDuration = 10` | ✅ Validated for `complete` | Short completion was suppressed; long completion notified; permission still notified immediately |

## 1. Main task completion

Prompt:

```text
Reply only with: notification test completed
```

Expected notification:

```text
OpenCode - <project>
Task completed
<session title or completion detail>
```

Validated result: one persistent Windows toast.

## 2. Permission request

Use a temporary directory so the test does not alter a real project:

```bash
mkdir -p ~/opencode-notifier-test
cd ~/opencode-notifier-test
```

Create a local `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": "ask"
  }
}
```

Start OpenCode from that directory and send:

```text
Run this exact shell command:

printf 'permission notification test\n'

Do not do anything else.
```

When OpenCode asks for approval, do not answer immediately.

Expected notification:

```text
OpenCode - opencode-notifier-test
Permission required
<permission detail>
```

Validated result: one persistent toast appeared while OpenCode was still waiting for the user's approval.

## 3. Question requiring a decision

Prompt:

```text
Use the question tool to ask me the following question:

Which notification style do you prefer?

Options:
- Compact
- Detailed
- Minimal

Do not choose an option yourself.
Do not continue until I answer the question.
```

Do not answer immediately.

Expected notification:

```text
OpenCode - opencode-notifier-test
Question requires attention
<question/session detail>
```

Validated result: exactly one persistent toast appeared while the question remained unanswered.

## 4. Subagent completion

Ensure `subagent_complete.command` is `true` in `opencode-notifier.json`.

Example prompt:

```text
Delegate this task to a subagent:
inspect the current directory and summarize the visible project structure in 3 bullet points.
```

Expected behavior:

1. OpenCode launches a subagent.
2. When the subagent finishes, a `Subagent completed` toast appears.
3. When the main session later finishes, a separate `Task completed` toast may also appear.

Example:

```text
OpenCode - opencode-notifier-test
Subagent completed
explore - Summarize project structure
```

followed by a distinct main-session notification:

```text
OpenCode - opencode-notifier-test
Task completed
<main session title>
```

Two notifications in this scenario are not necessarily duplicates; they can represent two different events.

## 5. Error event

`error` is enabled in the baseline configuration but was not intentionally forced.

A failed shell command is not necessarily equivalent to an OpenCode session error, because OpenCode may handle a tool failure and continue normally.

Recommended policy: leave the event enabled and validate it opportunistically if a real provider/session error occurs.

## 6. Plan exit event

`plan_exit` is enabled in the baseline configuration but was not intentionally forced.

This is a specific OpenCode tool event. Merely finishing a response in Plan mode, or manually switching from Plan to Build with `Tab`, did not trigger a toast during testing.

Recommended policy: treat it as optional and validate only if the normal workflow actually uses the `plan_exit` tool.

## 7. Focus suppression

Tested configuration:

```json
"suppressWhenFocused": true,
"minDuration": 0
```

Controlled prompt:

```text
Reply only with: focused test completed
```

The OpenCode tab remained focused inside Windows Terminal for the entire response.

### Observed result

A `Task completed` toast still appeared.

Therefore `suppressWhenFocused` is **not effective in the validated WSL2 + Windows Terminal environment**.

### Why

OpenCode is running inside WSL, so the notifier process sees a Linux platform rather than a native Windows process. The plugin's focus detector therefore follows its Linux focus-detection path. A normal WSL shell hosted by Windows Terminal does not expose a Linux X11/Wayland window ID for the host Windows Terminal window. The focus detector is intentionally fail-open, so when it cannot prove the terminal is focused it returns "not focused" and the notification is allowed.

This is separate from the plugin's native Windows focus-detection path (`GetForegroundWindow()`), because that path is selected only when the notifier itself runs as a native Windows process.

Upstream references:

- focus implementation: https://github.com/mohak34/opencode-notifier/blob/main/src/focus.ts
- Windows focus issue reported against 0.2.8-era behavior: https://github.com/mohak34/opencode-notifier/issues/81
- later Windows focus fix work: https://github.com/mohak34/opencode-notifier/pull/92

The Windows fix does not automatically make WSL use the native Windows branch; WSL remains a Linux process from Node/Bun's point of view.

### Baseline decision

Keep:

```json
"suppressWhenFocused": false
```

in the repository's WSL baseline so the configuration does not imply a focus-aware behavior that was not observed.

A future enhancement could implement Windows-side focus suppression in `OpenCodeNotify.ps1`, but a simple implementation would only know that **Windows Terminal** is foreground, not necessarily whether the specific OpenCode tab is the active tab. That trade-off should be tested before becoming a default.

## 8. Minimum duration

Tested configuration:

```json
"suppressWhenFocused": false,
"minDuration": 10
```

### M1 - short main task

Prompt:

```text
Reply only with: short duration test completed
```

Observed duration: approximately 2.2 seconds.

Observed result: **no toast**.

This confirms that the 10-second threshold suppresses trivial `complete` notifications.

### M2 - task longer than 10 seconds with a permission gate

Prompt:

```text
Run this exact shell command:

sleep 12

Then reply only with: long duration test completed
```

The temporary project configuration still required Bash permission approval.

Observed behavior:

1. `Permission required` toast appeared immediately while OpenCode was waiting for approval.
2. After `Allow once`, the task executed `sleep 12` and the total response lasted more than 10 seconds.
3. A separate `Task completed` toast appeared when the long-running main task finished.

This is the desired behavior: `minDuration` reduces noise from short completion events without suppressing the high-value `permission` event.

### Baseline decision

Use:

```json
"minDuration": 10
```

as the repository's recommended daily-use threshold.

The main `complete` threshold is now validated. A dedicated short/long `subagent_complete` duration test may still be run if strict subagent-specific evidence is desired, although the plugin applies the same top-level threshold to completion events.
