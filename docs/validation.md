# Validation

This document records the controlled tests used to validate the notification bridge.

## Baseline test settings

During validation, keep:

```json
"suppressWhenFocused": false,
"minDuration": 0
```

This avoids hiding notifications while testing.

Before each scenario, clear Windows Notification Center so the number of resulting notifications is unambiguous.

## Validation matrix

| Event | Status | Expected behavior |
| --- | --- | --- |
| `complete` | ✅ Validated | One toast after the main OpenCode session finishes |
| `permission` | ✅ Validated | One toast while OpenCode is blocked waiting for approval |
| `question` | ✅ Validated | One toast while OpenCode is blocked waiting for an answer |
| `subagent_complete` | ✅ Validated | One toast when the subagent finishes; main completion may produce a separate `complete` toast |
| `error` | 🟡 Configured | Not intentionally forced; expected to use the same custom-command transport |
| `plan_exit` | 🟡 Configured | Specific tool event; not intentionally forced |

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

Not yet part of the validated baseline.

After the core events work, test:

```json
"suppressWhenFocused": true
```

Desired behavior:

- OpenCode terminal focused -> no completion toast
- another Windows application focused -> toast appears

Because the final notification transport is a custom PowerShell command rather than the plugin's native backend, verify this behavior empirically on the target workstation before relying on it.

## 8. Minimum duration

Not yet part of the validated baseline.

After validation, consider increasing:

```json
"minDuration": 0
```

to a value such as `10` or `15` seconds to reduce noise from short `complete` and `subagent_complete` events.

Permission and question events are high-value attention signals and should not be accidentally filtered during tuning.
