import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "codex-agentdeck-notify.py"
spec = importlib.util.spec_from_file_location("notify", SCRIPT)
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)


class NotifyTest(unittest.TestCase):
    def test_config_preserves_notify_and_captures_frontend_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            original = ["/app with spaces/client", "turn-ended"]
            (home / "config.toml").write_text("notify = " + json.dumps(original))
            output = io.StringIO()
            environment = {
                "CODEX_HOME": directory,
                "AGENTDECK_INSTANCE_ID": "frontend-123",
                "AGENTDECK_PROFILE": "work",
            }
            with patch.object(notify.os, "environ", environment), patch.object(
                notify.shutil, "which", return_value="/absolute/agent-deck"
            ), contextlib.redirect_stdout(output):
                notify.config_override()
            command = tomllib.loads(output.getvalue())["notify"]
            self.assertEqual(command[command.index("--instance") + 1], "frontend-123")
            self.assertEqual(command[command.index("--profile") + 1], "work")
            self.assertEqual(json.loads(command[command.index("--original") + 1]), original)
            self.assertEqual(command[-1], "--")

    def run_callbacks(self, failure):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = root / "callback"
            fixture.write_text(
                f"#!{sys.executable}\n"
                "import json, os, pathlib, sys, time\n"
                "kind = sys.argv[1]\n"
                "data = {'argv': sys.argv[2:], 'instance': os.environ.get('AGENTDECK_INSTANCE_ID'),"
                " 'profile': os.environ.get('AGENTDECK_PROFILE')}\n"
                "pathlib.Path(os.environ['NOTIFY_TEST_DIR'], kind + '.json').write_text(json.dumps(data))\n"
                "if kind == 'turn-ended' and os.environ.get('NOTIFY_TEST_FAILURE') == 'timeout': time.sleep(7)\n"
                "if kind == 'turn-ended' and os.environ.get('NOTIFY_TEST_FAILURE') == 'exit': sys.exit(9)\n"
            )
            fixture.chmod(0o700)
            payload = json.dumps({"type": "agent-turn-complete", "thread-id": "thread-123", "message": "Привет\nquotes \" $() `test`"})
            environment = os.environ | {
                "NOTIFY_TEST_DIR": directory, "NOTIFY_TEST_FAILURE": failure,
                "AGENTDECK_INSTANCE_ID": "wrong-daemon-id", "AGENTDECK_PROFILE": "wrong-profile",
            }
            result = subprocess.run([
                sys.executable, str(SCRIPT), "dispatch", "--instance", "frontend-123",
                "--profile", "work", "--codex-home", directory, "--agent-deck", str(fixture),
                "--original", json.dumps([str(fixture), "turn-ended"]), "--", payload,
            ], env=environment, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            original = json.loads((root / "turn-ended.json").read_text())
            deck = json.loads((root / "codex-notify.json").read_text())
            self.assertEqual(original["argv"], [payload])
            self.assertEqual(deck["argv"], [payload])
            self.assertEqual(original["instance"], "wrong-daemon-id")
            self.assertEqual(deck["instance"], "frontend-123")
            self.assertEqual(deck["profile"], "work")
            self.assertNotIn(payload, result.stderr)

    def test_dispatch_preserves_payload_and_overrides_daemon_identity(self):
        self.run_callbacks("")

    def test_original_failure_does_not_skip_agent_deck(self):
        self.run_callbacks("exit")

    def test_original_timeout_does_not_skip_agent_deck(self):
        self.run_callbacks("timeout")


if __name__ == "__main__":
    unittest.main()
