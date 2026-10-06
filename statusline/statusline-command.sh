#!/usr/bin/env bash
input=$(cat)

j() { printf '%s' "$input" | jq -r "$1 // empty"; }

model=$(j '.model.display_name')
effort=$(j '.effort.level')
session_id=$(j '.session_id')
cur_dir=$(j '.workspace.current_dir')
ctx_used=$(j '.context_window.used_percentage')
ctx_in=$(j '.context_window.total_input_tokens')
ctx_out=$(j '.context_window.total_output_tokens')
ctx_size=$(j '.context_window.context_window_size')
five=$(j '.rate_limits.five_hour.used_percentage')
week=$(j '.rate_limits.seven_day.used_percentage')

R=$'\033[0m'
GREY=$'\033[38;5;244m'
WHITE=$'\033[38;5;252m'
BLUE=$'\033[38;5;75m'
ORANGE=$'\033[38;5;214m'
YELLOW=$'\033[38;5;221m'
GREEN=$'\033[38;5;77m'
SEP="${GREY}│${R}"

hue() {
  local p=${1%%.*}
  if   [ "${p:-0}" -ge 85 ]; then printf '\033[38;5;203m'
  elif [ "${p:-0}" -ge 60 ]; then printf '\033[38;5;214m'
  else                            printf '%s' "$GREEN"
  fi
}

bar() {
  local p=${1%%.*} w=8 filled i
  p=${p:-0}
  filled=$(( (p * w + 50) / 100 ))
  [ "$filled" -gt "$w" ] && filled=$w
  [ "$filled" -lt 0 ] && filled=0
  printf '%s' "$(hue "$p")"
  for ((i = 0; i < filled; i++)); do printf '▰'; done
  printf '%s' "$GREY"
  for ((i = filled; i < w; i++)); do printf '▱'; done
  printf '%s' "$R"
}

parts=()

cave=""
[ -n "$session_id" ] && [ -f "$HOME/.claude/.caveman-sessions/$session_id.mode" ] &&
  cave=$(< "$HOME/.claude/.caveman-sessions/$session_id.mode")
[ -z "$cave" ] && [ -f "$HOME/.claude/.caveman-active" ] && cave=$(< "$HOME/.claude/.caveman-active")
cave=${cave//[$'\n\r']/}
[ -n "$cave" ] && [ "$cave" != "off" ] && parts+=("${ORANGE}⛏ ${cave}${R}")

[ -n "$model" ] && parts+=("${BLUE}${model}${R}")
[ -n "$effort" ] && parts+=("${GREY}eff ${YELLOW}${effort}${R}")
[ -n "$cur_dir" ] && parts+=("${GREEN}${cur_dir##*/}${R}")

if [ -n "$ctx_used" ]; then
  used=$(( (${ctx_in:-0} + ${ctx_out:-0}) / 1000 ))
  size=$(( ${ctx_size:-0} / 1000 ))
  parts+=("${WHITE}ctx ${R}$(hue "$ctx_used")${ctx_used%%.*}%${R} $(bar "$ctx_used") ${WHITE}${used}/${size}k${R}")
fi

[ -n "$five" ] && parts+=("${GREY}5h ${R}$(hue "$five")${five%%.*}%${R}")
[ -n "$week" ] && parts+=("${GREY}7d ${R}$(hue "$week")${week%%.*}%${R}")

line=""
for p in "${parts[@]}"; do
  [ -n "$line" ] && line="${line} ${SEP} "
  line="${line}${p}"
done
[ -n "$line" ] && printf '%s\n' "$line"
