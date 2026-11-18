# Perancangan UML — rekonsiliasi dengan implementasi

Folder ini menyimpan diagram UML/ERD yang disiapkan user (2026-11-05) sebagai acuan
perancangan, **beserta sumber `.mmd`-nya** supaya bisa dirender ulang dan di-diff.
Isi diagram menggambarkan rencana sebelum skema final di-apply. Sebagian masih benar,
sebagian sudah digantikan implementasi. Dokumen ini mencatat mana yang mana, supaya
diagram tidak dibaca sebagai spesifikasi.

## 1. Isi folder dan statusnya

Berikutnya penting: **kode `.mmd` di folder ini sudah dikoreksi** dan sekarang
menggambarkan implementasi nyata (migration 0001–0007 + `lib/`). **PNG-nya masih render
versi lama** — dipakai sebagai catatan sejarah dan contoh visual, bukan sebagai spesifikasi.

| Berkas | Status | Isi |
| --- | --- | --- |
| `erd.mmd` | **dikoreksi** | 8 tabel + `v_lab_stats`, enum, kolom yang dulu hilang |
| `sequence_report_flow.mmd` | **dikoreksi** | satu RPC atomik, jalur saksi, offline, batal, stok |
| `activity_combined_detailed.mmd` | **dikoreksi** | kosakata status wire, cabang stok, buka ulang, offline |
| `class_diagram.mmd` | **dikoreksi** | kelas yang benar-benar ada di `lib/`, tanpa CRUD dan manajemen akun |
| `use_case_diagram.mmd` | **dikoreksi** | use case dipersempit ke aksi ber-RPC, akun dipindah ke aktor dashboard |
| `component_diagram.mmd` | **dikoreksi** | ditambah `LocalCache`, `ConnectivityService`, label "tulis = RPC" |
| `deployment_diagram.mmd` | **dikoreksi** | dua target build, batas dart-define, akses LAN, risiko pause Free |
| `png/ERD.png` | render lama | cocok dengan `erd.mmd` versi sebelum koreksi |
| `png/flowchart.png` | render lama | cocok dengan `activity_combined_detailed.mmd` versi lama |
| `png/usecase.png`, `png/class_d.png`, `png/sequence_d.png` | render lama | sama, versi lama |
| `png/activity_d.png` | render lama, **tanpa sumber** | swimlane 4 partisi; tidak ada `.mmd` untuk ini, termasuk versi lama |

Render ulang PNG dari sumber yang sudah benar (butuh jaringan saat instalasi):

```
npx -y @mermaid-js/mermaid-cli -i erd.mmd -o ERD.png -b dark -s 2
```

`activity_d.png` satu-satunya yang tidak bisa dirender ulang dari folder ini; kalau
masih ada sumbernya di tempat lain, taruh di sini. Sebaliknya,
`component_diagram.mmd` dan `deployment_diagram.mmd` **belum punya PNG** — keduanya
sudah benar secara konsep (lihat §3.6) dan tinggal dirender.

## 2. Aturan membaca

Yang **mengikat** adalah `supabase/migrations/0001`–`0007` dan kode di `lib/`.
Koreksi terhadap keduanya sudah diterapkan **langsung di berkas `.mmd`** folder ini,
jadi `.mmd` boleh dipakai sebagai spesifikasi. §3 di bawah tetap dibiarkan sebagai
daftar "apa yang dulu salah dan kenapa diperbaiki" — berguna untuk laporan dan untuk
menjelaskan keputusan, bukan sebagai daftar pekerjaan yang tertunda. PNG belum
di-render ulang, jadi jangan memverifikasi kolom dari gambar.

## 3. Selisih per diagram

### 3.1 ERD (`erd.mmd`, `ERD.png`)

Benar: 6 entitas inti dan relasi `LABS→PCS`, `LABS→SUPPORTING_ITEMS`,
`USERS→REPORTS`, `PCS/SUPPORTING_ITEMS→REPORTS`, `REPORTS→MAINTENANCE_HISTORIES`.

