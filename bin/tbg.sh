#!/system/bin/sh
# ============================================================
# TitanBG v1.0 — larang total app berjalan di background
# app tetap normal saat dibuka; begitu ditinggal -> dilarang lagi
# KernelSU / Magisk / APatch  ·  by eLSanz
# ============================================================

case "$0" in
  */*) SELFDIR=$(cd "${0%/*}" 2>/dev/null && pwd) ;;
  *)   SELFDIR=$(pwd) ;;
esac
[ -z "$SELFDIR" ] && SELFDIR=$(pwd)
MODROOT=$(cd "$SELFDIR/.." 2>/dev/null && pwd)
[ -z "$MODROOT" ] && MODROOT=$SELFDIR
[ -f "$MODROOT/module.prop" ] || MODROOT=$SELFDIR
[ -f "$MODROOT/module.prop" ] || MODROOT=/data/adb/modules/titanbg

CFG=${TBG_DIR:-/data/adb/titanbg}
CONF="$CFG/config.conf"
LOG="$CFG/titanbg.log"
STDIR="$CFG/state"
PIDF="$CFG/daemon.pid"
DEF="$MODROOT/defaults.conf"

mkdir -p "$CFG" "$STDIR" 2>/dev/null
if [ ! -s "$CONF" ]; then
  [ -s "$DEF" ] && cp -f "$DEF" "$CONF" 2>/dev/null
fi
if [ ! -s "$CONF" ]; then
  printf 'enabled=1\nmode=hard\ninterval=3\ngrace=10\nbg_appops=1\nbucket=1\nscreenoff=1\nnotif_off=0\nfs_boot=0\n' > "$CONF"
fi

getv() { awk -v k="$1" 'index($0,k"=")==1{sub(/^[^=]*=/,"");print;exit}' "$CONF" 2>/dev/null; }
setv() {
  K="$1" V="$2" awk 'BEGIN{k=ENVIRON["K"];v=ENVIRON["V"];d=0}
    index($0,k"=")==1{if(!d){print k"="v;d=1};next}{print}END{if(!d)print k"="v}' \
    "$CONF" > "$CONF.new" 2>/dev/null && mv "$CONF.new" "$CONF" 2>/dev/null
}
unsetv() {
  K="$1" awk 'BEGIN{k=ENVIRON["K"]} index($0,k"=")==1{next}{print}' \
    "$CONF" > "$CONF.new" 2>/dev/null && mv "$CONF.new" "$CONF" 2>/dev/null
}

# ---- binary resolution -------------------------------------
AM=$(command -v am 2>/dev/null); [ -x "$AM" ] || AM=/system/bin/am
CM=$(command -v cmd 2>/dev/null); [ -x "$CM" ] || CM=/system/bin/cmd
DS=$(command -v dumpsys 2>/dev/null); [ -x "$DS" ] || DS=/system/bin/dumpsys
PM=$(command -v pm 2>/dev/null); [ -x "$PM" ] || PM=/system/bin/pm

now_s() {
  _n=$(date +%s 2>/dev/null)
  case "$_n" in ''|*[!0-9]*) _n=$(cut -d. -f1 /proc/uptime 2>/dev/null) ;; esac
  case "$_n" in ''|*[!0-9]*) _n=0 ;; esac
  printf '%s' "$_n"
}

log() {
  printf '%s %s\n' "$(date '+%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$LOG" 2>/dev/null
  _sz=$(wc -l < "$LOG" 2>/dev/null)
  case "$_sz" in ''|*[!0-9]*) ;; *)
    if [ "$_sz" -gt 400 ]; then
      tail -n 300 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null
    fi ;;
  esac
}

apps_list() { grep '^app\.' "$CONF" 2>/dev/null | sed 's/^app\.//; s/=.*$//' | sed '/^$/d'; }
apps_count() { apps_list | wc -l | tr -d ' '; }

st_get()  { cut -d' ' -f1 "$STDIR/$1" 2>/dev/null; }
st_put()  { printf '%s\n' "$2" > "$STDIR/$1" 2>/dev/null; }
st_del()  { rm -f "$STDIR/$1" 2>/dev/null; }

fg_pkg() {
  _d=$("$DS" activity activities 2>/dev/null | head -80 | grep -m1 -E 'topResumedActivity=|mResumedActivity:')
  [ -z "$_d" ] && _d=$("$DS" window 2>/dev/null | head -60 | grep -m1 -E 'mCurrentFocus|mFocusedApp')
  [ -z "$_d" ] && return 0
  printf '%s' "$_d" | tr ' ' '\n' | grep '/' | head -n 1 | cut -d/ -f1
}

screen_on() {
  _w=$("$DS" power 2>/dev/null | grep -m1 -o 'mWakefulness=[A-Za-z]*' | cut -d= -f2)
  case "$_w" in
    Awake) return 0 ;;
    Asleep|Dozing) return 1 ;;
  esac
  _w=$("$DS" deviceidle 2>/dev/null | grep -m1 -o 'mScreenOn=[a-z]*' | cut -d= -f2)
  case "$_w" in
    true) return 0 ;;
    false) return 1 ;;
  esac
  return 0
}

pkg_installed() {
  _hit=$("$PM" list packages 2>/dev/null | grep -x "package:$1")
  [ -z "$_hit" ] && _hit=$("$CM" package list packages 2>/dev/null | grep -x "package:$1")
  [ -n "$_hit" ]
}

procs_of() {
  ps -A 2>/dev/null | grep -v grep | grep -c "$1"
}

# murah: pidof itu applet native (bukan Java), jauh lebih ringan dari dumpsys
pkg_running() {
  if command -v pidof >/dev/null 2>&1; then
    pidof "$1" >/dev/null 2>&1
    return $?
  fi
  ps -A 2>/dev/null | grep -v grep | grep -q "$1"
}

do_enforce() {
  _p=$1
  if [ "$(getv bg_appops)" != 0 ]; then
    "$CM" appops set "$_p" RUN_ANY_IN_BACKGROUND ignore >/dev/null 2>&1
    "$CM" appops set "$_p" RUN_IN_BACKGROUND ignore >/dev/null 2>&1
  fi
  if [ "$(getv notif_off)" = 1 ]; then
    "$CM" appops set "$_p" POST_NOTIFICATION ignore >/dev/null 2>&1
  fi
  if [ "$(getv bucket)" != 0 ]; then
    "$AM" set-standby-bucket "$_p" restricted >/dev/null 2>&1
    "$CM" deviceidle whitelist -pkg "$_p" >/dev/null 2>&1
  fi
  if [ "$(getv fs_boot)" = 1 ]; then
    "$CM" appops set "$_p" BOOT_COMPLETED ignore >/dev/null 2>&1
  fi
  return 0
}

do_relax() {
  _p=$1
  "$CM" appops set "$_p" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
  "$CM" appops set "$_p" RUN_IN_BACKGROUND allow >/dev/null 2>&1
  if [ "$(getv notif_off)" = 1 ]; then
    "$CM" appops set "$_p" POST_NOTIFICATION allow >/dev/null 2>&1
  fi
  "$AM" set-standby-bucket "$_p" active >/dev/null 2>&1
  return 0
}

do_kill() {
  _p=$1
  case "$(getv mode)" in
    soft) "$AM" kill --user 0 "$_p" >/dev/null 2>&1 ;;
    *)    "$AM" force-stop --user 0 "$_p" >/dev/null 2>&1 ;;
  esac
  return 0
}

# ---------------- commands ----------------------------------

cmd_installed() {
  _flt="-3"
  [ "$1" = all ] && _flt=""
  {
    "$PM" list packages $_flt 2>/dev/null
    [ $? -ne 0 ] && "$CM" package list packages $_flt 2>/dev/null
  } | sed 's/^package://' | sed '/^$/d' | sort
}

cmd_add() {
  _p=$1
  [ -z "$_p" ] && { echo "usage: add <pkg>"; return 1; }
  setv "app.$_p" 1
  log "ADD $_p"
  echo "added=$_p"
}

cmd_del() {
  _p=$1
  [ -z "$_p" ] && { echo "usage: del <pkg>"; return 1; }
  unsetv "app.$_p"
  st_del "$_p"
  do_relax "$_p"
  log "DEL $_p"
  echo "removed=$_p"
}

cmd_toggle() {
  _p=$1
  [ -z "$_p" ] && { echo "usage: toggle <pkg>"; return 1; }
  if grep -q "^app\.$_p=1" "$CONF" 2>/dev/null; then
    cmd_del "$_p"
  else
    cmd_add "$_p"
  fi
}

cmd_apply() {
  _fg=$(fg_pkg)
  _n=0
  for _p in $(apps_list); do
    if [ "$_p" = "$_fg" ]; then
      do_relax "$_p"
      st_put "$_p" inuse
      log "RELAX $_p (foreground/apply)"
    else
      do_enforce "$_p"
      do_kill "$_p"
      st_put "$_p" banned
      log "BAN $_p (apply)"
    fi
    _n=$((_n+1))
  done
  echo "applied=$_n"
  echo "fg=$_fg"
  echo "mode=$(getv mode)"
}

cmd_reset() {
  for _p in $(apps_list); do
    do_relax "$_p"
    st_del "$_p"
  done
  echo "reset=1"
  log "RESET all (appops allow)"
}

cmd_dump() {
  # buang state app yang sudah tidak ada di config
  for _f in "$STDIR"/*; do
    [ -f "$_f" ] || continue
    _b=${_f##*/}
    grep -q "^app\.$_b=1" "$CONF" 2>/dev/null || rm -f "$_f" 2>/dev/null
  done
  echo "rt.version=$(awk -F= '/^version=/{print $2}' "$MODROOT/module.prop" 2>/dev/null)"
  echo "rt.enabled=$(getv enabled)"
  echo "rt.mode=$(getv mode)"
  echo "rt.interval=$(getv interval)"
  echo "rt.grace=$(getv grace)"
  echo "rt.bg_appops=$(getv bg_appops)"
  echo "rt.bucket=$(getv bucket)"
  echo "rt.screenoff=$(getv screenoff)"
  echo "rt.notif_off=$(getv notif_off)"
  echo "rt.fs_boot=$(getv fs_boot)"
  echo "rt.count=$(apps_count)"
  echo "rt.apps=$(apps_list | tr '\n' ',')"
  if _pid=$(cat "$PIDF" 2>/dev/null) && [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
    echo "rt.daemon=running:$_pid"
  else
    echo "rt.daemon=stopped"
  fi
  echo "rt.fg=$(cat "$CFG/fg" 2>/dev/null)"
  echo "rt.screen=$(cat "$CFG/screen" 2>/dev/null)"
  echo "rt.root=$(printf '%s' "$MODROOT")"
  echo "rt.sdk=$(getprop ro.build.version.sdk 2>/dev/null)"
  echo "rt.model=$(getprop ro.product.model 2>/dev/null)"
  grep '^app\.' "$CONF" 2>/dev/null
}

