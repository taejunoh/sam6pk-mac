# 삼국지6 파워업 키트 — macOS 실행 도구

맥에서 **삼국지6 파워업 키트**를 **한글 안 깨지고, 전투 중 안 멈추게** 실행하는 세팅 도구입니다.
(Apple Silicon / Intel Mac)

> ⚠️ **게임 파일은 포함돼 있지 않습니다.** 저작권 때문에 게임(`SAM6.EXE` 등)은 배포하지 않으며,
> 이 도구는 "게임이 맥에서 제대로 돌아가게 하는 환경"만 세팅합니다.
> 설치 중에 **본인이 가진 게임 폴더**를 지정하면 됩니다.

---

## ⬇️ 설치 (사용자용)

1. **[Releases](../../releases)** 에서 최신 `삼국지6-mac.zip` 을 받습니다.
2. 압축을 풀고 **`설치.command`** 를 더블클릭합니다.
   - "확인할 수 없는 개발자" 경고 → **우클릭 → 열기 → 열기**
3. 폴더 선택창에서 **본인 삼국지6 게임 폴더**(`SAM6.EXE` 가 있는 폴더)를 지정합니다.
4. 설치가 끝나면 **바탕화면 '삼국지6' 아이콘**으로 실행합니다.

### 게임 시작 요령
- "CD-ROM" 창 → **취소**
- "화면 재생 실패" → **확인**
- 초기설정에서 새 게임 / 데이터 로드 / 전술 시뮬레이션 선택

---

## ✅ 이 도구가 해결하는 것

| 문제 | 해결 |
|------|------|
| 한글이 □□□ 로 깨짐 | AppleGothic 매핑 + 메뉴폰트 설정 + Wine 시스템폰트 수정으로 **메뉴·대사·군주 이름까지 정상** |
| 전투 중 게임이 멈춤 | 가상머신(VM) 대신 **Wine 으로 구동**해 하이퍼바이저 타이머 버그 회피 |
| 실행이 번거로움 | **바탕화면 아이콘** 원클릭 실행 |

자세한 원리는 [`docs/기술설명.md`](docs/기술설명.md) 참고.

---

## 🗂 저장소 구성

```
설치.command            # 설치 스크립트 (더블클릭)
assets/
  reg/                  # 한글/폰트 설정 레지스트리 (5개)
  AppIcon.icns          # 앱 아이콘
  wine.tar              # 폰트픽스 Wine (⚠️ 용량 커서 git 미포함 → Releases 에서 제공)
docs/기술설명.md         # 한글 깨짐/프리징 해결 원리
scripts/build-release.command   # 배포용 zip 빌드
LICENSE                 # 이 도구(스크립트) 라이선스 (MIT)
LICENSE-Wine.txt        # 포함된 Wine 라이선스 안내 (LGPL)
```

> **참고**: `assets/wine.tar`(약 800MB)는 git 저장소에 넣지 않습니다(`.gitignore`).
> 배포는 이 저장소 + `wine.tar` 를 합쳐 만든 `삼국지6-mac.zip` 을 **Releases 에 올리는** 방식입니다.

---

## 🛠 개발자용 — 배포본 만들기

`wine.tar`(폰트픽스된 Wine) 을 `assets/` 에 넣은 뒤:

```bash
./scripts/build-release.command
```

→ `삼국지6-mac.zip` 이 만들어집니다. 이 파일을 GitHub **Releases** 에 업로드하세요.

`wine.tar` 만드는 법: 한글 폰트픽스(시스템폰트 `hvgasys.fon` 제거)를 적용한 Wine 앱을
`tar -cf assets/wine.tar -C /Applications "Wine Stable.app"` 로 묶습니다. ([`docs/기술설명.md`](docs/기술설명.md) 참고)

---

## 📄 라이선스 / 출처
- **이 도구(스크립트/문서)**: MIT (`LICENSE`)
- **Wine** (배포본에 포함): LGPL — https://www.winehq.org (`LICENSE-Wine.txt`)
- **AppleGothic 폰트**: 배포에 미포함, 설치 시 사용자 macOS에서 복사
- **게임(삼국지6)**: 미포함. 각자 본인 소유 게임을 사용하세요.

> 개인적으로 즐기기 위한 도구입니다. **게임 자체를 재배포하지 마세요.**
