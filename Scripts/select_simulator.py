#!/usr/bin/env python3
"""Print an available iPhone simulator UDID, preferring the newest iOS runtime.

Selection is not a claim about oldest-runtime compatibility. No device is
created or deleted; xcodebuild boots the selected device when running tests.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "--json"], text=True))
runtimes = {r["identifier"]: r for r in inventory["runtimes"] if r.get("isAvailable")}
candidates = []
for key, devices in inventory["devices"].items():
    runtime = runtimes.get(key)
    if runtime is None or not runtime["name"].startswith("iOS "):
        continue
    version = tuple(int(n) for n in re.findall(r"\d+", runtime["version"]))
    if version < (17,):
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, device["udid"], device, runtime))
if not candidates:
    sys.exit("No available iPhone simulator with iOS 17+. Install a runtime/device; simulator testing was not performed.")
requested = os.environ.get("TYPED_SWIFTDATA_SIMULATOR")
if requested:
    candidates = [candidate for candidate in candidates if candidate[1] == requested]
    if not candidates:
        sys.exit(f"Requested simulator {requested} is not an available iPhone with iOS 17+.")
selected = max(candidates, key=lambda item: (item[0], item[1]))
report = Path(".build/verification/simulator.json")
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({"device": selected[2], "runtime": selected[3]}, indent=2) + "\n")
print(selected[1])
