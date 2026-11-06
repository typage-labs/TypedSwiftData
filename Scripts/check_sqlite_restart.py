#!/usr/bin/env python3
"""Verify real SQLite restarts; optionally record native container lifetimes.

Every phase is a separate, awaited process. Stores are removed only after all
children exit normally and checks pass; failure evidence is retained. Lifetime
observations are diagnostics, never an assertion that ARC must finish by a date.
"""
import argparse
from contextlib import closing
import json
from pathlib import Path
import platform
import plistlib
import shutil
import sqlite3
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]


def invoke(command, report_path, expected):
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=90)
    except subprocess.TimeoutExpired as error:
        report_path.write_text(json.dumps({"command": command, "timeout": True}, indent=2) + "\n")
        raise RuntimeError("Child timed out; store preserved because child termination is not established") from error
    record = {"command": command, "returncode": result.returncode,
              "stdout": result.stdout, "stderr": result.stderr}
    report_path.write_text(json.dumps(record, indent=2) + "\n")
    if result.returncode != 0:
        raise RuntimeError(f"Child exited {result.returncode}: {report_path.name}")
    events = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
    record["events"] = events
    report_path.write_text(json.dumps(record, indent=2) + "\n")
    completed = [event for event in events if event.get("event") == "completed"]
    if len(completed) != 1 or any(event.get("event") == "failure" for event in events):
        raise RuntimeError(f"Missing/ambiguous successful completion: {report_path.name}")
    if any(completed[0].get(key) != value for key, value in expected.items()):
        raise RuntimeError(f"Completion fields mismatch: {report_path.name}")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", help="Available, booted iOS simulator UDID; omit for macOS")
    parser.add_argument("--label", default="macos")
    parser.add_argument("--report-dir", type=Path, default=ROOT / ".build/verification")
    parser.add_argument("--lifetime", action="store_true", help="Run six native-only memory lifetime controls")
    args = parser.parse_args()
    output = args.report_dir.resolve() / f"sqlite-{args.label}"
    output.mkdir(parents=True, exist_ok=True)
    report = {"status": "incomplete", "restart": [], "lifetime": {}, "failures": []}
    (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    work = Path(tempfile.mkdtemp(prefix="processes-", dir=output))
    report["work_directory"] = str(work)
    try:
        sdk_name = "iphonesimulator" if args.simulator else "macosx"
        sdk = subprocess.check_output(["xcrun", "--sdk", sdk_name, "--show-sdk-path"], text=True).strip()
        target = f"{platform.machine()}-apple-" + ("ios17.0-simulator" if args.simulator else "macosx14.0")
        report.update(sdk=sdk, target=target,
                      xcode=subprocess.check_output(["xcodebuild", "-version"], text=True).strip())
        prefix = []
        if args.simulator:
            inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "--json"], text=True))
            matches = [(key, device) for key, devices in inventory["devices"].items() for device in devices
                       if device["udid"] == args.simulator and device.get("isAvailable")]
            if len(matches) != 1 or matches[0][1]["state"] != "Booted":
                raise RuntimeError("Requested simulator must be available and booted")
            runtime = next(r for r in inventory["runtimes"] if r["identifier"] == matches[0][0])
            report["runtime"] = {k: runtime[k] for k in ["identifier", "version", "buildversion"]}
            report["device"] = {k: matches[0][1][k] for k in ["udid", "name", "state"]}
            prefix = ["xcrun", "simctl", "spawn", args.simulator]
        else:
            report["runtime"] = subprocess.check_output(["sw_vers"], text=True).strip()
        common = ["xcrun", "swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors",
                  "-target", target, "-sdk", sdk, "-parse-as-library"]
        build = output / "build"
        build.mkdir(exist_ok=True)
        commands = []
        def compile_command(arguments):
            command = common + arguments
            result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
            commands.append({"command": command, "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
            (output / "compilation.json").write_text(json.dumps(commands, indent=2) + "\n")
            if result.returncode:
                raise RuntimeError(f"Probe compilation failed: {result.stderr}")
        compile_command(["-emit-library", "-static", "-emit-module", "-module-name", "TypedSwiftData",
                         "-emit-module-path", str(build / "TypedSwiftData.swiftmodule"),
                         *map(str, sorted((ROOT / "Sources/TypedSwiftData").glob("*.swift"))),
                         "-o", str(build / "libTypedSwiftData.a")])
        def executable(name, source, typed):
            app = build / f"{name}.app"
            app.mkdir(exist_ok=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": name, "CFBundleName": name,
                "CFBundleIdentifier": f"org.typage-labs.{name}", "CFBundlePackageType": "APPL", "CFBundleVersion": "1"}))
            flags = ["-I", str(build), "-L", str(build), "-lTypedSwiftData"] if typed else []
            compile_command(flags + [str(ROOT / "Experiments/Models.swift"),
                                     str(ROOT / "Tests/RuntimeProbes" / source), "-o", str(app / name)])
            return str(app / name)
        binary = executable("SQLiteRestart", "SQLiteRestart.swift", True)
        store = work / "restart.sqlite"
        nonce = str(uuid.uuid4())
        pids = set()
        for phase, count in [("write", 1), ("read-delete", 0), ("verify-deleted", 0)]:
            record = invoke(prefix + [binary, phase, str(store), nonce], output / f"{phase}.json",
                            {"phase": phase, "nonce": nonce, "restaurants": count, "customers": 1})
            event = next(e for e in record["events"] if e["event"] == "completed")
            if not isinstance(event.get("pid"), int) or event["pid"] in pids:
                raise RuntimeError("Restart phases must report distinct process IDs")
            pids.add(event["pid"])
            report["restart"].append(event)
            if store.read_bytes()[:16] != b"SQLite format 3\x00":
                raise RuntimeError("Expected an actual SQLite file after process exit")
            print(f"PASS {args.label} {phase}: pid={event['pid']}", flush=True)
        with closing(sqlite3.connect(store.as_uri() + "?mode=ro", uri=True)) as database:
            integrity = database.execute("PRAGMA integrity_check").fetchall()
        if integrity != [("ok",)]:
            raise RuntimeError(f"SQLite integrity check failed: {integrity}")
        report["sqlite_integrity"] = "ok"
        if args.lifetime:
            native = executable("NativeContainerLifetime", "NativeContainerLifetime.swift", False)
            for mode in ["container-only", "context-only", "model-only", "insert", "save", "save-retain-id"]:
                record = invoke(prefix + [native, mode, str(work / f"{mode}.sqlite")],
                                output / f"lifetime-{mode}.json", {"mode": mode})
                observations = [e for e in record["events"] if e.get("event") == "lifetime"]
                if not observations:
                    raise RuntimeError("Native diagnostic produced no lifetime observations")
                report["lifetime"][mode] = observations[-1]
                print(f"OBSERVED {args.label} {mode}: {observations[-1]}", flush=True)
        shutil.rmtree(work)  # Every child has terminated before SQLite files are removed.
        report["status"] = "passed"
    except (OSError, RuntimeError, ValueError, sqlite3.Error, subprocess.SubprocessError) as error:
        report["status"] = "failed"
        report["failures"].append(str(error))
        print(f"FAIL {args.label}: {error}", flush=True)
    (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
