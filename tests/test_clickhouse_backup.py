"""Exercise the rendered backup scripts without either remote provider.

Run: python3 -m unittest discover -s tests -p test_clickhouse_backup.py -v
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BackupScriptsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        rendered = subprocess.check_output([
            "helm", "template", "clickhouse", "charts/clickhouse",
            "--set", "backup.enabled=true", "--set", "backup.drive.enabled=true",
            "--set", "backup.endpoint=https://example.invalid/ccx",
        ], cwd=ROOT, text=True)
        cls.scripts = dict(re.findall(r"^  ([\w.]+): \|\n((?:    .*\n|\n)*)", rendered, re.M))
        cls.scripts = {name: re.sub(r"^    ", "", body, flags=re.M) for name, body in cls.scripts.items()}

    def run_script(self, name, fail=""):
        scratch = ROOT / ".agent-runs" / "clickhouse-drive-backup"
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as tmp:
            folder = Path(tmp)
            for script, body in self.scripts.items():
                body = body.replace("/scripts/", tmp + "/").replace("/credentials/rclone.conf", tmp + "/secret.conf").replace("/config/rclone.conf", tmp + "/rclone.conf")
                (folder / script).write_text(body)
            (folder / "secret.conf").write_text("test credentials\n")
            commands = {
                "rclone": 'echo "rclone $1" >> "$EVENTS"\n[ "$FAIL" != "$1" ] || exit 41\n',
                "wget": 'for arg do case "$arg" in http://*) echo "notify ${arg##*success=}" >> "$EVENTS" ;; esac; done\n[ "$FAIL" != notify ] || exit 42\n',
                "clickhouse-client": '''[ "$FAIL" != backup ] || exit 43
case "$*" in
  *"SELECT line"*) echo full-base ;;
  *"BACKUP DATABASE"*) echo backup-id ;;
  *"SELECT status FROM"*) echo BACKUP_CREATED ;;
esac
''',
            }
            for command, body in commands.items():
                binary = folder / command
                binary.write_text("#!/bin/sh\n" + body)
                binary.chmod(0o755)
            events = folder / "events"
            env = dict(os.environ, PATH=tmp + ":" + os.environ["PATH"], FAIL=fail, EVENTS=str(events),
                       COPY_SOURCE="s3:source/ccx", COPY_DESTINATION="drive:copy/ccx", GATUS_URL="http://monitor",
                       HEARTBEAT_TOKEN="test-token", S3_ACCESS_KEY="test", S3_SECRET_KEY="test",
                       S3_ENDPOINT="https://source/ccx", CH_HOST="clickhouse", CLICKHOUSE_ADMIN_PASSWORD="test")
            result = subprocess.run(["/bin/sh", str(folder / name)], env=env, text=True, capture_output=True)
            return result.returncode, events.read_text().splitlines() if events.exists() else []

    def test_copy_success_notifies_only_after_every_path_is_verified(self):
        rc, events = self.run_script("drive.sh")
        self.assertEqual(rc, 0)
        self.assertEqual(events, ["rclone copy", "rclone check", "rclone size", "rclone size", "notify true&error="])

    def test_failed_copy_alerts_and_does_not_claim_success(self):
        rc, events = self.run_script("drive.sh", "copy")
        self.assertNotEqual(rc, 0)
        self.assertEqual(events, ["rclone copy", "notify false&error=drive-copy-failed-see-Kubernetes-job-logs"])

    def test_failed_verification_alerts_and_does_not_claim_success(self):
        rc, events = self.run_script("drive.sh", "check")
        self.assertNotEqual(rc, 0)
        self.assertEqual(events[-1], "notify false&error=drive-copy-failed-see-Kubernetes-job-logs")
        self.assertNotIn("notify true&error=", events)

    def test_failed_backup_alerts_and_does_not_claim_success(self):
        rc, events = self.run_script("backup.sh", "backup")
        self.assertNotEqual(rc, 0)
        self.assertEqual(events, ["notify false&error=backup-failed-see-Kubernetes-job-logs"])

    def test_completed_backup_notifies_success(self):
        rc, events = self.run_script("backup.sh")
        self.assertEqual(rc, 0)
        self.assertEqual(events, ["notify true&error="])

    def test_failed_notification_keeps_job_failed(self):
        rc, _ = self.run_script("drive.sh", "notify")
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
