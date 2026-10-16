---
name: design-bounce
description: 디자인 개발을 스크린샷 검증 루프로 구조화하는 워크플로우. dev-bounce의 디자인 버전으로, UI 화면을 구현·수정할 때 명세 선승인(Design Phase) → 어댑터로 스크린샷 캡처 → 분리된 판정자(Vision)의 2트랙 판정(명세 준수 + 외부표준 크리틱)을 반복한 뒤 최종 사람 승인(Human Review)으로 완료한다. "디자인/UI를 만들어줘", "화면을 예쁘게", "이 스크린 개선", "리스킨", "슬롭 방지" 같은 요청에 사용. 코드를 만든 에이전트가 자기 결과를 스스로 "괜찮다"고 판정하는 메아리(= AI 슬롭)를 막기 위해 판정자를 분리하고 WCAG/HIG/8px 그리드/톱티어 벤치마크에 앵커하며, 판정자도 구현자와 같은 모델이라는 한계 때문에 최종 완료는 사람이 선언하고 거부 사유(취향)는 taste.md에 누적한다.
---

# design-bounce

> ⛔ **이 스킬이 로드되면 — 코드부터 만들지 않는다.**
> 디자인은 "예쁘냐"를 텍스트 단언으로 검증할 수 없다. 코드를 만든 에이전트가 스스로
> 판정하면 자기 취향의 메아리로 수렴한다(= AI 슬롭). design-bounce는 **① 명세 선승인**과
> **② 판정자 분리 + 외부표준 앵커**로 이 실패를 막는다. 반드시 Phase 1(Design Phase)부터 시작한다.

## 개요

design-bounce는 `dev-bounce`의 **디자인 버전**이다. `dev-bounce`가 "코드 개발"을
phase/step + 훅으로 구조화하듯, design-bounce는 "디자인 개발"을 **스크린샷 검증 루프**로
구조화한다.

**자기판정 함정 방지의 두 축 + 최종 안전장치:**

1. **판정자 분리** — 구현하는 주체(Dev)와 판정하는 주체(QA·Vision)를 분리한다.
   같은 에이전트가 만들고 스스로 채점하면 "내가 만든 게 제일 낫다"는 메아리에 빠진다.
2. **외부표준 앵커** — 판정을 "내 취향"이 아니라 **외부 표준**에 고정한다.
   WCAG 대비 4.5:1, HIG 터치타겟 44pt, 8px 그리드, 톱티어 벤치마크(`knowledge/*.md`).
3. **사람 최종 승인** — 판정자도 구현자와 **같은 모델**이라 취향 판단에는 한계가 있다.
   루프가 끝나면 사람이 승인해야만 완료(`done`)되고, 거부 사유는 `.design-bounce/taste.md`에
   누적되어 다음 명세의 금지목록으로 인용된다(Phase 3).

이 스킬은 워크플로우 **오케스트레이션**이다. 실제 판정 기준은 `knowledge/`에,
빌드/캡처 실행은 `adapters/`에, 강제 게이트는 `hooks/`에 위임한다.

## 어댑터 계약

워크플로우는 **플랫폼 세부사항을 모른다.** 각 플랫폼 어댑터가 노출하는
`adapters/<platform>/adapter.sh`의 **4개 함수만** 호출한다 (`adapters/CONTRACT.md` 참조):

| 함수 | 호출 | 성공 stdout | 실패 |
|---|---|---|---|
| `build` | `adapter.sh build` | `OK` | exit≠0 |
| `launch` | `adapter.sh launch` | `OK` | exit≠0 |
| `navigate` | `adapter.sh navigate <screen_id>` | `OK` | exit≠0 |
| `capture` | `adapter.sh capture <screen_id>` | `<png경로>` | exit≠0 |

- `<screen_id>`: `design-bounce.config.json`의 `screens` 키(예: `home`, `tasks`).
- **플랫폼 자동 감지**: 프로젝트에 `app.json`/`app.config.js`(Expo) 또는 `expo` 의존성이 있으면
  `rn-expo` 어댑터를 채택한다. 그 외는 config의 `adapter` 필드를 따른다.
- 새 플랫폼(웹/Flutter 등)은 CONTRACT.md의 4함수만 구현하면 이 워크플로우를 그대로 재사용한다.

---

## Phase 1: Design Phase (코드 0줄)

> ⚠️ **이 Phase에서는 소스 코드를 단 한 줄도 쓰지 않는다.** 명세를 만들고 승인받는 단계다.
> 미승인 상태에서 소스 수정을 시도하면 `hooks/spec-gate.sh`가 차단한다.

주관("예쁘게")을 **객관적 명세**로 변환해 사용자에게 **선승인**받는다.

