#!/usr/bin/env bash
# ================================================================
#  Claude Statusline HUD — cross-platform (macOS + Linux)
# ================================================================
#  Presets (set via CLAUDE_STATUSLINE_PRESET or ~/.claude/statusline-preset):
#
#    minimal   — 1 row:  [Model | Max]  Dir  Git
#    essential — 2 rows: + Activity (when active), Context/Usage bars
#    full      — 3–4 rows: + Stats (cost, duration, lines, etc.)  (default)
#    vitals    — 4–5 rows: + System vitals (CPU, Mem, GPU, Disk, Battery)
# ================================================================

set -f  # disable globbing for safety

input=$(cat)

# --- Platform detection ---
OS="$(uname -s)"
is_mac() { [ "$OS" = "Darwin" ]; }
is_linux() { [ "$OS" = "Linux" ]; }

# --- Terminal width detection ---
COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}"
if [ "$COLS" -lt 70 ] 2>/dev/null; then TIER="compact"
elif [ "$COLS" -lt 100 ] 2>/dev/null; then TIER="normal"
else TIER="wide"; fi

# --- Determine preset ---
PRESET="${CLAUDE_STATUSLINE_PRESET:-}"
if [ -z "$PRESET" ] && [ -f "$HOME/.claude/statusline-preset" ]; then
  PRESET=$(tr -d '[:space:]' < "$HOME/.claude/statusline-preset")
fi
PRESET="${PRESET:-full}"

# --- Parse JSON ---
j() { printf '%s' "$input" | jq -r "$1"; }

MODEL=$(j '.model.display_name // "Unknown"')
DIR=$(j '.workspace.current_dir // ""')
PCT=$(j '.context_window.used_percentage // 0 | floor')
COST_RAW=$(j '.cost.total_cost_usd // 0')
DURATION_MS=$(j '.cost.total_duration_ms // 0 | floor')
API_MS=$(j '.cost.total_api_duration_ms // 0 | floor')
LINES_ADD=$(j '.cost.total_lines_added // 0')
LINES_DEL=$(j '.cost.total_lines_removed // 0')
VIM_MODE=$(j '.vim.mode // ""')
AGENT_NAME=$(j '.agent.name // ""')
WT_NAME=$(j '.worktree.name // ""')
WT_BRANCH=$(j '.worktree.branch // ""')
EXCEEDS_200K=$(j '.exceeds_200k_tokens // false')
INPUT_TOK=$(j '.context_window.current_usage.input_tokens // 0')
CACHE_CREATE=$(j '.context_window.current_usage.cache_creation_input_tokens // 0')
CACHE_READ=$(j '.context_window.current_usage.cache_read_input_tokens // 0')
TOTAL_OUT=$(j '.context_window.total_output_tokens // 0')
TRANSCRIPT=$(j '.transcript_path // ""')
CTX_SIZE=$(j '.context_window.context_window_size // 200000')

# --- Smart directory name ---
if [ "$DIR" = "$HOME" ]; then DIR_NAME="~"
elif [ -n "$DIR" ]; then DIR_NAME="${DIR##*/}"
else DIR_NAME=""; fi

# --- Adaptive model label ---
case "$TIER" in
  compact) MODEL_LABEL="${MODEL%% *}" ;;
  normal)  MODEL_LABEL="${MODEL%% (*}" ;;
  wide)    MODEL_LABEL="$MODEL" ;;
esac

# --- Adaptive bar widths ---
case "$TIER" in
  compact) BAR_W=6;  RL_BAR_W=6  ;;
  normal)  BAR_W=8;  RL_BAR_W=8  ;;
  wide)    BAR_W=10; RL_BAR_W=10 ;;
esac

# --- Colors ---
CYAN=$'\033[36m'    GREEN=$'\033[32m'   YELLOW=$'\033[33m'  RED=$'\033[31m'
BLUE=$'\033[34m'    MAGENTA=$'\033[35m' WHITE=$'\033[97m'
RST=$'\033[0m'      BOLD=$'\033[1m'     DIM=$'\033[2m'     ITAL=$'\033[3m'
BG_YELLOW=$'\033[43m'

