# Spesifikasi Arsitektur & Instruksi Proyek — SIBAL

## Stack Teknologi
- **Flutter Mobile** — frontend pengguna (siswa/pengelola lab).
- **Hive CE** — cache/local DB di perangkat (`lib/services/hive_database_service.dart`).
- **Supabase (PostgreSQL)** — cloud DB, sumber kebenaran data. Plan **Free**; database ini
  dipakai untuk tes dan demo tugas, jadi seluruh rencana harus tetap di Rp 0.
- **Flutter Web** — panel admin, **satu package yang sama** dengan target build terpisah
  (`-t lib/admin_main.dart`). Retool **ditinggalkan** (keputusan 2026-11-03).

## Pola Arsitektur
**Local-First / Offline-First** dengan **Approval Workflow**: pengguna tidak pernah menulis ke data master; semua perubahan pengguna masuk antrean pengajuan dan hanya admin yang menyetujui atau mengubah langsung.

## Gaya Komunikasi (wajib)
Hemat konteks: jawaban singkat dan langsung ke inti. Jangan mengulang isi file, menempel ulang
kode yang sudah ada, atau menulis ringkasan langkah yang baru saja dikerjakan. Tanpa pembuka
("Baik, saya akan..."), tanpa penutup yang mengulang. Sebut hanya yang berubah dan apa langkah
berikutnya. Kutip kode hanya bila memang perlu dibahas.

---

## Bagian 1 — Desain & Struktur Database (Supabase Cloud)

Skema **bertipe**, bukan dua tabel generik. Draf awal rencana ini memakai `tabel_utama`
(`nama_data`, `konten_data`) + `tabel_pengajuan` (`data_perubahan` JSONB); itu **sudah
digantikan** karena inventaris lab ini relasional (tiket→PC, stok→barang, riwayat→tiket) dan
panel admin butuh kolom nyata untuk filter/sort.

Implementasi ada di `supabase/migrations/`:

| File | Isi |
| --- | --- |
| `0001_init.sql` | domain enum, tabel, constraint, index |
| `0002_security.sql` | grants, RLS, function atomik, trigger, view, Storage, realtime |
| `0003_seed.sql` | data awal 3 Lab (menggantikan seed dari kode) |
| `0004_hardening.sql` | tutup eskalasi role lewat signup, perbaiki ambiguitas kolom di `sibal_report_issue` |
| `0005_workflow_fixes.sql` | perbaiki alur periksa→approve, pemulihan status saat reject, buku stok di `complete` |
| `0006_admin_rpc.sql` | jalur tulis panel web: `sibal_update_pc`, `sibal_update_supporting_item`, `sibal_upsert_announcement`, `sibal_delete_announcement` + helper `app.text_field` |
| `0007_email_domain.sql` | domain email sintetis dipindah dari `.invalid` ke `.my.id` karena GoTrue menolak signup ber-domain dicadangkan |
| `0008_keepalive.sql` | pg_cron + pg_net menyentuh DB tiap hari supaya project Free tidak di-pause; berhenti sendiri 21 Des |
| `0009_maintenance_crud.sql` | CRUD riwayat mandiri (di luar pengajuan): `sibal_create_maintenance`, `sibal_update_maintenance`, `sibal_delete_maintenance` |

Tabel: `labs`, `profiles`, `pcs`, `supporting_items`, `reports`, `report_witness`,
`maintenance_histories`, `announcements`.

- **`reports` adalah antrean pengajuan.** `status`: `menunggu` → `diperiksa` / `diproses` →
  `selesai`, atau `ditolak`, plus `batal` oleh pelapor. Satu tiket terbuka per aset ditegakkan
  partial unique index.
- **`maintenance_histories` adalah riwayat pekerjaan**; `report_id` boleh NULL untuk inspeksi
  rutin, dan satu tiket hanya boleh punya satu pekerjaan terbuka.
- **Status aset (`asset_status`) bukan teks bebas.** Domain: `baik`, `dalam_pengajuan`,
  `diperiksa`, `rusak`, `habis`, `purnatugas`.
- Semua timestamp `timestamptz`; hanya `maintenance_date` berupa `date` kalender WIB.

---

## Bagian 2 — Implementasi Logika Flutter Mobile & Hive CE

Sisi mobile fokus pada kecepatan akses via lokal (cache), deteksi koneksi, dan pembatasan fitur saat offline.

### Langkah 1: Hive CE sebagai cache lokal
- **Online:** fetch dari Supabase (`pcs`, `supporting_items`, `maintenance_histories`,
  `announcements`, `v_lab_stats`), lalu **overwrite** hasilnya ke Box Hive CE.
