#!/usr/bin/env python3
"""Generator ERD Chen-notation (.drawio) untuk SIBAL.

Diagram Chen punya simbol yang tidak bisa dihasilkan Mermaid (elips atribut,
belah ketupat relationship, weak entity garis ganda, ISA), jadi bentuknya
berkas draw.io. Layout diatur di sini supaya bisa diregenerasi, bukan
diatur tangan di kanvas.

    python docs/perancangan/tools/gen_chen_erd.py
"""
import os

W, H = 1600, 1400
ATTR_W, ATTR_H = 128, 46

STYLES = {
    'entity':  'shape=rect;html=1;whiteSpace=wrap;fontSize=13;fontStyle=1;fillColor=#dae8fc;strokeColor=#6c8ebf;',
    'weak':    'shape=rect;html=1;whiteSpace=wrap;double=1;fontSize=13;fontStyle=1;fillColor=#e1d5e7;strokeColor=#9673a6;',
    'rel':     'rhombus;html=1;whiteSpace=wrap;fontSize=12;fontStyle=1;fillColor=#fff2cc;strokeColor=#d6b656;',
    'ident':   'rhombus;html=1;whiteSpace=wrap;double=1;fontSize=12;fontStyle=1;fillColor=#fff2cc;strokeColor=#d6b656;',
    'attr':    'ellipse;html=1;whiteSpace=wrap;fontSize=12;fillColor=#ffffff;strokeColor=#666666;',
    'multi':   'ellipse;html=1;whiteSpace=wrap;double=1;fontSize=12;fillColor=#ffffff;strokeColor=#666666;',
    'derived': 'ellipse;html=1;whiteSpace=wrap;dashed=1;fontSize=12;fillColor=#ffffff;strokeColor=#666666;',
    'isa':     'ellipse;html=1;whiteSpace=wrap;fontSize=11;fontStyle=1;fillColor=#f5f5f5;strokeColor=#666666;',
    'card':    'text;html=1;align=center;verticalAlign=middle;fontSize=12;fontStyle=1;fontColor=#333333;',
    'note':    'text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=12;spacing=8;fillColor=#f5f5f5;strokeColor=#666666;',
}
LINE = 'html=1;endArrow=none;startArrow=none;rounded=0;strokeColor=#666666;'

nodes, links = [], []
_seq = [0]


def _id(kind):
    _seq[0] += 1
    return f'n{_seq[0]}_{kind}'


def add(kind, label, x, y, w, h):
    """x,y = sudut kiri-atas (koordinat mxGeometry)."""
    n = dict(id=_id(kind), kind=kind, label=label, x=x, y=y, w=w, h=h)
    nodes.append(n)
    return n


def box(kind, label, cx, cy, w, h):
    """Varian berbasis titik tengah — lebih mudah dipakai untuk relasi/elips."""
    return add(kind, label, cx - w / 2, cy - h / 2, w, h)


def connect(a, b, style=LINE):
    links.append(dict(src=a['id'], dst=b['id'], style=style))
    return a, b


def card(a, b, text, frac=0.24):
    """Kartinalitas di sepanjang garis, dekat salah satu ujung."""
    x = a['x'] + a['w'] / 2 + (b['x'] - a['x']) * frac
    y = a['y'] + a['h'] / 2 + (b['y'] - a['y']) * frac
    box('card', text, x, y, 28, 24)


def place(label, kind, cx, cy):
    return box(kind, label, cx, cy, ATTR_W, ATTR_H)


# ---------------------------------------------------------------------------
# Entitas
# ---------------------------------------------------------------------------
LAB = box('entity', 'LABORATORIUM', 270, 185, 200, 70)
PROFIL = box('entity', 'PROFIL', 270, 470, 200, 70)
PC = box('entity', 'PERSONIL (PC)', 800, 185, 200, 70)
BARANG = box('entity', 'BARANG PENDUKUNG', 1280, 250, 240, 70)
TIKET = box('entity', 'TIKET PENGAJUAN', 810, 640, 230, 80)
SAKSI = box('weak', 'SAKSI', 1300, 640, 200, 70)
RIWAYAT = box('entity', 'RIWAYAT SERVIS', 810, 1060, 230, 80)

