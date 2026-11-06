#!/bin/bash
# ============================================================
#  삼국지6 파워업 키트 — macOS 실행 도구 (Wine 기반)
#
#  ※ 이 도구는 "게임을 macOS에서 돌아가게 해주는 세팅"만 합니다.
#     게임 파일(SAM6.EXE 등)은 포함돼 있지 않습니다 —
#     본인이 가진 삼국지6 게임 폴더를 설치 중에 지정하시면 됩니다.
#
#  자동으로 해주는 것:
#   - Wine 설치 (한글 폰트 깨짐까지 수정된 빌드)
#     · Apple Silicon + macOS 26.4 이상이면 Rosetta 가 필요 없는
#       ARM64 엔진(Mach9)도 고를 수 있음 (macOS 28 이상은 자동)
#   - 한글 렌더링/가상데스크톱 등 Wine 설정
#   - 실행 런처 + 바탕화면 아이콘
# ============================================================

SELF="$(cd "$(dirname "$0")" && pwd)"
AS="$SELF/assets"
ROOT="$HOME/Library/Application Support/삼국지6"
PREFIX="$HOME/.wine-sam6"
# 엔진: stable = 기본 Wine(Rosetta 2 필요) / mach9 = ARM64 네이티브 Wine + FEX (Rosetta 불필요)
# Mach9 은 설치 중에 내려받으며, 검증한 릴리스와 SHA256 을 고정해 둔다. (docs/macOS28-대응계획.md 5절)
MACH9_VER="arm64-11.20-5"
MACH9_URL="https://github.com/athei/wine-build/releases/download/arm64-11.20-5/wine-arm64-11.20-5-macos-arm64.tar.xz"
MACH9_SHA256="8083f8e84c012d707a623060c0fc11fbea9ae810dcfe3b0252a0bd14410cad48"
STABLE_BIN_REL="Wine Stable.app/Contents/Resources/wine/bin"
MACH9_BIN_REL="Mach9/wine/bin"
APPLEGOTHIC="/System/Library/Fonts/Supplemental/AppleGothic.ttf"
SDGOTHIC="/System/Library/Fonts/AppleSDGothicNeo.ttc"

die() { echo; echo "❌ 설치 실패: $1"; echo; printf "[Enter]를 눌러 닫기 ... "; read _ 2>/dev/null || true; exit 1; }

clear 2>/dev/null || true
echo "======================================================"
echo "   삼국지6 파워업 키트  —  macOS 실행 도구 설치"
echo "======================================================"
echo
echo "  이 도구는 게임 실행 '환경'만 설치합니다."
echo "  게임 파일은 설치 중에 '본인 게임 폴더'를 직접 지정합니다."
echo
printf "  계속하려면 [Enter], 취소하려면 [Ctrl+C] ... "
read _ 2>/dev/null || true
echo

# --- 사전 확인 ---
[ -d "$AS/reg" ]       || die "assets/reg 폴더를 찾을 수 없습니다."
[ -f "$APPLEGOTHIC" ]  || die "macOS 한글 폰트(AppleGothic)를 찾을 수 없습니다. macOS가 맞나요?"

# major.minor 기준 버전 비교: ver_ge A B → A >= B (예: 26.4 vs 27.0.1)
ver_ge() {
  local a1 a2 b1 b2
  a1="${1%%.*}"; a2="${1#*.}"; [ "$a2" = "$1" ] && a2=0; a2="${a2%%.*}"
  b1="${2%%.*}"; b2="${2#*.}"; [ "$b2" = "$2" ] && b2=0; b2="${b2%%.*}"
  a1="${a1//[!0-9]/}"; a2="${a2//[!0-9]/}"; b1="${b1//[!0-9]/}"; b2="${b2//[!0-9]/}"
  a1="${a1:-0}"; a2="${a2:-0}"; b1="${b1:-0}"; b2="${b2:-0}"
  [ "$a1" -gt "$b1" ] && return 0
  [ "$a1" -eq "$b1" ] && [ "$a2" -ge "$b2" ] && return 0
  return 1
}

