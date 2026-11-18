#!/usr/bin/env python3
"""Generator class diagram UML (.drawio) untuk SIBAL — layout berlapis.

Aturan tata letak, inilah yang membuat garis tidak saling memotong:

  tier 1  UI            lib/pages/*              lib/admin/*
  tier 2  state         AppState                 AdminState
  tier 3  «frame» lib/services/* + lib/core/     |  PostgreSQL (di luar Dart)
  tier 4  «frame» lib/models/*  (domain baris atas, enum baris bawah)

  • garis antar tier yang bersebelahan berjalan tegak lurus;
  • garis panjang (state → models) keluar lewat sisi kiri/kanan kelas lalu
    turun di KORIDOR tepi halaman, jadi tidak menembus bingkai apa pun;
  • relasi antar kelas hanya digambar bila keduanya bersebelahan, sehingga
    tidak ada garis yang melintasi kotak;
  • setiap kotak dicek tidak boleh tumpang-tindih dan harus termuat di dalam
    bingkainya — generator mencetak hasilnya dan berhenti kalau melanggar.

Tanda tangan kelas diambil dari kode hari ini, bukan class_diagram.mmd v2 yang
masih memakai nama lama dan belum mengenal AdminState.

    python docs/perancangan/tools/gen_class_drawio.py
"""
import os
import sys

PAGE_W, PAGE_H = 1950, 1660
LINE_H, PAD_TOP, SECTION_GAP = 12, 26, 6

FRAME_L, FRAME_W = 110, 1560            # 110 .. 1670
CORRIDOR_L, CORRIDOR_R = 55, 1900
UI_Y, STATE_Y = 40, 250
SVC_Y, SVC_H = 470, 380                 # 470 .. 850
SVC_ROW, SVC_SUB = 525, 718
MDL_Y, MDL_H = 900, 520                 # 900 .. 1420
MDL_ROW1, MDL_ROW2 = 955, 1230

FILL = {
    'infra': ('#dae8fc', '#6c8ebf'),
    'state': ('#ffe6cc', '#d79b00'),
    'model': ('#d5e8d4', '#82b366'),
    'enum':  ('#e1d5e7', '#9673a6'),
    'srv':   ('#f5f5f5', '#666666'),
    'ui':    ('#fff2cc', '#d6b656'),
}
EDGE = {
    'assoc': 'html=1;endArrow=none;startArrow=none;strokeColor=#666666;',
    'agg':   ('html=1;endArrow=none;startArrow=diamondThin;startFill=0;startSize=16;'
              'strokeColor=#666666;'),
    'dep':   'html=1;endArrow=open;dashed=1;strokeColor=#666666;',
    'note':  ('shape=note;html=1;whiteSpace=wrap;align=left;verticalAlign=top;fontSize=11;'
              'fillColor=#fffbe6;strokeColor=#d6b656;spacing=8;'),
    'frame': ('shape=rect;html=1;whiteSpace=wrap;verticalAlign=top;align=left;fontSize=13;'
              'fontStyle=1;fillColor=none;strokeColor=#666666;dashed=1;spacing=10;'),
    'multi': 'text;html=1;align=center;verticalAlign=middle;fontSize=11;fontStyle=1;',
}

cells, content, frames, links = [], [], [], []
_seq = [0]


def _next(p):
    _seq[0] += 1
    return f'{p}{_seq[0]}'


