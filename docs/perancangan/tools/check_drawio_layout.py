#!/usr/bin/env python3
"""Pemeriksa tata letak berkas .drawio: tumpang-tindih kotak & garis menembus kotak.

    python docs/perancangan/tools/check_drawio_layout.py <berkas.drawio> [<berkas2> ...]

Cara kerjanya: geometri kotak dibaca dari mxGeometry, rute tiap mxCell edge
direkonstruksi dari exitX/exitY, entryX/entryY dan Array points, lalu tiap
segmen sumbu-x/sumbu-y diuji terhadap semua kotak yang BUKAN ujung garis itu.
Bingkai (frame) tidak dihitung sebagai halangan — garis memang boleh memotong
tepi bingkai.
"""
import sys
import xml.etree.ElementTree as ET


def style_map(style):
    out = {}
    for part in (style or '').split(';'):
        if '=' in part:
            k, v = part.split('=', 1)
            out[k] = v
    return out


def load(path):
    root = ET.parse(path).getroot()
    for di in root.findall('.//diagram'):
        boxes, styles, edges = {}, {}, []
        for c in di.findall('.//mxCell'):
            g = c.find('mxGeometry')
            if g is None:
                continue
            if c.get('vertex'):
                boxes[c.get('id')] = (float(g.get('x', 0)), float(g.get('y', 0)),
                                      float(g.get('width', 0)), float(g.get('height', 0)))
                styles[c.get('id')] = c.get('style') or ''
            elif c.get('edge'):
                st = style_map(c.get('style'))
                pts = [(float(p.get('x')), float(p.get('y')))
                       for p in c.findall(".//Array[@as='points']/mxPoint")]
                sp, tp = g.find("mxPoint[@as='sourcePoint']"), g.find("mxPoint[@as='targetPoint']")
                free = None
                if sp is not None and tp is not None:
                    free = ((float(sp.get('x')), float(sp.get('y'))),
                            (float(tp.get('x')), float(tp.get('y'))))
                edges.append((c.get('id'), c.get('source'), c.get('target'), st, pts, free))
        yield di.get('name'), boxes, styles, edges


def anchor(box, st, key, default):
    x, y, w, h = box
    fx = float(st.get(key + 'X', default[0]))
    fy = float(st.get(key + 'Y', default[1]))
    return x + fx * w, y + fy * h


def endpoint_box(src, dst, st, side, boxes):
    """Sisi mana yang menghadap lawan — dipakai kalau exit/entry tidak ditulis."""
    a, b = boxes[src], boxes[dst]
    acx, acy = a[0] + a[2] / 2, a[1] + a[3] / 2
    bcx, bcy = b[0] + b[2] / 2, b[1] + b[3] / 2
    if side == 'exit':
        if abs(bcx - acx) > abs(bcy - acy):
            return ('0.5', '0') if bcy < acy else ('0.5', '1')
        return ('0', '0.5') if bcx < acx else ('1', '0.5')
    if abs(bcx - acx) > abs(bcy - acy):
        return ('0.5', '1') if bcy < acy else ('0.5', '0')
    return ('1', '0.5') if bcx < acx else ('0', '0.5')


def route(a_box, b_box, st, pts, side_default):
    ex, ey = anchor(a_box, st, 'exit', side_default[0])
    nx, ny = anchor(b_box, st, 'entry', side_default[1])
    walk = [(ex, ey)] + pts + [(nx, ny)]
    # setiap belahan dibuat orthogonal: arah awal mengikuti exit/entry
    path = [walk[0]]
    horiz = st.get('exitX') in ('0', '1') or (st.get('exitX') is None
                                              and abs(walk[1][0] - ex) > abs(walk[1][1] - ey))
    for px, py in walk[1:]:
        cx, cy = path[-1]
        if horiz:
            path += [(px, cy), (px, py)] if abs(cy - py) > 0.5 else [(px, py)]
        else:
            path += [(cx, py), (px, py)] if abs(cx - px) > 0.5 else [(px, py)]
        horiz = not horiz
    return path


def hits(r, seg):
    """Uji segmen vs persegi dengan Liang-Barsky; garis miring tidak dianggap
    memotong hanya karena diagonal."""
    x, y, w, h = r
    (x1, y1), (x2, y2) = seg
    dx, dy = x2 - x1, y2 - y1
    t0, t1 = 0.0, 1.0
    for pp, qq in ((-dx, x1 - x), (dx, x + w - x1), (-dy, y1 - y), (dy, y + h - y1)):
        if abs(pp) < 1e-9:
            if qq > 0:
                return False
        else:
            tt = -qq / pp
            if pp < 0:
                t0 = max(t0, tt)
            else:
                t1 = min(t1, tt)
    return t0 < t1 - 1e-9 and 0 < t1 and t0 < 1


def check(path):
    bad_total = 0
    def obs(i):
        return is_obstacle(styles[i], boxes[i])

    for name, boxes, styles, edges in load(path):
        solid = [i for i in boxes if obs(i)]
        overlap = []
        for i, a in enumerate(solid):
            for b in solid[i + 1:]:
                ax, ay, aw, ah = boxes[a]
                bx, by, bw, bh = boxes[b]
                if (ax < bx + bw - 2 and bx < ax + aw - 2
                        and ay < by + bh - 2 and by < ay + ah - 2):
                    overlap.append((a, b))
        cut = []
        for eid, src, dst, st, pts, free in edges:
            if free is not None:                      # garis bebas (sequence message)
                path = [free[0]] + pts + [free[1]]
                for seg in zip(path, path[1:]):
                    for bid, box in boxes.items():
                        if not obs(bid):
                            continue
                        if hits(box, seg):
                            cut.append((eid, f'memotong {bid}',
                                        tuple(round(c) for pt in seg for c in pt)))
                continue
            if src not in boxes or dst not in boxes:
                cut.append((eid, 'ujung tidak ada'))
                continue
            defaults = (endpoint_box(src, dst, st, 'exit', boxes),
                        endpoint_box(dst, src, st, 'entry', boxes))
            path_pts = route(boxes[src], boxes[dst], st, pts, defaults)
            for seg in zip(path_pts, path_pts[1:]):
                for bid, box in boxes.items():
                    if bid in (src, dst) or not is_obstacle(styles[bid]):
                        continue
                    if hits(box, seg):
                        cut.append((eid, f'memotong {bid}',
                                    tuple(round(c) for pt in seg for c in pt)))
        bad_total += len(overlap) + len(cut)
        print(f'--- {name}: {len(boxes)} bentuk, {len(edges)} garis')
        print('    tumpang-tindih        :', overlap if overlap else 'tidak ada')
        print('    garis memotong kotak :', cut if cut else 'tidak ada')
    return bad_total


def is_obstacle(style, box=None):
    """Hanya kelas/entitas nyata yang dianggap halangan.

    Bingkai (fillColor=none), catatan, label teks, dan batang aktivasi/lifeline
    yang tipis bukan halangan: garis sequence memang melewati kolom kosong.
    """
    if 'fillColor=none' in style or 'shape=note' in style or style.startswith('text;'):
        return False
    if 'shape=hexagon' in style:
        return False
    if box is not None and (box[2] < 24 or box[3] < 24):
        return False
    return 'shape=rect' in style or 'rounded=1' in style or 'ellipse' in style


if __name__ == '__main__':
    total = 0
    for p in sys.argv[1:]:
        print(f'== {p}')
        total += check(p)
    raise SystemExit(1 if total else 0)
