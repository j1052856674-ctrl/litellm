# LiteLLM 使用手册（快速启动版）

## 1. 每次开机后的最短链路

推荐方式（双击一键启动）：

- 双击 start_litellm.bat（Copilot 路由）
- 脚本会自动做 3 件事：
  - 检查 4000 端口是否已有 LiteLLM
  - 若已运行其他配置，则自动先停再启（自动切换）
  - 若发现多个残留 LiteLLM 进程，会先清理再启动，避免旧 Key 或旧配置继续占用 4000
  - 若未启动则在 WSL 后台启动 LiteLLM
  - 自动调用 /models 做健康检查

切换到 Gemini：

- 双击 start_litellm_gemini.bat（Gemini 路由）
- 该启动器现在默认走“强制清理并重启”流程
- 会先停掉 WSL 中残留的 LiteLLM，再启动 Gemini 配置并回显最终状态

需要显式做一次干净重启时，也可以直接双击：

- restart_litellm_gemini_clean.bat

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
- 脚本会停止 WSL 中的 litellm 进程、等待残留进程退出，并检查 4000 端口是否释放

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

- Copilot 配置 `config.yaml`
  - `gpt-4` -> `github_copilot/gpt-4.1`
  - `claude-sonnet-4-6` / `claude-sonnet-4-5` -> `github_copilot/claude-sonnet-4.6`
  - `claude-opus-4-6` -> `github_copilot/claude-opus-4.6`
  - `claude-haiku-4-5` -> `github_copilot/claude-haiku-4.5`

- Gemini 配置 `config.gemini.yaml`
  - `gpt-4` -> `gemini/gemini-2.5-flash`
  - `claude-sonnet-4-6` / `claude-sonnet-4-5` -> `gemini/gemini-2.5-flash`
  - `claude-opus-4-6` -> `gemini/gemini-2.5-flash`
  - `claude-haiku-4-5` -> `gemini/gemini-2.5-flash`

说明：

- 当前配置是固定映射，不是随机路由。
- 这次把 Gemini 下的 Opus / Haiku 也临时统一到 `gemini-2.5-flash`，目的是避开 `gemini-pro-latest` 与 `gemini-2.0-flash` 的 429 配额问题，优先保证 Claude 四个主要入口都能用。

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

1. 先看状态脚本：
- 运行 `status_litellm.bat`
- 重点看 3 项：`API health`、`Process` 实例数、`Port check`

2. 如果 `Process` 大于 1：
- 说明 WSL 内存在 stale 进程，旧 Key 或旧配置可能仍然占着 4000
- 先运行 `stop_litellm.bat`
- 再运行目标启动器，例如 `start_litellm_gemini.bat`

3. 如果 `/models` 正常但 `/chat/completions` 失败：
- 说明 LiteLLM 进程在，但上游提供商出错
- 常见区分：
- `400 API key expired` = 当前生效 Key 无效或已过期
- `429 RESOURCE_EXHAUSTED` = 模型额度不足，不是配置语法问题

4. 如果 4000 没监听：
- 看 `status_litellm.bat` 里的 `Recent log tail`
- 再执行文档中的手动 debug 命令

5. 如果 Claude Code 仍异常：
- 确认 `settings.json` 的 `ANTHROPIC_BASE_URL` 是 `http://127.0.0.1:4000`
- 完全退出 Claude Code 再重新打开

6. 如果日志提示 device code：
- 说明是 GitHub Copilot 授权问题，按提示重新授权

---

## 5. LiteLLM 进程清理保障

当前脚本的保障策略：

- `start_litellm.ps1`
  - 启动前会检查 WSL 中是否已有多个 `litellm` 进程
  - 发现多实例时会先清理残留，再继续启动
  - `-ForceRestart` 会主动停掉旧实例并等待 4000 释放

- `restart_litellm_gemini_clean.ps1`
  - 是 Gemini 的专用“干净重启”入口
  - 固定执行：`stop -> start(config.gemini.yaml) -> status`
  - 适合切换 Key、切换 Gemini 映射、或怀疑 4000 仍被旧实例占用时使用

- `stop_litellm.ps1`
  - 不只执行 `pkill`
  - 还会等待进程真正退出，并检查 4000 是否释放
  - 如果还有残留，会打印 WSL 进程和监听信息，便于直接定位

- `status_litellm.ps1`
  - 会显示当前 LiteLLM 实例数
  - 当检测到多实例时直接给出告警
  - 当 API 不通时会顺带打印 `/tmp/litellm.log` 的最近日志

这套保障主要解决本次遇到的典型问题：

- WSL 里同时挂着多份 LiteLLM
- 新实例虽然启动了，但 4000 仍被旧实例占用
- 结果 `/models` 看起来正常，但实际请求一直打到旧 Key

---

## 6. 维护建议

1. 配置变更前先备份到 .backups
2. 保持 model_list 精简，优先保留 Sonnet/Opus/Haiku + 一个兼容入口
3. 每次升级 LiteLLM 后先用最小请求回归测试

---

## 7. Gemini API 接入（可用每日免费额度）

前提：你有 Google AI Studio 的 API Key。

### 7.1 在 WSL 设置 API Key（推荐写入专用环境文件）

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

### 7.2 使用 Gemini 专用配置启动

双击：

- start_litellm_gemini.bat
- restart_litellm_gemini_clean.bat

或命令行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start_litellm.ps1" -ForceRestart -ConfigPath ".\config.gemini.yaml"
```

强制干净重启命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\restart_litellm_gemini_clean.ps1" -NoPause
```

### 7.3 验证是否走 Gemini

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
- 当前模板已将 Claude 的 Default / Sonnet / Opus / Haiku 入口统一映射到 `gemini-2.5-flash`，优先保证可用性。

### 7.4 如何更新/轮换 Gemini Key

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

## 8. 当前整体状态（2026-04-03）

1. Copilot 路由
- 状态：可用。
- 依据：`gpt-4` 最小请求可返回 `OK`。

2. Gemini 路由
- 状态：4000 入口已恢复，Claude 四个主要入口都已切到稳定可用路线。
- 当前映射：`gpt-4`、`claude-sonnet-4-6`、`claude-opus-4-6`、`claude-haiku-4-5` 都走 `gemini-2.5-flash`。
- 目的：先保证整体可用，再保留 direct Gemini 模型入口做 A/B 测试。
- 实测结果：`gpt-4`、`claude-sonnet-4-6`、`claude-sonnet-4-5`、`claude-opus-4-6`、`claude-haiku-4-5` 已全部返回 HTTP 200。

3. 启停脚本
- 状态：可用，已补强 stale 进程清理与快速诊断输出。
- 说明：Gemini 默认启动器已切到“强制清理并重启”流程；若怀疑旧实例残留，优先跑 `status_litellm.bat`。

4. Key 更新脚本
- 状态：已增强。
- 能力：自动去除换行/回车、校验 Key 格式、写入前做 Gemini 官方接口校验。

---

## 9. 关键链接（本会话使用）

1. GitHub Device 登录页：
- https://github.com/login/device

2. Gemini API 配额文档：
- https://ai.google.dev/gemini-api/docs/rate-limits

3. Gemini API 配额看板：
- https://ai.dev/rate-limit

备注：如果你最初提供的 3 个链接不是以上这三个，按你的原始链接替换本节即可。
