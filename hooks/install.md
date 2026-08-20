# 훅 배선 (Hook Installation)

design-bounce의 강제 게이트 훅을 **채택 프로젝트**(예: PetCycle)에 배선하는 방법.
두 훅은 채택 프로젝트가 코드를 아무렇게나 갈아엎는 것을 막는 안전장치다:

- **spec-gate.sh** — design-spec 승인 전에는 소스 수정을 막는다.
- **screenshot-gate.sh** — 직전 step의 스크린샷/판정 아티팩트가 없으면 다음 step을 막는다.

둘 다 Claude Code의 `PreToolUse` 이벤트에 `Write|Edit` matcher로 배선한다.
훅이 `{"decision":"block", ...}` JSON을 stdout에 출력하면 해당 도구 호출이 차단된다.

---

## 사전 요구

- `jq` 설치 (`brew install jq`)
- 채택 프로젝트 루트에 design-bounce가 관리하는 `.design-bounce/state.json` 존재
  (state 파일이 없으면 두 훅 모두 **통과** — design-bounce 미사용 프로젝트에 영향 없음)

## 1. 훅 스크립트 배치

design-bounce 레포를 채택 프로젝트에서 참조할 수 있는 위치에 둔다. 예를 들어
서브모듈/클론으로 `tools/design-bounce/`에 두었다면 훅 경로는
`tools/design-bounce/hooks/spec-gate.sh` 형태가 된다.

훅 스크립트에 실행 권한이 있어야 한다:

```bash
chmod +x tools/design-bounce/hooks/spec-gate.sh \
         tools/design-bounce/hooks/screenshot-gate.sh
```

> `screenshot-gate.sh`/`spec-gate.sh`는 같은 디렉토리의 `lib/state.sh`를
> `source`하므로 `hooks/lib/state.sh`가 함께 있어야 한다.

## 2. `.claude/settings.json`에 PreToolUse 배선

채택 프로젝트 루트의 `.claude/settings.json`(없으면 생성)에 아래를 추가한다.
`command` 경로는 실제 배치 경로에 맞게 수정한다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "tools/design-bounce/hooks/spec-gate.sh"
          },
          {
            "type": "command",
            "command": "tools/design-bounce/hooks/screenshot-gate.sh"
          }
        ]
      }
    ]
  }
}
```

- `matcher`는 정규식으로 도구 이름과 매칭된다. `Write|Edit`는 파일 쓰기/수정 도구를 모두 커버한다.
- 두 훅을 같은 `hooks` 배열에 나열하면 순서대로 실행되고, **어느 하나라도** block을 반환하면 도구 호출이 차단된다.

### state 디렉토리 위치를 바꾸려면

기본 state 경로는 `.design-bounce/`이다. 다른 경로를 쓰려면 `DESIGN_BOUNCE_DIR`
환경변수를 훅 `command`에서 지정한다:

```json
{
  "type": "command",
  "command": "DESIGN_BOUNCE_DIR=.db-state tools/design-bounce/hooks/spec-gate.sh"
}
```

## 3. `.design-bounce/state.json` 스키마

design-bounce 워크플로우(SKILL.md)가 이 파일을 생성/갱신한다. 훅은 읽기만 한다.

| 필드 | 타입 | 값 | 의미 |
|---|---|---|---|
| `phase` | string | `"design"` \| `"loop"` | 현재 단계. design=명세 단계, loop=스크린샷 개선 루프 |
| `spec_approved` | bool | `true` \| `false` | design-spec을 사용자가 승인했는지 |
| `current_step` | int | `0`, `1`, `2`, ... | 루프의 현재 step 번호(1부터). 아직 시작 안 했으면 0 |

예시:

```json
{
  "phase": "loop",
  "spec_approved": true,
  "current_step": 2
}
```

## 4. 게이트 동작 요약

### spec-gate.sh
- state 파일 없음 → 통과
- `phase="design"` & `spec_approved != "true"` → **차단**
  (`{"decision":"block","reason":"design-spec 미승인. 명세 승인 후 구현하세요."}`)
- 그 외 → 통과

### screenshot-gate.sh
- state 파일 없음 → 통과
- `phase != "loop"` → 통과
- `PREV = current_step - 1`이 1 이상이고
  `.design-bounce/steps/step-$PREV/after.png` 또는 `verdict.md`가 없음 → **차단**
  (`{"decision":"block","reason":"직전 step 스크린샷/판정 누락. 캡처+판정 후 진행."}`)
- 그 외 → 통과

## 5. 배선 검증

훅을 직접 실행해 동작을 확인할 수 있다(테스트 러너가 하는 일과 동일):

```bash
# 미승인 design 단계 → block 출력 기대
mkdir -p /tmp/db/.design-bounce
echo '{"phase":"design","spec_approved":false}' > /tmp/db/.design-bounce/state.json
DESIGN_BOUNCE_DIR=/tmp/db/.design-bounce tools/design-bounce/hooks/spec-gate.sh
# → {"decision":"block","reason":"design-spec 미승인. 명세 승인 후 구현하세요."}
```

레포 자체 유닛테스트는 `test/test-hooks.sh` 참고.
