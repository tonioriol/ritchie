import importlib.util
from pathlib import Path
import threading
import unittest

spec = importlib.util.spec_from_file_location(
    "engine_cleanup",
    Path(__file__).parents[1] / "charts/acestream/files/engine_cleanup.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Download:
    def __init__(self, active=False, starting=False, kind=4):
        self.dllock = threading.RLock()
        self.live_download = object() if active else None
        self.starting = starting
        self.kind = kind

    def get_type(self):
        return self.kind


class Session:
    def __init__(self, *downloads):
        self.sesslock = threading.RLock()
        self.downloads = list(downloads)

    def get_downloads(self, kind=0):
        return [d for d in self.downloads if d.kind == kind]

    def remove_download(self, download, removecontent=False):
        assert self.sesslock._is_owned()
        assert download.dllock._is_owned()
        assert removecontent
        self.downloads.remove(download)


class CleanupTests(unittest.TestCase):
    def test_stopped_live_download_is_removed_after_grace(self):
        d = Download()
        session = Session(d)
        cleanup = module.Cleanup(session)
        self.assertEqual(cleanup.run(0), 0)
        self.assertEqual(cleanup.run(59), 0)
        self.assertEqual(cleanup.run(60), 1)
        self.assertEqual(session.downloads, [])

    def test_active_starting_and_non_live_downloads_are_untouched(self):
        downloads = [Download(active=True), Download(starting=True), Download(kind=0)]
        session = Session(*downloads)
        cleanup = module.Cleanup(session)
        cleanup.run(0)
        self.assertEqual(cleanup.run(3600), 0)
        self.assertEqual(session.downloads, downloads)

    def test_restart_resets_stopped_grace(self):
        d = Download()
        cleanup = module.Cleanup(Session(d))
        cleanup.run(0)
        d.live_download = object()
        cleanup.run(50)
        d.live_download = None
        self.assertEqual(cleanup.run(100), 0)
        self.assertEqual(cleanup.run(159), 0)
        self.assertEqual(cleanup.run(160), 1)

    def test_recent_lookup_protects_download_before_restart(self):
        d = Download()
        cleanup = module.Cleanup(Session(d))
        cleanup.run(0)
        d._cleanup_last_access = 55
        self.assertEqual(cleanup.run(60), 0)
        self.assertEqual(cleanup.run(114), 0)
        self.assertEqual(cleanup.run(115), 1)


if __name__ == "__main__":
    unittest.main()
