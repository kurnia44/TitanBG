#!/system/bin/sh
# TitanBG — post-fs-data: siapkan config sedini mungkin
CFG=/data/adb/titanbg
mkdir -p "$CFG/state" 2>/dev/null
MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && MODDIR=$(pwd)
if [ ! -s "$CFG/config.conf" ]; then
  [ -s "$MODDIR/defaults.conf" ] && cp -f "$MODDIR/defaults.conf" "$CFG/config.conf" 2>/dev/null
fi
exit 0