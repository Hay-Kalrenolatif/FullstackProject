-- ============================================================================
-- SIBAL — 0002_security.sql
-- Grants, RLS, helper, RPC atomik, trigger invariant, view, Storage, realtime.
--
-- Prinsip: klien mobile tidak punya hak tulis apa pun di tabel bisnis.
-- Setiap perubahan terjadi lewat satu function = satu transaksi, sehingga
-- state machine tidak bisa dilangkahi dan approve tidak bisa setengah jalan.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schema akses
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema app to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Helper identitas
-- ----------------------------------------------------------------------------

-- Konvensi login: Supabase Auth tidak mengenal kredensial username, jadi
-- username dipetakan ke email sintetis. Satu-satunya tempat konvensi ini
-- ditulis di sisi SQL; sisi Dart punya kembarannya di
-- lib/services/auth_service.dart. Dua-duanya harus diubah bareng.
create or replace function app.email_for_username(p_username text) returns text
language sql immutable as $$
  select lower(trim(p_username)) || '@sibal.invalid'
$$;

create or replace function app.role_of(p_uid uuid) returns public.app_role
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.profiles where id = p_uid and is_active
$$;

create or replace function app.is_admin() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(app.role_of(auth.uid()), 'user') = 'admin'
$$;

-- Baris profil pemanggil yang masih aktif. Dipakai sebagai pernyataan pertama
-- di setiap RPC: kolom is_active dibaca hidup, jadi kill switch admin bekerja
-- seketika walau JWT sesi lama belum kedaluwarsa.
create or replace function app.active_profile() returns public.profiles
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v public.profiles;
begin
  select * into v from public.profiles where id = auth.uid();
  if not found then raise exception 'Sesi tidak valid'; end if;
  if not v.is_active then raise exception 'Akun dinonaktifkan'; end if;
  return v;
end $$;

-- Menegakkan "hanya admin" di dua dunia sekaligus:
--   * mobile (PostgREST): auth.uid() terisi, role dibaca dari profiles.
--   * Retool (koneksi Postgres langsung): auth.uid() selalu NULL, jadi operator
--     mengidentifikasi diri dengan email Retool-nya.
-- Jujur tentang batasnya: ini menyetop kecelakaan, bug UI, dan user Retool
-- non-admin. Tidak menyetop orang yang bisa mengedit query Retool, karena
-- resource Retool berjalan sebagai role postgres yang punya BYPASSRLS.
create or replace function app.resolve_admin(p_operator_email text default null) returns uuid
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_uid uuid; v_role public.app_role; v_active boolean;
begin
  v_uid := auth.uid();
  if v_uid is not null then
    select role, is_active into v_role, v_active from public.profiles where id = v_uid;
    if v_role = 'admin' and v_active then return v_uid; end if;
    raise exception 'Aksi admin ditolak: sesi ini bukan admin aktif';
  end if;

  if coalesce(trim(p_operator_email), '') = '' then
    raise exception 'Butuh identitas admin: sesi Supabase Auth atau email operator';
  end if;

  select u.id, p.role, p.is_active into v_uid, v_role, v_active
    from auth.users u
    join public.profiles p on p.id = u.id
   where lower(u.email) = lower(trim(p_operator_email));
  if not found then raise exception 'Operator % tidak terdaftar', trim(p_operator_email); end if;
  if v_role <> 'admin' or not v_active then
    raise exception 'Operator % bukan admin aktif', trim(p_operator_email);
  end if;
  return v_uid;
end $$;

-- Penanda "penulisan ini datang dari RPC". Dipakai trigger pagar status di §7.
create or replace function app.allow_rpc_write() returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform set_config('app.rpc', 'on', true);
end $$;

-- Tidak untuk dipanggil klien: hanya RPC yang berhak menyalakan penanda.
revoke execute on function app.allow_rpc_write() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. Hak akses tabel — write path ditutup, read dibuka
-- ----------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
-- Fungsi di schema public secara default boleh dieksekusi PUBLIC di Supabase,
-- jadi setiap RPC diberi revoke eksplisit lalu grant selektif di §6 — bukan
-- blanket revoke di sini, yang bisa ikut menutup fungsi milik Supabase.
revoke execute on all functions in schema app from public, anon;
grant execute on all functions in schema app to authenticated;

