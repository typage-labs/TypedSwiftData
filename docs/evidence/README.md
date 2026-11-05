# Verification evidence policy

Raw local reports are deliberately excluded from Git. They contain machine
paths, temporary directories, compiler caches, simulator IDs, and test artifacts.
The original working directory retains them for local inspection.

Portable results are summarized in [the phase 1 report](../IMPLEMENTATION_VERIFICATION.md),
[the release review](../RELEASE_REVIEW.md), and [the compatibility matrix](../COMPATIBILITY.md).
Links labeled "local evidence" in historical reports point here rather than to
files that would be missing from a clean checkout.

Run `bash Scripts/verify.sh` to generate fresh evidence under
`.build/verification`. Each GitHub job uploads that directory as its own private
workflow artifact. Hosted results must be read from the corresponding run;
older local results are not substituted for them.

The checked-in `LICENSE` was compared byte for byte with
[the canonical Apache 2.0 text](https://www.apache.org/licenses/LICENSE-2.0.txt).
SHA-256: `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.
