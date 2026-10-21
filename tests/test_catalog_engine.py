import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
FILES = ROOT / "charts/acestream-catalog/files"
spec = importlib.util.spec_from_file_location("engine_bootstrap", FILES / "engine_bootstrap.py")
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class CatalogEngineTests(unittest.TestCase):
    def test_cleanup_is_identical_to_the_playback_engine_fix(self):
        self.assertEqual(
            (FILES / "engine_cleanup.py").read_bytes(),
            (ROOT / "charts/acestream/files/engine_cleanup.py").read_bytes(),
        )

    def test_cleanup_and_hard_exit_are_installed_before_engine_start(self):
        cleanup = types.SimpleNamespace(install=Mock())
        with patch.dict(sys.modules, engine_cleanup=cleanup), \
             patch.object(sys, "argv", ["engine_bootstrap.py", "--disable-upnp"]), \
             patch.object(bootstrap.threading, "Timer") as timer, \
             patch.object(bootstrap.os, "_exit") as exit_process, \
             patch.object(bootstrap.runpy, "run_path") as run:
            def started(*args, **kwargs):
                cleanup.install.assert_called_once()
                timer.return_value.start.assert_called_once()
                self.assertTrue(timer.return_value.daemon)
                self.assertEqual(sys.argv, ["main.py", "--disable-upnp"])
            run.side_effect = started
            bootstrap.main()
            seconds, callback = timer.call_args.args
            self.assertEqual(seconds, 7200)
            callback()
            exit_process.assert_called_once_with(1)
            run.assert_called_once_with("/acestream/main.py", run_name="__main__")


if __name__ == "__main__":
    unittest.main()