**0. 누적 취향 로드 (명세 작성 전)** — `.design-bounce/taste.md`를 Read한다(Phase 3에서 사람이
거부한 사유의 누적). 명세에 `## 사용자 취향 금지목록 (taste.md)` 섹션을 만들고 각 줄을
**원문 그대로 인용**한다(요약·재해석 금지). 파일이 없거나 비어 있으면 "누적 취향 없음" 한 줄을 적는다.
taste.md가 50줄을 넘으면 사용자에게 정리(중복 병합)를 제안한다 — 자동으로 지우지 않는다.

명세는 다음을 담는다:

1. **구체 토큰값** — "파란색"이 아니라 `#2563EB`, "여백"이 아니라 `16px`(8px 그리드).
   색/간격/타이포/radius를 실제 값으로 명시. 기준: `knowledge/design-standards.md`.
2. **anti-slop 금지목록** — `knowledge/anti-slop.md`의 금지 패턴(이모지 아이콘/아바타,
   탁한 저채도 팔레트, 균일 카드 3열 나열, 무의미 그라디언트)을 명세에 **명시적으로 금지**한다.
3. **외부 앵커** — `knowledge/design-standards.md`(대비 4.5:1, 8px 그리드, 타이포 스케일) +
   `knowledge/standards-mobile.md`(터치타겟 44pt, safe area)를 판정 기준으로 링크.

### 진실의 원천(reference) 확보

- **시안이 있으면** → 시안을 **픽셀 레퍼런스로 채택**한다. Track A(명세 준수)의 기준이 된다.
- **시안이 없으면 (하드 케이스)** → 아래 중 하나로 진실의 원천을 만든다:
  - **구체 레퍼런스 앱 지목** — "Linear의 설정 화면", "Things 3의 리스트" 같이 톱티어 벤치마크를 명시.
  - **자연어 → 명세 변환** — 사용자 요구를 캐물어 구체 토큰값으로 번역.
  - **A/B 3변형 → 사용자 선택** — 방향이 다른 3개 시안을 제시하고 사용자가 하나를 고른다.

  > ⚠️ 거부된 '현재 상태(before)' 스크린샷을 Track A 레퍼런스로 쓰지 않는다.
  > before는 개선의 출발점일 뿐 기준이 아니다(그걸 기준 삼으면 자기판정 메아리가 된다).

### 승인 게이트

명세를 **텍스트로 사용자에게 제시**하고 승인을 받는다.

- 승인 후:
  1. 명세를 `.design-bounce/design-spec.md`에 저장.
  2. `.design-bounce/state.json` 업데이트: `phase`를 `design` → `loop`, `spec_approved=true`.
     (`phase` 값: `design` → `loop` → `review` → `done`. `review`/`done`은 Phase 3 참고.)
- 미승인 상태에서는 `hooks/spec-gate.sh`(PreToolUse: Write/Edit)가 소스 수정을 **차단**한다.

---

## Phase 2: Screenshot 루프 (step 단위)

승인된 명세를 화면당·변경당 **step 단위**로 구현하고 판정한다.

```
Step N:
  1. Dev 구현 (명세의 해당 부분만 최소 구현)
  2. adapter.sh build            → OK
     adapter.sh launch           → OK
     adapter.sh navigate <id>    → OK
     adapter.sh capture <id>     → <png경로>
  3. QA(Vision)가 스크린샷을 Read하여 2트랙 판정
  4. 편차를 트리아지하여 .design-bounce/steps/step-N/{after.png, verdict.md} 기록
  5. Blocker/High-Priority가 있으면 재작업 → 다시 2로
```

> `hooks/screenshot-gate.sh`는 직전 step의 `after.png`/`verdict.md` 아티팩트가 없으면
> 다음 step 코드 수정을 **차단**한다. 캡처+판정 없이 전진할 수 없다.

### 2트랙 판정 (판정자 = 구현자와 분리)

판정자(QA·Vision)는 캡처한 스크린샷을 **직접 Read**하여 두 트랙으로 독립 평가한다:

- **트랙 A — 명세 준수 (객관)**: 토큰/간격/타이포가 `design-spec.md`와 일치하는가.
  색값·간격·radius·폰트 위계가 승인된 명세 그대로 구현됐는지 대조.
  명세의 **사용자 취향 금지목록(taste.md 인용)** 위반도 트랙 A 편차로 판정한다.
- **트랙 B — 표준 크리틱 (외부표준)**: 명세와 별개로 `knowledge/review-process.md`의
  **8단계 리뷰**(인터랙션 → 반응형 → 비주얼 폴리시 → 접근성 → 견고성 → 코드헬스 → 콘텐츠)를
  따라 **대비 4.5:1 / 8px 정렬 / 터치타겟 44pt / 시각 위계**를 독립 판정한다.

두 트랙 모두 **트리아지 매트릭스**로 등급을 매긴다:

| 등급 | 처리 |
|---|---|
| `[Blocker]` | 즉시 수정 (대비 4.5:1 미달, 조작 불가 등) |
| `[High-Priority]` | 머지 전 수정 |
| `[Medium-Priority]` | 후속 작업 |
| `Nit:` | 선택 |

