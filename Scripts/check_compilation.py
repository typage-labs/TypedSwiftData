#!/usr/bin/env python3
"""Compile as an external client; verify each negative's diagnostic and location.

No @testable imports. Only the Python standard library and the selected Xcode.
Example: python3 Scripts/check_compilation.py --sdk iphoneos --target arm64-apple-ios17.0
"""
import argparse
import json
import pathlib
import platform
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--sdk", default="macosx", help="xcrun SDK name or absolute SDK path")
parser.add_argument("--target", default=f"{platform.machine()}-apple-macosx14.0")
parser.add_argument("--label", default="macos")
parser.add_argument("--report-dir", type=pathlib.Path, default=ROOT / ".build/verification")
parser.add_argument("--external-plugin-path", help="Apple macro directory#plugin-server for a standalone SDK")
args = parser.parse_args()
sdk = args.sdk if args.sdk.startswith("/") else subprocess.check_output(
    ["xcrun", "--sdk", args.sdk, "--show-sdk-path"], text=True).strip()
out = ROOT / ".build" / "compile-checks" / args.label
out.mkdir(parents=True, exist_ok=True)
swiftc = subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip()
flags = [swiftc, "-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors",
         "-sdk", sdk, "-target", args.target, "-module-cache-path", str(out / "cache")]
if args.external_plugin_path:
    flags += ["-external-plugin-path", args.external_plugin_path]
records = []

def run(name, arguments):
    process = subprocess.run(arguments, cwd=ROOT, text=True, capture_output=True, timeout=180)
    records.append({"name": name, "command": arguments, "returncode": process.returncode,
                    "stdout": process.stdout, "stderr": process.stderr})
    return process

module = run("library", flags + ["-parse-as-library", "-emit-module", "-emit-module-path",
             str(out / "TypedSwiftData.swiftmodule"), "-module-name", "TypedSwiftData"] +
             [str(p) for p in sorted((ROOT / "Sources/TypedSwiftData").glob("*.swift"))])
failures = []
if module.returncode != 0:
    failures.append("library compilation failed")
else:
    fixtures = ROOT / "Tests/CompileFixtures"
    for fixture in sorted(fixtures.glob("*.swift")):
        if fixture.name == "Models.swift":
            continue
        support = [str(fixtures / "Models.swift")]
        if fixture.name in {"InheritancePositive.swift", "InvariantInheritance.swift"}:
            support.append(str(fixtures / "Support/InheritanceModels.swift"))
        result = run(fixture.name, flags + ["-typecheck", "-I", str(out)] + support + [str(fixture)])
        expected = [(i, line.split("// expected-error: ", 1)[1])
                    for i, line in enumerate(fixture.read_text().splitlines(), 1) if "// expected-error: " in line]
        records[-1]["expectation"] = "reject" if expected else "accept"
        # Count primary diagnostics only; compiler source excerpts repeat "error:".
        errors = re.findall(r"^(.+?):(\d+):(\d+): error: (.*)$", result.stderr, re.MULTILINE)
        if not expected:
            valid = result.returncode == 0 and not errors
        else:
            valid = result.returncode == 1 and len(errors) == len(expected)
            for (line, pattern), (path, actual_line, _, message) in zip(expected, errors):
                valid &= pathlib.Path(path) == fixture and int(actual_line) == line and re.search(pattern, message) is not None
        records[-1]["verified"] = bool(valid)
        if not valid:
            failures.append(fixture.name)
            print(result.stderr)
        print(f"{'PASS' if valid else 'FAIL'} {fixture.name}")

report = args.report_dir.resolve() / f"compilation-{args.label}.json"
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({"sdk": sdk, "target": args.target, "failures": failures, "checks": records}, indent=2) + "\n")
print(f"{len(records)} compiler invocations; {len(failures)} failure(s). Report: {report}")
sys.exit(bool(failures))