Yang sudah dikoreksi di `.mmd`:

1. **`USERS` bukan nama tabel.** Yang ada `public.profiles` (PK = `auth.users.id`,
   `on delete cascade`). Kolomnya `avatar_path`, bukan `profile_picture_url`.
2. **`labs` kehilangan `code`** — `code` unik dengan pola `^[A-Z0-9_-]{2,12}$` dan
   justru dipakai UI sebagai label Lab; `name` untuk nama panjang.
3. **`pcs` kehilangan** `codename_norm` (generated, untuk pencarian), `location`,
   `notes`, `is_active`. `status` bukan `text`: enum `asset_status` dengan constraint
   `status <> 'habis'` (habis milik stok, bukan PC).
4. **`supporting_items` kehilangan `qty` dan `unit`** — tanpa keduanya inventaris stok
   tidak ada. Juga `location`, `notes`, `is_active`. `category` = enum
   `support_category`, `status` = enum `asset_status`.
5. **`reports` kehilangan** `lab_id`, `reporter_name` (jejak nama saat pelapor
   berhenti), `prev_asset_status` (dipakai untuk memulihkan status saat
   reject/batal), `severity` (`ringan|sedang|darurat`), `evidence_paths text[]`,
   `reviewed_by`, `decided_at`. `target_type` namanya `target_kind` dan
   **generated column** — jangan pernah masuk daftar INSERT/UPDATE. Constraint nyata:
   tepat satu target (`num_nonnulls(pc_id, supporting_item_id) = 1`) dan
   **partial unique index: satu tiket terbuka per aset**.
6. **`maintenance_histories` kehilangan** `lab_id`, `status`
   (`tertunda|berjalan|selesai|dibatalkan`), `performed_by`, `performed_by_name`,
   `completed_at`, `qty_delta`. `report_id` **nullable** (inspeksi rutin tanpa tiket)
   dengan `on delete set null`. Constraint: `qty_delta = 0` untuk PC, dan
   `status = 'selesai'` wajib `completed_at not null`.
7. **Dua tabel tidak ada di ERD**: `report_witness` (N–N; pengguna lain
   mengonfirmasi tiket yang sudah terbuka — inilah alasan "satu tiket per aset" tidak
   menghasilkan duplikat laporan) dan `announcements` (Broadcast, padahal use case
   UC1 "Melihat Broadcast" ada).
8. **Kardinalitas `REPORTS ||--o| MAINTENANCE_HISTORIES` terlalu ketat.** Satu tiket
   bisa menghasilkan banyak baris riwayat sepanjang waktu (dibuka ulang), tetapi
   partial unique index menjamin **satu pekerjaan terbuka** per tiket. Jadi
   `REPORTS ||--o{ MAINTENANCE_HISTORIES` dengan catatan "≤1 yang belum selesai".
9. **Tidak ada view.** Angka dashboard (kesiapan lab, antrean, pekerjaan berjalan)
   berasal dari `v_lab_stats` (`security_invoker`): `total_pc`, `pc_baik`,
   `pc_butuh_perhatian`, `support_qty`, `support_butuh_perhatian`, `pending_reports`,
   `pekerjaan_berjalan`.

### 3.2 Class diagram (`class_diagram.mmd`, `class_d.png`)

Benar: pemisahan entitas, `RoleGuard`, `AuthService`, dan arah relasi antar model.

Yang sudah dikoreksi di `.mmd`:

1. **`InventoryRepository` dengan `createPC/updatePC/deletePC/createItem/updateItem/
   deleteItem` tidak ada.** Repo nyata satu: `lib/services/supabase_repository.dart`
   (satu-satunya tempat menyentuh cloud). Tulis hanya lewat RPC:
   `sibal_update_pc`, `sibal_update_supporting_item`, `sibal_set_asset_status`.
   **Tidak ada delete** di jalur klien: aset diarsipkan dengan `is_active`, dan
   menambah aset master saat ini lewat dashboard Supabase.
