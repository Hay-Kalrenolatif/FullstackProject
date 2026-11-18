#!/usr/bin/env python3
"""Generator sequence diagram UML (.drawio) — satu halaman untuk SATU fungsi.

Setiap operasi di setiap layar punya lifeline, pesan sinkron/balasan, aktivasi,
fragment alt/opt, dan note sendiri — termasuk jalur gagal (server menolak,
akun nonaktif, offline) dan fan-out refresh sesudah tiap tulis, karena memang
begitu kode berjalan.

Konvensi langkah:
    (dari, ke, 'pesan')                    pesan sinkron, panah solid tertutup
    (dari, ke, 'hasil', 'r')               balasan, panah putus-putus terbuka
    (kolom, kolom, 'aksi dirinya')         self message (kolom sama)
    ('!', 'alt'|'opt'|'loop', '[penjaga]') mulai fragment
    ('!', 'else', '[penjaga]')            pemisah fragment
    ('!', 'end')                           tutup fragment
    ('=', 'isi note', 'Kolom')            note di atas satu kolom

    python docs/perancangan/tools/gen_sequence_drawio.py
"""
import os

HDR_W, HDR_H, COL_GAP = 152, 46, 40
TOP, STEP, NOTE_H, ACT_W = 118, 30, 40, 12
X0 = 40

S_HEAD = 'shape=rect;whiteSpace=wrap;html=1;fontSize=11;fontStyle=1;verticalAlign=middle;'
S_LIFE = 'shape=rect;html=1;fillColor=none;strokeColor=#999999;dashed=1;'
S_ACT = 'shape=rect;html=1;fillColor=#d5e8d4;strokeColor=#82b366;'
S_MSG = 'html=1;endArrow=block;strokeColor=#333333;fontSize=10;verticalAlign=bottom;'
S_RET = 'html=1;endArrow=open;dashed=1;strokeColor=#333333;fontSize=10;verticalAlign=bottom;'
S_FRAG = 'shape=rect;html=1;fillColor=none;strokeColor=#666666;dashed=1;'
S_TAG = ('shape=hexagon;perimeter=hexagonPerimeter2;html=1;fontSize=10;fontStyle=1;'
         'fillColor=#fff2cc;strokeColor=#d6b656;fixedSize=1;size=12;')
S_NOTE = ('shape=note;html=1;whiteSpace=wrap;fontSize=10;align=left;verticalAlign=top;'
          'fillColor=#fffbe6;strokeColor=#d6b656;spacing=4;')
S_TITLE = 'text;html=1;align=left;verticalAlign=middle;fontSize=13;fontStyle=1;spacing=4;'
S_CAPTION = 'text;html=1;align=left;verticalAlign=top;fontSize=10;spacing=4;'
S_ACTOR = ('shape=umlActor;html=1;verticalLabelPosition=bottom;labelPosition=center;'
           'verticalAlign=top;fontSize=11;fontStyle=1;fillColor=#ffe6cc;strokeColor=#d79b00;')

# kepala lifeline: warna mengikuti lapisan kode
COLOR = {
    'Halaman': ('#dae8fc', '#6c8ebf'),
    'Sheet': ('#dae8fc', '#6c8ebf'),
    'Shell': ('#dae8fc', '#6c8ebf'),
    'State': ('#ffe6cc', '#d79b00'),
    'Repository': ('#d5e8d4', '#82b366'),
    'PostgREST': ('#f5f5f5', '#666666'),
    'RPC': ('#f5f5f5', '#666666'),
    'Supabase DB': ('#e1d5e7', '#9673a6'),
    'Auth': ('#f5f5f5', '#666666'),
    'Cache Hive': ('#d5e8d4', '#82b366'),
}

pages = []
_seq = [0]


def esc(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
            .replace('"', '&quot;'))


def nid(p='c'):
    _seq[0] += 1
    return f'{p}{_seq[0]}'


def vertex(cells, label, x, y, w, h, style):
    cid = nid()
    cells.append(f'<mxCell id="{cid}" value="{esc(label)}" style="{style}" vertex="1" '
                 f'parent="1"><mxGeometry x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" '
                 f'height="{h:.0f}" as="geometry"/></mxCell>')
    return cid


def free_arrow(cells, x1, y1, x2, y2, label, style):
    cells.append(f'<mxCell id="{nid("e")}" value="{esc(label)}" style="{style}" edge="1" '
                 f'parent="1"><mxGeometry relative="1" as="geometry">'
                 f'<mxPoint as="sourcePoint" x="{x1:.0f}" y="{y1:.0f}"/>'
                 f'<mxPoint as="targetPoint" x="{x2:.0f}" y="{y2:.0f}"/>'
                 f'</mxGeometry></mxCell>')


def measure(steps):
    y, depth = 0, []
    for st in steps:
        if st[0] == '!':
            op = st[1]
            if op == 'end':
                depth.pop() if depth else None
            elif op == 'else':
                y += STEP
            else:
                depth.append(op)
                y += STEP
        elif st[0] == '=':
            y += NOTE_H + 10
        elif st[1] == st[2] if len(st) > 2 else False:
            y += STEP + 10
        else:
            y += STEP
    return y