cmd_status() {
  echo "TitanBG $(awk -F= '/^version=/{print $2}' "$MODROOT/module.prop" 2>/dev/null)"
  echo "config   : $CONF"
  echo "enabled  : $(getv enabled)   mode: $(getv mode)   interval: $(getv interval)s   grace: $(getv grace)s"
  echo "daemon   : $(cat "$PIDF" 2>/dev/null || echo '-')"
  echo "foreground: $(cat "$CFG/fg" 2>/dev/null)"
  echo "aplikasi ($(apps_count)):"
  for _p in $(apps_list); do
    echo "  - $_p  [$(st_get "$_p" 2>/dev/null || echo idle)]  procs=$(procs_of "$_p")"
  done
}

bucket_name() {
  case "$1" in
    10) echo active ;;
    20) echo working_set ;;
    30) echo frequent ;;
    40) echo rare ;;
    45) echo restricted ;;
    *)  echo "unknown($1)" ;;
  esac
}

cmd_check() {
  _p=$1
  [ -z "$_p" ] && _p=$(cat "$CFG/fg" 2>/dev/null)
  echo "check.pkg=$_p"
  [ -z "$_p" ] && { echo "check.verdict=FAIL"; echo "check.msg=tidak ada paket target"; return 1; }
  if grep -q "^app\.$_p=1" "$CONF" 2>/dev/null; then echo "check.listed=1"; else echo "check.listed=0"; fi
  if pkg_installed "$_p"; then echo "check.exist=1"; else echo "check.exist=0"; fi

  _b=$("$AM" get-standby-bucket "$_p" 2>/dev/null | tr -dc '0-9')
  echo "check.bucket=$(bucket_name "${_b:-0}")"

  _a=$("$CM" appops get "$_p" RUN_ANY_IN_BACKGROUND 2>/dev/null | sed 's/.*: *//' | tr -d ' \r')
  [ -z "$_a" ] && _a=$("$CM" appops get "$_p" RUN_IN_BACKGROUND 2>/dev/null | sed 's/.*: *//' | tr -d ' \r')
  echo "check.appops=${_a:-unknown}"

  _n=$("$CM" appops get "$_p" POST_NOTIFICATION 2>/dev/null | sed 's/.*: *//' | tr -d ' \r')
  echo "check.notif=${_n:-default}"

  echo "check.procs=$(procs_of "$_p")"
  _fg=$(fg_pkg)
  if [ "$_p" = "$_fg" ]; then echo "check.foreground=1"; else echo "check.foreground=0"; fi
  echo "check.state=$(st_get "$_p" 2>/dev/null || echo idle)"

  if [ "$_p" = "$_fg" ]; then
    echo "check.verdict=IN_USE"
    echo "check.msg=app sedang dibuka, aturan dilonggarkan (normal)"
  else
    case "$_a" in
      ignore)
        if [ "${_b:-0}" = 45 ]; then
          echo "check.verdict=BANNED"
          echo "check.msg=background diblokir total (appops ignore + bucket restricted)"
        else
          echo "check.verdict=WARN"
          echo "check.msg=appops ignore tapi standby bucket belum restricted"
        fi ;;
      *)
        echo "check.verdict=WARN"
        echo "check.msg=aturan belum aktif untuk app ini, tekan Terapkan" ;;
    esac
  fi
}

