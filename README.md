# claude-statusline-hud

A comprehensive, btop-inspired statusline HUD plugin for Claude Code. Cross-platform (macOS + Linux) with adaptive terminal width.

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

## Preview

### Presets × Terminal Width

<details>
<summary><b>minimal</b> — 1 row</summary>

**Wide (≥100 cols):**
```
[Opus 4.6 (1M context) | Max] | my-project |  main ✓ ↑2 | ⚡ agent
```

**Normal (70–99 cols):**
```
[Opus 4.6 | Max] | my-project |  main ✓
```

**Compact (<70 cols):**
```
[Opus | Max] | my-project |  main ✓
```
</details>

<details>
<summary><b>essential</b> — 2 rows</summary>

**Wide (≥100 cols):**
```
[Opus 4.6 (1M context) | Max] | my-project |  main [+2 ~1] ↑2
Context ██████████ 42%  | Usage  ██░░░░░░░░ 6% (0h 18m / 5h) | ██████████ 23% (1d 14h / 7d)
```

**Normal (70–99 cols):**
```
[Opus 4.6 | Max] | my-project |  main ✓
Context ████████ 42%  | Usage  ████████ 6% (0h 18m / 5h) | ████████ 23% (1d 14h / 7d)
```

**Compact (<70 cols):**
```
[Opus | Max] | my-project |  main ✓
Context ██████ 42% | 5h ██████ 6% | 7d ██████ 23%
```
</details>

<details open>
<summary><b>full</b> — 3–4 rows (default)</summary>

**Wide (≥100 cols):**
```
[Opus 4.6 (1M context) | Max] │ my-project │  main ✓ ↑2 │ ⚡ agent
Context ██████████ 42% 45k/200k │ Usage  ██░░░░░░░░ 6% (0h 18m / 5h) │ ██████████ 23% (1d 14h / 7d)
› ◐ Edit auth.ts  ✓ Read ×3  │  ▸ Fix auth bug (2/5)  │  ⚡ explore
$1.31 │ ⏱ 12m 3s (api 68%) │ +142 -38 ▲ │ cache 87% │ 1k/min
```

**At high context (85%+), token breakdown appears:**
```
Context █████████░ 87% 174k/200k [in:30k cch:140k out:4k] ⚠
```

**Activity row only shows when tools/todos/agents are active — otherwise hidden.**

**Compact (<70 cols):**
```
[Opus | Max] │ my-project │  main ✓
Context ██████ 42% │ 5h ██████ 6% │ 7d ██████ 23%
$1.31 │ ⏱ 12m 3s │ +142 -38 ▲
```
</details>

<details>
<summary><b>vitals</b> — 4–5 rows</summary>

**Wide (≥100 cols):**
```
[Opus 4.6 (1M context) | Max] │ my-project │  main ✓ ↑2 │ ⚡ agent
Context ██████████ 42% 45k/200k │ Usage  ██░░░░░░░░ 6% (0h 18m / 5h) │ ██████████ 23% (1d 14h / 7d)
› ◐ Edit auth.ts  ✓ Read ×3  │  ▸ Fix auth bug (2/5)
$1.31 │ ⏱ 12m 3s (api 68%) │ +142 -38 ▲ │ cache 87% │ 1k/min
cpu ██▌  35% │ mem ███▊ 15G/16G │ gpu █    11% │ disk ▋   15G/926G │ bat ████ 80% │ load 2.41
```

**Normal (70–99 cols):**
```
[Opus 4.6 | Max] | my-project |  main ✓
Context ████████ 42%  | Usage  ████████ 6% (0h 18m / 5h) | ████████ 23% (1d 14h / 7d)
$1.31 | ⏱ 12m 3s (api 68%) | +142 -38 ▲ | cache 87% | 1k/min
cpu ██▌  35% | mem ███▊ 15G/16G | gpu █    11% | disk ▋   15G/926G | bat ████ 80% | load 2.41
```

**Compact (<70 cols):**
```
[Opus | Max] | my-project |  main ✓
Context ██████ 42% | 5h ██████ 6% | 7d ██████ 23%
$1.31 | ⏱ 12m 3s | +142 -38 ▲
cpu ██▌  35% | mem ███▊ 15G/16G | gpu █    11%
```
</details>

## Install

### Quick Install

```bash
# Step 1: Add the marketplace
/plugin marketplace add Thewhey-Brian/claude-statusline-hud

# Step 2: Install the plugin
/plugin install claude-statusline-hud
```

The plugin auto-configures on the next session start via a `SessionStart` hook. If the statusline doesn't appear, run this one-liner:

```bash
# Manual setup (only if auto-config didn't work)
bash ~/.claude/plugins/cache/claude-statusline-hud/claude-statusline-hud/1.1.0/scripts/setup.sh
```

### Uninstall

```bash
# Step 1: Remove statusLine config
bash ~/.claude/plugins/cache/claude-statusline-hud/claude-statusline-hud/*/scripts/teardown.sh

# Step 2: Remove the plugin
/plugin uninstall claude-statusline-hud
```

### Alternative: Test Locally

```bash
claude --plugin-dir /path/to/claude-statusline-hud/plugins/claude-statusline-hud
```

## Presets

| Preset | Rows | What you see |
|---|---|---|
| `minimal` | 1 | Model, directory, git branch & status |
| `essential` | 2–3 | + Activity (when active), context/usage bars |
| **`full`** | **3–5** | **+ Session stats, token breakdown at 85%+ (default)** |
| `vitals` | 4–6 | + System vitals (CPU, memory, GPU, disk, battery, load) |