2. **`AuthService.createUser() / resetPassword() / deleteUser()` tidak ada di klien.**
   Ketiganya menuntut `service_role`, yang dilarang masuk bundle web. Pembuatan akun
   = signup dari mobile (role selalu `user`) atau dashboard → Authentication → Add user.
3. **`PC.changeStatus()` dan `SupportingItem.changeStatus()` menyesatkan.** Pengguna
   tidak pernah mengubah status. Status berpindah karena function server:
   `sibal_report_issue` → `dalam_pengajuan`, `sibal_complete_maintenance` → `baik`.
4. **`Report.approve()/check()/reject()`** adalah aksi admin, dan masing-masing
   **satu RPC atomik** (tiket + status aset + stok + riwayat berubah bersama), bukan
   method pada objek klien.
5. **Model nyata tidak tergambar**: `lib/models/{assets,tickets,people,row}.dart`
   memakai enum dengan pasangan `wire` (label Postgres, satu-satunya yang boleh
   dikirim ke RPC) dan `label` (UI). `StorageService.uploadProfilePicture` memang
   sudah ada bucket-nya (`avatars` publik, `report-evidence` privat) tapi **UI-nya
   sengaja belum dibuat**.
6. **Hilang tiga komponen penting**: `LocalCache` (Hive CE, Box `sibal_cache_*`,
   overwrite penuh, baca-saja), `ConnectivityService` (`ValueNotifier<bool> online`),
   dan `AppState` (daftar + keadaan muat + fallback cache). Tanpa ketiganya sifat
   local-first/offline-read sistem tidak terlihat.

### 3.3 Sequence diagram (`sequence_report_flow.mmd`, `sequence_d.png`)

Ini yang paling perlu diluruskan, karena menggambarkan pola yang **dilarang** di
proyek:

1. `M->>D: INSERT reports` **lalu** `M->>D: UPDATE status aset` = dua langkah.
   Kenyataannya satu panggilan `sibal_report_issue(...)`; function itu juga yang
   memutuskan tiket baru atau menambah saksi pada tiket terbuka, dan menolak
   pengajuan ganda. Pola dua-RPC-beruntun pernah ada dan sudah dihapus karena bila
   panggilan pertama sukses dan kedua gagal, aset berubah tapi tiket tetap terbuka.
2. `W->>D: UPDATE reports.status dan admin_notes` **lalu** `W->>D: INSERT
   maintenance_histories` = juga dua langkah. Kenyataannya `sibal_approve_report`
   atomik, dan penutupan pekerjaan lewat `sibal_complete_maintenance` (atomik,
   termasuk buku stok `qty_delta`).
3. **Tidak ada cabang `batal`** (`sibal_cancel_report`, hanya pemilik, hanya selama
   tiket terbuka, status aset dipulihkan ke `prev_asset_status`) dan **tidak ada
   cabang `ditolak`** yang memulihkan status.
4. `D-->>W: Data laporan baru tersedia` mengesankan push realtime ke panel.
   Sisi database memang siap (`0002` §10 menambahkan `reports`,
   `maintenance_histories`, `announcements`, `pcs` ke publication
   `supabase_realtime`), tapi **belum ada satu pun klien yang berlangganan** —
   `supabase_repository.dart` hanya menarik data saat `AppState.refresh()`.
   Jadi anak panah itu menggambarkan kemampuan, bukan perilaku yang berjalan.

### 3.4 Activity diagram (`flowchart.png`, `activity_d.png`)

Alur dan cabang keputusan sudah benar (login → role=admin? → tinjau → Check/Approve/
Reject → perbaikan selesai? → simpan riwayat → user melihat riwayat).
`activity_d.png` bahkan sudah memuat jalur **"pemeriksaan rutin tanpa pengajuan"** —
itu memang sesuai skema (`report_id` NULL).

Yang sudah dikoreksi di `.mmd`:

1. **Kosakata status.** Diagram memakai `Check`, `Approved`, `Rejected` dan
   "status aset menjadi Selesai". Nilai wire nyata: `menunggu → diperiksa / diproses
   → selesai`, `ditolak`, `batal`; dan status aset **kembali `baik`** — `selesai`
   bukan anggota `asset_status`.