def page(name, actor, cols, steps, pre='', post=''):
    for st in steps:
        if st[0] in ('!', '='):
            who = st[2] if st[0] == '=' and len(st) > 2 else None
            if who and who not in cols:
                raise KeyError(f'{name}: note merujuk kolom tidak ada -> {who!r}')
            continue
        for c in (st[0], st[1]):
            if c not in cols:
                raise KeyError(f'{name}: pesan merujuk kolom tidak ada -> {c!r}')

    xs, cx = {}, X0
    for c in cols:
        xs[c] = cx + HDR_W / 2
        cx += HDR_W + COL_GAP
    width = cx - COL_GAP + X0

    cells = []
    subtitle = f'{name}' + (f'<br><font style="font-size:10px">prasyarat: {pre}</font>' if pre else '')
    vertex(cells, subtitle, X0, 16, width - 2 * X0, 44 if pre else 24, S_TITLE)

    y = TOP + HDR_H + 14
    if cols[0] == 'Aktor':
        vertex(cells, actor, xs['Aktor'] - 24, TOP - 6, 48, 62, S_ACTOR)
        y = TOP + 80
    for c in cols:
        if c == 'Aktor':
            continue
        fill, stroke = COLOR.get(c, ('#dae8fc', '#6c8ebf'))
        vertex(cells, c, xs[c] - HDR_W / 2, TOP, HDR_W, HDR_H,
               f'{S_HEAD}fillColor={fill};strokeColor={stroke};')

    final = max(y + 8, TOP + HDR_H + 10) + measure(steps) + 30

    for c in cols:
        top = TOP + 62 if c == 'Aktor' else TOP + HDR_H
        vertex(cells, '', xs[c] - 1, top, 2, final - top - 10, S_LIFE)

    y += 26
    frag, act = [], {}
    for st in steps:
        if st[0] == '!':
            op, guard = st[1], (st[2] if len(st) > 2 else '')
            if op == 'end':
                top = frag.pop()
                vertex(cells, '', X0, top - 16, width - 2 * X0, y - top + 20, S_FRAG)
            elif op == 'else':
                free_arrow(cells, X0, y, width - 2 * X0, y, f'[ {guard} ]',
                           'html=1;endArrow=none;dashed=1;strokeColor=#666666;fontSize=10;'
                           'verticalAlign=bottom;align=left;')
                y += STEP
            else:
                frag.append(y)
                vertex(cells, f'{op} {guard}'.strip(), X0, y - 12, 118, 24, S_TAG)
                y += STEP
            continue
        if st[0] == '=':
            who = st[2] or cols[-1]
            vertex(cells, st[1], xs[who] - 110, y, 280, NOTE_H, S_NOTE)
            y += NOTE_H + 10
            continue

        src, dst, label = st[0], st[1], st[2]
        kind = st[3] if len(st) > 3 else 'c'
        if src == dst:
            st = S_MSG if kind == 'c' else S_RET
            x1, xb = xs[src] + ACT_W / 2, xs[src] + 56
            free_arrow(cells, x1, y, xb, y, '', 'html=1;endArrow=none;strokeColor=#333333;')
            free_arrow(cells, xb, y, xb, y + 20, '', 'html=1;endArrow=none;strokeColor=#333333;')
            free_arrow(cells, xb, y + 20, x1, y + 20, label, st)
            y += STEP + 12
            continue
        free_arrow(cells, xs[src], y, xs[dst], y, label, S_MSG if kind == 'c' else S_RET)
        if kind == 'c':
            act[dst] = y
        else:
            who = src if src in act else dst
            top = act.pop(who, y - STEP)
            vertex(cells, '', xs[who] - ACT_W / 2, top, ACT_W, max(STEP, y - top), S_ACT)
        y += STEP

    for who, top in act.items():
        vertex(cells, '', xs[who] - ACT_W / 2, top, ACT_W, max(STEP, y - top), S_ACT)

    if post:
        vertex(cells, f'pasca-syarat: {post}', X0, y + 12, width - 2 * X0, 22, S_CAPTION)
        y += 40

    pages.append(dict(name=name, cells=cells,
                      w=width, h=y + 30, actor=actor, cols=cols))
    return width, y + 30


# ===========================================================================
# MOBILE
# ===========================================================================
page('M1 · Masuk (login_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Repository', 'Auth', 'Supabase DB'],
     [('Aktor', 'Halaman', 'isi username + password, tekan Masuk'),
      ('Halaman', 'State', 'AppState.instance.signIn? tidak: langsung AuthService.signIn'),
      ('State', 'Repository', 'signIn(username, password)'),
      ('Repository', 'Auth', 'emailForUsername(u) -> u@sibal.my.id'),
      ('Repository', 'Auth', 'signInWithPassword(email, password)'),
      ('Auth', 'Repository', 'Session + JWT', 'r'),
      ('Repository', 'Supabase DB', 'select profiles where id = auth.uid()'),
      ('Supabase DB', 'Repository', 'baris Profile', 'r'),
      ('=', 'requireProfile() menolak bila baris profil tidak ada, dan menolak '
            'bila is_active = false.', 'Repository'),
      ('!', 'alt', '[sesi + profil aktif]'),
      ('Repository', 'State', 'Profile', 'r'),
      ('State', 'State', 'refresh() menarik data pertama', 'c'),
      ('State', 'Halaman', 'beranda terbuka', 'r'),
      ('!', 'else', '[kredensial salah]'),
      ('Repository', 'Halaman', 'AuthFailure "Username atau password salah."', 'r'),
      ('!', 'end')],
     pre='perangkat pernah menjalankan onboarding; AppEnv.ensureConfigured() lolos',
     post='AuthState.onAuthStateChange berisi sesi; AppState.profile terisi')

page('M2 · Daftar akun baru (login_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Auth', 'Supabase DB', 'PostgREST'],
     [('Aktor', 'Halaman', 'isi username, nama lengkap, password'),
      ('Halaman', 'State', 'signUp(username, fullName, password)'),
      ('State', 'State', 'validateUsername + validateFullName + validatePassword (≥8)'),
      ('State', 'Auth', 'signUp(email = u@sibal.my.id, password, data:{username, full_name})'),
      ('Auth', 'Supabase DB', 'INSERT auth.users -> trigger app.handle_new_user()'),
      ('=', 'trigger selalu menulis role = \'user\'; nilai role dari klien diabaikan '
            '(0004 menutup lubang eskalasi).', 'Supabase DB'),
      ('Supabase DB', 'PostgREST', 'INSERT public.profiles (id = auth.uid())'),
      ('Auth', 'State', 'Session (hanya bila mailer_autoconfirm mati)', 'r'),
      ('!', 'alt', '[sesi langsung aktif]'),
      ('State', 'Halaman', 'Profile', 'r'),
      ('State', 'State', 'refresh()'),
      ('!', 'else', '[konfirmasi email masih ON]'),
      ('Auth', 'State', 'session = null', 'r'),
      ('State', 'Halaman', 'AuthFailure: matikan Confirm email di dashboard', 'r'),
      ('!', 'end')],
     pre='ConnectivityService.online = true',
     post='akun baru ber-role user; belum admin apa pun')

