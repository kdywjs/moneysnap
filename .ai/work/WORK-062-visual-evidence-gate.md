---
id: WORK-062
status: active
depends_on: [WORK-008]
owner: codex
---

# iOS 시각 증거 게이트 복구

## Intent

네 화면의 Figma diff/report가 실제로 생성·판정되지 않으면 iOS CI가 실패하게 한다.

## In scope

- macOS Bash 빈 배열 확장으로 Home 뒤 캡처가 중단되는 문제
- 4개 시나리오 report 부재를 성공으로 표시하는 CI 게이트
- Windows 줄바꿈에서 build-once 정적 검증이 실패하는 문제

## Out of scope

- Figma node, SHA-256, crop, 오차 임계값 등 고정 앵커
- 제품 화면·기능 변경

## Acceptance criteria

- [x] Home/My/record-category/record-amount의 PNG overlay/diff와 report가 모두 생성된다.
- [x] 어느 시나리오라도 report가 없거나 임계값을 넘으면 CI가 실패한다.
- [x] Windows iOS project·visual validator가 통과한다.
- [ ] 기능 PR #39와 분리된 PR에서 검증·병합한다.

## Test seam

- 기존 macOS CI의 Home 첫 캡처 뒤 종료 로그와 누락된 report artifact.
- 기존 Windows visual validator의 build-once 검사 실패.
- CI에서 report 4건을 독립적으로 검사한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: 기존 PR CI `35992048212` log/artifact 검토; `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`; `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`; `git diff --check`; LF 정규화 후 `bash -n`.
- 결과: 기존 artifact의 `home/overlay.png`가 없어 CI completeness probe가 실패했다. 기존 Home 첫 캡처 뒤 `visual_diff_crop_arguments[@]: unbound variable`였지만 CI는 성공 표시했다. 수정 후 Windows validator 2건·Bash syntax·diff check 통과. macOS CI `35995925369` 재실행에서 native tests 통과, 네 화면의 overlay/diff/report 12개 생성 확인. Home MAE `0.061819`와 record-amount MAE `0.068398`가 고정 기준 `0.05`를 초과하여 CI가 정확히 실패했다. My `0.033377`와 record-category `0.048584`는 통과. 기존 UI 오차는 WORK-061 기능 PR에서 수정한다.
- 리뷰: 기존 고정 앵커는 유지한다.

## Agent rules impact

- 영향 여부: no
- 근거: 검증 명령·기술 스택·승인 경계는 유지하고 허위 성공만 복구한다.
- 처리 결과: AGENTS.md 갱신 불필요. 2026-09-24 사용자 별도 하네스 PR 승인.

## Code Review Graph

- 코드 변경 여부: yes (CI workflow·script)
- graph action: 빈 그래프 확인 후 full build (205 files, 1812 nodes), 변경 탐지
- base: origin/main `1e50fc6`
- risk: low 0.35
- findings와 처리 결과: `capture_scenario` test gap 1건은 macOS CI 실제 4-screen 캡처와 report 산출로 검증. 기능 화면 오차 2건은 WORK-061로 이관.

## Decisions and risks

- 고정 manifest의 기준값은 바꾸지 않는다.
- 실제 비교가 드러낸 기존 화면 오차는 기능 PR에서 처리한다.
