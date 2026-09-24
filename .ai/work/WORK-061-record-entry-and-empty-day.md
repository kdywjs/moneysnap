---
id: WORK-061
status: complete
depends_on: [WORK-046, WORK-043]
owner: codex
---

# 기록 진입·전체 화면 입력과 빈 날짜

## Intent

Figma 기록 quick menu, 한 화면에서 끝나는 입력, 보관함 빈 날짜의 정상 상태를 제공한다.

## In scope

- Home 기록하기와 추가 탭의 Figma `86:716` quick menu
- 기존 사진 촬영·앨범·사진 없음 저장 경로를 유지한 전체 화면 입력
- 393x852에서 스크롤 없는 완료, 저장 중 진행 표시
- 월 조회에서 비어 있다고 확인된 날짜의 보관함 빈 상태
- Home 물리 카드의 터치·집기·놓기 안정화와 어색한 카드 그림자 제거
- Home 상단·하단 safe area와 탭 바의 iOS 재질 표현 복구

## Out of scope

- 기존 시각 하네스 고정 앵커 변경
- 서버 API·배포 설정 변경

## Acceptance criteria

- [x] 두 진입점에서 플로팅 세 액션을 보여주고 촬영·앨범·사진 없음 경로가 연결된다.
- [x] 입력 화면의 카테고리, 금액, 완료/다음이 393x852에서 스크롤 없이 보인다.
- [x] 저장 중 진행 상태를 표시하고 중복 제출·불명확한 retry의 안전성은 유지한다.
- [x] 기록 없는 날짜는 오류로 표시하지 않고 명확한 빈 상태를 보여준다.
- [x] macOS native test와 승인된 시각 검증을 통과한다.
- [x] 카드의 금액·카테고리 부분을 탭해도 튀지 않고 상세로 열리며, 끌어 옮긴 뒤 놓으면 자연스럽게 떨어진다.
- [x] 상단·하단에 검은 띠가 생기지 않고 탭 바에 시스템 반투명 재질을 사용한다.

## Test seam

- XCUITest: Home/추가 → quick menu → 사진 없음 → 전체 화면 입력 → 저장.
- ArchiveViewModel: 월 결과에서 점유되지 않은 날짜를 선택하면 day network call 없이 빈 상태.
- Home physics: 오프센터 탭은 카드 위치를 바꾸지 않고, 드래그는 집은 지점의 상대 위치를 유지한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`; `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`; `git diff --check`; code-review-graph full build → minimal context → standard detect changes
- 결과: `git diff --check` exit 0. 하네스 PR #40 병합 후 Windows validator 2건이 통과했다. PR CI `35998346981`의 macOS native test가 통과했고, 회귀 테스트 `tappingCardCaptionOpensDetailWithoutMovingTheCard`, `draggedCardKeepsTheGrabOffsetAndFallsWhenReleased`, 기록 완료 버튼 UI 테스트를 확인했다.
- 시각 검증: PR #40의 하네스로 4개 시나리오의 diff/report가 모두 생성됐다. 최종 PR CI `36004527557`에서 native test와 visual completeness gate 통과. Home MAE `0.048005`, mismatch `0.420597`; My `0.034739` / `0.237803`; record-category `0.040821` / `0.243403`; record-amount `0.034341` / `0.376831`. 네 시나리오의 overlay/diff/report 12개 존재 확인. 고정 MAE `0.05`, mismatch `0.43` 이내다. 기록 전체화면은 XCUITest로 393x852 완료 버튼 접근성과 저장 흐름을 검증한다. 사용자 결정에 따라 기존 Figma 기준 이미지·crop은 유지한다.
- 리뷰: 최신 main을 기준으로 isolated worktree를 만들고, 기존 사진 publish와 archive API를 재사용했다.

## Agent rules impact

- 영향 여부: no
- 근거: 기술 스택·아키텍처·승인 경계·검증 명령은 유지하고 사용자 화면 결정을 기준 문서에 반영한다.
- 처리 결과: AGENTS.md 갱신 불필요

## Code Review Graph

- 코드 변경 여부: yes
- graph action: full build (worktree에 그래프 부재, 205 files / 1816 nodes) 후 최신 코드 커밋 `fa3c842`까지 incremental update와 standard detect changes
- base: origin/main (1e50fc6)
- risk: medium
- findings와 처리 결과: high 0.75, AppShell photo entry와 archive request 경계의 test gap을 보고했다. UI/Archive/Physics 테스트와 macOS native CI `36004527557`로 확인했다. 그래프의 Swift 테스트 인식 누락은 보조 증거로 취급한다.

## Decisions and risks

- 사진 publish 및 계정 인증은 최신 main의 기존 경로를 재사용한다.
- TestFlight는 성공한 main iOS CI 이후 별도 workflow가 업로드한다.
- 시각 하네스는 사용자 승인에 따라 별도 PR #40에서 수정·병합했다. 고정 Figma anchor는 변경하지 않았다.
- 2026-09-24 사용자 결정에 따라 기존 modal Figma 기준 이미지·crop을 유지한다. 런타임 기록 입력은 전체화면이며 native UI test로 검증한다.
