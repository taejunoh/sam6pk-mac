#!/bin/bash
# ============================================================
#  삼국지6 파워업 키트 — macOS 호환성 점검 (읽기 전용 진단)
#
#  macOS 28 베타(또는 아무 macOS)에서 지금의 "Rosetta + Wine" 경로가
#  아직 동작하는지 확인합니다.
#
#  - 아무것도 설치하지 않고, sudo 도 쓰지 않습니다.
#  - ~/.wine-sam6 와 게임 폴더는 건드리지 않습니다 (임시 prefix 사용 후 삭제).
#  - 전체 출력은 바탕화면에 txt 로 저장됩니다.
#
#  사용법: 더블클릭, 또는  scripts/macos28-check.command [Wine 폴더 경로]
#          (Wine 폴더 경로 = .../Wine Stable.app/Contents/Resources/wine,
#           환경변수 SAM6_WINE_DIR 로도 지정 가능)
# ============================================================

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/Desktop/삼국지6-macos28-check-$STAMP.txt"
DEFAULT_W="$HOME/Library/Application Support/삼국지6/Wine Stable.app/Contents/Resources/wine"
W="${1:-${SAM6_WINE_DIR:-$DEFAULT_W}}"

exec > >(tee "$LOG") 2>&1

SUMMARY=()
R3="SKIP"; R5="SKIP"; R6="SKIP"
TMPD=""

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; }
info() { echo "  [INFO] $1"; }
skip() { echo "  [SKIP] $1"; }
add()  { SUMMARY+=("$1"); }

# 포터블 타임아웃 (macOS 에는 timeout 이 기본 제공되지 않음): run_to <초> <명령...>
run_to() { local t="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$t" "$@"; }

cleanup() { [ -n "$TMPD" ] && [ -d "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT

echo "======================================================"
echo "   삼국지6 파워업 키트  —  macOS 호환성 점검"
echo "======================================================"
echo "  (읽기 전용: 설치/수정/sudo 없음)"
echo "  결과 저장 위치: $LOG"
echo

# --- 1. 환경 ---
echo "  ▶ 1. 환경"
ARCH="$(uname -m)"
info "macOS $(sw_vers -productVersion 2>/dev/null) (빌드 $(sw_vers -buildVersion 2>/dev/null)), CPU: $ARCH"
add "[INFO] 1. 환경: macOS $(sw_vers -productVersion 2>/dev/null) / $(sw_vers -buildVersion 2>/dev/null) / $ARCH"
echo

# --- 2. Rosetta 패키지/데몬 (참고용) ---
echo "  ▶ 2. Rosetta 패키지/데몬 (참고용)"
PKGS="$(pkgutil --pkgs 2>/dev/null | grep -i rosetta)"
if [ -n "$PKGS" ]; then
  info "Rosetta 관련 패키지:"
  echo "$PKGS" | sed 's/^/           /'
else
  info "Rosetta 관련 패키지 없음 (pkgutil)"
fi
if [ -e /usr/libexec/rosetta/oahd ]; then
  info "/usr/libexec/rosetta/oahd 있음"
else
  info "/usr/libexec/rosetta/oahd 없음"
fi
if [ -d /Library/Apple/usr/libexec/oah ]; then
  info "/Library/Apple/usr/libexec/oah/ 내용:"
  ls -la /Library/Apple/usr/libexec/oah/ 2>&1 | sed 's/^/           /'
else
  info "/Library/Apple/usr/libexec/oah/ 없음"
fi
OAHD="$(pgrep -lf oahd 2>/dev/null)"
if [ -n "$OAHD" ]; then
  info "oahd 프로세스 실행 중: $OAHD"
else
  info "oahd 프로세스 없음 (필요할 때 자동으로 뜨므로 정상일 수 있음)"
fi
if [ -e /Library/Apple/usr/libexec/oah/RosettaLinux ]; then
  info "RosettaLinux 있음 (Linux VM용 Rosetta 존속)"
else
  info "RosettaLinux 없음 (Linux VM용 Rosetta 없음/제거됨)"
fi
add "[INFO] 2. Rosetta 패키지: $([ -n "$PKGS" ] && echo 있음 || echo 없음), oahd 바이너리: $([ -e /usr/libexec/rosetta/oahd ] && echo 있음 || echo 없음), RosettaLinux: $([ -e /Library/Apple/usr/libexec/oah/RosettaLinux ] && echo 있음 || echo 없음)"
echo

# --- 3. 일반 x86_64 실행 ---
echo "  ▶ 3. 일반 x86_64 실행 (arch -x86_64 /usr/bin/true)"
if [ "$ARCH" = "x86_64" ]; then
  skip "Intel 맥이라 Rosetta 가 필요 없습니다."
  add "[SKIP] 3. x86_64 실행: Intel 맥 (Rosetta 불필요)"
else
  if arch -x86_64 /usr/bin/true 2>/dev/null; then
    pass "x86_64 바이너리를 실행할 수 있습니다 (Rosetta 동작)."
    R3="PASS"
    add "[PASS] 3. x86_64 실행"
  else
    fail "x86_64 바이너리를 실행하지 못했습니다."
    R3="FAIL"
    add "[FAIL] 3. x86_64 실행 (단독으로는 결정적이지 않음 — 5번이 최종 판정)"
  fi
  info "※ 이 항목 하나만 FAIL 이라고 끝난 것은 아닙니다. 시스템 바이너리에서 x86_64 슬라이스가"
  info "   빠졌을 수도 있으므로, 실제 Wine 엔진을 돌려 보는 5번이 최종 판정입니다."
fi
echo

# --- 4. softwareupdate --install-rosetta 옵션 존재 여부 ---
echo "  ▶ 4. softwareupdate 의 Rosetta 설치 옵션 (실행하지 않고 존재만 확인)"
if softwareupdate --help 2>&1 | grep -i -- --install-rosetta >/dev/null 2>&1; then
  info "--install-rosetta 옵션이 아직 있습니다."
  add "[INFO] 4. softwareupdate --install-rosetta: 있음"
else
  info "--install-rosetta 옵션이 보이지 않습니다 (Rosetta 설치 경로가 바뀌었을 수 있음)."
  add "[INFO] 4. softwareupdate --install-rosetta: 없음"
fi
echo

# --- 5. Wine 엔진 (최종 판정) ---
echo "  ▶ 5. Wine 엔진 실행 (최종 판정)"
info "엔진 경로: $W"
if [ ! -x "$W/bin/wine" ]; then
  skip "Wine 엔진을 찾을 수 없어 건너뜁니다. 설치.command 로 먼저 설치하거나, 경로를 인자/SAM6_WINE_DIR 로 지정하세요."
  add "[SKIP] 5. Wine 엔진: 찾을 수 없음"
  add "[SKIP] 6. Wine 실제 기동: 엔진 없음"
else
  FILEINFO="$(file "$W/bin/wine" 2>&1)"
  info "file: ${FILEINFO#*: }"
  VER_OUT="$(run_to 20 "$W/bin/wine" --version 2>&1)"
  VER_RC=$?
  case "$VER_OUT" in
    wine-*)
      pass "wine --version → $(echo "$VER_OUT" | head -1)"
      R5="PASS"
      add "[PASS] 5. Wine 엔진 실행: $(echo "$VER_OUT" | head -1)"
      ;;
    *)
      fail "wine --version 실패 (종료코드 $VER_RC, 20초 제한)"
      echo "$VER_OUT" | head -10 | sed 's/^/           /'
      R5="FAIL"
      add "[FAIL] 5. Wine 엔진 실행: $(echo "$VER_OUT" | head -1)"
      ;;
  esac
  echo

  # --- 6. Wine 실제 기동 (임시 prefix) ---
  echo "  ▶ 6. Wine 실제 기동 (임시 prefix, 기존 ~/.wine-sam6 는 건드리지 않음)"
  if [ "$R5" != "PASS" ]; then
    skip "5번이 통과하지 못해 건너뜁니다."
    add "[SKIP] 6. Wine 실제 기동: 5번 실패로 생략"
  else
    TMPD="$(mktemp -d)"
    export WINEPREFIX="$TMPD/pfx"
    info "임시 prefix 생성 중 (첫 기동은 시간이 걸립니다. 최대 120초) ..."
    RUN_OUT="$(WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=d" run_to 120 "$W/bin/wine" cmd /c echo SAM6_OK 2>&1)"
    RUN_RC=$?
    if echo "$RUN_OUT" | grep -q SAM6_OK; then
      pass "Wine 이 임시 prefix 를 만들고 명령을 실행했습니다 (SAM6_OK)."
      R6="PASS"
      add "[PASS] 6. Wine 실제 기동"
    else
      fail "Wine 기동 실패 (종료코드 $RUN_RC, 120초 제한)"
      echo "$RUN_OUT" | tail -15 | sed 's/^/           /'
      R6="FAIL"
      add "[FAIL] 6. Wine 실제 기동: $(echo "$RUN_OUT" | tail -1)"
    fi
    WINEPREFIX="$TMPD/pfx" "$W/bin/wineserver" -k >/dev/null 2>&1
    sleep 1
    cleanup
    TMPD=""
    unset WINEPREFIX
    info "임시 prefix 정리 완료"
  fi
