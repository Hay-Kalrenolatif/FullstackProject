/// Beranda — ringkasan kesiapan fasilitas dari data cloud (atau cache terakhir).
///
/// Semua angka berasal dari baris nyata: `pcs`, `supporting_items`,
/// `maintenance_histories`, `reports`, `announcements`. Tidak ada nilai contoh
/// yang ditulis di kode; seed ada di 0003_seed.sql. Header (brand + pill ONLINE)
/// ditangani `AppHeader` di shell, jadi halaman ini hanya berisi konten.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/tickets.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mock_ui.dart';
import '../widgets/ring.dart';
import '../widgets/sync_banner.dart';
import '../widgets/state_scope.dart';

class SummaryPage extends StatelessWidget {
  final void Function(int) navigateTo;
  const SummaryPage({super.key, required this.navigateTo});

  @override
  Widget build(BuildContext context) => stateScope(builder: (context, s) {
        final pcs = s.visiblePcs;
        final items = s.visibleItems;

        final totalPc = pcs.length;
        final pcBaik = pcs.where((p) => p.status == AssetStatus.baik).length;
        final pcButuh = pcs.where((p) => p.status.butuhPerhatian).toList();
        final totalQty = items.fold<int>(0, (a, e) => a + e.qty);
        final qtyBaik = items
            .where((e) => e.status == AssetStatus.baik)
            .fold<int>(0, (a, e) => a + e.qty);
        final butuhQty = totalQty - qtyBaik;

        final pcPct = cl(totalPc == 0 ? 1.0 : pcBaik / totalPc);
        final supportPct = cl(totalQty == 0 ? 1.0 : qtyBaik / totalQty);
        final butuh = pcButuh.length + items.where((e) => e.status.butuhPerhatian).length;

        final pcCounts = <String, int>{};
        for (final p in s.pcs) {
          pcCounts[p.labId] = (pcCounts[p.labId] ?? 0) + 1;
        }

        final openTickets = s.myReports.where((r) => r.status.terbuka).length;
        final lab = _selectedLab(s);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            SyncBanner(s),

            tx('PILIH RUANG LABORATORIUM', 10.5, c: secText, w: FontWeight.w700),
            const SizedBox(height: 8),
            LabPicker(
              labs: s.labsWithData,
              selectedId: s.labFilter,
              counts: pcCounts,
              onSelect: (id) => s.setLabFilter(id),
            ),
            const SizedBox(height: 18),

            if (butuh > 0) ...[
              _WarningBanner(
                butuh: butuh,
                pcButuh: pcButuh,
                onTap: () => navigateTo(1),
              ),
              const SizedBox(height: 4),
            ],

            _BentoCard(
              pcPct: pcPct,
              supportPct: supportPct,
              pcBaik: pcBaik,
              totalPc: totalPc,
              jobCount: s.jobs.length,
              healthy: butuh == 0,
            ),
            const SizedBox(height: 18),

            tx('Kategori Inventaris', 14, w: FontWeight.w600),
            const SizedBox(height: 10),
            _AccessCard(
              icon: Icons.desktop_windows_rounded,
              color: mint,
              title: 'Manajemen Unit PC',
              count: '$totalPc Total',
              subtitle: 'Spesifikasi, posisi, dan status tiap unit',
              indicator: [
                (mint, '$pcBaik Normal'),
                (org, '${totalPc - pcBaik} Servis'),
              ],
              onTap: () => navigateTo(1),
            ),
            _AccessCard(
              icon: Icons.devices_other_rounded,
              color: yel,
              title: 'Inventaris Pendukung Lab',
              count: '$totalQty Alat',
              subtitle: 'Barang non-PC dan jumlahnya',
              indicator: [
                (mint, '$qtyBaik Siap'),
                (org, '$butuhQty Masalah'),
              ],
              onTap: () => navigateTo(2),
            ),
            _AccessCard(
              icon: Icons.build_circle_rounded,
              color: lil,
              title: 'Tiket Berjalan',
              count: '$openTickets Tiket',
              countColor: Colors.white38,
              subtitle: 'Pengajuan yang menunggu tindakan admin',
              onTap: () => navigateTo(3),
            ),

            if (lab != null && (lab.description?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              _LabInfoCard(lab: lab),
            ],

            const SizedBox(height: 8),
            _ActivitySection(s: s, onAll: () => navigateTo(3)),
          ],
        );
      });

  Lab? _selectedLab(AppState s) {
    if (s.labFilter != null) {
      for (final l in s.labs) {
        if (l.id == s.labFilter) return l;
      }
    }
    return s.labsWithData.isNotEmpty ? s.labsWithData.first : null;
  }
}

class _WarningBanner extends StatelessWidget {
  final int butuh;
  final List<PcAsset> pcButuh;
  final VoidCallback onTap;

  const _WarningBanner({
    required this.butuh,
    required this.pcButuh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: a(org, 0.35)),
            boxShadow: [
              BoxShadow(color: org.withAlpha(26), blurRadius: 18, spreadRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: a(org, 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: tx('Prioritas', 10, c: org, w: FontWeight.w700),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: org, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              tx('Perlu Penanganan Teknis', 15, w: FontWeight.w700, c: org),
              const SizedBox(height: 6),
              tx(
                '$butuh aset membutuhkan perbaikan/pengecekan segera'
                '${pcButuh.isNotEmpty ? ' (${pcButuh.map((p) => p.codename).take(3).join(', ')}${pcButuh.length > 3 ? ', …' : ''})' : ''}.',
                12,
                c: Colors.white70,
              ),
              const SizedBox(height: 8),
              tx('Buka Detail Tiket →', 12, c: org, w: FontWeight.w700),
            ],
          ),
        ),
      );
}