2. **Approve tidak bebas.** `p_asset_status` hanya menerima `rusak` atau `diperiksa`.
3. **Cabang stok belum ada.** Perubahan jumlah barang menuntut `p_qty_delta` +
   alasan ≥3 karakter dan menulis riwayat kategori `pelengkapan` (masuk) /
   `purnatugas` (keluar). Delta diisi di Approve **atau** Complete, tidak keduanya.
4. **Cabang offline belum ada.** Saat offline pengajuan dikunci dan data dibaca dari
   cache — itu perilaku nyata yang layak masuk diagram aktivitas.

### 3.5 Use case (`use_case_diagram.mmd`, `usecase.png`)

Benar: dua aktor manusia + dua aktor sistem, `include` ke "Memvalidasi Kredensial"
dan "Menyimpan Data Sistem", dan judul subgraph sudah menyebut *Flutter Mobile &
Flutter Web* (bukan Retool).

Yang sudah ditambahkan / dipersempit di `.mmd`:

1. **UC14 "Mengelola PC" dan UC15 "Mengelola Barang Pendukung"** terlalu luas.
   Persempit jadi tiga use case: *mengoreksi spesifikasi*, *mengubah status aset*,
   *menyesuaikan stok dengan alasan*.
2. **UC18 "Mengelola Pengguna" tidak mencakup create/reset password/delete.**
   Yang ada di panel: *mengangkat/menurunkan role* dan *menonaktifkan akun*.
3. **Belum ada use case pengguna**: *membatalkan pengajuan sendiri* dan
   *mengonfirmasi tiket kerusakan milik orang lain (saksi)*. Keduanya fitur nyata.
4. UC1 "Melihat Broadcast" benar, tapi entitas `announcements` hilang di ERD —
   tambahkan agar konsisten.

### 3.6 Component & deployment (`component_diagram.mmd`, `deployment_diagram.mmd`)

Keduanya sudah paling dekat dengan kenyataan (satu codebase, shared core, dua build
target, Supabase Auth/Postgres/Storage/Realtime, RLS di dalam cloud).

Yang sudah ditambah di `.mmd`:

1. Component mobile belum menampilkan **`LocalCache (Hive CE)`** dan
   **`Connectivity`**; dan `REPO → SUPA → DB` perlu catatan "tulis hanya lewat RPC".
2. `GUARD["Role Guard: Admin Only"]` harus diberi catatan: yang menegakkan adalah
   **server** (privilege + RLS + `app.resolve_admin()`), guard di UI hanya kosmetik.
3. Deployment belum menyebut dua hal operasional: panel dibangun dengan
   `flutter build web -t lib/admin_main.dart` dan di-host statis (atau cukup
   `flutter run -d web-server` di laptop pada jaringan lab), serta project Supabase
   Free `ap-southeast-1` yang **di-pause setelah 7 hari tanpa aktivitas**.

## 4. Ringkasan untuk laporan/tugas

Ketujuh berkas `.mmd` sudah diperbaiki dan boleh dipakai sebagai spesifikasi. Yang
tersisa hanya kosmetik: render ulang PNG dari sumber baru (enam gambar), dan
`activity_d.png` perlu sumbernya kalau masih ada — kalau tidak, hapus saja atau
biarkan sebagai varian lama.

Urutan koreksi yang sudah diterapkan, kalau perlu diceritakan di laporan:
ERD (kolom + `report_witness` + `announcements` + `v_lab_stats`) → sequence (dua
langkah tulis digabung jadi satu RPC atomik, tambah jalur saksi/batal/offline/stok) →
activity (kosakata status wire, cabang stok dan buka ulang) → class (buang CRUD dan
metode manajemen akun, tambah lapisan cache dan konektivitas) → use case (persempit
"mengelola", pindahkan create/reset/delete akun ke aktor dashboard) → component dan
deployment (cache lokal, label "tulis = RPC", dua target build, risiko pause Free).
