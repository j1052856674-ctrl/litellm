#!/usr/bin/env python3
import json, subprocess, urllib.request, urllib.error

ACCESS = "ghu_sDiWlaAzkhtJapRpsmZeruBXvEpJgH1CTjvd"

# Step 1: get API token
req = urllib.request.Request(
    "https://api.github.com/copilot_internal/v2/token",
    headers={
        "Authorization": f"token {ACCESS}",
        "editor-version": "vscode/1.95.0",
        "editor-plugin-version": "copilot-chat/0.26.7",
    }
)
with urllib.request.urlopen(req) as r:
    data = json.load(r)
    api_token = data["token"]
    print(f"Token OK, expires: {data.get('expires_at')}")

# Step 2: query models
req2 = urllib.request.Request(
    "https://api.individual.githubcopilot.com/models",
    headers={
        "Authorization": f"Bearer {api_token}",
        "editor-version": "vscode/1.95.0",
        "Copilot-Integration-Id": "vscode-chat",
    }
)
with urllib.request.urlopen(req2) as r:
    mdata = json.load(r)
    models = mdata.get("data", [])
    print(f"\n=== GitHub Copilot 可用模型 ({len(models)} 个) ===")
    for m in sorted(models, key=lambda x: x.get("id", "")):
        mid = m.get("id", "")
        caps = m.get("capabilities", {})
        ctype = caps.get("type", "")
        limits = caps.get("limits", {})
        ctx = limits.get("max_context_window_tokens", "?")
        print(f"  {mid:55s} type={ctype:12s} ctx={ctx}")
