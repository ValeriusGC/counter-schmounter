#!/usr/bin/env bash
# Gate git write operations for Cursor Agent shell (project hook).
# Read-only git — allow. commit / push / gh pr create — ask (UI approve).

set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | python3 -c "import sys, json; print(json.load(sys.stdin).get('command', ''))" 2>/dev/null || true)

if [[ -z "$command" ]]; then
  echo '{ "permission": "allow" }'
  exit 0
fi

if [[ "$command" == *"git commit"* ]] \
  || [[ "$command" == *"git push"* ]] \
  || [[ "$command" == *"gh pr create"* ]]; then
  cat <<'EOF'
{
  "permission": "ask",
  "user_message": "Agent запрашивает git commit, push или gh pr create. Одобряй только если ты явно просил («Сделай коммит», «Сделай пуш», «создай PR»).",
  "agent_message": "Hook gate-git.sh: git write требует явной команды пользователя и подтверждения в UI. Не предлагай commit/push сам."
}
EOF
  exit 0
fi

echo '{ "permission": "allow" }'
exit 0