cmd_states() {
  for _p in $(apps_list); do
    _b=$("$AM" get-standby-bucket "$_p" 2>/dev/null | tr -dc '0-9')
    _a=$("$CM" appops get "$_p" RUN_ANY_IN_BACKGROUND 2>/dev/null | sed 's/.*: *//' | tr -d ' \r')
    echo "s.$_p.state=$(st_get "$_p" 2>/dev/null || echo idle)"
    echo "s.$_p.bucket=$(bucket_name "${_b:-0}")"
    echo "s.$_p.appops=${_a:-unknown}"
    echo "s.$_p.procs=$(procs_of "$_p")"
  done
}

cmd_log() { tail -n 40 "$LOG" 2>/dev/null; }

cmd_screen() {
  if screen_on; then echo "screen=on"; else echo "screen=off"; fi
  echo "fg=$(fg_pkg)"
}

cmd_daemon() {
  _old=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
    echo "daemon already running pid=$_old"
    return 0
  fi
  echo $$ > "$PIDF"
  trap 'rm -f "$PIDF"; log "daemon stopped"; exit 0' TERM INT HUP
  log "daemon start pid=$$"
  _scr_prev=$(cat "$CFG/screen_prev" 2>/dev/null)

  while :; do
    if [ "$(getv enabled)" != 1 ]; then
      sleep 5
      continue
    fi
    _iv=$(getv interval); case "$_iv" in ''|*[!0-9]*) _iv=3 ;; esac
    _gr=$(getv grace);    case "$_gr" in ''|*[!0-9]*) _gr=10 ;; esac

    _apps=$(apps_list)

    # tidak ada app terdaftar -> nol kerja, nol dumpsys
    if [ -z "$_apps" ]; then
      printf 'idle\n' > "$CFG/fg" 2>/dev/null
      sleep 10
      continue
    fi

    # ---- filter termurah: pakai pidof (native). Kalau tidak satu pun app
    #      terdaftar punya proses, tidak ada yang bisa jadi foreground dan
    #      tidak ada yang perlu dibunuh -> dumpsys dilewati sepenuhnya.
    _alive=0
    for _p in $_apps; do
      pkg_running "$_p" && { _alive=1; break; }
    done
    if [ "$_alive" = 0 ]; then
      printf 'none\n' > "$CFG/fg" 2>/dev/null
      for _p in $_apps; do
        [ "$(st_get "$_p")" = banned ] || { do_enforce "$_p"; st_put "$_p" banned; }
      done
      sleep "$_iv"
      continue
    fi

    if screen_on; then _sc=1; else _sc=0; fi
    printf '%s\n' "$_sc" > "$CFG/screen" 2>/dev/null

    # ---- layar mati + sapu bersih: mode hemat, tanpa dumpsys ----
    if [ "$_sc" = 0 ] && [ "$(getv screenoff)" = 1 ]; then
      [ "$_scr_prev" = 1 ] && log "screen off -> purge all"
      _scr_prev=0
      printf 'off\n' > "$CFG/fg" 2>/dev/null
      printf '%s\n' "$_sc" > "$CFG/screen_prev" 2>/dev/null
      for _p in $_apps; do
        if [ "$(procs_of "$_p")" = 0 ]; then
          st_put "$_p" banned
          continue
        fi
        do_enforce "$_p"
        do_kill "$_p"
        st_put "$_p" banned
      done
      sleep "$_iv"; sleep "$_iv"; sleep "$_iv"; sleep "$_iv"
      continue
    fi
    _scr_prev=$_sc
    printf '%s\n' "$_sc" > "$CFG/screen_prev" 2>/dev/null

    _fg=$(fg_pkg)
    printf '%s\n' "$_fg" > "$CFG/fg" 2>/dev/null

    for _p in $_apps; do
      _s=$(st_get "$_p")
      if [ "$_p" = "$_fg" ]; then
        if [ "$_s" != inuse ]; then
          do_relax "$_p"
          st_put "$_p" inuse
          log "RELAX $_p (foreground)"
        fi
      else
        case "$_s" in
          banned) : ;;
          inuse)
            st_put "$_p" "leaving $(now_s)"
            log "LEAVE $_p (grace ${_gr}s)"
            ;;
        esac
        _s=$(st_get "$_p")
        case "$_s" in
          leaving)
            _ts=$(cut -d' ' -f2 "$STDIR/$_p" 2>/dev/null)
            case "$_ts" in ''|*[!0-9]*) _ts=$(now_s) ;; esac
            _now=$(now_s)
            if [ $((_now - _ts)) -ge "$_gr" ]; then
              do_enforce "$_p"
              do_kill "$_p"
              st_put "$_p" banned
              log "BAN $_p (idle >${_gr}s)"
            fi
            ;;
          '')
            # belum pernah dicatat (boot / baru ditambah) -> langsung ban
            do_enforce "$_p"
            st_put "$_p" banned
            log "BAN $_p (init)"
            ;;
        esac
      fi
    done

    sleep "$_iv"
  done
}

