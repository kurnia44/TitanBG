#!/system/bin/sh
# TitanBG — boot entry
MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && MODDIR=$(pwd)
BIN="$MODDIR/bin/tbg.sh"
[ -f "$BIN" ] || BIN=/data/adb/modules/titanbg/bin/tbg.sh
CFG=/data/adb/titanbg
mkdir -p "$CFG/state" 2>/dev/null

i=0
while [ "$i" -lt 120 ]; do
  [ "$(getprop sys.boot_completed 2>/dev/null)" = 1 ] && break
  sleep 2
  i=$((i+1))
done
sleep 6

# pastikan aturan sudah menempel sejak boot sebelum daemon hidup
sh "$BIN" apply >> "$CFG/titanbg.log" 2>&1

# watchdog (guard) yang menghidupkan daemon; kalau daemon mati/macet
# guard akan menyalakannya lagi dalam <=60 detik (tanpa perlu apply manual)
nohup sh "$BIN" guard >/dev/null 2>&1 &
exit 0