class _BentoCard extends StatelessWidget {
  final double pcPct;
  final double supportPct;
  final int pcBaik;
  final int totalPc;
  final int jobCount;
  final bool healthy;

  const _BentoCard({
    required this.pcPct,
    required this.supportPct,
    required this.pcBaik,
    required this.totalPc,
    required this.jobCount,
    required this.healthy,
  });

  @override
  Widget build(BuildContext context) => Panel(
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx('Kesiapan Lab', 18, w: FontWeight.w700),
                      const SizedBox(height: 3),
                      tx('Audit real-time perangkat & utilitas', 11.5, c: secText),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: a(healthy ? statusMint : org, 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: a(healthy ? statusMint : org, 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: healthy ? statusMint : org,
                        ),
                      ),
                      const SizedBox(width: 6),
                      tx(
                        healthy ? 'Optimal Operasional' : 'Perlu Perhatian',
                        10.5,
                        c: healthy ? statusMint : org,
                        w: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Ring(
              [pcPct, supportPct],
              [mint, yel],
              size: 180,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tx('${(pcPct * 100).round()}%', 30, w: FontWeight.w800),
                  tx('Kesiapan PC', 11, c: secText),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(value: '$pcBaik / $totalPc', label: 'PC Normal', color: mint),
                  _MiniStat(
                    value: '${(supportPct * 100).round()}%',
                    label: 'Alat Pendukung',
                    color: yel,
                  ),
                  _MiniStat(value: '$jobCount', label: 'Riwayat Servis', color: lil),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          tx(value, 15, w: FontWeight.w700),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 5),
              tx(label, 10.5, c: Colors.white60),
            ],
          ),
        ],
      );
}

class _AccessCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String count;
  final Color? countColor;
  final String subtitle;
  final List<(Color, String)>? indicator;
  final VoidCallback onTap;

  const _AccessCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.subtitle,
    required this.onTap,
    this.countColor,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) => Panel(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kolom kiri: icon + indikator vertikal di bawahnya.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a(color, 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: a(color, 0.25)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (indicator != null) ...[
                  const SizedBox(height: 8),
                  _VerticalIndicator(items: indicator!),
                ],
              ],
            ),
            const SizedBox(width: 14),
            // Kolom kanan: judul + badge, subtitle.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: tx(title, 15, w: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: a(countColor ?? color, 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: tx(count, 11, c: countColor ?? color, w: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  tx(subtitle, 11, c: secText),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
          ],
        ),
        onTap: onTap,
      );
}

/// Indikator rasio vertikal: bar tipis dua warna + legenda compact di sebelahnya.
class _VerticalIndicator extends StatelessWidget {
  final List<(Color, String)> items;
  const _VerticalIndicator({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Bar vertikal tipis (4×26 px, terbelah dua warna).
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 4,
            height: 26,
            child: Column(
              children: [
                for (final (color, _) in items) Expanded(child: ColoredBox(color: color)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Legenda vertikal compact.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (color, label) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 4),
                    tx(label, 10, c: Colors.white60),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LabInfoCard extends StatelessWidget {
  final Lab lab;
  const _LabInfoCard({required this.lab});

  @override
  Widget build(BuildContext context) => Panel(
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: a(mint, 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: a(mint, 0.22)),
              ),
              child: const Icon(Icons.meeting_room_outlined, color: mint, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx(lab.code.isEmpty ? lab.name : '${lab.code} · ${lab.name}', 14.5,
                      w: FontWeight.w700),
                  const SizedBox(height: 4),
                  tx(lab.description ?? '', 11.5, c: secText),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActivitySection extends StatelessWidget {
  final AppState s;
  final VoidCallback onAll;

  const _ActivitySection({required this.s, required this.onAll});

  @override
  Widget build(BuildContext context) {
    final jobs = s.jobs.take(3).toList();

    return Panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              tx('Aktivitas Terkini', 14, w: FontWeight.w700),
              const Spacer(),
              GestureDetector(
                onTap: onAll,
                child: tx('Semua Log', 11.5, c: mint, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            tx('Belum ada aktivitas tercatat. Riwayat muncul setelah admin '
                'memproses pengajuan.', 11.5, c: secText)
          else
            for (final j in jobs) _ActivityRow(job: j),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final MaintenanceJob job;
  const _ActivityRow({required this.job});

  IconData get _icon => switch (job.status) {
        MaintenanceStatus.selesai => Icons.check_circle_rounded,
        MaintenanceStatus.dibatalkan => Icons.cancel_rounded,
        _ => Icons.build_circle_rounded,
      };

  Color get _color => switch (job.status) {
        MaintenanceStatus.selesai => mint,
        MaintenanceStatus.dibatalkan => Colors.white38,
        _ => org,
      };

  DateTime? get _when => job.completedAt ?? job.createdAt ?? job.maintenanceDate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: a(_color, 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: tx(job.assetLabel, 13, w: FontWeight.w600)),
                      const SizedBox(width: 8),
                      tx(_when == null ? '' : rel(_when!), 11, c: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 2),
                  tx(job.actionTaken, 11.5, c: secText, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
}
