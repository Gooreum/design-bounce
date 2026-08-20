# Standards — Mobile (iOS HIG / Android Material)

> 출처: Apple Human Interface Guidelines + Android Material Design 이식.
> `design-standards.md`(플랫폼 무관)에 더해, **모바일 기기 전용** 표준 앵커다.
> 판정자는 모바일 스크린샷을 **실제 기기 프레임**(노치·홈 인디케이터 포함)에서 평가한다.

## 터치 타겟 (Touch Targets)

- **iOS (HIG)**: 최소 **44pt × 44pt**.
- **Android (Material)**: 최소 **48dp × 48dp**.
- 이보다 작은 인터랙티브 요소는 오탭을 유발 — `[Blocker]`/`[High-Priority]` 후보.
- 시각 크기가 작아도(예 아이콘 20px) **히트 영역(hitbox)** 은 44pt/48dp를 확보해야 한다.
- 인접 타겟 간 간격을 확보해 오탭을 방지한다 (최소 8px 이상 권장).

## Safe Area (안전 영역)

- **노치 / 다이나믹 아일랜드 / 상태바** 영역에 콘텐츠·인터랙션이 가리지 않도록 상단 safe area 존중.
- **홈 인디케이터** 영역에 하단 버튼·탭바가 겹치지 않도록 하단 safe area 존중.
- 배경/이미지는 safe area 밖까지 확장 가능하나, **텍스트·터치 요소는 safe area 안**에 둔다.
- 가로 모드에서는 좌우 노치 인셋도 고려.

## Dynamic Type (가변 글꼴)

- 시스템 글꼴 크기 설정(작게~아주 크게)에 **레이아웃이 대응**해야 한다.
- 폰트 크기 하드코딩 대신 텍스트 스타일(iOS Text Styles / Android sp 단위)을 사용.
- 큰 글꼴 설정에서 텍스트 잘림·겹침·버튼 깨짐이 없는지 견고성(Robustness) 점검 항목으로 검증.
- 접근성 큰 글꼴(Accessibility sizes)에서 레이아웃이 세로로 리플로우되는지 확인.

## 하단 탭바 (Bottom Tab Bar)

- 탭 **라벨 가독성** 확보: 아이콘만으로 의미가 모호하면 라벨을 병기.
- 라벨은 짧고 잘리지 않아야 하며, 대비 4.5:1을 만족.
- 활성/비활성 탭이 색·굵기로 명확히 구분되어야 한다.
- 탭 개수는 iOS 5개 / Android 3~5개 권장 범위 준수. 초과 시 과밀로 터치 타겟 축소.

## 모바일 판정 체크 요약

| 항목 | 표준 |
|------|------|
| 터치 타겟 (iOS) | **44pt** 이상 |
| 터치 타겟 (Android) | **48dp** 이상 |
| Safe area | 상단(노치)·하단(홈 인디케이터) 존중 |
| Dynamic Type | 시스템 글꼴 크기 대응, 잘림 없음 |
| 탭바 라벨 | 가독성·대비 4.5:1·명확한 활성 구분 |
