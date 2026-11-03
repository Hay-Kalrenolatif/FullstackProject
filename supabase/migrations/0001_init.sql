-- ============================================================================
-- SIBAL — 0001_init.sql
-- Skema cloud: domain, tabel, constraint, index. Tidak ada policy di sini
-- (semua enforcement ada di 0002_security.sql).
--
-- Terapkan lewat Supabase SQL Editor atau `supabase db push`.
-- ============================================================================

create schema if not exists app;
comment on schema app is 'Helper internal. Tidak diekspos PostgREST karena bukan schema publik.';

-- ----------------------------------------------------------------------------
-- 1. Domain. Enum, bukan text+CHECK: status adalah state machine, jadi nilai
--    typo harus gagal di level tipe, bukan lolos diam-diam.
-- ----------------------------------------------------------------------------
create type public.app_role           as enum ('user', 'admin');
create type public.target_kind        as enum ('pc', 'supporting_item');
create type public.asset_status       as enum ('baik', 'dalam_pengajuan', 'diperiksa', 'rusak', 'habis', 'purnatugas');
create type public.report_status      as enum ('menunggu', 'diperiksa', 'diproses', 'selesai', 'ditolak', 'batal');
create type public.report_severity    as enum ('ringan', 'sedang', 'darurat');
create type public.maintenance_status as enum ('tertunda', 'berjalan', 'selesai', 'dibatalkan');
create type public.maintenance_kind   as enum ('perbaikan', 'penggantian', 'pembersihan', 'pelengkapan', 'inspeksi', 'pemindahan', 'purnatugas');
create type public.support_category   as enum ('jaringan', 'tampilan', 'daya', 'periferal', 'alat', 'konsumsi', 'lain');
create type public.announcement_level as enum ('info', 'peringatan', 'penting');

-- ----------------------------------------------------------------------------
-- 2. Trigger updated_at. Supabase tidak memperbarui kolom ini sendiri.
-- ----------------------------------------------------------------------------
create function app.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ----------------------------------------------------------------------------
-- 3. labs
-- ----------------------------------------------------------------------------
create table public.labs (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique check (code ~ '^[A-Z0-9_-]{2,12}$'),
  name        text not null,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger trg_touch_labs before update on public.labs
  for each row execute function app.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 4. profiles
--    id = auth.users.id, tidak ada tabel users terpisah.
-- ----------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null,
  full_name   text not null check (char_length(full_name) between 2 and 80),
  description text not null default '' check (char_length(description) <= 280),
  -- object name di Storage, bukan URL: URL publik berubah kalau konfigurasi
  -- bucket berubah, sedangkan path adalah identitas objeknya.
  avatar_path text,
  role        public.app_role not null default 'user',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint profiles_username_shape check (username ~ '^[a-z0-9._-]{3,32}$')
);
-- Unik case-insensitive. unique biasa membiarkan 'Rian' dan 'rian' berdua
-- masuk, dan karena login menurunkan email sintetis dari username, tabrakan
-- itu jadi bug autentikasi, bukan sekadar tampilan.
create unique index profiles_username_uniq on public.profiles (lower(username));
create index profiles_active_role on public.profiles (role) where is_active;
create trigger trg_touch_profiles before update on public.profiles
  for each row execute function app.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 5. pcs
-- ----------------------------------------------------------------------------
create table public.pcs (
  id            uuid primary key default gen_random_uuid(),
  lab_id        uuid not null references public.labs (id) on delete restrict,
  codename      text not null,
  codename_norm text generated always as (upper(regexp_replace(codename, '\s+', '', 'g'))) stored,
  processor     text not null,
  ram           text not null,
  storage       text,
  gpu           text,
  mouse_spec    text,
  keyboard_spec text,
  status        public.asset_status not null default 'baik',
  location      text,
  notes         text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint pcs_status_check check (status is distinct from 'habis'),
  constraint pcs_codename_len check (char_length(codename) between 1 and 24)
);
-- Unik per Lab, bukan global: memaksa 'LAB1-PC01' kalau global, dan string itu
-- rusak begitu sebuah PC dipindah antar lab.
create unique index pcs_codename_per_lab on public.pcs (lab_id, codename_norm);
create index pcs_lab_status on public.pcs (lab_id, status) where is_active;
create trigger trg_touch_pcs before update on public.pcs
  for each row execute function app.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 6. supporting_items
