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
#   - 한글 렌더링/가상데스크톱 등 Wine 설정
#   - 실행 런처 + 바탕화면 아이콘
# ============================================================

SELF="$(cd "$(dirname "$0")" && pwd)"
AS="$SELF/assets"
ROOT="$HOME/Library/Application Support/삼국지6"
PREFIX="$HOME/.wine-sam6"
WINE="$ROOT/Wine Stable.app/Contents/Resources/wine/bin/wine"
WINESERVER="$ROOT/Wine Stable.app/Contents/Resources/wine/bin/wineserver"
APPLEGOTHIC="/System/Library/Fonts/Supplemental/AppleGothic.ttf"

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
[ -f "$AS/wine.tar" ]  || die "assets/wine.tar 를 찾을 수 없습니다."
[ -d "$AS/reg" ]       || die "assets/reg 폴더를 찾을 수 없습니다."
[ -f "$APPLEGOTHIC" ]  || die "macOS 한글 폰트(AppleGothic)를 찾을 수 없습니다. macOS가 맞나요?"

# Rosetta 2 확인 (Apple Silicon 전용) — Wine 은 Intel 용이라 Rosetta 가 없으면 실행 자체가 안 됨
need_rosetta() { [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; }
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
echo "  [1/5] Wine 설치 중... (약 800MB, 잠시 걸립니다)"
mkdir -p "$ROOT" || die "설치 폴더 생성 실패"
rm -rf "$ROOT/Wine Stable.app"
tar -xf "$AS/wine.tar" -C "$ROOT" || die "Wine 설치 실패"
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

# --- 4. 한글/폰트픽스 레지스트리 주입 ---
echo "  [4/5] 한글 설정(폰트 매핑/가상데스크톱) 적용 중..."
for r in "$AS/reg/"*.reg; do
  "$WINE" regedit /S "$r" >/dev/null 2>&1
done
"$WINESERVER" -k 2>/dev/null

# --- 5. 런처 + 바탕화면 아이콘 ---
echo "  [5/5] 실행 런처/아이콘 생성 중..."
LAUNCHER="$ROOT/삼국지6_실행.command"
cat > "$LAUNCHER" <<LAUNCH
#!/bin/bash
# 삼국지6 파워업 키트 실행 (Wine)
ROOT="\$HOME/Library/Application Support/삼국지6"
WINE="\$ROOT/Wine Stable.app/Contents/Resources/wine/bin/wine"
WINESERVER="\$ROOT/Wine Stable.app/Contents/Resources/wine/bin/wineserver"
export WINEPREFIX="\$HOME/.wine-sam6"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
export LANG="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
need_rosetta() { [ "\$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; }
if need_rosetta; then
  osascript -e 'display dialog "Rosetta 2가 없어 실행할 수 없습니다.\n터미널에서 softwareupdate --install-rosetta 를 실행한 뒤 다시 열어 주세요." with title "삼국지6" with icon caution buttons {"확인"} default button "확인"' >/dev/null 2>&1
  exit 1
fi
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
