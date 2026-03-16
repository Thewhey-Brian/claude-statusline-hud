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

If the user asks to delete/disable the statusline, remove the `statusLine` key from `~/.claude/settings.json`.
