#!/usr/bin/env python3
"""Generator dokumen Word "Skenario Use Case SIBAL" (.docx).

Menyusun skenario use case mendetail (gaya Cockburn: aksi aktor vs respons
sistem, alur utama / alternatif / pengecualian, aturan bisnis) untuk seluruh
use case aplikasi mobile + panel admin, selaras dengan use_case diagram
(docs/perancangan) dan kode nyata di lib/.

    python docs/perancangan/tools/gen_skenario_usecase.py

Butuh: python-docx  (pip install python-docx)
Keluaran: docs/perancangan/Skenario_Use_Case_SIBAL.docx
"""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# ---------------------------------------------------------------------------
# Palet & font
# ---------------------------------------------------------------------------
NAVY = RGBColor(0x1F, 0x38, 0x64)
BLUE = RGBColor(0x2E, 0x54, 0x96)
INK = RGBColor(0x22, 0x22, 0x22)
GREY = RGBColor(0x55, 0x55, 0x55)
HDR_BG = "1F3864"
ALT_BG = "EEF3FB"
LABEL_BG = "DCE6F5"
FONT = "Calibri"


# ---------------------------------------------------------------------------
# Helper XML rendah-tinggi
# ---------------------------------------------------------------------------
def shade(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr()
    sh = OxmlElement('w:shd')
    sh.set(qn('w:val'), 'clear')
    sh.set(qn('w:color'), 'auto')
    sh.set(qn('w:fill'), hexcolor)
    tcPr.append(sh)


def cell_margins(cell, top=60, bottom=60, left=110, right=110):
    tcPr = cell._tc.get_or_add_tcPr()
    m = OxmlElement('w:tcMar')
    for tag, val in (('top', top), ('bottom', bottom), ('start', left), ('end', right)):
        e = OxmlElement(f'w:{tag}')
        e.set(qn('w:w'), str(val))
        e.set(qn('w:type'), 'dxa')
        m.append(e)
    tcPr.append(m)


def table_borders(table, color="B7C3D9", sz=4):
    tbl = table._tbl
    tblPr = tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for edge in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        e = OxmlElement(f'w:{edge}')
        e.set(qn('w:val'), 'single')
        e.set(qn('w:sz'), str(sz))
        e.set(qn('w:space'), '0')
        e.set(qn('w:color'), color)
        borders.append(e)
    tblPr.append(borders)


def set_repeat_header(row):
    trPr = row._tr.get_or_add_trPr()
    th = OxmlElement('w:tblHeader')
    th.set(qn('w:val'), 'true')
    trPr.append(th)


def no_split(row):
    trPr = row._tr.get_or_add_trPr()
    cs = OxmlElement('w:cantSplit')
    trPr.append(cs)


def style_run(run, size=11, bold=False, color=INK, italic=False, font=FONT):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    rpr = run._element.get_or_add_rPr()
    rf = rpr.find(qn('w:rFonts'))
    if rf is None:
        rf = OxmlElement('w:rFonts')
        rpr.append(rf)
    rf.set(qn('w:ascii'), font)
    rf.set(qn('w:hAnsi'), font)


def cell_text(cell, text, size=10.5, bold=False, color=INK, align=None, italic=False):
    cell.text = ''
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.space_before = Pt(2)
    if align is not None:
        p.alignment = align
    # dukung multi-baris
    lines = text.split('\n')
    for i, ln in enumerate(lines):
        if i > 0:
            p = cell.add_paragraph()
            p.paragraph_format.space_after = Pt(2)
            if align is not None:
                p.alignment = align
        r = p.add_run(ln)
        style_run(r, size=size, bold=bold, color=color, italic=italic)
    return cell


# ---------------------------------------------------------------------------
# Builder dokumen
# ---------------------------------------------------------------------------
doc = Document()

# Gaya dasar
normal = doc.styles['Normal']
normal.font.name = FONT
normal.font.size = Pt(11)
normal.font.color.rgb = INK
normal.paragraph_format.space_after = Pt(6)
normal.paragraph_format.line_spacing = 1.08

for name, sz, col in (('Heading 1', 16, NAVY), ('Heading 2', 13, BLUE), ('Heading 3', 11.5, BLUE)):
    st = doc.styles[name]
    st.font.name = FONT
    st.font.size = Pt(sz)
    st.font.bold = True
    st.font.color.rgb = col
    st.paragraph_format.space_before = Pt(12)
    st.paragraph_format.space_after = Pt(6)
    st.paragraph_format.keep_with_next = True

# Halaman A4 + margin
sec = doc.sections[0]
sec.page_width = Cm(21.0)
sec.page_height = Cm(29.7)
sec.top_margin = Cm(2.2)
sec.bottom_margin = Cm(2.0)
sec.left_margin = Cm(2.2)
sec.right_margin = Cm(2.2)


def para(text='', size=11, bold=False, color=INK, align=None, italic=False,
         space_after=6, space_before=0):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.space_before = Pt(space_before)
    if align is not None:
        p.alignment = align
    if text:
        r = p.add_run(text)
        style_run(r, size=size, bold=bold, color=color, italic=italic)
    return p


def bullet(text, size=11, bold_lead=None):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_after = Pt(3)
    if bold_lead:
        r = p.add_run(bold_lead)
        style_run(r, size=size, bold=True)
        r2 = p.add_run(text)
        style_run(r2, size=size)
    else:
        r = p.add_run(text)
        style_run(r, size=size)
    return p


def numbered(text, size=11):
    p = doc.add_paragraph(style='List Number')
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(text)
    style_run(r, size=size)
    return p


def make_table(headers, rows, widths=None, header_bg=HDR_BG, zebra=True,
               body_size=10.5, first_col_bold=False):
    t = doc.add_table(rows=1, cols=len(headers))
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    table_borders(t)
    hdr = t.rows[0]
    set_repeat_header(hdr)
    no_split(hdr)
    for i, h in enumerate(headers):
        c = hdr.cells[i]
        shade(c, header_bg)
        cell_margins(c)
        cell_text(c, h, size=10.5, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
    for ri, row in enumerate(rows):
        tr = t.add_row()
        no_split(tr)
        for ci, val in enumerate(row):
            c = tr.cells[ci]
            cell_margins(c)
            if zebra and ri % 2 == 1:
                shade(c, ALT_BG)
            cell_text(c, str(val), size=body_size,
                      bold=(first_col_bold and ci == 0))
    if widths:
        for ci, w in enumerate(widths):
            for row in t.rows:
                row.cells[ci].width = Cm(w)
    return t


def kv_table(pairs, label_w=4.3, val_w=12.3):
    t = doc.add_table(rows=0, cols=2)
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    table_borders(t)
    for k, v in pairs:
        tr = t.add_row()
        no_split(tr)
        lc, vc = tr.cells
        lc.width = Cm(label_w)
        vc.width = Cm(val_w)
        shade(lc, LABEL_BG)
        cell_margins(lc)
        cell_margins(vc)
        cell_text(lc, k, size=10.5, bold=True, color=NAVY)
        cell_text(vc, v, size=10.5)
    return t


def flow_table(steps):
    """steps: list (aksi_aktor, respons_sistem). Kolom No otomatis."""
    rows = [(str(i + 1), a, b) for i, (a, b) in enumerate(steps)]
    return make_table(['No', 'Aksi Aktor', 'Respons Sistem'], rows,
                      widths=[1.0, 6.3, 9.3], body_size=10.5)


def branch_table(items):
    """items: list (kode, kondisi, penanganan)."""
    return make_table(['Kode', 'Kondisi / Pemicu', 'Penanganan / Langkah'],
                      items, widths=[1.3, 5.0, 10.3], body_size=10.5,
                      first_col_bold=True)


def spacer(pt=4):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(pt)
    p.paragraph_format.space_before = Pt(0)
    return p


# ---------------------------------------------------------------------------
# Footer: nomor halaman
# ---------------------------------------------------------------------------
def add_page_footer(section):
    footer = section.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run('SIBAL — Skenario Use Case  ·  Halaman ')
    style_run(r, size=9, color=GREY)
    fld = OxmlElement('w:fldSimple')
    fld.set(qn('w:instr'), 'PAGE')
    rr = OxmlElement('w:r')
    rt = OxmlElement('w:t')
    rt.text = '1'
    rr.append(rt)
    fld.append(rr)
    p._p.append(fld)


add_page_footer(sec)


# ===========================================================================
# DATA SKENARIO
# ===========================================================================
# Setiap use case: dict lengkap. main = (aksi, respons). alt/exc = (kode,kondisi,penanganan).
UC = []


def uc(**kw):
    UC.append(kw)


# --- KELOMPOK A: MOBILE -----------------------------------------------------
uc(
    id='UC-01', group='A', name='Masuk (Login)',
    diagram='1. Masuk', seq='M1 · Masuk',
    actor='Pengguna / Pengelola Lab (Admin memakai alur yang sama lewat web)',
    desc='Pengguna mengautentikasi diri memakai username dan password untuk memperoleh sesi '
         'Supabase Auth, sehingga aplikasi dapat menarik data lab sesuai perannya.',
    trigger='Pengguna membuka aplikasi dan belum ada sesi tersimpan.',
    pre=['Aplikasi terpasang dan terkonfigurasi (SUPABASE_URL + publishable key).',
         'Onboarding sudah dilihat (flag perangkat tersimpan).',
         'Perangkat online; fitur "Confirm email" di dashboard Supabase dimatikan.',
         'Pengguna sudah memiliki akun (lihat UC-02 untuk mendaftar).'],
    post=['Sesi authenticated tersimpan di perangkat.',
          'Profil pengguna termuat (username, nama, peran, keaktifan).',
          'Data lab ditarik dan ditulis ke cache Hive; Beranda ditampilkan.'],
    minimal=['Tidak ada sesi dibuat bila autentikasi gagal.',
             'Form tetap terisi dan dapat diulang; tidak ada data lab yang berubah.'],
    main=[
        ('Pengguna membuka aplikasi.',
         'Sistem menampilkan layar "Masuk ke Lab Anda" berisi kolom Username dan Password '
         'serta tombol "Masuk".'),
        ('Pengguna mengisi username dan password, lalu menekan "Masuk".',
         'Sistem menurunkan email sintetis username@sibal.my.id (AppEnv.emailForUsername) '
         'dan memanggil Supabase Auth signInWithPassword.'),
        ('—',
         'Auth memverifikasi kredensial. Bila sah, sistem memuat profil (requireProfile), '
         'menyimpan sesi, lalu menampilkan pesan "Halo, {nama}. Data lab dimuat.".'),
        ('—',
         'Sistem menjalankan AppState.refresh: menarik data lab dari PostgREST dan menulis '
         'penuh ke cache Hive, lalu menampilkan Beranda (UC-03).'),
    ],
    alt=[
        ('A1', 'Pengguna belum punya akun dan menekan "Daftar".',
         'Sistem beralih ke mode pendaftaran (UC-02); kolom "Nama tampilan" ditambahkan.'),
        ('A2', 'Sesi dari pembukaan sebelumnya masih tersimpan.',
         'Sistem memulihkan sesi otomatis tanpa menampilkan form (M3), langsung menjalankan '
         'refresh dan membuka Beranda.'),
        ('A3', 'Pengguna menekan ikon mata pada kolom password.',
         'Sistem menampilkan / menyembunyikan teks password tanpa mengirim apa pun.'),
    ],
    exc=[
        ('E1', 'Username atau password salah.',
         'Auth mengembalikan kegagalan; sistem menerjemahkan pesan (mis. "Username atau '
         'password salah.") dan menampilkannya di form. Tidak ada sesi; pengguna dapat mencoba lagi.'),
        ('E2', 'Akun dinonaktifkan (is_active = false).',
         'Server menolak; sistem menampilkan pesan bahwa akun tidak aktif dan tidak membuka sesi.'),
        ('E3', 'Perangkat tidak terhubung ke cloud.',
         'Sistem menampilkan "Tidak terhubung ke cloud: …"; form tetap, pengguna dapat mengulang '
         'setelah online.'),
        ('E4', 'Konfigurasi SUPABASE_URL / key belum diisi saat build.',
         'Sistem menampilkan layar "konfigurasi belum lengkap" dan tidak melanjutkan ke form login.'),
    ],
    rules=['Login memakai username, bukan email; email sintetis diturunkan di klien dan di SQL '
           '(app.email_for_username) dengan domain sibal.my.id yang harus sama.',
           'Peran dibaca dari tabel profiles, bukan dari input pengguna.',
           'Domain .invalid tidak boleh dipakai (ditolak GoTrue); "Confirm email" wajib OFF agar '
           'login/daftar tidak berhenti di batas kirim email.'],
)

uc(
    id='UC-02', group='A', name='Daftar Akun Baru',
    diagram='cabang dari 1. Masuk', seq='M2 · Daftar akun baru',
    actor='Pengguna / Pengelola Lab (calon anggota)',
    desc='Pengguna membuat akun baru secara mandiri. Akun yang dihasilkan selalu berperan '
         'sebagai anggota (user); peran admin hanya diangkat oleh admin lain atau lewat SQL Editor.',
    trigger='Pengguna menekan "Daftar" pada layar Masuk.',
    pre=['Perangkat online.',
         '"Confirm email" dimatikan di dashboard Supabase.',
         'Username yang diinginkan belum dipakai (unik case-insensitive).'],
    post=['Akun Auth baru terbentuk dengan email sintetis username@sibal.my.id.',
          'Baris profiles dibuat oleh trigger handle_new_user dengan role = user, is_active = true.',
          'Pengguna langsung masuk dan Beranda ditampilkan.'],
    minimal=['Bila pendaftaran gagal, tidak ada akun maupun profil yang terbentuk.',
             'Form tetap terisi dan dapat diperbaiki lalu diulang.'],
    main=[
        ('Pengguna menekan "Daftar" pada layar Masuk.',
         'Sistem menampilkan mode pendaftaran: kolom "Nama tampilan", Username, Password, '
         'dan tombol "Daftar & Masuk".'),
        ('Pengguna mengisi nama tampilan, username, dan password, lalu menekan "Daftar & Masuk".',
         'Sistem memanggil AuthService.signUp dengan email sintetis; peran tidak pernah dikirim '
         'dari klien.'),
        ('—',
         'Trigger app.handle_new_user membuat profil dengan role = user. Sistem langsung '
         'signIn, memuat profil, menjalankan refresh, dan menampilkan Beranda beserta pesan sambutan.'),
    ],
    alt=[
        ('A1', 'Pengguna berubah pikiran dan menekan "Masuk".',
         'Sistem kembali ke mode login (UC-01) tanpa mengirim permintaan.'),
    ],
    exc=[
        ('E1', 'Username sudah dipakai.',
         'Index unik lower(username) menolak; sistem menampilkan pesan tabrakan dan meminta '
         'username lain.'),
        ('E2', 'Bentuk username tidak valid.',
         'Constraint profiles_username_shape (^[a-z0-9._-]{3,32}$) menolak; sistem menampilkan '
         'pesan aturan username.'),
        ('E3', 'Nama tampilan terlalu pendek / panjang.',
         'Constraint full_name (2–80 karakter) menolak; sistem meminta perbaikan.'),
        ('E4', '"Confirm email" masih ON.',
         'Signup mencoba mengirim surat lalu berhenti di over_email_send_rate_limit; sistem '
         'menampilkan kegagalan. Penanganan: matikan Confirm email di dashboard.'),
        ('E5', 'Perangkat offline.',
         'Sistem menampilkan "Tidak terhubung ke cloud"; pendaftaran tidak dilanjutkan.'),
    ],
    rules=['Signup selalu menghasilkan role = user (0004_hardening); field role dari '
           'raw_user_meta_data tidak pernah dipercaya.',
           'Tidak ada jalur mendaftar sebagai admin dari aplikasi.',
           'Password tidak pernah ditampilkan di log maupun chat.'],
)

uc(
    id='UC-03', group='A', name='Lihat Kondisi Lab (Beranda)',
    diagram='2. Lihat Kondisi Lab', seq='M4 · Muat & sinkron data; M5 · Baca pengumuman & aktivitas',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna melihat ringkasan kesiapan fasilitas laboratorium: persentase kesiapan PC, '
         'jumlah unit normal dan yang perlu servis, aktivitas terkini, serta pengumuman.',
    trigger='Pengguna membuka tab Beranda setelah masuk.',
    pre=['Pengguna sudah masuk (UC-01).',
         'Data sudah ditarik ke cache, atau perangkat offline dengan cache terakhir tersedia.'],
    post=['Ringkasan kesiapan lab terpilih ditampilkan.',
          'Pengumuman aktif dan aktivitas terkini terlihat.'],
    minimal=['Bila data belum ada, sistem menampilkan keadaan kosong, bukan angka karangan.'],
    main=[
        ('Pengguna membuka tab Beranda.',
         'Sistem menampilkan SyncBanner (status online/offline + waktu sinkron terakhir) dan '
         'LabPicker "PILIH RUANG LABORATORIUM".'),
        ('Pengguna memilih sebuah Lab.',
         'Sistem menyaring ringkasan: kartu "Kesiapan Lab" (persentase Kesiapan PC, PC Normal '
         'x/y, Perlu Servis, Riwayat Servis) dan kartu info Lab.'),
        ('—',
         'Sistem menampilkan Kategori Inventaris (Manajemen Unit PC, Inventaris Pendukung Lab, '
         'Tiket Berjalan), banner "Perlu Penanganan Teknis" bila ada tiket prioritas, dan bagian '
         '"Aktivitas Terkini".'),
        ('Pengguna mengetuk kategori atau "Buka Detail Tiket".',
         'Sistem membuka halaman terkait (UC-04 untuk PC/Inventaris, UC-07 untuk tiket).'),
    ],
    alt=[
        ('A1', 'Pengguna memilih "Semua laboratorium".',
         'Sistem menampilkan agregat seluruh lab, bukan satu lab.'),
        ('A2', 'Perangkat offline.',
         'Sistem membaca dari cache Hive; SyncBanner menyatakan offline dan tombol pengajuan '
         'dikunci (UC-11).'),
        ('A3', 'Ada pengumuman aktif.',
         'Sistem menampilkan pengumuman sesuai level (info / peringatan / penting) — UC-09.'),
    ],
    exc=[
        ('E1', 'Belum ada aktivitas / data.',
         'Sistem menampilkan "Belum ada aktivitas tercatat. Riwayat muncul setelah admin …" '
         'dan keadaan kosong, bukan error.'),
        ('E2', 'Pengguna belum login / sesi habis.',
         'AppState.refresh keluar lebih dulu tanpa memanggil cloud (menghindari deretan 401); '
         'sistem mengarahkan ke login.'),
    ],
    rules=['Semua hitungan berasal dari query (v_lab_stats, pcs, supporting_items), bukan angka palsu.',
           'Nilai mockup yang tidak punya kolom di skema (kapasitas lab, foto lab, uptime) tidak '
           'ditampilkan.'],
)

uc(
    id='UC-04', group='A', name='Lihat PC & Inventaris',
    diagram='3. Lihat PC & Inventaris', seq='M6 · Lihat daftar PC per lab; M9 · Lihat inventaris pendukung',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna menelusuri daftar unit PC dan barang inventaris pendukung per laboratorium, '
         'lengkap dengan status, spesifikasi, dan (untuk barang) jumlah stok.',
    trigger='Pengguna membuka tab PC atau tab Pendukung.',
    pre=['Pengguna sudah masuk.',
         'Data aset tersedia di cloud atau cache.'],
    post=['Daftar aset per lab ditampilkan beserta status dan spesifikasi.',
          'Detail satu aset dapat dibuka.'],
    minimal=['Daftar baca-saja; tidak ada data aset yang berubah karena membuka halaman ini.'],
    main=[
        ('Pengguna membuka tab PC (atau Pendukung).',
         'Sistem menampilkan daftar aset dikelompokkan per Lab, dengan chip status, filter '
         'status (Semua / Normal / Perlu Tindakan), dan ringkasan jumlah.'),
        ('Pengguna memilih Lab atau filter status.',
         'Sistem menyaring daftar sesuai pilihan.'),
        ('Pengguna mengetuk satu unit.',
         'Sistem membuka sheet detail: spesifikasi lengkap (prosesor, RAM, storage, GPU, mouse, '
         'keyboard), posisi, status, dan tombol tindakan.'),
        ('Pengguna menekan "Ajukan Kerusakan" pada detail.',
         'Sistem membuka formulir pengajuan (UC-05).'),
    ],
    alt=[
        ('A1', 'Tab Pendukung dipilih.',
         'Sistem menampilkan barang non-PC beserta kategori, jumlah (qty), dan satuan; detail '
         'menampilkan spesifikasi barang.'),
        ('A2', 'Perangkat offline.',
         'Daftar dibaca dari cache; tombol pengajuan dikunci (UC-11).'),
        ('A3', 'Aset sudah bermasalah / punya tiket.',
         'Tombol berubah menjadi "Lapor lagi" (mencatat saksi) atau "Batalkan Pengajuan" bila '
         'tiket milik pengguna masih terbuka.'),
    ],
    exc=[
        ('E1', 'Lab belum punya unit terdata.',
         'Sistem menampilkan "Belum ada unit komputer yang terdata di laboratorium ini."'),
    ],
    rules=['Halaman ini baca-saja terhadap inventaris; klien tidak punya hak INSERT/UPDATE tabel aset.',
           'Status memakai domain asset_status (baik, dalam_pengajuan, diperiksa, rusak, habis, '
           'purnatugas), bukan teks bebas.'],
)

uc(
    id='UC-05', group='A', name='Ajukan Laporan Kerusakan',
    diagram='4. Ajukan Laporan Kerusakan', seq='M7 · Ajukan kerusakan PC; M10 · Ajukan kerusakan barang',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna melaporkan kerusakan sebuah aset. Laporan tidak langsung mengubah inventaris '
         'menjadi rusak; admin memverifikasi lebih dulu. Satu RPC atomik memutuskan tiket baru '
         'atau pencatatan saksi pada tiket yang sudah terbuka.',
    trigger='Pengguna menekan "Ajukan Kerusakan" / "Laporkan Kerusakan" pada detail aset.',
    pre=['Pengguna sudah masuk dan perangkat online.',
         'Aset target sudah dipilih (PC atau barang).'],
    post=['Tiket baru berstatus menunggu terbentuk dengan prev_asset_status direkam, ATAU '
          'pengguna dicatat sebagai saksi pada tiket terbuka yang sudah ada.',
          'Status aset berpindah menjadi dalam_pengajuan dalam transaksi yang sama.',
          'Daftar aset dan tiket disegarkan.'],
    minimal=['Bila RPC gagal, tiket tidak dibuat dan status aset tidak bergerak (satu transaksi).',
             'Formulir tetap terbuka dengan isian pengguna.'],
    main=[
        ('Pengguna menekan "Ajukan Kerusakan".',
         'Sistem membuka sheet "Laporkan Kerusakan" menampilkan label aset dan chip status saat ini.'),
        ('Pengguna mengisi deskripsi gejala (minimal 5 karakter) dan memilih tingkat urgensi '
         '(Ringan / Sedang / Darurat; bawaan Sedang).',
         'Sistem mengaktifkan tombol "Kirim Pengajuan" begitu deskripsi memenuhi panjang minimum.'),
        ('Pengguna menekan "Kirim Pengajuan".',
         'Sistem memanggil RPC sibal_report_issue lewat AppState.submitReport (satu transaksi).'),
        ('—',
         'Server: bila belum ada tiket terbuka untuk aset itu, membuat tiket status menunggu, '
         'merekam prev_asset_status, dan memindahkan status aset ke dalam_pengajuan.'),
        ('—',
         'Sistem menutup sheet, menampilkan pesan hasil, dan menyegarkan daftar.'),
    ],
    alt=[
        ('A1', 'Aset sudah punya tiket terbuka (dilaporkan orang lain).',
         'Server tidak membuat tiket kedua; pengguna dicatat sebagai saksi (report_witness) dan '
         'pesan dikirim ke pelapor. Sistem menampilkan konfirmasi bahwa laporan sudah ada.'),
    ],
    exc=[
        ('E1', 'Deskripsi kurang dari 5 karakter.',
         'Tombol "Kirim Pengajuan" tetap nonaktif; tidak ada permintaan dikirim.'),
        ('E2', 'Perangkat offline.',
         'Sheet menampilkan panel "Butuh koneksi. Pengajuan tidak bisa diantrekan di perangkat …"; '
         'tombol kirim diganti panel peringatan. Tidak ada antrean tulis lokal.'),
        ('E3', 'RPC gagal (mis. jaringan terputus saat kirim).',
         'Sistem menampilkan pesan error (CloudFailure dibersihkan); tiket tidak dibuat, status '
         'aset tidak berubah, dan formulir tetap terbuka untuk diulang.'),
    ],
    rules=['Satu tiket terbuka per aset ditegakkan partial unique index (reports_open_pc / '
           'reports_open_support).',
           'Laporan pengguna tidak langsung membuat aset menjadi rusak — itu keputusan approve admin.',
           'Tidak ada antrean tulis offline; pengajuan butuh koneksi.'],
)

uc(
    id='UC-06', group='A', name='Batalkan Laporan',
    diagram='4a. Batalkan Laporan', seq='M8 · Batalkan pengajuan',
    actor='Pengguna / Pengelola Lab (pemilik tiket)',
    desc='Pemilik tiket membatalkan pengajuannya selagi tiket masih terbuka. Status aset '
         'dipulihkan ke keadaan sebelum dilaporkan.',
    trigger='Pengguna menekan "Batalkan Pengajuan" pada tiket miliknya.',
    pre=['Pengguna sudah masuk.',
         'Tiket milik pengguna sendiri dan masih terbuka (menunggu / diperiksa / diproses).'],
    post=['Tiket berstatus batal.',
          'Status aset dipulihkan ke prev_asset_status.',
          'Daftar pengajuan disegarkan.'],
    minimal=['Bila pembatalan gagal, tiket dan status aset tetap seperti semula.'],
    main=[
        ('Pengguna membuka "Pengajuan Saya" atau detail PC, lalu menekan "Batalkan Pengajuan".',
         'Sistem menampilkan dialog konfirmasi "Batalkan pengajuan? Status unit kembali ke '
         '{status semula}. Hanya bisa selama tiket masih terbuka."'),
        ('Pengguna menekan "Ya, batalkan".',
         'Sistem memanggil RPC sibal_cancel_report.'),
        ('—',
         'Server mengubah tiket menjadi batal dan memulihkan status aset ke prev_asset_status.'),
        ('—',
         'Sistem menampilkan "Pengajuan dibatalkan dan status aset dipulihkan." lalu menyegarkan daftar.'),
    ],
    alt=[
        ('A1', 'Pengguna menekan "Batal" pada dialog konfirmasi.',
         'Dialog ditutup; tidak ada permintaan dikirim; tiket tetap terbuka.'),
    ],
    exc=[
        ('E1', 'Tiket sudah selesai / ditolak / batal.',
         'Tombol "Batalkan Pengajuan" tidak ditampilkan (bisaDibatalkanBy salah); server juga menolak.'),
        ('E2', 'Tiket bukan milik pengguna.',
         'Server menolak pembatalan; sistem menampilkan pesan kegagalan.'),
        ('E3', 'Offline atau RPC gagal.',
         'Sistem menampilkan pesan error; tiket dan status aset tidak berubah.'),
    ],
    rules=['Hanya pemilik tiket dan hanya selama tiket terbuka yang boleh membatalkan.',
           'Use case ini merupakan «extend» dari UC-07 (Cek Status Laporan Saya).'],
)

uc(
    id='UC-07', group='A', name='Cek Status Laporan Saya',
    diagram='8. Cek Status Laporan Saya', seq='M11 · Daftar pengajuan saya',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna memantau seluruh pengajuan miliknya beserta status terkini, catatan admin, '
         'dan tindakan lanjutan (batalkan atau lihat berita acara).',
    trigger='Pengguna membuka tab "Pengajuan Saya".',
    pre=['Pengguna sudah masuk.'],
    post=['Daftar tiket milik pengguna ditampilkan dengan status dan severity.',
          'Tindakan lanjutan tersedia sesuai status tiket.'],
    minimal=['Halaman baca-saja; membuka halaman ini tidak mengubah tiket.'],
    main=[
        ('Pengguna membuka tab "Pengajuan Saya".',
         'Sistem menampilkan ringkasan (Total pengajuan, Masih menunggu admin, Disetujui & selesai, '
         'Ditolak / dibatalkan) dan daftar tiket milik pengguna.'),
        ('Pengguna membaca sebuah tiket.',
         'Sistem menampilkan status (menunggu / diperiksa / diproses / selesai / ditolak / batal), '
         'severity, target, dan catatan admin bila ada (mis. alasan penolakan).'),
        ('Pengguna memilih tindakan pada tiket.',
         'Tiket terbuka: tombol "Batalkan Pengajuan" (UC-06). Tiket selesai: "Lihat Berita Acara" '
         '(UC-08).'),
    ],
    alt=[
        ('A1', 'Pengguna belum pernah mengajukan.',
         'Sistem menampilkan keadaan kosong "Tidak Ada Pengajuan".'),
        ('A2', 'Perangkat offline.',
         'Daftar dibaca dari cache; tindakan tulis (batalkan) dikunci.'),
    ],
    exc=[
        ('E1', 'Gagal memuat dari cloud saat online.',
         'Sistem jatuh ke cache terakhir dan menampilkan banner keadaan; tidak menampilkan error palsu.'),
    ],
    rules=['Status memakai nilai wire database; alasan penolakan dari admin_notes tampil ke pelapor.',
           'Tombol batalkan hanya muncul bila bisaDibatalkanBy (pemilik + tiket terbuka).'],
)

uc(
    id='UC-08', group='A', name='Buka Berita Acara Servis',
    diagram='jalur mandiri (rincian UC-07)', seq='M12 · Buka Berita Acara servis',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna melihat rincian pekerjaan pemeliharaan yang sudah direkam admin sebagai '
         '"Berita Acara Servis" — sumber nyata dari maintenance_histories.',
    trigger='Pengguna menekan "Berita Acara" / "Lihat Berita Acara" pada tiket/pekerjaan.',
    pre=['Pengguna sudah masuk.',
         'Ada baris pekerjaan (maintenance_histories) untuk aset terkait.'],
    post=['Rincian pekerjaan ditampilkan: kode layanan, lokasi, petugas, kategori, tanggal, hasil, catatan.'],
    minimal=['Dialog baca-saja; tidak ada data yang berubah.'],
    main=[
        ('Pengguna menekan "Berita Acara".',
         'Sistem membuka sheet "Berita Acara Servis" dengan kode #SBL-xxxxxxxx (diturunkan dari id baris).'),
        ('—',
         'Sistem menampilkan Lokasi (dari labs), Petugas (performed_by_name), Kategori, Tanggal '
         '(kalender WIB), bagian Hasil (action_taken), dan catatan (notes) bila ada.'),
        ('Pengguna menekan "Tutup".',
         'Sistem menutup sheet dan kembali ke daftar.'),
    ],
    alt=[
        ('A1', 'Pekerjaan belum punya catatan.',
         'Sistem menampilkan Hasil saja tanpa kotak catatan.'),
    ],
    exc=[
        ('E1', 'Kolom tidak ada di skema (mis. "Garansi Lab").',
         'Sistem sengaja tidak menampilkannya — tidak memalsukan data (lihat PETA-REVISI-UI.md §7).'),
    ],
    rules=['Kode layanan diturunkan dari id baris, bukan disimpan terpisah.',
           'Tanggal memakai date kalender WIB (maintenance_date), bukan timestamptz UTC.'],
)

uc(
    id='UC-09', group='A', name='Baca Pengumuman',
    diagram='Baca Pengumuman', seq='M5 · Baca pengumuman & aktivitas',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna membaca pengumuman (broadcast) yang diterbitkan admin dan masih dalam '
         'jendela tayang, tampil di Beranda / splash.',
    trigger='Sistem memuat Beranda / splash; pengguna membaca pengumuman yang tampil.',
    pre=['Ada pengumuman dengan is_published = true dan masih dalam jendela tayang.'],
    post=['Pengumuman aktif terlihat sesuai levelnya.'],
    minimal=['Bila tidak ada pengumuman aktif, tidak ada yang ditampilkan (bukan error).'],
    main=[
        ('—',
         'Sistem menarik announcements yang is_published = true dan published_at ≤ sekarang < '
         'expires_at (bila diatur).'),
        ('—',
         'Sistem menampilkan pengumuman di Beranda / splash sesuai level (info / peringatan / penting).'),
        ('Pengguna membaca pengumuman.',
         'Sistem mempertahankan tampilan selama jendela tayang masih berlaku.'),
    ],
    alt=[
        ('A1', 'Perangkat offline.',
         'Pengumuman dibaca dari cache terakhir.'),
        ('A2', 'Pengumuman sudah kedaluwarsa atau ditarik.',
         'Sistem tidak menampilkannya lagi pada pemuatan berikutnya.'),
    ],
    exc=[
        ('E1', 'Tidak ada pengumuman aktif.',
         'Sistem menampilkan Beranda tanpa bagian pengumuman.'),
    ],
    rules=['Hanya pengumuman terbit dan belum kedaluwarsa yang tampil; dibuat/dikelola admin (UC-21).',
           'Predikat index tidak memakai now(); jendela expires_at disaring saat query.'],
)

uc(
    id='UC-10', group='A', name='Edit Profil Saya',
    diagram='Edit Profil Saya', seq='M13 · Edit profil sendiri',
    actor='Pengguna / Pengelola Lab',
    desc='Pengguna memperbarui nama tampilan dan deskripsi singkat miliknya. Hanya kolom '
         'milik sendiri yang boleh diubah; peran dan keaktifan tidak dapat diubah sendiri.',
    trigger='Pengguna mengubah nama/deskripsi di tab Akun lalu menekan "Simpan Perubahan".',
    pre=['Pengguna sudah masuk.'],
    post=['Kolom full_name / description (dan avatar_path bila diubah) tersimpan.',
          'Tampilan profil menampilkan nilai baru.'],
    minimal=['Bila gagal, profil tetap seperti semula; isian form tidak hilang.'],
    main=[
        ('Pengguna membuka tab Akun / Profil.',
         'Sistem menampilkan nama, deskripsi, dan statistik (Lab Terhubung, Unit Terkelola, '
         'Pengajuan Saya).'),
        ('Pengguna mengubah "Nama tampilan" dan/atau "Deskripsi singkat (opsional)", lalu menekan '
         '"Simpan Perubahan".',
         'Sistem memanggil AuthService.updateOwnProfile (full_name, description, avatar_path).'),
        ('—',
         'Server memperbarui kolom milik sendiri; sistem menampilkan "Profil diperbarui." dan '
         'nilai baru.'),
    ],
    alt=[
        ('A1', 'Pengguna mengosongkan deskripsi.',
         'Sistem menyimpan string kosong (deskripsi memang boleh kosong).'),
    ],
    exc=[
        ('E1', 'Nama tampilan < 2 atau > 80 karakter.',
         'Constraint full_name menolak; sistem menampilkan pesan dan tidak menyimpan.'),
        ('E2', 'Deskripsi > 280 karakter.',
         'Constraint description menolak; sistem meminta pemendekan.'),
        ('E3', 'Offline / gagal.',
         'Sistem menampilkan pesan kegagalan; profil tidak berubah.'),
    ],
    rules=['Hanya full_name, description, avatar_path yang dapat diubah pemiliknya (privilege kolom).',
           'role dan is_active TIDAK dapat diubah sendiri — itu mencegah eskalasi hak (UC-22).'],
)

uc(
    id='UC-11', group='A', name='Sinkronisasi & Keadaan Offline',
    diagram='jalur mandiri (pendukung seluruh UC mobile)', seq='M14 · Segarkan data cloud; M15 · Keadaan offline & penguncian',
    actor='Pengguna / Pengelola Lab',
    desc='Aplikasi menjaga data tetap terbaru saat online dan tetap terbaca saat offline. '
         'Cache Hive hanya untuk baca; pengajuan butuh koneksi.',
    trigger='Pengguna menekan "Segarkan data cloud", atau ConnectivityService mendeteksi '
            'perubahan status jaringan.',
    pre=['Pengguna sudah masuk.'],
    post=['Online: data cloud ditarik dan ditulis penuh ke cache; banner offline hilang; '
          'tombol pengajuan terbuka.',
          'Offline: banner offline tampil; daftar dibaca dari cache; tombol pengajuan dikunci.'],
    minimal=['Data terakhir tetap terbaca dari cache walau offline; tidak ada tulis lokal ke data master.'],
    main=[
        ('Pengguna menekan "Segarkan data cloud" (atau otomatis saat login).',
         'AppState.refresh menarik tujuh pembacaan paralel dari PostgREST (labs, pcs, '
         'supporting_items, reports, maintenance_histories, announcements, v_lab_stats).'),
        ('—',
         'Sistem menulis penuh (overwrite) hasil ke Box Hive dan menandai waktu sinkron '
         '(markSynced).'),
        ('—',
         'Sistem menghilangkan banner offline dan membuka kembali tombol pengajuan; daftar '
         'menampilkan data termutakhir.'),
    ],
    alt=[
        ('A1', 'ConnectivityService mendeteksi offline.',
         'online = false; sistem menampilkan SyncBanner "Anda sedang offline. Menampilkan data '
         'terakhir. Pengajuan dinonaktifkan.", membaca daftar dari cache, dan mengunci tombol ajukan.'),
        ('A2', 'Koneksi kembali online.',
         'Banner hilang pada refresh berikutnya; data baru ditarik dan cache diperbarui.'),
    ],
    exc=[
        ('E1', 'Refresh dipanggil sebelum login.',
         'AppState.refresh keluar lebih dulu (semua tabel bisnis menolak anon 401); tidak ada '
         'deretan error palsu.'),
        ('E2', 'Sebagian pembacaan gagal saat online.',
         'Sistem jatuh ke cache untuk bagian yang gagal dan menampilkan banner keadaan.'),
    ],
    rules=['Cache Hive berhenti menjadi sumber kebenaran; hanya cache baca, overwrite penuh saat sinkron.',
           'Tidak ada antrean tulis offline.',
           'Panel admin TIDAK memakai cache Hive (data basi berbahaya untuk keputusan).'],
)

uc(
    id='UC-12', group='A', name='Keluar (Logout)',
    diagram='9. Keluar', seq='M1 · Masuk (kebalikan); profil signOut',
    actor='Pengguna / Pengelola Lab; Admin',
    desc='Pengguna mengakhiri sesi dan kembali ke layar Masuk.',
    trigger='Pengguna menekan "Keluar" di tab Profil.',
    pre=['Pengguna sedang masuk.'],
    post=['Sesi Supabase dihapus; layar Masuk ditampilkan.'],
    minimal=['Bila signOut gagal, sistem tetap mencoba membersihkan keadaan lokal dan kembali ke login.'],
    main=[
        ('Pengguna membuka tab Profil dan menekan "Keluar".',
         'Sistem memanggil AppState.signOut (Supabase Auth signOut + pembersihan keadaan).'),
        ('—',
         'Sesi dihapus; sistem menampilkan layar Masuk dan pesan "Anda keluar. Sampai jumpa."'),
    ],
    alt=[
        ('A1', 'Admin keluar dari panel web.',
         'Sistem kembali ke layar login admin (UC-13); tidak ada jalur daftar di web.'),
    ],
    exc=[
        ('E1', 'Jaringan terputus saat signOut.',
         'Sistem tetap membersihkan sesi lokal dan mengarahkan ke login; sesi cloud kedaluwarsa alami.'),
    ],
    rules=['Setelah keluar, refresh tidak memanggil cloud sampai ada sesi baru.'],
)

# --- KELOMPOK B: ADMIN ------------------------------------------------------
uc(
    id='UC-13', group='B', name='Masuk Panel Admin',
    diagram='1. Masuk (via web)', seq='A1 · Login panel admin',
    actor='Admin',
    desc='Admin mengautentikasi diri ke panel Flutter Web. Login memakai username/password '
         'yang sama dengan mobile; tidak ada jalur daftar di web.',
    trigger='Admin membuka panel web dan belum ada sesi.',
    pre=['Build web membawa SUPABASE_URL + publishable key (bukan secret key).',
         'Akun memiliki role = admin dan is_active = true.'],
    post=['Sesi authenticated admin tersimpan.',
          'AdminState.refresh menarik data panel; shell enam tab ditampilkan.'],
    minimal=['Non-admin tidak memperoleh data admin; penegak sebenarnya ada di server '
             '(resolve_admin + RLS), bukan sekadar layar.'],
    main=[
        ('Admin membuka panel web.',
         'Sistem menampilkan layar login username/password (tanpa tombol daftar).'),
        ('Admin mengisi kredensial dan menekan masuk.',
         'Sistem menurunkan email sintetis, memanggil signIn, lalu memuat profil (requireProfile).'),
        ('—',
         'Bila role = admin dan aktif, sistem menjalankan AdminState.refresh (sepuluh pembacaan '
         'paralel, TANPA cache Hive) dan menampilkan shell enam tab.'),
    ],
    alt=[
        ('A1', 'Sesi admin masih tersimpan.',
         'Sistem memulihkan sesi dan langsung membuka shell.'),
    ],
    exc=[
        ('E1', 'Akun bukan admin.',
         'Sistem menampilkan layar "Anda bukan admin". Ini kosmetik; setiap RPC admin tetap '
         'ditolak server lewat app.resolve_admin.'),
        ('E2', 'Akun nonaktif.',
         'Server menolak pembacaan maupun RPC; sistem menampilkan kegagalan.'),
        ('E3', 'Kredensial salah.',
         'Sistem menampilkan pesan kegagalan login; tidak ada sesi.'),
    ],
    rules=['Tidak ada supabase.auth.admin.* di web (menuntut service_role yang dilarang dibundel).',
           'RLS berlaku di jalur admin karena klien membawa JWT Supabase Auth.',
           'Admin pertama di-bootstrap manual lewat SQL Editor; sesudah itu diangkat lewat UC-22.'],
)

uc(
    id='UC-14', group='B', name='Lihat Ringkasan Lab (Dashboard)',
    diagram='Lihat Ringkasan Lab', seq='A2 · Muat dashboard admin',
    actor='Admin',
    desc='Admin melihat KPI dan ringkasan kesiapan tiap lab, antrean teratas, serta pekerjaan '
         'yang masih terbuka sebagai titik masuk pengelolaan.',
    trigger='Admin membuka tab Dashboard.',
    pre=['Admin sudah masuk (UC-13).'],
    post=['KPI, tabel v_lab_stats per lab, antrean teratas, dan pekerjaan terbuka ditampilkan.'],
    minimal=['Dashboard baca-saja; tidak ada data yang berubah.'],
    main=[
        ('Admin membuka tab Dashboard.',
         'Sistem menampilkan KPI (jumlah antrean, pekerjaan terbuka, dll.) dari data yang dimuat '
         'AdminState.refresh.'),
        ('—',
         'Sistem menampilkan tabel v_lab_stats per lab, daftar antrean teratas, dan pekerjaan terbuka.'),
        ('Admin membaca / menavigasi.',
         'Sistem mengarahkan ke tab terkait (Antrean, Aset, Riwayat) saat admin memilih.'),
    ],
    alt=[
        ('A1', 'Admin menekan "Muat ulang".',
         'Sistem menjalankan AdminState.refresh ulang (tanpa cache).'),
    ],
    exc=[
        ('E1', 'Data kosong (database demo belum diisi).',
         'Sistem menampilkan keadaan kosong / nol, bukan angka karangan.'),
    ],
    rules=['Semua angka berasal dari query (v_lab_stats + hitungan antrean).',
           'Panel tidak memakai cache Hive agar keputusan tidak berdasar data basi.'],
)

uc(
    id='UC-15', group='B', name='Periksa Laporan',
    diagram='5. Periksa Laporan', seq='A3 · Antrean · Periksa',
    actor='Admin',
    desc='Admin menandai tiket sebagai sedang diperiksa dan membuat satu pekerjaan tertunda '
         'dalam transaksi yang sama, sebagai langkah sebelum keputusan setujui/tolak.',
    trigger='Admin menekan "Periksa" pada tiket berstatus menunggu.',
    pre=['Admin sudah masuk.',
         'Tiket berstatus menunggu.'],
    post=['Tiket berstatus diperiksa.',
          'Satu pekerjaan berstatus tertunda dibuat untuk tiket itu.',
          'Data panel disegarkan penuh.'],
    minimal=['Bila RPC gagal, tiket tetap menunggu dan tidak ada pekerjaan yang dibuat.'],
    main=[
        ('Admin membuka tab Antrean.',
         'Sistem menampilkan tabel tiket (Prioritas, Tiket, Lab, Target, Keluhan, Pelapor, Saksi, '
         'Umur, Status, Aksi) dengan filter status dan lab.'),
        ('Admin menekan "Detail" pada sebuah tiket.',
         'Sistem menampilkan dialog rincian: status, prioritas, pelapor, status aset sebelumnya, '
         'jumlah bukti foto, keluhan, dan catatan admin.'),
        ('Admin menekan "Periksa".',
         'Sistem membuka dialog form: Catatan pemeriksaan (opsional) dan Petugas pelaksana '
         '(opsional; kosong = saya sendiri).'),
        ('Admin menekan "Tandai diperiksa".',
         'Sistem memanggil RPC sibal_check_report: tiket menjadi diperiksa dan satu pekerjaan '
         'tertunda dibuat dalam satu transaksi.'),
        ('—',
         'Sistem menampilkan "Tiket ditandai diperiksa." lalu menjalankan refresh penuh.'),
    ],
    alt=[
        ('A1', 'Admin mengisi catatan pemeriksaan.',
         'Catatan masuk ke admin_notes tiket dan notes riwayat.'),
        ('A2', 'Admin memilih petugas lain.',
         'Nilai dikirim sebagai p_performed_by; kosong berarti admin sendiri.'),
    ],
    exc=[
        ('E1', 'RPC gagal.',
         'Dialog tidak menutup sebelum RPC sukses; isian tetap ada dan sistem menampilkan pesan '
         'kegagalan.'),
    ],
    rules=['Periksa lalu Approve adalah urutan normal dan aman; approve memakai ulang pekerjaan '
           'tertunda milik tiket itu.',
           'Satu tiket hanya boleh punya satu pekerjaan terbuka (mh_one_open_job).'],
)

uc(
    id='UC-16', group='B', name='Setujui Laporan',
    diagram='6. Setujui Laporan', seq='A4 · Antrean · Setujui',
    actor='Admin',
    desc='Admin menyetujui pengajuan dan membuka pekerjaan pemeliharaan. Status tiket, status '
         'aset, dan buku stok berubah bersama dalam satu transaksi atomik.',
    trigger='Admin menekan "Setujui" pada tiket menunggu / diperiksa.',
    pre=['Admin sudah masuk.',
         'Tiket berstatus menunggu atau diperiksa.'],
    post=['Tiket berstatus diproses.',
          'Status aset menjadi rusak atau diperiksa (sesuai pilihan).',
          'Pekerjaan terbuka (memakai ulang pekerjaan tertunda bila ada).',
          'Bila barang dan qty_delta diisi, stok dibukukan ke maintenance_histories.'],
    minimal=['Bila RPC gagal, tidak ada perubahan separuh jalan: tiket, aset, dan stok tetap semula.'],
    main=[
        ('Admin menekan "Setujui" pada tiket.',
         'Sistem membuka dialog: Tindakan yang akan dikerjakan (wajib, min. 3 karakter), Kategori '
         'pekerjaan (bawaan perbaikan), Status aset setelah approve (hanya rusak / diperiksa), '
         'Perubahan stok (opsional, khusus barang, boleh negatif), dan Petugas.'),
        ('Admin mengisi tindakan dan pilihan, lalu menekan "Setujui dan buka pekerjaan".',
         'Sistem memvalidasi panjang tindakan, lalu memanggil RPC sibal_approve_report.'),
        ('—',
         'Server (satu transaksi): tiket menjadi diproses, aset menjadi rusak/diperiksa, pekerjaan '
         'terbuka, dan stok bergerak bila qty_delta diisi.'),
        ('—',
         'Sistem menampilkan "Tiket disetujui; pekerjaan terbuka." lalu refresh penuh.'),
    ],
    alt=[
        ('A1', 'Target adalah barang dan admin mengisi perubahan stok.',
         'qty_delta dibukukan sebagai baris riwayat (pelengkapan bila masuk, purnatugas bila keluar). '
         'Jika diisi di sini, jangan diisi lagi saat Complete (UC-18).'),
        ('A2', 'Tiket sudah lewat Periksa.',
         'Approve memakai ulang pekerjaan tertunda milik tiket itu, tidak membuat pekerjaan ganda.'),
    ],
    exc=[
        ('E1', 'Tindakan kurang dari 3 karakter.',
         'Sistem menampilkan "Tindakan minimal 3 karakter." dan tidak mengirim permintaan.'),
        ('E2', 'p_asset_status selain rusak / diperiksa.',
         'Server menolak; mengembalikan aset ke baik adalah pekerjaan Complete (UC-18), bukan approve.'),
        ('E3', 'qty_delta diisi untuk PC.',
         'Constraint mh_qty_pc_na menolak (PC tidak punya stok).'),
        ('E4', 'Sudah ada pekerjaan terbuka untuk tiket.',
         'Guard mh_one_open_job menolak pekerjaan ganda (anti double-approve).'),
    ],
    rules=['Approve hanya boleh menghasilkan rusak atau diperiksa.',
           'p_qty_delta bergerak dua kali bila diisi di Approve DAN Complete — isi di salah satu saja.',
           'p_operator_email tidak perlu dikirim; auth.uid() diverifikasi app.resolve_admin.'],
)

uc(
    id='UC-17', group='B', name='Tolak Laporan',
    diagram='6b. Tolak Laporan', seq='A5 · Antrean · Tolak',
    actor='Admin',
    desc='Admin menolak pengajuan dengan alasan. Status aset dipulihkan ke keadaan sebelum '
         'dilaporkan, dan alasan tampil ke pelapor.',
    trigger='Admin menekan "Tolak" pada tiket terbuka.',
    pre=['Admin sudah masuk.',
         'Tiket masih terbuka (menunggu / diperiksa / diproses).'],
    post=['Tiket berstatus ditolak; admin_notes terisi alasan.',
          'Status aset dipulihkan ke prev_asset_status.',
          'Data panel disegarkan.'],
    minimal=['Bila RPC gagal, tiket dan status aset tetap semula.'],
    main=[
        ('Admin menekan "Tolak" pada tiket.',
         'Sistem membuka dialog Alasan penolakan (wajib, min. 3 karakter).'),
        ('Admin mengisi alasan dan menekan "Tolak pengajuan".',
         'Sistem memvalidasi panjang alasan, lalu memanggil RPC sibal_reject_report.'),
        ('—',
         'Server mengubah tiket menjadi ditolak, menyimpan alasan di admin_notes, dan memulihkan '
         'status aset ke prev_asset_status.'),
        ('—',
         'Sistem menampilkan "Tiket ditolak dan aset dipulihkan." lalu refresh penuh.'),
    ],
    alt=[
        ('A1', 'Pelapor membuka "Pengajuan Saya".',
         'Sistem menampilkan status ditolak beserta alasan penolakan (UC-07).'),
    ],
    exc=[
        ('E1', 'Alasan kurang dari 3 karakter.',
         'Sistem menampilkan "Alasan minimal 3 karakter." dan tidak mengirim.'),
        ('E2', 'RPC gagal.',
         'Dialog tetap terbuka dengan isian; sistem menampilkan pesan kegagalan.'),
    ],
    rules=['Alasan penolakan wajib dan tampil ke pelapor.',
           'Pemulihan status memakai prev_asset_status yang direkam saat pengajuan.'],
)

uc(
    id='UC-18', group='B', name='Catat Perbaikan Selesai',
    diagram='7. Catat Perbaikan Selesai', seq='A10 · Riwayat · Selesaikan',
    actor='Admin',
    desc='Admin menutup pekerjaan pemeliharaan: riwayat ditandai selesai, status aset dipulihkan, '
         'tiket menjadi selesai, dan (untuk barang) stok digeser dengan delta — semuanya satu transaksi.',
    trigger='Admin menekan "Selesaikan" pada pekerjaan terbuka di tab Riwayat.',
    pre=['Admin sudah masuk.',
         'Pekerjaan berstatus terbuka (tertunda / berjalan).'],
    post=['Pekerjaan berstatus selesai dengan completed_at dan tanggal kalender WIB.',
          'Status aset menjadi outcome (baik / diperiksa / rusak / habis / purnatugas).',
          'Tiket terkait menjadi selesai.',
          'Bila barang dan delta diisi, stok bergerak sesuai delta.'],
    minimal=['Bila RPC gagal, pekerjaan, aset, tiket, dan stok tetap semula.'],
    main=[
        ('Admin membuka tab Riwayat.',
         'Sistem menampilkan tabel pekerjaan (Tanggal, Target, Lab, Kategori, Status, Petugas, '
         'Stok, Tindakan, Tiket, Aksi) dengan filter Terbuka / Selesai / Semua dan lab.'),
        ('Admin menekan "Selesaikan" pada pekerjaan terbuka.',
         'Sistem membuka dialog: Status aset setelah selesai (bawaan baik; barang menambah habis), '
         'Catatan hasil (opsional), dan Delta stok saat penutupan (opsional, khusus barang, BENTUK DELTA).'),
        ('Admin memilih outcome dan menekan "Tandai selesai".',
         'Sistem memanggil RPC sibal_complete_maintenance (satu transaksi).'),
        ('—',
         'Server menandai pekerjaan selesai (completed_at + tanggal WIB), memulihkan aset ke '
         'outcome, menjadikan tiket selesai, dan menggeser stok bila delta diisi.'),
        ('—',
         'Sistem menampilkan "Pekerjaan … selesai." lalu refresh penuh.'),
    ],
    alt=[
        ('A1', 'Unit berhenti dipakai.',
         'Admin memilih outcome purnatugas; aset tidak kembali ke baik.'),
        ('A2', 'Stok barang benar-benar kosong.',
         'Admin memilih outcome habis (khusus barang).'),
        ('A3', 'Stok sudah digeser saat Approve.',
         'Admin membiarkan delta = 0 di sini agar stok tidak bergerak dua kali.'),
    ],
    exc=[
        ('E1', 'Delta diisi lagi padahal sudah digeser saat Approve.',
         'Stok bergerak dua kali; UI memperingatkan bentuk delta dan mengingatkan pengisian ganda.'),
        ('E2', 'Delta diisi untuk PC.',
         'Ditolak (mh_qty_pc_na); form PC tidak menampilkan kolom delta.'),
        ('E3', 'RPC gagal.',
         'Dialog tetap terbuka; sistem menampilkan pesan kegagalan.'),
    ],
    rules=['Complete mengembalikan aset ke baik / purnatugas (bukan approve).',
           'Delta stok di sini berbentuk + masuk / − keluar, berbeda dari form Aset yang absolut.',
           'Tanggal penyelesaian memakai kalender WIB, bukan UTC server.'],
)

uc(
    id='UC-19', group='B', name='Buka Lagi Laporan',
    diagram='7b. Buka Lagi Laporan', seq='A6 · Antrean · Buka lagi; A11 · Riwayat · Buka lagi tiket',
    actor='Admin',
    desc='Admin membuka kembali tiket yang sudah ditutup (selesai / ditolak / batal) karena '
         'kerusakan muncul lagi atau keputusan perlu ditinjau ulang.',
    trigger='Admin menekan "Buka lagi" pada tiket tertutup.',
    pre=['Admin sudah masuk.',
         'Tiket berstatus selesai / ditolak / batal.'],
    post=['Tiket kembali ke antrean (menunggu).',
          'Status aset masuk lagi ke dalam_pengajuan.',
          'Data panel disegarkan.'],
    minimal=['Bila RPC gagal, tiket tetap tertutup dan status aset tidak berubah.'],
    main=[
        ('Admin menekan "Buka lagi" (Antrean tampilan "Sudah tutup", atau dari Riwayat).',
         'Sistem membuka dialog Alasan membuka kembali (wajib, min. 3 karakter).'),
        ('Admin mengisi alasan dan menekan "Buka kembali".',
         'Sistem memvalidasi panjang alasan, lalu memanggil RPC sibal_reopen_report.'),
        ('—',
         'Server mengembalikan tiket ke antrean dan memindahkan aset ke dalam_pengajuan.'),
        ('—',
         'Sistem menampilkan "Tiket dibuka kembali." lalu refresh penuh.'),
    ],
    alt=[
        ('A1', 'Tiket dibuka dari tab Riwayat.',
         'Sistem memakai tiket yang terkait dengan pekerjaan tersebut; alur RPC sama.'),
    ],
    exc=[
        ('E1', 'Alasan kurang dari 3 karakter.',
         'Sistem menampilkan "Alasan minimal 3 karakter." dan tidak mengirim.'),
        ('E2', 'Tiket masih terbuka.',
         'Tombol "Buka lagi" tidak ditawarkan untuk tiket terbuka.'),
    ],
    rules=['Hanya tiket tertutup yang boleh dibuka lagi.',
           'Alasan membuka kembali wajib dan tercatat.'],
)

uc(
    id='UC-20', group='B', name='Kelola Aset & Status',
    diagram='Kelola Aset & Status', seq='A7 · Koreksi PC; A8 · Koreksi barang + stok; A9 · Ubah status',
    actor='Admin',
    desc='Admin mengoreksi kolom deskriptif aset (PC dan barang), menyesuaikan stok barang, '
         'dan mengubah status aset. Setiap perubahan menulis jejak; status tidak bisa diubah '
         'lewat form edit bebas.',
    trigger='Admin membuka tab Aset dan memilih tindakan pada sebuah aset.',
    pre=['Admin sudah masuk.'],
    post=['Kolom deskriptif aset diperbarui sesuai konvensi null/empty.',
          'Perubahan stok barang dibukukan ke maintenance_histories dengan alasan.',
          'Perubahan status menulis baris riwayat.'],
    minimal=['Bila RPC gagal, aset tetap seperti semula; form tidak menutup sebelum sukses.'],
    main=[
        ('Admin membuka tab Aset dan memilih jenis (PC / Barang) serta lab.',
         'Sistem menampilkan daftar aset (admin juga melihat is_active = false).'),
        ('Admin memilih tindakan pada sebuah aset.',
         'Sistem membuka dialog sesuai tindakan: Koreksi PC (A), Koreksi Barang & Stok (B), '
         'atau Ubah Status (C).'),
        ('Admin mengisi form dan menekan "Simpan" / "Terapkan status".',
         'Sistem memanggil RPC terkait (sibal_update_pc / sibal_update_supporting_item / '
         'sibal_set_asset_status), lalu refresh penuh.'),
    ],
    alt=[
        ('A', 'Koreksi Spesifikasi PC (A7).',
         'Form: Prosesor (wajib), RAM (wajib), Storage, GPU, Mouse, Keyboard, Lokasi, Catatan. '
         'Kolom yang tidak diubah dikirim null (tetap); string kosong berarti mengosongkan. '
         'RPC sibal_update_pc tidak punya parameter status.'),
        ('B', 'Koreksi Barang & Stok (A8).',
         'Form: Nama (wajib, unik per lab), Kategori, Spesifikasi, Satuan, Lokasi, Catatan, '
         'Jumlah stok (ABSOLUT), dan Alasan perubahan stok (wajib bila stok berubah, min. 3). '
         'RPC sibal_update_supporting_item membukukan delta ke riwayat (pelengkapan masuk / '
         'purnatugas keluar).'),
        ('C', 'Ubah Status Aset (A9).',
         'Form: Status baru (dalam_pengajuan tidak ditawarkan — itu wilayah tiket mobile) dan '
         'Alasan (wajib, min. 3) yang menjadi action_taken riwayat. RPC sibal_set_asset_status.'),
    ],
    exc=[
        ('E1', 'Prosesor / RAM kosong (PC) atau Nama kosong (barang).',
         'Sistem menampilkan pesan wajib diisi dan tidak mengirim.'),
        ('E2', 'Jumlah stok bukan angka ≥ 0.',
         'Sistem menampilkan "Jumlah stok harus angka ≥ 0." dan tidak mengirim.'),
        ('E3', 'Stok berubah tanpa alasan.',
         'Sistem menampilkan "Perubahan stok wajib disertai alasan."; server juga menolak delta '
         'tanpa alasan ≥ 3 karakter.'),
        ('E4', 'Alasan ubah status < 3 karakter.',
         'Sistem menampilkan "Alasan minimal 3 karakter." dan tidak mengirim.'),
        ('E5', 'Status habis dipilih untuk PC.',
         'Constraint pcs_status_check menolak (PC tidak mengenal habis).'),
    ],
    rules=['Konvensi app.text_field: null = jangan ubah, string kosong = kosongkan, nilai = ditulis (trim).',
           'Stok di tab Aset berbentuk ABSOLUT (p_qty); di tab Riwayat berbentuk DELTA (p_qty_delta).',
           'status dan qty tidak masuk form edit bebas; target_kind adalah generated column.',
           'Form edit tidak punya parameter status — trigger trg_pcs_status_guard hanya menyala '
           'untuk update of status, jadi jalur koreksi tidak bisa mengubah status.'],
)

uc(
    id='UC-21', group='B', name='Kelola Pengumuman (Broadcast)',
    diagram='Kirim Pengumuman', seq='A12 · Buat/ubah; A13 · Terbitkan/tarik; A14 · Hapus',
    actor='Admin',
    desc='Admin membuat, mengubah, menerbitkan, menarik, dan menghapus pengumuman yang tampil '
         'di Beranda mobile selama jendela tayang.',
    trigger='Admin membuka tab Broadcast dan memilih tindakan.',
    pre=['Admin sudah masuk.'],
    post=['Pengumuman tersimpan / terbit / ditarik / terhapus sesuai tindakan.',
          'Pengumuman terbit dan belum kedaluwarsa tampil di Beranda mobile (UC-09).'],
    minimal=['Bila RPC gagal, pengumuman tetap seperti semula; form tidak menutup sebelum sukses.'],
    main=[
        ('Admin membuka tab Broadcast.',
         'Sistem menampilkan daftar pengumuman beserta status tayang dan level.'),
        ('Admin memilih tindakan (buat / ubah / terbit-tarik / hapus).',
         'Sistem membuka dialog sesuai tindakan (lihat alur alternatif A–C).'),
        ('Admin mengisi / mengonfirmasi dan menyimpan.',
         'Sistem memanggil RPC terkait (sibal_upsert_announcement / sibal_delete_announcement), '
         'lalu refresh penuh.'),
    ],
    alt=[
        ('A', 'Buat / Ubah pengumuman (A12).',
         'Form: Judul (3–120 karakter), Isi (maks. 2000), Level (info / peringatan / penting), '
         '"Langsung terbit" (toggle; bila mati tersimpan sebagai draf), dan Batas tayang '
         '(opsional, harus sesudah waktu tayang). RPC sibal_upsert_announcement.'),
        ('B', 'Terbitkan / Tarik (A13).',
         'Admin mengubah is_published; menerbitkan mengisi published_at. Sistem memanggil '
         'sibal_upsert_announcement dan menampilkan "Pengumuman diterbitkan / ditarik dari Beranda."'),
        ('C', 'Hapus (A14).',
         'Sistem meminta konfirmasi "Hapus pengumuman?"; bila setuju memanggil '
         'sibal_delete_announcement dan menampilkan "Pengumuman dihapus."'),
    ],
    exc=[
        ('E1', 'Judul < 3 atau > 120 karakter.',
         'Sistem menampilkan pesan panjang judul dan tidak mengirim.'),
        ('E2', 'Isi pengumuman kosong.',
         'Sistem menampilkan "Isi pengumuman wajib diisi." dan tidak mengirim.'),
        ('E3', 'Batas tayang ≤ waktu tayang.',
         'Constraint ann_window_sane menolak; sistem meminta tanggal yang lebih akhir.'),
        ('E4', 'Menerbitkan tanpa published_at.',
         'Constraint ann_published_needs_date menolak; sistem mengisi published_at saat terbit.'),
    ],
    rules=['Pengumuman tampil di mobile hanya selama is_published dan dalam jendela tayang.',
           'Parameter RPC yang boleh tidak dikirim wajib punya default (mis. p_id / p_title / '
           'p_body NULL) agar PostgREST tidak gagal PGRST202.'],
)

uc(
    id='UC-22', group='B', name='Kelola Akun & Peran',
    diagram='Kelola Akun & Peran', seq='A15 · Angkat/turunkan peran; A16 · Aktif/nonaktif akun',
    actor='Admin',
    desc='Admin mengangkat/menurunkan peran pengguna dan mengaktifkan/menonaktifkan akun. '
         'Daftar dibaca dari public.profiles, bukan skema auth.',
    trigger='Admin membuka tab Pengguna dan memilih tindakan pada sebuah akun.',
    pre=['Admin sudah masuk.',
         'Admin pertama sudah di-bootstrap lewat SQL Editor.'],
    post=['Peran akun menjadi admin / user, atau keaktifan menjadi aktif / nonaktif.',
          'Akun nonaktif ditolak semua RPC admin dan pembacaan data meski sesinya masih ada.'],
    minimal=['Bila RPC gagal, peran/keaktifan tetap semula; admin tidak dapat menonaktifkan dirinya sendiri.'],
    main=[
        ('Admin membuka tab Pengguna.',
         'Sistem menampilkan daftar akun (username, nama, peran, keaktifan, deskripsi, tanggal '
         'buat) dengan pencarian username / nama.'),
        ('Admin membuka menu aksi pada sebuah akun.',
         'Sistem menawarkan "Jadikan admin" / "Turunkan peran" dan "Nonaktifkan" / "Aktifkan".'),
        ('Admin memilih tindakan dan mengonfirmasi.',
         'Sistem memanggil RPC sibal_set_user_role atau sibal_set_user_active, lalu refresh penuh.'),
    ],
    alt=[
        ('A', 'Angkat / Turunkan peran (A15).',
         'Konfirmasi "Angkat {username} jadi admin?" / "Turunkan {username} dari admin?". '
         'RPC sibal_set_user_role; admin baru dapat menyetujui pengajuan, mengubah aset, dan '
         'mengangkat admin lain.'),
        ('B', 'Aktif / Nonaktif akun (A16).',
         'Konfirmasi "Nonaktifkan {username}?" / "Aktifkan kembali {username}?". RPC '
         'sibal_set_user_active; akun nonaktif ditolak server meski sesi masih ada.'),
    ],
    exc=[
        ('E1', 'Admin mencoba menonaktifkan dirinya sendiri.',
         'Sistem menolak; akun sendiri tidak bisa dinonaktifkan oleh dirinya.'),
        ('E2', 'Pemanggil bukan admin.',
         'app.resolve_admin menolak RPC; perubahan tidak terjadi.'),
        ('E3', 'Mencari data auth (mis. last_sign_in_at).',
         'Tidak tersedia lewat profiles; sistem tidak menampilkannya (bukan memanggil auth.admin).'),
    ],
    rules=['Daftar pengguna dibaca dari public.profiles (policy profiles_read using true).',
           'Tidak ada supabase.auth.admin.* di web; membuat akun tetap di mobile / dashboard.',
           'Admin pertama diangkat manual: update public.profiles set role = admin where username = …; '
           'sesudah itu lewat sibal_set_user_role.'],
)

# --- KELOMPOK C: EKSTERNAL --------------------------------------------------
uc(
    id='UC-23', group='C', name='Buat / Reset / Hapus Akun (Operator Supabase)',
    diagram='Buat / Reset / Hapus Akun (di luar sistem)', seq='— (di luar aplikasi)',
    actor='Operator Dashboard Supabase (eksternal)',
    desc='Operator membuat, mereset, atau menghapus akun lewat dashboard Supabase, serta '
         'mem-bootstrap admin pertama lewat SQL Editor. Berada di luar batas sistem SIBAL '
         'karena menuntut service_role / secret key.',
    trigger='Operator membuka dashboard Supabase (Authentication / SQL Editor).',
    pre=['Operator memiliki akses ke dashboard project Supabase.'],
    post=['Akun Auth dibuat / direset / dihapus; profil terkait mengikuti trigger.',
          'Admin pertama memiliki role = admin bila di-bootstrap lewat SQL.'],
    minimal=['Operasi ini tidak tersedia dari aplikasi mobile maupun panel web.'],
    main=[
        ('Operator membuka dashboard Supabase → Authentication.',
         'Dashboard menampilkan daftar pengguna Auth.'),
        ('Operator memilih Add user / reset password / delete user.',
         'Dashboard menjalankan operasi memakai hak service_role; trigger handle_new_user '
         'membuat profil bila akun baru.'),
        ('Operator (opsional) membuka SQL Editor untuk bootstrap admin.',
         'Operator menjalankan update public.profiles set role = \'admin\' where username = …; '
         'admin pertama siap masuk panel (UC-13).'),
    ],
    alt=[
        ('A1', 'Pendaftaran mandiri dari mobile.',
         'Jalur utama pembuatan akun adalah UC-02 (role selalu user); dashboard dipakai untuk '
         'kasus khusus / reset / hapus.'),
    ],
    exc=[
        ('E1', 'Mencoba memakai service_role dari bundle web.',
         'Dilarang: apa pun yang masuk flutter build web dapat dibaca publik; secret key tidak '
         'pernah masuk --dart-define / kode / assets.'),
    ],
    rules=['Use case ini di luar kotak sistem pada use case diagram karena menuntut service_role.',
           'Satu-satunya jalur yang mem-bypass RLS adalah SQL Editor / Table Editor dashboard, '
           'atas nama manusia, bukan kode.'],
)


# ===========================================================================
# RENDER
# ===========================================================================
GROUP_TITLE = {
    'A': 'Kelompok A — Aplikasi Mobile (Pengguna / Pengelola Lab)',
    'B': 'Kelompok B — Panel Admin (Flutter Web)',
    'C': 'Kelompok C — Operator Dashboard Supabase (Eksternal)',
}

# ---- Sampul ----------------------------------------------------------------
para('', space_after=40)
para('SIBAL', size=40, bold=True, color=NAVY, align=WD_ALIGN_PARAGRAPH.CENTER, space_after=6)
para('Sistem Inventaris & Pelaporan Aset Laboratorium', size=15, color=BLUE,
     align=WD_ALIGN_PARAGRAPH.CENTER, space_after=30)
para('SKENARIO USE CASE', size=26, bold=True, color=INK,
     align=WD_ALIGN_PARAGRAPH.CENTER, space_after=8)
para('Spesifikasi Use Case Mendetail — Aplikasi Mobile & Panel Admin', size=13,
     color=GREY, align=WD_ALIGN_PARAGRAPH.CENTER, space_after=50)

kv_table([
    ('Proyek', 'SIBAL (sebelumnya LTrack) — inventaris & pengajuan kerusakan lab'),
    ('Platform', 'Flutter Mobile (pengguna) + Flutter Web (admin), satu package'),
    ('Sumber kebenaran', 'Supabase (PostgreSQL); cache Hive CE hanya baca di mobile'),
    ('Pola arsitektur', 'Local-first / offline-first dengan approval workflow'),
    ('Acuan diagram', 'docs/perancangan/use_case diagram (alur pemakaian 1 → 9)'),
    ('Acuan sequence', 'docs/perancangan/sequence_diagram.drawio (31 halaman per fungsi)'),
    ('Versi dokumen', '1.0 — 2026-11-11'),
    ('Jumlah use case', f'{len(UC)} use case (A: mobile, B: admin, C: eksternal)'),
], label_w=4.6, val_w=12.0)

doc.add_page_break()

# ---- 1. Pendahuluan --------------------------------------------------------
doc.add_heading('1. Pendahuluan', level=1)
para('Dokumen ini merinci skenario setiap use case sistem SIBAL pada tingkat pemakaian '
     'eksternal: apa yang dilakukan aktor dan bagaimana sistem merespons, tanpa membongkar '
     'detail internal database kecuali sebagai aturan bisnis yang mengikat. Setiap use case '
     'disajikan dalam format spesifikasi Cockburn: identitas, prakondisi, pascakondisi, alur '
     'utama (aksi aktor vs respons sistem), alur alternatif, alur pengecualian, dan aturan bisnis.')
para('Penomoran dan nama use case diselaraskan dengan use case diagram pada folder '
     'docs/perancangan (alur pemakaian satu putaran 1 → 9 beserta cabang 4a, 6b, 7b dan jalur '
     'mandiri). Kolom "Acuan" pada tiap use case memetakan ke nomor diagram dan halaman sequence '
     'diagram terkait, sehingga dokumen ini dapat ditelusuri balik ke diagram dan kode.')

doc.add_heading('1.1 Cara membaca spesifikasi', level=2)
bullet('Alur utama adalah jalur sukses (happy path): satu putaran normal dari pemicu hingga pascakondisi.', bold_lead='')
bullet('Alur alternatif (A, B, C / A1, A2) adalah cabang sah yang tetap menuju sukses atau kembali ke alur utama.')
bullet('Alur pengecualian (E1, E2, …) adalah kondisi gagal; jaminan minimal memastikan sistem tidak meninggalkan keadaan separuh jalan.')
bullet('Aturan bisnis adalah batasan yang ditegakkan di server (constraint, RLS, RPC atomik) dan tidak boleh dilanggar klien.')

doc.add_heading('1.2 Daftar aktor', level=2)
make_table(
    ['Aktor', 'Peran', 'Kewenangan utama'],
    [
        ('Pengguna / Pengelola Lab', 'Anggota lab (siswa / pengelola)',
         'Masuk, melihat kondisi lab & inventaris, mengajukan / membatalkan laporan, memantau '
         'status, membaca berita acara & pengumuman, edit profil sendiri, keluar.'),
        ('Admin', 'Pengelola dengan role = admin (generalisasi dari Pengguna)',
         'Semua hak Pengguna ditambah: periksa / setujui / tolak / buka lagi laporan, catat '
         'perbaikan selesai, kelola aset & status, kelola pengumuman, kelola akun & peran.'),
        ('Operator Dashboard Supabase', 'Eksternal di luar batas sistem',
         'Buat / reset / hapus akun dan bootstrap admin pertama memakai service_role / SQL Editor.'),
    ],
    widths=[4.3, 4.6, 7.7], body_size=10.5, first_col_bold=True)
para('Catatan: Admin adalah generalisasi Pengguna (Admin is-a Pengguna) — login keduanya sama. '
     'Layar "Anda bukan admin" hanyalah kosmetik; penegak sebenarnya adalah app.resolve_admin + '
     'RLS + privilege di server.', size=10, italic=True, color=GREY)

doc.add_heading('1.3 Kamus status (nilai wire database)', level=2)
make_table(
    ['Domain', 'Nilai', 'Keterangan singkat'],
    [
        ('asset_status', 'baik, dalam_pengajuan, diperiksa, rusak, habis, purnatugas',
         'Status aset. habis hanya untuk barang; PC tidak mengenal habis.'),
        ('report_status', 'menunggu, diperiksa, diproses, selesai, ditolak, batal',
         'Status tiket pengajuan. Terbuka = menunggu / diperiksa / diproses.'),
        ('maintenance_status', 'tertunda, berjalan, selesai, dibatalkan',
         'Status pekerjaan pemeliharaan. Terbuka = tertunda / berjalan.'),
        ('report_severity', 'ringan, sedang, darurat', 'Tingkat urgensi laporan (bawaan sedang).'),
        ('maintenance_kind', 'perbaikan, penggantian, pembersihan, pelengkapan, inspeksi, pemindahan, purnatugas',
         'Kategori pekerjaan. pelengkapan = stok masuk; purnatugas = stok keluar / unit pensiun.'),
        ('app_role', 'user, admin', 'Peran akun. Signup selalu user; admin diangkat terpisah.'),
        ('announcement_level', 'info, peringatan, penting', 'Level pengumuman broadcast.'),
    ],
    widths=[3.6, 7.0, 6.0], body_size=10, first_col_bold=True)

doc.add_page_break()

# ---- 2. Daftar use case ----------------------------------------------------
doc.add_heading('2. Daftar Use Case', level=1)
para('Tabel berikut merangkum seluruh use case beserta aktor dan acuan diagram / sequence. '
     'Rincian tiap use case ada pada Bab 3 (mobile), Bab 4 (admin), dan Bab 5 (eksternal).')
rows = [(u['id'], u['name'], u['actor'].split(' (')[0], u['diagram'], u['seq']) for u in UC]
make_table(['Kode', 'Use Case', 'Aktor utama', 'Acuan diagram', 'Acuan sequence'],
           rows, widths=[1.5, 4.6, 3.4, 3.4, 3.7], body_size=9.5, first_col_bold=True)

doc.add_page_break()

# ---- 3/4/5. Spesifikasi per kelompok ---------------------------------------
BAB = {'A': '3. Spesifikasi Use Case — Aplikasi Mobile',
       'B': '4. Spesifikasi Use Case — Panel Admin',
       'C': '5. Spesifikasi Use Case — Eksternal'}

for grp in ('A', 'B', 'C'):
    doc.add_heading(BAB[grp], level=1)
    para(GROUP_TITLE[grp], size=11, italic=True, color=GREY, space_after=8)
    for u in [x for x in UC if x['group'] == grp]:
        doc.add_heading(f"{u['id']} · {u['name']}", level=2)
        kv_table([
            ('Aktor', u['actor']),
            ('Acuan diagram', u['diagram']),
            ('Acuan sequence', u['seq']),
            ('Deskripsi', u['desc']),
            ('Pemicu', u['trigger']),
            ('Prakondisi', '\n'.join(f'• {p}' for p in u['pre'])),
            ('Pascakondisi (sukses)', '\n'.join(f'• {p}' for p in u['post'])),
            ('Jaminan minimal', '\n'.join(f'• {p}' for p in u['minimal'])),
        ])
        spacer(6)
        doc.add_heading('Alur utama (normal flow)', level=3)
        flow_table(u['main'])
        spacer(4)
        doc.add_heading('Alur alternatif', level=3)
        if u['alt']:
            branch_table(u['alt'])
        else:
            para('Tidak ada alur alternatif.', size=10.5, italic=True, color=GREY)
        spacer(4)
        doc.add_heading('Alur pengecualian', level=3)
        if u['exc']:
            branch_table(u['exc'])
        else:
            para('Tidak ada alur pengecualian khusus.', size=10.5, italic=True, color=GREY)
        spacer(4)
        doc.add_heading('Aturan bisnis', level=3)
        for r in u['rules']:
            bullet(r, size=10.5)
        doc.add_page_break()

# ---- 6. Matriks ketertelusuran --------------------------------------------
doc.add_heading('6. Matriks Ketertelusuran', level=1)
para('Memetakan tiap use case ke nomor use case diagram, halaman sequence diagram, dan RPC / '
     'jalur data yang dipakai. Baca = PostgREST SELECT; tulis = RPC security definer. Klien '
     'tidak pernah menulis tabel bisnis secara langsung.')
TRACE = {
    'UC-01': 'Auth signInWithPassword; requireProfile; AppState.refresh',
    'UC-02': 'Auth signUp; trigger app.handle_new_user (role = user)',
    'UC-03': 'v_lab_stats, pcs, supporting_items, announcements (baca)',
    'UC-04': 'pcs, supporting_items, labs (baca)',
    'UC-05': 'sibal_report_issue (tulis atomik) + report_witness',
    'UC-06': 'sibal_cancel_report (tulis atomik)',
    'UC-07': 'reports milik pengguna (baca)',
    'UC-08': 'maintenance_histories, labs (baca)',
    'UC-09': 'announcements terbit & dalam jendela tayang (baca)',
    'UC-10': 'updateOwnProfile (full_name, description, avatar_path)',
    'UC-11': 'AppState.refresh (7 baca) → LocalCache.replaceAll; ConnectivityService',
    'UC-12': 'Auth signOut; AppState.signOut',
    'UC-13': 'Auth signIn; requireProfile; AdminState.refresh (10 baca, tanpa Hive)',
    'UC-14': 'v_lab_stats + hitungan antrean (baca)',
    'UC-15': 'sibal_check_report (tulis atomik)',
    'UC-16': 'sibal_approve_report (tulis atomik)',
    'UC-17': 'sibal_reject_report (tulis atomik)',
    'UC-18': 'sibal_complete_maintenance (tulis atomik)',
    'UC-19': 'sibal_reopen_report (tulis atomik)',
    'UC-20': 'sibal_update_pc · sibal_update_supporting_item · sibal_set_asset_status',
    'UC-21': 'sibal_upsert_announcement · sibal_delete_announcement',
    'UC-22': 'sibal_set_user_role · sibal_set_user_active; profiles (baca)',
    'UC-23': 'Dashboard Supabase (service_role) / SQL Editor — di luar aplikasi',
}
rows = [(u['id'], u['name'], u['diagram'], u['seq'], TRACE.get(u['id'], '—')) for u in UC]
make_table(['Kode', 'Use Case', 'Diagram', 'Sequence', 'RPC / jalur data'],
           rows, widths=[1.4, 3.6, 3.0, 3.6, 5.0], body_size=9, first_col_bold=True)

spacer(8)
para('Catatan penutup: seluruh jalur tulis adalah RPC atomik (satu transaksi) yang diverifikasi '
     'app.resolve_admin untuk aksi admin. Tidak ada grant INSERT/UPDATE tabel bisnis ke role '
     'authenticated; perubahan data master hanya terjadi lewat persetujuan admin atau koreksi '
     'admin lewat panel. Anggaran seluruh rencana Rp 0 (Supabase Free + hosting gratis).',
     size=10, italic=True, color=GREY)

# ---- Simpan ----------------------------------------------------------------
out = os.path.join(os.path.dirname(__file__), '..', 'Skenario_Use_Case_SIBAL.docx')
out = os.path.normpath(out)
doc.save(out)
print(f'{out} · {len(UC)} use case')