/// Tiket pengajuan (`reports`) dan pekerjaan/riwayat (`maintenance_histories`).
///
/// Kedua kelas ini hanya dibaca oleh klien; tidak ada constructor "baru" karena
/// pembuatan tiket terjadi di database lewat sibal_report_issue(). Klien tidak
/// pernah menyusun baris tiket sendiri — itu inti approval workflow-nya.
library;

import 'asset_enums.dart';
import 'row.dart';

class Report {
  Report({
    required this.id,
    required this.status,
    required this.severity,
    required this.issue,
    required this.reporterName,
    required this.labId,
    required this.targetKind,
    required this.prevAssetStatus,
    this.userId,
    this.pcId,
    this.supportingItemId,
    this.evidencePaths = const [],
    this.reviewedBy,
    this.adminNotes,
    this.decidedAt,
    this.createdAt,
    this.updatedAt,
    this.labName,
    this.labCode,
    this.assetName,
    this.witnessCount,
  });

  final String id;
  final String? userId;
  final String reporterName;
  final String labId;
  final String? pcId;
  final String? supportingItemId;
  final TargetKind targetKind;
  final AssetStatus prevAssetStatus;

  /// Keluhan, plus keluhan siswa kedua yang ditambahkan RPC ke tiket yang sama.
  final String issue;
  final ReportSeverity severity;
  final List<String> evidencePaths;
  final ReportStatus status;
  final String? reviewedBy;

  /// Catatan admin (mis. alasan penolakan). Tampil di "Pengajuan saya" supaya
  /// pengguna tahu kenapa tiketnya berhenti.
  final String? adminNotes;
  final DateTime? decidedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Hasil embed PostgREST; null saat data dibaca dari cache lama.
  final String? labName;
  final String? labCode;
  final String? assetName;
  final int? witnessCount;

  factory Report.fromRow(Row r) => Report(
        id: s(r, 'id'),
        userId: sOrNull(r, 'user_id'),
        reporterName: s(r, 'reporter_name'),
        labId: s(r, 'lab_id'),
        pcId: sOrNull(r, 'pc_id'),
        supportingItemId: sOrNull(r, 'supporting_item_id'),
        targetKind: TargetKind.parseOr(sOrNull(r, 'target_kind'),
            sOrNull(r, 'pc_id') != null ? TargetKind.pc : TargetKind.supportingItem),
        prevAssetStatus:
            AssetStatus.tryParse(sOrNull(r, 'prev_asset_status')) ?? AssetStatus.baik,
        issue: s(r, 'issue_description'),
        severity: ReportSeverity.parseOr(sOrNull(r, 'severity')),
        evidencePaths: strList(r, 'evidence_paths'),
        status: ReportStatus.tryParse(sOrNull(r, 'status')) ?? ReportStatus.menunggu,
        reviewedBy: sOrNull(r, 'reviewed_by'),
        adminNotes: sOrNull(r, 'admin_notes'),
        decidedAt: dt(r, 'decided_at'),
        createdAt: dt(r, 'created_at'),
        updatedAt: dt(r, 'updated_at'),
        labName: embText(r, 'labs', 'name'),
        labCode: embText(r, 'labs', 'code'),
        assetName: emb(r, 'pcs') != null
            ? s(emb(r, 'pcs')!, 'codename')
            : (emb(r, 'supporting_items') != null ? s(emb(r, 'supporting_items')!, 'name') : null),
        witnessCount: r['report_witness'] is List ? (r['report_witness'] as List).length : null,
      );

  static List<Report> rows(List<Row> rs) => rs.map(Report.fromRow).toList();

  Row toJson() => {
        'id': id,
        'user_id': userId,
        'reporter_name': reporterName,
        'lab_id': labId,
        'pc_id': pcId,
        'supporting_item_id': supportingItemId,
        'target_kind': targetKind.wire,
        'prev_asset_status': prevAssetStatus.wire,
        'issue_description': issue,
        'severity': severity.wire,
        'evidence_paths': evidencePaths,
        'status': status.wire,
        'reviewed_by': reviewedBy,
        'admin_notes': adminNotes,
        'decided_at': decidedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'labs': {'name': labName, 'code': labCode},
        if (pcId != null) 'pcs': {'codename': assetName},
        if (supportingItemId != null) 'supporting_items': {'name': assetName},
      };

  String get assetId => pcId ?? supportingItemId ?? '';
  String get targetLabel => assetName ?? (targetKind == TargetKind.pc ? 'PC' : 'Barang');
  String get labLabel => labCode ?? labName ?? 'Lab';

  /// Hanya pelapor yang bisa membatalkan, dan hanya selama admin belum
  /// memprosesnya — sama seperti yang dituntut sibal_cancel_report().
  bool get bisaDibatalkanBy => status == ReportStatus.menunggu;

  bool get masihDiproses => status == ReportStatus.diperiksa || status == ReportStatus.diproses;
}

