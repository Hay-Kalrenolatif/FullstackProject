# Peta Revisi UI Mobile — dari mockup `docs/design/` ke Flutter

Dokumen ini adalah **persiapan revisi**, bukan pekerjaan yang sudah dilakukan. Isinya: apa yang
ada di mockup, apa yang sudah ada di kode sekarang, dan selisih yang harus dikerjakan.
Mockup adalah acuan **tampilan**; skema Supabase tetap acuan **data**. Bila mockup menampilkan
nilai yang tidak ada kolomnya, nilai itu tidak boleh dipalsukan di UI (lihat §7).

## 1. Sumber

Salinan mockup asli (`D:\assets uiux`) sudah masuk repo supaya tidak hilang bila folder luar
dipindah/dihapus:

| Layar | Berkas | Pratinjau |
| --- | --- | --- |
| Dashboard | `dashboard_sibal_lab/code.html` | `dashboard_sibal_lab/screen.png` |
| Unit PC | `unit_pc_sibal_lab/code.html` | `unit_pc_sibal_lab/screen.png` |
| Inventaris | `inventaris_sibal_lab/code.html` | `inventaris_sibal_lab/screen.png` |
| Pengajuan + Riwayat | `pengajuan_riwayat_sibal/code.html` | `pengajuan_riwayat_sibal/screen.png` |
| Akun | `akun_sibal_lab/code.html` | `akun_sibal_lab/screen.png` |
| Design system | `smart_lab_interface/DESIGN.md` | — |

Buka `code.html` di browser untuk melihat keadaan interaktif (chip, sheet, toast sudah ada JS-nya).
Semua layar memakai **Material Symbols Outlined** + **Inter** + Tailwind CDN, satu layar per berkas
(tidak ada frame berdampingan; modal/toast/empty state disembunyikan lewat `hidden`).

## 2. Navigasi: 5 tab, bukan 6

Mockup memakai dock bawah 5 tab: **Dashboard · Unit PC · Inventaris · Pengajuan · Akun**
(ikon `dashboard`, `desktop_windows`, `inventory_2`, `build`, `person`; tab aktif = warna mint,
dua layar menambah glow `0 0 16px rgba(88,226,194,.25)`).

Shell sekarang (`lib/main.dart:182-199`) punya 6 tab: Beranda · PC Lab · Pendukung · Log Servis ·
Pengajuan · Profil.

Pemetaannya:

| Tab mockup | Halaman Flutter sekarang | Perubahan |
| --- | --- | --- |
| Dashboard | `pages/summary_page.dart` | restyle |
| Unit PC | `pages/pc_management_page.dart` | restyle + sheet baru |
| Inventaris | `pages/support_inventory_page.dart` | restyle |
| Pengajuan | `pages/my_reports_page.dart` **+** `pages/repair_log_page.dart` | **digabung** |
| Akun | `pages/profile_page.dart` | restyle |

Konsekuensi yang harus diputuskan sebelum coding:

- **`repair_log_page.dart` dilebur** ke layar Pengajuan (mockup menampilkan tiket selesai +
  dialog "Berita Acara" di layar yang sama). Alternatif: tetap 6 tab dan biarkan Log terpisah —
  tapi itu menyimpang dari mockup.
- Header mockup adalah **app bar tetap** (bukan header per halaman): `SIBAL` + pill **`ONLINE`**
  berdenyut + subtitle nama layar + ikon `notifications` + avatar. `widgets/state_scope.dart`
  (`PageHeader`) harus diganti/diperluas; pill ONLINE adalah tempat alami untuk
  `connectivity_service.dart` (mint saat online, amber + teks `OFFLINE` saat putus — mockup tidak
  menggambar keadaan offline, itu tugas kita).
- Mockup **tidak punya** layar Pengumuman/Broadcast, padahal `announcements` sudah ada di skema
  dan di `summary_page.dart` sekarang. Keputusan: pertahankan panel broadcast di Dashboard
  (disarankan, datanya nyata) atau lepaskan.

## 3. Token warna — `lib/theme.dart` harus diganti

Mockup meninggalkan nuansa hijau-arang lama (`#0A0F0B`/`#151B17`) dan pindah ke arang
**berwarna cyan** (`#0F141A`/`#182326`) dengan mint yang jauh lebih jenuh.