fi
echo

# --- 7. 로그 힌트 ---
echo "  ▶ 7. 시스템 로그 힌트 (최근 5분, oahd / rosetta 관련)"
LOGHINT="$(log show --last 5m --style compact --predicate 'process == "oahd" OR eventMessage CONTAINS[c] "rosetta"' 2>/dev/null | tail -20)"
if [ -n "$LOGHINT" ]; then
  info "관련 로그 (마지막 20줄):"
  echo "$LOGHINT" | sed 's/^/           /'
else
  info "관련 로그 없음 (비어 있을 수 있음)"
fi
echo

# --- 요약 ---
echo "======================================================"
echo "   요약"
echo "======================================================"
for line in "${SUMMARY[@]}"; do
  echo "  $line"
done
echo

# --- 8. 마지막 안내 ---
echo "  ▶ 8. 결론"
if [ "$R5" = "PASS" ] && [ "$R6" = "PASS" ]; then
  echo "  현재 Wine 경로가 이 macOS에서 동작합니다. 게임을 실제로 켜서 전투/한글을 확인하세요 (docs/macOS28-체크리스트.md)"
elif [ "$R5" = "SKIP" ]; then
  echo "  Wine 엔진을 찾지 못해 최종 판정을 하지 못했습니다. 엔진 경로를 인자로 주고 다시 실행하세요."
else
  echo "  현재 Wine 경로가 이 macOS에서 동작하지 않습니다. docs/macOS28-대응계획.md 의 ARM64 엔진 경로를 참고하세요."
fi
echo
echo "  전체 출력 저장됨: $LOG"
echo
sleep 1
printf "  [Enter]를 눌러 닫기 ... "
read _ 2>/dev/null || true
