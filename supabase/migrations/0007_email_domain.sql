-- ============================================================================
-- SIBAL — 0007_email_domain.sql
--
-- Ditemukan lewat percobaan nyata, bukan dari dokumen: Supabase Auth menolak
-- signup dengan `email_address_invalid` untuk domain `.invalid` (domain khusus
-- yang dicadangkan RFC 2606). Akibatnya "siswa mendaftar sendiri dari aplikasi"
-- tidak pernah bisa jalan, padahal seluruh rancangan login dibangun di atas
-- pemetaan username → email sintetis.
--
-- Konvensi dipindah ke domain yang diterima validasi. Dengan `Confirm email`
-- dimatikan di dashboard, tidak ada surat yang benar-benar dikirim — domain ini
-- hanya kunci teks.
--
-- Satu-satunya tempat nilai domain hidup di SQL adalah function ini; padanan
-- Dart-nya `AppEnv.emailDomain` di lib/core/app_env.dart. Keduanya HARUS sama:
-- kalau berbeda, login seluruh akun berubah menjadi "Invalid login credentials"
-- tanpa petunjuk apa pun.
-- ============================================================================

create or replace function app.email_for_username(p_username text) returns text
language sql immutable as $$
  select lower(trim(p_username)) || '@sibal.my.id'
$$;

comment on function app.email_for_username(text) is
  'Petakan username ke email sintetis. Domain wajib sama dengan AppEnv.emailDomain (Dart).';

-- Tidak ada perubahan data di sini. Baris auth.users yang masih memakai domain
-- lama dipindahkan lewat Admin API (PUT /auth/v1/admin/users), bukan UPDATE
-- mentah pada schema auth, supaya GoTrue tetap yang menulis state-nya sendiri.