class MaintenanceJob {
  MaintenanceJob({
    required this.id,
    required this.category,
    required this.status,
    required this.actionTaken,
    required this.performedByName,
    required this.labId,
    required this.targetKind,
    required this.qtyDelta,
    this.reportId,
    this.pcId,
    this.supportingItemId,
    this.notes,
    this.performedBy,
    this.maintenanceDate,
    this.completedAt,
    this.createdAt,
    this.assetName,
    this.labName,
  });

  final String id;

  /// Boleh null: inspeksi rutin admin tidak berangkat dari tiket.
  final String? reportId;
  final String labId;
  final String? pcId;
  final String? supportingItemId;
  final TargetKind targetKind;
  final MaintenanceKind category;
  final MaintenanceStatus status;
  final String actionTaken;
  final String? notes;
  final String? performedBy;
  final String performedByName;

  /// Tanggal kalender WIB, bukan timestamptz — lihat 0001 §8.
  final DateTime? maintenanceDate;
  final DateTime? completedAt;
  final DateTime? createdAt;

  /// Penanda arah untuk barang pendukung; selalu 0 untuk PC (dijaga CHECK).
  final int qtyDelta;
  final String? assetName;
  final String? labName;

  factory MaintenanceJob.fromRow(Row r) => MaintenanceJob(
        id: s(r, 'id'),
        reportId: sOrNull(r, 'report_id'),
        labId: s(r, 'lab_id'),
        pcId: sOrNull(r, 'pc_id'),
        supportingItemId: sOrNull(r, 'supporting_item_id'),
        targetKind: TargetKind.parseOr(sOrNull(r, 'target_kind'),
            sOrNull(r, 'pc_id') != null ? TargetKind.pc : TargetKind.supportingItem),
        category: MaintenanceKind.parseOr(sOrNull(r, 'category')),
        status: MaintenanceStatus.tryParse(sOrNull(r, 'status')) ?? MaintenanceStatus.berjalan,
        actionTaken: s(r, 'action_taken'),
        notes: sOrNull(r, 'notes'),
        performedBy: sOrNull(r, 'performed_by'),
        performedByName: s(r, 'performed_by_name', fallback: 'Petugas'),
        maintenanceDate: dateOnly(r, 'maintenance_date'),
        completedAt: dt(r, 'completed_at'),
        createdAt: dt(r, 'created_at'),
        qtyDelta: i(r, 'qty_delta'),
        assetName: emb(r, 'pcs') != null
            ? s(emb(r, 'pcs')!, 'codename')
            : (emb(r, 'supporting_items') != null ? s(emb(r, 'supporting_items')!, 'name') : null),
        labName: embText(r, 'labs', 'name'),
      );

  static List<MaintenanceJob> rows(List<Row> rs) => rs.map(MaintenanceJob.fromRow).toList();

  Row toJson() => {
        'id': id,
        'report_id': reportId,
        'lab_id': labId,
        'pc_id': pcId,
        'supporting_item_id': supportingItemId,
        'target_kind': targetKind.wire,
        'category': category.wire,
        'status': status.wire,
        'action_taken': actionTaken,
        'notes': notes,
        'performed_by': performedBy,
        'performed_by_name': performedByName,
        'maintenance_date': maintenanceDate == null
            ? null
            : '${maintenanceDate!.year.toString().padLeft(4, '0')}-'
                '${maintenanceDate!.month.toString().padLeft(2, '0')}-'
                '${maintenanceDate!.day.toString().padLeft(2, '0')}',
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'qty_delta': qtyDelta,
        if (pcId != null) 'pcs': {'codename': assetName},
        if (supportingItemId != null) 'supporting_items': {'name': assetName},
        'labs': {'name': labName},
      };

  String get assetLabel => assetName ?? (targetKind == TargetKind.pc ? 'PC' : 'Barang');
  bool get stokBergerak => qtyDelta != 0;
}

/// Hasil pemanggilan sibal_report_issue() — function ini mengembalikan baris,
/// bukan status sukses belaka, karena ia memutuskan sendiri antara "tiket baru"
/// dan "keluhan ditambahkan ke tiket yang sudah terbuka".
class ReportIssueResult {
  ReportIssueResult({
    this.reportId,
    this.status,
    required this.reused,
    required this.message,
  });

  final String? reportId;
  final ReportStatus? status;
  final bool reused;
  final String message;

  bool get ok => reportId != null;

  factory ReportIssueResult.fromRow(Row r) => ReportIssueResult(
        reportId: sOrNull(r, 'report_id'),
        status: ReportStatus.tryParse(sOrNull(r, 'status')),
        reused: b(r, 'reused'),
        message: s(r, 'msg', fallback: 'Pengajuan diproses.'),
      );

  /// PostgREST mengirim fungsi RETURNS TABLE sebagai array satu baris.
  static ReportIssueResult decode(dynamic raw) {
    if (raw is List) {
      if (raw.isEmpty) return ReportIssueResult(reused: false, message: 'Tidak ada hasil.');
      return ReportIssueResult.fromRow(Row.from(raw.first as Map<dynamic, dynamic>));
    }
    if (raw is Map) return ReportIssueResult.fromRow(Row.from(raw.cast<String, dynamic>()));
    return ReportIssueResult(reused: false, message: 'Balasan cloud tidak dikenali.');
  }
}