usage() {
  cat <<'EOF'
TitanBG CLI
  dump                       status runtime + config (key=value)
  status                     ringkasan manusia
  installed [all]            daftar paket (default: third-party)
  add <pkg> | del <pkg>      masuk/keluar daftar ban
  toggle <pkg>               flip
  apply                      terapkan aturan sekarang
  reset                      longgarkan semua (restore)
  check [pkg]                bukti aturan benar-benar kena
  states                     state/bucket/appops/procs semua app terdaftar
  screen                     status layar + app foreground
  log                        log terakhir
  setk <key> <value>         ubah config
  daemon                     jalankan loop (dipakai service.sh)
EOF
}

case "$1" in
  dump)      cmd_dump ;;
  status)    cmd_status ;;
  installed) cmd_installed "$2" ;;
  add)       cmd_add "$2" ;;
  del)       cmd_del "$2" ;;
  toggle)    cmd_toggle "$2" ;;
  apply)     cmd_apply ;;
  reset)     cmd_reset ;;
  check)     cmd_check "$2" ;;
  states)    cmd_states ;;
  screen)    cmd_screen ;;
  log)       cmd_log ;;
  setk)      setv "$2" "$3"; echo "set=$2" ;;
  unsetk)    unsetv "$2"; echo "unset=$2" ;;
  daemon)    cmd_daemon ;;
  ''|-h|--help|help) usage ;;
  *) echo "unknown command: $1"; usage; exit 1 ;;
esac