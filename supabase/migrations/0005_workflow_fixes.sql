-- ============================================================================
-- SIBAL — 0005_workflow_fixes.sql
-- Lima cacat yang baru terlihat setelah alur kerja dijalankan sungguhan
-- terhadap database nyata (verifikasi 18 tes pertama lolos, lalu berhenti di
-- approve). Semua perbaikan di sini adalah CREATE OR REPLACE, jadi ACL hasil
-- DO-loop di 0002 tetap utuh.
--
--   1. BLOKIR TOTAL: Periksa → Approve selalu gagal dengan
--      "duplicate key value violates unique constraint mh_one_open_job".
--      sibal_check_report sudah membuat pekerjaan 'tertunda' untuk tiket itu,
--      lalu sibal_approve_report menyisipkan pekerjaan kedua. Index unik
--      satu-pekerjaan-terbuka-per-tiket menolak. Artinya tombol utama di Retool
--      tidak pernah bisa dipakai berurutan.
--
--   2. Aset nyangkut di 'diperiksa'. reject/cancel hanya memulihkan status
--      bila aset masih 'dalam_pengajuan'. Setelah diperiksa, aset berstatus
--      'diperiksa', jadi menolak tiket yang sudah diperiksa meninggalkan aset
--      pada status itu selamanya — tidak ada RPC yang bisa mengembalikannya
--      kecuali set_asset_status manual.
--
--   3. Pekerjaan yatim. reject tidak menutup pekerjaan 'tertunda' milik
--      tiket yang ditolak, jadi tab Riwayat di Retool selamanya menampilkan
--      pekerjaan yang masih berjalan untuk tiket yang sudah mati.
--
--   4. Buku stok tidak reconcile. complete_maintenance menggerakkan qty tapi
--      tidak mencatatnya ke maintenance_histories.qty_delta, sehingga jumlah
--      pergerakan di riwayat lebih kecil daripada perubahan stok sebenarnya.
--
--   5. reopen menimpa keputusan lain. sibal_reopen_report memaksa aset ke
--      'dalam_pengajuan' tanpa melihat statusnya sekarang, jadi membuka tiket
--      lama untuk aset yang sudah dipurnatugaskan menghidupkannya kembali.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Approve memakai ulang pekerjaan terbuka yang sudah ada, bukan menyisip
--    baru. Jejak pengecekan dipertahankan di notes supaya tidak hilang.
-- ----------------------------------------------------------------------------
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
  v_prev_action text;
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

  select id, action_taken into v_mh, v_prev_action
    from public.maintenance_histories
   where report_id = r.id and status in ('tertunda', 'berjalan')
   for update;

  if found then
    update public.maintenance_histories
       set category = p_kind,
           status = 'berjalan',
           action_taken = trim(p_action_taken),
           performed_by = coalesce(p_performed_by, v_admin),
           performed_by_name = v_actor_name,
           qty_delta = case when r.supporting_item_id is not null then p_qty_delta else 0 end,
           notes = case
                     when nullif(trim(v_prev_action), '') is null then notes
                     else trim(coalesce(notes || E'\n', '') || 'Pengecekan: ' || trim(v_prev_action))
                   end
     where id = v_mh;
  else
    insert into public.maintenance_histories
      (report_id, lab_id, pc_id, supporting_item_id, category, status, action_taken,
       performed_by, performed_by_name, qty_delta)
    values (r.id, r.lab_id, r.pc_id, r.supporting_item_id, p_kind, 'berjalan',
            trim(p_action_taken), coalesce(p_performed_by, v_admin), v_actor_name,
            case when r.supporting_item_id is not null then p_qty_delta else 0 end)
    returning id into v_mh;
  end if;

  update public.reports
     set status = 'diproses', reviewed_by = v_admin,
         admin_notes = coalesce(admin_notes, trim(p_action_taken)), decided_at = now()
   where id = r.id;
  return v_mh;
