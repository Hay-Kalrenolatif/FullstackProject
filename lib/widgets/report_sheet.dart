/// Formulir pengajuan kerusakan — satu-satunya jalur tulis pengguna.
///
/// Klien tidak menulis tabel apa pun di sini: tombol kirim memanggil
/// sibal_report_issue() lewat AppState, dan function itulah yang memutuskan
/// tiket baru atau keluhan tambahan pada tiket yang sudah terbuka, sekaligus
/// memindahkan status aset ke `dalam_pengajuan`.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'status_chip.dart';

/// Hasil ringkas yang perlu diketahui pemanggil untuk menampilkan pesan.
class ReportOutcome {
  const ReportOutcome({required this.message, required this.sent});
  final String message;
  final bool sent;
}

Future<ReportOutcome?> openReportSheet(
  BuildContext context, {
  required String assetLabel,
  String? pcId,
  String? itemId,
  AssetStatus? currentStatus,
}) =>
    showModalBottomSheet<ReportOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(
        assetLabel: assetLabel,
        pcId: pcId,
        itemId: itemId,
        currentStatus: currentStatus,
      ),
    );

class _ReportSheet extends StatefulWidget {
  final String assetLabel;
  final String? pcId;
  final String? itemId;
  final AssetStatus? currentStatus;

  const _ReportSheet({
    required this.assetLabel,
    this.pcId,
    this.itemId,
    this.currentStatus,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _ctrl = TextEditingController();
  ReportSeverity _severity = ReportSeverity.sedang;
  bool _busy = false;
  String? _localError;

  static const _severities = [ReportSeverity.ringan, ReportSeverity.sedang, ReportSeverity.darurat];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _ready => _ctrl.text.trim().length >= 5;

  Future<void> _send() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final res = await AppState.instance.submitReport(
        pcId: widget.pcId,
        itemId: widget.itemId,
        issue: _ctrl.text.trim(),
        severity: _severity,
      );
      if (!mounted) return;
      Navigator.pop(context, ReportOutcome(message: res.message, sent: res.ok));
    } catch (e) {
      if (!mounted) return;
      // Gagal berarti tiket tidak dibuat dan status aset tidak bergerak —
      // RPC satu transaksi, jadi tidak ada keadaan setengah jalan.
      setState(() {
        _busy = false;
        _localError = '$e'.replaceFirst('CloudFailure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = !AppState.instance.online;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: a(mint, 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            tx('Laporkan Kerusakan', 19, w: FontWeight.w700),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: tx(widget.assetLabel, 13, c: mint, w: FontWeight.w600),
                ),
                if (widget.currentStatus != null) AssetChip(widget.currentStatus!),
              ],
            ),
            const SizedBox(height: 14),
            tx(
              'Ceritakan gejala yang Anda lihat. Admin memverifikasi sebelum status '
              'berubah — laporan Anda tidak langsung mengubah inventaris.',
              11.5,
              c: Colors.white54,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ctrl,
              maxLines: 4,
              decoration: dec('Kerusakan yang terjadi'),
              style: const TextStyle(fontSize: 14, color: Colors.white),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            tx('Tingkat urgensi', 12.5, c: Colors.white70, w: FontWeight.w600),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in _severities)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: s == _severities.last ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _severity = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _severity == s ? a(severityColor(s), 0.16) : cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _severity == s ? severityColor(s) : a(mint, 0.12),
                              width: _severity == s ? 1.5 : 1,
                            ),
                          ),
                          child: tx(
                            s.label,
                            12.5,
                            c: _severity == s ? severityColor(s) : Colors.white54,
                            w: FontWeight.w700,
                            al: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_localError != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: tx(_localError!, 12, c: redAlert, w: FontWeight.w600),
              ),
            const SizedBox(height: 20),

            if (offline)
              Panel(
                Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: org, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: tx(
                        'Butuh koneksi. Pengajuan tidak bisa diantrekan di perangkat — '
                        'status aset pindah di database, bukan di catatan lokal.',
                        11.5,
                        c: Colors.white70,
                      ),
                    ),
                  ],
                ),
                borderColor: a(org, 0.3),
                padding: const EdgeInsets.all(14),
              )
            else
              btn(
                _busy ? 'Mengirim…' : 'Kirim Pengajuan',
                _busy || !_ready ? () {} : _send,
                icon: Icons.send_rounded,
              ),
          ],
        ),
      ),
    );
  }
}
