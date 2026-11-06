#!/usr/bin/env python3
"""Record observed versions and Swift Testing counts, including explicit skips.

This report does not decide success: command exit statuses remain authoritative.
Unstarted checks are reported as missing, never as zero tests passed.
"""
import argparse
import json
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("--exit-code", type=int, required=True)
args = parser.parse_args()
directory = Path(".build/verification")

def log(name):
    path = directory / f"{name}.log"
    return path.read_text(errors="replace") if path.exists() else ""

def load(name):
    path = directory / f"{name}.json"
    return json.loads(path.read_text()) if path.exists() else None

def testing(name):
    text = log(name)
    # Native Testing reports discovered tests in its final line, including skips.
    match = re.search(r"Test run with (\d+) tests?(?: in (\d+) suites?)? (passed|failed)", text)
    skipped = re.findall(r"Test (.+?) skipped: (.+)", text)
    failures = re.findall(r"Test (.+?) failed after", text)
    if match is None:
        return {"status": "missing_or_incomplete", "skips": skipped, "failure_lines": failures}
    discovered = int(match[1])
    return {"status": match[3], "discovered": discovered,
            "passed": discovered - len(skipped) - len(failures) if match[3] == "passed" else None,
            "skipped": len(skipped), "failed": 0 if match[3] == "passed" else len(failures),
            "skips": skipped, "failure_lines": failures}

compilation = {}
for label in ["macos", "ios"]:
    report = load(f"compilation-{label}")
    if report is not None:
        checks = report["checks"]
        compilation[label] = {"target": report["target"], "sdk": report["sdk"],
            "positive_verified": sum(c.get("expectation") == "accept" and c.get("verified", False) for c in checks),
            "negative_verified": sum(c.get("expectation") == "reject" and c.get("verified", False) for c in checks),
            "failures": report["failures"]}
steps = []
if (directory / "steps.tsv").exists():
    steps = [{"step": line.split("\t")[0], "exit_code": int(line.split("\t")[1])}
             for line in (directory / "steps.tsv").read_text().splitlines()]
sqlite_checks = {}
for label in ["macos", "ios"]:
    path = directory / f"sqlite-{label}" / "summary.json"
    if path.exists():
        result = json.loads(path.read_text())
        sqlite_checks[label] = {"status": result["status"], "restart_processes": len(result["restart"]),
                                "sqlite_integrity": result.get("sqlite_integrity"),
                                "lifetime_controls": len(result["lifetime"]), "failures": result["failures"]}
report = {"exit_code": args.exit_code, "xcode": log("xcode").strip(),
    "swift": log("swift").strip(), "host": log("host").strip(),
    "selected_simulator": load("simulator"), "macos_tests": testing("swift-tests"),
    "ios_tests": testing("ios-tests"), "compilation": compilation,
    "sqlite_checks": sqlite_checks, "steps": steps}
(directory / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
        output.write("## Observed verification results\n\n```json\n" + json.dumps(report, indent=2) + "\n```\n")
if args.exit_code == 0 and any(report[key]["status"] != "passed" for key in ["macos_tests", "ios_tests"]):
    raise SystemExit("Successful command exits did not produce complete passing Swift Testing summaries.")
if args.exit_code == 0 and any(sqlite_checks.get(label, {}).get("status") != "passed" for label in ["macos", "ios"]):
    raise SystemExit("Missing or failed SQLite process-restart checks.")
