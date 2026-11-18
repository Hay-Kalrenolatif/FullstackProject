/// Pengajuan saya + log servis (digabung, 5 tab).
///
/// Layar ini melebur `repair_log_page.dart` yang lama: tiket milik pengguna di
/// atas, lalu buku besar `maintenance_histories` di bawah sebagai "Log Servis".
/// Satu-satunya tindakan pengguna di sini: membatalkan tiket yang masih
/// menunggu, dan membuka "Berita Acara" pekerjaan yang sudah direkam admin.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/tickets.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/berita_acara.dart';
import '../widgets/common.dart';
import '../widgets/mock_ui.dart';
import '../widgets/status_chip.dart';
import '../widgets/sync_banner.dart';
import '../widgets/state_scope.dart';

class MyReportsPage extends StatefulWidget {
  /// Pindah tab (1 = Unit PC) untuk tombol "Buat" pada banner kendala.
  final void Function(int) navigateTo;
  const MyReportsPage({super.key, required this.navigateTo});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  int _filter = 0; // 0 semua layanan, 1 PC, 2 inventaris

  List<Report> _apply(List<Report> rs) => switch (_filter) {
        1 => rs.where((r) => r.targetKind == TargetKind.pc).toList(),
        2 => rs.where((r) => r.targetKind == TargetKind.supportingItem).toList(),
        _ => rs,
      };

  Future<void> _batalkan(Report r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: tx('Batalkan pengajuan?', 16, w: FontWeight.w700),
        content: tx(
          'Aset akan kembali ke status semula (${r.prevAssetStatus.label}). Hanya bisa '
          'dilakukan selama admin belum memprosesnya.',
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
      await AppState.instance.cancelMyReport(r.id);
      if (mounted) snack(context, 'Pengajuan dibatalkan dan status aset dipulihkan.');
    } catch (e) {
      if (mounted) snack(context, '$e', isError: true);
    }
  }

  MaintenanceJob? _jobFor(AppState s, String reportId) {
    for (final j in s.jobs) {
      if (j.reportId == reportId) return j;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => stateScope(builder: (context, s) {
        final shown = _apply(s.myReports);
        final diproses = s.myReports.where((r) => r.status.terbuka).length;
        final selesai = s.myReports.where((r) => r.status == ReportStatus.selesai).length;
        final batal = s.myReports
            .where((r) => r.status == ReportStatus.batal || r.status == ReportStatus.ditolak)
            .length;
        final pcCount = s.myReports.where((r) => r.targetKind == TargetKind.pc).length;
        final itemCount = s.myReports.length - pcCount;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            SyncBanner(s),

            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    value: '$diproses',
                    label: 'Diproses',
                    sublabel: 'Butuh tindakan',
                    accent: org,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    value: '$selesai',
                    label: 'Selesai',
                    sublabel: 'Tiket beres',
                    accent: mint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    value: '$batal',
                    label: 'Dibatalkan',
                    sublabel: 'Verifikasi batal',
                    accent: Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Panel(
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tx('Kendala Lab Baru?', 14.5, w: FontWeight.w700),
                        const SizedBox(height: 4),
                        tx('Laporkan unit rusak atau servis periodik', 11, c: secText),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: s.online ? () => widget.navigateTo(1) : null,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Buat',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    style: FilledButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              borderColor: a(mint, 0.22),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  ChipCount(
                    label: 'Semua Layanan', count: s.myReports.length, active: _filter == 0,
                    activeColor: mint,
                    onTap: () => setState(() => _filter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'PC Unit', count: pcCount, active: _filter == 1,
                    activeColor: mint,
                    onTap: () => setState(() => _filter = 1),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'Inventaris', count: itemCount, active: _filter == 2,
                    activeColor: mint,
                    onTap: () => setState(() => _filter = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (shown.isEmpty)
              EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Tidak Ada Pengajuan',
                body: s.myReports.isEmpty
                    ? 'Belum ada pengajuan dari akun ini. Ajukan kerusakan dari tab '
                        'Unit PC atau Inventaris.'
                    : 'Tidak ada pengajuan pada saringan ini.',
              )
            else
              for (final r in shown)
                _TicketCard(
                  r: r,
                  job: _jobFor(s, r.id),
                  online: s.online,
                  onCancel: () => _batalkan(r),
                  onAcara: (j) => showBeritaAcara(context, j),
                ),

            if (s.jobs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  tx('Log Servis', 16, w: FontWeight.w700),
                  const SizedBox(width: 8),
                  tx('${s.jobs.length} catatan', 11, c: secText),
                ],
              ),
              const SizedBox(height: 10),
              for (final j in s.jobs)
                _JobCard(job: j, onAcara: () => showBeritaAcara(context, j)),
            ],
          ],
        );
      });
}

