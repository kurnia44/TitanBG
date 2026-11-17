#!/bin/sh
# TitanBG — bikin zip modul siap flash
# pakai: sh build.sh [folder-tujuan]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-/storage/emulated/0/Download}
VER=$(awk -F= '/^version=/{print $2}' "$HERE/module.prop")
ZIP="$OUT/TitanBG-$VER.zip"
mkdir -p "$OUT"

cd "$HERE"
python3 - "$ZIP" <<'PY'
import os, sys, stat, zipfile

zpath = sys.argv[1]
files = ['module.prop', 'customize.sh', 'service.sh', 'post-fs-data.sh',
         'action.sh', 'uninstall.sh', 'defaults.conf']
trees = ['bin', 'webroot', 'META-INF']

def add(zf, path):
    st = os.stat(path)
    zi = zipfile.ZipInfo(path)
    zi.date_time = (2026, 1, 1, 0, 0, 0)
    mode = 0o755 if (path.endswith('.sh') or '/update-binary' in path) else 0o644
    zi.external_attr = (stat.S_IFREG | mode) << 16
    zi.compress_type = zipfile.ZIP_DEFLATED
    with open(path, 'rb') as fh:
        zf.writestr(zi, fh.read())

if os.path.exists(zpath):
    os.remove(zpath)

with zipfile.ZipFile(zpath, 'w', zipfile.ZIP_DEFLATED) as zf:
    for f in files:
        if os.path.exists(f):
            add(zf, f)
    for root in trees:
        for dirpath, _dirs, names in os.walk(root):
            for n in sorted(names):
                add(zf, os.path.join(dirpath, n))

print('zip  :', zpath)
print('size :', round(os.path.getsize(zpath) / 1024, 1), 'KB')
PY

echo "ok"