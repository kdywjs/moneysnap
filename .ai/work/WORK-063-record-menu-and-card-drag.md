---
id: WORK-063
status: complete
depends_on: [WORK-061]
owner: codex
---

# 기록 메뉴 전환과 Figma Home 카드 상호작용

## Intent

기록 메뉴를 아래에서 부드럽게 올리고 뒤 화면을 명확히 구분하며, Home의 물리 카드를 손가락으로 집어 이동할 수 있게 한다.

## In scope

- 기록 quick menu의 아래→위 전환과 더 분명한 배경 scrim
- 물리 카드 드래그의 실제 터치 경로 복구
- 새로고침·다른 탭에서 Home 복귀 시 위에서 카드가 다시 떨어지는 연출
- Figma Home `9:2`의 사진 컷아웃·반투명 금액 칩 카드
- 기존 SpriteKit 낙하·충돌 유지

## Out of scope

- Figma 시각 기준 이미지·crop·임계값 변경
- 기록 저장/API 변경

## Acceptance criteria

- [x] 기록 메뉴가 아래에서 살짝 올라오고 배경이 더 진하게 구분된다.
- [x] 실제 Home 화면에서 카드를 집어 옮기고 놓으면 새 위치에서 물리가 이어진다.
- [x] 새로고침과 Home 재진입마다 카드가 위에서 다시 낙하한다.
- [x] Home 물리 카드가 Figma `9:2`의 사진·금액 칩 구성을 따른다.
- [x] 빈 캔버스의 목록 스크롤과 카드 탭 상세 열기가 유지된다.
- [x] iOS native test 및 기존 4개 Figma 비교가 통과한다.

## Test seam

- 실제 ScrollView 안의 SpriteView에 수직 드래그를 수행하고 카드 이동 완료 신호를 확인하는 XCUITest를 먼저 실패시킨다.
- SpriteKit scene의 기존 탭/드래그 단위 테스트를 유지한다.

## Verification

```text
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1
powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1
bash ios/scripts/test.sh
bash ios/scripts/capture-visual-baseline.sh
git diff --check
```

## Evidence

- 실행 명령: `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-project.ps1`; `powershell -ExecutionPolicy Bypass -File ios\scripts\validate-visual-baseline.ps1`; `git diff --check`
- 결과: Windows 정적 검증 2건 통과, diff whitespace 통과. PR CI `36018281996`에서 `bash ios/scripts/test.sh`, `bash ios/scripts/capture-visual-baseline.sh`, 4개 시각 evidence 완전성 검사 통과. UI 테스트 10건 통과.
- 시각 리포트: Home `9:2` MAE 0.04720/불일치 0.42060, My `77:798` 0.03474/0.23780, 기록 금액 `108:549` 0.03434/0.37683, 기록 카테고리 `108:465` 0.04082/0.24340. 기준·crop·임계값 변경 없음.
- 리뷰: Figma `9:2` design context와 기존 라이브 SpriteKit 카드 비교 완료. 카드 전체 흰 surface가 기준과 달라 제거. `docs/UI_GUIDE.md`와 `AGENTS.md` 계약 비교 결과 `AGENTS.md` 요약·경로·명령 영향 없음.

## Agent rules impact

- 영향 여부: no
- 근거: 제품 범위·기술 스택·승인 경계·검증 명령을 바꾸지 않는다.
- 처리 결과: AGENTS.md 갱신 불필요.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: `get_minimal_context_tool` 0 nodes 확인 → full rebuild(205 files) → minimal context → `detect_changes_tool(standard)`
- base: origin/main `ee7276d`
- risk: low 0.40 (그래프 보조 지표)
- findings와 처리 결과: 자동 영향 흐름 0, test gap 21 보고. 새 scene replay/카드 구조 단위 테스트와 실제 drag/refresh/tab UI 테스트 통과. 추가 actionable finding 없음.

## Decisions and risks

- 물리 시뮬레이션 파라미터와 고정 Figma anchor는 유지한다.
