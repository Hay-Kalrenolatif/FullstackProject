#!/usr/bin/env python3
"""Generator flowchart (.drawio) untuk alur SIBAL — dua halaman.

Halaman 1 "Alur Utama": satu putaran penuh, simbol flowchart standar
(terminator pil, proses kotak, keputusan belah ketupat) dengan warna penanda
siapa yang beraksi.

Halaman 2 "Cabang & Aturan": percabangan yang tidak muat di jalur utama —
tiket terbuka yang sudah ada (saksi), penolakan non-admin, aturan
p_asset_status saat approve, pergerakan stok, buka lagi, dan pembatalan.

Isinya mengikuti activity_combined_detailed.mmd v2 (kosakata status wire,
gerbang offline, cabang saksi/stok, aturan approve): .mmd tetap sumber yang
bisa di-diff, berkas ini versi yang diedit di draw.io.

    python docs/perancangan/tools/gen_flowchart_drawio.py
"""
import os

STYLES = {
    'term':  'rounded=1;arcSize=50;whiteSpace=wrap;html=1;fontSize=12;fontStyle=1;'
             'fillColor=#d5e8d4;strokeColor=#82b366;',
    'user':  'rounded=0;whiteSpace=wrap;html=1;fontSize=12;fillColor=#dae8fc;strokeColor=#6c8ebf;',
    'admin': 'rounded=0;whiteSpace=wrap;html=1;fontSize=12;fillColor=#ffe6cc;strokeColor=#d79b00;',
    'srv':   'rounded=0;whiteSpace=wrap;html=1;fontSize=12;dashed=1;'
             'fillColor=#f5f5f5;strokeColor=#666666;',
    'dec':   'rhombus;whiteSpace=wrap;html=1;fontSize=11;fillColor=#fff2cc;strokeColor=#d6b656;',
    'note':  'shape=note;whiteSpace=wrap;html=1;align=left;verticalAlign=top;fontSize=11;'
             'fillColor=#fffbe6;strokeColor=#d6b656;spacing=8;',
    'head':  'text;html=1;align=left;verticalAlign=middle;fontSize=14;fontStyle=1;',
}
EDGE = ('edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;'
        'strokeColor=#666666;fontSize=11;')

MAIN_X, MAIN_W = 700, 330
SIDE_L, SIDE_R = 290, 1140
SIDE_W = 300
STEP = 92


class Page:
    def __init__(self, name, ident, w, h):
        self.name, self.ident, self.w, self.h = name, ident, w, h
        self.cells, self.nodes, self.links = [], [], []
        self._n = 0

    def put(self, style, label, cx, cy, w=MAIN_W, h=56):
        self._n += 1
        nid = f'{self.ident}n{self._n}'
        self.nodes.append(dict(id=nid, label=label, x=cx - w / 2, y=cy - h / 2,
                               w=w, h=h, style=style))
        return nid

    def link(self, a, b, label='', points=()):
        self.links.append(dict(src=a, dst=b, label=label, points=list(points)))
        return b

    def note(self, label, cx, cy, w=300, h=210):
        return self.put('note', label, cx, cy, w, h)

    def xml(self):
        for n in self.nodes:
            self.cells.append(
                f'<mxCell id="{n["id"]}" value="{esc(n["label"])}" style="{STYLES[n["style"]]}" '
                f'vertex="1" parent="1"><mxGeometry x="{n["x"]:.0f}" y="{n["y"]:.0f}" '
                f'width="{n["w"]:.0f}" height="{n["h"]:.0f}" as="geometry"/></mxCell>')
        for i, l in enumerate(self.links):
            pts = ''.join(f'<mxPoint x="{x}" y="{y}"/>' for x, y in l['points'])
            arr = f'<Array as="points">{pts}</Array>' if pts else ''
            self.cells.append(
                f'<mxCell id="{self.ident}e{i}" value="{esc(l["label"])}" style="{EDGE}" '
                f'edge="1" parent="1" source="{l["src"]}" target="{l["dst"]}">'
                f'<mxGeometry relative="1" as="geometry">{arr}</mxGeometry></mxCell>')
        return (f'<diagram id="{self.ident}" name="{esc(self.name)}">\n'
                f'      <mxGraphModel dx="{self.w}" dy="{self.h}" grid="1" gridSize="10" '
                f'guides="1" connect="1" arrows="1" page="1" pageWidth="{self.w}" '
                f'pageHeight="{self.h}" math="0" shadow="0">\n        <root>\n'
                f'          <mxCell id="0" />\n          <mxCell id="1" parent="0" />\n          '
                + '\n          '.join(self.cells)
                + '\n        </root>\n      </mxGraphModel>\n    </diagram>')


