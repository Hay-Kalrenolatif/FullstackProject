-- ============================================================================
-- SIBAL — 0006_admin_rpc.sql
-- Panel admin Flutter Web masuk sebagai role `authenticated`, dan 0002 §3
-- sengaja TIDAK memberi authenticated hak tulis apa pun atas tabel bisnis.
-- Artinya: setiap aksi admin harus menjadi function di file ini, bukan query
-- dari klien. Ini bukan birokrasi — jalur tulis langsung adalah cara satu-satunya
-- perubahan data terjadi tanpa jejak operator, dan jejak itulah isi tugas ini.
--
-- Pola dipertahankan identik dengan 0002/0005: `security definer`, search_path
-- dikunci, dibuka dengan app.resolve_admin(), dan perubahan yang wajib
-- meninggalkan jejak (status aset, stok) ditulis ke maintenance_histories dalam
-- transaksi yang sama.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Helper kolom teks
--    Konvensi: NULL  = tidak dikirim  -> pertahankan nilai lama
--              ''    = dikirim kosong -> kosongkan kolom
--              nilai = trim lalu tulis
--    Tanpa konvensi ini, form edit tidak punya cara untuk mengosongkan catatan;
--    dengan `coalesce(p_new, col)` polos, kolom NOT NULL bisa diam-diam berubah
--    jadi string kosong. Kolom wajib (processor, ram, name) tidak lewat sini —
--    mereka divalidasi eksplisit supaya pesannya jelas.
-- ----------------------------------------------------------------------------
create or replace function app.text_field(p_new text, p_old text) returns text
language sql immutable as $$
  select case
    when p_new is null   then p_old
    when btrim(p_new) = '' then null::text
    else btrim(p_new)
  end
$$;
comment on function app.text_field(text, text) is
  'Aturan tulis satu kolom teks: null=jangan ubah, string kosong=kosongkan.';