grant select on public.labs, public.pcs, public.supporting_items,
                public.profiles, public.reports, public.report_witness,
                public.maintenance_histories, public.announcements to authenticated;

-- Hanya tiga kolom ini yang boleh ditulis pemilik akun. role, is_active, dan
-- username tidak bisa diubah sendiri — dan ini ditutup di lapis privilege,
-- bukan policy: RLS WITH CHECK hanya melihat NEW, tidak pernah baris lama, jadi
-- ia bukan tempat yang tepat untuk mencegah "user menaikan dirinya jadi admin".
grant update (full_name, description, avatar_path) on public.profiles to authenticated;
grant insert on public.profiles to authenticated;
grant delete on public.profiles to authenticated;

-- Tidak ada insert/update/delete untuk authenticated di labs, pcs,
-- supporting_items, reports, maintenance_histories, announcements.

-- ----------------------------------------------------------------------------
-- 4. Row Level Security
-- ----------------------------------------------------------------------------
alter table public.labs                  enable row level security;
alter table public.pcs                   enable row level security;
alter table public.supporting_items      enable row level security;
alter table public.profiles              enable row level security;
alter table public.reports               enable row level security;
alter table public.report_witness        enable row level security;
alter table public.maintenance_histories enable row level security;
alter table public.announcements         enable row level security;

-- Master data: setiap anggota yang login boleh melihat, tidak boleh menulis.
create policy labs_read on public.labs for select to authenticated using (true);
create policy pcs_read on public.pcs for select to authenticated
  using (is_active or app.is_admin());
create policy support_read on public.supporting_items for select to authenticated
  using (is_active or app.is_admin());

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_self_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Self-registration tidak boleh melahirkan admin.
create policy profiles_self_insert on public.profiles for insert to authenticated
  with check (id = auth.uid() and role = 'user');
create policy profiles_self_delete on public.profiles for delete to authenticated
  using (id = auth.uid());

-- Pelapor melihat tiketnya sendiri; admin melihat semuanya.
create policy reports_read on public.reports for select to authenticated
  using (user_id = auth.uid() or app.is_admin());
create policy witness_read on public.report_witness for select to authenticated
  using (user_id = auth.uid() or app.is_admin());

-- Riwayat perbaikan adalah baca-seluruh-anggota; tulis hanya lewat RPC.
create policy mh_read on public.maintenance_histories for select to authenticated using (true);

-- Broadcast hanya yang sudah terbit dan belum kedaluwarsa.
create policy ann_read on public.announcements for select to authenticated using (
  is_published and (expires_at is null or expires_at > now())
);

-- ----------------------------------------------------------------------------
-- 5. Profil otomatis saat akun dibuat (Termasuk saat admin membuat akun
--    lewat Retool / Auth API)
-- ----------------------------------------------------------------------------
create or replace function app.handle_new_user() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_username text;
  v_fullname text;