def esc(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;'))


# ===========================================================================
# Halaman 1 — alur utama
# ===========================================================================
p1 = Page('Alur Utama', 'p1', 1600, 1700)
Y = 60

start = p1.put('term', 'Mulai', MAIN_X, Y, 180)
Y += STEP
open_app = p1.put('user', 'Pengguna membuka aplikasi SIBAL', MAIN_X, Y)
p1.link(start, open_app)

Y += STEP
d_onb = p1.put('dec', 'Onboarding sudah dilihat di perangkat ini?', MAIN_X, Y, 300, 76)
p1.link(open_app, d_onb)
onb = p1.put('user', 'Selesaikan onboarding, lalu simpan flag perangkat',
             SIDE_R, Y, SIDE_W, 56)
p1.link(d_onb, onb, 'Belum')

Y += STEP
login = p1.put('user', 'Login lewat Supabase Auth memakai username\n'
                       '(username diubah jadi email sintetis di domain sibal.my.id)',
               MAIN_X, Y, MAIN_W, 62)
p1.link(d_onb, login, 'Sudah')
p1.link(onb, login, '', [(SIDE_R, Y - 46)])

Y += STEP
d_log = p1.put('dec', 'Login berhasil?', MAIN_X, Y, 220, 70)
p1.link(login, d_log)
p1.link(d_log, login, 'Tidak', [(1450, Y - 46), (1450, Y - STEP + 40)])

Y += STEP
sync = p1.put('srv', 'Data ditarik dari PostgREST, lalu ditulis penuh ke cache Hive',
              MAIN_X, Y, MAIN_W, 56)
p1.link(d_log, sync, 'Ya')

Y += STEP
d_net = p1.put('dec', 'Perangkat online?', MAIN_X, Y, 220, 70)
p1.link(sync, d_net)
off = p1.put('user', 'Banner offline tampil · daftar dibaca dari cache · '
                     'tombol pengajuan dikunci', SIDE_R, Y, SIDE_W, 62)
p1.link(d_net, off, 'Tidak')
p1.link(off, sync, '', [(1480, Y - 30), (1480, Y - STEP)])

Y += STEP
browse = p1.put('user', 'Pilih Lab, lihat daftar PC / Inventaris Pendukung '
                        'beserta status dan spesifikasi', MAIN_X, Y, MAIN_W, 62)
p1.link(d_net, browse, 'Ya')

Y += STEP
report = p1.put('user', 'Tekan "Ajukan Kerusakan", isi deskripsi + severity', MAIN_X, Y)
p1.link(browse, report)

Y += STEP
rpc_new = p1.put('srv', 'RPC sibal_report_issue · tiket dibuat status "menunggu", '
                        'aset pindah ke "dalam_pengajuan" — satu transaksi',
                 MAIN_X, Y, MAIN_W, 62)
p1.link(report, rpc_new)

Y += STEP
adm_login = p1.put('admin', 'Admin membuka panel Flutter Web dan login', MAIN_X, Y)
p1.link(rpc_new, adm_login)

Y += STEP
adm_check = p1.put('admin', 'Tab Antrean: tinjau tiket lalu tekan "Periksa" · '
                             'tiket "diperiksa", pekerjaan "tertunda" dibuat',
                   MAIN_X, Y, MAIN_W, 62)
p1.link(adm_login, adm_check)

Y += STEP
d_dec = p1.put('dec', 'Keputusan admin', MAIN_X, Y, 220, 70)
p1.link(adm_check, d_dec)

reject = p1.put('admin', 'Tolak + alasan ·\ntiket "ditolak",\naset dipulihkan ke '
                         'prev_asset_status', SIDE_L, Y, SIDE_W, 84)
p1.link(d_dec, reject, 'Tolak')
approve = p1.put('admin', 'Setujui: action_taken + kind +\naset jadi "rusak" atau "diperiksa"',
                 SIDE_R, Y, SIDE_W, 70)
p1.link(d_dec, approve, 'Setujui')

Y += STEP
complete = p1.put('srv', 'sibal_complete_maintenance · pekerjaan "selesai", '
                         'tiket "selesai", aset kembali "baik"', MAIN_X, Y, MAIN_W, 62)
p1.link(approve, complete, '', [(SIDE_R, Y - 46)])
p1.link(reject, complete, '', [(SIDE_L, Y - 46)])

Y += STEP
seen = p1.put('user', 'Pengguna melihat hasilnya di Pengajuan Saya & riwayat servis',
              MAIN_X, Y)
p1.link(complete, seen)

Y += STEP
end = p1.put('term', 'Selesai', MAIN_X, Y, 180)
p1.link(seen, end)

p1.note('<b>Legenda warna</b><br>'
        '• hijau pil = mulai / selesai<br>'
        '• <font color="#6c8ebf">biru</font> = aksi pengguna di aplikasi mobile<br>'
        '• <font color="#d79b00">oranye</font> = aksi admin di panel web<br>'
        '• <font color="#666666">abu-abu putus-putus</font> = pekerjaan di sisi '
        'server (PostgREST, RPC, cache)<br>'
        '• kuning belah ketupat = keputusan<br><br>'
        'Semua tulis lewat satu RPC atomik; tidak pernah dua panggilan beruntun.',
        1440, 300, 250, 250)

# ===========================================================================
# Halaman 2 — cabang & aturan
# ===========================================================================
p2 = Page('Cabang dan Aturan', 'p2', 1600, 1400)


def group(page, title, x0, y0, items, arrows):
    page.put('head', f'<b>{title}</b>', x0 + 150, y0, 300, 30)
    ids = {}
    for key, (style, label, cx, cy, w, h) in items.items():
        ids[key] = page.put(style, label, cx, cy, w, h)
    for a, b, lab, pts in arrows:
        page.link(ids[a], ids[b], lab, pts)
    return ids


# A. tiket terbuka sudah ada -> saksi
idsA = group(
    p2, 'A. Aset sudah punya tiket terbuka?', 100, 90,
    {
        'd': ('dec', 'ada tiket belum selesai\nuntuk aset yang sama?', 280, 230, 260, 90),
        'w': ('user', 'pelapor dicatat sebagai <b>saksi</b> '
                      '(report_witness) pada tiket yang ada — tiket kedua tidak dibuat',
              280, 380, 300, 76),
        'n': ('srv', 'tiket baru dibuat, <i>prev_asset_status</i> direkam untuk '
                      'pemulihan saat ditolak / dibatalkan', 280, 500, 300, 76),
        'note': ('note', 'Ditegakkan oleh partial unique index reports_open_pc / '
                         'reports_open_support: satu tiket terbuka per aset.',
                 660, 440, 280, 120),
    },
    [('d', 'w', 'Ya', ()), ('d', 'n', 'Tidak', ())])

# B. bukan admin
group(
    p2, 'B. Akun bukan admin', 100, 620,
    {
        'd': ('dec', 'profiles.role = admin\ndan is_active?', 280, 760, 260, 90),
        'no': ('srv', 'setiap RPC admin memanggil app.resolve_admin() dan gagal · '
                      'RLS + privilege tetap menolak', 280, 910, 300, 76),
        'no2': ('user', 'UI hanya menampilkan layar "Anda bukan admin" — kosmetik, '
                        'penegaknya ada di server', 280, 1030, 300, 76),
        'yes': ('admin', 'panel terbuka penuh', 660, 760, 280, 56),
    },
    [('d', 'no', 'Tidak', ()), ('no', 'no2', '', ()), ('d', 'yes', 'Ya', ())])

# C. aturan approve
group(
    p2, 'C. Aturan p_asset_status saat Approve', 850, 90,
    {
        'd': ('dec', 'p_asset_status yang\n dipilih?', 1050, 230, 250, 90),
        'rusak': ('srv', 'tiket "diproses" · aset tetap <b>rusak</b>', 880, 390, 280, 56),
        'periksa': ('srv', 'tiket "diproses" · aset <b>diperiksa</b>', 1230, 390, 280, 56),
        'other': ('srv', 'ditolak server — "baik", "habis", "purnatugas" bukan '
                         'hasil approve; mengembalikan aset ke "baik" adalah '
                         'pekerjaan Selesaikan', 1050, 520, 330, 76),
    },
    [('d', 'rusak', 'rusak', ()), ('d', 'periksa', 'diperiksa', ()),
     ('d', 'other', 'nilai lain', ()), ('other', 'd', 'isi ulang', [(1450, 170)])])

# D. stok
group(
    p2, 'D. Stok hanya bergerak beralasan', 850, 640,
    {
        'd': ('dec', 'ada barang masuk /\nkeluar?', 1050, 780, 250, 90),
        'yes': ('srv', 'p_qty_delta + alasan (≥3 karakter) → dibukukan sebagai '
                       'baris riwayat <i>pelengkapan</i> atau <i>purnatugas</i>',
                 880, 940, 300, 86),
        'no': ('srv', 'delta 0 — dan <b>jangan diisi lagi</b> saat Complete, '
                      'kalau diisi di keduanya stok bergerak dua kali',
               1240, 940, 300, 86),
    },
    [('d', 'yes', 'Ya', ()), ('d', 'no', 'Tidak', ())])

# E. buka lagi & batalkan
group(
    p2, 'E. Setelah tiket selesai', 850, 1090,
    {
        'dr': ('dec', 'perlu dibuka lagi?', 950, 1210, 220, 80),
        'reopen': ('admin', 'sibal_reopen_report → tiket kembali ke antrean, '
                           'aset masuk "dalam_pengajuan" lagi', 1290, 1180, 300, 76),
        'dc': ('dec', 'pelapor membatalkan\nsebelum selesai?', 950, 1330, 240, 84),
        'cancel': ('srv', 'sibal_cancel_report — hanya pemilik, hanya tiket masih '
                          'terbuka → tiket "batal", aset dipulihkan',
                   1290, 1310, 300, 76),
    },
    [('dr', 'reopen', 'Ya', ()), ('dc', 'cancel', 'Ya', ())])

p2.note('<b>Kenapa cabang ini dipisah</b><br>'
        'Halaman 1 hanya jalur utama supaya bisa diceritakan sekali tarik. '
        'Aturan yang membuat sistemnya aman (satu tiket per aset, approve tidak '
        'boleh menghasilkan "baik", stok wajib alasan, pembatalan hanya oleh '
        'pemilik) justru hidup di halaman ini.', 100, 1180, 300, 200)

# ===========================================================================
dst = os.path.join(os.path.dirname(__file__), '..', 'flowchart.drawio')
xml = ('<mxfile host="app.diagrams.net" agent="Qoder" version="24.7.7" type="device">\n'
       '    ' + p1.xml() + '\n    ' + p2.xml() + '\n  </mxfile>\n')
with open(dst, 'w', encoding='utf-8') as f:
    f.write(xml)
print(f'{os.path.normpath(dst)} · p1 {len(p1.nodes)}/{len(p1.links)} · '
      f'p2 {len(p2.nodes)}/{len(p2.links)}')
