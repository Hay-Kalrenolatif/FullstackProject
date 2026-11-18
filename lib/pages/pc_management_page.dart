/// Daftar unit PC.
///
/// Halaman ini baca-saja terhadap inventaris. Yang bisa dilakukan anggota lab
/// hanya satu: mengajukan kerusakan. Perubahan status — termasuk "baik"
/// kembali — terjadi di database setelah admin memverifikasi.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/tickets.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mock_ui.dart';
import '../widgets/report_sheet.dart';
import '../widgets/status_chip.dart';
import '../widgets/sync_banner.dart';
import '../widgets/state_scope.dart';

class PCManagementPage extends StatefulWidget {
  const PCManagementPage({super.key});

  @override
  State<PCManagementPage> createState() => _PCManagementPageState();
}

class _PCManagementPageState extends State<PCManagementPage> {
  final _search = TextEditingController();
  int _statusFilter = 0; // 0 semua, 1 normal, 2 perlu tindakan

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lapor(AppState s, PcAsset pc) async {
    final res = await openReportSheet(
      context,
      assetLabel: '${pc.codename} · ${pc.processor}',
      pcId: pc.id,
      currentStatus: pc.status,
    );
    if (!mounted || res == null) return;
    snack(context, res.message, isError: !res.sent);
  }