def klass(name, layer, attrs, methods, x, y, w, stereo=None):
    cid = _next('c')
    h = PAD_TOP + LINE_H * (len(attrs) + len(methods) + 2) + SECTION_GAP
    head = f'<b>{name}</b>'
    if stereo:
        head += f'<br><font style="font-size:9px;font-style:italic">&#171;{stereo}&#187;</font>'
    label = (head + '<hr size="1"/><div style="text-align:left">'
             + ''.join(f'{a}<br>' for a in attrs)
             + '</div><hr size="1"/><div style="text-align:left">'
             + ''.join(f'{m}<br>' for m in methods) + '</div>')
    fill, stroke = FILL[layer]
    cells.append(dict(id=cid, label=label, x=x, y=y, w=w, h=h,
                      style=(f'shape=rect;html=1;whiteSpace=wrap;verticalAlign=top;'
                             f'align=center;fontSize=11;spacing=4;fillColor={fill};'
                             f'strokeColor={stroke};')))
    content.append((name, x, y, w, h))
    return cid


def frame(label, x, y, w, h, inside=None):
    fid = _next('f')
    cells.append(dict(id=fid, label=label, x=x, y=y, w=w, h=h, style=EDGE['frame']))
    frames.append((label, x, y, w, h, inside or []))
    return fid


def edge(a, b, kind='assoc', label='', exit_=None, entry=None, points=()):
    st = EDGE[kind] + (exit_ or '') + (entry or '')
    links.append(dict(src=a, dst=b, style=st, label=label, points=list(points)))


def multi(x, y, text):
    cells.append(dict(id=_next('m'), label=text, x=x, y=y, w=46, h=18, style=EDGE['multi']))


def note(label, x, y, w, h):
    cells.append(dict(id=_next('n'), label=label, x=x, y=y, w=w, h=h, style=EDGE['note']))


# ===========================================================================
# Tier 1 — UI
# ===========================================================================
pages = klass('lib/pages/*', 'ui',
              ['summary_page', 'pc_management_page', 'support_inventory_page',
               'my_reports_page', 'profile_page', 'login_page'],
              ['widgets: report_sheet · berita_acara · app_header'],
              140, UI_Y, 320, stereo='5 dock tab, mobile')
admin_pages = klass('lib/admin/*', 'ui',
                    ['dashboard_page', 'queue_page', 'assets_page', 'history_page',
                     'broadcast_page', 'users_page', 'admin_login', 'admin_shell'],
                    ['widgets/admin_ui : AdminTable · adminFormDialog · AdminForm'],
                    1180, UI_Y, 340, stereo='6 tab, web build')

# ===========================================================================
# Tier 2 — state
# ===========================================================================
app_state = klass('AppState', 'state',
                  ['+profile, labs, pcs, items, jobs', '+myReports, announcements, stats',
                   '+state : LoadState', '+labFilter : String?'],
                  ['+refresh() / refreshAssets()', '+refreshMyReports()',
                   '+submitReport(...) : ReportIssueResult', '+cancelMyReport(id)',
                   '+start / signIn / signOut', '+pcReadyRatio : double {get}'],
                  140, STATE_Y, 320, stereo='ChangeNotifier')
admin_state = klass('AdminState', 'state',
                    ['+me : Profile?', '+queue, recent : List<Report>',
                     '+pcs, items, jobs, profiles', '+announcements, stats',
                     '+state : AdminLoadState'],
                    ['+attach(p) / detach() / refresh()', '+check / approve / reject / reopen',
                     '+complete(jobId, outcome, qtyDelta)',
                     '+setAssetStatus / savePc / saveItem',
                     '+saveAnnouncement / deleteAnnouncement', '+setRole / setActive',
                     '+statusUntukPerubahan(...) {static}'],
                    1180, STATE_Y, 340, stereo='ChangeNotifier, TANPA Hive')

# ===========================================================================
# Tier 3 — bingkai layanan + PostgreSQL di luarnya
# ===========================================================================
svc_f = frame('lib/services/*   +   lib/core/', FRAME_L, SVC_Y, FRAME_W, SVC_H)
pg_f = frame('supabase\nPostgreSQL', 1690, SVC_Y, 150, SVC_H)

appenv = klass('AppEnv', 'infra', ['+url {static}', '+publishableKey {static}',
                                   "+emailDomain = '@sibal.my.id'", '+usernameShape {static}'],
               ['+emailForUsername(u)', '+normalizeUsername(s)', '+ensureConfigured()'],
               140, SVC_ROW, 240)