- **Offline:** tidak ada request ke cloud. Aplikasi 100% membaca data terakhir dari Box Hive CE.
- Yang di-cache hanya **baca**. Tidak ada antrean tulis offline: pengajuan butuh koneksi.

### Langkah 2: Deteksi koneksi jaringan
Pakai package seperti `connectivity_plus` untuk memantau status internet real-time.

### Langkah 3: Aturan status offline pada UI/UX
- **Offline terdeteksi:**
  - Tampilkan card alert / banner di atas layar, contoh: *"Anda sedang offline. Menampilkan data terakhir. Pengajuan dinonaktifkan."*
  - Kunci (disable) atau sembunyikan tombol/form **"Ajukan Perubahan"**.
- **Online terdeteksi:**
  - Hilangkan banner dan buka kembali tombol pengajuan.

### Langkah 4: Alur pengiriman pengajuan (saat online)
Pengguna **tidak pernah menulis tabel** lewat SDK. Saat tombol "Laporkan Kerusakan" ditekan,
panggil `supabase.rpc('sibal_report_issue', {...})`. Function itu memutuskan tiket baru atau
konfirmasi atas tiket yang sudah terbuka, dan memindahkan status aset ke `dalam_pengajuan`.
Klien tidak punya hak INSERT/UPDATE di `pcs`, `supporting_items`, `reports`, maupun `labs`.

### Struktur klien yang sudah ada (jangan dibuat ulang)

| Berkas | Isi |
| --- | --- |
| `lib/core/app_env.dart` | `--dart-define`, `emailDomain`, `emailForUsername`, bentuk username |
| `lib/core/app_bootstrap.dart` | `Supabase.initialize` untuk kedua shell |
| `lib/models/asset_enums.dart` | domain enum dengan `wire` (label Postgres) + `label` (UI) |
| `lib/models/{row,assets,tickets,people}.dart` | pembaca baris toleran + kelas domain + `toJson` untuk cache |
| `lib/services/auth_service.dart` | login/signup/pemulihan sesi, pesan error diterjemahkan |
| `lib/services/supabase_repository.dart` | **satu-satunya** tempat menyentuh cloud: baca PostgREST, tulis RPC |
| `lib/services/local_cache.dart` | Box Hive baca-saja, overwrite penuh saat sinkron |
| `lib/services/connectivity_service.dart` | `ValueNotifier<bool> online` (non-web) |
| `lib/state/app_state.dart` | daftar + keadaan muat, refresh, fallback cache, submitReport |
| `lib/pages/*.dart`, `lib/widgets/*.dart` | Beranda, PC, Pendukung, Log, Pengajuan Saya, Profil + sheet pengajuan |

`lib/services/hive_database_service.dart` dan model `PCItem`/`SupportItem`/`RepairLog`
**sudah dihapus** — sumber kebenaran sekarang cloud, cache lewat `local_cache.dart`.

---

## Bagian 3 — Panel Admin (Flutter Web, satu package)

**Keputusan 2026-11-03:** panel admin dibangun sebagai target Flutter Web di package yang sama,
bukan Retool. Yang didapat: satu identitas login (tidak ada lagi akun ganda `botan` + email
asli), RLS **berlaku** di jalur admin karena klien membawa JWT Supabase Auth (tidak ada lagi
koneksi role `postgres` dengan BYPASSRLS), tanpa batas plan pihak ketiga, dan model domain tidak
diduplikasi. Yang ditanggung: UI keenam halaman ditulis sendiri dan di-host sendiri — keduanya
tetap Rp 0.

### Struktur & build

```
lib/main.dart                              shell mobile (siswa)   → flutter build apk
lib/admin_main.dart                        shell panel admin      → flutter build web -t lib/admin_main.dart
lib/admin/                                 halaman admin; TIDAK diimpor main.dart → tidak ikut ke APK
lib/models/                                enum status + kelas domain, dipakai berdua
lib/services/supabase_repository.dart      cloud-only, tanpa Hive; dipakai berdua
```