| Peran | Sekarang | Mockup | Catatan |
| --- | --- | --- | --- |
| `bg` | `#0A0F0B` | `#0F141A` | kanvas; `surface-container-lowest` `#0A0F14` untuk header/dock |
| `card` | `#151B17` | `#182326` | Level 1 (`surface-card`) |
| `cardSurface` | `#1B241F` | `#1C2729` | Level 2 naik (`surface-card-elevated`); ada juga `#161F22` (`surface-card-subtle`) untuk sel di dalamnya |
| `cardBorder` | `#233027` | `#253438` | `border-subtle`; varian glow `#58E2C240` dan `#F59E0B40` |
| `mint` | `#A8E6D8` | `#58E2C2` | primary; teks di atasnya gelap (`#00382D`) |
| `yel` | `#E8E48C` | `#C1D045` | chip terpilih juga memakai `#DDEC5F`; glow aktif `#E2F163` |
| `lil` | `#E3B8F5` | `#C084FC` | cincin ketiga, badge tiket |
| `org` | `#F08A4B` | `#F59E0B` | warning; tint `#F6AD55`; tile gelap `#451A03` (amber-950) & `#78350F` (amber-900) |
| `redAlert` | `#FF6B6B` | `#FFB4AB` | error; kontainer `#93000A` |
| teks | `Colors.white` | `#FFFFFF` judul, `#DEE3EB` isi, `#94A3B8`/`#BBCAC4` sekunder | `tx()` default `Colors.white` masih cocok untuk judul saja |
| status normal | `mint` | `#3BD6B0` | `status-mint`, sedikit lebih gelap dari primary |

Perubahan ini menyentuh seluruh layar karena semua warna dipanggil lewat konstanta `theme.dart` —
untungnya cukup mengganti nilai konstanta, bukan setiap pemanggilan. Yang perlu diperiksa manual:
`a(mint, .15)` di `btn(tonal:)`, `dec()` (fill `#0E1410` → `#0A0F14`), `snack()`, dan track
`Ring` (`a(Colors.white, .07)` → `#1C2729` @ .6 seperti mockup).

Tipografi: **Inter 400/500/600/700**, letterSpacing rapat (mockup tidak menyetel letter-spacing
negatif selain gaya kita sekarang). Skala yang dipakai: 32/24 headline, 20 headline-md,
16 headline-sm/body-lg, 14 body-md/label-lg, 12 body-sm/label-md, 11 label-sm, **28 `display-stat`**
(angka besar di kartu metrik). Inter **belum** dibundel — pilihan: taruh TTF di `assets/fonts/`
(OFL, gratis, jalan offline; disarankan) atau `google_fonts` (butuh jaringan, tidak cocok untuk
lab offline).

Radius: kartu 16-20px, tombol/sub-kontainer 8-12px, chip/pill/nav `9999`, tile ikon 12px.
Spacing: margin luar 16px, jarak antarkartu 12-16px, ritme blok 16-20px, celah mikro 4/8px.
Elevation: tanpa drop shadow berat — lapisan tonal + glow (mint untuk aktif, halo amber
`inset 0 0 0 1px rgba(245,158,11,.3)` untuk kartu peringatan), dock/header translucent
`#12191CD9` + `backdrop-filter: blur(16px)` + garis `#2B3C40`.

## 4. Selisih per layar

### 4.1 Dashboard → `summary_page.dart`

Urutan mockup: chip lab (dot + label, terpilih lime) → banner peringatan → kartu bento cincin →
seksi "Kategori Inventaris" → 3 kartu akses → kartu foto lab → aktivitas terkini.

- **Banner `Perlu Penanganan Teknis`** + badge `Prioritas` + isi `1 unit PC bermasalah dan 1
  inventaris non-PC membutuhkan perbaikan/pengecekan segera di Lab 1.` + tautan
  `Buka Detail Tiket →` + meta `• ID: #SB-2041`. Panel serupa sudah ada; perlu badge, tautan, dan
  id tiket nyata (bukan format mockup).
- **Kartu bento `Kesiapan Lab 1`** + subjudul `Audit real-time perangkat & utilitas` + pill
  `Optimal Operasional`. Cincin **3 lapis** (160px; mint ≈75%, lime ≈60%, lilac ≈50%; track
  `#1C2729`) dengan pusat `75%` + `Kesiapan PC` → `widgets/ring.dart` sudah persis pola ini,
  tinggal ukuran/warna. Strip 3 sel di bawahnya: `3 / 4` `PC Normal` · `60%` `Alat Pendukung` ·
  `2` `Riwayat Servis`.
