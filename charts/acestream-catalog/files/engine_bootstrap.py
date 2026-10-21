"""Dedicated probe engine: clean retained downloads and bound a hung shutdown."""
import os
import runpy
import sys
import threading

MAX_LIFETIME_SECONDS = 2 * 60 * 60


def main():
    import engine_cleanup

    # Match running main.py from /acestream, including its adjacent modules.
    sys.path.insert(0, "/acestream")
    engine_cleanup.install()
    # get_version stays healthy when the request broker/shutdown is wedged.
    # A daemon independent of engine locks guarantees kubelet can restart us.
    # Normal catalog recycling exits earlier; this is only the hard upper bound.
    watchdog = threading.Timer(MAX_LIFETIME_SECONDS, lambda: os._exit(1))
    watchdog.daemon = True
    watchdog.start()
    sys.argv = ["main.py", *sys.argv[1:]]
    runpy.run_path("/acestream/main.py", run_name="__main__")


if __name__ == "__main__":
    main()
