# LiteLLM 安装与初始化教程（Windows + WSL + GitHub Copilot）

## 1. 目标

在 Windows 上通过 WSL 启动 LiteLLM Proxy，将 Claude Code 请求转发到 GitHub Copilot 可用模型。

---

## 2. 前置条件

- Windows 11（建议）
- 可用的 GitHub Copilot 订阅
- PowerShell 可用
- WSL 已安装 Ubuntu-24.04

---

## 3. 安装 Python 环境与 LiteLLM（WSL）

在 PowerShell 执行：

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "apt update; apt install -y python3 python3-pip python3-venv git curl; mkdir -p /home/administrator/litellm; python3 -m venv /home/administrator/litellm/.venv; /home/administrator/litellm/.venv/bin/python -m pip install -U pip setuptools wheel; /home/administrator/litellm/.venv/bin/python -m pip install 'litellm>=1.68.0,!=1.82.7,!=1.82.8'; /home/administrator/litellm/.venv/bin/python -m pip install 'litellm[proxy]>=1.68.0,!=1.82.7,!=1.82.8'"
```

---

## 4. 创建配置文件

在项目目录创建 config.yaml（示例为精简稳定版）：

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: github_copilot/gpt-4.1

  - model_name: claude-sonnet-4-6
    litellm_params:
      model: github_copilot/claude-sonnet-4.6

  - model_name: claude-sonnet-4-5
    litellm_params:
      model: github_copilot/claude-sonnet-4.6

  - model_name: claude-opus-4-6
    litellm_params:
      model: github_copilot/claude-opus-4.6

  - model_name: claude-haiku-4-5
    litellm_params:
      model: github_copilot/claude-haiku-4.5

general_settings:
  master_key: sk-litellm-static-key
```

---

## 5. 启动 LiteLLM

推荐使用一键启动器：

- start_litellm.bat：启动 Copilot 路由
- start_litellm_gemini.bat：启动 Gemini 路由

这两个启动器已启用自动切换（会自动先停旧实例再启新实例）。

命令行方式：

```powershell
wsl -d Ubuntu-24.04 -u root -- bash -lc "source /home/administrator/litellm/.venv/bin/activate; litellm --config /mnt/e/产品/litellm/config.yaml --port 4000"
```

第一次可能出现 GitHub Device Code 授权提示，按提示访问链接完成授权。

---

## 6. 配置 Claude Code

编辑 C:\Users\Administrator\.claude\settings.json 的 env：

```json
{
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
  "ANTHROPIC_AUTH_TOKEN": "sk-litellm-static-key",
  "ANTHROPIC_MODEL": "gpt-4"
}
```

修改后必须完全重启 Claude Code。

---

## 7. 连通性验证

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:4000/models' -Headers @{ Authorization = 'Bearer sk-litellm-static-key' }
```

若返回模型列表，说明代理可用。

---

## 8. 常见问题

1. 403 预扣费错误（第三方平台）
- 原因：仍在使用第三方 ANTHROPIC_BASE_URL。
- 处理：改成 http://127.0.0.1:4000 并重启 Claude Code。

2. Claude Code 请求没有出现在 LiteLLM 日志
- 原因：Claude Code 未重启，仍读取旧环境变量。
- 处理：完全退出 Claude Code 后重新打开。

3. WSL 无法访问 GitHub Copilot
- 建议在 C:\Users\Administrator\.wslconfig 使用 mirrored + autoProxy + dnsTunneling。

---

## 9. 回滚方案

每次改配置前备份：

```powershell
$ts = Get-Date -Format "yyyyMMdd_HHmm"
Copy-Item "e:\产品\litellm\config.yaml" "e:\产品\litellm\.backups\config.yaml_bak_$ts"
```

出现异常时，将备份文件覆盖回 config.yaml 并重启 LiteLLM。

---

## 10. Gemini Key 更新

推荐：

- 双击 update_gemini_key.bat
- 粘贴新 Key，脚本会写入 /root/.litellm_env

命令行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\update_gemini_key.ps1" -GeminiApiKey "你的新Key" -NoPause
```

更新后双击 start_litellm_gemini.bat 重启生效。

---

## 11. 当前状态快照（2026-04-03）

1. Copilot 路由：可用（已通过最小请求验证）。
2. Gemini 路由：服务启动与模型列表正常，但实际请求失败，当前报错为 Key 过期。
3. 启停链路：`start_litellm.bat` 与 `start_litellm_gemini.bat` 已支持自动切换。
4. Key 管理：`update_gemini_key.ps1` 已支持格式校验与官方接口预校验。

---

## 12. 关键链接索引

1. https://github.com/login/device
2. https://ai.google.dev/gemini-api/docs/rate-limits
3. https://ai.dev/rate-limit

备注：如需与最初记录完全一致，可将上述 3 条替换为你最初提供的原始链接。
