#!/usr/bin/env python3
"""Select an installed Xcode; never substitute a different requested version.

A major-only requirement selects that major; 26.6 selects the 26.6 family.
DEVELOPER_DIR is exported to subsequent GitHub steps without changing the host's
global xcode-select setting. No toolchain is downloaded or installed.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--require", required=True)
args = parser.parse_args()
required = tuple(map(int, args.require.split(".")))
inventory = []
seen = set()
for application in sorted(Path("/Applications").glob("Xcode*.app")):
    developer = (application / "Contents/Developer").resolve()
    if developer in seen or not developer.is_dir():
        continue
    seen.add(developer)
    environment = dict(os.environ, DEVELOPER_DIR=str(developer))
    result = subprocess.run(["xcodebuild", "-version"], env=environment, text=True, capture_output=True)
    match = re.search(r"^Xcode ([\d.]+)$", result.stdout, re.MULTILINE)
    if result.returncode == 0 and match:
        inventory.append({"developer_dir": str(developer), "version": match[1], "description": result.stdout.strip()})
matches = [item for item in inventory if tuple(map(int, item["version"].split(".")))[:len(required)] == required]
selected = max(matches, key=lambda item: tuple(map(int, item["version"].split(".")))) if matches else None
report = Path(".build/verification/xcode-selection.json")
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({"required": args.require, "installed": inventory, "selected": selected}, indent=2) + "\n")
if selected is None:
    raise SystemExit(f"Required Xcode {args.require} is not installed. Found: {[item['version'] for item in inventory]}. No substitution performed.")
print(selected["description"])
print("DEVELOPER_DIR=" + selected["developer_dir"])
if os.environ.get("GITHUB_ENV"):
    with open(os.environ["GITHUB_ENV"], "a") as destination:
        destination.write("DEVELOPER_DIR=" + selected["developer_dir"] + "\n")