page('M3 · Pulih sesi saat aplikasi dibuka (main.dart)', 'Pengguna',
     ['Shell', 'Auth', 'State', 'Cache Hive', 'Repository'],
     [('Shell', 'Shell', 'AppBootstrap: Supabase.initialize(url, publishableKey)'),
      ('Shell', 'Auth', 'currentSession'),
      ('!', 'opt', '[sesi tersimpan ada]'),
      ('Shell', 'State', 'attachProfile(Profile hasil loadProfile)'),
      ('State', 'Cache Hive', 'init(): buka box labs/pcs/support/jobs/ann/stats'),
      ('State', 'State', 'start() -> refresh()'),
      ('State', 'Repository', '7 baca paralel (lihat M4)'),
      ('!', 'else', '[belum ada sesi]'),
      ('=', 'refresh() keluar lebih dulu: tabel bisnis menolak role anon dengan 401, '
            'dan deretan error itu bukan informasi bagi pengguna.', 'State'),
      ('Shell', 'Shell', 'tampilkan login_page', 'r'),
      ('!', 'end')],
     pre='perangkat pernah login',
     post='state = ready/offline sesuai jaringan')

page('M4 · Muat & sinkron data (summary_page.dart / refresh)', 'Pengguna',
     ['Halaman', 'State', 'Repository', 'PostgREST', 'Supabase DB', 'Cache Hive'],
     [('Halaman', 'State', 'refresh()'),
      ('State', 'State', 'set state = loading, notifyListeners()'),
      ('State', 'Repository', 'Future.wait(labs, pcs, supportingItems, recentJobs, '
                              'announcements, labStats, myReports)'),
      ('Repository', 'PostgREST', 'GET /rest/v1/<tabel>?select=... (order ascending eksplisit)'),
      ('PostgREST', 'Supabase DB', 'SELECT dengan RLS authenticated'),
      ('Supabase DB', 'PostgREST', 'baris', 'r'),
      ('PostgREST', 'Repository', 'JSON list<Row>', 'r'),
      ('Repository', 'State', 'List<Lab>, List<PcAsset>, ... LabStats, myReports', 'r'),
      ('State', 'Cache Hive', 'replaceAll(6 box) + markSynced()'),
      ('State', 'Halaman', 'state = ready', 'r'),
      ('!', 'alt', '[perangkat offline]'),
      ('State', 'State', 'throw _Offline (non-web)'),
      ('State', 'Cache Hive', 'read(6 box) -> _loadFromCache()'),
      ('State', 'Halaman', 'state = offline + banner, pengajuan dikunci', 'r'),
      ('!', 'end')],
     pre='signedIn = true',
     post='daftar di内存 = isi cloud terbaru; cache = salinan terakhir')

page('M5 · Baca pengumuman & aktivitas (summary_page.dart)', 'Pengguna',
     ['Halaman', 'State', 'Cache Hive'],
     [('Halaman', 'State', 'bangun widget dari s.liveAnnouncements / s.jobs'),
      ('State', 'State', 'liveAnnouncements = announcements.where(masihTayang(now))'),
      ('State', 'State', 'aktivitas terkini = jobs + myReports urut waktu, diformat '
                         'relative ("10 mnt lalu")'),
      ('State', 'Halaman', 'daftar siap tampil (tanpa request baru)', 'r'),
      ('!', 'opt', '[state = offline]'),
      ('Halaman', 'Cache Hive', 'isi box announcements/jobs dibaca lewat _loadFromCache'),
      ('!', 'end')],
     pre='M4 sudah selesai',
     post='tidak ada tulis apa pun; pengumuman kadaluarsa tidak tampil')

page('M6 · Lihat daftar PC per lab (pc_management_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Repository', 'Cache Hive'],
     [('Aktor', 'Halaman', 'pilih chip Lab / ketik cari'),
      ('Halaman', 'State', 'setLabFilter(labId)'),
      ('State', 'State', 'notifyListeners()'),
      ('State', 'State', 'visiblePcs = pcs.where(labId) lalu sort codename'),
      ('!', 'alt', '[state = ready]'),
      ('State', 'Halaman', 'daftar PcAsset + AssetChip', 'r'),
      ('!', 'else', '[offline]'),
      ('State', 'Cache Hive', 'pcs dari box cache'),
      ('State', 'Halaman', 'daftar + banner offline', 'r'),
      ('!', 'end')],
     pre='M4 selesai',
     post='hanya is_active = true yang sampai ke pengguna (filter ada di query, bukan UI)')

page('M7 · Ajukan kerusakan PC (report_sheet.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'Sheet', 'State', 'Repository', 'RPC', 'Supabase DB', 'Cache Hive'],
     [('Aktor', 'Sheet', 'pilih PC, isi deskripsi + severity, tekan Kirim'),
      ('Sheet', 'State', 'tolak kirim bila AppState.online = false'),
      ('Sheet', 'State', 'submitReport(pcId, issue, severity)'),
      ('State', 'Repository', 'reportIssue(p_pc_id, p_issue, p_severity, p_evidence_paths)'),
      ('Repository', 'RPC', 'sibal_report_issue'),
      ('RPC', 'Supabase DB', 'SELECT pcs FOR UPDATE + cek tiket terbuka (reports_open_pc)'),
      ('!', 'alt', '[belum ada tiket terbuka]'),
      ('RPC', 'Supabase DB', 'INSERT reports (status menunggu, prev_asset_status, lab_id)'),
      ('RPC', 'Supabase DB', 'UPDATE pcs SET status = dalam_pengajuan'),
      ('!', 'else', '[sudah ada tiket terbuka]'),
      ('RPC', 'Supabase DB', 'INSERT report_witness (report_id, auth.uid()) — tanpa tiket baru'),
      ('!', 'end'),
      ('=', 'Semua langkah di atas satu transaksi: gagal satu, tidak ada yang '
            'terlanjur berubah.', 'Supabase DB'),
      ('RPC', 'Repository', 'ReportIssueResult (tiket id + dibuat/diulang + status aset)', 'r'),
      ('Repository', 'State', 'hasil', 'r'),
      ('State', 'Repository', 'refreshAssets(): pcs, supportingItems, recentJobs, labStats'),
      ('State', 'Repository', 'refreshMyReports(): myReports()'),
      ('State', 'Cache Hive', 'replaceAll + markSynced'),
      ('State', 'Sheet', 'tutup sheet + snackbar "Laporan terkirim"', 'r'),
      ('Sheet', 'Halaman', 'kartu PC berubah menjadi amber "Dalam Pengajuan"', 'r')],
     pre='aset terpilih tidak punya tiket terbuka ATAS nama pengguna yang sama; '
         'deskripsi 5..2000 karakter',
     post='reports 1 baris (atau report_witness 1 baris), pcs.status = dalam_pengajuan')

