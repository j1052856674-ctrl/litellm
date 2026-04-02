# LiteLLM 使用手册（快速启动版）

## 1. 每次开机后的最短链路

推荐方式（双击一键启动）：

- 双击 start_litellm.bat（Copilot 路由）
- 脚本会自动做 3 件事：
  - 检查 4000 端口是否已有 LiteLLM
  - 若已运行其他配置，则自动先停再启（自动切换）
  - 若未启动则在 WSL 后台启动 LiteLLM
  - 自动调用 /models 做健康检查

切换到 Gemini：

- 双击 start_litellm_gemini.bat（Gemini 路由）
- 该启动器同样是自动切换模式，不需要手动先点 stop

命令行方式（与双击等价）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start_litellm.ps1"
```

无交互模式（适合自动化，不等待 Enter）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start_litellm.ps1" -NoPause -ForceRestart
```

停止服务（双击一键停止）：

- 双击 stop_litellm.bat
- 脚本会停止 WSL 中的 litellm 进程并检查 4000 端口是否释放

命令行停止：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\stop_litellm.ps1"
```

无交互停止（自动化）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\stop_litellm.ps1" -NoPause
```

1. 启动 LiteLLM：

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "source /home/administrator/litellm/.venv/bin/activate; litellm --config /mnt/e/产品/litellm/config.yaml --port 4000"
```

2. 在另一个 PowerShell 验证：

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/models' -Headers @{ Authorization = 'Bearer sk-litellm-static-key' }
```

3. 打开 Claude Code 开始使用。

---

## 2. 模型选项与实际路由

- Default / Sonnet（常用）
  - 请求模型名常见为 claude-sonnet-4-6 或 claude-sonnet-4-5
  - 实际路由到 github_copilot/claude-sonnet-4.6

- Opus（复杂任务）
  - 实际路由到 github_copilot/claude-opus-4.6

- Haiku（快响应）
  - 实际路由到 github_copilot/claude-haiku-4.5

- gpt-4（兼容入口）
  - 实际路由到 github_copilot/gpt-4.1

说明：当前配置是固定映射，不是随机路由。

---

## 3. 你和 AI 的标准操作指令（可直接复制）

### 3.1 快速健康检查

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/models' -Headers @{ Authorization = 'Bearer sk-litellm-static-key' } | ConvertTo-Json -Depth 4
```

### 3.2 发送最小测试请求

```powershell
$headers = @{ Authorization = 'Bearer sk-litellm-static-key' }
$payload = @{ model = 'gpt-4'; messages = @(@{ role = 'user'; content = 'reply exactly: OK' }); max_tokens = 20 } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/chat/completions' -Method Post -Headers $headers -ContentType 'application/json' -Body $payload
```

### 3.3 让 AI 诊断当前链路的提示词

请检查以下 3 项并给出结论：
1. settings.json 的 ANTHROPIC_BASE_URL 是否为 http://127.0.0.1:4000
2. LiteLLM 进程是否在 WSL 中运行并监听 4000
3. 最近一次请求是否出现在 LiteLLM 日志并返回 200

---

## 4. 失败时的一键排查顺序

1. 检查代理是否在线：
- /models 是否能返回数据

2. 检查配置是否生效：
- Claude Code 重启后再测

3. 检查端口冲突：
- 确保只保留一个 LiteLLM 实例

4. 检查授权状态：
- 若日志提示 device code，按提示重新授权

---

## 5. 维护建议

1. 配置变更前先备份到 .backups
2. 保持 model_list 精简，优先保留 Sonnet/Opus/Haiku + 一个兼容入口
3. 每次升级 LiteLLM 后先用最小请求回归测试

---

## 6. Gemini API 接入（可用每日免费额度）

前提：你有 Google AI Studio 的 API Key。

### 6.1 在 WSL 设置 API Key（推荐写入专用环境文件）

在 PowerShell 执行：

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "cat > /root/.litellm_env <<'EOF'
export GEMINI_API_KEY=你的真实Key
EOF
chmod 600 /root/.litellm_env"
```

然后重启 WSL：

```powershell
wsl --shutdown
```

### 6.2 使用 Gemini 专用配置启动

双击：

- start_litellm_gemini.bat

或命令行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start_litellm.ps1" -ForceRestart -ConfigPath ".\config.gemini.yaml"
```

### 6.3 验证是否走 Gemini

```powershell
$headers = @{ Authorization = 'Bearer sk-litellm-static-key' }
$payload = @{ model = 'claude-sonnet-4-6'; messages = @(@{ role = 'user'; content = 'reply exactly: OK' }); max_tokens = 20 } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/chat/completions' -Method Post -Headers $headers -ContentType 'application/json' -Body $payload | ConvertTo-Json -Depth 6
```

说明：

- Claude Code 仍然只显示 Default/Sonnet/Opus/Haiku 这类入口。
- 你通过 LiteLLM 映射把这些入口转到 Gemini 后端。
- 免费额度是否可用取决于 Google 账号地区、当日配额和模型限制。
- 若 gemini-2.5-pro 返回 429 免费配额限制，建议优先使用 gemini-2.5-flash（当前模板已采用该策略）。

### 6.4 如何更新/轮换 Gemini Key

推荐方式（双击）：

- 双击 update_gemini_key.bat
- 在提示中粘贴新 Key（不会显示明文）
- 更新后重启 Gemini 路由：双击 start_litellm_gemini.bat

命令行方式（可脚本化）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\update_gemini_key.ps1" -GeminiApiKey "你的新Key" -NoPause
```

验证 Key 是否生效：

```powershell
$headers = @{ Authorization = 'Bearer sk-litellm-static-key' }
$payload = @{ model = 'claude-sonnet-4-6'; messages = @(@{ role = 'user'; content = 'reply exactly: OK' }); max_tokens = 20 } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/chat/completions' -Method Post -Headers $headers -ContentType 'application/json' -Body $payload
```

安全建议：

- 一旦 Key 泄露（聊天记录、截图、终端历史），立刻在 Google AI Studio 里 Revoke/Regenerate。
- 旧 Key 失效后，立刻执行 update_gemini_key.bat 写入新 Key。

---

## 7. 当前整体状态（2026-04-03）

1. Copilot 路由
- 状态：可用。
- 依据：`gpt-4` 最小请求可返回 `OK`。

2. Gemini 路由
- 状态：服务可启动，模型可列出，但实际调用失败。
- 失败原因：当前生效的 Gemini Key 在官方接口返回 `API key expired. Please renew the API key.`

3. 启停脚本
- 状态：可用，支持自动切换（`-ForceRestart`）。
- 说明：若切换路由，直接点击对应启动器即可，不必手动先 stop。

4. Key 更新脚本
- 状态：已增强。
- 能力：自动去除换行/回车、校验 Key 格式、写入前做 Gemini 官方接口校验。

---

## 8. 关键链接（本会话使用）

1. GitHub Device 登录页：
- https://github.com/login/device

2. Gemini API 配额文档：
- https://ai.google.dev/gemini-api/docs/rate-limits

3. Gemini API 配额看板：
- https://ai.dev/rate-limit

备注：如果你最初提供的 3 个链接不是以上这三个，按你的原始链接替换本节即可。
