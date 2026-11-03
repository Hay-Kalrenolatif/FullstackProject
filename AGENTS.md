# Spesifikasi Arsitektur & Instruksi Proyek — SIBAL

## Stack Teknologi
- **Flutter Mobile** — frontend pengguna (siswa/pengelola lab).
- **Hive CE** — cache/local DB di perangkat (`lib/services/hive_database_service.dart`).
- **Supabase (PostgreSQL)** — cloud DB, sumber kebenaran data.
- **Retool** — web admin panel (dibuat tanpa coding UI dari nol).

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
Retool butuh kolom nyata untuk filter/sort.

Implementasi ada di `supabase/migrations/`:

| File | Isi |
| --- | --- |
| `0001_init.sql` | domain enum, tabel, constraint, index |
| `0002_security.sql` | grants, RLS, function atomik, trigger, view, Storage, realtime |
| `0003_seed.sql` | data awal 3 Lab (menggantikan seed dari kode) |
| `0004_hardening.sql` | tutup eskalasi role lewat signup, perbaiki ambiguitas kolom di `sibal_report_issue` |
| `0005_workflow_fixes.sql` | perbaiki alur periksa→approve, pemulihan status saat reject, buku stok di `complete` |

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

---

## Bagian 3 — Konfigurasi & Pembuatan Web Admin (Retool)

Retool dipakai sebagai shortcut pembuatan web admin fungsional dan instan.

### Langkah 1: Hubungkan Supabase ke Retool
Dashboard Retool → `Resources` → `Add Resource` → **PostgreSQL** → connection string
**session pooler, port 5432** (Settings → Database → *Supavisor / Pooler*), bukan `db.<ref>.supabase.co`
(koneksi langsung hanya IPv6) dan bukan port 6543 (transaction mode merusak prepared statement Retool).

**Konsekuensi yang harus disadari:** resource ini berjalan sebagai role `postgres`, yang punya
`BYPASSRLS` dan memiliki semua tabel. Artinya RLS **tidak** membatasi jalur admin. Yang membatasi
admin hanya (a) login + app permission Retool, dan (b) isi function di §B, yang membuka dengan
`app.resolve_admin('{{ currentEmail }}')`. Retool Free juga **tidak** bisa login memakai Supabase
Auth — identitas user Retool dikelola Retool. Jangan pernah memasukkan `service_role` key ke Retool.

### Langkah 2: Halaman/Tab 1 — Konfirmasi pengajuan pengguna
- Tabel Retool: `SELECT * FROM reports WHERE status IN ('menunggu','diperiksa') ORDER BY created_at;`
- Tombol di aksi baris **memanggil function, bukan menulis tabel**:
  - **Periksa** → `SELECT * FROM public.sibal_check_report(p_report_id := {{ id }}, p_operator_email := {{ currentEmail }})`
  - **Approve** → `sibal_approve_report(p_report_id, p_action_taken, p_kind, p_asset_status, p_performed_by, p_qty_delta, p_operator_email)`
  - **Reject** → `sibal_reject_report(p_report_id, p_reason, p_operator_email)`
- Dua aturan yang mudah salah di tab ini:
  - `p_asset_status` pada **Approve** hanya menerima `rusak` atau `diperiksa`. Kembali ke `baik`
    adalah pekerjaan `sibal_complete_maintenance`, bukan approve.
  - `p_qty_delta` bergerak dua kali kalau diisi di keduanya. Isi di Approve untuk keputusan
    stoknya, lalu **biarkan 0** di Complete kecuali ada barang masuk/keluar tambahan saat
    penutupan. `maintenance_histories.qty_delta` menyimpan total keduanya.
- **Periksa lalu Approve** adalah urutan normal dan aman: approve memakai ulang pekerjaan
  `tertunda` milik tiket itu, bukan membuat yang kedua.
- **Input Retool yang kosong harus jadi `null`, bukan string kosong.** `p_performed_by := ''`
  gagal dengan SQLSTATE 22P02 karena kolomnya `uuid`. Untuk setiap parameter uuid/integer yang
  opsional, pakai transformer: `{{ form1.value.performed_by || null }}`. Literal bertanda kutip
  tanpa cast (`p_report_id := '{{ table1.selectedRow.id }}'`) sudah teruji benar — Postgres
  menurunkan tipenya dari tanda tangan function.
- Kolom `status`, `pc_id`, `supporting_item_id`, `target_kind` dibuat **read-only** di grid.
- `target_kind` adalah *generated column*: jangan pernah masukkan ke daftar kolom INSERT,
  termasuk query INSERT yang di-generate otomatis oleh Retool.

### Langkah 3: Halaman/Tab 2 — Modifikasi data langsung
- Tabel Retool terhubung ke `pcs` dan `supporting_items`, **Inline Editing aktif hanya untuk kolom
  deskriptif**: processor, ram, storage, gpu, mouse_spec, keyboard_spec, name, category,
  specifications, location, notes.
- **Status tidak boleh diubah lewat inline edit.** Trigger `app.guard_status_offband()` menolak
  perubahan `status` yang tidak datang dari RPC; gunakan `sibal_set_asset_status(...)` supaya
  perubahannya meninggalkan jejak di `maintenance_histories`.