- **3 kartu akses** dengan badge jumlah (`4 Total`, `10 Alat`, `2 Tiket Berjalan`), subjudul,
  `chevron_right`, dan **progress bar terbelah** (mint 75% + amber 25%) plus legenda
  (`3 Unit Normal` / `1 Dalam Pengajuan`). Kartu ketiga tanpa bar, aksinya `Pantau →`.
  Bar terbelah = widget baru.
- **Kartu foto lab** `Ruang SIBAL-01 Lab Rekayasa` + pill `Kapasitas: 32 Kursi`.
  ⚠ tidak ada kolom foto maupun kapasitas di `labs` (hanya `code`, `name`, `description`).
  Jangan memakai URL remote mockup. Pilihan: hapus kartu ini, atau ganti kartu info lab
  (code + name + description) tanpa foto.
- **`Aktivitas Terkini Lab 1`** + tombol teks `Semua Log` + 3 baris (ikon `report_problem` amber /
  `check_circle` mint / `swap_horiz` lime, judul, waktu relatif `10m lalu`, `2j lalu`, `08:30 WIB`,
  dan isi). Sumber nyata: `maintenance_histories` + `reports` terbaru. Waktu relatif butuh
  formatter sendiri (`theme.dart` baru punya `fd/ft/fdt`).

### 4.2 Unit PC → `pc_management_page.dart`

- Baris pemilih lab: label `PILIH RUANG LABORATORIUM` + kanan `3 Lab Terhubung` (dot mint);
  pill `Lab 1` `4 PC` / `Lab 2` `0 PC` / `Lab 3` `0 PC` dengan ikon `domain`. Jumlah PC per lab
  nyata dari data; nama lab **dari `labs.name` seed**, bukan dari mockup.
- **Grid KPI 2 kolom**: `PC Normal` → `3` `Unit` → `75% siap praktikum`; `Perlu Servis` → `1`
  `Unit` → `Tiket aktif #REP-08`. Angka besar = `display-stat` 28px.
- Header daftar `Unit Komputer` + subjudul `Laboratorium Sistem & Jaringan 1`, kanan tombol
  **`+ Ajukan Kerusakan`** (mint, teks gelap) membuka sheet.
- Chip status dengan badge hitung: `Semua 4` · `Normal 3` · `Dalam Pengajuan 1`.
  Status di skema lebih banyak (`baik`, `dalam_pengajuan`, `diperiksa`, `rusak`, `purnatugas`) —
  putuskan apakah chip mengikuti 3 kelompok mockup atau domain enum penuh.
- **Kartu PC normal**: tile ikon, `PC-01`, pill `Kondisi Normal` (dot berdenyut), subjudul
  `Dell OptiPlex 7090 MT`, kebab `more_vert`. Grid spek 2 kolom: `Processor` →
  `Intel Core i5-12400`; `RAM / Storage` → `16GB DDR4 • 512GB SSD`; baris penuh `Posisi Stasiun`
  → `pin_drop` + `Meja depan kiri (Workstation A-01)`. Footer `task_alt Siap Digunakan` +
  tombol `Ajukan Kerusakan`. Kolom nyata: `processor`, `ram`, `storage`, `location`, `notes`,
  plus `gpu`/`mouse_spec`/`keyboard_spec` yang tidak digambar mockup (bisa masuk sheet detail).
  ⚠ subjudul "Dell OptiPlex 7090 MT" tidak punya kolom — pakai `codename` atau `notes`.
- **Kartu PC bermasalah** (varian amber): ikon `error`, judul amber, pill
  `Dalam Pengajuan Perbaikan` (dot `animate-ping`), subjudul `Tiket #REP-2024-008 • Menunggu
  Teknisi`, tombol `receipt_long` (detail tiket) menggantikan kebab, grid spek di latar lebih
  gelap, blok `Deskripsi Masalah Kerusakan` + `warning` + teks masalah, footer
  `schedule Diajukan 2 jam yang lalu` + tombol **`Batalkan Pengajuan`** (amber pekat).
  Semua punya sumber nyata: `reports.status`, `reports.issue_description`, `reports.created_at`,
  `sibal_cancel_report`.