page('M8 · Batalkan pengajuan (pc_management_page / my_reports_page)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Batalkan Pengajuan'),
      ('Halaman', 'Halaman', 'dialog konfirmasi'),
      ('Aktor', 'Halaman', 'Ya'),
      ('Halaman', 'State', 'cancelMyReport(reportId)'),
      ('State', 'Repository', 'cancelReport(p_report_id)'),
      ('Repository', 'RPC', 'sibal_cancel_report'),
      ('RPC', 'Supabase DB', 'cek user_id = auth.uid() dan status masih menunggu'),
      ('!', 'alt', '[pemilik dan masih terbuka]'),
      ('RPC', 'Supabase DB', 'UPDATE reports SET status = batal'),
      ('RPC', 'Supabase DB', 'UPDATE aset SET status = prev_asset_status'),
      ('RPC', 'Repository', 'void (HTTP 204)', 'r'),
      ('State', 'Repository', 'refreshAssets() + refreshMyReports()'),
      ('!', 'else', '[bukan pemilik / sudah diperiksa]'),
      ('RPC', 'Supabase DB', 'RAISE EXCEPTION berbahasa Indonesia'),
      ('Repository', 'State', 'CloudFailure(message)', 'r'),
      ('State', 'Halaman', 'snackbar error, daftar tidak berubah', 'r'),
      ('!', 'end')],
     pre='tiket ber-status menunggu dan report.user_id = sesi ini',
     post='status aset dipulihkan persis seperti sebelum dilapor')

page('M9 · Lihat inventaris pendukung (support_inventory_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State'],
     [('Aktor', 'Halaman', 'pilih chip Lab / filter status'),
      ('Halaman', 'State', 'visibleItems = items.where(labId) sort name'),
      ('State', 'State', 'ringkasan: totalQty = fold(qty); siap = where(status baik)'),
      ('State', 'State', 'perhatian = where(status.butuhPerhatian or habis)'),
      ('State', 'Halaman', 'kartu per jenis barang + qtyLabel "12 rol"', 'r'),
      ('=', 'qty dan status aset TIDAK bisa diubah dari sini: tidak ada stepper, '
            'dan tidak ada RPC tulis untuk pengguna.', 'Halaman')],
     pre='M4 selesai',
     post='nihil (hanya baca)')

page('M10 · Ajukan kerusakan barang (report_sheet.dart, target item)', 'Pengguna',
     ['Aktor', 'Sheet', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Sheet', 'pilih barang, isi gejala + severity'),
      ('Sheet', 'State', 'submitReport(itemId, issue, severity)'),
      ('State', 'Repository', 'reportIssue(p_supporting_item_id: itemId, ...)'),
      ('Repository', 'RPC', 'sibal_report_issue'),
      ('RPC', 'Supabase DB', 'SELECT supporting_items FOR UPDATE + cek reports_open_support'),
      ('RPC', 'Supabase DB', 'INSERT reports (pc_id NULL, item terisi -> target_kind '
                             'otomatis supporting_item)'),
      ('RPC', 'Supabase DB', 'UPDATE status = dalam_pengajuan'),
      ('RPC', 'Repository', 'ReportIssueResult', 'r'),
      ('State', 'Repository', 'refreshAssets() + refreshMyReports()'),
      ('Sheet', 'Aktor', 'snackbar + kartu amber', 'r')],
     pre='num_nonnulls(pc_id, supporting_item_id) = 1 ditegakkan database',
     post='satu tiket terbuka untuk barang itu; qty belum bergerak')

page('M11 · Daftar pengajuan saya (my_reports_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Repository', 'PostgREST', 'Supabase DB'],
     [('Aktor', 'Halaman', 'buka tab Pengajuan / ganti filter layanan'),
      ('Halaman', 'State', 'myReports sudah ada di memori; filter lokal targetKind'),
      ('Aktor', 'Halaman', 'tarik untuk segarkan'),
      ('Halaman', 'State', 'refreshMyReports()'),
      ('State', 'Repository', 'myReports()'),
      ('Repository', 'PostgREST', 'GET reports?user_id=eq.<uid>&order=created_at.desc&limit=100'
                                  '&select=*,labs(...),pcs(...),supporting_items(...)'),
      ('PostgREST', 'Supabase DB', 'SELECT (RLS: pengguna hanya melihat tiketnya)'),
      ('=', 'embed report_witness sengaja TIDAK dipakai di mobile: policy membuatnya '
            'selalu 1 baris untuk diri sendiri, jadi jumlahnya akan palsu.', 'Repository'),
      ('Supabase DB', 'Repository', 'row + embed', 'r'),
      ('Repository', 'State', 'List<Report>', 'r'),
      ('State', 'Halaman', 'metrik terbuka/selesai/batal + kartu tiket', 'r')],
     pre='signedIn',
     post='daftar milik pengguna saja; tidak ada tulis')