# Rosetta 2 확인 (Apple Silicon 전용) — 기본 Wine 은 Intel 용이라 Rosetta 가 없으면 실행 자체가 안 됨
need_rosetta() { [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; }
ensure_rosetta() {
  if need_rosetta; then
    echo "  ▶ Rosetta 2 가 설치돼 있지 않습니다."
    echo "    Wine 은 Intel 용이라 Apple Silicon 맥에서는 Rosetta 2 가 필요합니다."
    echo "    (macOS 업데이트 후 빠지는 경우가 있습니다.)"
    echo "    지금 설치합니다. 라이선스 동의를 물으면 A 를 입력하고 Enter 를 누르세요."
    echo "    (한글 입력 상태면 'ㅁ' 이 입력되니, 한/영 키로 영문으로 바꾼 뒤 A)"
    /usr/sbin/softwareupdate --install-rosetta
    if need_rosetta; then
      echo "  ▶ 다시 시도합니다. 맥 로그인 암호를 물으면 입력해 주세요 (입력해도 화면에 안 보입니다)."
      sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    fi
    need_rosetta && die "Rosetta 2 설치에 실패했습니다. 터미널에서 softwareupdate --install-rosetta 를 실행한 뒤 다시 설치하세요."
    echo "  · Rosetta 2 설치 완료"
    echo
  fi
}

# --- 실행 엔진 선택 ---
ARCH="$(uname -m)"
OSVER="$(sw_vers -productVersion 2>/dev/null)"
OSMAJOR="${OSVER%%.*}"; OSMAJOR="${OSMAJOR//[!0-9]/}"; OSMAJOR="${OSMAJOR:-0}"
MACH9_POSSIBLE=0
if [ "$ARCH" = "arm64" ] && ver_ge "$OSVER" "26.4"; then MACH9_POSSIBLE=1; fi

ENGINE=""
case "${SAM6_ENGINE:-}" in
  stable) ENGINE="stable" ;;
  mach9)
    [ "$MACH9_POSSIBLE" = "1" ] || die "Mach9 엔진은 Apple Silicon + macOS 26.4 이상에서만 쓸 수 있습니다. (이 맥: $ARCH, macOS ${OSVER:-?})"
    ENGINE="mach9" ;;
  "") ;;
  *) die "SAM6_ENGINE 값이 올바르지 않습니다: ${SAM6_ENGINE} (stable 또는 mach9)" ;;
esac
if [ -z "$ENGINE" ]; then
  if [ "$MACH9_POSSIBLE" != "1" ]; then
    ENGINE="stable"
  elif [ "$OSMAJOR" -ge 28 ]; then
    ENGINE="mach9"
    echo "  ▶ macOS ${OSVER}: Rosetta 2 제공이 끝난 macOS 라서 Rosetta 가 필요 없는 Mach9 ARM64 엔진을 설치합니다."
    echo
  else
    echo "  ▶ 실행 엔진을 선택하세요."
    echo "    1) 기본 Wine (Rosetta 2 사용, 2026-07부터 검증)  ← Enter"
    echo "    2) Mach9 ARM64 Wine (Rosetta 불필요, macOS 28 대비, 새 엔진)"
    printf "  선택 [1/2] ... "
    read -r choice 2>/dev/null || choice="1"
    case "$choice" in
      2) ENGINE="mach9" ;;
      *) ENGINE="stable" ;;
    esac
    echo
  fi
fi

if [ "$ENGINE" = "stable" ]; then
  [ -f "$AS/wine.tar" ] || die "assets/wine.tar 를 찾을 수 없습니다."
  echo "  · 실행 엔진: 기본 Wine (Wine Stable 11.0, Rosetta 2 사용)"
  ensure_rosetta
else
  echo "  · 실행 엔진: Mach9 ARM64 Wine ($MACH9_VER, Rosetta 불필요)"
fi
echo

# --- 게임 폴더 선택 ---
echo "  ▶ 삼국지6 게임 폴더를 선택하세요 (SAM6.EXE 가 들어있는 폴더)."
GAMEDIR="$(osascript -e 'POSIX path of (choose folder with prompt "삼국지6 게임 폴더(SAM6.EXE가 있는 폴더)를 선택하세요")' 2>/dev/null)"
GAMEDIR="${GAMEDIR%/}"
[ -n "$GAMEDIR" ] || die "게임 폴더 선택이 취소되었습니다."
[ -f "$GAMEDIR/SAM6.EXE" ] || die "선택한 폴더에 SAM6.EXE 가 없습니다: $GAMEDIR"
echo "  · 게임 폴더: $GAMEDIR"
echo

# --- 기존 설정 백업 ---
if [ -d "$PREFIX" ]; then
  BK="$PREFIX.old-$(date +%Y%m%d%H%M%S)"
  echo "  · 기존 Wine 설정 백업 → $(basename "$BK")"
  mv "$PREFIX" "$BK" || die "기존 설정 백업 실패"
