# SIBAL — Sistem Inventaris Barang & Admintrasi Lab

Aplikasi manajemen inventaris laboratorium komputer: spesifikasi PC, barang
pendukung, riwayat perawatan, dan **pengajuan kerusakan dengan alur persetujuan
admin**. Dibangun sebagai satu package Flutter dengan dua target: aplikasi
mobile untuk siswa/pengelola lab, dan panel admin berbasis web.

Proyek portofolio — backend Supabase (PostgreSQL) plan Free, seluruh biaya Rp 0.

## Fitur

**Mobile (siswa / pengelola lab)**
- Beranda: kesiapan lab, prioritas penanganan, aktivitas terkini, broadcast admin.
- Inventaris PC & barang pendukung: spesifikasi, status aset, stok — tetap
  terbaca saat offline (cache lokal baca-saja).
- Pengajuan kerusakan: satu tiket terbuka per aset, konfirmasi tiket existing,
  pembatalan oleh pelapor; dinonaktifkan saat offline.
- Pengajuan saya: lacak status `menunggu → diperiksa/diproses → selesai/ditolak/batal`.
- Profil: edit nama/deskripsi, ganti password, logout dengan konfirmasi.

**Panel admin (Flutter Web)**
- Antrean: periksa → setujui → tolak, dengan pemulihan status aset saat reject.
- Aset: koreksi deskriptif PC/barang, ubah status, penyesuaian stok beralasan.
- Riwayat: selesaikan pekerjaan (delta stok tercatat), buka lagi tiket.
- Broadcast, pengguna (peran & keaktifan), dashboard KPI.

## Arsitektur

- **Local-first, approval workflow.** Pengguna tidak pernah menulis tabel master;
  semua perubahan lewat RPC atomik (`sibal_report_issue`, `sibal_approve_report`,
  `sibal_complete_maintenance`, …) yang diverifikasi `app.resolve_admin()` di server.
- **Supabase PostgreSQL = sumber kebenaran.** RLS + privilege sempit: klien
  `authenticated` hanya SELECT tabel bisnis + UPDATE tiga kolom profil miliknya.
  Signup selalu menghasilkan peran `user` (eskalasi lewat metadata ditutup di `0004`).
- **Hive CE = cache baca-saja**, overwrite penuh saat sinkron; tidak ada antrean
  tulis offline. `connectivity_plus` mengunci form pengajuan saat offline.
- **Login username** dipetakan ke email sintetis `username@sibal.my.id`
  (kembaran SQL `app.email_for_username()` dan `AppEnv.emailDomain`).
- Panel admin **tidak** memakai cache: menyetujui tiket berdasarkan data basi
  adalah kesalahan desain.

## Struktur

```
lib/main.dart               shell mobile (5 tab)
lib/admin_main.dart         shell panel admin (6 tab) — tidak ikut ke APK
lib/core/                   env (--dart-define) + bootstrap Supabase
lib/models/                 enum domain (wire Postgres ↔ label UI) + kelas baris
lib/services/               auth, repository cloud (satu-satunya jalur tulis),
                            cache Hive, connectivity
lib/state/                  AppState mobile
lib/admin/                  halaman + state panel admin
lib/pages/, lib/widgets/    layar mobile + komponen bersama
lib/onboarding/             alur sambutan pertama kali
supabase/migrations/        0001 skema · 0002 RLS/RPC · 0003 seed · 0004 hardening
                            0005 workflow · 0006 RPC admin · 0007 domain email
                            0008 keepalive demo
test/                       cloud_model_test, admin_contract_test
docs/                       mockup UI, peta revisi, diagram perancangan (.drawio)
run.js + *.cmd              launcher yang menyuntikkan --dart-define dari .env
```

## Menjalankan

Prasyarat: Flutter SDK, project Supabase (skema sudah di-apply), file `.env`
(salin dari `.env.example`; berisi `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`
saja untuk klien — jangan pernah memasukkan secret key).

```bash
flutter pub get
# klik dua kali di Windows, atau:
node run.js mobile        # run di perangkat/emulator terhubung
node run.js admin         # panel admin di http://localhost:8080
node run.js mobile-web    # shell mobile di browser http://localhost:8081
node run.js check         # verifikasi .env terbaca
```

Tanpa launcher, sertakan konfigurasi saat compile (nilainya tertanam di binary):

```bash
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_PUBLISHABLE_KEY=<key>
```

Database: `supabase db push --remote="$SUPABASE_DB_URL"` (session pooler,
user `postgres.<ref>`). Seed demo diisi lewat RPC, bukan INSERT mentah, supaya
guard status dan invariant satu tiket terbuka per aset tetap tegak.

## Uji

```bash
flutter analyze
flutter test        # model cloud + kontrak RPC panel admin
```

Verifikasi alur database (RLS, eskalasi hak, report→check→approve→complete,
anti-double-approve, buku stok) dijalankan lewat harness SQL terpisah terhadap
project live — bukan hanya parser.

## Build & distribusi

```bash
node run.js build-mobile   # APK debug, kredensial tertanam
node run.js build-admin    # build/web siap di-host statis
```

APK release untuk demo (ukuran per-ABI):

```bash
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_PUBLISHABLE_KEY=<key>
```

Panel admin adalah file statis setelah build: host di Netlify Drop / Cloudflare
Pages / GitHub Pages (gratis, HTTPS). Tidak ada rahasia di bundle web — hanya
publishable key; penegakan peran tetap di server.

## Catatan operasional

- Project Free Supabase di-pause setelah 7 hari tanpa aktivitas; migration
  `0008_keepalive.sql` memasang job `pg_cron` + `pg_net` harian selama masa demo
  dan berhenti sendiri setelahnya.
- Admin pertama di-bootstrap manual lewat SQL Editor; pengangkatan admin
  berikutnya lewat `sibal_set_user_role` dari panel.
- "Confirm email" di dashboard Supabase harus OFF agar signup mandiri berhasil
  (domain sintetis tidak punya inbox).
