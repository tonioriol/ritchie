"""Evict stopped live downloads retained by the Android engine's HTTP stop command.

Run on the core task queue, just like network_restart/network_stop. The session
lock serializes lookup/removal; the download lock serializes the final state check.
Recent lookups and downloads still starting are protected as well as live players.
"""
import logging
import threading
import time
import weakref

LOGGER = logging.getLogger("acestream.idle_cleanup")
INTERVAL = 15
GRACE = 60


class Cleanup:
    def __init__(self, session):
        self.session = session
        self.stopped_since = weakref.WeakKeyDictionary()

    def run(self, now=None):
        now = time.monotonic() if now is None else now
        removed = 0
        with self.session.sesslock:
            for download in self.session.get_downloads(4):
                if download.get_type() != 4:  # DLTYPE_LIVE
                    continue
                with download.dllock:
                    if download.live_download is not None or download.starting:
                        self.stopped_since.pop(download, None)
                        continue
                    since = self.stopped_since.setdefault(download, now)
                    last_access = getattr(download, "_cleanup_last_access", since)
                    if now - max(since, last_access) < GRACE:
                        continue
                    self.session.remove_download(download, removecontent=True)
                    self.stopped_since.pop(download, None)
                    removed += 1
        LOGGER.info("retained live downloads: removed=%d total=%d", removed,
                    len(self.session.get_downloads(4)))
        return removed


def install():
    from ACEStream.Core.Session import Session

    original_get_download = Session.get_download

    def get_download(session, kind, infohash):
        with session.sesslock:
            download = original_get_download(session, kind, infohash)
            if download is not None and kind == 4:
                download._cleanup_last_access = time.monotonic()
            return download

    Session.get_download = get_download

    def attach():
        # Do not call get_instance here: that would construct a session before
        # the application has supplied its configuration.
        while True:
            session = Session._Session__single
            if session is not None and getattr(getattr(session, "lm", None), "rawserver", None):
                break
            time.sleep(1)
        cleanup = Cleanup(session)

        def tick():
            try:
                cleanup.run()
            except Exception:
                LOGGER.exception("retained live download cleanup failed")
            finally:
                session.lm.rawserver.add_task(tick, INTERVAL)

        session.lm.rawserver.add_task(tick, INTERVAL)

    threading.Thread(target=attach, name="attach-idle-cleanup", daemon=True).start()