--    qty sengaja dipertahankan dari SupportItem lama: satu baris adalah satu
--    jenis barang dengan jumlah, bukan satu unit fisik. Tanpa qty, persentase
--    kesiapan di Beranda jadi persentase baris dan stepper +/- kehilangan arti.
-- ----------------------------------------------------------------------------
create table public.supporting_items (
  id             uuid primary key default gen_random_uuid(),
  lab_id         uuid not null references public.labs (id) on delete restrict,
  name           text not null,
  category       public.support_category not null default 'lain',
  specifications text,
  qty            integer not null default 0 check (qty between 0 and 100000),
  unit           text not null default 'unit',
  status         public.asset_status not null default 'baik',
  location       text,
  notes          text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index support_name_per_lab on public.supporting_items (lab_id, lower(name));
create index support_lab_status on public.supporting_items (lab_id, status) where is_active;
create trigger trg_touch_support before update on public.supporting_items
  for each row execute function app.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 7. reports — tiket pengajuan kerusakan
-- ----------------------------------------------------------------------------
create table public.reports (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid references public.profiles (id) on delete set null,
  reporter_name      text not null,
  lab_id             uuid not null references public.labs (id) on delete restrict,
  pc_id              uuid references public.pcs (id) on delete restrict,
  supporting_item_id uuid references public.supporting_items (id) on delete restrict,
  -- Discriminator diturunkan dari FK, bukan ditulis pemanggil: kelas bug
  -- "target_kind bilang pc tapi pc_id null" jadi tidak bisa terjadi.
  target_kind        public.target_kind generated always as
                       (case when pc_id is not null then 'pc'::public.target_kind
                             else 'supporting_item'::public.target_kind end) stored,
  prev_asset_status  public.asset_status not null,
  issue_description  text not null check (char_length(issue_description) between 5 and 2000),
  severity           public.report_severity not null default 'sedang',
  evidence_paths     text[] not null default '{}',
  status             public.report_status not null default 'menunggu',
  reviewed_by        uuid references public.profiles (id) on delete set null,
  admin_notes        text,
  decided_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint reports_one_target check (num_nonnulls(pc_id, supporting_item_id) = 1)
);

-- Anti-spam: satu tiket terbuka per aset fisik. Tanpa ini, tiga siswa di PC yang
-- sama menghasilkan tiga tiket, tiga approve, tiga baris riwayat untuk satu
-- kerusakan — dan tiket yang sudah diproses masih bisa di-approve ulang.
create unique index reports_open_pc on public.reports (pc_id)
  where pc_id is not null and status in ('menunggu', 'diperiksa', 'diproses');
create unique index reports_open_support on public.reports (supporting_item_id)
  where supporting_item_id is not null and status in ('menunggu', 'diperiksa', 'diproses');

create index reports_queue on public.reports (created_at) where status = 'menunggu';
create index reports_mine on public.reports (user_id, created_at desc);
create index reports_lab on public.reports (lab_id, status);
create trigger trg_touch_reports before update on public.reports
  for each row execute function app.touch_updated_at();

-- Pelapor tambahan pada tiket yang sama ("saya juga"), supaya tiket kedua tidak
-- perlu dibuat.
create table public.report_witness (
  report_id  uuid not null references public.reports (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);

-- ----------------------------------------------------------------------------
-- 8. maintenance_histories — pekerjaan/riwayat
-- ----------------------------------------------------------------------------
create table public.maintenance_histories (
  id                 uuid primary key default gen_random_uuid(),
  report_id          uuid references public.reports (id) on delete set null,
  lab_id             uuid not null references public.labs (id) on delete restrict,
  pc_id              uuid references public.pcs (id) on delete restrict,
  supporting_item_id uuid references public.supporting_items (id) on delete restrict,
  target_kind        public.target_kind generated always as
                       (case when pc_id is not null then 'pc'::public.target_kind
                             else 'supporting_item'::public.target_kind end) stored,
  category           public.maintenance_kind not null default 'perbaikan',
  status             public.maintenance_status not null default 'berjalan',
  notes              text,
  action_taken       text not null check (char_length(action_taken) between 3 and 2000),
  performed_by       uuid references public.profiles (id) on delete set null,
  performed_by_name  text not null,
  -- Tanggal kalender WIB, bukan timestamptz: jam server Supabase adalah UTC,
  -- jadi pekerjaan jam 19.00 WIB tercatat "besok" tanpa cast eksplisit ini.
  maintenance_date   date not null default ((now() at time zone 'Asia/Jakarta')::date),
  completed_at       timestamptz,
  qty_delta          integer not null default 0 check (qty_delta between -100000 and 100000),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint mh_one_target  check (num_nonnulls(pc_id, supporting_item_id) = 1),
  constraint mh_qty_pc_na   check (pc_id is null or qty_delta = 0),
  constraint mh_done_stamp  check (status is distinct from 'selesai' or completed_at is not null)
);

-- Guard struktural anti-double-approve: satu pekerjaan terbuka per tiket,
-- ditegakkan database sehingga tetap bekerja walau pemanggilnya ceroboh.
create unique index mh_one_open_job on public.maintenance_histories (report_id)
  where report_id is not null and status in ('tertunda', 'berjalan');

create index mh_recent on public.maintenance_histories (maintenance_date desc, created_at desc);
create index mh_lab on public.maintenance_histories (lab_id, status);
create index mh_open on public.maintenance_histories (maintenance_date) where status = 'berjalan';
create trigger trg_touch_mh before update on public.maintenance_histories
  for each row execute function app.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 9. announcements — Broadcast di splash/Beranda. Tidak ada padanannya di
--    rancangan awal, padahal splash mensyaratkannya.
-- ----------------------------------------------------------------------------
create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null check (char_length(title) <= 120),
  body         text not null check (char_length(body) between 1 and 2000),
  level        public.announcement_level not null default 'info',
  is_published boolean not null default false,
  published_at timestamptz,
  expires_at   timestamptz,
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint ann_published_needs_date check (not is_published or published_at is not null),
  constraint ann_window_sane check (expires_at is null or coalesce(published_at, created_at) < expires_at)
);
-- Predikat index tidak boleh memakai now() (tidak immutable), jadi hanya sisi
-- is_published yang masuk index; jendela expires_at disaring saat query.
create index ann_feed on public.announcements (published_at desc) where is_published;
create trigger trg_touch_ann before update on public.announcements
  for each row execute function app.touch_updated_at();
