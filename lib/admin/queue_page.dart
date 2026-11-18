/// Tab Antrean — jantung panel admin.
///
/// Tiga aksi di sini adalah satu-satunya jalan tiket berpindah status, dan
/// ketiganya satu RPC atomik: tidak ada "panggil dua kali dari klien".
///
/// Dua aturan yang paling mudah salah dan sudah dikunci di server:
///   * Approve hanya boleh menghasilkan `rusak` atau `diperiksa`.
///   * `p_qty_delta` diisi di Approve ATAU di Complete, tidak keduanya.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/tickets.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

enum _Tampilan { antrean, selesai }

class AdminQueuePage extends StatefulWidget {
  const AdminQueuePage({super.key});

  @override
  State<AdminQueuePage> createState() => _AdminQueuePageState();
}

class _AdminQueuePageState extends State<AdminQueuePage> {
  _Tampilan _tampilan = _Tampilan.antrean;
  ReportStatus? _status;
  String? _lab;

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          final sumber = _tampilan == _Tampilan.antrean ? s.queue : _tertutup(s);
          final daftar = sumber
              .where((r) => _status == null || r.status == _status)
              .where((r) => _lab == null || r.labId == _lab)
              .toList();

          return AdminPage(
            title: 'Laporan pengajuan',
            subtitle: '${s.queue.length} menunggu keputusan',
            actions: [
              AdminButton(
                _tampilan == _Tampilan.antrean ? 'Lihat yang sudah tutup' : 'Lihat antrean',
                icon: Icons.swap_horiz_rounded,
                onTap: () => setState(() {
                  _tampilan = _tampilan == _Tampilan.antrean
                      ? _Tampilan.selesai
                      : _Tampilan.antrean;
                  _status = null;
                }),
              ),
              AdminButton('Muat ulang',
                  icon: Icons.refresh_rounded,
                  tone: AdminTone.primary,
                  onTap: s.state == AdminLoadState.loading ? null : s.refresh),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filters(s),
                const SizedBox(height: 12),
                Expanded(
                  child: daftar.isEmpty
                      ? AdminEmpty(
                          _tampilan == _Tampilan.antrean
                              ? 'Tidak ada pengajuan yang menunggu. Antrean bersih.'
                              : 'Belum ada tiket yang ditutup.',
                          icon: _tampilan == _Tampilan.antrean
                              ? Icons.verified_rounded
                              : Icons.history_rounded,
                        )
                      : SingleChildScrollView(
                          child: AdminTable(
                            headers: const [
                              'Prioritas', 'Tiket', 'Lab', 'Target', 'Keluhan',
                              'Pelapor', 'Saksi', 'Durasi', 'Status', 'Aksi',
                            ],
                            rows: [for (final r in daftar) _row(context, s, r)],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );

  static List<Report> _tertutup(AdminState s) => s.recent
      .where((r) =>
          r.status == ReportStatus.selesai ||
          r.status == ReportStatus.ditolak ||
          r.status == ReportStatus.batal)
      .toList();

  Widget _filters(AdminState s) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            label: 'Antrean',
            on: _tampilan == _Tampilan.antrean,
            onTap: () => setState(() {
              _tampilan = _Tampilan.antrean;
              _status = null;
            }),
          ),
          _Chip(
            label: 'Sudah tutup',
            on: _tampilan == _Tampilan.selesai,
            onTap: () => setState(() {
              _tampilan = _Tampilan.selesai;
              _status = null;
            }),
          ),
          const SizedBox(width: 6),
          _Chip(
              label: 'Semua status',
              on: _status == null,
              onTap: () => setState(() => _status = null)),
          for (final st in _pilihanStatus(_tampilan))
            _Chip(
              label: st.label,
              color: reportColor(st),
              on: _status == st,
              onTap: () => setState(() => _status = _status == st ? null : st),
            ),
          const SizedBox(width: 6),
          _Chip(label: 'Semua Lab', on: _lab == null, onTap: () => setState(() => _lab = null)),
          for (final l in s.labs)
            _Chip(
              label: l.code,
              on: _lab == l.id,
              onTap: () => setState(() => _lab = _lab == l.id ? null : l.id),
            ),
        ],
      );

  List<Widget> _row(BuildContext context, AdminState s, Report r) {
    final terbuka = r.status.terbuka;
    return [
      SeverityChip(r.severity),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          tx(shortId(r.id).toUpperCase(), 11.5, w: FontWeight.w700, c: mint),
          tx(r.targetKind.label, 10, c: Colors.white38),
        ],
      ),
      AdminTable.cell(r.labLabel, weight: FontWeight.w700),
      AdminTable.cell(r.targetLabel),
      AdminTable.cell(r.issue, maxLines: 2),
      AdminTable.muted(r.reporterName),
      AdminTable.muted(r.witnessCount == null ? '—' : '${r.witnessCount}'),
      AdminTable.muted(ago(r.createdAt)),
      ReportChip(r.status),
      AdminActionMenu(
        onSelected: (v) => switch (v) {
          'detail' => _detail(context, r),
          'periksa' => _check(context, s, r),
          'setujui' => _approve(context, s, r),
          'tolak' => _reject(context, s, r),
          _ => _reopen(context, s, r),
        },
        items: [
          adminMenuItem('detail', 'Detail', Icons.info_outline_rounded, Colors.white70),
          if (terbuka && r.status == ReportStatus.menunggu)
            adminMenuItem('periksa', 'Periksa', Icons.search_rounded, yel),
          if (terbuka &&
              (r.status == ReportStatus.menunggu || r.status == ReportStatus.diperiksa))
            adminMenuItem('setujui', 'Setujui', Icons.check_circle_outline_rounded, mint),
          if (terbuka) adminMenuItem('tolak', 'Tolak', Icons.block_rounded, redAlert),
          if (!terbuka) adminMenuItem('buka', 'Buka lagi', Icons.replay_rounded, org),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Dialog
  // ---------------------------------------------------------------------------

  Future<void> _detail(BuildContext context, Report r) => adminDialog<void>(
        context,
        title: 'Tiket ${shortId(r.id)}',
        subtitle: '${r.targetLabel} · ${r.labLabel} · dilaporkan ${wib(r.createdAt)}',
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Kv('Status', r.status.label),
            _Kv('Prioritas', r.severity.label),
            _Kv('Pelapor', r.reporterName),
            _Kv('Status aset sebelumnya', r.prevAssetStatus.label),
            _Kv('Bukti foto', '${r.evidencePaths.length} berkas'),
            _Kv('Diputuskan', r.decidedAt == null ? '—' : wib(r.decidedAt)),
            const SizedBox(height: 10),
            tx('Keluhan', 11.5, c: Colors.white70, w: FontWeight.w700),
            const SizedBox(height: 4),
            tx(r.issue, 12.5),
            if ((r.adminNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              tx('Catatan admin', 11.5, c: Colors.white70, w: FontWeight.w700),
              const SizedBox(height: 4),
              tx(r.adminNotes!, 12.5, c: Colors.white70),
            ],
          ],
        ),
      );

  Future<void> _check(BuildContext context, AdminState s, Report r) => adminFormDialog(
        context,
        title: 'Periksa tiket ${shortId(r.id)}',
        subtitle:
            'Status menjadi diperiksa, dan satu pekerjaan tertunda dibuat dalam transaksi yang sama.',
        submitLabel: 'Tandai diperiksa',
        build: (ctx, f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormRow(
              label: 'Catatan pemeriksaan (opsional)',
              hint: 'Masuk ke admin_notes tiket dan notes riwayat.',
              field: AdminTextField(
                  controller: f.c('notes'),
                  maxLines: 3,
                  placeholder: 'Mis. gejala muncul lagi saat render'),
            ),
            _petugas(s, f),
          ],
        ),
        submit: (f) => runAdminAction(
          context,
          successMessage: 'Tiket ditandai diperiksa.',
          setBusy: f.setBusy,
          action: () => s.check(
              reportId: r.id,
              notes: f.nullable('notes'),
              performedBy: f.sel<String>('petugas')),
        ),
      );

  Future<void> _approve(BuildContext context, AdminState s, Report r) {
    final pc = r.pcId != null;
    final item = pc ? null : s.itemById(r.supportingItemId);

    return adminFormDialog(
      context,
      title: 'Setujui tiket ${shortId(r.id)}',
      subtitle: 'Satu transaksi: status tiket, status aset, dan buku stok berubah bersama.',
      submitLabel: 'Setujui dan buka pekerjaan',
      build: (ctx, f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormRow(
            label: 'Tindakan yang akan dikerjakan (wajib)',
            hint: 'Minimal 3 karakter. Inilah yang tercatat sebagai action_taken di riwayat.',
            field: AdminTextField(
                controller: f.c('action'),
                maxLines: 3,
                placeholder: 'Mis. ganti PSU 650W lalu uji beban 30 menit'),
          ),
          FormRow(
            label: 'Kategori pekerjaan',
            field: AdminDropdown<String>(
              value: f.sel<String>('kind') ?? MaintenanceKind.perbaikan.wire,
              items: [for (final k in MaintenanceKind.values) k.wire],
              labelOf: (w) => MaintenanceKind.parseOr(w).label,
              onChanged: (v) => f.pick('kind', v ?? MaintenanceKind.perbaikan.wire),
            ),
          ),
          FormRow(
            label: 'Status aset setelah approve',
            hint: 'Hanya rusak atau diperiksa. Mengembalikan aset ke "baik" dilakukan saat '
                'menyelesaikan riwayat, dan server menolak nilai lain.',
            field: AdminDropdown<String>(
              value: f.sel<String>('status') ?? 'rusak',
              items: const ['rusak', 'diperiksa'],
              labelOf: (w) => AssetStatus.tryParse(w)?.label ?? w,
              onChanged: (v) => f.pick('status', v ?? 'rusak'),
            ),
          ),
          if (!pc && item != null)
            FormRow(
              label: 'Perubahan stok (opsional, boleh negatif)',
              hint: 'Stok sekarang ${item.qtyLabel}. Kalau diisi di sini, jangan diisi lagi saat '
                  'menyelesaikan riwayat — delta yang sama akan bergerak dua kali.',
              field: AdminTextField(
                controller: f.c('qty', initial: '0'),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                placeholder: '0',
              ),
            ),
          _petugas(s, f),
        ],
      ),
      submit: (f) {
        if (f.v('action').trim().length < 3) {
          snack(context, 'Tindakan minimal 3 karakter.', isError: true);
          return Future.value(false);
        }
        return runAdminAction(
          context,
          successMessage: 'Tiket disetujui; pekerjaan terbuka.',
          setBusy: f.setBusy,
          action: () => s.approve(
            reportId: r.id,
            actionTaken: f.v('action').trim(),
            kind: MaintenanceKind.parseOr(f.sel<String>('kind')),
            assetStatus:
                AssetStatus.tryParse(f.sel<String>('status') ?? 'rusak') ?? AssetStatus.rusak,
            performedBy: f.sel<String>('petugas'),
            qtyDelta: pc ? 0 : f.intV('qty'),
          ),
        );
      },
    );
  }