page('M12 · Buka Berita Acara servis (berita_acara.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Cache Hive'],
     [('Aktor', 'Halaman', 'tekan "Berita Acara" pada tiket selesai'),
      ('Halaman', 'State', '_jobFor(reportId) cari MaintenanceJob di s.jobs'),
      ('State', 'Cache Hive', 'jobs berasal dari recentJobs() saat M4 / M7'),
      ('State', 'Halaman', 'MaintenanceJob', 'r'),
      ('Halaman', 'Halaman', 'dialog: tindakan, petugas, tanggal WIB, qty_delta, hasil'),
      ('=', 'Tidak ada request cloud: berita acara disusun dari data yang sudah '
            'ditarik. Tombol "Unduh PDF" sengaja tidak ada.', 'Halaman')],
     pre='tiket punya baris maintenance_histories ber-status selesai',
     post='nihil')

page('M13 · Edit profil sendiri (profile_page.dart)', 'Pengguna',
     ['Aktor', 'Halaman', 'State', 'Repository', 'PostgREST', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Edit Profil, ubah nama / deskripsi'),
      ('Halaman', 'State', 'AuthService.updateOwnProfile(fullName, description)'),
      ('State', 'State', 'validateFullName (2..80) + deskripsi ≤ 280'),
      ('State', 'PostgREST', 'PATCH profiles?select=* (hanya full_name, description)'),
      ('PostgREST', 'Supabase DB', 'UPDATE ... WHERE id = auth.uid()'),
      ('=', 'kolom role dan is_active tidak dikirim: grant hanya membuka full_name, '
            'description, avatar_path — itu yang mencegah menaikkan diri jadi admin.',
       'Supabase DB'),
      ('Supabase DB', 'PostgREST', 'baris baru', 'r'),
      ('PostgREST', 'State', 'Profile', 'r'),
      ('State', 'State', 'attachProfile(p) + notifyListeners()'),
      ('State', 'Halaman', 'kartu identitas terbaru', 'r')],
     pre='email sintetis tidak ditampilkan dan tidak bisa diubah',
     post='profil pemilik berubah; role tetap user')

page('M14 · Segarkan data cloud (profile_page.dart)', 'Pengguna',
     ['Halaman', 'State', 'Cache Hive'],
     [('Halaman', 'State', 'btn("Segarkan data cloud") -> refresh()'),
      ('State', 'State', 'alurnya persis M4 (7 baca + replaceAll + markSynced)'),
      ('State', 'Halaman', 'state = ready; teks "Terakhir sinkron" memakai lastSyncedAt', 'r')],
     pre='online',
     post='usia cache diperbarui')

page('M15 · Keadaan offline & penguncian (sync_banner.dart)', 'Pengguna',
     ['Connectivity', 'State', 'Halaman', 'Sheet', 'Cache Hive'],
     [('Connectivity', 'Connectivity', 'stream connectivity_plus berubah'),
      ('Connectivity', 'State', 'online.value = false'),
      ('State', 'State', 'notifyListeners() + _onNetChanged()'),
      ('State', 'Halaman', 'SyncBanner tampil'),
      ('State', 'Sheet', 'tombol Kirim disable + form terkunci'),
      ('State', 'Halaman', 'daftar tetap terisi dari cache'),
      ('=', 'tidak ada antrean tulis offline: pengajuan memang butuh koneksi, dan '
            'menyimpan janji palsu lebih buruk daripada menolak.', 'State'),
      ('Connectivity', 'State', 'online.value = true'),
      ('State', 'State', 'state == offline -> refresh() otomatis'),
      ('State', 'Halaman', 'banner hilang, pengajuan terbuka lagi', 'r')],
     pre='non-web (kIsWeb false), karena web-server selalu dianggap online',
     post='pengguna tidak pernah menulis tabel saat offline')

# ===========================================================================
# PANEL ADMIN
# ===========================================================================
page('A1 · Login panel admin (admin_login.dart)', 'Admin',
     ['Aktor', 'Halaman', 'Shell', 'State', 'Auth', 'Supabase DB'],
     [('Aktor', 'Halaman', 'username + password'),
      ('Halaman', 'Shell', 'AuthService.signIn(username, password)'),
      ('Shell', 'Auth', 'signInWithPassword(email sintetis)'),
      ('Auth', 'Supabase DB', 'SELECT profiles WHERE id = auth.uid()'),
      ('Supabase DB', 'Shell', 'Profile (role, is_active)', 'r'),
      ('Shell', 'State', 'attach(profile) -> refresh()'),
      ('!', 'alt', '[role = admin dan is_active]'),
      ('State', 'Shell', 'state = ready', 'r'),
      ('Shell', 'Aktor', 'sidebar 6 tab', 'r'),
      ('!', 'else', '[role = user]'),
      ('Shell', 'Aktor', 'layar "Anda bukan admin" (kosmetik)', 'r'),
      ('=', 'penegak sebenarnya app.resolve_admin() + RLS + privilege di tiap RPC, '
            'bukan layar ini.', 'Supabase DB'),
      ('!', 'end')],
     pre='build web membawa --dart-define SUPABASE_URL + publishable key',
     post='panel tidak memakai Hive sama sekali')

page('A2 · Muat dashboard admin (admin_state.refresh)', 'Admin',
     ['Halaman', 'State', 'Repository', 'PostgREST', 'Supabase DB'],
     [('Halaman', 'State', 'refresh() (attach / Muat ulang / tiap aksi)'),
      ('State', 'State', 'state = loading; guard _inFlight mencegah dobel'),
      ('State', 'Repository', 'Future.wait 10 baca:'),
      ('Repository', 'PostgREST', 'labs() / pcs(includeInactive) / supportingItems(includeInactive)'),
      ('Repository', 'PostgREST', 'openReports(menunggu,diperiksa,diproses) / allReports()'),
      ('Repository', 'PostgREST', 'recentJobs(150) / openJobs()'),
      ('Repository', 'PostgREST', 'announcements(publishedOnly=false) / profiles() / labStats()'),
      ('PostgREST', 'Supabase DB', 'SELECT + embed labs/pcs/supporting_items/report_witness'),
      ('Supabase DB', 'Repository', 'rows', 'r'),
      ('Repository', 'State', '10 list domain', 'r'),
      ('State', 'State', 'queue.sort(severity.rank desc, created_at asc); _gabungPekerjaan '
                         'buang duplikat job'),
      ('State', 'Halaman', 'KPI + tabel v_lab_stats + antrean teratas + pekerjaan terbuka', 'r'),
      ('=', 'includeInactive = true hanya di panel: policy pcs_read mengizinkan admin '
            'membaca baris arsip.', 'PostgREST')],
     pre='me.role = admin',
     post='tidak ada cache; loadedAt dicatat untuk label "dimuat pukul"')