authsvc = klass('AuthService', 'infra', ['+session : Session?', '+userId : String?',
                                         '+isSignedIn : bool', '+onAuthStateChange'],
                ['+signIn(username, password)', '+signUp(u, nama, pw)',
                 '+requireProfile(id)', '+updateOwnProfile(...)', '+signOut()'],
                400, SVC_ROW, 270, stereo='singleton')
cache = klass('LocalCache', 'infra', ['+lastSyncedAt : DateTime?', '_boxes : Map'],
              ['+init()', '+replaceAll(kind, rows)', '+read(kind)', '+markSynced()',
               '+clearAll()'],
              690, SVC_ROW, 250, stereo='Hive CE, baca-saja')
conn = klass('ConnectivityService', 'infra', ['+online : ValueNotifier<bool>'],
             ['+start()', '+dispose()'], 960, SVC_ROW, 250, stereo='singleton')
repo = klass('SupabaseRepository', 'infra',
             ['instance {static}', '_c : SupabaseClient {get}'],
             ['labs / pcs / supportingItems', 'myReports / openReports / allReports',
              'job / recentJobs / openJobs', 'announcements / labStats / profile(s)',
              'reportIssue / cancelReport', 'checkReport / approveReport / rejectReport',
              'completeMaintenance / reopenReport', 'setAssetStatus / setUserRole / setActive',
              'updatePc / updateSupportItem', 'upsertAnnouncement / deleteAnnouncement'],
             1230, SVC_ROW, 320, stereo='satu-satunya ke cloud')
cache_kind = klass('CacheKind', 'enum', ['labs · pcs · support', 'jobs · announcements',
                                         'stats'], [],
                   720, SVC_SUB, 190, stereo='enumeration')
srv_k = klass('sibal_* function', 'srv',
              ['report_issue', 'check / approve', 'reject / reopen', 'cancel_report',
               'complete_maintenance', 'set_asset_status', 'set_user_role/active',
               'update_pc / update_item', 'upsert / delete_announcement'],
              ['app.resolve_admin()', 'app.text_field()', 'app.email_for_username()'],
              1700, SVC_ROW, 130, stereo='security definer')

# ===========================================================================
# Tier 4 — bingkai model domain + enum
# ===========================================================================
mdl_f = frame('lib/models/*', FRAME_L, MDL_Y, FRAME_W, MDL_H)

W1 = [150, 175, 175, 190, 185, 160, 175, 170]
GAP = 16
X1, _x = [], FRAME_L + 25
for w in W1:
    X1.append(_x)
    _x += w + GAP

lab = klass('Lab', 'model', ['+id, code, name', '+description?'],
            ['+rows(rs) {static}', '+toJson()'], X1[0], MDL_ROW1, W1[0])
pc = klass('PcAsset', 'model',
           ['+id, labId, codename', '+processor, ram', '+storage, gpu?',
            '+mouse/keyboard?', '+status : AssetStatus', '+location, notes?',
            '+isActive : bool'],
           ['+specLine {get}', '+fromRow(r) {static}', '+toJson()'],
           X1[1], MDL_ROW1, W1[1])
si = klass('SupportAsset', 'model',
           ['+id, labId, name', '+category', '+qty : int, unit', '+status : AssetStatus',
            '+spec? location? notes?', '+isActive : bool'],
           ['+qtyLabel {get}', '+habis {get}', '+toJson()'],
           X1[2], MDL_ROW1, W1[2])
rep = klass('Report', 'model',
            ['+id, userId?, labId', '+pcId? / itemId?', '+targetKind', '+prevAssetStatus',
             '+issue, severity', '+evidencePaths', '+status : ReportStatus',
             '+reviewedBy?, notes?', '+witnessCount?'],
            ['+assetId {get}', '+targetLabel {get}', '+bisaDibatalkanBy {get}', '+toJson()'],
            X1[3], MDL_ROW1, W1[3])
