#!/bin/sh
# TitanBG — compiler helper UI (bukan dijalankan di HP)
# javac + d8 -> bin/tbgui.dex
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
SDK=${ANDROID_HOME:-/opt/android-sdk}
AJAR=$(ls -1 "$SDK"/platforms/*/android.jar 2>/dev/null | tail -n 1)
BT=$(ls -1d "$SDK"/build-tools/*/ 2>/dev/null | tail -n 1)
D8="$BT/d8"

[ -f "$AJAR" ] || { echo "android.jar tidak ketemu (set ANDROID_HOME)"; exit 1; }
[ -x "$D8" ] || { echo "d8 tidak ketemu di $BT"; exit 1; }

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

echo "· javac  : $(javac -version 2>&1)"
echo "· android: $AJAR"
echo "· d8     : $D8"

# javac tidak paham path berspasi -> kerja di temp dir (path bersih)
mkdir -p "$OUT/work"
cp -r "$HERE/src" "$OUT/work/src"
cd "$OUT/work"

find src -name '*.java' -exec javac -source 8 -target 8 -Xlint:-options \
  -bootclasspath "$AJAR" -d "$OUT/work/cls" {} +

mkdir -p "$OUT/dex"
find cls -name '*.class' -exec "$D8" --min-api 21 --release --output "$OUT/dex" {} +

mkdir -p "$HERE/bin"
cp -f "$OUT/dex/classes.dex" "$HERE/bin/tbgui.dex"
chmod 644 "$HERE/bin/tbgui.dex"

SIZE=$(wc -c < "$HERE/bin/tbgui.dex" | tr -d ' ')
echo "· ok     : bin/tbgui.dex ($SIZE byte)"