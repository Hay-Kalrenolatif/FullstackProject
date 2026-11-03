-- ============================================================================
-- SIBAL — 0004_hardening.sql
-- Dua cacat yang baru terlihat setelah migration dijalankan ke database nyata:
--
--   1. ESKALASI HAK LEWAT SIGNUP. app.handle_new_user() mengambil role dari
--      raw_user_meta_data. Field itu diisi klien saat signUp(), jadi siapa pun
--      bisa mendaftar dengan {role:'admin'} dan langsung jadi admin — melewati
--      seluruh pembatasan GRANT yang sudah dipasang. Terverifikasi: profile
--      hasil signup semacam itu benar-benar ber-role 'admin'.
--
--   2. sibal_report_issue() selalu gagal dengan SQLSTATE 42702 "column
--      reference status is ambiguous". Penyebabnya RETURNS TABLE: nama kolom
--      OUT (report_id, status, reused, msg) ikut menjadi variabel PL/pgSQL,
--      sehingga `select lab_id, status into ...` dan `where status in (...)`
--      ambigu. Artinya fungsi paling sering dipakai di aplikasi tidak pernah
--      bisa dipanggil sama sekali.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Signup tidak pernah melahirkan admin.
--    Role hanya bisa naik lewat public.sibal_set_user_role(), yang menuntut
--    operator admin aktif — jadi rantai kepercayaannya tunggal.
--
--    Konsekuensi: admin pertama harus di-bootstrap manual oleh pemilik database
--    (SQL Editor dashboard, bukan dari aplikasi):
--
--      update public.profiles set role = 'admin' where username = 'namaadmin';
--
--    Setelah itu admin pertama bisa mengangkat admin lain lewat Retool.
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

  -- role sengaja dipatok 'user'. Jangan pernah membaca new.raw_user_meta_data
  -- untuk role: field itu datang dari klien.
  insert into public.profiles (id, username, full_name, role)
  values (new.id, v_username, v_fullname, 'user'::public.app_role)
  on conflict (id) do nothing;
  return new;
end $$;

-- ----------------------------------------------------------------------------
-- 2. use_column: nama ambigu diselesaikan sebagai kolom tabel, bukan variabel.
--    Aman di sini karena tidak ada query di badan fungsi yang memang bermaksud
--    memakai kolom OUT — semuanya memakai variabel berprefiks v_.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_report_issue(
  p_pc_id uuid default null,
  p_supporting_item_id uuid default null,
  p_issue text default null,
  p_severity public.report_severity default 'sedang',
  p_evidence_paths text[] default '{}'
) returns table (report_id uuid, status public.report_status, reused boolean, msg text)
language plpgsql security definer set search_path = public, pg_temp as $$
#variable_conflict use_column
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

-- Grant EXECUTE ikut hilang saat fungsi dibuat ulang? Tidak — CREATE OR REPLACE
-- mempertahankan ACL. Tapi DO-loop di 0002 sudah menjamin anon/public dicabut,
-- dan fungsi ini tidak pernah berubah kepemilikannya, jadi tidak perlu diulang.