mh = klass('MaintenanceJob', 'model',
           ['+id, reportId?, labId', '+pcId? / itemId?', '+targetKind', '+category',
            '+status : MaintenanceStatus', '+actionTaken', '+performedByName',
            '+maintenanceDate', '+qtyDelta : int'],
           ['+stokBergerak {get}', '+assetLabel {get}', '+toJson()'],
           X1[4], MDL_ROW1, W1[4])
prof = klass('Profile', 'model', ['+id, username', '+fullName', '+description',
                                  '+avatarPath?', '+role : AppRole', '+isActive'],
             ['+isAdmin {get}', '+initials {get}', '+toJson()'],
             X1[5], MDL_ROW1, W1[5])
ann = klass('Announcement', 'model', ['+id, title, body', '+level', '+isPublished',
                                      '+publishedAt? expiresAt?', '+createdBy?'],
            ['+masihTayang([now])', '+toJson()'],
            X1[6], MDL_ROW1, W1[6])
stats = klass('LabStats', 'model', ['+labId, code, name', '+totalPc, pcBaik',
                                    '+pcButuhPerhatian', '+supportQty, supportBaik',
                                    '+pendingReports', '+pekerjaanBerjalan'],
              ['+pcReadyRatio {get}', '+fromRow(r) {static}'],
              X1[7], MDL_ROW1, W1[7])

W2 = [230, 190, 200]
X2 = [380, X1[3] + 4, 930]
as_e = klass('AssetStatus', 'enum', ['baik · dalamPengajuan', 'diperiksa · rusak',
                                     'habis · purnatugas'],
             ['+wire, label', '+butuhPerhatian {get}', '+bolehUntukApprove {get}'],
             X2[0], MDL_ROW2, W2[0], stereo='enumeration')
rs_e = klass('ReportStatus', 'enum', ['menunggu · diperiksa', 'diproses · selesai',
                                      'ditolak · batal'],
             ['+wire, label', '+terbuka {get}', '+bisaDibatalkanPemilik {get}'],
             X2[1], MDL_ROW2, W2[1], stereo='enumeration')
ms_e = klass('MaintenanceStatus', 'enum', ['tertunda · berjalan', 'selesai · dibatalkan'],
             ['+terbuka {get}'], X2[2], MDL_ROW2, W2[2], stereo='enumeration')

note('<b>Baris domain</b><br>'
     'PcAsset, SupportAsset, Report, MaintenanceJob dan LabStats semuanya punya '
     '<i>labId</i> yang menunjuk Lab; Report menyimpan <i>prevAssetStatus</i> '
     'bertipe AssetStatus. Sengaja tidak digambar sebagai garis supaya tidak ada '
     'garis yang melintasi kotak.', X2[2] + 230, MDL_ROW2, 250, 128)

# ===========================================================================
# Garis
# ===========================================================================
edge(pages, app_state, 'assoc', exit_='exitX=0.5;exitY=1;', entry='entryX=0.5;entryY=0;')
edge(admin_pages, admin_state, 'assoc', exit_='exitX=0.5;exitY=1;', entry='entryX=0.5;entryY=0;')

edge(app_state, svc_f, 'agg', 'memakai + memiliki cache & koneksi',
     exit_='exitX=0.5;exitY=1;', entry='entryX=0.15;entryY=0;')
edge(admin_state, svc_f, 'assoc', 'memakai repository',
     exit_='exitX=0.5;exitY=1;', entry='entryX=0.8;entryY=0;')

edge(app_state, mdl_f, 'agg', 'memiliki daftar domain',
     exit_='exitX=0;exitY=0.5;', entry='entryX=0;entryY=0.35;',
     points=[(CORRIDOR_L, STATE_Y + 110), (CORRIDOR_L, MDL_Y + MDL_H * 0.35)])