### Switch preset

```bash
# Option 1: Write to file
echo "vitals" > ~/.claude/statusline-preset

# Option 2: Environment variable
export CLAUDE_STATUSLINE_PRESET=essential

# Option 3: Use the built-in skill
/statusline
```

## Adaptive Width

The statusline automatically adapts to your terminal width:

| Width | Model label | Bar width | Usage format | Row 4 vitals |
|---|---|---|---|---|
| **Wide** (≥100) | `Opus 4.6 (1M context)` | 10 chars | Full with time breakdowns | All (cpu/mem/gpu/disk/bat/load) |
| **Normal** (70–99) | `Opus 4.6` | 8 chars | Full with time breakdowns | All |
| **Compact** (<70) | `Opus` | 6 chars | Short (no time breakdowns) | cpu/mem/gpu only |

## What Each Metric Means

### Row 1 — Identity & Location
| Element | Description |
|---|---|
| `[Model \| Max]` | Active model name and subscription plan |
| `Dir` | Current working directory (`~` for home) |
| ` branch` | Git branch with dirty status (`+staged ~unstaged ?untracked`) |
| `↑↓` | Commits ahead of / behind remote |
| `⚡ agent` | Active agent name (when using `--agent`) |
| `🌿 worktree` | Active worktree name and branch |
| `NORMAL`/`INSERT` | Vim keybinding mode |

### Row 2 — Capacity Bars
| Element | Description |
|---|---|
| `Context 42% 45k/200k` | Context window fill with token counts (wide mode) |
| `[in:30k cch:140k out:4k]` | Token breakdown at 85%+ context — input, cached, output |
| `⚠` | Warning when tokens exceed 200k (autocompact pressure) |
| `Usage 5h` | Rolling 5-hour rate limit with time consumed / total |
| `Usage 7d` | Rolling 7-day rate limit with time consumed / total |
| `syncing` | Shown when using stale data during API backoff |

### Row 3 — Live Activity (conditional, only when active)
| Element | Description |
|---|---|
| `◐ Edit auth.ts` | Tool currently running with its target file/pattern |
| `✓ Read ×3` | Completed tool with invocation count |
| `▸ Fix auth bug (2/5)` | Active todo/task with completion progress |
| `⚡ explore` | Running subagent with description |

### Row 4 — Session Stats
| Element | Description |
|---|---|
| `$cost` | Total API cost this session (USD, rounded to 2 decimals) |
| `⏱ duration` | Wall-clock session time |
| `(api N%)` | % of wall-clock time spent waiting for API responses |
| `+N -N ▲▼═` | Lines added/removed with net direction (▲ growing, ▼ shrinking, ═ neutral) |
| `cache N%` | Prompt cache hit rate — higher means cheaper and faster |
| `Nk/min` | Output token throughput |

### Row 5 — System Vitals (btop-style)
| Element | Description |
|---|---|
| `cpu` | User + system CPU usage with sub-character precision bar |
| `mem` | Memory used / total |
| `gpu` | GPU utilization (Apple Silicon, NVIDIA, or AMD/Intel) |
| `disk` | Root volume used / total |
| `bat` | Battery level (red alert ≤20%) |
| `load` | 1-minute load average |

## Platform Support

| Feature | macOS | Linux |
|---|---|---|
| CPU usage | `/usr/bin/top` | `/proc/stat` delta |
| Memory | `/usr/bin/top` + `sysctl hw.memsize` | `/proc/meminfo` |
| GPU | `ioreg` (Apple Silicon) | `nvidia-smi` or `/sys/class/drm` |
| Disk | `df` | `df` |
| Battery | `pmset` | `/sys/class/power_supply/BAT0` |
| Load average | `sysctl vm.loadavg` | `/proc/loadavg` |
| Rate limit token | macOS Keychain | `~/.claude/credentials.json` |

## Performance

All expensive operations are cached to keep the statusline snappy:

| Data source | Cache TTL | Notes |
|---|---|---|
| System vitals (CPU/mem/GPU/disk) | 5 seconds | Single cache file, sourced as shell vars |
| Git info (branch, dirty, ahead/behind) | 10 seconds | |
| Rate limit API call | 30 minutes (2h after 429) | The `/api/oauth/usage` endpoint has a very low rate limit (~5 req/token). The plugin caches aggressively and falls back to stale data on errors. |

## Requirements

- **Required:** `bash`, `jq`
- **Optional:** `git` (git status), `curl` (rate limits)

## File Structure

```
claude-statusline-hud/
├── .claude-plugin/
│   └── marketplace.json       # Marketplace catalog
├── plugins/
│   └── claude-statusline-hud/
│       ├── .claude-plugin/
│       │   └── plugin.json    # Plugin manifest
│       ├── scripts/
│       │   └── statusline.sh  # Main statusline script
│       ├── skills/
│       │   └── statusline/
│       │       └── SKILL.md   # /statusline skill for preset switching
│       └── settings.json      # Auto-configures statusLine on install
├── LICENSE
└── README.md
```

## Contributing

1. Fork the repository
2. Test locally: `claude --plugin-dir ./claude-statusline-plugin`
3. Change preset to verify: `echo "vitals" > ~/.claude/statusline-preset`
4. Submit a PR

## License

MIT