Admin **tidak** memakai cache Hive: panel yang menampilkan data basi adalah panel yang
menyetujui tiket berdasarkan kenyataan yang salah. Kedua target hanya boleh menggendong
`SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (lewat `--dart-define`).

### Langkah 0 — RPC tulis untuk admin (`0006_admin_rpc.sql`, SELESAI & terverifikasi)

`authenticated` hanya punya SELECT atas tabel bisnis (`0002` §3) plus UPDATE tiga kolom
miliknya sendiri di `profiles`. Tanpa empat function berikut, panel web tidak punya jalur sama
sekali untuk Broadcast dan untuk mengoreksi kolom deskriptif aset. Semuanya sudah dibuat,
di-apply, dan diuji 44 assertion lewat jalur klien sungguhan (`set role authenticated` +
`request.jwt.claim.sub`, bukan role `postgres`):

- `sibal_update_pc(p_pc_id, p_processor, p_ram, p_storage, p_gpu, p_mouse_spec, p_keyboard_spec, p_location, p_notes, p_operator_email)`
- `sibal_update_supporting_item(p_supporting_item_id, p_name, p_category, p_specifications, p_unit, p_location, p_notes, p_qty, p_reason, p_operator_email)`
- `sibal_upsert_announcement(p_id, p_title, p_body, p_level, p_is_published, p_expires_at, p_operator_email) → uuid`
- `sibal_delete_announcement(p_id, p_operator_email)`

Tiga hal yang harus diketahui klien saat memanggilnya:

1. **Konvensi kolom teks** (helper `app.text_field`): `null` = jangan ubah, `''` = kosongkan,
   nilai = ditulis (trim). Artinya form Flutter harus mengirim kolom yang memang diubah dan
   `null` untuk yang tidak — bukan mengirim string kosong untuk semuanya.
2. **Stok hanya lewat `p_qty` + `p_reason`.**Delta apa pun tanpa alasan ≥3 karakter ditolak,
   dan setiap delta menulis baris `maintenance_histories` (`pelengkapan` bila masuk, `purnatugas`
   bila keluar, `qty_delta` bertanda). `qty` negatif ditolak.
3. **Keduanya sengaja tidak punya parameter status.** Trigger `trg_pcs_status_guard` hanya
   menyala untuk `update of status`, jadi jalur ini secara struktural tidak bisa mengubah
   status; itu tetap tugas `sibal_set_asset_status`.

Enum yang dipakai adalah `pelengkapan` (bukan *perlengkapan*) — salah satu penyebab tes pertama
gagal, dan bukti aturan "jangan anggap SQL selesai sebelum dieksekusi".
**Jangan** menyelesaikan kebutuhan tulis panel dengan `grant insert/update on <tabel bisnis> to
authenticated`: itu membuka jalur tulis tanpa jejak dan menghapus seluruh alasan function ini ada.

### Halaman (enam) — baca lewat PostgREST, tulis lewat RPC

| Tab | Baca | Aksi (RPC) |
| --- | --- | --- |
| Antrean | `reports` join `labs`/`pcs`/`supporting_items`, filter `status in ('menunggu','diperiksa')`, urut `severity` lalu `created_at` | `sibal_check_report` · `sibal_approve_report` · `sibal_reject_report` |
| Aset | `pcs`, `supporting_items` (admin juga melihat `is_active = false`) | `sibal_update_pc` · `sibal_update_supporting_item` · `sibal_set_asset_status` |
| Riwayat | `maintenance_histories` join `reports` | `sibal_complete_maintenance` · `sibal_reopen_report` |
| Broadcast | `announcements` | `sibal_upsert_announcement` · `sibal_delete_announcement` |
| Pengguna | `public.profiles` | `sibal_set_user_role` · `sibal_set_user_active` |
| Dashboard | `v_lab_stats` + hitungan antrean | — |

Dua aturan alur yang tidak boleh lupa: `p_asset_status` pada **Approve** hanya menerima `rusak`
atau `diperiksa` (kembali `baik` adalah pekerjaan `sibal_complete_maintenance`), dan `p_qty_delta`
bergerak dua kali kalau diisi di Approve **dan** Complete — isi di Approve, biarkan `0` di Complete
kecuali ada barang keluar/masuk tambahan saat penutupan. Periksa lalu Approve adalah urutan normal
dan aman karena approve memakai ulang pekerjaan `tertunda` milik tiket itu.

### Panel sudah ditulis (2026-11-05)

```
lib/admin_main.dart          entrypoint panel (bootstrap → sesi → shell/login)
lib/admin/admin_shell.dart   sidebar enam tab + layar "Anda bukan admin"
lib/admin/admin_login.dart   login username/password, tanpa jalur daftar
lib/admin/admin_state.dart   keadaan data panel; TIDAK mengimpor Hive/AppState
lib/admin/dashboard_page.dart  KPI + tabel v_lab_stats + antrean teratas + pekerjaan terbuka
lib/admin/queue_page.dart    Periksa / Setujui / Tolak / Buka lagi + detail tiket
lib/admin/assets_page.dart   koreksi PC & barang, ubah status, penyesuaian stok
lib/admin/history_page.dart  Selesaikan pekerjaan (delta stok) + buka lagi tiket
lib/admin/broadcast_page.dart buat / ubah / terbit-tarik / hapus pengumuman
lib/admin/users_page.dart    angkat-turunkan peran, aktif-nonaktif akun
lib/admin/widgets/admin_ui.dart  AdminPage, AdminTable, AdminButton, KpiCard, AdminEmpty,
                                 adminDialog, adminFormDialog + AdminForm, runAdminAction,
                                 textFieldValue, qtyIfChanged
