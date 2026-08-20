# 어댑터 계약 (Adapter Contract)

design-bounce 워크플로우(SKILL.md)는 플랫폼 세부사항을 모른다. 대신 각 어댑터가
노출하는 **4개 함수**만 호출한다. 새 플랫폼(웹, Android, Flutter 등)을 지원하려면
이 4함수만 구현하면 된다 — 워크플로우 코드는 손대지 않는다.

모든 함수는 단일 진입점 `adapter.sh <fn> <args...>`를 통해 호출된다.

## 4함수 표준 I/O 계약

| 함수 | 호출 | 성공 시 stdout | 실패 시 |
|---|---|---|---|
| `build` | `adapter.sh build` | `OK` | exit≠0 + 에러 로그(stderr) |
| `launch` | `adapter.sh launch` | `OK` | exit≠0 |
| `navigate` | `adapter.sh navigate <screen_id>` | `OK` | exit≠0 |
| `capture` | `adapter.sh capture <screen_id>` | `<png경로>` (예: `.design-bounce/shots/home.png`) | exit≠0 |

- **성공**: 위 stdout을 출력하고 `exit 0`.
- **실패**: 어떤 함수든 실패하면 **0이 아닌 종료 코드**로 종료한다. 진단은 stderr로.
- `<screen_id>`: 채택 프로젝트의 `design-bounce.config.json` 내 `screens` 객체의 키
  (예: `home`, `tasks`, `settings`). 어댑터는 이 키로 config에서 딥링크/settle 등을 조회한다.

## `--dry-run` 플래그

모든 함수는 마지막 인자로 `--dry-run`을 받을 수 있다. `--dry-run`이 주어지면
어댑터는 **실제 실행 없이** 수행할 명령 문자열만 stdout에 출력하고 `exit 0` 한다.
테스트(`test/test-adapter.sh`)와 사람이 명령을 미리 확인하는 용도.

예:
```
$ adapter.sh navigate home --dry-run
xcrun simctl openurl booted "petcycle://home"

$ adapter.sh capture home --dry-run
SLEEP 600ms; xcrun simctl io booted screenshot ".design-bounce/shots/home.png"
```

## 설정 파일

어댑터는 **현재 작업 디렉토리**의 `design-bounce.config.json`을 `jq`로 읽는다.
테스트 편의를 위해 `DESIGN_BOUNCE_CONFIG` 환경변수로 경로를 override할 수 있다:

```bash
CFG="${DESIGN_BOUNCE_CONFIG:-design-bounce.config.json}"
```

읽는 필드:
- `bundleId` — `launch`가 사용
- `captureDir` (기본 `.design-bounce/shots`) — `capture` 출력 위치
- `screens[<id>].deeplink` — `navigate`가 사용
- `screens[<id>].settleMs` (기본 0) — `capture`가 스크린샷 전 대기

## 새 플랫폼 어댑터 추가하기

1. `adapters/<platform>/` 디렉토리 생성.
2. `adapter.sh` 디스패처 + `build.sh` / `launch.sh` / `navigate.sh` / `capture.sh` 구현.
3. 위 4함수의 I/O 계약(성공 stdout, 실패 exit≠0, `--dry-run`)을 그대로 지킨다.
4. `design-bounce.config.json`의 `adapter` 필드를 `<platform>`으로 설정.

이 계약을 지키는 한 워크플로우는 플랫폼을 구분하지 않고 동일하게 동작한다.
