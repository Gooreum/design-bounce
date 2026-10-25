# Verdict Template — verdict.md 표준 형식

> 판정자(QA·Vision)는 매 사이클 `.design-bounce/steps/step-N/verdict.md`를 **이 형식 그대로** 쓴다.
> `hooks/screenshot-gate.sh`가 형식을 검사해 위반 시 다음 step을 차단하고,
> `hooks/verdict-summary.sh`가 첫 줄 요약 헤더를 모아 정지조건(success/plateau)을 집계한다.

## 1. 요약 헤더 (첫 줄 필수)

파일의 **첫 번째 비어 있지 않은 줄**이 아래 형식과 정확히 일치해야 한다. 키 순서 고정, 값은 0 이상의 정수.

```
blockers: 0, high: 1, medium: 2, nit: 1, deviations: 3
```

검사 정규식:

```
^blockers: [0-9]+, high: [0-9]+, medium: [0-9]+, nit: [0-9]+, deviations: [0-9]+$
```

> ⚠️ 헤더는 **반드시 첫 줄**이다. 제목(`# ...`)이나 설명을 헤더 위에 두면 형식 오류로 차단된다.

| 키 | 의미 |
|---|---|
| `blockers` | 트랙 A+B의 `[Blocker]` 건수 |
| `high` | 트랙 A+B의 `[High-Priority]` 건수 |
| `medium` | 트랙 A+B의 `[Medium-Priority]` 건수 |
| `nit` | 트랙 A+B의 `Nit:` 건수 |
| `deviations` | **blockers + high + medium** (Nit 제외). plateau 판단 기준 |

- **clean** = `blockers == 0 && high == 0` (SKILL.md 정지조건의 "Blocker/High 0건").
- 숫자는 판정자가 직접 센다. 게이트는 형식만 검사하고 본문 태그 개수와의 일치는 검사하지 않는다.

## 2. 필수 섹션

헤더 아래에 다음 4개 섹션이 있어야 한다. 줄 맨 앞이 아래 문자열로 **시작**하면 된다
(`## 트랙 A — 명세 준수`처럼 뒤에 설명을 붙여도 된다).

| 섹션 | 작성 가이드 |
|---|---|
| `## 잘된 점` | 인정할 점 1~N개 (Evidence + Acknowledge) |
| `## 트랙 A` | 명세 준수 발견사항. 각 항목에 트리아지 등급(`[Blocker]`/`[High-Priority]`/`[Medium-Priority]`/`Nit:`) + 문제·영향 + 스크린샷 증거 |
| `## 트랙 B` | 외부표준 크리틱 발견사항. 형식은 트랙 A와 같음 |
| `## 정지 판단` | `hooks/verdict-summary.sh`의 `status` + 판정자 판단(success/plateau/stuck/infra-fail/continue) |

발견사항은 **Problems over Prescriptions** 원칙(`knowledge/review-process.md`)으로 쓴다.
처방("padding을 12px로")이 아니라 문제·영향("터치 영역이 붙어 오탭 위험")을 기술한다.

## 3. 작성 예시

```markdown
blockers: 0, high: 1, medium: 2, nit: 1, deviations: 3

## 잘된 점
- 헤더 타이포 위계가 명확하고 본문 대비 7.1:1로 충분하다.

## 트랙 A — 명세 준수
- [High-Priority] 카드 radius가 명세(12)와 달리 8로 보여 다른 카드와 이질적이다. (증거: after.png 상단 카드)
- [Medium-Priority] 섹션 간격이 16/24로 혼재해 리듬이 깨진다. (증거: 중단 리스트)

## 트랙 B — 표준 크리틱
- [Medium-Priority] 보조 버튼 터치 영역이 44pt 미만으로 보여 오탭 위험이 있다. (증거: 하단 우측)
- Nit: 캡션 자간이 약간 좁아 보인다.

## 정지 판단
- verdict-summary: status: continue (High 1건 남음) → 재작업
```
