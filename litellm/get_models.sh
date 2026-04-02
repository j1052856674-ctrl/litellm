#!/bin/bash
ACCESS=ghu_sDiWlaAzkhtJapRpsmZeruBXvEpJgH1CTjvd
TOKEN=$(curl -s \
  -H "Authorization: token $ACCESS" \
  -H "editor-version: vscode/1.95.0" \
  -H "editor-plugin-version: copilot-chat/0.26.7" \
  https://api.github.com/copilot_internal/v2/token | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('token','ERR'))")

echo "=== GitHub Copilot 可用模型 ==="
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "editor-version: vscode/1.95.0" \
  -H "Copilot-Integration-Id: vscode-chat" \
  https://api.individual.githubcopilot.com/models | python3 - << 'EOF'
import json, sys
data = json.load(sys.stdin)
models = data.get("data", [])
for m in sorted(models, key=lambda x: x.get("id","")):
    mid = m.get("id", "")
    caps = m.get("capabilities", {})
    ctype = caps.get("type", "")
    limits = caps.get("limits", {})
    ctx = limits.get("max_context_window_tokens", "")
    print(f"{mid:50s} | {ctype:20s} | ctx={ctx}")
EOF