- Tab lain: `Riwayat` (maintenance_histories + `sibal_complete_maintenance`), `Broadcast`
  (announcements), `Pengguna` (kelola akun lewat Supabase Auth API, bukan tabel `auth`).

---

## Bagian 4 — Alur Sinkronisasi Data Akhir (Data Lifecycle)

1. Perubahan data di cloud terjadi karena 2 hal: **pengajuan disetujui admin** atau **admin mengubah langsung via Retool**.
2. Begitu `tabel_utama` berubah, aplikasi Flutter yang online menerima data termutakhir pada request/fetch berikutnya.
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
  "dua query beruntun di Retool" — bila query pertama sukses dan kedua gagal, aset berubah tapi
  tiket tetap terbuka dan bisa disetujui ulang.
- **Peran ditegakkan di server, dengan satu pengecualian jujur.** Untuk pengguna mobile, hak tulis
  ditutup di lapis privilege (tidak ada INSERT/UPDATE ke tabel bisnis untuk role `authenticated`)
  dan kolom `profiles` yang bisa diubah pemiliknya hanya `full_name`, `description`, `avatar_path`
  — itu yang mencegah user menaikkan dirinya jadi admin, bukan policy RLS. Untuk koneksi Retool,
  role `postgres` men-bypass RLS (lihat Bagian 3 Langkah 1).
- **`raw_user_meta_data` adalah input musuh.** `app.handle_new_user()` dulu membaca `role` dari
  sana, padahal field itu dikirim klien lewat `signUp(options.data)` — jadi siapa pun bisa
  mendaftar sebagai admin. Sudah ditutup di `0004_hardening.sql`: signup selalu menghasilkan
  `role = 'user'`. Jangan pernah mengembalikannya.
- **Admin pertama di-bootstrap manual**, karena tidak ada jalur resmi untuk mengangkat diri
  sendiri. Jalankan di SQL Editor dashboard sebagai pemilik database:
  `update public.profiles set role = 'admin' where username = 'namaadmin';`
  Setelah itu admin pertama mengangkat admin lain lewat `sibal_set_user_role`.
- **Login memakai email sintetis:** `lower(username) || '@sibal.invalid'`. Konfirmasinya ada di dua
  tempat yang harus diubah berbarengan: `app.email_for_username()` di SQL dan
  `lib/services/auth_service.dart` di Dart. Matikan "Confirm email" di dashboard Supabase.
- **Tanggal pakai `timestamptz`**, bukan string ISO hasil `toIso8601String()` seperti model lama.
  Pengecualian yang disengaja: `maintenance_histories.maintenance_date` berupa `date` kalender WIB.
- **Jangan ubah area yang tidak diminta.** Pekerjaan onboarding di `lib/onboarding/` sudah selesai
  dan ter-commit (`46643b8`); perubahan cloud/admin tidak boleh merusaknya.

---

## Bagian 6 — Status Pengerjaan

- **Database sudah berdiri dan terverifikasi.** Project Supabase region `ap-southeast-1`
  (ref & connection string ada di `.env`, tidak di-commit). `0001`–`0005` sudah di-apply lewat
  `supabase db push --remote`. Verifikasi 45 tes: RLS untuk `authenticated` dan `anon`, penolakan
  eskalasi hak, alur report → check → approve → complete, anti-double-approve, satu tiket terbuka
  per aset, pemulihan status saat reject/batal, buku stok, dan guard edit status di luar RPC —
  semuanya lolos, dan data tes sudah dibersihkan sehingga database kembali persis seperti seed.
- **Dua cacat nyata ditemukan hanya karena dijalankan.** `sibal_report_issue` selalu gagal 42702
  (kolom OUT `status` bentrok dengan nama kolom) dan signup bisa meminta `role: 'admin'`. Keduanya
  lolos parser grammar. Pelajarannya: jangan anggap SQL selesai sebelum dieksekusi.
- **Belum:** Retool tersambung dan sisi Flutter. Repo `lib/` masih
  100% Hive CE lokal: `lib/models/pc_item.dart`, `lib/models/support_item.dart`,
  `lib/models/repair_log.dart` dan tiga halaman CRUD di `lib/pages/`. Belum ada `supabase_flutter`
  di `pubspec.yaml`, belum ada login, splash, Broadcast, grouping Lab, atau halaman Profil.
- **Urutan kerja yang disepakati** ada di plan `silent-plateau-mullet.md` Bagian F: Langkah 0
  (setup + uji jalur koneksi dari jaringan lab) → migration → seed → Retool → Flutter → uji.
  **Selesai:** setup, migration, seed. **Berikutnya:** Retool. Yang masih tertunda dari Langkah 0
  adalah uji `Test-NetConnection aws-0-ap-southeast-1.pooler.supabase.com -Port 5432` **dari
  perangkat di lab** — koneksi yang terverifikasi sejauh ini adalah dari mesin pengembangan, dan
  itu belum membuktikan jaringan lab bisa keluar ke internet.
- **Yang masih harus Anda putuskan:** data PC/barang lama dimigrasi atau seed ulang; admin satu
  orang atau tim; dan apakah fitur "pengambilan barang oleh user" masih diinginkan (skema sekarang
  hanya menyiapkan pengajuan kerusakan).