# ---------------------------------------------------------------------------
# Relationship (belah ketupat) + satu ISA + satu identifying relationship
# ---------------------------------------------------------------------------
R_LOC = box('rel', 'berlokasi', 535, 185, 140, 74)
R_ITEM = box('rel', 'berada di', 1010, 250, 140, 74)
R_TICKET = box('rel', 'bertiket', 470, 400, 140, 74)
R_LAPOR = box('rel', 'dilaporkan', 500, 560, 140, 74)
R_JOB = box('rel', 'dikerjakan', 810, 850, 150, 74)
Rwit = box('ident', 'disaksikan', 1075, 640, 150, 74)
ISA = box('isa', 'ISA', 950, 420, 70, 70)

# ---------------------------------------------------------------------------
# Atribut (elips). Teks bergaris bawah = kunci utama.
# ---------------------------------------------------------------------------

# LABORATORIUM
a_lab = [place('<u>id_lab</u>', 'attr', 120, 60), place('kode', 'attr', 258, 60),
         place('nama', 'attr', 396, 60), place('deskripsi', 'attr', 150, 290)]
# PROFIL (kolom kiri)
a_pf = [place('<u>id_profil</u>', 'attr', 95, 380), place('username', 'attr', 95, 440),
        place('nama_lengkap', 'attr', 95, 500), place('peran', 'attr', 95, 560),
        place('is_aktif', 'attr', 250, 600), place('foto_profil', 'derived', 95, 620)]
# PERSONIL (PC)
a_pc = [place('<u>id_pc</u>', 'attr', 640, 60), place('kode_unit', 'attr', 778, 60),
        place('spesifikasi', 'attr', 916, 60), place('lokasi', 'attr', 640, 300),
        place('status_aset', 'attr', 778, 300), place('is_arsip', 'attr', 916, 300)]
# BARANG
a_si = [place('<u>id_barang</u>', 'attr', 1150, 60), place('nama_barang', 'attr', 1288, 60),
        place('kategori', 'attr', 1426, 60), place('qty', 'attr', 1150, 120),
        place('satuan', 'attr', 1288, 120), place('status_aset', 'attr', 1426, 120)]
# TIKET
a_rt = [place('<u>id_tiket</u>', 'attr', 500, 740), place('nama_pelapor', 'attr', 638, 740),
        place('deskripsi', 'attr', 776, 740), place('tingkat', 'attr', 914, 740),
        place('status', 'attr', 1052, 740), place('bukti_foto', 'multi', 638, 800),
        place('sasaran', 'derived', 776, 800), place('catatan_admin', 'attr', 914, 800)]
# SAKSI (weak: id-nya gabungan)
a_wt = [place('<u>id_tiket + id_profil</u>', 'attr', 1300, 745), place('waktu_saksi', 'attr', 1300, 805)]
# RIWAYAT
a_mv = [place('<u>id_rwt</u>', 'attr', 560, 950), place('tindakan', 'attr', 698, 950),
        place('tgl_servis', 'attr', 836, 950), place('qty_delta', 'attr', 974, 950),
        place('nama_petugas', 'attr', 698, 1150), place('status_kerja', 'attr', 836, 1150),
        place('usia_kerja', 'derived', 974, 1150)]

for el, target in [(a_lab[0], LAB), (a_lab[1], LAB), (a_lab[2], LAB), (a_lab[3], LAB),
                   (a_pf[0], PROFIL), (a_pf[1], PROFIL), (a_pf[2], PROFIL), (a_pf[3], PROFIL),
                   (a_pf[4], PROFIL), (a_pf[5], PROFIL),
                   (a_pc[0], PC), (a_pc[1], PC), (a_pc[2], PC), (a_pc[3], PC), (a_pc[4], PC), (a_pc[5], PC),
                   (a_si[0], BARANG), (a_si[1], BARANG), (a_si[2], BARANG), (a_si[3], BARANG),
                   (a_si[4], BARANG), (a_si[5], BARANG),
                   (a_rt[0], TIKET), (a_rt[1], TIKET), (a_rt[2], TIKET), (a_rt[3], TIKET),
                   (a_rt[4], TIKET), (a_rt[5], TIKET), (a_rt[6], TIKET), (a_rt[7], TIKET),
                   (a_wt[0], SAKSI), (a_wt[1], SAKSI),
                   (a_mv[0], RIWAYAT), (a_mv[1], RIWAYAT), (a_mv[2], RIWAYAT), (a_mv[3], RIWAYAT),
                   (a_mv[4], RIWAYAT), (a_mv[5], RIWAYAT), (a_mv[6], RIWAYAT)]:
    connect(el, target)

