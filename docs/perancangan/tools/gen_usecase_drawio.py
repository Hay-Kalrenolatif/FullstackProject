#!/usr/bin/env python3
"""Generator use case diagram UML — versi alur pemakaian (.drawio).

Bedanya dengan versi lama: use case tidak lagi dikelompokkan per fitur, tapi
dinomori sesuai urutan pemakaian satu putaran penuh (1 Masuk → 9 Keluar),
sehingga diagram ini bisa dibaca sebagai cerita tanpa perlu penjelasan lisan.
Cabang diberi huruf (4a, 6b, 7b); use case tanpa angka adalah jalur mandiri.

    python docs/perancangan/tools/gen_usecase_drawio.py

Level tetap eksternal: apa yang orang lakukan, bukan RPC atau tabel.
"""
import os

PAGE_W, PAGE_H = 1900, 1250
UC_W, UC_H = 190, 66
UC_WIDE = 230

STYLE = {
    'actor': 'shape=umlActor;html=1;verticalAlign=bottom;labelPosition=center;'
             'verticalLabelPosition=bottom;fontSize=13;fontStyle=1;'
             'fillColor=#dae8fc;strokeColor=#6c8ebf;',
    'ext':   'shape=umlActor;html=1;verticalAlign=bottom;labelPosition=center;'
             'verticalLabelPosition=bottom;fontSize=13;fontStyle=1;'
             'fillColor=#f5f5f5;strokeColor=#666666;',
    'uc':      'ellipse;html=1;whiteSpace=wrap;fontSize=12;fillColor=#ffffff;strokeColor=#2f6f2f;',
    'ucadmin': 'ellipse;html=1;whiteSpace=wrap;fontSize=12;fillColor=#ffffff;strokeColor=#6c8ebf;',
    'ucstep':  'ellipse;html=1;whiteSpace=wrap;fontSize=12;fontStyle=1;fillColor=#eaf7ee;strokeColor=#2f6f2f;',
    'ucstepadm': 'ellipse;html=1;whiteSpace=wrap;fontSize=12;fontStyle=1;fillColor=#eaf1fb;strokeColor=#6c8ebf;',
    'ucout':   'ellipse;html=1;whiteSpace=wrap;fontSize=12;dashed=1;fillColor=#fafafa;strokeColor=#999999;',
    'sys':     'shape=rect;html=1;whiteSpace=wrap;verticalAlign=top;align=center;fontSize=15;'
               'fontStyle=1;fillColor=none;strokeColor=#333333;spacing=8;',
    'group':   'shape=rect;html=1;whiteSpace=wrap;verticalAlign=top;align=center;fontSize=12;'
               'fontStyle=2;fillColor=#f5f5f5;strokeColor=#999999;dashed=1;opacity=45;spacingTop=6;',
    'note':    'shape=note;html=1;whiteSpace=wrap;align=left;verticalAlign=top;fontSize=11;'
               'fillColor=#fffbe6;strokeColor=#d6b656;spacing=8;',
}
EDGE = {
    'assoc': 'html=1;endArrow=none;startArrow=none;strokeColor=#828282;',
    'inc':   'html=1;endArrow=open;dashed=1;strokeColor=#2f6f2f;',
    'extd':  'html=1;endArrow=open;dashed=1;strokeColor=#9673a6;',
    'flow':  'html=1;endArrow=open;strokeWidth=3;strokeColor=#d79b00;',
    'branch': 'html=1;endArrow=open;dashed=1;strokeColor=#d79b00;',
    'gen':   'html=1;endArrow=block;endFill=0;strokeColor=#333333;',
}

nodes, links = [], []
_seq = [0]


def _id(p):
    _seq[0] += 1
    return f'{p}{_seq[0]}'


def put(kind, label, cx, cy, w=UC_W, h=UC_H, style=None):
    n = dict(id=_id(kind), label=label, x=cx - w / 2, y=cy - h / 2, w=w, h=h, style=style or kind)
    nodes.append(n)
    return n


