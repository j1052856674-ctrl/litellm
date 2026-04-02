@echo off
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start_litellm.ps1" -ForceRestart -ConfigPath "%SCRIPT_DIR%config.yaml"