page('A3 · Antrean · Periksa (queue_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'buka detail tiket, tekan Periksa'),
      ('Halaman', 'State', 'check(reportId, notes?, performedBy?)'),
      ('State', 'Repository', 'checkReport(p_report_id, p_notes, p_performed_by)'),
      ('Repository', 'RPC', 'sibal_check_report'),
      ('RPC', 'Supabase DB', 'app.resolve_admin() -> uid harus role admin & is_active'),
      ('RPC', 'Supabase DB', 'UPDATE reports SET status = diperiksa, reviewed_by = uid, '
                             'decided_at = now()'),
      ('RPC', 'Supabase DB', 'INSERT/UPDATE maintenance_histories status = tertunda '
                             '(satu pekerjaan terbuka per tiket)'),
      ('RPC', 'Repository', 'job id (uuid)', 'r'),
      ('State', 'Repository', 'refresh() 10 baca'),
      ('State', 'Halaman', 'tiket berpindah, chip diproses naik', 'r')],
     pre='tiket ber-status menunggu',
     post='p_performed_by sengaja boleh kosong; p_operator_email tidak pernah dikirim')

page('A4 · Antrean · Setujui (queue_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Setujui: action_taken, kind, status aset, qty_delta'),
      ('Halaman', 'State', 'approve(reportId, actionTaken, kind, assetStatus, performedBy, qtyDelta)'),
      ('State', 'State', 'tolak lebih dulu bila status bukan rusak/diperiksa'),
      ('State', 'Repository', 'approveReport(...) -> _clean buang argumen null'),
      ('Repository', 'RPC', 'sibal_approve_report'),
      ('RPC', 'Supabase DB', 'resolve_admin + SELECT reports FOR UPDATE'),
      ('!', 'alt', '[rusak]'),
      ('RPC', 'Supabase DB', 'UPDATE pcs/items SET status = rusak; tiket = diproses'),
      ('!', 'else', '[diperiksa]'),
      ('RPC', 'Supabase DB', 'UPDATE status = diperiksa; tiket = diproses'),
      ('!', 'end'),
      ('!', 'opt', '[qty_delta <> 0 dan target = barang]'),
      ('RPC', 'Supabase DB', 'p_reason wajib ≥3 -> INSERT riwayat pelengkapan/purnatugas '
                             '+ UPDATE qty'),
      ('!', 'end'),
      ('RPC', 'Supabase DB', 'mh_one_open_job dipakai ulang: approve tidak membuat '
                             'pekerjaan kedua'),
      ('=', 'p_qty_delta yang diisi di Approve DAN di Complete akan menggerakkan stok '
            'dua kali — hint dialog selalu menyebut ini.', 'Repository'),
      ('RPC', 'Repository', 'job id', 'r'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'tiket keluar dari antrean menunggu', 'r')],
     pre='tiket menunggu/diperiksa; aset PC tidak boleh diminta status habis',
     post='tiket diproses + satu pekerjaan berjalan; belum selesai')

page('A5 · Antrean · Tolak (queue_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Tolak, isi alasan'),
      ('Halaman', 'Halaman', 'dialog konfirmasi (danger)'),
      ('Halaman', 'State', 'reject(reportId, reason)'),
      ('State', 'Repository', 'rejectReport(p_report_id, p_reason)'),
      ('Repository', 'RPC', 'sibal_reject_report'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE reports SET status = ditolak, '
                             'admin_notes = reason'),
      ('RPC', 'Supabase DB', 'UPDATE aset SET status = prev_asset_status (pemulihan)'),
      ('RPC', 'Supabase DB', 'pekerjaan tertunda -> dibatalkan'),
      ('RPC', 'Repository', 'void (204)', 'r'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'kartu hilang dari antrean; aset kembali baik', 'r')],
     pre='alasan wajib diisi',
     post='pelapor melihat status ditolak + admin_notes di tab Pengajuan Saya')

page('A6 · Antrean · Buka lagi (queue_page.dart / history_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Buka lagi + alasan'),
      ('Halaman', 'State', 'reopen(reportId, reason)'),
      ('State', 'Repository', 'reopenReport(p_report_id, p_reason)'),
      ('Repository', 'RPC', 'sibal_reopen_report'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE reports SET status = menunggu, '
                             'decided_at = null'),
      ('RPC', 'Supabase DB', 'UPDATE aset SET status = dalam_pengajuan'),
      ('RPC', 'Supabase DB', 'partial unique index melaporkan bila aset itu sudah punya '
                             'tiket terbuka lain'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'tiket kembali ke antrean', 'r')],
     pre='tiket sudah selesai/ditolak',
     post='riwayat lama tetap utuh; satu pekerjaan terbuka baru dibuat saat Periksa')

page('A7 · Aset · Koreksi PC (assets_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Edit data; ubah sebagian kolom'),
      ('Halaman', 'State', 'savePc(...) dengan textFieldValue(asli, sekarang)'),
      ('=', 'konvensi app.text_field: kolom yang tidak disentuh dikirim null (jangan '
            'ubah), yang dikosongkan dikirim \'\' (kosongkan). Trim di Dart akan '
            'menghancurkan bedanya, jadi nilai dikirim apa adanya.', 'State'),
      ('State', 'Repository', 'updatePc(p_pc_id, p_processor, p_ram, p_storage, p_gpu, '
                              'p_mouse_spec, p_keyboard_spec, p_location, p_notes)'),
      ('Repository', 'RPC', 'sibal_update_pc'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE pcs hanya kolom deskriptif'),
      ('=', 'function ini tidak punya parameter status, dan trigger trg_pcs_status_guard '
            'hanya menyala untuk update of status: perubahan status mustahil lewat jalur '
            'ini.', 'Supabase DB'),
      ('RPC', 'Repository', 'void (204)', 'r'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'baris tabel Aset diperbarui', 'r'),
      ('!', 'opt', '[processor atau ram dikosongkan]'),
      ('Supabase DB', 'RPC', 'NOT NULL menolak'),
      ('RPC', 'Repository', 'PostgrestException -> CloudFailure', 'r'),
      ('Repository', 'Halaman', 'dialog tetap terbuka, isian tidak hilang', 'r'),
      ('!', 'end')],
     pre='admin sudah login; dialog adminFormDialog hanya menutup saat RPC sukses',
     post='updated_at berubah lewat trigger trg_touch_pcs')

