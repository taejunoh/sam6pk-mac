# macOS 28 대응 계획

> 작성: 2026-11-06 · 기준 환경: macOS 27.0.1 (Apple Silicon)
> 이 문서는 조사 시점의 정보입니다. 확인된 사실에는 출처를 달았고, 근거가 추론뿐인 내용은 **[추정]** 으로 표시했습니다.

## 요약

- 이 도구는 **전부 Intel(x86_64)용 Wine** 위에서 돌아가기 때문에, Apple Silicon 맥에서는 **Rosetta 2 가 없으면 아무것도 실행되지 않습니다.**
- Apple은 Rosetta 2 를 **macOS 27 까지만** 범용으로 제공합니다. macOS 28 부터는 "Intel 프레임워크에 의존하는 오래되고 유지보수되지 않는 게임"을 위한 일부 기능만 남깁니다 ([Apple 지원 102527](https://support.apple.com/en-us/102527), [개발자 공지 2026-09-01](https://developer.apple.com/news/?id=w5ngl9k2)). 그 "일부"에 Wine 이 들어갈지는 정해진 바가 없습니다.
- **추천안: ARM64 네이티브 Wine + FEX(x86 에뮬레이터)로 엔진만 교체합니다.** 하이퍼바이저를 쓰지 않는 구조라 전투 프리징 위험이 낮고, 한글 설정도 대부분 그대로 쓸 수 있습니다.
  - 후보 엔진은 CrossOver 27 arm64(정식판 2027년 초 예정)와 커뮤니티 엔진 Mach9 입니다.
  - 걸림돌이던 툴바 폰트 픽스(엔진의 `hvgasys.fon` 제거)는 **prefix 만으로 해결하는 방식을 찾아 검증했고, 설치 도구에 반영했습니다** (아래 [4단계](#4-프로토타입--엔진-독립-한글-폰트-픽스)).
- **실측 (2026-11-06):** Mach9 엔진으로 Rosetta 없이 게임을 돌려 봤습니다. 한글, 툴바 군주 이름, 적벽 수전 전투(약 20분, 멈춤 0회), 세이브·로드가 모두 정상이었습니다 ([5절](#5-실측--mach9-arm64-엔진-검증-2026-11-06)).
- **macOS 27 에서는 지금 방식(Wine Stable + Rosetta)을 그대로 유지합니다.** 이 계획의 어떤 작업도 기존 경로를 바꾸지 않습니다.

---

## 1. 지금 실행 경로가 Rosetta 에 의존하는 지점

macOS 27.0.1 맥에서 `file` 명령으로 확인한 결과입니다.

| 구성 요소 | 위치 | 아키텍처 | Rosetta 필요 |
|---|---|---|---|
| 바탕화면 실행 앱 (AppleScript applet) | `~/Desktop/삼국지6.app` | universal (arm64 + x86_64) | ❌ |
| 실행 런처 스크립트 | `~/Library/Application Support/삼국지6/삼국지6_실행.command` | bash (시스템, arm64) | ❌ |
| **Wine 로더 / 서버** | `…/Wine Stable.app/Contents/Resources/wine/bin/wine`, `wineserver` | **x86_64 전용** | ✅ |
| **Wine 유닉스 쪽 모듈** | `lib/wine/x86_64-unix/*.so` (ntdll.so, winemac.so 등) | **x86_64 전용** | ✅ |
| **Wine 동봉 라이브러리** | `lib/*.dylib` (freetype, MoltenVK, SDL2, gnutls …) | **x86_64 전용** | ✅ |
| Wine 윈도우 쪽 DLL | `lib/wine/i386-windows/`, `x86_64-windows/` | PE (Windows 코드) | ✅ (위 로더가 실행) |
| 게임 `SAM6.EXE` | 사용자 게임 폴더 | PE32 i386 | ✅ (Wine 이 실행) |
| 설치 스크립트 `설치.command` | 이 레포 | bash | ❌ (단, 안에서 Wine 을 실행) |

**결론:** 실행 앱과 스크립트는 네이티브라서 문제가 없습니다. **Wine 엔진(Wine Stable 11.0) 한 덩어리가 통째로 Rosetta 에 의존합니다.** 32비트 게임은 Wine 11 의 새 WoW64 방식으로 64비트 x86 프로세스 안에서 돌기 때문에, Rosetta 가 빠지면 게임까지 가지도 못하고 `wine` 실행 단계에서 `Bad CPU type in executable` 로 멈춥니다. 2026-09 macOS 27 업그레이드 직후 Rosetta 가 빠졌을 때 실제로 이 증상이 났습니다.

### 이 레포와 관계없는 것 (참고)
- `~/Applications/samgukji6 powerupkit extracted Game S6New Kor Final exe.app` 와 `~/Library/Application Support/Wineskin/` 는 신무장 에디터(`S6New_Kor_Final.exe`)를 돌리려고 따로 만든 **Wineskin 래퍼**입니다. 래퍼 실행 파일(`wineskinlauncher`)과 들어 있는 Wine 이 모두 **x86_64 전용**이고, 엔진 보관함에 있는 `WS12WineSikarugir10.0_3` 도 마찬가지입니다. Sikarugir(Wineskin 후속)는 README 에 Rosetta 2 가 필수라고 적혀 있고, arm64 지원 계획은 없습니다 ([이슈 #247](https://github.com/Sikarugir-App/Sikarugir/issues/247)). 이 래퍼도 macOS 28 에서 같은 영향을 받습니다.

---

## 2. 대안 비교

| | (a) ARM64 Wine + FEX | (b) x86 PC 에뮬레이터 + Win98 | (c) Win11 ARM VM + Prism | (d) "게임용 Rosetta" 에 기대기 |
|---|---|---|---|---|
| 대표 구현 | **CrossOver 27 arm64**, **Mach9** | **DOSBox-X**, 86Box, UTM 에뮬레이트 모드 | Parallels, VMware Fusion, UTM | 지금 그대로 |
| Rosetta 필요 | 없음 | 없음 | 없음 | **필요(남을지 불확실)** |
| 한글 | 지금 설정 그대로 사용. 툴바 폰트는 prefix 방식 픽스로 해결(검증 완료) | 한글 Win98 이 처리 | Windows 가 처리 | 지금 그대로 |
| 전투 프리징 위험 | 낮음~중간. 하이퍼바이저가 없음. FEX 의 x87 정확도가 변수 [추정] | 낮음. CPU·타이머를 소프트웨어로 에뮬레이션해서 HVF 를 쓰지 않음 [추정] | **높음. UTM 에서 실제로 멈췄음.** Parallels 는 자체 구현이지만 같은 Apple Hypervisor 를 씀 [추정] | 지금과 같음(낮음) |
| 사용자 설치 난이도 | 쉬움~보통 (설치 도구가 엔진을 받아 설치) | **어려움**: 한글 Win98 정품 CD·키가 필요하고 지금은 구할 곳이 없음 | 보통. Windows 11 라이선스 + (Parallels 는 연 $99.99~) | 없음 |
| 성숙도 | CrossOver arm64 는 Preview(2026-07), 정식판은 2027년 초. Mach9 은 2026-10 첫 출시(1인 개발) | DOSBox-X 성숙(arm64 빌드 2026-10) | 제품은 성숙, 이 게임에선 실패 이력 | — |
| 판정 | ✅ **추천** | 🟡 예비안 (Win98 을 가진 사용자용) | ❌ 비추천 | 🟡 공짜 보험. 대비책으로 삼지 않음 |

### (a) ARM64 네이티브 Wine + x86 에뮬레이션 — 추천
- **OS 쪽 준비는 끝났습니다.** CodeWeavers 의 Brendan Shanks 가 2026-08-07 wine-devel 에 "macOS 에 ARM64 Wine 을 네이티브로 돌릴 요소가 다 갖춰졌다"고 공지했습니다 ([wine-devel](https://list.winehq.org/hyperkitty/list/wine-devel@list.winehq.org/thread/CKG5CEN2BE5VRXZ7O7NX4YUSBH3247WH/)). 필요한 기능은 macOS 26.5 의 x18 ABI·4K 페이지·TSO 와 26.4 의 PAGEZERO 조정이고, 제한 entitlement 가 필요합니다.
- **업스트림 WineHQ 에는 macOS arm64 빌드가 아직 없습니다.** 2026-10 기준 핵심 패치가 병합되지 않았습니다 ([Gcenx 빌드](https://github.com/Gcenx/macOS_Wine_builds/releases)).
- **CrossOver 27 arm64 Preview** (2026-07-31): ARM64 Wine 에 CodeWeavers 가 macOS 용으로 포팅한 FEX 를 붙였고, macOS 26.5 이상이 필요합니다. CodeWeavers 는 macOS 28 에서 Rosetta 가 대부분 사라져도 CrossOver 는 계속 동작한다고 밝혔습니다 ([블로그](https://www.codeweavers.com/blog/mjohnson/2026/7/31/crossover-preview-the-right-to-bear-arm64-on-mac), [AppleInsider](https://appleinsider.com/articles/26/07/31/first-apple-silicon-native-crossover-build-in-testing-as-rosettas-end-nears)).
  - CrossOver 27 에서는 32비트 *bottle* 지원이 끝나지만, 32비트 *앱*은 64비트 bottle 에서 계속 돕니다. 우리 prefix 는 이미 win64 + WoW64 라서 해당 사항이 없습니다.
  - 유료 제품이라 설치 도구에 넣어 배포할 수는 없습니다. 사용자가 CrossOver 를 따로 사고, 우리 설정(레지스트리·폰트)만 bottle 에 적용하는 방식이 됩니다.
- **Mach9** ([athei/wine-build](https://github.com/athei/wine-build)): 업스트림 Wine 11.19+ 에 자체 패치를 얹은 arm64 빌드입니다. 32비트 코드는 FEX 가, DirectDraw 는 wined3d 가 처리합니다. macOS 26.4 이상, 노터라이즈된 DMG 로 배포되고, 런처에 내장해 쓰도록 만들어졌습니다.
  - 다만 **엔진 번들(wine.app)을 수정하지 말라고 명시**하고 있습니다. 그래서 지금의 `hvgasys.fon` 제거 방식은 쓸 수 없습니다.
  - 무료 오픈소스라 설치 도구가 받아서 쓰는 방식이 가능합니다 [추정: 라이선스 확인 필요].
- **해당 없음:** Hangover·Box64 는 Linux 전용이고, Sikarugir·Whisky·Wineskin·GPTK 는 Rosetta 가 필요합니다.
- **우회 경로:** Linux arm64 VM(Apple Virtualization) 안에서 Hangover/FEX 를 쓰면 지금도 돌릴 수 있습니다. 하지만 일반 사용자가 설치하기 어렵고, VM 계층이 있으니 프리징 위험도 0 은 아닙니다 [추정].

### (b) arm64 PC 에뮬레이터 + Windows 98 — 예비안
- **DOSBox-X** 는 네이티브 arm64 macOS 빌드를 정식 배포하고(2026-10-01, [릴리스](https://github.com/joncampbell123/dosbox-x/releases)), Win98 SE 구동을 공식 목표로 둡니다. CPU 와 타이머(PIT/RTC)를 소프트웨어로 에뮬레이션하므로 우리가 겪은 HVF 타이머 문제와는 구조적으로 무관합니다 [추정].
- 성능은 Mac 에서 Win98 이 "괜찮지만 매끄럽진 않다"는 수준이라는 사용자 보고가 있습니다 ([VOGONS](https://www.vogons.org/viewtopic.php?p=1202988)). 640×480 2D 게임에는 충분할 것으로 봅니다 [추정].
- **가장 큰 장벽은 기술이 아니라 OS 입니다.** 한글 Windows 98 정품 CD 와 키를 사용자가 갖고 있어야 하고, 지금은 판매처가 없습니다. Windows 이미지를 배포할 수도 없습니다.
- 공유 폴더가 사실상 없어서 게임 파일은 디스크 이미지로 넣어야 하고, 세이브를 주고받기도 번거롭습니다.
- 86Box 는 정확도가 가장 높지만 BIOS ROM 이 필요하고 Apple Silicon 성능이 검증되지 않았습니다. UTM 에뮬레이트 모드(QEMU TCG)는 느리고 Win98 용 가속 드라이버가 마땅치 않습니다.

### (c) Windows 11 ARM + Prism — 비추천
- 2026-07 에 **UTM + Windows 11 ARM 에서 이 게임이 전투 중 반복해서 멈췄습니다.** GPU 를 끄고 vCPU 를 1개로 줄여도 해결되지 않았고, 하이퍼바이저(QEMU/HVF)가 타이머·인터럽트를 놓치는 문제로 진단했습니다 ([기술설명](기술설명.md)).
- Parallels 는 장치·그래픽 스택이 자체 구현이고 Microsoft 가 공식 지원하는 유일한 제품입니다. 그래서 QEMU 고유의 버그는 피할 수 있습니다. 하지만 같은 Apple Hypervisor 위에서 Prism 으로 x86 을 번역하므로 같은 계열의 문제를 배제할 수 없습니다 [추정].
- Windows 라이선스와 Parallels 구독 비용이 들고, 오래된 DirectDraw 게임은 Win10/11 에서 래퍼(cnc-ddraw 등)가 필요할 때가 많습니다 [추정].
- Parallels 14일 체험판으로 전투 장면을 직접 검증해 보기 전에는 대안으로 올리지 않습니다.

### (d) Apple 이 남기는 "게임용 Rosetta" — 보험
- Apple 은 이 "일부 기능"이 어떤 방식인지 밝히지 않았습니다. 프레임워크 단위인지, 타이틀 허용목록인지, 서명 기준인지 알 수 없습니다 ([102527](https://support.apple.com/en-us/102527)).
- 우리 Wine 번들의 상태는 이렇습니다(로컬 확인).
  - 서명은 ad-hoc 이고 TeamID 가 없습니다. `LSApplicationCategoryType` 도 없습니다.
  - `winemac.so` 는 AppKit, Metal, OpenGL, QuartzCore, IOKit 을, `winecoreaudio.so` 는 CoreAudio 계열을 링크합니다. 오래된 게임이 쓰는 프레임워크와 거의 같습니다.
- **판단** [추정]
  - 프레임워크 단위로 남긴다면 Wine 도 살아남을 수 있습니다.
  - 허용목록이나 서명 기준이라면 가능성이 낮습니다.
  - 종합하면 그대로 동작할 가능성은 낮음~중간입니다. **이걸 계획의 기반으로 삼지 않습니다.**
- **확인 방법:** macOS 28 베타가 나오면 [체크리스트](macOS28-체크리스트.md) 의 자동 점검 스크립트(`scripts/macos28-check.command`)를 돌리면 바로 판정됩니다.
- **Linux VM 용 Rosetta:** macOS 27 부터 OS 에 통합됐고, 26.4 릴리스 노트에 27 이후에도 유지된다고 나와 있습니다(2차 출처: [MacRumors 2026-02-16](https://www.macrumors.com/2026/02/16/macos-tahoe-26-4-rosetta-2-warnings/)).

---

## 3. 추천안과 로드맵

**ARM64 Wine + FEX 로 엔진만 교체합니다.** 게임은 계속 BYO 로 두고, 설정 방식(prefix·레지스트리·AppleGothic 복사·런처)도 지금 그대로 유지합니다.

| 단계 | 시기 | 할 일 | 상태 |
|---|---|---|---|
| 0 | 지금 | macOS 27 에서 지금 경로 유지. Rosetta 가 없으면 설치 도구가 자동 설치(v1.1) | ✅ 완료 |
| 1 | 지금 | 점검 스크립트 `scripts/macos28-check.command`, 베타 체크리스트 | ✅ 이번 작업 |
| 2 | 지금 | **엔진을 고치지 않는 한글 폰트 픽스** ([4단계](#4-프로토타입--엔진-독립-한글-폰트-픽스)) — 검증 완료, 설치 도구에 반영 | ✅ 이번 작업 |
| 3 | 2026-11 | 맥에서 ARM64 엔진으로 SAM6 실행 검증: 한글(메뉴·툴바), 장시간 전투, 사운드, 세이브. **Mach9 은 통과** ([5절](#5-실측--mach9-arm64-엔진-검증-2026-11-06)). CrossOver arm64 Preview 는 유료 고객 전용이라 정식판(2027년 초)에서 확인 | ✅ Mach9 / ⏳ CrossOver |
| 4 | 다음 | 설치 도구에 엔진 선택 추가: Apple Silicon + macOS 26.4 이상이면 ARM64 엔진, 아니면 지금의 Wine Stable(Rosetta). 런처는 엔진 경로만 바꿈 | ⏳ |
| 5 | 2027-06 (WWDC, macOS 28 베타) | 체크리스트 실행. Wine Stable 이 살아남는지(d), ARM64 엔진이 베타에서 도는지(a) 확인 | ⏳ |
| 6 | macOS 28 정식 출시 전 | v2.0 배포: ARM64 엔진을 기본으로, Rosetta 경로는 macOS 27 이하용 | ⏳ |

**지켜볼 것**
- 업스트림 Wine 에 macOS arm64 MR 이 병합되는지, Gcenx 가 arm64 패키지를 내는지
- CrossOver 27 정식판 출시(2027년 초)와 CodeWeavers FEX 포크의 소스 공개 여부
- Mach9 의 i386·x87 회귀
- macOS 28 베타에서 "게임용 Rosetta" 의 실제 범위

---

## 4. 프로토타입 — 엔진 독립 한글 폰트 픽스

**문제:** 툴바의 군주 이름은 `CreateFont("System", charset=129)` 로 그려집니다. Wine 의 비트맵 폰트 `hvgasys.fon` 이 이 요청에 정확히 매칭되는데, 이 폰트에는 한글 글리프가 없어서 "III" 으로 깨집니다. 지금은 엔진 안의 이 파일을 `.bak` 으로 바꿔서 해결하는데, 서명·노터라이즈된 ARM64 엔진(Mach9, CrossOver)에는 쓸 수 없는 방법입니다.

**목표:** 엔진은 건드리지 않고 **prefix(레지스트리·`drive_c/windows/Fonts`)만으로** 같은 결과를 내는 것입니다. 그러면 어떤 엔진에서든 같은 설치 단계를 쓸 수 있습니다.

### 결과 — 해결됨 (2026-11-06, Wine 11.0 순정 엔진에서 검증)

**방법 (A) — prefix 에 폰트 파일 하나 두기 (채택, `설치.command` 3단계에 반영):**

```bash
cp /System/Library/Fonts/AppleSDGothicNeo.ttc "$WINEPREFIX/drive_c/windows/Fonts/hvgasys.fon"
```

- **원리:** Wine(`dlls/win32u/font.c`)은 코드페이지 949 의 시스템 비트맵 폰트를 레지스트리 `HKCC\Software\Fonts "FONTS.FON"`(값 `hvgasys.fon`)에서 정하고, 그 파일을 **`C:\windows\Fonts` 에서 먼저** 찾은 뒤 없을 때만 엔진의 `share/wine/fonts` 를 봅니다. 그래서 같은 이름으로 한글 폰트를 prefix 에 두면 엔진 파일 대신 그것이 로드됩니다.
- **장점**
  - 레지스트리·런처·엔진을 고치지 않습니다.
  - 코드페이지나 DPI 가 바뀌어 Wine 이 레지스트리를 다시 써도 유지됩니다.
  - 사용자 맥의 시스템 폰트를 그 자리에서 복사하므로 폰트를 재배포하지 않습니다. 기존 AppleGothic 복사와 같은 방식입니다.
- **비용:** prefix 가 약 55MB 늘어납니다.

**검증 (`WINEDEBUG=+font` 로그 + 맵 화면 툴바 캡처, 샌드박스)**

| 구성 | "System"/charset 129 요청이 고른 폰트 | 툴바 군주 이름 |
|---|---|---|
| 순정 엔진 + 기존 레지스트리 | 엔진의 `hvgasys.fon` (한글 없음) | ❌ "III" |
| 지금 방식 (엔진의 hvgasys.fon 이름 변경) | Apple SD Gothic Neo (macOS 시스템 폰트) | ✅ |
| **(A) 순정 엔진 + prefix 파일** | Apple SD Gothic Neo (`C:\windows\fonts\hvgasys.fon`) | ✅ 지금 방식과 픽셀 동일 |
| (A) + 코드페이지 en_US → ko 전환 후 | 위와 같음 | ✅ |
| (A) + 지금 배포 엔진(이름 변경 포함) — **v1.2 설치 도구 회귀 테스트** | 위와 같음 | ✅ |
| (B) 레지스트리만 (`FONTS.FON` 을 없는 파일로) | 대체 폰트로 넘어감 | ✅ 단, 코드페이지가 바뀌면 Wine 이 값을 되돌려 ❌ → 런처가 매번 다시 써야 함 |
| AppleGothic 에 OS/2 테이블 추가 | 여전히 hvgasys.fon | ❌ (B 와 같이 쓰면 되지만 UI 레이아웃이 커짐) |

초기설정·로드 대화상자와 메뉴의 한글도 지금 방식과 픽셀 단위로 같습니다.

**함께 발견한 점:** Wine 11 은 `applegothic.ttf` 를 **아예 로드하지 않습니다**. 로그에 `lacks either an OS2, HHEA or HEAD table` 이 찍힙니다.
- 그래서 레지스트리의 "AppleGothic" 대체 설정은 실제로는 macOS 시스템 폰트(Apple SD Gothic Neo)로 넘어가서 동작합니다. Wine 이 CoreText 로 macOS 폰트를 읽는 기능(`load_mac_fonts`)에 기대고 있는 셈입니다.
- (A)를 쓰면 툴바 쪽은 prefix 안의 폰트 파일이 직접 쓰이므로, 이 의존성이 줄어듭니다.
- ARM64 엔진에서 macOS 폰트를 읽지 못하면 다른 한글도 깨질 수 있으니, 3단계 검증에서 확인할 항목입니다.

**ARM64 엔진에 적용될지** [추정]
- 두 방법 모두 CPU 와 관계없는 Wine 공용 코드(코드페이지별 폰트 표, `HKCC\Software\Fonts`, Windows 폰트 폴더 우선 탐색)만 씁니다. CrossOver 의 bottle 도 곧 WINEPREFIX 이므로 같은 설치 단계를 그대로 적용할 수 있을 것으로 봅니다.
- 실제 엔진에서는 `WINEDEBUG=+font` 로 실행한 뒤, `font_SelectFont L"System" ... charset=129` 다음의 `Chosen:` 줄이 prefix 의 `hvgasys.fon` 을 가리키는지 확인합니다.

**v1.x 와의 관계:** 지금 배포하는 엔진(`wine.tar`)의 `hvgasys.fon` 이름 변경은 그대로 둡니다(이중 안전장치). 앞으로 ARM64 엔진으로 바꿀 때는 (A)만으로 충분합니다.

---

## 5. 실측 — Mach9 arm64 엔진 검증 (2026-11-06)

**엔진**
- [athei/wine-build](https://github.com/athei/wine-build) 의 `wine-arm64-11.20-5-macos-arm64.tar.xz` (2026-10-30, SHA256 `8083f8e8…`, zlib 라이선스)
- `wine`·`wineserver` 는 arm64 이고, Developer ID 로 서명돼 있습니다(Alexander Theissen, TeamID `WLKUUJD25W`). `codesign --verify` 통과.
- 32비트 x86 코드는 FEX(`libwow64fex`, `xtajit.dll`)로 실행됩니다. 엔진에 `hvgasys.fon` 이 들어 있으므로 [4절](#4-프로토타입--엔진-독립-한글-폰트-픽스)의 prefix 폰트 픽스가 필요합니다.

**환경**
- macOS 27.0.1, Apple Silicon. 실제 설치와는 분리된 샌드박스 HOME/prefix 에서 테스트했습니다.
- prefix 준비는 설치 도구와 같습니다: `wineboot -i` → AppleGothic·Apple SD Gothic Neo 복사 → `assets/reg/*.reg` 적용 → `LANG=ko_KR.UTF-8` 로 실행.

| 항목 | 결과 |
|---|---|
| Rosetta 미사용 | ✅ `vmmap` 에서 SAM6.EXE 프로세스의 Code Type 이 `ARM64`, FEX 모듈이 로드됨. `/usr/lib/libRosetta.dylib`·`liboah.dylib` 가 매핑되는데, 번역이 아니라 arm64 프로세스가 쓰는 시스템 라이브러리로 보임 [추정]. macOS 28 에서 이 둘이 남는지는 체크리스트로 확인 |
| 메뉴·대화상자·맵·정보 패널 한글 | ✅ |
| 툴바 군주 이름 (System/charset 129) | ✅ prefix 폰트 픽스로 정상 ("오태준") |
| 전투 (전술 시뮬레이션 → 적벽 수전) | ✅ 4번 진입, 전투 맵 합계 약 20분 + 컷신 2번(각 약 5분). 게임 프로세스를 45분 연속 실행했고 **멈춤·크래시 0회**. 원군 도착, 계략, 관우·관평 도발 같은 스크립트 이벤트와 실제 교전·사상자가 모두 정상 |
| 세이브·로드 | ✅ 일반 모드 10번 슬롯에 저장 → 다시 로드 정상. 전술 모드 저장·불러오기도 정상 |
| 효과음 | ✅ (추정) coreaudiod 로그에서 전투 중 내장 스피커 출력이 수백 번 열렸다 닫힘. 귀로 확인하지는 않음. BGM 은 원래 CD 오디오라 나오지 않음 |
| 속도 | 진행 1턴 처리 약 10초 (CPU 약 100%). 느리다는 느낌은 없었음. Rosetta 와 같은 조건으로 재 보지는 않음 |

**참고 — CPU 기준선 정정:** 전략 맵이나 전투 맵에서 입력을 기다릴 때도 CPU 는 **계속 약 100%** 입니다. 게임이 메시지가 없어도 쉬지 않고 계속 확인하는 구조이기 때문이고, Rosetta 엔진에서도 똑같이 측정됐습니다. 대기 중 약 2% 까지 내려가는 건 모달 창이 떠 있을 때뿐입니다. 프리징 판단은 CPU 가 아니라 **화면이 멈추고 클릭에 반응하지 않는지**로 합니다.

**한계**
- 전투가 매번 주유 포획·본진 함락으로 일찍 끝나서, 하나의 전투를 10분 넘게 이어가지는 못했습니다. 황개 화공 같은 후반부 이벤트도 보지 못했습니다.
- 가끔 부대를 두 번 클릭해야 명령 창이 떴습니다. Rosetta 와 비교하지는 않았습니다.
- Mach9 은 1인 개발 프로젝트이고 첫 arm64 릴리스가 2026-10 입니다. 업데이트가 잦으니, 설치 도구에 넣을 때는 **검증한 릴리스 버전과 SHA256 을 고정**합니다.

**다음 (4단계):** 설치 도구에 엔진 선택을 추가합니다. Apple Silicon + macOS 26.4 이상이면 Mach9 엔진을 고정 버전으로 받아 SHA256 을 확인한 뒤 쓰고, 그 밖에는 지금의 Wine Stable(Rosetta)을 씁니다. macOS 28 베타가 나오면 Mach9 경로를 먼저 확인합니다.