# ---------------------------------------------------------------------------
# Garis relationship + kartinalitas (1 : N)
# ---------------------------------------------------------------------------
for ent, rel, other in [(LAB, R_LOC, PC), (LAB, R_TICKET, TIKET), (PROFIL, R_LAPOR, TIKET),
                        (TIKET, R_JOB, RIWAYAT), (TIKET, Rwit, SAKSI)]:
    connect(ent, rel)
    connect(rel, other)
    card(ent, rel, '1')
    card(rel, other, 'N', 0.76)

connect(LAB, R_ITEM)
connect(R_ITEM, BARANG)
card(LAB, R_ITEM, '1')
card(R_ITEM, BARANG, 'N', 0.76)

# ISA: PERSONIL & BARANG adalah subtype, TIKET menunjuk superclass-nya.
connect(PC, ISA)
connect(BARANG, ISA)
connect(ISA, TIKET)
card(ISA, TIKET, 'N', 0.72)

# ---------------------------------------------------------------------------
# Legenda & pemetaan
# ---------------------------------------------------------------------------
box('note',
    '<b>Legenda simbol Chen</b><br>'
    '&nbsp;&nbsp;kotak &nbsp;= <b>entity</b> (baris tabel)<br>'
    '&nbsp;&nbsp;kotak garis ganda = <b>weak entity</b> (SAKSI: tidak punya id sendiri, '
    'kunci = gabungan tiket + profil)<br>'
    '&nbsp;&nbsp;elips = <b>atribut</b>; teks bergaris bawah = <b>kunci utama</b><br>'
    '&nbsp;&nbsp;elips garis ganda = <b>multivalued</b> (bukti_foto: text[])<br>'
    '&nbsp;&nbsp;elips putus-putus = <b>derived</b> (sasaran, usia_kerja, foto_profil: '
    'diitung database, tidak disimpan)<br>'
    '&nbsp;&nbsp;belah ketupat = <b>relationship</b>; garis ganda = '
    '<b>identifying relationship</b><br>'
    '&nbsp;&nbsp;lingkaran <b>ISA</b> = generalization (PC / Barang adalah aset)<br>'
    '&nbsp;&nbsp;1 / N = kartinalitas pada ujung garis',
    1180, 900, 380, 300)

box('note',
    '<b>Pemetaan ke skema Supabase</b><br>'
    'LABORATORIUM &rarr; public.labs &nbsp;·&nbsp; PROFIL &rarr; public.profiles<br>'
    'PERSONIL &rarr; public.pcs &nbsp;·&nbsp; BARANG &rarr; public.supporting_items<br>'
    'TIKET &rarr; public.reports &nbsp;·&nbsp; SAKSI &rarr; public.report_witness<br>'
    'RIWAYAT &rarr; public.maintenance_histories<br><br>'
    'Atribut lain (timestamp created_at/updated_at, kolom teknis) sengaja tidak '
    'digambar: Chen diagram menjelaskan konsep, daftar kolom lengkap ada di '
    'supabase/migrations/0001_init.sql.',
    60, 1180, 470, 200)

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------
def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


def cell(n):
    return (f'<mxCell id="{n["id"]}" value="{esc(n["label"])}" '
            f'style="{STYLES[n["kind"]]}" vertex="1" parent="1">'
            f'<mxGeometry x="{n["x"]:.0f}" y="{n["y"]:.0f}" width="{n["w"]:.0f}" '
            f'height="{n["h"]:.0f}" as="geometry"/></mxCell>')


def edge(i, l):
    return (f'<mxCell id="e{i}" style="{l["style"]}" edge="1" parent="1" '
            f'source="{l["src"]}" target="{l["dst"]}">'
            f'<mxGeometry relative="1" as="geometry"/></mxCell>')


body = '\n        '.join(cell(n) for n in nodes)
body += '\n        ' + '\n        '.join(edge(i, l) for i, l in enumerate(links))

xml = f'''<mxfile host="app.diagrams.net" agent="Qoder" version="24.7.7" type="device">
  <diagram id="sibal-chen" name="SIBAL ERD Chen">
    <mxGraphModel dx="1600" dy="1200" grid="1" gridSize="10" guides="1" connect="1" arrows="1" page="1"
                  pageWidth="{W}" pageHeight="{H}" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        {body}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
'''

out = os.path.join(os.path.dirname(__file__), '..', 'erd_uml.drawio')
with open(out, 'w', encoding='utf-8') as f:
    f.write(xml)
print(f'{os.path.normpath(out)} · {len(nodes)} bentuk · {len(links)} garis')