판정은 **"Problems over Prescriptions"** 원칙을 따른다: "margin을 16px로 바꿔라"(처방)가
아니라 "간격이 12px/20px로 혼재해 리듬이 깨진다"(문제·영향)로 기술한다. 잘된 점도 먼저 인정한다.
판정 결과는 `verdict.md`에 기록한다(잘된 점 + 등급별 발견사항 + 트랙 A/B 요약 + 정지 판단).

**재작업 조건**: `[Blocker]` 또는 `[High-Priority]`가 하나라도 있으면 Dev가 재작업한다.

---

## 정지조건

루프는 무한히 돌지 않는다. 매 사이클 끝에 다음을 판단한다:

| 조건 | 트리거 | 처리 |
|---|---|---|
| **success** | 2트랙 모두 clean(Blocker/High 0건)이 **2회 연속** | 해당 step 완료, 다음 step. **마지막 step이면 Phase 3(Human Review) 진입** |
| **plateau** | 편차 수가 **3사이클 동안 정체**(줄지 않음) | TODO로 남기고 사용자에게 보고. 마지막 step이면 Phase 3 진입 |
| **stuck** | **동일 편차가 2회 실패** → 다른 접근 시도. **3회** 실패 → TODO로 남기고 전진 (마지막 step이면 Phase 3 진입) |
| **infra-fail** | `build`/`capture` 등 어댑터 실패 | 1회 재시도 → 그래도 실패면 중단·보고 |

> **컨텍스트 압축**: 루프가 길어지면 이전 사이클을 **요약 + 최근 스크린샷**만 유지하고
> 오래된 verdict 원문은 압축한다. 판정에 필요한 것은 최신 화면과 남은 편차 목록이다.

---

## Phase 3: Human Review (사람 최종 승인)

> ⚠️ **사람 승인 없이 `phase`를 `done`으로 바꾸지 않는다.** 판정자의 clean은 "완료"가 아니라
> "사람에게 보여줄 준비가 됨"일 뿐이다. 판정자도 구현자와 같은 모델이라 취향 판단은 사람 몫이다.

**진입**: 명세의 마지막 step이 success로 끝났거나, plateau/stuck으로 TODO를 남긴 채 끝났을 때.
각 화면의 최종 `steps/step-N/after.png`와 `verdict.md`가 있어야 한다 — 없으면 진입하지 않고
Phase 2 규칙대로 먼저 캡처+판정한다. 진입 시 `state.json`의 `phase`를 `loop` → `review`로 바꾼다.

> `review` 동안에는 `hooks/screenshot-gate.sh`가 `.design-bounce/` 밖 파일 수정을 **차단**한다.

**제시** — `knowledge/review-process.md`의 **사람 승인용 요약** 형식으로 사용자에게 보여주고 멈춘다:

1. 화면별 최종 `steps/step-N/after.png` 경로 (Read로 이미지도 함께 보여준다)
2. `verdict.md` 요약: 잘된 점, 남은 Medium/Nit, TODO로 남긴 plateau/stuck 항목, 트랙 A/B 결론
3. 질문: **"승인 / 거부(+사유)"**

**분기**:

| 응답 | 처리 |
|---|---|
| **승인** | `state.phase=done`. 완료를 보고하고 종료한다. |
| **거부(+사유)** | 사유를 `taste.md`에 한 줄씩 추가(사유가 여러 개면 여러 줄) → `phase=loop`, `current_step += 1`. 새 step의 목표는 거부 사유 해소. |
| **거부 — 명세 자체 변경 필요** (방향 전환, 토큰 변경) | 사유를 `taste.md`에 기록 → `phase=design`, `spec_approved=false`로 되돌려 명세를 다시 승인받는다(Phase 1의 0단계에서 인용됨). |
| **사유 없는 거부** | 사유를 한 번 더 묻는다. 그래도 없으면 `(사유 미기재)`로 기록하고 loop로 돌아간다. |

**`.design-bounce/taste.md` 형식** (append-only, 첫 거부 때 생성):

```markdown
# taste — 사용자 거부 사유 누적 (design-bounce가 관리, 다음 명세에 인용)
- 2026-10-13 [home] 카드 그림자가 과해 장난감처럼 보임
- 2026-10-13 [tasks] 강조색을 두 개 이상 쓰지 말 것
```

- 한 줄 형식: `- <YYYY-MM-DD> [<screen_id>] <사유 원문>`. 사유는 사용자 표현 **그대로** 쓰고 요약하지 않는다.
- 기존 줄을 수정·삭제하지 않는다(정리는 사용자 동의 후에만).

---

## 동적 UI 주의

애니메이션·타이머·스켈레톤 로딩 등 **움직이는 화면**은 캡처 타이밍에 따라 프레임이 흔들린다.
`design-bounce.config.json`의 `screens[<id>].settleMs`로 캡처 전 대기 시간을 설정해
프레임을 안정화한 뒤 스크린샷을 찍는다(어댑터의 `capture`가 이 값을 사용한다).
