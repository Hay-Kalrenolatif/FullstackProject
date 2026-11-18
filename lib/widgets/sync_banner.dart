/// Banner kondisi koneksi + keadaan muat.
///
/// Aturannya datang dari rencana (Bagian 2 Langkah 3): offline berarti data
/// terakhir + pengajuan dinonaktifkan, dan itu harus diberitahu, tidak boleh
/// diam-diam. Karena itu pemanggil tetap wajib mengunci tombol pengajuan —
/// banner ini hanya menjelaskannya.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

class SyncBanner extends StatelessWidget {
  final AppState s;

  /// Halaman menempel sendiri padding-nya; banner tidak menambah margin besar.
  const SyncBanner(this.s, {super.key});

  String _waktu(DateTime? d) {
    if (d == null) return 'belum pernah';
    final local = d.toLocal();
    return '${fd(local)}, ${ft(local)}';
  }

  @override
  Widget build(BuildContext context) {
    if (s.state == LoadState.loading) {
      return _Line(
        icon: Icons.sync_rounded,
        color: a(mint, 0.5),
        text: 'Mengambil data cloud…',
        borderColor: a(mint, 0.18),
      );
    }
    if (s.state == LoadState.offline || !s.online) {
      return _Line(
        icon: Icons.cloud_off_rounded,
        color: org,
        text: 'Anda sedang offline. Menampilkan data terakhir (${_waktu(s.lastSyncedAt)}). '
            'Pengajuan dinonaktifkan.',
        borderColor: a(org, 0.35),
      );
    }
    if (s.state == LoadState.error) {
      return _Line(
        icon: Icons.error_outline_rounded,
        color: redAlert,
        text: 'Cloud menolak permintaan: ${s.error ?? "tidak diketahui"}',
        borderColor: a(redAlert, 0.35),
        action: 'Coba lagi',
        onAction: s.refresh,
      );
    }
    return _Line(
      icon: Icons.cloud_done_rounded,
      color: mint,
      text: 'Sinkron terakhir ${_waktu(s.lastSyncedAt)}',
      borderColor: a(mint, 0.18),
      action: 'Segarkan',
      onAction: s.refresh,
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Color borderColor;
  final String? action;
  final Future<void> Function()? onAction;

  const _Line({
    required this.icon,
    required this.color,
    required this.text,
    required this.borderColor,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: tx(text, 11.5, c: Colors.white70)),
            if (action != null)
              TextButton(
                onPressed: () => onAction?.call(),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: tx(action!, 11.5, c: color, w: FontWeight.w700),
              ),
          ],
        ),
      );
}
