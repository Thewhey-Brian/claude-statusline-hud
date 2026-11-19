---
name: statusline
description: Configure the statusline HUD preset. Use when the user wants to change the statusline layout, switch presets (minimal/essential/full/vitals), or customize the HUD.
---

# Statusline Configuration

The user wants to configure their statusline HUD. The available presets are:

- **minimal** — 1 row: Model, directory, git branch/status
- **essential** — 2 rows: + Context window bar, rate limit bars with time breakdowns
- **full** — 3 rows (default): + Cost, duration, lines changed, cache hit rate, throughput
- **vitals** — 4 rows: + System vitals (CPU, memory, GPU, disk, battery, load average)

To change the preset, write the preset name to `~/.claude/statusline-preset`:

```bash
echo "full" > ~/.claude/statusline-preset
```

The user can also set the `CLAUDE_STATUSLINE_PRESET` environment variable.

Other options:

- Per-model weekly limits (e.g. `Fable 100%` after the 7d bar) show by default when the plan has them. To hide them, set `CLAUDE_SL_MODEL_LIMITS=0` in the `env` block of `~/.claude/settings.json`.
- To refresh the HUD on a timer (e.g. live system vitals), add `"refreshInterval": 5` (seconds, ≥1) to the `statusLine` object in `~/.claude/settings.json`. Keep the existing `type`, `command` and `hideVimModeIndicator` keys.

If the user asks to delete/disable the statusline, remove the `statusLine` key from `~/.claude/settings.json`.
