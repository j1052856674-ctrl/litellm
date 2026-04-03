from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent


class LiteLLMScriptRegressionTests(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_start_script_contains_stale_process_guards(self) -> None:
        script = self.read("start_litellm.ps1")
        self.assertIn("function Wait-LiteLLMStopped", script)
        self.assertIn("Multiple LiteLLM processes detected.", script)
        self.assertIn("pgrep -af litellm", script)
        self.assertIn("ss -tlnp | grep :$Port", script)

    def test_stop_script_verifies_cleanup_before_success(self) -> None:
        script = self.read("stop_litellm.ps1")
        self.assertIn("function Wait-LiteLLMStopped", script)
        self.assertIn("LiteLLM processes are still present after stop attempt.", script)
        self.assertIn("WSL port listener:", script)

    def test_status_script_reports_duplicate_processes_and_logs(self) -> None:
        script = self.read("status_litellm.ps1")
        self.assertIn("Process: RUNNING ($procCount instance(s))", script)
        self.assertIn("multiple LiteLLM processes detected", script)
        self.assertIn("Recent log tail:", script)

    def test_gemini_config_routes_all_claude_aliases_to_flash(self) -> None:
        config = self.read("config.gemini.yaml")
        self.assertIn("- model_name: claude-sonnet-4-6", config)
        self.assertIn("- model_name: claude-opus-4-6", config)
        self.assertIn("- model_name: claude-haiku-4-5", config)
        self.assertEqual(config.count("model: gemini/gemini-2.5-flash"), 6)

    def test_clean_restart_script_chains_stop_start_status(self) -> None:
        script = self.read("restart_litellm_gemini_clean.ps1")
        launcher = self.read("start_litellm_gemini.bat")
        self.assertIn("[1/3] Stopping existing LiteLLM instances...", script)
        self.assertIn("& $StopScript -NoPause", script)
        self.assertIn("& $StartScript -NoPause -ForceRestart -ConfigPath $ConfigPath", script)
        self.assertIn("& $StatusScript -NoPause", script)
        self.assertIn("restart_litellm_gemini_clean.ps1", launcher)

    def test_playbook_documents_process_cleanup_workflow(self) -> None:
        playbook = self.read("LITELLM_USAGE_PLAYBOOK.md")
        self.assertIn("LiteLLM 进程清理保障", playbook)
        self.assertIn("status_litellm.bat", playbook)
        self.assertIn("旧 Key", playbook)
        self.assertIn("restart_litellm_gemini_clean.bat", playbook)


if __name__ == "__main__":
    unittest.main()