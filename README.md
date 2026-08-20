# design-bounce

디자인 개발을 위한 스크린샷 검증 harness. `dev-bounce`가 "코드 개발"을 phase/step + 훅으로 구조화하듯, **design-bounce는 "디자인 개발"을 구조화**한다.

디자인은 "예쁘냐"를 텍스트 단언으로 검증할 수 없다. 코드를 만든 에이전트가 스스로 판정하면 자기 취향의 메아리로 수렴한다 (= AI 슬롭). design-bounce는 **명세 선승인**과 **판정자 분리 + 외부표준 앵커**로 이 실패를 막는다.

## 왜 필요한가

- 디자인 품질은 주관적 → AI가 자기 결과물을 스스로 "괜찮다"고 판정하는 메아리 문제 발생.
- 시안 없이 생성한 화면은 사용자 거부로 이어진다 (실물 실패 사례 존재).
- 해결: 주관을 **객관적 명세로 변환해 선승인**받고, 구현 결과를 **분리된 판정자**가 **외부 표준**(WCAG / HIG / 8px 그리드 / 톱티어 벤치마크)에 앵커해 검증한다.

## 아키텍처

design-bounce는 **범용(웹/모바일) 코어 + 플랫폼 어댑터** 구조다.

### 범용 코어

플랫폼과 무관한 워크플로우·검증 지식·훅으로 구성된다.

- **SKILL.md** — 워크플로우 오케스트레이션 (Design Phase + 스크린샷 루프).
- **knowledge/** — 검증 지식 베이스 (리뷰 프로세스, 디자인 표준, 모바일 표준, 안티슬롭 금지목록).
- **hooks/** — 채택 프로젝트가 `settings.json`에 배선하는 강제 게이트.
- **config.schema.json** — 채택 프로젝트가 두는 `design-bounce.config.json`의 JSON 스키마 계약.

### 플랫폼 어댑터

빌드/실행/네비게이션/캡처를 플랫폼별로 캡슐화한다. 코어는 **4개 함수 계약**(`build` / `launch` / `navigate` / `capture`)만 호출하고, 어댑터가 실제 명령을 수행한다.

- **adapters/CONTRACT.md** — 어댑터 계약 (표준 I/O).
- **adapters/rn-expo/** — 첫 어댑터. React Native / Expo용 `simctl` / `expo` 구현 (`--dry-run` 지원).

새 플랫폼(웹, Flutter 등)은 CONTRACT.md를 만족하는 어댑터만 추가하면 코어 재사용.

### 스크린샷 검증 루프

디자인 슬롭을 막는 두 가지 축:

1. **명세 선승인 (주관 → 객관 변환)**
   Design Phase에서 구체 토큰값 + 금지목록 + 외부 앵커를 담은 명세를 생성하고, **사용자 승인 게이트**를 통과해야 구현으로 넘어간다. 승인 전 소스 수정은 `spec-gate.sh` 훅이 차단한다.

2. **판정자 분리 + 외부표준 앵커**
   구현 후 어댑터로 스크린샷을 캡처하고, **구현자와 분리된 판정자**(Vision)가 2트랙으로 검증한다.
   - 트랙 A: 승인된 명세 준수 여부.
   - 트랙 B: 외부 표준(WCAG 대비 4.5:1, HIG 터치타겟 44pt, 8px 그리드, 톱티어 벤치마크) 크리틱.
   스크린샷 + 판정 아티팩트가 없으면 `screenshot-gate.sh` 훅이 다음 step을 차단한다.

```
Design Phase: 명세 생성 → [사용자 승인 게이트] → spec_approved=true
        │
        ▼
Screenshot 루프: Dev 구현 → adapter(build/launch/navigate/capture)
        → QA 2트랙 판정(명세준수 + 외부표준 크리틱)
        → step-N/{after.png, verdict.md}
        → 편차 있으면 재작업 (정지조건: success/plateau/stuck/infra-fail)
```

## 설치

### 1. 스킬로 설치 (전역)

`/design-bounce` 스킬로 어느 프로젝트에서든 쓰려면 레포를 클론하고 `install.sh`를 실행한다. `~/.claude/skills/design-bounce` 심링크가 생성된다.

```bash
git clone https://github.com/Gooreum/design-bounce ~/Code/design-bounce && cd ~/Code/design-bounce && ./install.sh
```

**새 세션**을 시작하면 `/design-bounce`가 활성화된다.

- **업데이트**: 심링크 설치라서 `cd ~/Code/design-bounce && git pull`만 하면 최신 반영. 재설치 불필요.
- `--copy`: 심링크 대신 복사본으로 설치한다 (레포 위치를 옮기거나 지워도 스킬이 남아야 할 때). 이 경우 업데이트하려면 다시 `./install.sh --copy --force`.
- `--force`: `~/.claude/skills/design-bounce`에 다른 항목이 이미 있을 때 제거 후 재설치한다.

`install.sh`는 동일 레포를 가리키는 심링크가 이미 있으면 그대로 성공(idempotent)하고, 끝에 `SKILL.md` 존재를 확인해 설치를 검증한다.

### 2. 프로젝트에 훅 강제 배선 (선택)

특정 프로젝트에서 게이트 훅(`spec-gate` / `screenshot-gate`)까지 강제하려면 채택 프로젝트에 다음을 배선한다.

1. design-bounce를 프로젝트에 둔다 (전역 클론 재사용, 또는 `git submodule add https://github.com/Gooreum/design-bounce`).
2. 프로젝트 루트에 `design-bounce.config.json`을 둔다 (`config.schema.json` 준수, `examples/petcycle.config.json` 참고).
3. 플랫폼 어댑터를 선택한다 (현재: `rn-expo`).
4. `hooks/install.md`를 따라 `spec-gate.sh` / `screenshot-gate.sh`를 프로젝트 `settings.json`의 `PreToolUse`에 배선한다.

### 의존성

- `jq` — config / state JSON 파싱 (훅·어댑터 런타임). `brew install jq`.
- Xcode 커맨드라인 툴(`xcrun simctl`) — `rn-expo` 어댑터(macOS)에 필요.
- `node` / `npx expo` — `rn-expo` build에 필요.

`install.sh`는 위 의존성이 없으면 경고만 출력하고 설치는 계속한다.

## 사용법

1. **Design Phase 실행** — SKILL.md 워크플로우로 명세를 생성하고 승인받는다.
2. **Screenshot 루프 실행** — 어댑터로 화면을 캡처하고 2트랙 판정을 반복한다.
3. **검증** — `test/run.sh`로 harness 자체 유닛테스트(JSON 유효성 / 훅 / 어댑터 dry-run / bash 문법)를 실행한다.

```bash
# 어댑터 dry-run (실제 실행 없이 명령 문자열 확인)
adapters/rn-expo/adapter.sh capture home --dry-run

# harness 전체 테스트
test/run.sh
```

## 디렉토리 구조

```
design-bounce/
├── README.md                 설치/사용법, 아키텍처 요약
├── LICENSE                   MIT
├── .gitignore
├── SKILL.md                  워크플로우 오케스트레이션
├── config.schema.json        design-bounce.config.json JSON 스키마
├── examples/                 config 예시
├── knowledge/                검증 지식 (플랫폼 무관 + 모바일)
├── adapters/                 어댑터 계약 + rn-expo 구현
│   ├── CONTRACT.md
│   └── rn-expo/
├── hooks/                    강제 게이트 훅 + lib
│   └── lib/
└── test/                     테스트 러너 + fixtures
    └── fixtures/
```

## 라이선스

[MIT](./LICENSE) © 2026 MINGU
