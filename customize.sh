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

mkdir -p "$CFG/state" 2>/dev/null
[ -s "$CFG/config.conf" ] || cp -f "$MODDIR/defaults.conf" "$CFG/config.conf" 2>/dev/null

chmod 755 "$MODDIR" 2>/dev/null
chmod 755 "$MODDIR"/*.sh 2>/dev/null
chmod 755 "$MODDIR"/bin/tbg.sh 2>/dev/null
chmod 644 "$MODDIR/module.prop" "$MODDIR/defaults.conf" 2>/dev/null
chmod 644 "$MODDIR"/webroot/* 2>/dev/null

# matikan daemon lama biar versi baru yang jalan
_old=$(cat "$CFG/daemon.pid" 2>/dev/null)
[ -n "$_old" ] && kill "$_old" 2>/dev/null

exit 0