```

Yang sudah terbukti: `flutter analyze` bersih, **36 assertion** lolos (14 di antaranya
`test/admin_contract_test.dart` menguji konvensi `null`/`''`, stok absolut, dan daftar
status yang boleh dipilih), dan `flutter build web -t lib/admin_main.dart` berhasil
(41 MB di `build/web`). Artefak hasil build pernah diboot di browser tanpa `--dart-define`
dan hanya menampilkan layar "konfigurasi belum lengkap" — itu jalur yang benar, dan
konsolnya bersih.

Yang **belum** terbukti: panel dijalankan dengan kredensial nyata dan satu siklus aksi
admin (report → check → approve → complete) diklik lewat UI. Kontraknya sendiri sudah
teruji 19 assertion lewat HTTP (`restclient.js`), tapi bukan dari widget.

Tiga keputusan bentuk yang diambil saat menulis panel, supaya tidak "ditemukan ulang"
nanti:

1. **Form selalu mengirim kolom yang diubah saja** lewat `textFieldValue(asli, sekarang)`;
   bedanya "tidak disentuh" dan "dikosongkan" dipertahankan sampai ke RPC.
2. **Dialog tidak menutup sebelum RPC sukses.** `adminFormDialog` menutup hanya bila
   `submit` mengembalikan `true`, jadi isian tidak hilang ketika server menolak.
3. **Stok dua bentuk, dan UI menyebutnya.** Tab Aset mengirim angka **absolut**
   (`p_qty`), tab Riwayat mengirim **delta** (`p_qty_delta` saat penutupan). Hint di
   kedua form mengingatkan bahwa mengisi keduanya menggerakkan stok dua kali.

### Aturan implementasi sisi klien

- **`p_operator_email` tidak perlu dikirim.** Dengan sesi Supabase Auth, `auth.uid()` terisi dan
  `app.resolve_admin()` menuntut `profiles.role = 'admin' and is_active` untuk uid itu; admin palsu
  ditolak di server. Jalur email hanya ada untuk memetakan sesi Retool dan sudah tidak dipakai —
  pertahankan parameternya (default `null`) supaya migration lama tidak diutak-atik.
- **Jangan menyentuh schema `auth`.** Tidak ada `supabase.auth.admin.*` di web: memanggilnya
  menuntut `service_role`/secret key, dan apa pun yang masuk bundle `flutter build web` bisa dibaca
  siapa pun. Daftar pengguna dibaca dari `public.profiles` (policy `profiles_read` sudah
  `using (true)`); konsekuensinya kolom `last_sign_in_at` dan bentuk email tidak tersedia.
- **Membuat akun tetap di luar panel:** signup dari aplikasi mobile (`role` selalu `user`) atau
  dashboard Supabase → Authentication → Add user.
- `status` aset dan `qty` tidak masuk form edit bebas; `target_kind` adalah generated column dan
  jangan pernah masuk daftar kolom INSERT/UPDATE.
- Layar "Anda bukan admin" untuk pengguna non-admin hanyalah kosmetik; penegaknya `resolve_admin`
  + RLS + privilege, dan itu harus tetap diuji dengan akun `user`.

### Empat jebakan SDK yang baru terbukti saat aplikasi dijalankan

Keempatnya lolos `flutter analyze` dan hanya muncul ketika request sungguhan dikirim:

1. **`order()` di postgrest-dart defaultnya DESCENDING** (`ascending = false`), kebalikan dari SQL
   dan postgrest-js. `.order('code')` menghasilkan LAB3→LAB1, `PC-04`→`PC-01`. Semua `order()`
   di `supabase_repository.dart` sekarang menulis `ascending:` secara eksplisit — jangan dihapus.
2. **PostgREST mencocokkan RPC dari nama argumen yang DIKIRIM klien.** Parameter tanpa `DEFAULT`
   yang tidak dikirim membuat panggilan gagal `PGRST202` ("Searched for the function ... with
   parameters ..."), bukan dengan pesan yang jelas. Karena itu `p_id`/`p_title`/`p_body` di
   `sibal_upsert_announcement` diberi default NULL dan panjangnya divalidasi di badan function.
   Aturan turunannya: setiap parameter RPC yang boleh tidak dikirim **wajib** punya default.
3. **RPC `returns void` menjawab 204, bukan 200.** Uji yang mengharapkan 200 akan melaporkan
   kegagalan palsu; terima 200/201/204.
4. **Jangan panggil `refresh()` sebelum login.** Semua tabel bisnis menolak role `anon` dengan 401
   (itu memang benar), jadi menarik data saat belum ada sesi hanya menghasilkan deretan error di
   konsol dan keadaan `error` palsu. `AppState.refresh()` sekarang keluar lebih dulu bila tidak ada
   sesi.

Perubahan function juga perlu memberi tahu cache skema PostgREST: setelah menerapkan SQL di luar
`supabase db push` (mis. lewat harness node), jalankan `notify pgrst, 'reload schema'` — tanpa itu
tanda tangan baru tidak terlihat oleh `/rest/v1/rpc/...`.

### Menjalankan & menyerahkan tanpa biaya

- Development: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 -t lib/admin_main.dart`
  di laptop → panel bisa dibuka dari perangkat lain di jaringan lab. Tidak perlu hosting, tidak
  perlu akun Retool, tidak ada langganan.