  /// Buka sheet pilih unit, lalu lempar ke sheet laporan untuk PC terpilih.
  Future<void> _laporDariHeader(AppState s) async {
    final pcs = s.visiblePcs;
    if (pcs.isEmpty) return;
    final chosen = await showModalBottomSheet<PcAsset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PcPickerSheet(pcs: pcs),
    );
    if (chosen == null || !mounted) return;
    await _lapor(s, chosen);
  }

  Future<void> _batalkan(AppState s, Report r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: tx('Batalkan pengajuan?', 16, w: FontWeight.w700),
        content: tx(
          'Status unit kembali ke ${r.prevAssetStatus.label}. Hanya bisa selama '
          'admin belum memprosesnya.',
          12.5,
          c: Colors.white70,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: tx('Batal', 13, c: secText)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: tx('Ya, batalkan', 13, c: org, w: FontWeight.w700),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await s.cancelMyReport(r.id);
      if (mounted) snack(context, 'Pengajuan dibatalkan dan status unit dipulihkan.');
    } catch (e) {
      if (mounted) snack(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => stateScope(builder: (context, s) {
        final q = _search.text.trim().toLowerCase();
        var all = s.visiblePcs;
        if (_statusFilter == 1) {
          all = all.where((p) => p.status == AssetStatus.baik).toList();
        } else if (_statusFilter == 2) {
          all = all.where((p) => p.status.butuhPerhatian).toList();
        }
        final shown = q.isEmpty
            ? all
            : all
                .where((p) =>
                    p.codename.toLowerCase().contains(q) ||
                    p.processor.toLowerCase().contains(q) ||
                    p.ram.toLowerCase().contains(q) ||
                    (p.location ?? '').toLowerCase().contains(q))
                .toList();

        final groups = <String, List<PcAsset>>{};
        for (final p in shown) {
          groups.putIfAbsent(p.labId, () => []).add(p);
        }
        for (final l in groups.values) {
          l.sort((a, b) => a.codename.compareTo(b.codename));
        }
        final byLab = <String, Lab>{for (final l in s.labs) l.id: l};

        final totalPc = s.visiblePcs.length;
        final pcBaik = s.visiblePcs.where((p) => p.status == AssetStatus.baik).length;
        final pcButuh = s.visiblePcs.where((p) => p.status.butuhPerhatian).length;
        final pcPct = cl(totalPc == 0 ? 1.0 : pcBaik / totalPc);

        final pcCounts = <String, int>{};
        for (final p in s.pcs) {
          pcCounts[p.labId] = (pcCounts[p.labId] ?? 0) + 1;
        }

        final openByPc = <String, Report>{};
        for (final r in s.myReports) {
          if (r.status.terbuka && r.pcId != null) openByPc[r.pcId!] = r;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            SyncBanner(s),

            Row(
              children: [
                Expanded(child: tx('PILIH RUANG LABORATORIUM', 10.5, c: secText, w: FontWeight.w700)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: statusMint)),
                    const SizedBox(width: 6),
                    tx('${s.labsWithData.length} Lab Terhubung', 10.5, c: secText),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LabPicker(
              labs: s.labsWithData,
              selectedId: s.labFilter,
              counts: pcCounts,
              onSelect: (id) => s.setLabFilter(id),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    value: '$pcBaik',
                    unit: 'Unit',
                    label: 'PC Normal',
                    sublabel: '${(pcPct * 100).round()}% siap praktikum',
                    accent: statusMint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    value: '$pcButuh',
                    unit: 'Unit',
                    label: 'Perlu Servis',
                    sublabel: pcButuh > 0 ? 'Tiket aktif' : 'Tidak ada',
                    accent: org,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx('Unit Komputer', 18, w: FontWeight.w700),
                      const SizedBox(height: 2),
                      tx(
                        byLab[s.labFilter] == null
                            ? 'Semua laboratorium'
                            : (byLab[s.labFilter]!.code.isEmpty
                                ? byLab[s.labFilter]!.name
                                : '${byLab[s.labFilter]!.code} · ${byLab[s.labFilter]!.name}'),
                        11.5,
                        c: secText,
                      ),
                    ],
                  ),
                ),
                if (s.online)
                  FilledButton.icon(
                    onPressed: () => _laporDariHeader(s),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Ajukan Kerusakan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    style: FilledButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ChipCount(
                    label: 'Semua', count: totalPc, active: _statusFilter == 0,
                    onTap: () => setState(() => _statusFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'Normal', count: pcBaik, active: _statusFilter == 1,
                    onTap: () => setState(() => _statusFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'Perlu Tindakan', count: pcButuh, active: _statusFilter == 2,
                    onTap: () => setState(() => _statusFilter = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: dec(
                'Cari kode, prosesor, RAM, atau posisi',
                prefix: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),

            if (shown.isEmpty)
              EmptyState(
                icon: Icons.desktop_windows_rounded,
                title: 'Tidak Ada PC Ditemukan',
                body: all.isEmpty
                    ? 'Belum ada unit komputer yang terdata di laboratorium ini.'
                    : 'Tidak ada unit yang sesuai dengan filter yang Anda pilih.',
              )
            else
              for (final entry in groups.entries) ...[
                _LabGroupTitle(lab: byLab[entry.key], count: entry.value.length),
                for (final pc in entry.value)
                  _PcCard(
                    pc: pc,
                    report: openByPc[pc.id],
                    online: s.online,
                    onReport: () => _lapor(s, pc),
                    onCancel: (r) => _batalkan(s, r),
                    onDetail: () => _detail(s, pc),
                  ),
              ],
          ],
        );
      });

  void _detail(AppState s, PcAsset pc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PcDetailSheet(pc: pc, online: s.online, onReport: () {
        Navigator.pop(context);
        _lapor(s, pc);
      }),
    );
  }
}

class _PcCard extends StatelessWidget {
  final PcAsset pc;
  final Report? report;
  final bool online;
  final VoidCallback onReport;
  final ValueChanged<Report> onCancel;
  final VoidCallback onDetail;

  const _PcCard({
    required this.pc,
    required this.report,
    required this.online,
    required this.onReport,
    required this.onCancel,
    required this.onDetail,
  });

  bool get _bermasalah => pc.status.butuhPerhatian;

  @override
  Widget build(BuildContext context) => Panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: a(_bermasalah ? org : statusMint, 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: a(_bermasalah ? org : statusMint, 0.25)),
                  ),
                  child: Icon(
                    _bermasalah ? Icons.error_outline_rounded : Icons.desktop_windows_rounded,
                    color: _bermasalah ? org : statusMint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx(pc.codename, 15, c: _bermasalah ? org : Colors.white, w: FontWeight.w700),
                      const SizedBox(height: 3),
                      tx(pc.specLine, 11, c: secText, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AssetChip(pc.status),
              ],
            ),
            if (pc.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, color: Colors.white38, size: 15),
                  const SizedBox(width: 6),
                  Expanded(child: tx('Posisi: ${pc.location}', 11, c: Colors.white60)),
                ],
              ),
            ],
            if (report != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a(org, 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a(org, 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: org, size: 15),
                        const SizedBox(width: 6),
                        tx('Deskripsi Masalah Kerusakan', 10.5, c: org, w: FontWeight.w700),
                      ],
                    ),
                    const SizedBox(height: 6),
                    tx(report!.issue, 11.5, c: Colors.white70),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: onDetail,
                    icon: const Icon(Icons.info_outline_rounded, size: 14),
                    label: const Text('Spesifikasi', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      side: BorderSide(color: a(mint, 0.18)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (report != null)
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: online ? () => onCancel(report!) : null,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Batalkan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: a(org, 0.16),
                        foregroundColor: org,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: online ? onReport : null,
                      icon: const Icon(Icons.report_gmailerrorred_rounded, size: 14),
                      label: Text(
                        _bermasalah ? 'Lapor lagi' : 'Ajukan Kerusakan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: a(yel, 0.16),
                        foregroundColor: yel,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        borderColor: _bermasalah ? a(org, 0.28) : null,
      );
}

class _PcPickerSheet extends StatelessWidget {
  final List<PcAsset> pcs;
  const _PcPickerSheet({required this.pcs});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx('Pilih Unit Komputer', 17, w: FontWeight.w700),
            const SizedBox(height: 4),
            tx('Pilih unit yang ingin dilaporkan kerusakannya.', 12, c: secText),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in pcs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: a(mint, 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.desktop_windows_rounded, color: mint, size: 18),
                      ),
                      title: tx(p.codename, 13.5, w: FontWeight.w600),
                      subtitle: tx(p.specLine, 11, c: secText),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LabGroupTitle extends StatelessWidget {
  final Lab? lab;
  final int count;

  const _LabGroupTitle({required this.lab, required this.count});

  @override
  Widget build(BuildContext context) {
    final l = lab;
    final title = l == null ? 'Lab' : (l.code.isEmpty ? l.name : '${l.code} · ${l.name}');
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          tx(title, 12.5, c: mint, w: FontWeight.w700),
          const SizedBox(width: 8),
          tx('$count unit', 11, c: secText),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _PcDetailSheet extends StatelessWidget {
  final PcAsset pc;
  final bool online;
  final VoidCallback onReport;

  const _PcDetailSheet({
    required this.pc,
    required this.online,
    required this.onReport,
  });

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 108, child: tx(label, 11.5, c: secText)),
            Expanded(child: tx((value == null || value.trim().isEmpty) ? '—' : value, 12.5,
                w: FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: tx(pc.codename, 19, w: FontWeight.w700)),
                AssetChip(pc.status),
              ],
            ),
            const SizedBox(height: 18),
            _row('Prosesor', pc.processor),
            _row('RAM', pc.ram),
            _row('Penyimpanan', pc.storage),
            _row('Grafis', pc.gpu),
            _row('Mouse', pc.mouseSpec),
            _row('Keyboard', pc.keyboardSpec),
            _row('Posisi', pc.location),
            _row('Catatan admin', pc.notes),
            const SizedBox(height: 8),
            btn(online ? 'Ajukan Kerusakan' : 'Butuh koneksi untuk melapor',
                online ? onReport : () {},
                icon: Icons.report_gmailerrorred_rounded),
          ],
        ),
      );
}
