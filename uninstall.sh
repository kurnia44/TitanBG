#!/system/bin/sh
# TitanBG — uninstall: longgarkan semua app & bersihkan config
CFG=/data/adb/titanbg
MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && MODDIR=$(pwd)
BIN="$MODDIR/bin/tbg.sh"
[ -f "$BIN" ] && sh "$BIN" reset >/dev/null 2>&1

_pid=$(cat "$CFG/daemon.pid" 2>/dev/null)
[ -n "$_pid" ] && kill "$_pid" 2>/dev/null

rm -rf "$CFG" 2>/dev/null
exit 0