- **Empty state** `Tidak Ada PC Ditemukan` + `Tidak ada unit komputer yang sesuai dengan filter
  yang Anda pilih di laboratorium ini.` (ikon `devices_off`).
- **Sheet `Ajukan Kerusakan PC`**: subjudul `Laporan perbaikan hardware/software SIBAL`;
  dropdown `Target Unit Komputer` (hanya PC yang **tidak** punya tiket terbuka — cocok dengan
  partial unique index kita); **3 pill kategori berikon** `Monitor/Layar` `Power/Mati`
  `Blue Screen`; textarea `Deskripsi Kerusakan` (placeholder `Contoh: Layar flickering dan
  freeze saat menjalankan software...`); tombol `Kirim Laporan Kerusakan`.
  ⚠ **`reports` tidak punya kolom kategori** (hanya `issue_description` + `severity`). Pilihan:
  (a) buang pill kategori, (b) kirim sebagai awalan teks deskripsi, (c) migration `0008`
  menambah kolom `issue_category`. `widgets/report_sheet.dart` sekarang memakai pemilih
  **severity** (`ringan/sedang/mendesak`) yang justru tidak ada di mockup — mockup punya
  `Prioritas: Sedang` di layar Pengajuan, jadi severity tetap dipakai, hanya tidak dipilih di sheet.

### 4.3 Inventaris → `support_inventory_page.dart`

- Pemilih lab (`Lab 1 - Jaringan & IoT` dst. — lagi-lagi nama mockup, pakai seed) + kanan
  `SIBAL Node Active`.
- Kartu ringkasan `Inventaris Pendukung Lab` + pill `SIBAL v2.4`, grid 2 sel:
  `Total Alat Terdata` → `10` `Unit`; `Dalam Pengajuan` → `2` `Perlu Servis` (amber);
  lalu CTA **`+ Ajukan Kerusakan / Pengajuan`** (mint).
- Pill filter `Semua (10)` · `Normal / Siap Pakai (8)` · `Dalam Pengajuan (2)`.
- Kartu item: tile ikon per kategori (`videocam`, `hub`, `network_check`, `handyman`, `wifi`),
  judul, meta `location_on Langit-langit tengah • 1 unit`, pill status
  (`Pengajuan Kerusakan Aktif`, `Menunggu Teknisi`, `Kondisi Normal / Siap Pakai`),
  kotak catatan (`Catatan Tiket #SBL-8812` + isi, atau `verified` + catatan kondisi untuk normal),
  footer (`schedule Diajukan 2 jam lalu` / `Terakhir dicek: Pagi ini`) + tombol
  `Batalkan Pengajuan` / `Ajukan Kerusakan`. `category` enum nyata
  (`support_category`) harus dipetakan ke ikon; `unit` nyata ("unit"/"pcs"/…) menggantikan
  kata "unit" hardcode; "Terakhir dicek" = `maintenance_histories` terakhir atau `updated_at`.
- **Tidak ada stepper qty di mockup** — sejalan dengan aturan kita (qty hanya lewat RPC admin).
  Pertahankan.
- Sheet `Form Pengajuan Kerusakan`: dua kotak baca-saja (`Pilih Alat Laboratorium`,
  `Lokasi & Posisi Terakhir`) + textarea `Detail Gejala / Kerusakan` + `Batal` / `Kirim Tiket`.

### 4.4 Pengajuan (+ Riwayat) → `my_reports_page.dart` ⊕ `repair_log_page.dart`

- Filter lab (`Pilih Ruang Lab` + `Filter Aktif` dengan ikon `tune`).
- **Grid 3 metrik**: `2` `Diproses` / `Butuh Tindakan` (amber) · `14` `Selesai` / `Tiket Beres`
  (mint) · `1` `Dibatalkan` / `Verifikasi Batal`. Ini memetakan ke `report_status`
  (`menunggu`+`diperiksa`+`diproses` / `selesai` / `batal`, dan `ditolak` yang tidak digambar
  mockup — perlu keputusan tampilan).
- Banner `Kendala Lab Baru?` + `Laporkan unit rusak atau servis periodik` + tombol **`Buat`**.
- Pill tipe `Semua Layanan 3` · `PC Unit` · `Inventaris Pendukung` — yang ini **aktifnya mint**,
  bukan lime (satu-satunya layar yang begitu); cocok dengan `target_kind` generated column.
