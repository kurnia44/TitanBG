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
sweep=300        detik antar sapu ulang appops/bucket (min 60) — menambal aturan yang di-reset sistem
app.<pkg>=1      aplikasi yang diban
```

Semua bisa diubah dari WebUI, atau lewat CLI:

```sh
sh /data/adb/modules/titanbg/bin/tbg.sh dump
sh /data/adb/modules/titanbg/bin/tbg.sh add com.ss.android.ugc.trill
sh /data/adb/modules/titanbg/bin/tbg.sh bulk add com.a.app com.b.app com.c.app
sh /data/adb/modules/titanbg/bin/tbg.sh apply
sh /data/adb/modules/titanbg/bin/tbg.sh check com.ss.android.ugc.trill
```

## WebUI

Buka dari aplikasi manajer (KernelSU → Modul → TitanBG → Buka WebUI). Tampilan baru:

- banner **SANZ-TITAN**, empat tab bawah (Dasbor · Aplikasi · Ban · Cek), animasi masuk,
  tombol Terapkan mengapung, dan konfirmasi bottom-sheet untuk aksi berbahaya
- daftar aplikasi memakai **ikon dan nama aplikasi asli**, bukan cuma nama paket
- daftar aplikasi maupun daftar ban dibatasi ±10 baris lalu di-scroll, tidak memanjang ke bawah
- pencarian nama/paket, filter Semua · Terpasang · System · Diban, muat bertahap 60 baris
- **pilih banyak dulu, simpan sekali**: ketukan pada aplikasi cuma menandai pilihan (tidak ada
  perintah yang jalan), lalu satu tombol `Simpan N` yang menulis config sekaligus + menerapkan.
  Ada juga `pilih semua (N)` untuk seluruh hasil filter. Ini menghilangkan freeze saat memilih
- halaman dikunci zoom-nya (`user-scalable=no` + gestur pinch/double-tap diblokir), jadi layout
  tidak bisa ikut membesar
- ikon dimuat bertahap: placeholder inisial langsung tampil, ikon asli diambil per batch 16
  hanya untuk baris yang terlihat (IntersectionObserver), plus cache negatif supaya paket tanpa
  ikon tidak diminta berulang
- checker membaca keadaan sistem dan menampilkan verdict + meter (appops/bucket/proses/state)
- log daemon bisa dibuka langsung dari tab Cek

### Ikon dan nama aplikasi

WebUI modul cuma punya shell, jadi label dan ikon diambil lewat helper kecil
`bin/tbgui.dex` yang dijalankan sekali pakai:

```sh
sh /data/adb/modules/titanbg/bin/tbg.sh catalog        # pkg<TAB>label<TAB>s|u
sh /data/adb/modules/titanbg/bin/tbg.sh icons <pkg..>  # base64 webp 72px
```

Helper memanggil `app_process` (bukan daemon, bukan service, bukan Java yang menetap) lalu
langsung keluar. Hasilnya di-cache di `/data/adb/titanbg/cache/` supaya pembukaan berikutnya
tidak perlu memanggil helper lagi — cache otomatis dibuang kalau jumlah paket berubah, atau
manual lewat tombol **muat ulang label** / `recache`.

Kalau helper gagal di perangkat tertentu (ROM aneh, `app_process` diblokir), WebUI tetap jalan:
label jatuh ke nama paket yang dirapikan dan ikon jadi inisial berwarna. Tidak ada fungsi
yang mati.

Sumber helper ada di `src/com/sanz/tbgui/Main.java`, build ulang dengan `sh build-helper.sh`.

## Checker

`check` membaca ulang keadaan sistem, bukan config: standby bucket, appops, jumlah proses,
dan siapa yang sedang foreground. Verdict:

- `BANNED` — appops ignore + bucket restricted (aturan kena)
- `IN_USE` — app sedang dibuka, aturan sengaja dilonggarkan
- `WARN` — terdaftar tapi aturan belum menempel (tekan Terapkan)
- `FAIL` — paket tidak ada / tidak bisa diperiksa

## Konsumsi resource

Daemon-nya cuma satu proses shell (~1.5 MB RSS), tanpa service native, tanpa Java, tanpa `.so`.

Loop sengaja dibuat bertingkat supaya murah:

| Kondisi | Kerja per tick |
|---|---|
| belum ada app terdaftar | tidur 10s, nol perintah |
| app terdaftar tidak punya proses (kasus paling umum) | `pidof` native saja, **nol dumpsys** |
| app terdaftar hidup / sedang dibuka | 1× `dumpsys activity` (+ `dumpsys power`) per `interval` |
| layar mati + `screenoff=1` | tanpa dumpsys, cuma `pidof` + force-stop, tidur 4× `interval` |

`dumpsys` dijalankan lewat `head -80` supaya prosesnya langsung kena SIGPIPE dan mati cepat —
memori puncaknya sementara, tidak menumpuk. Kalau mau lebih hemat lagi, naikkan `interval`
ke 5–8 detik.

## Uninstall

`uninstall.sh` mengembalikan appops semua app ke `allow` lalu menghapus `/data/adb/titanbg`.
Kalau modul dicabut paksa, jalankan:
`sh /data/adb/modules/titanbg/bin/tbg.sh reset` sebelum reboot.

## Ketahanan (kenapa ban tidak "basi")

Tiga pengaman supaya pemblokiran tetap jalan berjam-jam tanpa perlu tekan Terapkan lagi:

1. **Watchdog `guard`** — proses terpisah yang memeriksa daemon tiap 60 detik. Kalau PID-nya mati
   *atau* heartbeat-nya (`/data/adb/titanbg/hb`) basi >300 detik (daemon macet), daemon dibunuh
   lalu dijalankan ulang. Daemon juga menghidupkan `guard` kalau `guard` yang mati.
2. **Timeout semua panggilan sistem** — `dumpsys`/`am`/`cmd` dibungkus `timeout`. Dulu satu
   `dumpsys` yang menggantung = daemon berhenti selamanya tanpa jejak.
3. **Verifikasi ulang state `banned` + sapu berkala** — app yang hidup lagi di background
   (push/alarm/update) diban ulang otomatis dalam ±2 tick; dan tiap `sweep` detik appops +
   standby bucket dipasang ulang untuk menambal yang di-reset sistem. `do_kill` juga memeriksa
   hasil: kalau `am force-stop` gagal, PID dimatikan langsung (`kill -9`) dan state ditandai
   `guard` untuk dicoba lagi.

Cek kesehatan kapan saja: `tbg.sh dump` → `rt.daemon`, `rt.guard`, `rt.hb` (umur heartbeat detik).
Di WebUI, indikator daemon menampilkan umur heartbeat dan menyalakan ulang sendiri kalau mati.

## Catatan

- Android 11+ wajib. `am set-standby-bucket` dan `cmd appops` butuh root (modul sudah root).
- Aplikasi yang punya widget atau layanan alarm penting (jam, alarm, messenger) jangan dimasukkan.
- Beberapa OEM (Xiaomi/Oppo/vivo) punya jalur push sendiri di luar FCM — mode `hard` tetap
  mematikannya karena proses app dimatikan paksa.

## Changelog

### v1.2.1

- **Fix: ban berhenti bekerja setelah beberapa jam.** Penyebabnya tiga: (a) daemon bisa mati
  atau macet tanpa ada yang menyalakan ulang — sekarang ada watchdog `guard` + heartbeat,
  (b) panggilan `dumpsys`/`am`/`cmd` tanpa timeout bisa menggantung dan membekukan loop — sekarang
  semuanya dibungkus `timeout`, (c) state `banned` dulu tidak pernah diperiksa lagi sehingga app
  yang hidup kembali (push/alarm/update) jalan terus sampai user menekan Terapkan — sekarang
  diverifikasi ulang dan diban otomatis (`REBAN`).
- `do_kill` memverifikasi hasil: kalau `am force-stop` tidak mematikan proses, PID dimatikan
  langsung dan state ditandai `guard` untuk dicoba ulang pada tick berikutnya.
- Sapu ulang berkala (`sweep`, default 300 detik) memasang ulang appops + standby bucket untuk
  menambal aturan yang di-reset sistem.
- Perintah baru `ensure` (menyalakan daemon/guard tanpa memblokir) dan `guard`. WebUI menyalakan
  ulang daemon otomatis saat indikatornya mati, plus menampilkan umur heartbeat.
- `apply` / `action.sh` tidak lagi menggantung di panel aksi manajer.

### v1.2.0

- WebUI: pemilihan bertahap — pilih sebanyak apa pun dulu, baru satu aksi `Simpan & terapkan`.
  Tidak ada lagi perintah shell yang jalan tiap ketukan (ini penyebab freeze sebelumnya).
- WebUI: `pilih semua (N)` per filter, tombol `batal` untuk membuang pilihan, indikator
  `N perubahan belum disimpan`, dan konfirmasi sebelum menyimpan.
- WebUI: zoom dimatikan (pinch, double-tap, gesture iOS) — tampilan selalu pas lebar layar.
- WebUI: ikon asli muncul lebih cepat — batch 16 paket sekali panggil, lazy per baris terlihat,
  placeholder langsung tampil, dan cache negatif untuk paket tanpa ikon.
- WebUI: perbaikan bug — chevron daftar ban dibuat dengan `createElementNS` (sebelumnya tidak
  pernah tergambar), detail ban dibaca saat baris dibuka (bukan `states` massal saat load),
  pencarian di-debounce, `probe()` tidak dobel, dan semua panggilan shell punya timeout.
- CLI: perintah baru `bulk add|del <pkg..>` — banyak paket ditulis dalam satu kali tulis config.
- CLI: `apply` membaca config sekali (bukan per app), force-stop hanya untuk app yang benar-benar
  punya proses, log ditulis sekali per apply. `states [pkg..]` menerima daftar paket dan dibatasi
  40 baris. Ikon dikecilkan ke 72px / kualitas 72.
