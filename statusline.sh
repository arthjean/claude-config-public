#!/bin/bash
input=$(cat)

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')

effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

ORANGE=$'\033[38;2;217;117;87m'
CYAN=$'\033[38;2;34;211;238m'
RESET=$'\033[0m'

if [ -n "$effort" ]; then
    model_fmt="${ORANGE}${model} [${effort}]${RESET}"
else
    model_fmt="${ORANGE}${model}${RESET}"
fi

branch_fmt=""
if [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        branch_fmt="${CYAN}${branch}${RESET} │ "
    fi
    cwd=$(basename "$cwd")
fi

# Format context bar
if [ -n "$used_pct" ]; then
    used=$(printf "%.0f" "$used_pct")
    bar_len=20
    filled=$(( used * bar_len / 100 ))
    empty=$(( bar_len - filled ))
    bar=""
    [ "$filled" -gt 0 ] && bar=$(printf '%0.s▮' $(seq 1 $filled))
    [ "$empty" -gt 0 ] && bar="${bar}$(printf '%0.s▯' $(seq 1 $empty))"
    printf "%s%s │ %s │ %s %s%%" "$branch_fmt" "$cwd" "$model_fmt" "$bar" "$used"
else
    printf "%s%s │ %s │ ▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯ ready" "$branch_fmt" "$cwd" "$model_fmt"
fi
