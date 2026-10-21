"""Dedicated probe engine: clean retained downloads and bound a hung shutdown."""
import os
import runpy
import sys
import threading

MAX_LIFETIME_SECONDS = 2 * 60 * 60


def main():
    # The engine's native core resolves its modules from argv[0]/path[0], so
    # look exactly like `python main.py` run in /acestream before importing it.
    sys.argv = ["main.py", *sys.argv[1:]]
    sys.path[0] = "/acestream"
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    import engine_cleanup

    engine_cleanup.install()
    # get_version stays healthy when the request broker/shutdown is wedged.
    # A daemon independent of engine locks guarantees kubelet can restart us.
    # Normal catalog recycling exits earlier; this is only the hard upper bound.
    watchdog = threading.Timer(MAX_LIFETIME_SECONDS, lambda: os._exit(1))
    watchdog.daemon = True
    watchdog.start()
    runpy.run_path("/acestream/main.py", run_name="__main__")


if __name__ == "__main__":
    main()
