#!/system/bin/sh
# TitanBG — installer info (dipanggil update-binary)
MODDIR=${MODPATH:-${0%/*}}
CFG=/data/adb/titanbg

echo ""
echo "████████╗██╗████████╗ █████╗ ███╗   ██╗██████╗  ██████╗ "
echo "╚══██╔══╝██║╚══██╔══╝██╔══██╗████╗  ██║██╔══██╗██╔════╝ "
echo "   ██║   ██║   ██║   ███████║██╔██╗ ██║██████╔╝██║  ███╗"
echo "   ██║   ██║   ██║   ██╔══██║██║╚██╗██║██╔══██╗██║   ██║"
echo "   ██║   ██║   ██║   ██║  ██║██║ ╚████║██████╔╝╚██████╔╝"
echo "   ╚═╝   ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝ "
echo "  background killer per-app · by eLSanz"
echo ""
echo "· OS      : Android $(getprop ro.build.version.release 2>/dev/null) (SDK $(getprop ro.build.version.sdk 2>/dev/null))"
echo "· Model   : $(getprop ro.product.manufacturer 2>/dev/null) $(getprop ro.product.model 2>/dev/null)"
echo "· Kernel  : $(uname -r 2>/dev/null)"
echo "· Modpath : $MODDIR"
echo ""
echo "· Buka WebUI modul untuk memilih aplikasi."
echo "· Butuh reboot sekali agar service.sh jalan."
echo ""

mkdir -p "$CFG/state" "$CFG/cache/icons" 2>/dev/null
[ -s "$CFG/config.conf" ] || cp -f "$MODDIR/defaults.conf" "$CFG/config.conf" 2>/dev/null

chmod 755 "$MODDIR" 2>/dev/null
chmod 755 "$MODDIR"/*.sh 2>/dev/null
chmod 755 "$MODDIR"/bin/tbg.sh 2>/dev/null
chmod 644 "$MODDIR"/bin/tbgui.dex 2>/dev/null
chmod 644 "$MODDIR/module.prop" "$MODDIR/defaults.conf" 2>/dev/null
chmod 644 "$MODDIR"/webroot/* 2>/dev/null

# matikan daemon + watchdog lama biar versi baru yang jalan
_old=$(cat "$CFG/daemon.pid" 2>/dev/null)
[ -n "$_old" ] && kill "$_old" 2>/dev/null
_gold=$(cat "$CFG/guard.pid" 2>/dev/null)
[ -n "$_gold" ] && kill "$_gold" 2>/dev/null
rm -f "$CFG/daemon.pid" "$CFG/guard.pid" "$CFG/hb" 2>/dev/null

# config lama: tambahkan kunci baru tanpa menyentuh pilihan user
if [ -s "$CFG/config.conf" ]; then
  grep -q '^sweep=' "$CFG/config.conf" 2>/dev/null || printf 'sweep=300\n' >> "$CFG/config.conf"
fi

exit 0