/// Keping status yang warnanyya sama di seluruh aplikasi.
///
/// Warna adalah bahasa visual prototipe: mint = siap, kuning = menunggu
/// keputusan, ungu = sedang diperiksa, oranye = perlu tindakan, merah = gagal,
/// abu-abu = selesai/diarsipkan. Satu tempat menentukan pemetaannya supaya
/// "dalam pengajuan" tidak hijau di satu tab dan kuning di tab lain.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../theme.dart';

Color assetColor(AssetStatus s) => switch (s) {
      AssetStatus.baik => mint,
      AssetStatus.dalamPengajuan => yel,
      AssetStatus.diperiksa => lil,
      AssetStatus.rusak => org,
      AssetStatus.habis => redAlert,
      AssetStatus.purnatugas => Colors.white38,
    };

Color reportColor(ReportStatus s) => switch (s) {
      ReportStatus.menunggu => yel,
      ReportStatus.diperiksa => lil,
      ReportStatus.diproses => org,
      ReportStatus.selesai => mint,
      ReportStatus.ditolak => redAlert,
      ReportStatus.batal => Colors.white38,
    };

Color severityColor(ReportSeverity s) => switch (s) {
      ReportSeverity.ringan => Colors.white54,
      ReportSeverity.sedang => yel,
      ReportSeverity.darurat => redAlert,
    };

Color jobColor(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.tertunda => yel,
      MaintenanceStatus.berjalan => org,
      MaintenanceStatus.selesai => mint,
      MaintenanceStatus.dibatalkan => Colors.white38,
    };

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final double size;

  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.size = 11,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: a(color, 0.13),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: a(color, 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: size + 1, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: tx(text, size, c: color, w: FontWeight.w700,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class AssetChip extends StatelessWidget {
  final AssetStatus status;
  const AssetChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) => StatusPill(
        text: status.label,
        color: assetColor(status),
        icon: switch (status) {
          AssetStatus.baik => Icons.verified_outlined,
          AssetStatus.dalamPengajuan => Icons.pending_outlined,
          AssetStatus.diperiksa => Icons.visibility_outlined,
          AssetStatus.rusak => Icons.report_gmailerrorred_rounded,
          AssetStatus.habis => Icons.inventory_2_outlined,
          AssetStatus.purnatugas => Icons.archive_outlined,
        },
      );
}

class ReportChip extends StatelessWidget {
  final ReportStatus status;
  const ReportChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) =>
      StatusPill(text: status.label, color: reportColor(status));
}

class SeverityChip extends StatelessWidget {
  final ReportSeverity severity;
  const SeverityChip(this.severity, {super.key});

  @override
  Widget build(BuildContext context) =>
      StatusPill(text: severity.label, color: severityColor(severity));
}
