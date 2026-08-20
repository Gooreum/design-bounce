# rn-expo 어댑터

React Native / Expo 앱을 iOS 시뮬레이터에서 빌드·실행·이동·캡처하는 어댑터.
[`../CONTRACT.md`](../CONTRACT.md)의 4함수 계약을 구현한다.

## 요구사항

- macOS + Xcode (`xcrun simctl`)
- Node.js + `npx` (`expo run:ios`)
- `jq` (config 파싱)
- `bc` (settle sleep 계산)
- 부팅된 iOS 시뮬레이터 1대 (`xcrun simctl boot "<시뮬>"` 또는 Simulator.app에서 부팅)

## 함수

| 명령 | 동작 | 출력 |
|---|---|---|
| `adapter.sh build` | `npx expo run:ios` | `OK` |
| `adapter.sh launch` | `xcrun simctl launch booted <bundleId>` | `OK` |
| `adapter.sh navigate <id>` | `xcrun simctl openurl booted <deeplink>` | `OK` |
| `adapter.sh capture <id>` | settle 대기 후 `xcrun simctl io booted screenshot` | `<png경로>` |

모든 명령에 `--dry-run`을 붙이면 실제 실행 없이 수행할 명령 문자열만 출력한다.

```bash
# 실제 실행 (부팅된 시뮬 + 설치된 앱 필요)
bash adapter.sh capture home

# 명령 미리보기
bash adapter.sh navigate home --dry-run
# → xcrun simctl openurl booted "petcycle://home"
```

## config (`design-bounce.config.json`)

현재 작업 디렉토리의 `design-bounce.config.json`을 읽는다.
`DESIGN_BOUNCE_CONFIG` 환경변수로 경로 override 가능.

```json
{
  "adapter": "rn-expo",
  "bundleId": "com.petcycletest.app",
  "captureDir": ".design-bounce/shots",
  "screens": {
    "home": { "deeplink": "petcycle://home", "settleMs": 600 }
  }
}
```

## 선행 작업 (채택 프로젝트에서)

`navigate`가 딥링크 기반이므로, 어댑터를 쓰기 전에 아래를 준비한다.

1. **URL scheme 등록**: Expo `app.json`의 `scheme`(예: `"petcycle"`)을 설정하고
   빌드에 반영. 이 scheme으로 `xcrun simctl openurl booted petcycle://home`이 동작한다.
2. **딥링크 라우팅**: 각 화면이 딥링크로 진입 가능해야 한다.
   Expo Router라면 `screens[<id>].route`가 곧 파일 경로이며 딥링크 경로와 매핑된다.
3. **화면 매핑**: `config.screens`에 검증할 화면마다 `id → { deeplink, settleMs }`를 등록.
   `settleMs`는 애니메이션/데이터 로딩이 안정될 때까지의 대기(ms).
4. **testID (권장)**: Vision 판정 시 요소 식별을 돕도록 핵심 컴포넌트에 `testID` 부여.
5. **딥링크 미지원 화면**: `deeplink`가 없으면 `navigate`는 exit 3을 반환한다.
   이 경우 Maestro flow 기반 내비게이션이 필요(후순위 지원).