- **Kartu tiket**: id + `Lab 1`, judul (`Penggantian Power Supply PC-03`), pill status
  (`Sedang Diperbaiki`, `Menunggu Verifikasi`, `Selesai`), grid meta 2 sel
  (`Target Aset`, `Estimasi Selesai` / `Kategori`, `Pelapor` / `Verifikator`, `Tanggal Selesai`),
  paragraf body, footer (`Batalkan Pengajuan` + `Log Teknisi →`, atau `Prioritas: Sedang`,
  atau `Lihat Berita Acara / Detail`).
  ⚠ `Estimasi Selesai` **tidak ada** di skema; `Verifikator` → `reviewed_by`/`performed_by_name`;
  `Pelapor` → `reporter_name`. Label status mockup harus dipetakan ke `ReportStatus.label` kita,
  jangan menambah kosakata baru.
- **Dialog `Berita Acara Servis`**: `Kode Layanan` `#SRV-103-CALIB` + judul, grid 2×2
  (`Lokasi`, `Petugas`, `Status Fisik`, `Garansi Lab`), paragraf hasil uji, tombol `Tutup` +
  **`Unduh PDF`**. Sumber nyata: `maintenance_histories` (`action_taken`, `notes`,
  `performed_by_name`, `maintenance_date`, `completed_at`, `qty_delta`).
  ⚠ `Garansi Lab` tidak ada di skema. ⚠ **Unduh PDF belum ada rencananya** dan menambah biaya
  waktu; keputusan: sembunyikan tombolnya dulu atau jadwalkan belakangan.

### 4.5 Akun → `profile_page.dart`

- Kartu identitas: avatar 64px + dot online mint, nama `Haykal Reno. L, S.Kom`, badge
  `verified Kepala Lab` (→ `profiles.role`), subjudul `Kepala Lab Komputer & Jaringan`
  (→ `description`), baris `badge ID: LAB-TECH-2026-08` (→ `username`; format mockup tidak ada
  di skema), tombol **`Edit Profil & Akun`**.
- **Grid 3 stat**: `3` `Lab Terhubung` · `32` `Unit Terkelola` · `98.2%` `Uptime Lab`.
  ⚠ `Uptime Lab` tidak ada sumbernya — ganti dengan metrik nyata (mis. tiket saya / riwayat saya)
  atau buang.
- **Kartu kesehatan daemon**: cincin tunggal 48px (track `#253438`, nilai `#58E2C2` ≈90%, ikon
  pusat `dns`) + `Status SIBAL Daemon` + `Sinkron Aktif` + `Terakhir diperbarui: Hari ini,
  14:32 WIB`. Ini pas sekali untuk `local_cache.lastSyncedAt` + `connectivity_service`.
- **Daftar menu 5 baris**: `Riwayat Pengajuan Saya` (+ pill `2 Diproses`) · `Notifikasi & Bot
  Telegram` (**switch**) · `Keamanan & Ganti Sandi` · `Unduh Laporan Lab` (+ pill `PDF`) ·
  `Pusat Bantuan & Panduan Lab`.
  ⚠ Bot Telegram di luar rencana dan butuh server (Rp 0 → buang atau jadikan baris nonaktif);
  `Unduh Laporan Lab` sama nasibnya dengan Unduh PDF; `Keamanan & Ganti Sandi` **bisa** nyata
  lewat `supabase.auth.updateUser(password:)` milik sendiri.
- Banner versi `SIBAL Engine Enterprise v4.8` / `Build #2026.03.11` + pill `Stable` → pakai
  `package_info_plus` atau konstanta di `app_env.dart`, jangan teks mockup.
- Tombol `Keluar Akun` (tint error) → `AuthService.signOut` (sudah ada, termasuk bersihkan cache).
- **Sheet `Edit Profil & Kredensial`**: 4 field — `Nama Lengkap & Gelar` (`person`),
  `Email Institusi` (`mail`), `Nomor Telepon / WhatsApp` (`phone`), `Kata Sandi Baru (Opsional)`
  (`key`, placeholder `Kosongkan bila tidak diubah`) + `Batal` / `Simpan Perubahan`.
  ⚠ **Email sintetis `@sibal.my.id` tidak boleh diedit** dan **telepon tidak ada kolomnya**.
  Yang sah diedit: `full_name`, `description`, `avatar_path` (kolom `profiles` yang dibuka untuk
  pemiliknya) + password lewat Auth. Field email harus baca-saja atau dihapus; field telepon
  dibuang atau dipetakan ke `description`.

