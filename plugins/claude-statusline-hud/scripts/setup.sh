#!/usr/bin/env bash
# Post-install / SessionStart: configure statusLine and check for updates
# Runs each session start — idempotent and lightweight.

SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SL_CMD="bash ${SCRIPT_DIR}/statusline.sh"

# --- Ensure settings file exists ---
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$HOME/.claude"
  echo '{}' > "$SETTINGS_FILE"
fi

# --- Inject statusLine config if not already set ---
# hideVimModeIndicator: the HUD renders vim.mode itself, so suppress the
# built-in "-- INSERT --" line to avoid showing it twice.
EXISTING=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE" 2>/dev/null)
HIDE_VIM=$(jq -r '.statusLine.hideVimModeIndicator // false' "$SETTINGS_FILE" 2>/dev/null)
if [ "$EXISTING" != "$SL_CMD" ] || [ "$HIDE_VIM" != "true" ]; then
  TMP=$(mktemp)
  jq --arg cmd "$SL_CMD" '.statusLine = ((.statusLine // {}) + {"type": "command", "command": $cmd, "hideVimModeIndicator": true})' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
fi

# --- Create default preset if none exists ---
if [ ! -f "$HOME/.claude/statusline-preset" ]; then
  echo "full" > "$HOME/.claude/statusline-preset"
fi

# --- Version update check (lightweight, non-blocking) ---
# Compare installed version vs marketplace version. Print notice if outdated.
INSTALLED_VERSION=""
MARKETPLACE_VERSION=""

# Find installed plugin.json
PLUGIN_JSON="${SCRIPT_DIR}/../.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
  INSTALLED_VERSION=$(jq -r '.version // ""' "$PLUGIN_JSON" 2>/dev/null)
fi

# Find marketplace plugin.json (updated by /plugin marketplace update)
for mp_json in "$HOME/.claude/plugins/marketplaces/claude-statusline-hud/plugins/claude-statusline-hud/.claude-plugin/plugin.json" \
               "$HOME/.claude/plugins/marketplaces/claude-statusline-hud/.claude-plugin/marketplace.json"; do
  if [ -f "$mp_json" ]; then
    # Try plugin.json first, fall back to marketplace.json
    v=$(jq -r '.version // (.plugins[0].version) // ""' "$mp_json" 2>/dev/null)
    if [ -n "$v" ] && [ "$v" != "null" ]; then
      MARKETPLACE_VERSION="$v"
      break
    fi
  fi
done

if [ -n "$INSTALLED_VERSION" ] && [ -n "$MARKETPLACE_VERSION" ] && [ "$INSTALLED_VERSION" != "$MARKETPLACE_VERSION" ]; then
  # Write update notice to a temp file — statusline.sh can optionally display it
  echo "${MARKETPLACE_VERSION}" > "/tmp/.claude_sl_update_available"
fi

exit 0