-- ----------------------------------------------------------------------------
-- 2. sibal_update_pc — koreksi spesifikasi PC
--    `status` TIDAK diterima di sini dan tidak perlu ditolak: trigger
--    trg_pcs_status_guard hanya menyala untuk `update of status`, jadi fungsi ini
--    secara struktural tidak bisa mengubahnya. Jalur status = sibal_set_asset_status.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_update_pc(
  p_pc_id uuid,
  p_processor text,
  p_ram text,
  p_storage text default null,
  p_gpu text default null,
  p_mouse_spec text default null,
  p_keyboard_spec text default null,
  p_location text default null,
  p_notes text default null,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
begin
  if coalesce(btrim(p_processor), '') = '' then raise exception 'Processor wajib diisi'; end if;
  if coalesce(btrim(p_ram), '')        = '' then raise exception 'RAM wajib diisi'; end if;

  update public.pcs
     set processor     = btrim(p_processor),
         ram           = btrim(p_ram),
         storage       = app.text_field(p_storage, storage),
         gpu           = app.text_field(p_gpu, gpu),
         mouse_spec    = app.text_field(p_mouse_spec, mouse_spec),
         keyboard_spec = app.text_field(p_keyboard_spec, keyboard_spec),
         location      = app.text_field(p_location, location),
         notes         = app.text_field(p_notes, notes)
   where id = p_pc_id;

  if not found then raise exception 'PC tidak ditemukan'; end if;
end $$;

-- ----------------------------------------------------------------------------
-- 3. sibal_update_supporting_item — koreksi barang + penyesuaian stok
--    Stok hanya boleh bergerak lewat parameter ini, dan setiap gerakan wajib
--    beralasan serta meninggalkan baris riwayat. Itu sebabnya `qty` tidak bisa
--    dibiarkan sebagai kolom yang diedit langsung: angka stok yang berubah tanpa
--    jejak membuat persentase kesiapan di Beranda tidak bisa dipertanggungjawabkan.
--    Arah gerakan memakai kategori yang sudah ada: masuk = 'pelengkapan',
--    keluar = 'purnatugas'. Status (mis. jadi 'habis') tetap keputusan terpisah
--    lewat sibal_set_asset_status, agar stok dan kondisi tidak tertukar.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_update_supporting_item(
  p_supporting_item_id uuid,
  p_name text,
  p_category public.support_category default null,
  p_specifications text default null,
  p_unit text default null,
  p_location text default null,
  p_notes text default null,
  p_qty integer default null,
  p_reason text default null,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  v_lab uuid; v_old_name text; v_old_qty int; v_delta int;
  v_actor_name text := coalesce((select full_name from public.profiles where id = v_admin), 'Admin');
begin
  if coalesce(btrim(p_name), '') = '' then raise exception 'Nama barang wajib diisi'; end if;

  select lab_id, name, qty into v_lab, v_old_name, v_old_qty
    from public.supporting_items where id = p_supporting_item_id for update;
  if not found then raise exception 'Barang tidak ditemukan'; end if;

  -- Nama unik per Lab (support_name_per_lab). Dicek di sini agar pesannya
  -- "nama sudah dipakai di Lab ini", bukan 23505 dari index yang tidak jelas.
  if lower(btrim(p_name)) <> lower(v_old_name)
     and exists (select 1 from public.supporting_items o
                  where o.lab_id = v_lab and lower(o.name) = lower(btrim(p_name))
                    and o.id <> p_supporting_item_id) then
    raise exception 'Nama % sudah dipakai barang lain di Lab ini', btrim(p_name);
  end if;

  if p_qty is not null then
    if p_qty < 0 or p_qty > 100000 then raise exception 'Jumlah harus antara 0 dan 100000'; end if;
    v_delta := p_qty - v_old_qty;
    if v_delta <> 0 and char_length(coalesce(btrim(p_reason), '')) < 3 then
      raise exception 'Alasan wajib diisi untuk setiap perubahan stok';
    end if;
  else
    v_delta := 0;
  end if;

  update public.supporting_items
     set name           = btrim(p_name),
         category       = coalesce(p_category, category),
         specifications = app.text_field(p_specifications, specifications),
         unit           = app.text_field(p_unit, unit),
         location       = app.text_field(p_location, location),
         notes          = app.text_field(p_notes, notes),
         qty            = coalesce(p_qty, qty)
   where id = p_supporting_item_id;

  if v_delta <> 0 then
    insert into public.maintenance_histories
      (report_id, lab_id, pc_id, supporting_item_id, category, status, notes, action_taken,
       performed_by, performed_by_name, completed_at, qty_delta)
    values (null, v_lab, null, p_supporting_item_id,
            case when v_delta > 0 then 'pelengkapan'::public.maintenance_kind
                 else 'purnatugas'::public.maintenance_kind end,
            'selesai'::public.maintenance_status,
            btrim(p_reason),
            format('Penyesuaian stok %s%s %s (sebelum %s, sesudah %s)',
                   case when v_delta > 0 then '+' else '' end, v_delta, btrim(p_name),
                   v_old_qty, p_qty),
            v_admin, v_actor_name, now(), v_delta);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 4. sibal_upsert_announcement — Broadcast di splash/Beranda
--    Tidak ada padanannya di sisi klien, dan tabel ini memang satu-satunya yang
--    isinya bukan aset, jadi penulisannya tidak memerlukan jejak riwayat.
--    published_at tidak pernah dikosongkan: CHECK ann_published_needs_date menuntut
--    nilai saat tayang, dan membekukan tanggal tayang pertama lebih jujur daripada
--    menghapusnya saat admin menyembunyikan pengumuman.
--    `p_id` diberi default NULL karena PostgREST mencocokkan function lewat
--    **nama argumen yang dikirim klien**: argumen tanpa default yang tidak dikirim
--    membuat pemanggilan gagal dengan PGRST202, bukan dengan pesan yang jelas.
--    Aturan Postgres melanjutkan itu: begitu satu parameter punya default, semua
--    sesudahnya wajib punya default — karena itu p_title/p_body juga diberi
--    `default null` dan panjangnya divalidasi di badan function, bukan di tanda tangan.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_upsert_announcement(
  p_id uuid default null,
  p_title text default null,
  p_body text default null,
  p_level public.announcement_level default 'info',
  p_is_published boolean default true,
  p_expires_at timestamptz default null,
  p_operator_email text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
  a public.announcements;
  v_pub timestamptz;
begin
  if char_length(coalesce(btrim(p_title), '')) < 3 then
    raise exception 'Judul minimal 3 karakter';
  end if;
  if char_length(btrim(p_title)) > 120 then raise exception 'Judul maksimal 120 karakter'; end if;
  if char_length(coalesce(btrim(p_body), '')) < 1 then raise exception 'Isi pengumuman wajib diisi'; end if;
  if char_length(btrim(p_body)) > 2000 then raise exception 'Isi pengumuman maksimal 2000 karakter'; end if;

  if p_id is null then
    v_pub := case when p_is_published then now() end;
    if p_expires_at is not null and p_expires_at <= v_pub then
      raise exception 'Batas tayang harus sesudah waktu tayang';
    end if;
    insert into public.announcements
      (title, body, level, is_published, published_at, expires_at, created_by)
    values (btrim(p_title), btrim(p_body), p_level, p_is_published, v_pub, p_expires_at, v_admin)
    returning id into p_id;
    return p_id;
  end if;

  select * into a from public.announcements where id = p_id for update;
  if not found then raise exception 'Pengumuman tidak ditemukan'; end if;

  -- Sudah tayang dan masih tayang -> tanggal tayang lama dipertahankan.
  -- Belum tayang -> tayang sekarang. Dihentikan -> tanggal lama dibekukan.
  v_pub := case
             when not p_is_published then a.published_at
             when a.published_at is not null then a.published_at
             else now()
           end;
  if p_expires_at is not null and p_expires_at <= coalesce(v_pub, a.created_at) then
    raise exception 'Batas tayang harus sesudah waktu tayang';
  end if;

  update public.announcements
     set title = btrim(p_title), body = btrim(p_body), level = p_level,
         is_published = p_is_published, published_at = v_pub, expires_at = p_expires_at
   where id = a.id;
  return a.id;
end $$;

-- ----------------------------------------------------------------------------
-- 5. sibal_delete_announcement
--    Pengumuman tidak punya FK yang menunjuknya dan tidak perlu diarsipkan:
--    yang harus kekal adalah riwayat pekerjaan, bukan pengumuman yang sudah lewat.
--    Untuk menyembunyikan tanpa menghapus, admin memakai is_published = false.
-- ----------------------------------------------------------------------------
create or replace function public.sibal_delete_announcement(
  p_id uuid,
  p_operator_email text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_admin uuid := app.resolve_admin(p_operator_email);
begin
  delete from public.announcements where id = p_id;
  if not found then raise exception 'Pengumuman tidak ditemukan'; end if;
end $$;

-- ----------------------------------------------------------------------------
-- 6. Hak jalan — loop yang sama dengan 0002 §6 diulang karena function di atas
--    lahir setelah loop itu dijalankan. Anon tetap tidak boleh mengeksekusi:
--    resolve_admin hanya menerima email operator ketika auth.uid() NULL, dan itu
--    reachable dari koneksi langsung — bukan dari PostgREST selama anon di-cabut.
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

grant execute on function app.text_field(text, text) to authenticated;