begin
  -- Bersihkan dulu, baru validasi: kolom punya CHECK bentuk username, dan
  -- local-part email asli user bisa saja berisi '+' atau titik-dua.
  v_username := regexp_replace(
    lower(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1))),
    '[^a-z0-9._-]', '', 'g');
  if char_length(v_username) < 3 then
    v_username := v_username || left(new.id::text, 3);
  end if;
  v_username := left(v_username, 32);

  v_fullname := coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
                         nullif(trim(v_username), ''), 'Anggota');
  if char_length(v_fullname) < 2 then v_fullname := v_fullname || '·'; end if;
  v_fullname := left(v_fullname, 80);

  insert into public.profiles (id, username, full_name, role)
  values (
    new.id,
    v_username,
    v_fullname,
    case when lower(coalesce(new.raw_user_meta_data ->> 'role', 'user')) = 'admin'
         then 'admin'::public.app_role else 'user'::public.app_role end
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function app.handle_new_user();

-- ----------------------------------------------------------------------------
-- 6. RPC — satu panggilan = satu transaksi
-- ----------------------------------------------------------------------------

-- 6.1 Pengajuan kerusakan oleh anggota mana pun.
create or replace function public.sibal_report_issue(
  p_pc_id uuid default null,
  p_supporting_item_id uuid default null,
  p_issue text default null,
  p_severity public.report_severity default 'sedang',
  p_evidence_paths text[] default '{}'
) returns table (report_id uuid, status public.report_status, reused boolean, msg text)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_prof public.profiles;
  v_tid uuid; v_kind text; v_lab uuid; v_prev public.asset_status;
  v_existing uuid;
begin
  perform app.allow_rpc_write();
  v_prof := app.active_profile();

  if num_nonnulls(p_pc_id, p_supporting_item_id) <> 1 then
    return query select null::uuid, null::public.report_status, false,
      'Pilih salah satu target: PC atau barang pendukung.'::text;
    return;
  end if;
  if char_length(coalesce(trim(p_issue), '')) < 5 then
    return query select null::uuid, null::public.report_status, false,
      'Deskripsikan masalahnya minimal 5 karakter.'::text;
    return;
  end if;

  if p_pc_id is not null then
    v_tid := p_pc_id; v_kind := 'pc';
    select lab_id, status into v_lab, v_prev from public.pcs
      where id = p_pc_id and is_active for update;
  else
    v_tid := p_supporting_item_id; v_kind := 'supporting_item';
    select lab_id, status into v_lab, v_prev from public.supporting_items
      where id = p_supporting_item_id and is_active for update;
  end if;
  if not found then
    return query select null::uuid, null::public.report_status, false,
      'Target tidak ditemukan atau sudah purnatugas.'::text;
    return;
  end if;
  if v_prev = 'purnatugas' then
    return query select null::uuid, null::public.report_status, false,
      'Aset sudah purnatugas.'::text;
    return;
  end if;

  -- Sudah ada tiket terbuka untuk aset ini: jangan buat tiket kedua,
  -- catat pelapor sebagai konfirmasi, dan tempel keluhannya ke tiket itu
  -- supaya keluhan siswa kedua tidak hilang begitu saja.
  select id into v_existing from public.reports
    where (pc_id = v_tid or supporting_item_id = v_tid)
      and status in ('menunggu', 'diperiksa', 'diproses');
  if found then
    insert into public.report_witness (report_id, user_id)
      values (v_existing, v_prof.id) on conflict do nothing;
    update public.reports
       set issue_description = left(
             issue_description || E'\n— ' || v_prof.full_name || ': ' || trim(p_issue), 2000)
     where id = v_existing;
    return query select v_existing,
      (select r.status from public.reports r where r.id = v_existing),
      true,
      'Sudah ada pengajuan terbuka untuk aset ini. Keluhannya ditambahkan ke sana.'::text;
    return;
  end if;

  insert into public.reports (user_id, reporter_name, lab_id, pc_id, supporting_item_id,
                              prev_asset_status, issue_description, severity, evidence_paths, status)
  values (v_prof.id, v_prof.full_name, v_lab,
          case when v_kind = 'pc' then v_tid end,
          case when v_kind = 'supporting_item' then v_tid end,
          v_prev, trim(p_issue), p_severity, p_evidence_paths, 'menunggu')
  returning reports.id into v_existing;

  -- Flip otomatis yang diminta rancangan, HANYA dari 'baik'. Aset yang sudah
  -- rusak/diperiksa mempertahankan statusnya, dan prev_asset_status tetap
  -- menyimpan nilai benar untuk pengembalian saat reject.
  if v_prev = 'baik' then
    if v_kind = 'pc' then
      update public.pcs set status = 'dalam_pengajuan' where id = v_tid;
    else
      update public.supporting_items set status = 'dalam_pengajuan' where id = v_tid;
    end if;
  end if;

  return query select v_existing, 'menunggu'::public.report_status, false,
    'Pengajuan terkirim.'::text;
end $$;

-- 6.2 Admin: periksa (belum menerima kerusakan, hanya menugaskan pengecekan)
create or replace function public.sibal_check_report(
  p_report_id uuid,
  p_notes text default null,
  p_performed_by uuid default null,
  p_operator_email text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  r public.reports;
  v_tid uuid; v_cur public.asset_status; v_mh uuid;
  v_actor_name text;
begin
  perform app.allow_rpc_write();
  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.status <> 'menunggu' then
    raise exception 'Hanya pengajuan berstatus menunggu yang bisa diperiksa (status kini: %)', r.status;
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  if r.pc_id is not null then
    select status into v_cur from public.pcs where id = v_tid for update;
    update public.pcs set status = 'diperiksa' where id = v_tid;
  else
    select status into v_cur from public.supporting_items where id = v_tid for update;
    update public.supporting_items set status = 'diperiksa' where id = v_tid;
  end if;

  v_actor_name := coalesce((select full_name from public.profiles where id = v_admin), 'Admin');
  insert into public.maintenance_histories
    (report_id, lab_id, pc_id, supporting_item_id, category, status, action_taken,
     performed_by, performed_by_name)
  values (r.id, r.lab_id, r.pc_id, r.supporting_item_id, 'inspeksi', 'tertunda',
          coalesce(nullif(trim(p_notes), ''), 'Pengecekan dijadwalkan'),
          coalesce(p_performed_by, v_admin), v_actor_name)
  returning id into v_mh;

  update public.reports
     set status = 'diperiksa', reviewed_by = v_admin,
         admin_notes = coalesce(p_notes, admin_notes), decided_at = now()
   where id = r.id;
  return v_mh;
end $$;

-- 6.3 Admin: setujui → aset jadi rusak/diperiksa + pekerjaan terbuka dibuat.
create or replace function public.sibal_approve_report(
  p_report_id uuid,
  p_action_taken text,
  p_kind public.maintenance_kind default 'perbaikan',
  p_asset_status public.asset_status default 'rusak',
  p_performed_by uuid default null,
  p_qty_delta integer default 0,
  p_operator_email text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  r public.reports;
  v_tid uuid; v_cur public.asset_status; v_mh uuid; v_actor_name text;
begin
  perform app.allow_rpc_write();
  if char_length(coalesce(trim(p_action_taken), '')) < 3 then
    raise exception 'Tindakan tidak boleh kosong';
  end if;
  if p_asset_status not in ('rusak', 'diperiksa') then
    raise exception 'Status hasil persetujuan hanya bisa rusak atau diperiksa';
  end if;

  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.status not in ('menunggu', 'diperiksa') then
    raise exception 'Pengajuan sudah diproses (status: %)', r.status;
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  if r.pc_id is not null then
    if p_qty_delta <> 0 then raise exception 'Perubahan stok hanya untuk barang pendukung'; end if;
    select status into v_cur from public.pcs where id = v_tid for update;
    if v_cur is null then raise exception 'Aset target sudah tidak ada'; end if;
    update public.pcs set status = p_asset_status where id = v_tid;
  else
    select status, qty into v_cur from public.supporting_items where id = v_tid for update;
    if v_cur is null then raise exception 'Aset target sudah tidak ada'; end if;
    update public.supporting_items
       set status = p_asset_status, qty = qty + p_qty_delta
     where id = v_tid;
  end if;

  v_actor_name := coalesce(
    (select full_name from public.profiles where id = coalesce(p_performed_by, v_admin)), 'Admin');
  insert into public.maintenance_histories
    (report_id, lab_id, pc_id, supporting_item_id, category, status, action_taken,
     performed_by, performed_by_name, qty_delta)
  values (r.id, r.lab_id, r.pc_id, r.supporting_item_id, p_kind, 'berjalan',
          trim(p_action_taken), coalesce(p_performed_by, v_admin), v_actor_name,
          case when r.supporting_item_id is not null then p_qty_delta else 0 end)
  returning id into v_mh;

  update public.reports
     set status = 'diproses', reviewed_by = v_admin,
         admin_notes = coalesce(admin_notes, trim(p_action_taken)), decided_at = now()
   where id = r.id;
  return v_mh;
end $$;

-- 6.4 Admin: tolak → aset kembali ke status sebelum pengajuan.
create or replace function public.sibal_reject_report(
  p_report_id uuid,
  p_reason text,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  r public.reports;
  v_tid uuid; v_cur public.asset_status;
begin
  perform app.allow_rpc_write();
  if char_length(coalesce(trim(p_reason), '')) < 3 then
    raise exception 'Alasan penolakan wajib diisi';
  end if;

  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.status not in ('menunggu', 'diperiksa') then
    raise exception 'Hanya pengajuan menunggu/diperiksa yang bisa ditolak (status kini: %)', r.status;
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  -- Kembalikan HANYA jika aset masih pada status dalam_pengajuan. Kalau admin
  -- lain sudah memindahkannya, keputusan itu tidak ditimpa.
  if r.pc_id is not null then
    select status into v_cur from public.pcs where id = v_tid for update;
    if v_cur = 'dalam_pengajuan' then
      update public.pcs set status = r.prev_asset_status where id = v_tid;
    end if;
  else
    select status into v_cur from public.supporting_items where id = v_tid for update;
    if v_cur = 'dalam_pengajuan' then
      update public.supporting_items set status = r.prev_asset_status where id = v_tid;
    end if;
  end if;

  update public.reports
     set status = 'ditolak', reviewed_by = v_admin,
         admin_notes = trim(p_reason), decided_at = now()
   where id = r.id;
end $$;

-- 6.5 Admin: pekerjaan selesai → tiket selesai + aset kembali normal.
--    Satu-satunya jalan kembali ke 'baik' selain reject, jadi stok juga
--    bergerak di sini kalau pekerjaannya menyangkut persediaan.
create or replace function public.sibal_complete_maintenance(
  p_maintenance_id uuid,
  p_notes text default null,
  p_outcome public.asset_status default 'baik',
  p_qty_delta integer default 0,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  m public.maintenance_histories;
  v_tid uuid;
begin
  perform app.allow_rpc_write();
  select * into m from public.maintenance_histories where id = p_maintenance_id for update;
  if not found then raise exception 'Riwayat pekerjaan tidak ditemukan'; end if;
  if m.status not in ('tertunda', 'berjalan') then
    raise exception 'Pekerjaan sudah berstatus %', m.status;
  end if;

  v_tid := coalesce(m.pc_id, m.supporting_item_id);
  if m.pc_id is not null then
    update public.pcs set status = p_outcome where id = v_tid;
  else
    update public.supporting_items
       set status = p_outcome, qty = qty + p_qty_delta
     where id = v_tid;
  end if;

  update public.maintenance_histories
     set status = 'selesai',
         notes = case when nullif(trim(p_notes), '') is null then notes
                      else coalesce(notes || E'\n', '') || trim(p_notes) end,
         completed_at = now()
   where id = m.id;

  if m.report_id is not null then
    update public.reports set status = 'selesai', decided_at = now()
     where id = m.report_id and status = 'diproses';
  end if;
end $$;

-- 6.6 Pelapor: batalkan pengajuan sendiri sebelum disentuh admin.
--    Tanpa jalur ini, satu salah pencet mengunci PC sampai admin sempat datang.
create or replace function public.sibal_cancel_report(p_report_id uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_prof public.profiles := app.active_profile();
  r public.reports;
  v_tid uuid; v_cur public.asset_status;
begin
  perform app.allow_rpc_write();
  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.user_id is distinct from v_prof.id then
    raise exception 'Hanya pelapor yang bisa membatalkan pengajuannya';
  end if;
  if r.status <> 'menunggu' then
    raise exception 'Pengajuan sudah diproses admin (status: %)', r.status;
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  if r.pc_id is not null then
    select status into v_cur from public.pcs where id = v_tid for update;
    if v_cur = 'dalam_pengajuan' then
      update public.pcs set status = r.prev_asset_status where id = v_tid;
    end if;
  else
    select status into v_cur from public.supporting_items where id = v_tid for update;
    if v_cur = 'dalam_pengajuan' then
      update public.supporting_items set status = r.prev_asset_status where id = v_tid;
    end if;
  end if;

  update public.reports set status = 'batal', decided_at = now() where id = r.id;
end $$;

-- 6.7 Admin: buka kembali tiket yang sudah selesai/ditolak ("masih rusak juga")
create or replace function public.sibal_reopen_report(
  p_report_id uuid,
  p_reason text,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  r public.reports;
  v_tid uuid;
begin
  perform app.allow_rpc_write();
  if char_length(coalesce(trim(p_reason), '')) < 3 then raise exception 'Alasan wajib diisi'; end if;
  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.status not in ('selesai', 'ditolak', 'batal') then
    raise exception 'Hanya tiket selesai/ditolak/batal yang bisa dibuka lagi';
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  if r.pc_id is not null then
    update public.pcs set status = 'dalam_pengajuan' where id = v_tid;
  else
    update public.supporting_items set status = 'dalam_pengajuan' where id = v_tid;
  end if;

  update public.reports
     set status = 'menunggu', reviewed_by = v_admin,
         admin_notes = trim(p_reason), decided_at = now()
   where id = r.id;
end $$;

-- 6.8 Admin: ubah status aset tanpa pengajuan (mis. hasil cek fisik).
--    Wajib tetap mencatat jejaknya, dan itu sebabnya function ini ada:
--    tanpa jalur resmi, edit inline di Retool jadi satu-satunya cara dan
--    tidak meninggalkan riwayat sama sekali.
create or replace function public.sibal_set_asset_status(
  p_pc_id uuid default null,
  p_supporting_item_id uuid default null,
  p_status public.asset_status default null,
  p_reason text default null,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  v_tid uuid; v_lab uuid;
  v_actor_name text := coalesce((select full_name from public.profiles where id = v_admin), 'Admin');
begin
  perform app.allow_rpc_write();
  if num_nonnulls(p_pc_id, p_supporting_item_id) <> 1 then
    raise exception 'Pilih salah satu target: PC atau barang pendukung';
  end if;
  if p_status is null then raise exception 'Status target wajib diisi'; end if;
  if char_length(coalesce(trim(p_reason), '')) < 3 then
    raise exception 'Alasan perubahan wajib diisi';
  end if;

  if p_pc_id is not null then
    select lab_id into v_lab from public.pcs where id = p_pc_id for update;
    if not found then raise exception 'PC tidak ditemukan'; end if;
    update public.pcs set status = p_status where id = p_pc_id;
  else
    select lab_id into v_lab from public.supporting_items where id = p_supporting_item_id for update;
    if not found then raise exception 'Barang tidak ditemukan'; end if;
    update public.supporting_items set status = p_status where id = p_supporting_item_id;
  end if;

  insert into public.maintenance_histories
    (report_id, lab_id, pc_id, supporting_item_id, category, status, action_taken,
     performed_by, performed_by_name, completed_at)
  values (null, v_lab, p_pc_id, p_supporting_item_id, 'inspeksi', 'selesai',
          trim(p_reason), v_admin, v_actor_name, now());
end $$;

-- 6.9 Admin: ganti peran / aktif-nonaktif akun
create or replace function public.sibal_set_user_role(
  p_user_id uuid,
  p_role public.app_role,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := app.resolve_admin(p_operator_email);
begin
  if p_user_id = v_admin and p_role <> 'admin' then
    raise exception 'Tidak bisa menurunkan peran sendiri';
  end if;
  update public.profiles set role = p_role where id = p_user_id;
end $$;

create or replace function public.sibal_set_user_active(
  p_user_id uuid,
  p_is_active boolean,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_admin uuid := app.resolve_admin(p_operator_email);
begin
  if p_user_id = v_admin and not p_is_active then
    raise exception 'Tidak bisa menonaktifkan akun sendiri';
  end if;
  update public.profiles set is_active = p_is_active where id = p_user_id;
end $$;

-- Semua RPC SIBAL: cabut hak jalan dari PUBLIC/anon lebih dulu, baru beri ke
-- authenticated. Ini bukan formalitas. app.resolve_admin() hanya menerima
-- identitas lewat parameter email ketika auth.uid() NULL — dan itu terjadi pada
-- koneksi langsung (Retool). Selama anon masih boleh mengeksekusi, siapa pun
-- tanpa login bisa berpura-pura menjadi admin hanya dengan mengirim email admin
-- mana pun. Setelah revoke, penyalahgunaan itu tidak reachable dari PostgREST;
-- untuk koneksi langsung sisanya tetap setebal kredensial DB itu sendiri.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'sibal_%'
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 7. Penjaga konsistensi lintas tabel
-- ----------------------------------------------------------------------------

-- Invarian: aset berstatus dalam_pengajuan wajib punya tiket terbuka. Hanya
-- status ini yang dijaga, karena 'diperiksa' dan 'rusak' sah dicapai tanpa
-- tiket (admin memeriksa fisik langsung lewat sibal_set_asset_status).
-- DEFERRABLE INITIALLY DEFERRED bukan hiasan: urutan di dalam RPC adalah
-- "pulihkan aset" lalu "tutup tiket", dan di akhir transaksi kondisi aset sudah
-- tidak dalam_pengajuan sehingga pemicu ini tidak lagi menuntut tiket terbuka.
-- Pemicu immediate akan membaca keadaan tengah-transaksi dan menggagalkan
-- penyelesaian yang sebenarnya benar.
create or replace function app.guard_asset_ticket_invariant() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_open int;
begin
  if new.status = 'dalam_pengajuan' then
    select count(*) into v_open from public.reports
     where (pc_id = new.id or supporting_item_id = new.id)
       and status in ('menunggu', 'diperiksa', 'diproses');
    if v_open = 0 then
      raise exception 'Aset % tidak boleh berstatus % tanpa pengajuan terbuka', new.id, new.status;
    end if;
  end if;
  return new;
end $$;

create constraint trigger pcs_ticket_invariant
  after update of status on public.pcs
  deferrable initially deferred
  for each row execute function app.guard_asset_ticket_invariant();

create constraint trigger support_ticket_invariant
  after update of status on public.supporting_items
  deferrable initially deferred
  for each row execute function app.guard_asset_ticket_invariant();

-- Pagar kecelakaan untuk status: kolom lain boleh diedit inline di Retool,
-- status tidak. Jujur: ini pagar, bukan batas keamanan — admin yang sengaja
-- bisa menyalakan penandanya sendiri. Yang menegangkan peran adalah privilege
-- kolom di §3 dan assert di setiap RPC.
create or replace function app.guard_status_offband() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status
     and coalesce(current_setting('app.rpc', true), '') <> 'on' then
    raise exception 'Status hanya boleh diubah lewat function sibal_*, bukan edit langsung';
  end if;
  return new;
end $$;

create trigger trg_pcs_status_guard before update of status on public.pcs
  for each row execute function app.guard_status_offband();
create trigger trg_support_status_guard before update of status on public.supporting_items
  for each row execute function app.guard_status_offband();

-- ----------------------------------------------------------------------------
-- 8. View statistik dashboard
--    security_invoker wajib: view definer akan melubangi RLS.
--    Metrik diambil lewat subquery terpisah, bukan join — join pcs dan reports
--    sekaligus akan menggandakan baris dan menggelembungkan angka.
-- ----------------------------------------------------------------------------
create or replace view public.v_lab_stats with (security_invoker = true) as
select l.id as lab_id, l.code, l.name,
       (select count(*) from public.pcs p
         where p.lab_id = l.id and p.is_active) as total_pc,
       (select count(*) from public.pcs p
         where p.lab_id = l.id and p.is_active and p.status = 'baik') as pc_baik,
       (select count(*) from public.pcs p
         where p.lab_id = l.id and p.is_active
           and p.status in ('rusak', 'diperiksa', 'dalam_pengajuan')) as pc_butuh_perhatian,
       (select coalesce(sum(s.qty), 0) from public.supporting_items s
         where s.lab_id = l.id and s.is_active) as support_qty,
       (select count(*) from public.supporting_items s
         where s.lab_id = l.id and s.is_active
           and s.status in ('rusak', 'diperiksa', 'dalam_pengajuan')) as support_butuh_perhatian,
       (select count(*) from public.reports r
         where r.lab_id = l.id and r.status = 'menunggu') as pending_reports,
       (select count(*) from public.maintenance_histories m
         where m.lab_id = l.id and m.status = 'berjalan') as pekerjaan_berjalan
from public.labs l;
grant select on public.v_lab_stats to authenticated;

-- ----------------------------------------------------------------------------
-- 9. Storage: avatar profil + bukti foto pengajuan
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;
insert into storage.buckets (id, name, public)
values ('report-evidence', 'report-evidence', false)
on conflict (id) do nothing;

-- Avatar dibuat publik-read supaya UI mobile cukup menempel satu URL.
-- Konsekuensinya: foto profil bisa dilihat siapa pun yang tahu URL-nya.
-- Kalau itu tidak dapat diterima, ganti ke signed URL dan bucket ini jadi private.
create policy avatars_public_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'avatars');
create policy avatars_own_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_own_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_own_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy evidence_own_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'report-evidence' and (storage.foldername(name))[1] = auth.uid()::text);
create policy evidence_own_update on storage.objects for update to authenticated
  using (bucket_id = 'report-evidence' and (storage.foldername(name))[1] = auth.uid()::text);
create policy evidence_own_delete on storage.objects for delete to authenticated
  using (bucket_id = 'report-evidence' and (storage.foldername(name))[1] = auth.uid()::text);
create policy evidence_member_read on storage.objects for select to authenticated
  using (bucket_id = 'report-evidence');

-- ----------------------------------------------------------------------------
-- 10. Realtime untuk bar notifikasi admin dan penyegaran mobile
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['reports', 'maintenance_histories', 'announcements', 'pcs'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