page('A8 · Aset · Koreksi barang + stok (assets_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'Edit data: nama, kategori, qty baru, alasan'),
      ('Halaman', 'Halaman', 'validasi: nama wajib; qty angka ≥ 0; berubah wajib alasan ≥3'),
      ('Halaman', 'State', 'saveItem(..., qty: qtyIfChanged(lama, baru), reason: ...)'),
      ('State', 'Repository', 'updateSupportItem(p_supporting_item_id, p_name, p_category, '
                              'p_specifications, p_unit, p_location, p_notes, p_qty, p_reason)'),
      ('Repository', 'RPC', 'sibal_update_supporting_item'),
      ('RPC', 'Supabase DB', 'resolve_admin; qty absolut -> delta dihitung server'),
      ('!', 'alt', '[delta <> 0 dan alasan diisi]'),
      ('RPC', 'Supabase DB', 'UPDATE qty; INSERT riwayat pelengkapan (masuk) atau '
                             'purnatugas (keluar) + qty_delta bertanda'),
      ('!', 'else', '[delta <> 0 tanpa alasan]'),
      ('RPC', 'Supabase DB', 'RAISE EXCEPTION'),
      ('Repository', 'State', 'CloudFailure', 'r'),
      ('!', 'end'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'stok baru + hint "tercatat di riwayat"', 'r')],
     pre='p_qty adalah angka absolut, bukan delta — tab Riwayat memakai delta',
     post='stok tidak pernah berubah tanpa baris riwayat')

page('A9 · Aset · Ubah status (assets_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Ubah status + alasan'),
      ('Halaman', 'State', 'pilihan = AdminState.statusUntukPerubahan(sekarang, pc: ...)'),
      ('=', 'dalam_pengajuan tidak ditawarkan (wilayah tiket); habis hanya untuk barang.',
       'Halaman'),
      ('State', 'Repository', 'setAssetStatus(p_pc_id | p_supporting_item_id, p_status, '
                              'p_reason)'),
      ('Repository', 'RPC', 'sibal_set_asset_status'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE status + INSERT riwayat inspeksi '
                             '(report_id NULL)'),
      ('RPC', 'Supabase DB', 'trg_*_status_guard: status dalam_pengajuan hanya boleh '
                             'lewat tiket'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'AssetChip baru; baris riwayat muncul di tab Riwayat', 'r')],
     pre='alasan minimal 3 karakter',
     post='perubahan status selalu meninggalkan jejak riwayat')

page('A10 · Riwayat · Selesaikan (history_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Selesaikan: catatan, hasil aset, delta stok'),
      ('Halaman', 'State', 'complete(jobId, notes, outcome, qtyDelta)'),
      ('State', 'Repository', 'completeMaintenance(p_maintenance_id, p_notes, p_outcome, '
                              'p_qty_delta)'),
      ('Repository', 'RPC', 'sibal_complete_maintenance'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE maintenance_histories SET status = '
                             'selesai, completed_at = now()'),
      ('RPC', 'Supabase DB', 'UPDATE aset SET status = p_outcome (baik / purnatugas)'),
      ('RPC', 'Supabase DB', 'UPDATE reports SET status = selesai'),
      ('!', 'opt', '[qty_delta <> 0]'),
      ('RPC', 'Supabase DB', 'gerakkan qty + baris riwayat tambahan; delta tanpa alasan '
                             'ditolak'),
      ('!', 'end'),
      ('=', 'mh_done_stamp melarang status selesai tanpa completed_at; tanggal kerja '
            'dipakai sebagai date kalender WIB, bukan jam server UTC.', 'Supabase DB'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'pekerjaan hilang dari daftar terbuka', 'r')],
     pre='pekerjaan ber-status tertunda/berjalan',
     post='tiket + aset + stok berubah dalam SATU transaksi')

page('A11 · Riwayat · Buka lagi tiket dari riwayat (history_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'tekan Buka lagi pada baris riwayat'),
      ('Halaman', 'State', 'reopen(reportId, reason)'),
      ('State', 'Repository', 'reopenReport'),
      ('Repository', 'RPC', 'sibal_reopen_report'),
      ('RPC', 'Supabase DB', 'tiket kembali menunggu; aset dalam_pengajuan'),
      ('RPC', 'Supabase DB', 'riwayat yang sudah selesai TIDAK dihapus — hanya bertambah'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'tab Antrean bertambah satu; chip menunggu naik', 'r')],
     pre='riwayat menunjuk tiket yang ada',
     post='jejak historis utuh untuk laporan')

page('A12 · Broadcast · Buat / ubah (broadcast_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'Pengumuman baru / Edit: judul, isi, level, batas tayang'),
      ('Halaman', 'Halaman', 'validasi judul 3..120, isi wajib, exp > tayang'),
      ('Halaman', 'State', 'saveAnnouncement(id?, title, body, level, isPublished, expiresAt)'),
      ('State', 'Repository', 'upsertAnnouncement(p_id?, p_title, p_body, p_level, '
                              'p_is_published, p_expires_at)'),
      ('=', 'p_id/p_title/p_body diberi DEFAULT NULL di SQL supaya PostgREST tidak '
            'menolak karena nama argumen tidak cocok (PGRST202).', 'Repository'),
      ('Repository', 'RPC', 'sibal_upsert_announcement'),
      ('RPC', 'Supabase DB', 'resolve_admin; ann_window_sane: expires_at harus sesudah '
                             'published_at'),
      ('!', 'alt', '[id kosong]'),
      ('RPC', 'Supabase DB', 'INSERT + RETURNING id'),
      ('!', 'else', '[id ada]'),
      ('RPC', 'Supabase DB', 'UPDATE by id'),
      ('!', 'end'),
      ('State', 'Repository', 'refresh() (announcements publishedOnly=false)'),
      ('State', 'Halaman', 'baris baru/ubah; keadaan Draf / Jadual / Tayang dihitung UI', 'r')],
     pre='function ini selalu menerima judul dan isi (bukan konvensi null seperti '
         'kolom aset)',
     post='pengumuman draf tidak tampil di mobile')

