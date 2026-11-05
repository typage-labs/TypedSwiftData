#!/usr/bin/env python3
"""Regression check: observation mode must never hide a failed probe process."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()
