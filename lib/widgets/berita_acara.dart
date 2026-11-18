/// Dialog "Berita Acara Servis" — rincian pekerjaan yang terekam di
/// `maintenance_histories`. Sumber nyata, bukan teks contoh: kode layanan
/// diturunkan dari id baris, lokasi dari `labs`, petugas dari
/// `performed_by_name`. Kolom yang tidak ada di skema (mis. "Garansi Lab")
/// sengaja tidak ditampilkan — lihat PETA-REVISI-UI.md §7.
library;

import 'package:flutter/material.dart';

import '../models/tickets.dart';
import '../theme.dart';

Future<void> showBeritaAcara(BuildContext context, MaintenanceJob j) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BeritaAcaraSheet(j: j),
    );

class _BeritaAcaraSheet extends StatelessWidget {
  final MaintenanceJob j;
  const _BeritaAcaraSheet({required this.j});

  String get _kode {
    final id = j.id.replaceAll('-', '');
    final seg = id.length <= 8 ? id : id.substring(0, 8);
    return '#SBL-$seg'.toUpperCase();
  }

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: a(lil, 0.14),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: a(lil, 0.3)),
                  ),
                  child: tx(_kode, 10.5, c: lil, w: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Expanded(child: tx('Berita Acara Servis', 17, w: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            tx(j.assetLabel, 13, c: Colors.white70),
            const SizedBox(height: 18),

            _grid([
              ('Lokasi', j.labName ?? '—'),
              ('Petugas', j.performedByName),
              ('Kategori', j.category.label),
              ('Tanggal', j.maintenanceDate == null ? '—' : fd(j.maintenanceDate!)),
            ]),

            const SizedBox(height: 18),
            tx('Hasil', 11, c: secText, w: FontWeight.w600),
            const SizedBox(height: 6),
            tx(j.actionTaken, 12.5, c: Colors.white70),
            if (j.notes != null && j.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: tx(j.notes!, 11.5, c: Colors.white54),
              ),
            ],
            const SizedBox(height: 20),
            btn('Tutup', () => Navigator.pop(context), tonal: true),
          ],
        ),
      );

  Widget _grid(List<(String, String)> cells) => Column(
        children: [
          for (var i = 0; i < cells.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: _cell(cells[i].$1, cells[i].$2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < cells.length
                        ? _cell(cells[i + 1].$1, cells[i + 1].$2)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _cell(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx(label, 10.5, c: secText, w: FontWeight.w600),
            const SizedBox(height: 4),
            tx(value, 12.5, w: FontWeight.w600),
          ],
        ),
      );
}