fi

# --- 1. Wine 설치 ---
mkdir -p "$ROOT" || die "설치 폴더 생성 실패"

install_stable() {
  [ -f "$AS/wine.tar" ] || die "assets/wine.tar 를 찾을 수 없습니다."
  rm -rf "$ROOT/Mach9"
  rm -rf "$ROOT/Wine Stable.app"
  tar -xf "$AS/wine.tar" -C "$ROOT" || die "Wine 설치 실패"
}

# Mach9: 고정 버전을 내려받아 SHA256 확인 후 설치. 실패하면 1 을 돌려준다.
install_mach9() {
  local tmpf got
  tmpf="$(mktemp -t sam6mach9)" || return 1
  echo "        $MACH9_URL"
  # 연결 20초, 60초 동안 평균 20KB/s 미만이면 중단 → 기본 Wine 으로 대체 설치
  if ! curl -fL -# --retry 2 --connect-timeout 20 --speed-limit 20000 --speed-time 60 -o "$tmpf" "$MACH9_URL"; then
    rm -f "$tmpf"; return 1
  fi
  got="$(shasum -a 256 "$tmpf" | awk '{print $1}')"
  if [ "$got" != "$MACH9_SHA256" ]; then
    echo "  · 내려받은 파일의 SHA256 이 일치하지 않습니다."
    rm -f "$tmpf"; return 1
  fi
  rm -rf "$ROOT/Mach9"
  mkdir -p "$ROOT/Mach9" || { rm -f "$tmpf"; return 1; }
  if ! tar -xJf "$tmpf" -C "$ROOT/Mach9"; then
    rm -f "$tmpf"; rm -rf "$ROOT/Mach9"; return 1
  fi
  rm -f "$tmpf"
  rm -rf "$ROOT/Wine Stable.app"
  return 0
}

if [ "$ENGINE" = "mach9" ]; then
  echo "  [1/5] Mach9 엔진 내려받는 중... (약 130MB, 인터넷 필요)"
  if ! install_mach9; then
    if [ "$OSMAJOR" -lt 28 ]; then
      echo "  ▶ Mach9 엔진을 설치하지 못했습니다. 기본 Wine(Rosetta 2 사용)으로 대신 설치합니다."
      ENGINE="stable"
      ensure_rosetta
      echo "  [1/5] Wine 설치 중... (약 800MB, 잠시 걸립니다)"
      install_stable
    else
      die "Mach9 엔진을 받지 못했습니다 (인터넷 연결 확인)"
    fi
  fi
else
  echo "  [1/5] Wine 설치 중... (약 800MB, 잠시 걸립니다)"
  install_stable
fi

if [ "$ENGINE" = "mach9" ]; then
  ENGINE_BIN_REL="$MACH9_BIN_REL"
  ENGINE_LABEL="mach9 ($MACH9_VER)"
else
  ENGINE_BIN_REL="$STABLE_BIN_REL"
  ENGINE_LABEL="stable (Wine Stable 11.0)"
fi
WINE="$ROOT/$ENGINE_BIN_REL/wine"
WINESERVER="$ROOT/$ENGINE_BIN_REL/wineserver"
[ -x "$WINE" ] || die "Wine 실행 파일을 찾을 수 없습니다."

# --- 2. Wine 설정(prefix) 새로 생성 ---
echo "  [2/5] Wine 설정 초기화 중... (처음이라 20~40초 걸립니다)"
export WINEPREFIX="$PREFIX"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
export LANG="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
"$WINE" wineboot -i >/dev/null 2>&1
"$WINESERVER" -w 2>/dev/null
[ -d "$PREFIX/drive_c/windows/Fonts" ] || die "Wine 설정 생성 실패"

# --- 3. 한글 폰트 설치 ---
echo "  [3/5] 한글 폰트(AppleGothic) 설치 중..."
cp "$APPLEGOTHIC" "$PREFIX/drive_c/windows/Fonts/applegothic.ttf" || die "폰트 복사 실패"
# 툴바 군주 이름("System" 폰트, 한글 charset) 픽스 — 엔진을 고치지 않는 방식.
# Wine 은 코드페이지 949 의 시스템 비트맵 폰트(hvgasys.fon)를 C:\windows\Fonts 에서 먼저 찾으므로,
# 그 이름으로 한글 폰트를 두면 엔진의 한글 없는 hvgasys.fon 대신 이것이 쓰인다.
# (ARM64 엔진처럼 서명돼 수정할 수 없는 엔진에서도 동작. docs/macOS28-대응계획.md 4절)
if [ -f "$SDGOTHIC" ]; then
  cp "$SDGOTHIC" "$PREFIX/drive_c/windows/Fonts/hvgasys.fon" || die "폰트 복사 실패"
