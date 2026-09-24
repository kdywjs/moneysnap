---
id: WORK-063
status: active
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

- [ ] 기록 메뉴가 아래에서 살짝 올라오고 배경이 더 진하게 구분된다.
- [ ] 실제 Home 화면에서 카드를 집어 옮기고 놓으면 새 위치에서 물리가 이어진다.
- [ ] 새로고침과 Home 재진입마다 카드가 위에서 다시 낙하한다.
- [ ] Home 물리 카드가 Figma `9:2`의 사진·금액 칩 구성과 일치한다.
- [ ] 빈 캔버스의 목록 스크롤과 카드 탭 상세 열기가 유지된다.
- [ ] iOS native test 및 기존 4개 Figma 비교가 통과한다.

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
- 결과: Windows 정적 검증 2건 통과, diff whitespace 통과. PR CI `36016410388`에서 XCUITest 10건 통과, 새 낙하 재생 단위 테스트 1건 실패. 센서 중력 변화를 허용하도록 초기 중력 고정 단정을 재생 전후 동일성으로 수정했고 재검증 대기.
- 리뷰: Figma `9:2` design context와 기존 라이브 SpriteKit 카드 비교 완료. 카드 전체 흰 surface가 기준과 달라 제거.

## Agent rules impact

- 영향 여부: no
- 근거: 제품 범위·기술 스택·승인 경계·검증 명령을 바꾸지 않는다.
- 처리 결과: AGENTS.md 갱신 불필요.

## Code Review Graph

- 코드 변경 여부: yes
- graph action: `get_minimal_context_tool` 0 nodes 확인 → full rebuild(205 files) → minimal context → `detect_changes_tool(standard)`
- base: origin/main `ee7276d`
- risk: low 0.40 (그래프 보조 지표)
- findings와 처리 결과: 자동 영향 흐름 0, test gap 19 보고. 새 scene replay/카드 구조 단위 테스트와 실제 drag/refresh/tab UI 테스트 추가. macOS 결과 대기.

## Decisions and risks

- 물리 시뮬레이션 파라미터와 고정 Figma anchor는 유지한다.