def link(a, b, kind='assoc', label=''):
    links.append(dict(src=a['id'], dst=b['id'], kind=kind, label=label))


# ---------------------------------------------------------------------------
# Batas sistem + lane
# ---------------------------------------------------------------------------
put('sys', 'SISTEM SIBAL — alur pemakaian satu putaran', 930, 590, 1300, 1000)
put('group', 'Lane 1 · Aplikasi Mobile (flutter, lib/main.dart)', 930, 355, 1240, 330)
put('group', 'Lane 2 · Panel Admin (flutter web, lib/admin_main.dart)', 930, 790, 1240, 460)

# ---------------------------------------------------------------------------
# Aktor
# ---------------------------------------------------------------------------
PENG = put('actor', 'Pengguna / Pengelola Lab', 140, 250, 60, 90)
ADMIN = put('actor', 'Admin', 140, 640, 60, 90)
SUPA = put('ext', 'Operator Dashboard Supabase', 1720, 890, 60, 90)

# ---------------------------------------------------------------------------
# Use case bernomor = jalur utama; bercabang diberi huruf; tanpa angka = mandiri
# ---------------------------------------------------------------------------
# --- Lane mobile, baris atas (y=300)
S1 = put('ucstep', '1. Masuk', 430, 300)
S2 = put('ucstep', '2. Lihat Kondisi Lab', 700, 300)
S3 = put('ucstep', '3. Lihat PC & Inventaris', 1000, 300, UC_WIDE)
S4 = put('ucstep', '4. Ajukan Laporan Kerusakan', 1330, 300, UC_WIDE, style='ucstep')

# --- Lane mobile, baris bawah (y=430)
OUT_ = put('uc', 'Baca Pengumuman', 430, 430)
S8 = put('ucstep', '8. Cek Status Laporan Saya', 760, 430, UC_WIDE, style='ucstep')
S4A = put('uc', '4a. Batalkan Laporan', 1080, 430)
S9 = put('ucstep', '9. Keluar', 1330, 430, 150, style='ucstep')
EDIT = put('uc', 'Edit Profil Saya', 1480, 430, 160)

# --- Lane admin, baris 1 (y=660)
S5 = put('ucstepadm', '5. Periksa Laporan', 1330, 660)
S6 = put('ucstepadm', '6. Setujui Laporan', 1060, 660)
S6B = put('uc', '6b. Tolak Laporan', 810, 660)
S7B = put('uc', '7b. Buka Lagi Laporan', 520, 660, UC_WIDE)

# --- Lane admin, baris 2 (y=800)
AASET = put('ucadmin', 'Kelola Aset & Status', 520, 800)
ABRAD = put('ucadmin', 'Kirim Pengumuman', 810, 800)
S7 = put('ucstepadm', '7. Catat Perbaikan Selesai', 1140, 800, UC_WIDE)
SROLE = put('ucadmin', 'Kelola Akun & Peran', 1420, 800, 190)

# --- Lane admin, baris 3 (y=930)
ARING = put('ucadmin', 'Lihat Ringkasan Lab', 1330, 930)

# --- di luar sistem
OUTUC = put('ucout', 'Buat / Reset / Hapus Akun', 1700, 1060, 210)

# ---------------------------------------------------------------------------
# Jalur utama (panah tebal) — urutan inilah yang harus diingat
# ---------------------------------------------------------------------------
for a, b in [(S1, S2), (S2, S3), (S3, S4), (S4, S5), (S5, S6), (S6, S7), (S7, S8), (S8, S9)]:
    link(a, b, 'flow')

# Cabang
link(S5, S6B, 'branch', 'bila ditolak')
link(S6B, S8, 'branch', 'pengguna melihat "ditolak"')
link(S7B, S5, 'branch', 'dibuka lagi')
link(ABRAD, OUT_, 'branch', 'pengumuman muncul di Beranda')