else
  echo "  · (참고) Apple SD Gothic Neo 가 없어 툴바 폰트 보조 설정을 건너뜁니다."
fi

# --- 4. 한글/폰트픽스 레지스트리 주입 ---
echo "  [4/5] 한글 설정(폰트 매핑/가상데스크톱) 적용 중..."
for r in "$AS/reg/"*.reg; do
  "$WINE" regedit /S "$r" >/dev/null 2>&1
done
"$WINESERVER" -k 2>/dev/null

# --- 5. 런처 + 바탕화면 아이콘 ---
echo "  [5/5] 실행 런처/아이콘 생성 중..."
LAUNCHER="$ROOT/삼국지6_실행.command"
# Rosetta 확인은 기본 Wine(Intel) 엔진에서만 필요하다. Mach9(ARM64)은 생략.
ROSETTA_CHECK=""
if [ "$ENGINE" = "stable" ]; then
  read -r -d '' ROSETTA_CHECK <<'ROSETTA_EOF' || true
need_rosetta() { [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; }
if need_rosetta; then
  osascript -e 'display dialog "Rosetta 2가 없어 실행할 수 없습니다.\n터미널에서 softwareupdate --install-rosetta 를 실행한 뒤 다시 열어 주세요." with title "삼국지6" with icon caution buttons {"확인"} default button "확인"' >/dev/null 2>&1
  exit 1
fi
ROSETTA_EOF
fi
cat > "$LAUNCHER" <<LAUNCH
#!/bin/bash
# 삼국지6 파워업 키트 실행 (Wine)
# engine: $ENGINE_LABEL
ROOT="\$HOME/Library/Application Support/삼국지6"
WINE="\$ROOT/$ENGINE_BIN_REL/wine"
WINESERVER="\$ROOT/$ENGINE_BIN_REL/wineserver"
export WINEPREFIX="\$HOME/.wine-sam6"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
export LANG="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
$ROSETTA_CHECK
"\$WINESERVER" -k 2>/dev/null
sleep 1
cd "$GAMEDIR"
exec "\$WINE" SAM6.EXE
LAUNCH
chmod +x "$LAUNCHER"

APP="$HOME/Desktop/삼국지6.app"
rm -rf "$APP"
osacompile -o "$APP" -e 'do shell script "nohup \"$HOME/Library/Application Support/삼국지6/삼국지6_실행.command\" >/dev/null 2>&1 &"' >/dev/null 2>&1
if [ -d "$APP" ]; then
  rm -f "$APP/Contents/Resources/Assets.car" 2>/dev/null
  [ -f "$AS/AppIcon.icns" ] && cp "$AS/AppIcon.icns" "$APP/Contents/Resources/applet.icns" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP/Contents/Info.plist" >/dev/null 2>&1
  find "$APP" -print0 | xargs -0 xattr -c >/dev/null 2>&1
  codesign --force --deep -s - "$APP" >/dev/null 2>&1
  touch "$APP"
fi

echo
echo "======================================================"
echo "   ✅ 설치 완료!"
echo "======================================================"
echo
echo "  설치된 실행 엔진: $ENGINE_LABEL"
echo
echo "  바탕화면의 '삼국지6' 아이콘을 더블클릭하면 실행됩니다."
echo "  (게임 시작 시: CD 확인창 → '취소', 초기설정에서 게임 선택)"
echo
echo "  ※ 첫 실행 때 '확인할 수 없는 개발자' 경고가 뜨면"
echo "     삼국지6 앱 마우스 우클릭 → '열기' → '열기' 한 번만."
echo "  ※ 게임 폴더를 나중에 옮기면 이 설치를 다시 실행하세요."
echo
printf "  지금 바로 실행할까요? [Enter=실행 / n 입력 후 Enter=나중에] ... "
read ans 2>/dev/null || ans="n"
if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
  open "$APP" 2>/dev/null || ( "$LAUNCHER" >/dev/null 2>&1 & )
fi
echo
echo "  설치 창은 닫으셔도 됩니다."
