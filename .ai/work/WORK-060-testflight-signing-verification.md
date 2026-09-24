---
id: WORK-060
status: active
depends_on: [WORK-059]
owner: codex
---

# Verify signed TestFlight payload before upload

## Intent
Diagnose shared Apple sign-in failures by inspecting the signed IPA before upload.

## In scope
Separate export/upload; fail closed on missing Apple login entitlement, mismatched identity or development signing; upload the exact verified IPA.

## Out of scope
Server changes, Apple portal changes, certificate generation/revocation, unproven authentication workarounds.

## Acceptance criteria
- [ ] Regression tests reject missing signed/profile entitlements and identity mismatches.
- [ ] Export does not upload; verification precedes upload.
- [ ] Only sanitized verification output is retained; no key/profile/IPA published in the public repository artifacts.
- [ ] CI and signed export verified before claiming deployment complete.

## Test seam
Python standard-library plist validation tests; real unsigned archive rejection on macOS.

## Verification
`python3 -m unittest discover -s ios/scripts -p 'test_verify_testflight_signing.py'`
`git diff --check`

## Evidence
Local Xcode 27 unsigned archive succeeds and codesign confirms no signature. This does NOT establish the contents of the previously exported build 21. Local signing identity inventory is empty.

- RED: unittest initially failed because the validator module did not exist.
- GREEN: all 6 tests pass, covering signed/profile capability omissions, team/app/build mismatches, debugging and distribution type.
- Ruby YAML parsing of both workflows, export plist inspection and git diff --check passed.
- Real unsigned IPA is rejected by codesign verification. A successful signed export requires the deployment environment; not yet verified.
- PR #34 merged after CI success; main CI 35943628436 also passed.
- Deployment 35944513185 (build 22) archived/exported successfully but codesign validation stopped upload. No new TestFlight build uploaded.
- Validator extraction bug reproduced locally: an ad-hoc signed archive passes strict verification before ZIP, fails after Python extractall, and passes after macOS ditto extraction. Build 22 does not establish a production signature defect or missing Apple-login entitlement.
- Follow-up RED: metadata-preserving extraction regression test fails before implementation; GREEN: all 7 tests pass after using ditto. Strict verification of the extracted signed fixture also passes. Signature/capability gates remain enforced.
- PR #35 and its main CI passed. Build 23 (35946297825) exported successfully, but a codesign verification still failed. Since the message did not distinguish integrity from certificate requirements, neither a signature defect nor entitlement omission is established.
- Further diagnostics read capability metadata before the still-mandatory signature gates, print only capability booleans, and classify allowlisted failure categories with distinct stage labels. No raw command stderr/profile data is exposed. All 9 tests pass, including diagnostic redaction tests.

## Agent rules impact
- no: existing security boundaries, environments and deployment approval remain unchanged. AGENTS.md unchanged.

## Code Review Graph
- graph action: skipped; tools unavailable in this session. Review workflow ordering and secret boundaries directly.
- base: aab4cda4a579779070b1b685e2ddea0bcb803976
- risk: deployment signing and accidental upload before validation.

## Decisions and risks
Do not change signing heuristically before inspecting an exported payload. If export requires unavailable signing credentials, stop without upload. Ponytail skill unavailable; no added dependencies.
