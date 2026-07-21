#!/bin/bash
input=$(cat)

# \x1f (unit separator) field delimiter: unlike tab, read does not collapse
# empty fields. Injected via --arg to avoid any literal control character here.
US=$(printf '\x1f')
IFS=$US read -r used_pct model cwd effort q5 q7 qf < <(echo "$input" | jq -r --arg us "$US" \
    '[(.context_window.used_percentage // ""), (.model.display_name // "Claude"),
      (.workspace.current_dir // ""), (.effort.level // ""),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.seven_day_opus.used_percentage // "")] | join($us)')

[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# OKLCH palette: both accents share L=0.669 and 60% of each hue's max chroma
TERRA=$'\033[38;2;217;117;87m'    # oklch(0.669 0.133 37.5) - model
BLUE=$'\033[38;2;94;158;194m'     # oklch(0.669 0.085 235)  - git branch
AMBER=$'\033[38;2;205;168;104m'   # oklch(0.750 0.093 80)   - pressure >= 60%
RED=$'\033[38;2;214;94;84m'       # oklch(0.630 0.153 27)   - pressure >= 85%
GRAY=$'\033[38;2;139;133;131m'    # oklch(0.62 0.008 40)    - secondary text
DIM=$'\033[38;2;81;76;74m'        # oklch(0.42 0.008 40)    - inactive
WHITE=$'\033[38;2;232;227;226m'   # oklch(0.92 0.005 40)    - healthy bar fill
DIM_BG=$'\033[48;2;81;76;74m'     # background for the half-block transition
RESET=$'\033[0m'

sep="${DIM} · ${RESET}"

segments=""
if [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
          || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    segments="${GRAY}$(basename "$cwd")${RESET}"
    [ -n "$branch" ] && segments="${segments}${sep}${BLUE}${branch}${RESET}"
fi

model_fmt="${TERRA}${model}${RESET}"
[ -n "$effort" ] && model_fmt="${model_fmt} ${GRAY}${effort}${RESET}"

bar_len=12
if [ -n "$used_pct" ]; then
    used=$(printf "%.0f" "$used_pct")
    # Half-character granularity: ▌ (fill fg / inactive bg) as the transition cell
    halves=$(( used * bar_len * 2 / 100 ))
    [ "$halves" -gt $(( bar_len * 2 )) ] && halves=$(( bar_len * 2 ))
    filled=$(( halves / 2 ))
    half=$(( halves % 2 ))
    empty=$(( bar_len - filled - half ))
    # Color only signals pressure: white when healthy, amber, then red
    fill_color=$WHITE
    [ "$used" -ge 60 ] && fill_color=$AMBER
    [ "$used" -ge 85 ] && fill_color=$RED
    bar=""
    [ "$filled" -gt 0 ] && bar="${fill_color}$(printf '%0.s█' $(seq 1 $filled))${RESET}"
    [ "$half" -eq 1 ] && bar="${bar}${fill_color}${DIM_BG}▌${RESET}"
    [ "$empty" -gt 0 ] && bar="${bar}${DIM}$(printf '%0.s█' $(seq 1 $empty))${RESET}"
    ctx="${bar} ${fill_color}${used}%${RESET}"
else
    ctx="${DIM}$(printf '%0.s█' $(seq 1 $bar_len))${RESET} ${GRAY}ready${RESET}"
fi

# Plan quotas: gray label, (n%) that only lights up under pressure
quotas=""
add_quota() {
    [ -z "$2" ] && return
    local p c
    p=$(printf "%.0f" "$2")
    c=$GRAY
    [ "$p" -ge 60 ] && c=$AMBER
    [ "$p" -ge 85 ] && c=$RED
    quotas="${quotas}${sep}${GRAY}${1}${RESET} ${c}(${p}%)${RESET}"
}
add_quota "session" "$q5"
add_quota "weekly" "$q7"
add_quota "opus" "$qf"

[ -n "$segments" ] && segments="${segments}${sep}"
printf "%s%s%s%s%s" "$segments" "$model_fmt" "$sep" "$ctx" "$quotas"
