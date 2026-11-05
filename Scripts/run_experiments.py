#!/usr/bin/env python3
"""Run native SwiftData probes in isolated processes and retain exact evidence.

--verify-reference checks the observed reference behavior, including the known
framework trap and SQLite anomaly. It does NOT certify SwiftData correctness.
Without that flag, process completion and the known trap are still checked,
but recorded field values have no claimed correctness verdict.
"""
import argparse
import json
import pathlib
import signal
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--binary", default=".build/debug/SwiftDataExperiments")
parser.add_argument("--label", default="native-run")
parser.add_argument("--report-dir", type=pathlib.Path, default=ROOT / ".build/verification")
parser.add_argument("--simulator", help="Booted simulator UDID; runs with simctl spawn")
parser.add_argument("--verify-reference", action="store_true")
args = parser.parse_args()
binary = str((ROOT / args.binary).resolve())
prefix = ["xcrun", "simctl", "spawn", args.simulator] if args.simulator else []
expectations = {
    "lifecycle": {"inserted-state": {"sameAsBefore": True, "registered": True, "fetchCount": 1, "identifierCount": 1},
                  "saved-state": {"sameAsInserted": False, "copyStillEqualsBefore": True, "oldRegistered": False,
                                  "newRegistered": True, "customerChanged": True, "fetchCount": 1, "identifierEqualsSaved": True}},
    "pending-delete": {"pending-delete": {"isDeleted": True, "registered": True, "fetchPending": 0, "fetchStored": 1,
                                          "identifierCount": 0, "deletedArray": 1},
                       "saved-delete": {"isDeleted": False, "contextNil": True, "registered": False,
                                        "fetchPending": 0, "fetchStored": 0, "identifierCount": 0}},
    "contexts": {"other-context-unsaved": {"fetchCount": 0}, "other-context-before-fetch": {"registered": False},
                 "other-context-saved": {"fetchCount": 1, "sameInstance": False, "sameID": True, "registered": True},
                 "other-context-pending-delete": {"fetchCount": 1},
                 "other-context-saved-delete": {"registeredBeforeFetch": True, "fetchCount": 0}},
    "containers": {"different-containers": {"sameID": False, "sameStore": False, "registered": False, "fetchCount": 0, "localCount": 1}},
    "reopen": {"released": {"containerNil": True, "contextNil": True, "sqliteHeader": "SQLite format 3"},
               "reopened": {"count": 0, "sameID": False},
               "reopened-row": {"allCount": 1, "name": "Reopened", "sameID": False, "sameInnerID": False,
                                "sameStore": True, "oldIDFetchCount": 0, "newIDFetchCount": 1,
                                "oldIDGenericFetchCount": 0, "oldIDRegistered": False, "newIDRegistered": True}},
    "same-store-containers": {"same-store-containers": {"oldIDFetchCount": 0, "allCount": 1, "sameID": False, "sameStore": True}},
    "generic-predicate": {"generic-result": {"count": 1, "wrongEntityCount": 0}},
    "temporary-predicate": {"never-inserted-fetch": {"count": 0}, "temporary-fetch": {"count": 1, "storedCount": 0},
                            "stale-temporary-fetch": {"count": 0, "currentCount": 1}},
    "registration-lifetime": {"registration-retained": {"registered": True}, "registration-released": {"registered": False}},
    "pending-sort": {"pending-sort": {"throwsExpectedError": True}},
}
for scenario in ["model-never-inserted", "model-deleted", "model-deleted-property", "model-stale-temporary", "model-foreign"]:
    expectations[scenario] = {"before-model-for": {"registered": False, "fetchCount": 0},
                              "after-model-for": {"castsToRestaurant": True, "sameID": True, "registered": True}}

records = []
failures = []
for scenario, expected in expectations.items():
    command = prefix + [binary, scenario]
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=45)
        record = {"scenario": scenario, "command": command, "returncode": result.returncode,
                  "stdout": result.stdout, "stderr": result.stderr}
        events = {}
        for line in result.stdout.splitlines():
            if line.startswith("{"):
                event = json.loads(line)
                events[event["event"]] = event
        problems = []
        # Observation mode still rejects unexpected crashes, errors, or missing
        # completion markers. Only baseline field values are optional.
        if scenario == "model-deleted-property":
            trap_code = 128 + signal.SIGTRAP if args.simulator else -signal.SIGTRAP
            if result.returncode != trap_code or "backing data could no longer be found" not in result.stderr or "before-property-access" not in events:
                problems.append("missing expected SIGTRAP and SwiftData invalidated-backing-data diagnostic")
        elif result.returncode != 0 or events.get("completed", {}).get("scenario") != scenario:
            problems.append("probe did not complete successfully")
        if args.verify_reference:
            for event, fields in expected.items():
                for key, value in fields.items():
                    if events.get(event, {}).get(key) != value:
                        problems.append(f"{event}.{key}: expected {value!r}; got {events.get(event, {}).get(key)!r}")
            print(f"{'PASS' if not problems else 'FAIL'} {scenario}: {problems}")
        else:
            print(f"OBSERVED {scenario}: exit {result.returncode}")
        record["verification_failures"] = problems
        if problems:
            failures.append(scenario)
    except subprocess.TimeoutExpired:
        record = {"scenario": scenario, "command": command, "timeout": True}
        failures.append(scenario)
        print(f"TIMEOUT {scenario}")
    records.append(record)

path = args.report_dir.resolve() / f"{args.label}.json"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps({"mode": "verify-reference" if args.verify_reference else "observe",
                            "failures": failures, "probes": records}, indent=2) + "\n")
print(f"{len(records)} probes. Report: {path}")
sys.exit(bool(failures))