String _kodeTiket(String id) {
  final seg = id.replaceAll('-', '');
  return '#SBL-${seg.length <= 8 ? seg : seg.substring(0, 8)}'.toUpperCase();
}

class _TicketCard extends StatelessWidget {
  final Report r;
  final MaintenanceJob? job;
  final bool online;
  final VoidCallback onCancel;
  final ValueChanged<MaintenanceJob> onAcara;

  const _TicketCard({
    required this.r,
    required this.job,
    required this.online,
    required this.onCancel,
    required this.onAcara,
  });

  @override
  Widget build(BuildContext context) => Panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: a(lil, 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: a(lil, 0.3)),
                  ),
                  child: tx(_kodeTiket(r.id), 10, c: lil, w: FontWeight.w700),
                ),
                const Spacer(),
                ReportChip(r.status),
              ],
            ),
            const SizedBox(height: 10),
            tx(r.assetName ?? r.targetLabel, 15, w: FontWeight.w700),
            const SizedBox(height: 3),
            tx(
              [
                if (r.labLabel.isNotEmpty) r.labLabel,
                if (r.createdAt != null) rel(r.createdAt!),
              ].join(' · '),
              11,
              c: secText,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _meta('Target Aset', r.targetLabel)),
                const SizedBox(width: 10),
                Expanded(child: _meta('Prioritas', r.severity.label)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _meta('Pelapor', r.reporterName)),
                const SizedBox(width: 10),
                Expanded(
                  child: _meta('Diajukan', r.createdAt == null ? '—' : fd(r.createdAt!)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            tx(r.issue, 12.5, c: Colors.white70),
            if (r.adminNotes != null && r.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a(mint, 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a(mint, 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tx('Catatan admin', 10.5, c: mint, w: FontWeight.w700),
                    const SizedBox(height: 4),
                    tx(r.adminNotes!, 12, c: Colors.white70),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (r.bisaDibatalkanBy) ...[
                  TextButton(
                    onPressed: online ? onCancel : null,
                    child: tx('Batalkan Pengajuan', 12, c: org, w: FontWeight.w700),
                  ),
                  const Spacer(),
                ],
                if (job != null)
                  TextButton(
                    onPressed: () => onAcara(job!),
                    child: tx(
                      r.status == ReportStatus.selesai ? 'Lihat Berita Acara' : 'Log Teknisi →',
                      12,
                      c: mint,
                      w: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
        borderColor: r.status == ReportStatus.menunggu ? a(yel, 0.28) : null,
      );

  Widget _meta(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx(label, 10, c: secText, w: FontWeight.w600),
            const SizedBox(height: 3),
            tx(value, 12, w: FontWeight.w600),
          ],
        ),
      );
}

class _JobCard extends StatelessWidget {
  final MaintenanceJob job;
  final VoidCallback onAcara;

  const _JobCard({required this.job, required this.onAcara});

  @override
  Widget build(BuildContext context) => Panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx(job.assetLabel, 15, w: FontWeight.w700),
                      const SizedBox(height: 3),
                      tx(
                        job.maintenanceDate == null
                            ? 'Tanggal tidak tercatat'
                            : fd(job.maintenanceDate!),
                        11,
                        c: secText,
                      ),
                    ],
                  ),
                ),
                StatusPill(text: job.status.label, color: jobColor(job.status)),
              ],
            ),
            const SizedBox(height: 12),
            tx(job.actionTaken, 12.5, c: Colors.white70),
            if (job.notes != null && job.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: tx(job.notes!, 11.5, c: secText),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                StatusPill(
                  text: job.category.label,
                  color: a(lil, 0.9),
                  icon: Icons.build_outlined,
                ),
                if (job.stokBergerak) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    text: '${job.qtyDelta > 0 ? '+' : ''}${job.qtyDelta} unit',
                    color: job.qtyDelta > 0 ? mint : redAlert,
                    icon: job.qtyDelta > 0 ? Icons.add_box_outlined : Icons.remove_outlined,
                  ),
                ],
                const Spacer(),
                const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                tx(job.performedByName, 11, c: secText),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: onAcara,
                  child: tx('Berita Acara', 12, c: mint, w: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        borderColor: job.status.terbuka ? a(org, 0.28) : null,
      );
}
