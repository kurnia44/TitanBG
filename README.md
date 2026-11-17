# TitanBG

Modul KernelSU / Magisk / APatch untuk **melarang total aplikasi pilihan berjalan di background**,
tapi tetap normal ketika dibuka. Begitu aplikasi ditinggal (atau layar mati), aturan langsung
dipasang lagi.

by eLSanz

## Cara kerja

Tiap aplikasi di daftar ban dapat tiga lapis penjagaan saat tidak dipakai:

| Lapis | Perintah | Efek |
|---|---|---|
| appops | `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore` | proses tidak boleh start/ jalan di background |
| standby bucket | `am set-standby-bucket <pkg> restricted` (+ `deviceidle whitelist -pkg`) | job/alarm/network background ditahan |
| kill | `am force-stop --user 0 <pkg>` (mode hard) / `am kill` (mode soft) | proses dimatikan; force-stop juga memutus jalur FCM sehingga push notification berhenti |

Saat aplikasi jadi foreground, daemon **melonggarkan** aturan (`allow` + bucket `active`) supaya
aplikasi jalan normal. Setelah `grace` detik tidak dipakai, aturan dipasang kembali.

Kenapa perlu force-stop untuk mematikan notifikasi: push FCM dikirim lewat Google Play Services
dan boleh membangunkan proses app (high-priority message) walaupun battery optimization =
restricted. Hanya force-stop yang memutus jalur itu sampai app dibuka manual.

## Mode

- `hard` (default) — force-stop. Background mati total, notifikasi push berhenti.
- `soft` — `am kill` saja. Proses UI mati, tapi push masih bisa membangunkan app.

## Opsi config (`/data/adb/titanbg/config.conf`)

```
enabled=1        master switch
mode=hard        hard | soft
interval=3       detik antar tick daemon
grace=10         detik tunggu setelah app ditinggal sebelum diban
bg_appops=1      blokir background start (appops)
bucket=1         standby bucket restricted + keluarkan dari idle whitelist
screenoff=1      sapu bersih semua app terdaftar saat layar mati
notif_off=0      blokir POST_NOTIFICATION (termasuk saat app dibuka)
fs_boot=0        blokir BOOT_COMPLETED
app.<pkg>=1      aplikasi yang diban
```

Semua bisa diubah dari WebUI, atau lewat CLI:

```sh
sh /data/adb/modules/titanbg/bin/tbg.sh dump
sh /data/adb/modules/titanbg/bin/tbg.sh add com.ss.android.ugc.trill
sh /data/adb/modules/titanbg/bin/tbg.sh apply
sh /data/adb/modules/titanbg/bin/tbg.sh check com.ss.android.ugc.trill
```

## WebUI

Buka dari aplikasi manajer (KernelSU → Modul → TitanBG → Buka WebUI). Fitur:
pilih aplikasi (third-party / system), mode hard/soft, toggle per lapis, daftar ban dengan
status hidup (state · bucket · appops · jumlah proses), checker, dan log daemon.

Nama paket dipakai karena WebUI modul hanya punya shell, tidak punya akses ke label/ikon aplikasi.

## Checker

`check` membaca ulang keadaan sistem, bukan config: standby bucket, appops, jumlah proses,
dan siapa yang sedang foreground. Verdict:

- `BANNED` — appops ignore + bucket restricted (aturan kena)
- `IN_USE` — app sedang dibuka, aturan sengaja dilonggarkan
- `WARN` — terdaftar tapi aturan belum menempel (tekan Terapkan)
- `FAIL` — paket tidak ada / tidak bisa diperiksa

## Uninstall

`uninstall.sh` mengembalikan appops semua app ke `allow` lalu menghapus `/data/adb/titanbg`.
Kalau modul dicabut paksa, jalankan:
`sh /data/adb/modules/titanbg/bin/tbg.sh reset` sebelum reboot.

## Catatan

- Android 11+ wajib. `am set-standby-bucket` dan `cmd appops` butuh root (modul sudah root).
- Aplikasi yang punya widget atau layanan alarm penting (jam, alarm, messenger) jangan dimasukkan.
- Beberapa OEM (Xiaomi/Oppo/vivo) punya jalur push sendiri di luar FCM — mode `hard` tetap
  mematikannya karena proses app dimatikan paksa.