# web-playwright 어댑터

웹 앱을 dev 서버로 띄우고 Playwright로 viewport 고정 스크린샷을 찍는 어댑터.
[`../CONTRACT.md`](../CONTRACT.md)의 4함수 계약을 구현한다.

## 요구사항

- Node.js + `npx`
- 채택 프로젝트의 devDependency로 `playwright`(또는 `@playwright/test`) 설치 + 브라우저 설치
  ```bash
  npm i -D playwright && npx playwright install chromium
  ```
  `capture`는 `npx --no-install`로 실행하므로, 설치돼 있지 않으면 대화형 설치 프롬프트 없이 바로 실패한다.
- `jq` (config 파싱), `curl` (헬스체크)

## 함수

| 명령 | 동작 | 출력 |
|---|---|---|
| `adapter.sh build` | `buildCommand` 실행. 없으면 생략 | `OK` |
| `adapter.sh launch` | `baseUrl`이 이미 응답하면 그대로 성공. 아니면 `devCommand`를 백그라운드로 띄우고 `launchTimeoutMs`까지 500ms 간격 헬스체크 | `OK` |
| `adapter.sh navigate <id>` | `baseUrl + screens[id].path` 도달 확인 (curl) | `OK` |
| `adapter.sh capture <id>` | `npx --no-install playwright screenshot --viewport-size=W,H --wait-for-timeout=<settleMs> <url> <png>` | `<png경로>` |

`navigate`는 도달 확인만 한다. 함수 호출마다 프로세스가 따로 떠서 브라우저 상태가 이어지지 않으므로,
실제 페이지 이동은 `capture`가 URL을 직접 열어 수행한다.

모든 명령에 `--dry-run`을 붙이면 실제 실행 없이 수행할 명령 문자열만 출력한다.

```bash
bash adapter.sh capture home --dry-run
# → npx --no-install playwright screenshot --viewport-size=1280,800 --wait-for-timeout=600 http://localhost:5173/ .design-bounce/shots/home.png
```

### 종료 코드

| 상황 | exit |
|---|---|
| `screen_id` 인자 누락, 형식 위반(`[A-Za-z0-9_-]` 외 문자) | 2 |
| `screens[id].path` 없음, `/`로 시작하지 않음, `//`로 시작, URL 응답 실패 | 3 |
| config 없음, `baseUrl` 없음/비 http(s), 명령 필드가 문자열 배열이 아님, `devCommand` 없음 + 서버 없음 | 4 |
| dev 서버 헬스체크 타임아웃 또는 dev 서버 조기 종료 | 5 |

## config (`design-bounce.config.json`)

현재 작업 디렉토리의 `design-bounce.config.json`을 읽는다.
`DESIGN_BOUNCE_CONFIG` 환경변수로 경로 override 가능. 전체 예시는 [`examples/web.config.json`](../../examples/web.config.json).

```json
{
  "adapter": "web-playwright",
  "baseUrl": "http://localhost:5173",
  "viewport": { "width": 1280, "height": 800 },
  "buildCommand": ["npm", "run", "build"],
  "devCommand": ["npm", "run", "dev", "--", "--port", "5173", "--strictPort"],
  "launchTimeoutMs": 30000,
  "screens": {
    "home": { "path": "/", "settleMs": 600 },
    "pricing": { "path": "/pricing", "fullPage": true }
  }
}
```

| 필드 | 기본값 | 설명 |
|---|---|---|
| `baseUrl` | (필수) | `http://` 또는 `https://`로 시작 |
| `viewport` | 1280×800 | 캡처 viewport |
| `buildCommand` | 없음(생략) | argv 문자열 배열 |
| `devCommand` | 없음 | argv 문자열 배열. 없으면 서버가 이미 떠 있어야 한다 |
| `launchTimeoutMs` | 30000 | 헬스체크 대기 한도 |
| `captureDir` | `.design-bounce/shots` | PNG 저장 위치 |
| `screens[id].path` | (필수) | `/`로 시작하는 경로 |
| `screens[id].settleMs` | 0 | 페이지 로드 후 캡처 전 대기 |
| `screens[id].fullPage` | false | 전체 페이지 캡처 |

**명령은 문자열 배열로만 받는다.** 어댑터는 배열을 그대로 argv로 실행하고 `eval`이나 `sh -c`를 쓰지 않는다.
`"npm run dev && ..."` 같은 셸 문법이 필요하면 `package.json` 스크립트로 옮기고 `["npm","run","<script>"]`로 호출한다.

## dev 서버 정리

계약에 종료 함수가 없어서 `launch`가 띄운 dev 서버는 백그라운드에 남는다.
로그는 `.design-bounce/web-dev.log`, PID는 `.design-bounce/web-dev.pid`에 기록된다.

```bash
kill "$(cat .design-bounce/web-dev.pid)"
```

`npm run dev`처럼 래퍼를 거치면 PID가 래퍼 프로세스일 수 있다. 자식 서버가 남으면 포트로 찾아 종료한다
(`lsof -ti tcp:5173 | xargs kill`).

## 한계

- SPA dev 서버는 없는 경로에도 200을 반환하므로 `navigate`는 "서버 도달" 수준만 확인한다.
  실제 화면 오류는 판정자가 스크린샷에서 잡는다.
- 클릭·로그인·폼 입력 같은 상호작용 내비게이션, 다중 viewport 캡처는 지원하지 않는다.