page('A13 · Broadcast · Terbitkan / tarik (broadcast_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Terbitkan (atau Tarik)'),
      ('Halaman', 'State', 'saveAnnouncement(id, title, body, level, !isPublished, '
                           'expiresAt) — upsert memakai kolom lama'),
      ('State', 'Repository', 'upsertAnnouncement(...)'),
      ('Repository', 'RPC', 'sibal_upsert_announcement'),
      ('RPC', 'Supabase DB', 'ann_published_needs_date: is_published wajib '
                             'published_at bukan null'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'chip Tayang/Draf berubah; mobile mengambilnya pada M4 '
                           'berikutnya', 'r')],
     pre='pengumuman sudah punya judul & isi',
     post='perubahan hanya is_published + published_at')

page('A14 · Broadcast · Hapus (broadcast_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Hapus'),
      ('Halaman', 'Halaman', 'dialog konfirmasi danger'),
      ('Halaman', 'State', 'deleteAnnouncement(id)'),
      ('State', 'Repository', 'deleteAnnouncement(p_id)'),
      ('Repository', 'RPC', 'sibal_delete_announcement'),
      ('RPC', 'Supabase DB', 'resolve_admin; DELETE announcements WHERE id = p_id'),
      ('=', 'riwayat tiket dan aset tidak tersentuh — pengumuman tidak punya FK keluar.',
       'Supabase DB'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'baris hilang dari daftar', 'r')],
     pre='tidak ada undo: hapus permanen',
     post='mobile berhenti menampilkannya pada sinkron berikutnya')

page('A15 · Pengguna · Angkat / turunkan peran (users_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Jadikan admin / Turunkan peran'),
      ('Halaman', 'Halaman', 'tombol untuk akun sendiri nonaktif'),
      ('Halaman', 'State', 'setRole(userId, role)'),
      ('State', 'Repository', 'setUserRole(p_user_id, p_role)'),
      ('Repository', 'RPC', 'sibal_set_user_role'),
      ('RPC', 'Supabase DB', 'resolve_admin(pemanggil); UPDATE profiles SET role'),
      ('=', 'satu-satunya jalur tulis untuk kolom role; grant pemilik hanya membuka '
            'full_name/description/avatar_path, jadi user tidak bisa mengangkat '
            'dirinya sendiri.', 'Supabase DB'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'chip admin berpindah; target kehilangan/medapat akses '
                           'pada RPC berikutnya', 'r')],
     pre='admin pertama diangkat lewat SQL Editor, bukan lewat layar ini',
     post='perubahan berlaku mulai panggilan RPC berikutnya (sesi tidak dihapus)')

page('A16 · Pengguna · Aktif / nonaktif akun (users_page.dart)', 'Admin',
     ['Aktor', 'Halaman', 'State', 'Repository', 'RPC', 'Supabase DB'],
     [('Aktor', 'Halaman', 'titik-tiga > Nonaktifkan / Aktifkan'),
      ('Halaman', 'State', 'setActive(userId, isActive)'),
      ('State', 'Repository', 'setUserActive(p_user_id, p_is_active)'),
      ('Repository', 'RPC', 'sibal_set_user_active'),
      ('RPC', 'Supabase DB', 'resolve_admin; UPDATE profiles SET is_active'),
      ('RPC', 'Supabase DB', 'setiap RPC memanggil app.resolve_admin yang menuntut '
                             'is_active -> sesi lama langsung tidak berguna'),
      ('!', 'alt', '[menonaktifkan diri sendiri]'),
      ('RPC', 'Supabase DB', 'ditolak / tombol sudah nonaktif di UI'),
      ('!', 'else', '[akun lain]'),
      ('State', 'Repository', 'refresh()'),
      ('State', 'Halaman', 'keadaan Akun nonaktif; login berikutnya gagal', 'r'),
      ('!', 'end')],
     pre='panel tidak bisa membuat/menghapus akun: itu butuh service_role',
     post='akun nonaktif ditolak semua RPC admin dan pembacaan data')

# ===========================================================================
# Emit
# ===========================================================================
def emit(path):
    chunks = []
    for i, p in enumerate(pages):
        chunks.append(
            f'  <diagram id="seq{i}" name="{esc(p["name"])}">\n'
            f'    <mxGraphModel dx="{p["w"]}" dy="{p["h"]}" grid="1" gridSize="10" guides="1" '
            f'connect="1" arrows="1" page="1" pageWidth="{p["w"]}" pageHeight="{p["h"]}" '
            f'math="0" shadow="0">\n      <root>\n        <mxCell id="0" />\n'
            f'        <mxCell id="1" parent="0" />\n        '
            + '\n        '.join(p['cells'])
            + '\n      </root>\n    </mxGraphModel>\n  </diagram>')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('<mxfile host="app.diagrams.net" agent="Qoder" version="24.7.7" type="device" '
                f'pages="{len(pages)}">\n' + '\n'.join(chunks) + '\n</mxfile>\n')
    return len(pages)


if __name__ == '__main__':
    dst = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'sequence_diagram.drawio'))
    n = emit(dst)
    print(f'{dst} · {n} halaman')
    for p in pages:
        print(f'  {p["name"]:<58} {p["cols"][1] if len(p["cols"])>1 else "":<12} '
              f'{p["w"]:5.0f} x {p["h"]:5.0f}')