SEP=" ${DIM}│${RST} "

# --- Helpers ---
make_bar() {
  local pct=$1 width=${2:-10}
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local filled=$((pct * width / 100)) empty=$((width - pct * width / 100))
  local bar=""
  [ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
  [ "$empty" -gt 0 ] && bar="${bar}$(printf "%${empty}s" | tr ' ' '░')"
  printf '%s' "$bar"
}

mini_bar() {
  local pct=$1
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local chars_0="▏" chars_1="▎" chars_2="▍" chars_3="▌"
  local chars_4="▋" chars_5="▊" chars_6="▉" chars_7="█"
  local width=4 total=$((pct * width))
  local full=$((total / 100)) remainder=$(( (total % 100) * 8 / 100 ))
  local bar="" i=0
  while [ "$i" -lt "$full" ] && [ "$i" -lt "$width" ]; do bar="${bar}█"; i=$((i+1)); done
  if [ "$i" -lt "$width" ] && [ "$remainder" -gt 0 ]; then
    eval "bar=\"\${bar}\${chars_${remainder}}\""; i=$((i+1))
  fi
  while [ "$i" -lt "$width" ]; do bar="${bar} "; i=$((i+1)); done
  printf '%s' "$bar"
}

bar_color() {
  if [ "$1" -ge 90 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

bar_color_inv() {
  if [ "$1" -le 10 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$1" -le 30 ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

fmt_dur() {
  local s=$(($1 / 1000))
  local h=$((s/3600)) m=$(((s%3600)/60)) sec=$((s%60))
  if [ "$h" -gt 0 ]; then printf '%dh %dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf '%dm %ds' "$m" "$sec"
  else printf '%ds' "$sec"; fi
}

fmt_tok() {
  if [ "$1" -ge 1000000 ] 2>/dev/null; then printf '%dM' "$(($1/1000000))"
  elif [ "$1" -ge 1000 ] 2>/dev/null; then printf '%dk' "$(($1/1000))"
  else printf '%d' "$1"; fi
}

fmt_cost() { printf '$%s' "$(printf '%s' "$1" | awk '{printf "%.2f", $1}')"; }

file_age() {
  local f="$1"
  [ -f "$f" ] || { echo 9999; return; }
  if is_mac; then echo $(( $(date +%s) - $(stat -f%m "$f" 2>/dev/null || echo 0) ))
  else echo $(( $(date +%s) - $(stat -c%Y "$f" 2>/dev/null || echo 0) )); fi
}

NOW=$(date +%s)

# =============================================
# GIT INFO (cached 10s)
# =============================================
GIT_DISPLAY=""
if [ -n "$DIR" ]; then
  GIT_CACHE="/tmp/.claude_sl_git"
  if [ "$(file_age "$GIT_CACHE")" -lt 10 ]; then
    GIT_INFO=$(cat "$GIT_CACHE")
  else
    if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
      GB=$(git -C "$DIR" symbolic-ref --short HEAD 2>/dev/null || git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
      GD=""
      gs=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
      gu=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
      gq=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
      [ "$gs" -gt 0 ] && GD="${GD}+${gs}"
      [ "$gu" -gt 0 ] && GD="${GD} ~${gu}"
      [ "$gq" -gt 0 ] && GD="${GD} ?${gq}"
      UPSTREAM=$(git -C "$DIR" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
      GAB=""
      if [ -n "$UPSTREAM" ]; then
        AB=$(git -C "$DIR" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
        AHEAD=$(printf '%s' "$AB" | awk '{print $1}')
        BEHIND=$(printf '%s' "$AB" | awk '{print $2}')
        [ "${AHEAD:-0}" -gt 0 ] && GAB="↑${AHEAD}"
        [ "${BEHIND:-0}" -gt 0 ] && GAB="${GAB}↓${BEHIND}"
      fi
      GIT_INFO="${GB}|${GD}|${GAB}"
    else
      GIT_INFO="||"
    fi
    printf '%s' "$GIT_INFO" > "$GIT_CACHE"
  fi
  GB=$(printf '%s' "$GIT_INFO" | cut -d'|' -f1)
  GD=$(printf '%s' "$GIT_INFO" | cut -d'|' -f2)
  GAB=$(printf '%s' "$GIT_INFO" | cut -d'|' -f3)
  if [ -n "$GB" ]; then
    GIT_DISPLAY="${MAGENTA} ${GB}${RST}"
    if [ -n "$GD" ]; then GIT_DISPLAY="${GIT_DISPLAY} ${YELLOW}[${GD}]${RST}"
    else GIT_DISPLAY="${GIT_DISPLAY} ${GREEN}✓${RST}"; fi
    [ -n "$GAB" ] && GIT_DISPLAY="${GIT_DISPLAY} ${CYAN}${GAB}${RST}"
  fi
fi

# --- Badges ---
BADGES=""
[ -n "$VIM_MODE" ] && BADGES="${BADGES}${SEP}${BOLD}${BLUE}${VIM_MODE}${RST}"
[ -n "$AGENT_NAME" ] && BADGES="${BADGES}${SEP}${BOLD}${CYAN}⚡ ${AGENT_NAME}${RST}"
[ -n "$WT_NAME" ] && BADGES="${BADGES}${SEP}${DIM}🌿 ${WT_NAME}${WT_BRANCH:+→${WT_BRANCH}}${RST}"

# =============================================================
# ROW 1: [Model | Max] │ Dir │ Git │ Badges     [ALL PRESETS]
# =============================================================
R1="${BOLD}${CYAN}[${MODEL_LABEL} | Max]${RST}"
R1="${R1}${SEP}${BOLD}${GREEN}${DIR_NAME}${RST}"
[ -n "$GIT_DISPLAY" ] && R1="${R1}${SEP}${GIT_DISPLAY}"
[ -n "$BADGES" ] && R1="${R1}${BADGES}"
printf '%b\n' "$R1"

[ "$PRESET" = "minimal" ] && exit 0

# =============================================================
# ROW 2 (conditional): Live Activity — Tools │ Todos │ Agents
#   Shown when there's active work. Parsed from transcript.
#   Cached 2s. Appears in ESSENTIAL+ presets.
# =============================================================

ACTIVITY_CACHE="/tmp/.claude_sl_activity"
ACTIVITY_LINE=""

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  if [ "$(file_age "$ACTIVITY_CACHE")" -lt 2 ]; then
    ACTIVITY_LINE=$(cat "$ACTIVITY_CACHE")
  else
    ACTIVITY_LINE=$(tail -100 "$TRANSCRIPT" 2>/dev/null | jq -rs '
      [.[] | select(.type == "tool_use" or .type == "tool_result")] as $events |
      (reduce $events[] as $e ({};
        if $e.type == "tool_use" then
          .[$e.id] = {name: $e.name, target: (
            if ($e.name == "Edit" or $e.name == "Write" or $e.name == "Read") then
              ($e.input.file_path // "" | split("/") | last)
            elif ($e.name == "Grep" or $e.name == "Glob") then
              ($e.input.pattern // "")[0:20]
            elif $e.name == "Bash" then
              ($e.input.command // "")[0:25]
            elif $e.name == "Agent" then
              ($e.input.description // "agent")
            else "" end
          ), done: false}
        elif $e.type == "tool_result" then
          .[$e.tool_use_id].done = true
        else . end
      )) as $tools |
      ([$tools | to_entries | .[-5:] | reverse[] |
        if .value.done then "✓ " + .value.name
        else "◐ " + .value.name + (if .value.target != "" then " " + .value.target else "" end) end
      ] | join("  ")) as $tool_str |
      [.[] | select(.type == "tool_use" and (.name == "TodoWrite" or .name == "TaskCreate" or .name == "TaskUpdate"))] as $todo_events |
      (if ($todo_events | length) > 0 then
        ($todo_events | last) as $last_todo |
        if $last_todo.name == "TodoWrite" then
          ($last_todo.input.todos // []) as $todos |
          ([$todos[] | select(.status == "completed")] | length) as $done |
          ([$todos[] | select(.status == "in_progress")] | first // null) as $current |
          if $current then "▸ " + ($current.content // "task")[0:30] + " (" + ($done|tostring) + "/" + ($todos|length|tostring) + ")"
          elif ($todos | length) > 0 then "✓ todos " + ($done|tostring) + "/" + ($todos|length|tostring)
          else "" end
        else "" end
      else "" end) as $todo_str |
      ([$tools | to_entries[] | select(.value.name == "Agent" and .value.done == false)] |
        if length > 0 then (first | "⚡ " + .value.target) else "" end
      ) as $agent_str |
      [[$tool_str, $todo_str, $agent_str] | .[] | select(length > 0)] | join("  │  ")
    ' 2>/dev/null)
    printf '%s' "$ACTIVITY_LINE" > "$ACTIVITY_CACHE"
  fi
fi

if [ -n "$ACTIVITY_LINE" ]; then
  printf '%b\n' "${DIM}›${RST} ${ACTIVITY_LINE}"
fi

# =============================================================
# ROW 3: Context bar │ Usage bars                   [ESSENTIAL+]
# =============================================================

# --- Autocompact buffer estimation ---
# Inflate by ~10% above 70% to reflect true context pressure.
TOTAL_INPUT=$((INPUT_TOK + CACHE_CREATE + CACHE_READ))
ADJ_PCT=$PCT
if [ "$PCT" -ge 70 ] 2>/dev/null; then
  ADJ_PCT=$(( PCT + (PCT - 70) * 10 / 30 ))
  [ "$ADJ_PCT" -gt 100 ] && ADJ_PCT=100
fi

CTX_CLR=$(bar_color "$ADJ_PCT")
CTX_BAR=$(make_bar "$ADJ_PCT" "$BAR_W")

# --- Context warning: ⚠ when exceeds 200k OR adjusted PCT ≥ 90% ---
CTX_WARN=""
if [ "$EXCEEDS_200K" = "true" ] || [ "$ADJ_PCT" -ge 90 ] 2>/dev/null; then
  CTX_WARN=" ${BOLD}${BG_YELLOW} ⚠ ${RST}"
fi

CTX_LABEL="${BOLD}${PCT}%${RST}"

# ---- Rate limit: token discovery ----
USAGE_CACHE="/tmp/.claude_sl_usage"
USAGE_META="/tmp/.claude_sl_usage_meta"
USAGE_LOCK="/tmp/.claude_sl_usage.lock"
USAGE_JSON=""
RL_SYNCING=0
RL_ERR=""

get_oauth_token() {
  local tk="" cred_json=""
  if is_mac; then
    for svc in "Claude Code-credentials" "claude-code-credentials" "Claude-credentials"; do
      cred_json=$(security find-generic-password -s "$svc" -w 2>/dev/null)
      [ -z "$cred_json" ] && continue
      local expires_at=$(printf '%s' "$cred_json" | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null)
      if [ "$expires_at" != "0" ] && [ -n "$expires_at" ] && [ "$NOW" -gt "$expires_at" ] 2>/dev/null; then continue; fi
      tk=$(printf '%s' "$cred_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      [ -n "$tk" ] && { printf '%s' "$tk"; return 0; }
    done
    cred_json=$(security find-generic-password -a "claude-code" -w 2>/dev/null)
    if [ -n "$cred_json" ]; then
      tk=$(printf '%s' "$cred_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      [ -n "$tk" ] && { printf '%s' "$tk"; return 0; }
    fi
  fi
  for cred_file in "$HOME/.claude/.credentials.json" "$HOME/.claude/credentials.json" \
    "$HOME/.config/claude/credentials.json" "${XDG_CONFIG_HOME:-$HOME/.config}/claude-code/credentials.json"; do
    if [ -f "$cred_file" ]; then
      local expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$cred_file" 2>/dev/null)
      if [ "$expires_at" != "0" ] && [ -n "$expires_at" ] && [ "$NOW" -gt "$expires_at" ] 2>/dev/null; then continue; fi
      tk=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null)
      [ -n "$tk" ] && { printf '%s' "$tk"; return 0; }
    fi
  done
  [ -n "${CLAUDE_OAUTH_TOKEN:-}" ] && { printf '%s' "$CLAUDE_OAUTH_TOKEN"; return 0; }
  return 1
}

# ---- Rate limit: fetch with exponential backoff ----
RATE_LIMITED_COUNT=0
if [ -f "$USAGE_META" ]; then eval "$(cat "$USAGE_META")"; fi

CACHE_TTL=300
if [ "$RATE_LIMITED_COUNT" -gt 0 ]; then
  BACKOFF=$((60 * (1 << (RATE_LIMITED_COUNT - 1))))
  [ "$BACKOFF" -gt 300 ] && BACKOFF=300
  CACHE_TTL=$BACKOFF
fi

if [ "$(file_age "$USAGE_CACHE")" -lt "$CACHE_TTL" ]; then
  USAGE_JSON=$(cat "$USAGE_CACHE")
  [ "$RATE_LIMITED_COUNT" -gt 0 ] && RL_SYNCING=1
else
  if ( set -o noclobber; echo $$ > "$USAGE_LOCK" ) 2>/dev/null; then
    trap "rm -f '$USAGE_LOCK'" EXIT
    TK=$(get_oauth_token)
    if [ -n "$TK" ]; then
      RESP=$(curl -s --max-time 5 -w '\n%{http_code}' "https://api.anthropic.com/api/oauth/usage" \
        -H "Accept: application/json" -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TK" -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
      HTTP_CODE=$(printf '%s' "$RESP" | tail -1)
      BODY=$(printf '%s' "$RESP" | sed '$d')
      if [ "$HTTP_CODE" = "200" ] && printf '%s' "$BODY" | jq -e '.five_hour' >/dev/null 2>&1; then
        USAGE_JSON="$BODY"
        printf '%s' "$USAGE_JSON" > "$USAGE_CACHE"
        printf "RATE_LIMITED_COUNT=0\nLAST_ERR=''\n" > "$USAGE_META"
      elif [ "$HTTP_CODE" = "429" ]; then
        RATE_LIMITED_COUNT=$((RATE_LIMITED_COUNT + 1))
        printf "RATE_LIMITED_COUNT=%d\nLAST_ERR='rate limited'\n" "$RATE_LIMITED_COUNT" > "$USAGE_META"
        if [ -f "$USAGE_CACHE" ]; then USAGE_JSON=$(cat "$USAGE_CACHE"); RL_SYNCING=1; touch "$USAGE_CACHE"
        else RL_ERR="rate limited"; fi
      elif [ "$HTTP_CODE" = "401" ]; then RL_ERR="token expired"
      elif [ "$HTTP_CODE" = "403" ]; then RL_ERR="not on Max plan"
      else
        if [ -f "$USAGE_CACHE" ]; then USAGE_JSON=$(cat "$USAGE_CACHE"); RL_SYNCING=1
        else RL_ERR="http ${HTTP_CODE:-err}"; fi
      fi
    else RL_ERR="no token"; fi
    rm -f "$USAGE_LOCK"; trap - EXIT
  else
    [ -f "$USAGE_CACHE" ] && USAGE_JSON=$(cat "$USAGE_CACHE")
    [ "$(file_age "$USAGE_LOCK")" -gt 30 ] && rm -f "$USAGE_LOCK"
  fi
fi

[ -z "$USAGE_JSON" ] && [ -z "$RL_ERR" ] && [ -n "${LAST_ERR:-}" ] && RL_ERR="$LAST_ERR"

# ---- Build rate limit display ----
RL_DISPLAY=""
SYNC_TAG=""
[ "$RL_SYNCING" = "1" ] && SYNC_TAG=" ${DIM}${ITAL}syncing${RST}"

if [ -n "$USAGE_JSON" ]; then
  U5=$(printf '%s' "$USAGE_JSON" | jq -r '.five_hour.utilization // 0' | cut -d. -f1)
  U5_CLR=$(bar_color "$U5"); U5_BAR=$(make_bar "$U5" "$RL_BAR_W")
  U5_TOTAL_MIN=$((U5 * 300 / 100)); U5_H=$((U5_TOTAL_MIN / 60)); U5_M=$((U5_TOTAL_MIN % 60))
  U7=$(printf '%s' "$USAGE_JSON" | jq -r '.seven_day.utilization // 0' | cut -d. -f1)
  U7_CLR=$(bar_color "$U7"); U7_BAR=$(make_bar "$U7" "$RL_BAR_W")
  U7_TOTAL_H=$((U7 * 168 / 100)); U7_D=$((U7_TOTAL_H / 24)); U7_H=$((U7_TOTAL_H % 24))
  if [ "$TIER" = "compact" ]; then
    RL_DISPLAY="${DIM}5h${RST} ${U5_CLR}${U5_BAR}${RST} ${BOLD}${U5}%${RST}${SEP}${DIM}7d${RST} ${U7_CLR}${U7_BAR}${RST} ${BOLD}${U7}%${RST}${SYNC_TAG}"
  else
    RL_DISPLAY="${DIM}Usage${RST}  ${U5_CLR}${U5_BAR}${RST} ${BOLD}${U5}%${RST} ${DIM}(${U5_H}h ${U5_M}m / 5h)${RST}${SEP}${U7_CLR}${U7_BAR}${RST} ${BOLD}${U7}%${RST} ${DIM}(${U7_D}d ${U7_H}h / 7d)${RST}${SYNC_TAG}"
  fi
else
  if [ "$TIER" = "compact" ]; then RL_DISPLAY="${DIM}usage ${YELLOW}--${RST}"
  else RL_DISPLAY="${DIM}Usage${RST}  ${YELLOW}${BOLD}--${RST} ${DIM}(${RL_ERR:-unavailable})${RST}"; fi
fi

R3="${DIM}Context${RST} ${CTX_CLR}${CTX_BAR}${RST} ${CTX_LABEL}${CTX_WARN}"
R3="${R3}${SEP}${RL_DISPLAY}"
printf '%b\n' "$R3"

# --- Token breakdown row (conditional): shown at 85%+ context ---
if [ "$PCT" -ge 85 ] 2>/dev/null && [ "$TOTAL_INPUT" -gt 0 ] && [ "$TIER" != "compact" ]; then
  CTX_TOTAL=$((TOTAL_INPUT + TOTAL_OUT))
  printf '%b\n' "  ${DIM}tokens${RST} $(fmt_tok $CTX_TOTAL)/$(fmt_tok $CTX_SIZE) ${DIM}—${RST} ${DIM}in${RST} ${BOLD}$(fmt_tok $INPUT_TOK)${RST} ${DIM}cached${RST} ${GREEN}${BOLD}$(fmt_tok $CACHE_READ)${RST} ${DIM}created${RST} ${YELLOW}$(fmt_tok $CACHE_CREATE)${RST} ${DIM}out${RST} ${BOLD}$(fmt_tok $TOTAL_OUT)${RST}"
fi

[ "$PRESET" = "essential" ] && exit 0

# =============================================================
# ROW 4: Stats — Cost │ Duration │ Lines │ Cache │ Speed  [FULL+]
# =============================================================

COST_FMT=$(fmt_cost "$COST_RAW")
DUR=$(fmt_dur "$DURATION_MS")
EFF=""
if [ "$DURATION_MS" -gt 0 ] && [ "$API_MS" -gt 0 ]; then
  EFF=" ${DIM}(api $((API_MS * 100 / DURATION_MS))%)${RST}"
fi

LINES=""
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  NET=$((LINES_ADD - LINES_DEL))
  if [ "$NET" -gt 0 ]; then NI="${GREEN}▲${RST}"
  elif [ "$NET" -lt 0 ]; then NI="${RED}▼${RST}"
  else NI="${YELLOW}═${RST}"; fi
  LINES="${GREEN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST} ${NI}"
fi

CACHE_HIT=""
if [ "$TOTAL_INPUT" -gt 0 ]; then
  CP=$((CACHE_READ * 100 / TOTAL_INPUT))
  if [ "$CP" -ge 80 ]; then CC="$GREEN"; elif [ "$CP" -ge 40 ]; then CC="$YELLOW"; else CC="$RED"; fi
  CACHE_HIT="${DIM}cache${RST} ${CC}${BOLD}${CP}%${RST}"
fi

THROUGHPUT=""
if [ "$DURATION_MS" -gt 0 ] && [ "$TOTAL_OUT" -gt 0 ]; then
  TPM=$((TOTAL_OUT * 60000 / DURATION_MS))
  THROUGHPUT="${DIM}$(fmt_tok "$TPM")/min${RST}"
fi

R4="${BOLD}${COST_FMT}${RST}"
R4="${R4}${SEP}⏱ ${DUR}${EFF}"
[ -n "$LINES" ] && R4="${R4}${SEP}${LINES}"
[ -n "$CACHE_HIT" ] && R4="${R4}${SEP}${CACHE_HIT}"
[ -n "$THROUGHPUT" ] && R4="${R4}${SEP}${THROUGHPUT}"
printf '%b\n' "$R4"

[ "$PRESET" = "full" ] && exit 0

# =============================================================
# ROW 5: System Vitals — btop-style mini bars          [VITALS]
# =============================================================

SYS_CACHE="/tmp/.claude_sl_sys"
if [ "$(file_age "$SYS_CACHE")" -lt 5 ]; then
  . "$SYS_CACHE"
else
  if is_mac; then
    TOP_OUT=$(/usr/bin/top -l1 -s0 -n0 2>/dev/null)
    CPU_USER=$(printf '%s' "$TOP_OUT" | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    CPU_SYS=$(printf '%s' "$TOP_OUT" | grep "CPU usage" | awk '{print $5}' | tr -d '%')
    CPU_USED=$(awk "BEGIN{printf \"%d\", ${CPU_USER:-0} + ${CPU_SYS:-0}}")
    MEM_USED=$(printf '%s' "$TOP_OUT" | grep "PhysMem" | awk '{print $2}')
    MEM_TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    MEM_TOTAL_GB=$(awk "BEGIN{printf \"%.0f\", ${MEM_TOTAL_BYTES:-0} / 1073741824}")
    MEM_USED_NUM=$(printf '%s' "$MEM_USED" | tr -d 'GM')
    if printf '%s' "$MEM_USED" | grep -q 'G'; then
      MEM_USED_BYTES=$(awk "BEGIN{printf \"%.0f\", ${MEM_USED_NUM} * 1073741824}")
    else
      MEM_USED_BYTES=$(awk "BEGIN{printf \"%.0f\", ${MEM_USED_NUM} * 1048576}")
    fi
    [ "$MEM_TOTAL_BYTES" -gt 0 ] 2>/dev/null && \
      MEM_PCT=$(awk "BEGIN{printf \"%.0f\", ${MEM_USED_BYTES} / ${MEM_TOTAL_BYTES} * 100}") || MEM_PCT=0
    GPU_PCT=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | grep '"Device Utilization %"' | head -1 | awk -F'= *' '{print $2}' | tr -d '}' | tr -d ' ')
    GPU_PCT="${GPU_PCT:-0}"
    BV=$(pmset -g batt 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
  elif is_linux; then
    read -r _ cu cn cs ci _ < /proc/stat 2>/dev/null
    PREV_STAT="/tmp/.claude_sl_cpu_prev"
    if [ -f "$PREV_STAT" ]; then
      read -r pu pn ps pi < "$PREV_STAT"
      TOTAL_D=$(( (cu+cn+cs+ci) - (pu+pn+ps+pi) )); IDLE_D=$(( ci - pi ))
      [ "$TOTAL_D" -gt 0 ] && CPU_USED=$(( (TOTAL_D - IDLE_D) * 100 / TOTAL_D )) || CPU_USED=0
    else CPU_USED=0; fi
    printf '%s' "$cu $cn $cs $ci" > "$PREV_STAT"
    MEM_TOTAL_KB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
    MEM_AVAIL_KB=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)
    MEM_USED_KB=$((${MEM_TOTAL_KB:-0} - ${MEM_AVAIL_KB:-0}))
    MEM_TOTAL_GB=$(( ${MEM_TOTAL_KB:-0} / 1048576 ))
    MEM_USED="$(awk "BEGIN{printf \"%.1f\", ${MEM_USED_KB:-0} / 1048576}")G"
    [ "${MEM_TOTAL_KB:-0}" -gt 0 ] && MEM_PCT=$(( MEM_USED_KB * 100 / MEM_TOTAL_KB )) || MEM_PCT=0
    if command -v nvidia-smi >/dev/null 2>&1; then
      GPU_PCT=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    else GPU_PCT=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0); fi
    GPU_PCT="${GPU_PCT:-0}"
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then BV=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    elif [ -f /sys/class/power_supply/BAT1/capacity ]; then BV=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
    else BV=""; fi
  fi
  DISK_LINE=$(df -h / 2>/dev/null | tail -1)
  DISK_USED=$(printf '%s' "$DISK_LINE" | awk '{print $3}')
  DISK_TOTAL=$(printf '%s' "$DISK_LINE" | awk '{print $2}')
  DISK_PCT=$(printf '%s' "$DISK_LINE" | awk '{gsub(/%/,""); print $5}')
  if is_mac; then LOAD_AVG=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
  else LOAD_AVG=$(awk '{print $1}' /proc/loadavg 2>/dev/null); fi
  cat > "$SYS_CACHE" <<CACHE
CPU_USED='${CPU_USED:-0}'
MEM_USED='${MEM_USED:-0M}'
MEM_TOTAL_GB='${MEM_TOTAL_GB:-0}'
MEM_PCT='${MEM_PCT:-0}'
GPU_PCT='${GPU_PCT:-0}'
DISK_USED='${DISK_USED:-0G}'
DISK_TOTAL='${DISK_TOTAL:-0G}'
DISK_PCT='${DISK_PCT:-0}'
BV='${BV:-}'
LOAD_AVG='${LOAD_AVG:-0}'
CACHE
fi

R5="${DIM}cpu${RST} $(bar_color "${CPU_USED:-0}")$(mini_bar "${CPU_USED:-0}")${RST} ${BOLD}${CPU_USED:-0}%${RST}"
R5="${R5}${SEP}${DIM}mem${RST} $(bar_color "${MEM_PCT:-0}")$(mini_bar "${MEM_PCT:-0}")${RST} ${BOLD}${MEM_USED:-0M}${RST}${DIM}/${MEM_TOTAL_GB:-0}G${RST}"
R5="${R5}${SEP}${DIM}gpu${RST} $(bar_color "${GPU_PCT:-0}")$(mini_bar "${GPU_PCT:-0}")${RST} ${BOLD}${GPU_PCT:-0}%${RST}"
if [ "$TIER" != "compact" ]; then
  R5="${R5}${SEP}${DIM}disk${RST} $(bar_color "${DISK_PCT:-0}")$(mini_bar "${DISK_PCT:-0}")${RST} ${BOLD}${DISK_USED:-0G}${RST}${DIM}/${DISK_TOTAL:-0G}${RST}"
  if [ -n "$BV" ]; then
    if [ "$BV" -le 20 ] 2>/dev/null; then
      R5="${R5}${SEP}${DIM}bat${RST} ${RED}${BOLD}$(mini_bar "$BV")${RST} ${RED}${BOLD}${BV}%${RST}"
    else
      R5="${R5}${SEP}${DIM}bat${RST} ${GREEN}$(mini_bar "$BV")${RST} ${DIM}${BV}%${RST}"
    fi
  fi
  [ -n "$LOAD_AVG" ] && R5="${R5}${SEP}${DIM}load${RST} ${BOLD}${LOAD_AVG}${RST}"
fi
printf '%b\n' "$R5"
