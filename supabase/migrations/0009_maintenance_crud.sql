-- ----------------------------------------------------------------------------
-- 0009 — CRUD riwayat pemeliharaan mandiri (di luar pengajuan).
--
-- Skema sudah menyiapkan `maintenance_histories.report_id` NULL untuk inspeksi
-- rutin, tetapi sampai migration ini tidak ada jalur tulis untuk membuat baris
-- seperti itu: panel hanya bisa menutup pekerjaan yang lahir dari approve.
-- Tiga function di bawah membuka jalur itu untuk admin, dengan aturan yang sama
-- seperti jalur pengajuan: satu transaksi, jejak stok beralasan, dan tidak ada
-- cara menghapus jejak approval atau gerakan stok.
--
-- Bentuk yang disengaja:
--   * Create membuka pekerjaan ('berjalan') ATAU mencatat pekerjaan yang sudah
--     selesai (`p_selesai = true`). Delta stok hanya boleh menyertai bentuk
--     kedua; pekerjaan terbuka menggeser stok saat sibal_complete_maintenance,
--     supaya delta yang sama tidak bergerak dua kali.
--   * Update hanya kolom deskriptif (kategori, tindakan, catatan, tanggal).
--     Status, target, dan stok tidak punya parameter di sini — status lewat
--     sibal_complete_maintenance / sibal_set_asset_status, stok lewat buku stok.
--   * Delete hanya untuk riwayat mandiri tanpa gerakan stok. Riwayat terkait
--     pengajuan adalah jejak approval; riwayat yang menggeser stok adalah buku
--     stok — keduanya tidak boleh hilang karena hapus baris.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- 1. sibal_create_maintenance — catat pemeliharaan/perbaikan di luar pengajuan
-- ----------------------------------------------------------------------------
create or replace function public.sibal_create_maintenance(
  p_pc_id uuid default null,
  p_supporting_item_id uuid default null,
  p_category public.maintenance_kind default 'inspeksi',
  p_action_taken text default null,
  p_notes text default null,
  p_maintenance_date date default null,
  p_selesai boolean default false,
  p_performed_by uuid default null,
  p_qty_delta integer default 0,
  p_reason text default null,
  p_operator_email text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  v_lab uuid;
  v_actor uuid;
  v_actor_name text;
  v_qty int;
  v_id uuid;
begin
  perform app.allow_rpc_write();

  if num_nonnulls(p_pc_id, p_supporting_item_id) <> 1 then
    raise exception 'Pilih tepat satu target: PC atau barang pendukung';
  end if;
  if char_length(coalesce(btrim(p_action_taken), '')) not between 3 and 2000 then
    raise exception 'Tindakan wajib diisi, 3 sampai 2000 karakter';
  end if;

  if p_pc_id is not null then
    select lab_id into v_lab from public.pcs where id = p_pc_id;
    if not found then raise exception 'PC tidak ditemukan'; end if;
    if p_qty_delta <> 0 then
      raise exception 'Perubahan stok hanya untuk barang pendukung';
    end if;
  else
    select lab_id, qty into v_lab, v_qty
      from public.supporting_items where id = p_supporting_item_id for update;
    if not found then raise exception 'Barang tidak ditemukan'; end if;
  end if;

  if p_qty_delta <> 0 then
    if not p_selesai then
      raise exception 'Delta stok hanya untuk pekerjaan yang langsung selesai; '
                      'pekerjaan terbuka menggeser stok saat penutupan';
    end if;
    if char_length(coalesce(btrim(p_reason), '')) < 3 then
      raise exception 'Alasan wajib diisi untuk setiap perubahan stok';
    end if;
    if v_qty + p_qty_delta < 0 then
      raise exception 'Stok tidak boleh negatif (sekarang %)', v_qty;
    end if;
    update public.supporting_items set qty = qty + p_qty_delta
     where id = p_supporting_item_id;
  end if;

  v_actor := coalesce(p_performed_by, v_admin);
  select full_name into v_actor_name from public.profiles where id = v_actor;
  if not found then raise exception 'Petugas tidak ditemukan'; end if;

  insert into public.maintenance_histories
    (report_id, lab_id, pc_id, supporting_item_id, category, status, notes,
     action_taken, performed_by, performed_by_name, maintenance_date,
     completed_at, qty_delta)
  values
    (null, v_lab, p_pc_id, p_supporting_item_id, p_category,
     case when p_selesai then 'selesai'::public.maintenance_status
          else 'berjalan'::public.maintenance_status end,
     nullif(btrim(p_notes), ''),
     btrim(p_action_taken), v_actor, v_actor_name,
     coalesce(p_maintenance_date, (now() at time zone 'Asia/Jakarta')::date),
     case when p_selesai then now() else null end,
     p_qty_delta)
  returning id into v_id;

  return v_id;
end $$;

-- ----------------------------------------------------------------------------
-- 2. sibal_update_maintenance — koreksi catatan pekerjaan, bukan hasilnya
--    Konvensi teks sama dengan 0006: null = jangan ubah, '' = kosongkan
--    (khusus notes; action_taken tidak boleh kosong karena CHECK skema).
-- ----------------------------------------------------------------------------
create or replace function public.sibal_update_maintenance(
  p_maintenance_id uuid,
  p_category public.maintenance_kind default null,
  p_action_taken text default null,
  p_notes text default null,
  p_maintenance_date date default null,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  m public.maintenance_histories;
  v_action text;
begin
  perform app.allow_rpc_write();
  select * into m from public.maintenance_histories where id = p_maintenance_id for update;
  if not found then raise exception 'Riwayat pekerjaan tidak ditemukan'; end if;

  v_action := coalesce(btrim(p_action_taken), m.action_taken);
  if char_length(v_action) not between 3 and 2000 then
    raise exception 'Tindakan wajib diisi, 3 sampai 2000 karakter';
  end if;

  update public.maintenance_histories
     set category         = coalesce(p_category, category),
         action_taken     = v_action,
         notes            = app.text_field(p_notes, notes),
         maintenance_date = coalesce(p_maintenance_date, maintenance_date)
   where id = m.id;
end $$;

-- ----------------------------------------------------------------------------
-- 3. sibal_delete_maintenance — hapus catatan mandiri yang belum berjejak
-- ----------------------------------------------------------------------------
create or replace function public.sibal_delete_maintenance(
  p_maintenance_id uuid,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  m public.maintenance_histories;
begin
  perform app.allow_rpc_write();
  select * into m from public.maintenance_histories where id = p_maintenance_id for update;
  if not found then raise exception 'Riwayat pekerjaan tidak ditemukan'; end if;

  if m.report_id is not null then
    raise exception 'Riwayat terkait pengajuan tidak boleh dihapus: itu jejak approval';
  end if;
  if m.qty_delta <> 0 then
    raise exception 'Riwayat yang menggeser stok tidak boleh dihapus: buat penyesuaian balik lewat tab Aset';
  end if;

  delete from public.maintenance_histories where id = m.id;
end $$;

-- ----------------------------------------------------------------------------
-- 4. Hak jalan — loop yang sama dengan 0002 §6 / 0006 §6: function baru lahir
--    setelah loop itu, jadi cabut anon dan beri authenticated di sini.
-- ----------------------------------------------------------------------------
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

notify pgrst, 'reload schema';