edge(admin_state, mdl_f, 'agg', 'memiliki daftar domain',
     exit_='exitX=1;exitY=0.5;', entry='entryX=1;entryY=0.62;',
     points=[(CORRIDOR_R, STATE_Y + 110), (CORRIDOR_R, MDL_Y + MDL_H * 0.62)])

edge(appenv, authsvc, 'dep', 'emailForUsername',
     exit_='exitX=1;exitY=0.5;', entry='entryX=0;entryY=0.5;')
edge(cache, cache_kind, 'dep', 'kunci box', exit_='exitX=0.5;exitY=1;', entry='entryX=0.5;entryY=0;')
edge(repo, srv_k, 'dep', 'RPC', exit_='exitX=1;exitY=0.5;', entry='entryX=0;entryY=0.5;')

edge(lab, pc, 'assoc', '', exit_='exitX=1;exitY=0.5;', entry='entryX=0;entryY=0.5;')
edge(rep, mh, 'assoc', '', exit_='exitX=1;exitY=0.5;', entry='entryX=0;entryY=0.5;')
edge(pc, as_e, 'dep', '', exit_='exitX=0.5;exitY=1;', entry='entryX=0.2;entryY=0;')
edge(si, as_e, 'dep', '', exit_='exitX=0.5;exitY=1;', entry='entryX=0.75;entryY=0;')
edge(rep, rs_e, 'dep', '', exit_='exitX=0.5;exitY=1;', entry='entryX=0.5;entryY=0;')
edge(mh, ms_e, 'dep', '', exit_='exitX=0.5;exitY=1;', entry='entryX=0.5;entryY=0;')

multi(X1[0] + W1[0] - 46, MDL_ROW1 - 34, '1')
multi(X1[1] + 2, MDL_ROW1 - 34, '0..*')
multi(X1[3] + W1[3] - 46, MDL_ROW1 - 34, '1')
multi(X1[4] + 2, MDL_ROW1 - 34, '0..1')

note('<b>Legenda simbol</b><br>'
     '• kotak 3 kompartemen = kelas UML (nama / atribut / metode)<br>'
     '• bingkai putus-putus = paket; garis yang menuju bingkai berarti "salah satu '
     'anggotanya"<br>'
     '• diamond kosong = agregasi · garis putus + panah terbuka = dependensi<br>'
     '• kotak abu-abu putus-putus = function PostgreSQL security definer, bukan Dart<br>'
     '• angka 1 / 0..* = multiplicity, ditulis mengambang di atas kotak<br>'
     '• dua koridor kosong di tepi halaman = jalur garis panjang, jadi tidak ada '
     'garis yang memotong bingkai',
     FRAME_L, MDL_Y + MDL_H + 30, 470, 200)
note('<b>Dua hukum yang wajib terlihat</b><br>'
     '1. Hanya SupabaseRepository menyentuh cloud: baca lewat PostgREST (SELECT '
     'saja), tulis lewat RPC. Tidak ada PcRepository.createPC() maupun '
     'manageUser() di klien.<br>'
     '2. AppState boleh jatuh ke cache Hive saat offline; AdminState sengaja '
     'tanpa LocalCache — panel yang menampilkan data basi akan menyetujui tiket '
     'di atas kenyataan yang salah.',
     FRAME_L + 500, MDL_Y + MDL_H + 30, 470, 200)

# ===========================================================================
# Verifikasi tata letak, lalu tulis
# ===========================================================================
geo = {n: (x, y, w, h) for n, x, y, w, h in content}

