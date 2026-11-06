#!/usr/bin/env python3
"""Regression check: observation mode must never hide a failed probe process."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from check_sqlite_restart import invoke

ROOT = Path(__file__).resolve().parents[1]


class ObservationModeTests(unittest.TestCase):
    def test_failed_probe_fails_observation_run(self):
        with tempfile.TemporaryDirectory(prefix="TypedSwiftDataHarness-") as directory:
            result = subprocess.run(
                [sys.executable, str(ROOT / "Scripts/run_experiments.py"),
                 "--binary", "/usr/bin/false", "--report-dir", directory, "--label", "failure"],
                text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            report = json.loads((Path(directory) / "failure.json").read_text())
            self.assertTrue(report["probes"])
            self.assertEqual(len(report["failures"]), len(report["probes"]))
            self.assertTrue(all(p["returncode"] == 1 and p["verification_failures"] for p in report["probes"]))


class SQLiteProcessHarnessTests(unittest.TestCase):
    def test_failed_child_is_not_a_successful_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Child exited 1"):
                invoke(["/usr/bin/false"], Path(directory) / "failure.json", {"phase": "write"})

    def test_zero_exit_requires_completion_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Missing/ambiguous successful completion"):
                invoke(["/usr/bin/true"], Path(directory) / "missing.json", {"phase": "write"})

    def test_completion_for_wrong_store_nonce_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            code = 'print(\'{"event":"completed","phase":"write","nonce":"wrong"}\')'
            with self.assertRaisesRegex(RuntimeError, "Completion fields mismatch"):
                invoke([sys.executable, "-c", code], Path(directory) / "mismatch.json",
                       {"phase": "write", "nonce": "expected"})


if __name__ == "__main__":
    unittest.main()
