#!/system/bin/sh
# TitanBG — Action button: apply + bukti
MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && MODDIR=$(pwd)
BIN="$MODDIR/bin/tbg.sh"
[ -f "$BIN" ] || BIN=/data/adb/modules/titanbg/bin/tbg.sh

echo "░█▀▄░█▀█░█▀▀░█░█░█▀▀░█▀▄░█▀█░█░█░█▀█░█▀▄"
echo "░█▀▄░█▀█░█░░░█▀▄░█░█░█▀▄░█░█░█░█░█░█░█▀▄"
echo "░▀▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀"
echo ""
sh "$BIN" status
echo ""
echo "--- apply ---"
sh "$BIN" apply
echo ""
echo "--- check foreground ---"
sh "$BIN" check
echo ""
echo "--- daemon ---"
sh "$BIN" dump | grep -E '^rt\.(daemon|guard|hb)='
nohup sh "$BIN" guard >/dev/null 2>&1 &
sleep 1
sh "$BIN" dump | grep -E '^rt\.(daemon|guard|hb)='
echo ""
echo "selesai."