end $$;

-- ----------------------------------------------------------------------------
-- 2 + 3. Reject memulihkan aset dari 'dalam_pengajuan' MAUPUN 'diperiksa',
--        dan menutup pekerjaan terbuka milik tiket itu.
-- ----------------------------------------------------------------------------
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
  -- Kembalikan hanya bila aset masih di jalur tiket ini. Kalau admin lain sudah
  -- memindahkannya ke rusak/purnatugas, keputusan itu tidak ditimpa.
  if r.pc_id is not null then
    select status into v_cur from public.pcs where id = v_tid for update;
    if v_cur in ('dalam_pengajuan', 'diperiksa') then
      update public.pcs set status = r.prev_asset_status where id = v_tid;
    end if;
  else
    select status into v_cur from public.supporting_items where id = v_tid for update;
    if v_cur in ('dalam_pengajuan', 'diperiksa') then
      update public.supporting_items set status = r.prev_asset_status where id = v_tid;
    end if;
  end if;

  update public.maintenance_histories
     set status = 'dibatalkan',
         completed_at = now(),
         notes = trim(coalesce(notes || E'\n', '') || 'Pengajuan ditolak: ' || trim(p_reason))
   where report_id = r.id and status in ('tertunda', 'berjalan');

  update public.reports
     set status = 'ditolak', reviewed_by = v_admin,
         admin_notes = trim(p_reason), decided_at = now()
   where id = r.id;
end $$;

-- ----------------------------------------------------------------------------
-- 4. Pergerakan stok saat penyelesaian ikut tercatat di qty_delta, sehingga
--    satu baris riwayat memuat SELURUH pergerakan milik pekerjaan itu.
--    p_qty_delta di sini adalah TAMBAHAN di luar yang sudah diterapkan approve;
--    biarkan 0 bila tidak ada barang yang masuk/keluar saat penutupan.
-- ----------------------------------------------------------------------------
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
    if p_qty_delta <> 0 then raise exception 'Perubahan stok hanya untuk barang pendukung'; end if;
    update public.pcs set status = p_outcome where id = v_tid;
  else
    update public.supporting_items
       set status = p_outcome, qty = qty + p_qty_delta
     where id = v_tid;
  end if;

  update public.maintenance_histories
     set status = 'selesai',
         qty_delta = qty_delta + case when m.pc_id is null then p_qty_delta else 0 end,
         notes = case when nullif(trim(p_notes), '') is null then notes
                      else coalesce(notes || E'\n', '') || trim(p_notes) end,
         completed_at = now()
   where id = m.id;

  if m.report_id is not null then
    update public.reports set status = 'selesai', decided_at = now()
     where id = m.report_id and status = 'diproses';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 5. Reopen tidak menghidupkan aset yang sudah dipurnatugaskan.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_reopen_report(
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
  if char_length(coalesce(trim(p_reason), '')) < 3 then raise exception 'Alasan wajib diisi'; end if;
  select * into r from public.reports where id = p_report_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan'; end if;
  if r.status not in ('selesai', 'ditolak', 'batal') then
    raise exception 'Hanya tiket selesai/ditolak/batal yang bisa dibuka lagi';
  end if;

  v_tid := coalesce(r.pc_id, r.supporting_item_id);
  if r.pc_id is not null then
    select status into v_cur from public.pcs where id = v_tid for update;
    if v_cur is distinct from 'purnatugas' then
      update public.pcs set status = 'dalam_pengajuan' where id = v_tid;
    end if;
  else
    select status into v_cur from public.supporting_items where id = v_tid for update;
    if v_cur is distinct from 'purnatugas' then
      update public.supporting_items set status = 'dalam_pengajuan' where id = v_tid;
    end if;
  end if;

  update public.reports
     set status = 'menunggu', reviewed_by = v_admin,
         admin_notes = trim(p_reason), decided_at = now()
   where id = r.id;
end $$;