- Kalau memang diminta URL publik: `flutter build web -t lib/admin_main.dart` lalu Netlify
  Drop / Cloudflare Pages / GitHub Pages (gratis, HTTPS). Jangan lupa `--dart-define` saat build.
- **Biaya seluruh rencana ini Rp 0.** Yang perlu diwaspadai bukan uang, tapi retensi: project Free
  **di-pause setelah 7 hari tanpa aktivitas database**. Datanya tidak hilang (volume dibekukan) dan
  restore dari dashboard, tapi restore butuh login + internet — cek status project H-1 demo.
  Menyentuh DB (mis. `node C:/Users/Administrator/.qoder/tmp/D--botan/pgtest/sig.js`) setiap
  beberapa hari menggeser jam pause.
- Karena DB hanya untuk tes/demo: **tidak ada migrasi data Hive → cloud** (keputusan terbuka
  #1 terjawab). Perlu `0003_seed.sql` dengan dataset demo yang meyakinkan — tiket di tiap status,
  beberapa riwayat, stok pernah bergerak — atau `supabase/seed_demo.sql` terpisah kalau tidak mau
  migration terisi data palsu.

---

## Bagian 4 — Alur Sinkronisasi Data Akhir (Data Lifecycle)

1. Perubahan data di cloud terjadi karena 2 hal: **pengajuan disetujui admin** atau **admin mengubah langsung via panel admin** (dua-duanya lewat RPC, tidak ada jalur ketiga).
2. Begitu data master berubah, aplikasi Flutter yang online menerima data termutakhir pada request/fetch berikutnya.
3. Flutter menyimpan data baru tersebut ke Hive CE.
4. Ketika perangkat offline, data di Hive CE yang menjadi penyelamat agar pengguna tetap melihat data terbaru sebelum kehilangan koneksi.

---

## Bagian 5 — Batasan yang Harus Dijaga

Aturan ini hasil pembahasan desain dan tidak boleh dilanggar saat implementasi.

- **Hive CE berhenti menjadi sumber kebenaran.** Box Hive hanya cache: write lokal seperti
  `togglePCStatus` (dipakai di `lib/pages/pc_management_page.dart:472-486`) dan `updateSupportQty`
  (`lib/services/hive_database_service.dart:206`) harus digantikan panggilan `sibal_report_issue`.
  Seed lokal `_seedInitialDataIfNeeded` (`lib/services/hive_database_service.dart:41`) dihapus;
  seed yang sah ada di `supabase/migrations/0003_seed.sql`.
- **Approve atomik — sudah diimplementasikan sebagai satu function.** `sibal_approve_report` dan
  `sibal_complete_maintenance` masing-masing satu transaksi: status tiket, status aset, stok, dan
  baris riwayat berubah bersama atau tidak sama sekali. Jangan pernah mengembalikan pola
  "dua RPC beruntun dari klien" — bila panggilan pertama sukses dan kedua gagal, aset berubah tapi
  tiket tetap terbuka dan bisa disetujui ulang.
- **Peran ditegakkan di server, di kedua sisi.** Mobile maupun panel web masuk sebagai role
  `authenticated` dengan JWT Supabase Auth, dan hak tulis atas tabel bisnis nol di lapis privilege
  (kolom `profiles` yang bisa diubah pemiliknya hanya `full_name`, `description`, `avatar_path` —
  itu yang mencegah user menaikkan dirinya jadi admin, bukan policy RLS). Aksi admin juga
  diverifikasi `app.resolve_admin()` di dalam setiap RPC. Satu-satunya jalur yang men-bypass RLS
  adalah SQL Editor/Table Editor dashboard, atas nama manusia, bukan kode.
- **Tidak ada rahasia di bundle web.** `SUPABASE_SECRET_KEY` / `service_role` tidak pernah masuk
  `--dart-define`, kode, atau `assets/`. Yang boleh hanya publishable key.
- **`raw_user_meta_data` adalah input musuh.** `app.handle_new_user()` dulu membaca `role` dari
  sana, padahal field itu datang dari klien lewat `signUp(options.data)` — jadi siapa pun bisa
  mendaftar sebagai admin. Sudah ditutup di `0004_hardening.sql`: signup selalu menghasilkan
  `role = 'user'`. Jangan pernah mengembalikannya.
- **Admin pertama di-bootstrap manual**, karena tidak ada jalur resmi untuk mengangkat diri
  sendiri. Jalankan di SQL Editor dashboard sebagai pemilik database:
  `update public.profiles set role = 'admin' where username = 'namaadmin';`
  Setelah itu admin pertama mengangkat admin lain lewat `sibal_set_user_role`.
- **Login memakai email sintetis:** `lower(username) || '@sibal.my.id'`. Kembarannya ada di dua
  tempat yang harus diubah berbarengan: `app.email_for_username()` di SQL (0002 §2, domain
  dipindah oleh `0007`) dan `AppEnv.emailDomain` di Dart. **Domain `.invalid` tidak bisa dipakai** —
  terbukti lewat percobaan: Supabase Auth menjawab `email_address_invalid` untuk domain dicadangkan
  RFC 2606, jadi pendaftaran mandiri dari aplikasi selalu gagal. Akun lama (`botan`) sudah
  dipindahkan lewat Admin API (`PUT /auth/v1/admin/users/{id}`), bukan UPDATE mentah `auth.users`.
  **Matikan "Confirm email"** di dashboard → Authentication → Providers → Email; selama
  `mailer_autoconfirm = false`, setiap signup mencoba mengirim surat dan berhenti di
  `over_email_send_rate_limit`.
- **Tanggal pakai `timestamptz`**, bukan string ISO hasil `toIso8601String()` seperti model lama.
  Pengecualian yang disengaja: `maintenance_histories.maintenance_date` berupa `date` kalender WIB.
- **Jangan ubah area yang tidak diminta.** Pekerjaan onboarding di `lib/onboarding/` sudah selesai
  dan ter-commit (`46643b8`); perubahan cloud/admin tidak boleh merusaknya.

---

## Bagian 6 — Status Pengerjaan

- **Database sudah berdiri dan terverifikasi.** Project Supabase region `ap-southeast-1`
  (ref & connection string ada di `.env`, tidak di-commit). `0001`–`0006` sudah di-apply lewat
  `supabase db push --remote`. Verifikasi 45 tes alur kerja + 22 tes berbentuk panggilan Retool
  (sudah tidak dipakai, tetap relevan sebagai uji tanda tangan RPC) + **44 tes `0006` lewat jalur
  klien `authenticated`**: RLS untuk `authenticated` dan `anon`, penolakan eskalasi hak, alur
  report → check → approve → complete, anti-double-approve, satu tiket terbuka per aset, pemulihan
  status saat reject/batal, buku stok, guard edit status di luar RPC, konvensi `null`/`''` pada
  `app.text_field`, penolakan stok tanpa alasan, dan penolakan eksekusi oleh `anon` — semuanya lolos.
- **Klaim "database kembali persis seperti seed" pernah ditulis sambil salah.** Dua run ditemukan
  meninggalkan sisa: satu baris `maintenance_histories` dari smoke test sesi sebelumnya, dan
  harness `verify.js` yang selalu menyisakan satu riwayat yatim. Penyebabnya struktural:
  `performed_by ... on delete set null` membuat baris riwayat kehilangan kaitannya begitu pengguna
  tes dihapus, sehingga cleanup berbasis id pengguna tidak lagi menjangkaunya. Harness sekarang
  menyapu `performed_by_name like 'Verif %'` lebih dulu dan membandingkan `qty` total terhadap seed
  (9); dijalankan dua kali berturut-turut, keduanya berakhir persis seperti seed
  (`reports=0, histories=0, announcements=1, profiles=2`). Pelajaran tambahan: klaim kebersihan
  data harus berupa assertion, bukan asumsi.
- **Dua cacat nyata ditemukan hanya karena dijalankan.** `sibal_report_issue` selalu gagal 42702
  (kolom OUT `status` bentrok dengan nama kolom) dan signup bisa meminta `role: 'admin'`. Keduanya
  lolos parser grammar. Yang ketiga menyusul: `0006` menulis kategori `'perlengkapan'` padahal
  enum-nya `'pelengkapan'`, typo yang hanya muncul saat dieksekusi. Pelajarannya tetap sama:
  jangan anggap SQL selesai sebelum dieksekusi.
- **Fondasi + halaman mobile sudah ditulis dan lolos periksa statis.** `flutter analyze` bersih,
  `flutter test` 22 assertion lolos (`test/cloud_model_test.dart`: konvensi login, domain enum,
  round-trip `fromRow ↔ toJson` yang menjaga jalur cache, decoding balasan RPC). Struktur berkas
  didaftar di Bagian 2. Yang **belum terbukti** adalah jalan di perangkat: `flutter run` dengan
  `--dart-define` belum pernah dijalankan, dan uji kontrak lewat HTTP (`restclient.js`) masih
  berhenti di setelan dashboard (lihat butir berikutnya).
- **Dua penemuan dari percobaan nyata di Auth:** (1) domain sintetis `.invalid` ditolak
  `email_address_invalid` saat signup → ditutup dengan `0007_email_domain.sql` dan akun `botan`
  dipindahkan lewat Admin API; (2) `mailer_autoconfirm = false` (Confirm email masih **ON**) membuat
  setiap signup mencoba mengirim surat lalu kena `over_email_send_rate_limit`. Matikan di
  dashboard → Authentication → Sign In / Providers → Email → **Confirm email** sebelum jalur
  pendaftaran mandiri bisa dipakai.
- **Retool ditinggalkan** (lihat Bagian 3). Koneksi pooler-nya sudah teruji dari mesin ini dan
  setelan SSL-nya sudah terpetakan (`*.pooler.supabase.com` ← `Supabase Root 2021 CA`), tapi
  panduan `docs/retool-admin-panduan.md` sekarang **superseded** — dipertahankan hanya sebagai
  catatan bila jalur itu dipakai lagi.
- **Belum dikerjakan:** (a) menjalankan mobile di perangkat/emulator dengan `--dart-define`;
  (b) **verifikasi panel admin di browser dengan kredensial nyata** — kodenya sudah ditulis,
  analyze bersih, build web berhasil, 14 assertion kontrak lolos; yang tersisa menjalankan
  satu siklus report → check → approve → complete lewat UI;
  (c) unggah foto bukti ke Storage (`evidence_paths` sudah ada di skema dan RPC,
  UI-nya sengaja belum, di mobile maupun panel); (d) **revisi UI mobile** mengikuti mockup di
  `docs/design/` (lihat Bagian 7) — lapisan presentasi saja, fondasi data tidak berubah.
  Yang sudah: uji kontrak HTTP `restclient.js` hijau 19/19 lewat jalur klien sungguhan.
- **Urutan kerja yang disepakati**: setup → migration → seed → panel admin → mobile → uji.
  Urutannya dibalik di tengah (user, 2026-11-03): fondasi + halaman mobile lebih dulu, karena
  keduanya memakai `supabase_repository.dart` yang sama dan panel admin tinggal menambah
  enam halaman di atas fondasi yang sudah terbukti. **Selesai:** setup, migration `0001`–`0007`,
  seed, fondasi klien, halaman mobile, panel admin (kode + kontrak teruji). **Berikutnya:**
  menjalankan kedua target dengan `--dart-define` nyata dan menguji satu siklus penuh lewat UI,
  lalu revisi tampilan mobile. Yang masih tertunda dari Langkah 0 plan lama
  adalah uji `Test-NetConnection aws-0-ap-southeast-1.pooler.supabase.com -Port 5432` **dari
  perangkat di lab** — yang terverifikasi sejauh ini hanya egress mesin pengembangan.
- **Database live saat ini kosong untuk demo.** `0003_seed.sql` hanya mengisi `labs`, `pcs`,
  `supporting_items`, dan satu `announcements`; setelah harness pembersih dijalankan,
  `reports = 0` dan `maintenance_histories = 0`. Terbukti lewat `panel_probe.js` (18 assertion
  baca, semuanya lolos — termasuk embed `report_witness(user_id)` dan urutan `severity.desc`).
  Konsekuensinya panel Antrean/Riwayat dan Beranda mobile tampil kosong. Perlu
  `supabase/seed_demo.sql` terpisah yang diisi **lewat RPC** (`sibal_report_issue` →
  `sibal_check_report` → `sibal_approve_report` → `sibal_complete_maintenance`) supaya
  `trg_*_status_guard` dan invariant "satu tiket terbuka per aset" tidak dilanggar oleh
  INSERT mentah.
- **Keputusan terbuka:** admin satu orang atau tim (klaim tiket); dan apakah fitur "pengambilan
  barang oleh user" masih diinginkan (skema sekarang hanya menyiapkan pengajuan kerusakan).
  Yang sudah terjawab: migrasi data lama → **tidak, seed ulang**; platform panel → **Flutter Web**;
  anggaran → **Rp 0, plan Free saja**.

---

## Bagian 7 — Mockup UI mobile (acuan revisi tampilan)

Mockup HTML+PNG dari user (2026-11-05) disimpan di **`docs/design/`** (salinan dari
`D:\assets uiux`): lima layar (`dashboard_sibal_lab`, `unit_pc_sibal_lab`, `inventaris_sibal_lab`,
`pengajuan_riwayat_sibal`, `akun_sibal_lab`) + design system `smart_lab_interface/DESIGN.md`.
Analisis selisih terhadap kode sekarang ada di **`docs/design/PETA-REVISI-UI.md`** — baca itu
sebelum menyentuh lapisan presentasi; dokumen tersebut memuat peta token warna, pemetaan tab
(mockup **5 tab**, shell sekarang 6), komponen baru yang harus dibuat, dan daftar nilai mockup
yang **tidak punya kolom** di skema (kapasitas/foto lab, uptime, estimasi selesai, garansi, nomor
telepon, kategori masalah) sehingga tidak boleh dipalsukan di UI.

Tiga hal yang mengikat saat revisi: (1) mockup adalah acuan **tampilan**, skema Supabase tetap
acuan **data** — nama lab, id tiket, dan semua hitungan harus berasal dari query; (2) revisi ini
murni presentasi, tidak mengubah RPC, RLS, alur approval, maupun `lib/onboarding/`;
(3) palet baru meninggalkan hijau-arang lama (`#0A0F0B`/`#151B17`) ke arang cyan
(`#0F141A`/`#182326`) dengan mint `#58E2C2`, lime `#C1D045`, lilac `#C084FC`, amber `#F59E0B`,
dan font **Inter** yang belum dibundel.

---

## Bagian 8 — Diagram perancangan (UML/ERD)

Diagram yang disiapkan user (2026-11-05) disimpan di **`docs/perancangan/`**: enam PNG
(`png/`) + sumber Mermaid (`.mmd`). **Ketujuh `.mmd` sudah dikoreksi** sehingga sekarang
selaras dengan migration `0001`–`0007` dan kode `lib/` — boleh dipakai sebagai spesifikasi
dan bisa dirender ulang (`npx -y @mermaid-js/mermaid-cli -i erd.mmd -o ERD.png -b dark -s 2`).
PNG-nya masih render versi lama, jadi jangan memverifikasi kolom dari gambar.
`activity_d.png` tidak punya sumber sama sekali.

Yang mengikat tetap `supabase/migrations/0001`–`0007` dan kode di `lib/`. Riwayat
"apa yang dulu salah dan kenapa diperbaiki" didaftarkan di
**`docs/perancangan/CATATAN-REKONSILIASI.md`** — baca itu sebelum mengubah diagram atau
memakainya di laporan. Empat koreksi yang sudah diterapkan: (a) ERD dilengkapi
`report_witness`, `announcements`, `qty`/`unit`, `severity`, `prev_asset_status`, `is_active`,
dan view `v_lab_stats`, dengan `USERS` diganti `profiles`; (b) sequence diagram tidak lagi
menunjukkan **dua langkah tulis** (`INSERT reports` lalu `UPDATE status aset`) yang dilarang —
realitanya satu RPC atomik; (c) kosakata status memakai nilai wire nyata
`menunggu/diperiksa/diproses/selesai/ditolak/batal` dan aset kembali `baik` (bukan `selesai`);
(d) class diagram tidak lagi memuat `InventoryRepository.createPC/deletePC` dan
`AuthService.createUser/deleteUser` yang tidak ada di klien, dan kini memuat
`LocalCache` + `ConnectivityService` + `AppState`.
