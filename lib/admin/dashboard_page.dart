/// Tab Dashboard — keadaan lab saat ini, read-only.
///
/// Angkanya dari `v_lab_stats` (dihitung database) dan dari daftar yang sudah
/// ditarik `AdminState`, bukan dari query terpisah, supaya dashboard dan tab lain
/// tidak pernah menunjukkan dua kenyataan berbeda pada layar yang sama.
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) => AdminPage(
          title: 'Dashboard',
          subtitle: s.loadedAt == null
              ? 'Menarik data cloud…'
              : 'Ditarik ${ft(s.loadedAt!.toLocal())} WIB',
          actions: [
            AdminButton(
              'Muat ulang',
              icon: Icons.refresh_rounded,
              tone: AdminTone.primary,
              onTap: s.state == AdminLoadState.loading ? null : s.refresh,
            ),
          ],
          child: switch (s.state) {
            AdminLoadState.loading when s.pcs.isEmpty => const _Loading(),
            AdminLoadState.error => _Error(message: s.error ?? 'Gagal memuat'),
            _ => _Body(state: s),
          },
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: mint));
}

class _Error extends StatelessWidget {
  final String message;
  const _Error({required this.message});

  @override
  Widget build(BuildContext context) => AdminEmpty(
        'Cloud menolak permintaan: $message\n'
        'Kalau project Supabase sedang di-pause (7 hari tanpa aktivitas), pulihkan '
        'dari dashboard lalu muat ulang.',
        icon: Icons.wifi_off_rounded,
      );
}

class _Body extends StatelessWidget {
  final AdminState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final perluTindakan = s.queue.take(6).toList();
    final pekerjaan = s.jobs.where((j) => j.status.terbuka).take(6).toList();

    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            KpiCard(
              label: 'Antrean menunggu',
              value: '${s.menungguCount}',
              sub: '${s.diprosesCount} sedang diproses',
              color: yel,
              icon: Icons.hourglass_top_rounded,
            ),
            KpiCard(
              label: 'Pekerjaan terbuka',
              value: '${s.pekerjaanTerbukaCount}',
              sub: 'riwayat berjalan/tertunda',
              color: org,
              icon: Icons.build_circle_rounded,
            ),
            KpiCard(
              label: 'PC siap pakai',
              value: '${s.pcBaik}/${s.pcTotal}',
              sub: '${s.pcPerhatian} unit perlu perhatian',
              color: mint,
              icon: Icons.desktop_windows_rounded,
            ),
            KpiCard(
              label: 'Stok pendukung',
              value: '${s.itemQty}',
              sub: '${s.itemTotal} jenis tercatat',
              color: lil,
              icon: Icons.devices_other_rounded,
            ),
            KpiCard(
              label: 'Pengguna aktif',
              value: '${s.akunAktif}',
              sub: '${s.akunAdmin} admin',
              color: Colors.white70,
              icon: Icons.group_rounded,
            ),
          ],
        ),
        const SizedBox(height: 22),
        tx('Kesiapan per Lab', 14, w: FontWeight.w700),
        const SizedBox(height: 10),
        if (s.stats.isEmpty)
          const AdminEmpty('Belum ada Lab. Jalankan 0003_seed.sql atau tambah lewat dashboard Supabase.')
        else
          AdminTable(
            headers: const ['Lab', 'PC baik', 'PC perlu perhatian', 'Stok alat', 'Alat bermasalah', 'Antrean', 'Pekerjaan', 'Kesiapan'],
            rows: [
              for (final st in s.stats)
                [
                  AdminTable.cell(st.name, weight: FontWeight.w700),
                  AdminTable.cell('${st.pcBaik}/${st.totalPc}'),
                  AdminTable.cell('${st.pcButuhPerhatian}',
                      color: st.pcButuhPerhatian > 0 ? org : Colors.white54),
                  AdminTable.cell('${st.supportQty}'),
                  AdminTable.cell('${st.supportButuhPerhatian}',
                      color: st.supportButuhPerhatian > 0 ? org : Colors.white54),
                  AdminTable.cell('${st.pendingReports}',
                      color: st.pendingReports > 0 ? yel : Colors.white54),
                  AdminTable.cell('${st.pekerjaanBerjalan}'),
                  _RatioBar(st.pcReadyRatio),
                ],
            ],
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            tx('Butuh tindakan', 14, w: FontWeight.w700),
            const Spacer(),
            tx('${s.queue.length} tiket terbuka', 11.5, c: Colors.white54),
          ],
        ),
        const SizedBox(height: 10),
        if (perluTindakan.isEmpty)
          const AdminEmpty('Antrean kosong. Tidak ada pengajuan yang menunggu keputusan.',
              icon: Icons.verified_rounded)
        else
          Column(
            children: [
              for (final r in perluTindakan)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      SeverityChip(r.severity),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tx('${r.targetLabel} · ${r.labLabel}', 12.5, w: FontWeight.w700),
                            const SizedBox(height: 2),
                            tx(r.issue, 11.5,
                                c: Colors.white54, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ReportChip(r.status),
                      const SizedBox(width: 10),
                      tx(ago(r.createdAt), 11.5, c: Colors.white38),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 22),
        tx('Pekerjaan yang sedang berjalan', 14, w: FontWeight.w700),
        const SizedBox(height: 10),
        if (pekerjaan.isEmpty)
          const AdminEmpty('Tidak ada pekerjaan terbuka.', icon: Icons.construction_rounded)
        else
          AdminTable(
            headers: const ['Tanggal', 'Target', 'Lab', 'Kategori', 'Status', 'Petugas', 'Tindakan'],
            rows: [
              for (final j in pekerjaan)
                [
                  AdminTable.cell(j.maintenanceDate == null
                      ? '—'
                      : fd(j.maintenanceDate!)),
                  AdminTable.cell(j.assetLabel, weight: FontWeight.w700),
                  AdminTable.muted(j.labName ?? '—'),
                  AdminTable.muted(j.category.label),
                  StatusPill(
                    text: j.status.label,
                    color: jobColor(j.status),
                  ),
                  AdminTable.muted(j.performedByName),
                  AdminTable.cell(j.actionTaken, maxLines: 1),
                ],
            ],
          ),
      ],
    );
  }
}

class _RatioBar extends StatelessWidget {
  final double ratio;
  const _RatioBar(this.ratio);

  // maxWidth, bukan width tetap: kolom tabel bisa lebih sempit dari 120px
  // (8 kolom di layar sempit), dan bar harus ikut menyusut, bukan overflow.
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: a(Colors.white, 0.08),
                  valueColor: AlwaysStoppedAnimation(ratio >= 0.75 ? mint : org),
                ),
              ),
            ),
            const SizedBox(width: 8),
            tx('${(ratio * 100).round()}%', 11.5, c: Colors.white70),
          ],
        ),
      );
}
