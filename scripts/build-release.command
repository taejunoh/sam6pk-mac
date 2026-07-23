#!/bin/bash
# 배포용 삼국지6-mac.zip 만들기 (repo + wine.tar → 릴리스 zip)
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"   # repo 루트로
REPO="$(pwd)"; NAME="삼국지6-mac"
if [ ! -f "assets/wine.tar" ]; then
  echo "❌ assets/wine.tar 가 없습니다."
  echo "   폰트픽스 Wine을 tar로 만들어 넣으세요:"
  echo '   tar -cf assets/wine.tar -C /Applications "Wine Stable.app"'
  echo "   (자세히: assets/wine.tar.README.txt)"
  exit 1
fi
STAGE="/tmp/${NAME}-stage"; rm -rf "$STAGE"; mkdir -p "$STAGE/$NAME"
rsync -a --exclude '.git' --exclude '.gitignore' --exclude 'scripts' \
      --exclude '*.zip' --exclude '.DS_Store' --exclude 'wine.tar.README.txt' \
      "$REPO/" "$STAGE/$NAME/"
( cd "$STAGE" && ditto -c -k --sequesterRsrc --keepParent "$NAME" "$REPO/${NAME}.zip" )
rm -rf "$STAGE"
echo "✅ ${REPO}/${NAME}.zip 생성 완료 ($(ls -lh "$REPO/${NAME}.zip" | awk '{print $5}'))"
echo "   → GitHub Releases 에 이 zip 을 업로드하세요."
