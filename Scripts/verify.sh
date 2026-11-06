#!/bin/bash
# Local and future CI entry point. All generated files stay under .build/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/verification
: > .build/verification/steps.tsv

finish() {
    local outcome=$?
    trap - EXIT
    python3 Scripts/summarize_verification.py --exit-code "$outcome" || {
        if [ "$outcome" -eq 0 ]; then outcome=1; fi
    }
    exit "$outcome"
}
trap finish EXIT

run_logged() {
    local log_name="$1"
    shift
    local outcome=0
    "$@" 2>&1 | tee ".build/verification/${log_name}.log" || outcome=$?
    printf '%s\t%s\n' "$log_name" "$outcome" >> .build/verification/steps.tsv
    return "$outcome"
}

run_logged xcode xcodebuild -version
run_logged swift swift --version
run_logged host sw_vers
run_logged sdks xcodebuild -showsdks
run_logged runtimes xcrun simctl list runtimes
# Reject missing toolchains instead of silently downgrading verification.
python3 - <<'PY'
import os, re, subprocess
xcode = subprocess.check_output(['xcodebuild', '-version'], text=True)
version = tuple(map(int, re.search(r'Xcode (\d+)\.(\d+)', xcode).groups()))
if version < (26, 6):
    raise SystemExit('This verification workflow requires Xcode 26.6+; that version is a declared floor, not a tested combination.')
expected = os.environ.get('TYPED_SWIFTDATA_EXPECTED_XCODE')
if expected:
    required = tuple(map(int, expected.split('.')))
    if version[:len(required)] != required:
        raise SystemExit(f'Expected Xcode {expected}, actually selected {version}.')
PY

run_logged swift-tests swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
run_logged harness-tests python3 Scripts/test_verification.py
run_logged sqlite-macos python3 Scripts/check_sqlite_restart.py --label macos --lifetime
run_logged compile-macos python3 Scripts/check_compilation.py --label macos
run_logged compile-ios python3 Scripts/check_compilation.py --sdk iphoneos --target arm64-apple-ios17.0 --label ios
run_logged ios-build xcodebuild -scheme TypedSwiftData -destination 'generic/platform=iOS' \
    -derivedDataPath .build/ci-device SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build

run_logged probe-build swift build --product SwiftDataExperiments \
    -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Process outcomes and the specific known trap are checked on every runner.
# Exact native field snapshots are only opt-in, for the recorded reference OSes.
run_logged probes python3 Scripts/run_experiments.py --label native

typed_swiftdata_simulator="$(python3 Scripts/select_simulator.py)"
printf '%s\n' "$typed_swiftdata_simulator" > .build/verification/simulator.txt
run_logged ios-tests xcodebuild -scheme TypedSwiftData-Package \
    -destination "platform=iOS Simulator,id=${typed_swiftdata_simulator}" \
    -derivedDataPath .build/ci-simulator -parallel-testing-enabled NO \
    SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO test
# Xcode may shut down a destination it booted itself when testing completes.
run_logged sqlite-simulator-boot xcrun simctl bootstatus "$typed_swiftdata_simulator" -b
run_logged sqlite-ios python3 Scripts/check_sqlite_restart.py \
    --simulator "$typed_swiftdata_simulator" --label ios --lifetime