GROUPS = {
    'lib/services/*': ((FRAME_L, SVC_Y, FRAME_W, SVC_H),
                       ['AppEnv', 'AuthService', 'LocalCache', 'ConnectivityService',
                        'SupabaseRepository', 'CacheKind']),
    'supabase PostgreSQL': ((1690, SVC_Y, 150, SVC_H), ['sibal_* function']),
    'lib/models/*': ((FRAME_L, MDL_Y, FRAME_W, MDL_H),
                     ['Lab', 'PcAsset', 'SupportAsset', 'Report', 'MaintenanceJob',
                      'Profile', 'Announcement', 'LabStats', 'AssetStatus', 'ReportStatus',
                      'MaintenanceStatus']),
    'luar bingkai': (None, ['lib/pages/*', 'lib/admin/*', 'AppState', 'AdminState']),
}


def rects_overlap(a, b):
    return (a[0] < b[0] + b[2] - 1 and b[0] < a[0] + a[2] - 1
            and a[1] < b[1] + b[3] - 1 and b[1] < a[1] + a[3] - 1)


clash = [(x[0], y[0]) for i, x in enumerate(content) for y in content[i + 1:]
         if rects_overlap((x[1], x[2], x[3], x[4]), (y[1], y[2], y[3], y[4]))]

spill = []
for group, (box, members) in GROUPS.items():
    for m in members:
        if m not in geo:
            spill.append((group, m, 'nama tidak ditemukan'))
            continue
        x, y, w, h = geo[m]
        if box is None:
            if x + w > PAGE_W - 20 or y + h > PAGE_H - 20 or x < 20 or y < 20:
                spill.append((group, m, 'keluar halaman'))
        else:
            fx, fy, fw, fh = box
            if not (fx + 8 <= x and x + w <= fx + fw - 8 and fy + 30 <= y and y + h <= fy + fh - 8):
                spill.append((group, m, f'tembok bingkai ({x},{y},{w},{h}) vs {box}'))

dst = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'class_diagram.drawio'))
print(f'kotak: {len(content)} | bingkai: {len(frames)} | garis: {len(links)}')
print('tumpang-tindih :', clash if clash else 'tidak ada')
print('keluar bingkai :', spill if spill else 'tidak ada')
if clash or spill:
    raise SystemExit('tata letak melanggar aturan — perbaiki koordinat sebelum menulis berkas')


def esc(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;'))


out = []
for c in cells:
    out.append(f'<mxCell id="{c["id"]}" value="{esc(c["label"])}" style="{c["style"]}" '
               f'vertex="1" parent="1"><mxGeometry x="{c["x"]:.0f}" y="{c["y"]:.0f}" '
               f'width="{c["w"]:.0f}" height="{c["h"]:.0f}" as="geometry"/></mxCell>')
for i, l in enumerate(links):
    pts = ''.join(f'<mxPoint x="{x}" y="{y}"/>' for x, y in l['points'])
    arr = f'<Array as="points">{pts}</Array>' if pts else ''
    out.append(f'<mxCell id="e{i}" value="{esc(l["label"])}" style="{l["style"]}" edge="1" '
               f'parent="1" source="{l["src"]}" target="{l["dst"]}">'
               f'<mxGeometry relative="1" as="geometry">{arr}</mxGeometry></mxCell>')

xml = ('<mxfile host="app.diagrams.net" agent="Qoder" version="24.7.7" type="device">\n'
       '  <diagram id="sibal-class" name="SIBAL Class Diagram">\n'
       f'    <mxGraphModel dx="{PAGE_W}" dy="{PAGE_H}" grid="1" gridSize="10" guides="1" '
       f'connect="1" arrows="1" page="1" pageWidth="{PAGE_W}" pageHeight="{PAGE_H}" '
       'math="0" shadow="0">\n      <root>\n        <mxCell id="0" />\n'
       '        <mxCell id="1" parent="0" />\n        '
       + '\n        '.join(out)
       + '\n      </root>\n    </mxGraphModel>\n  </diagram>\n</mxfile>\n')

with open(dst, 'w', encoding='utf-8') as f:
    f.write(xml)
print(f'tertulis: {dst}')