# ---------------------------------------------------------------------------
# Asosiasi aktor
# ---------------------------------------------------------------------------
for u in (S1, S2, S3, S4, S8, S4A, OUT_, EDIT, S9):
    link(PENG, u)
for u in (S1, S5, S6, S6B, S7B, S7, AASET, ABRAD, SROLE, ARING, S9):
    link(ADMIN, u)
link(SUPA, OUTUC)

# include / extend
link(S4, S1, 'inc', '<<include>>')
link(S4A, S8, 'extd', '<<extend>>')

# Generalisasi aktor, dirute di margin kiri agar tidak memotong lane.
link(ADMIN, PENG, 'gen', 'generalisasi')
links[-1]['points'] = [(95, 640), (95, 250)]

# ---------------------------------------------------------------------------
# Catatan
# ---------------------------------------------------------------------------
put('note',
    '<b>Cara baca</b><br>'
    '• <font color="#d79b00"><b>panah tebal</b></font> = jalur utama 1 → 9, '
    'hafalkan sampai di sini saja<br>'
    '• nomor = urutan pemakaian; huruf (4a, 6b, 7b) = cabang dari langkah itu<br>'
    '• use case tanpa angka = jalur mandiri, di luar satu putaran<br>'
    '• elips hijau = terjadi di HP, elips biru = terjadi di panel web<br>'
    '• <font color="#2f6f2f">putus hijau</font> = «include», '
    '<font color="#9673a6">putus ungu</font> = «extend»<br>'
    '• segitiga terbuka = Admin <i>is-a</i> Pengguna (login-nya sama)',
    210, 1010, 300, 240)

put('note',
    '<b>Satu putaran, satu kalimat</b><br>'
    'Pengguna masuk, melihat lab, menemukan unit rusak, mengajukan laporan — '
    'laporan itu muncul di antrean admin, diperiksa, disetujui, dicatat '
    'perbaikannya, lalu kembali terlihat di HP pengguna sebagai selesai. '
    'Pengguna keluar.<br><br>'
    '"Buat / Reset / Hapus Akun" di luar kotak karena menuntut service_role, '
    'yang tidak boleh ikut dibundel ke web build.',
    950, 1120, 420, 210)

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------
def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


cells = []
for n in nodes:
    cells.append(
        f'<mxCell id="{n["id"]}" value="{esc(n["label"])}" style="{STYLE[n["style"]]}" '
        f'vertex="1" parent="1"><mxGeometry x="{n["x"]:.0f}" y="{n["y"]:.0f}" '
        f'width="{n["w"]:.0f}" height="{n["h"]:.0f}" as="geometry"/></mxCell>')

for i, l in enumerate(links):
    pts = ''.join(f'<mxPoint x="{x}" y="{y}"/>' for x, y in l.get('points', []))
    arr = f'<Array as="points">{pts}</Array>' if pts else ''
    cells.append(
        f'<mxCell id="e{i}" value="{esc(l["label"])}" style="{EDGE[l["kind"]]}" '
        f'edge="1" parent="1" source="{l["src"]}" target="{l["dst"]}">'
        f'<mxGeometry relative="1" as="geometry">{arr}</mxGeometry></mxCell>')

xml = f'''<mxfile host="app.diagrams.net" agent="Qoder" version="24.7.7" type="device">
  <diagram id="sibal-usecase-alur" name="SIBAL Use Case (Alur)">
    <mxGraphModel dx="1900" dy="1250" grid="1" gridSize="10" guides="1" connect="1" arrows="1"
                  page="1" pageWidth="{PAGE_W}" pageHeight="{PAGE_H}" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        {chr(10).join("        " + c for c in cells)}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
'''

dst = os.path.join(os.path.dirname(__file__), '..', 'use_case_diagram.drawio')
with open(dst, 'w', encoding='utf-8') as f:
    f.write(xml)
print(f'{os.path.normpath(dst)} · {len(nodes)} bentuk · {len(links)} garis')