## 5. Komponen baru yang harus dibuat di `lib/widgets/`

Sudah ada dan tinggal disesuaikan: `Panel`, `Seg`, `Logo`, `PulseBadge`, `AnimatedCount`
(`common.dart`), `Ring` (`ring.dart`), `StatusPill`/`AssetChip`/`ReportChip`/`SeverityChip`
(`status_chip.dart`), `SyncBanner`, `PageHeader` (`state_scope.dart`), `ReportSheet`.

Belum ada:

1. `AppHeader` tetap (brand + pill ONLINE/OFFLINE + subtitle + `notifications` + avatar).
2. `LabPicker` — baris pill lab ber-dot dengan hitungan, dipakai 4 layar (buat sekali).
3. `SplitBar` — progress bar terbelah (mint/amber, lime/amber) + legenda ber-dot.
4. `StatCell` / `MetricTile` — angka `display-stat` 28px + label + sublabel + dot.
5. `ChipCount` — chip filter dengan badge hitung (lime saat aktif, kecuali layar Pengajuan: mint).
6. `EmptyState` — tile ikon bulat + judul + body (dipakai Unit PC, dan sebaiknya semua daftar).
7. `TicketNoteBox` — kotak catatan tiket (label kapital + isi) untuk kartu PC/Inventaris.
8. `SheetField` — baris field sheet (ikon + nilai + chevron) untuk sheet Inventaris/Akun.
9. `BeritaAcaraDialog` — dialog rincian servis (Pengajuan).
10. `MiniRing` — cincin tunggal 48px berikon pusat (Akun). Bisa jadi varian `Ring`.
11. `ToastSibal` — mockup memakai toast kustom; `snack()` yang sekarang sudah setara, cukup
    disamakan gaya (ikon + judul + pesan, radius pill, warna `cardSurface`).

## 6. Urutan kerja yang disarankan

1. `theme.dart` (token + Inter bundled) → semua layar otomatis bergeser; perbaiki kontras.
2. `AppHeader` + dock 5 tab di `main.dart` (keputusan §2 lebih dulu).
3. Komponen bersama §5 butir 2-6.
4. Dashboard → Unit PC → Inventaris → Pengajuan → Akun (satu layar satu commit, `flutter analyze`
   di tiap langkah).
5. Verifikasi di perangkat/browser dengan data seed nyata, bukan angka mockup.

Panel admin (`lib/admin/`) **tidak** tercakup mockup ini; mockup hanya untuk shell mobile.

## 7. Aturan saat merevisi

- **Data nyata mengalahkan mockup.** Nama lab dari `labs.name` seed; id tiket dari `reports`
  (mockup memakai enam format berbeda: `#SB-2041`, `#REP-08`, `#REP-2024-008`, `#SBL-8812`,
  `#SRV-104`, `#SRV-103-CALIB` — pilih satu dan turunkan dari data, jangan hardcode); jumlah
  dari query. Mockup juga tidak konsisten (chip Inventaris mengklaim 10 item padahal hanya 5
  kartu; nama orang di Akun berbeda antara kartu dan form edit) — itu cacat mockup, bukan target.
- **Jangan menambah kolom hanya demi mockup.** Field tanpa sumber (kapasitas lab, foto lab,
  uptime, estimasi selesai, garansi, telepon) dibuang atau diganti metrik nyata; kalau memang
  diperlukan, itu keputusan migration `0008` tersendiri.
- **Tetap local-first & approval workflow.** Tidak ada tulisan langsung ke tabel; semua aksi
  pengguna lewat RPC (`sibal_report_issue`, `sibal_cancel_report`). Qty dan status aset tidak
  boleh diedit dari mobile. Sheet pengajuan harus terkunci saat offline (sudah ada di
  `report_sheet.dart`, pertahankan di desain baru).
- **Jangan sentuh** `lib/onboarding/` (selesai, commit `46643b8`), `supabase/migrations/0001`-`0007`,
  dan jalur auth/RLS. Revisi ini murni lapisan presentasi + maksimal satu migration bila §4.2(c)
  diambil.
- **Aset gambar**: mockup memuat foto dari URL `googleusercontent`. Jangan dipakai di produk
  (lisensi tidak jelas + butuh jaringan). Kalau kartu foto lab dipertahankan, bikin aset lokal
  atau buang kartunya.
