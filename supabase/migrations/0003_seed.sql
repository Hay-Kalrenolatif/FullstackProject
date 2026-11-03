-- ============================================================================
-- SIBAL — 0003_seed.sql
-- Data awal. Ini menggantikan _seedInitialDataIfNeeded() di
-- lib/services/hive_database_service.dart: seed tidak lagi di-generate dari
-- kode aplikasi, cukup dijalankan sekali di cloud.
--
-- Idempoten: semua baris memakai uuid tetap dan `on conflict do nothing`,
-- jadi aman dijalankan ulang.
--
-- Data PC/barang di bawah adalah contoh yang sama dengan seed lama, dipindah
-- ke Lab 1. Ganti dengan inventaris asli lab Anda sebelum dipakai luas — dan
-- kalau data yang sekarang ada di Box Hive perangkat perlu DIMIGRASI, bukan
-- dimulai dari nol, itu script terpisah, bukan bagian file ini.
-- ============================================================================

insert into public.labs (id, code, name, description) values
  ('00000000-0000-0000-0000-0000000000a1', 'LAB1', 'Lab 1', 'Laboratorium komputer depan'),
  ('00000000-0000-0000-0000-0000000000a2', 'LAB2', 'Lab 2', 'Laboratorium komputer tengah'),
  ('00000000-0000-0000-0000-0000000000a3', 'LAB3', 'Lab 3', 'Laboratorium komputer belakang')
on conflict (id) do nothing;

insert into public.pcs (id, lab_id, codename, processor, ram, storage, gpu, mouse_spec, keyboard_spec, status, location, notes) values
  ('00000000-0000-0000-0000-0000000001a1',
   (select id from public.labs where code = 'LAB1'), 'PC-01',
   'Intel Core i5-12400', '16 GB DDR4', '512 GB NVMe', 'Terintegrasi',
   'Logitech M170', 'Standard USB', 'baik', 'Baris depan kiri', 'Posisi meja baris depan kiri'),
  ('00000000-0000-0000-0000-0000000001a2',
   (select id from public.labs where code = 'LAB1'), 'PC-02',
   'Intel Core i5-12400', '16 GB DDR4', '512 GB NVMe', 'Terintegrasi',
   'Logitech M170', 'Standard USB', 'baik', 'Baris depan tengah', 'Posisi meja baris depan tengah'),
  ('00000000-0000-0000-0000-0000000001a3',
   (select id from public.labs where code = 'LAB1'), 'PC-03',
   'AMD Ryzen 5 5600G', '16 GB DDR4', '512 GB NVMe', 'Radeon Vega 7',
   'Logitech M170', 'Standard USB', 'baik', 'Baris depan kanan', 'Posisi meja baris depan kanan'),
  ('00000000-0000-0000-0000-0000000001a4',
   (select id from public.labs where code = 'LAB1'), 'PC-04',
   'Intel Core i3-10100', '8 GB DDR4', '256 GB SSD', 'Terintegrasi',
   'Standard USB', 'Standard USB', 'rusak', 'Baris tengah kiri',
   'Power supply drop, mati saat render')
on conflict (id) do nothing;

insert into public.supporting_items (id, lab_id, name, category, specifications, qty, unit, status, location) values
  ('00000000-0000-0000-0000-0000000002a1',
   (select id from public.labs where code = 'LAB1'),
   'Switch Gigabit 24-Port', 'jaringan', 'Managed, RJ45 24 port', 2, 'unit', 'baik', 'Rak Server Utama'),
  ('00000000-0000-0000-0000-0000000002a2',
   (select id from public.labs where code = 'LAB1'),
   'Proyektor Epson HDMI', 'tampilan', '3LCD, 3600 lumen', 1, 'unit', 'baik', 'Langit-langit Tengah'),
  ('00000000-0000-0000-0000-0000000002a3',
   (select id from public.labs where code = 'LAB1'),
   'UPS ICA 1200VA', 'daya', 'Line interactive, 1200VA', 4, 'unit', 'baik', 'Meja Instruktur & Server'),
  ('00000000-0000-0000-0000-0000000002a4',
   (select id from public.labs where code = 'LAB1'),
   'Kabel LAN Tester Digital', 'alat', 'Wiremap + length test', 2, 'unit', 'baik', 'Lemari Toolkit Teknisi')
on conflict (id) do nothing;

-- Satu broadcast contoh supaya layar splash/Beranda punya sesuatu untuk dibaca.
insert into public.announcements (id, title, body, level, is_published, published_at) values
  ('00000000-0000-0000-0000-0000000003a1',
   'Selamat datang di SIBAL',
   'Laporkan kerusakan PC atau barang lab lewat aplikasi ini. Status aset berubah menjadi Dalam Pengajuan sampai admin memverifikasi.',
   'info', true, now())
on conflict (id) do nothing;

-- Catatan: PC-04 sengaja berstatus 'rusak' tanpa tiket terbuka. Invarian
-- hanya mengikat status 'dalam_pengajuan', jadi ini sah. Untuk membuatnya
-- punya jejak riwayat, jalankan sebagai admin:
--   select public.sibal_set_asset_status(
--     p_pc_id := (select id from public.pcs where codename = 'PC-04'),
--     p_status := 'rusak',
--     p_reason := 'Hasil pemeriksaan PSU, menunggu penggantian unit');