  Future<void> _reject(BuildContext context, AdminState s, Report r) => adminFormDialog(
        context,
        title: 'Tolak tiket ${shortId(r.id)}',
        subtitle: 'Alasan tersimpan di admin_notes, dan status aset dipulihkan seperti semula.',
        submitLabel: 'Tolak pengajuan',
        tone: AdminTone.danger,
        build: (ctx, f) => FormRow(
          label: 'Alasan penolakan (wajib)',
          hint: 'Tampil ke pelapor di halaman "Pengajuan saya".',
          field: AdminTextField(
              controller: f.c('reason'),
              maxLines: 3,
              placeholder: 'Mis. gejala tidak terkonfirmasi setelah uji 2 jam'),
        ),
        submit: (f) {
          if (f.v('reason').trim().length < 3) {
            snack(context, 'Alasan minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: 'Tiket ditolak dan aset dipulihkan.',
            setBusy: f.setBusy,
            action: () => s.reject(reportId: r.id, reason: f.v('reason').trim()),
          );
        },
      );

  Future<void> _reopen(BuildContext context, AdminState s, Report r) => adminFormDialog(
        context,
        title: 'Buka lagi tiket ${shortId(r.id)}',
        subtitle: 'Hanya tiket selesai/ditolak/batal. Tiket kembali ke antrean dan aset masuk '
            'lagi ke status dalam pengajuan.',
        submitLabel: 'Buka kembali',
        tone: AdminTone.warn,
        build: (ctx, f) => FormRow(
          label: 'Alasan membuka kembali (wajib)',
          field: AdminTextField(
              controller: f.c('reason'),
              maxLines: 3,
              placeholder: 'Mis. kerusakan muncul lagi setelah servis'),
        ),
        submit: (f) {
          if (f.v('reason').trim().length < 3) {
            snack(context, 'Alasan minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: 'Tiket dibuka kembali.',
            setBusy: f.setBusy,
            action: () => s.reopen(reportId: r.id, reason: f.v('reason').trim()),
          );
        },
      );

  Widget _petugas(AdminState s, AdminForm f) => FormRow(
        label: 'Petugas pelaksana (opsional)',
        hint: 'Kosong berarti Anda sendiri. Nilainya dikirim sebagai p_performed_by.',
        field: AdminDropdown<String>(
          value: f.sel<String>('petugas'),
          items: [for (final p in s.petugas) p.id],
          hint: 'Saya sendiri',
          labelOf: (id) {
            for (final p in s.petugas) {
              if (p.id == id) return '${p.fullName} · ${p.role.label}';
            }
            return id;
          },
          onChanged: (v) => f.pick('petugas', v),
        ),
      );
}

// ---------------------------------------------------------------------------
// Widget bantu tab ini
// ---------------------------------------------------------------------------

List<ReportStatus> _pilihanStatus(_Tampilan t) => switch (t) {
      _Tampilan.antrean => const [
          ReportStatus.menunggu,
          ReportStatus.diperiksa,
          ReportStatus.diproses,
        ],
      _Tampilan.selesai => const [
          ReportStatus.selesai,
          ReportStatus.ditolak,
          ReportStatus.batal,
        ],
    };

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? color;

  const _Chip({required this.label, required this.on, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? yel;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c : card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? c : cardBorder),
        ),
        child: tx(label, 11.5, c: on ? bg : Colors.white70, w: FontWeight.w700),
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  final String k;
  final String v;
  const _Kv(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: tx(k, 11.5, c: Colors.white54)),
            Expanded(child: tx(v, 12.5, w: FontWeight.w600)),
          ],
        ),
      );
}
