/// Aset: Lab, PC, barang pendukung, dan statistik agregat per Lab.
///
/// `fromRow` membaca baris PostgREST apa adanya; `toJson` menulis subset kolom
/// yang sama. Karena keduanya memakai kunci yang identik dengan nama kolom,
/// hasil `toJson` bisa langsung masuk Box Hive sebagai cache dan dibaca kembali
/// dengan `fromRow` tanpa adapter terpisah.
library;

import 'asset_enums.dart';
import 'row.dart';

class Lab {
  Lab({required this.id, required this.code, required this.name, this.description});

  final String id;
  final String code;
  final String name;
  final String? description;

  factory Lab.fromRow(Row r) => Lab(
        id: s(r, 'id'),
        code: s(r, 'code'),
        name: s(r, 'name'),
        description: sOrNull(r, 'description'),
      );

  static List<Lab> rows(List<Row> rs) => rs.map(Lab.fromRow).toList();

  Row toJson() => {'id': id, 'code': code, 'name': name, 'description': description};

  @override
  String toString() => '$code · $name';
}

class PcAsset {
  PcAsset({
    required this.id,
    required this.labId,
    required this.codename,
    required this.processor,
    required this.ram,
    this.storage,
    this.gpu,
    this.mouseSpec,
    this.keyboardSpec,
    required this.status,
    this.location,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String labId;
  final String codename;
  final String processor;
  final String ram;
  final String? storage;
  final String? gpu;
  final String? mouseSpec;
  final String? keyboardSpec;
  final AssetStatus status;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PcAsset.fromRow(Row r) => PcAsset(
        id: s(r, 'id'),
        labId: s(r, 'lab_id'),
        codename: s(r, 'codename'),
        processor: s(r, 'processor'),
        ram: s(r, 'ram'),
        storage: sOrNull(r, 'storage'),
        gpu: sOrNull(r, 'gpu'),
        mouseSpec: sOrNull(r, 'mouse_spec'),
        keyboardSpec: sOrNull(r, 'keyboard_spec'),
        status: AssetStatus.tryParse(sOrNull(r, 'status')) ?? AssetStatus.baik,
        location: sOrNull(r, 'location'),
        notes: sOrNull(r, 'notes'),
        isActive: b(r, 'is_active', fallback: true),
        createdAt: dt(r, 'created_at'),
        updatedAt: dt(r, 'updated_at'),
      );

  static List<PcAsset> rows(List<Row> rs) => rs.map(PcAsset.fromRow).toList();

  Row toJson() => {
        'id': id,
        'lab_id': labId,
        'codename': codename,
        'processor': processor,
        'ram': ram,
        'storage': storage,
        'gpu': gpu,
        'mouse_spec': mouseSpec,
        'keyboard_spec': keyboardSpec,
        'status': status.wire,
        'location': location,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  String get specLine => [processor, ram, storage, gpu]
      .whereType<String>()
      .where((e) => e.trim().isNotEmpty)
      .join(' · ');
}

class SupportAsset {
  SupportAsset({
    required this.id,
    required this.labId,
    required this.name,
    required this.category,
    this.specifications,
    required this.qty,
    required this.unit,
    required this.status,
    this.location,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String labId;
  final String name;
  final SupportCategory category;

  /// `qty` sengaja dipertahankan dari SupportItem lama: satu baris adalah satu
  /// jenis barang dengan jumlah, bukan satu unit fisik. Tanpa qty, persentase
  /// kesiapan di Beranda jadi persentase baris.
  final int qty;
  final String unit;
  final AssetStatus status;
  final String? specifications;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupportAsset.fromRow(Row r) => SupportAsset(
        id: s(r, 'id'),
        labId: s(r, 'lab_id'),
        name: s(r, 'name'),
        category: SupportCategory.parseOr(sOrNull(r, 'category')),
        specifications: sOrNull(r, 'specifications'),
        qty: i(r, 'qty'),
        unit: s(r, 'unit', fallback: 'unit'),
        status: AssetStatus.tryParse(sOrNull(r, 'status')) ?? AssetStatus.baik,
        location: sOrNull(r, 'location'),
        notes: sOrNull(r, 'notes'),
        isActive: b(r, 'is_active', fallback: true),
        createdAt: dt(r, 'created_at'),
        updatedAt: dt(r, 'updated_at'),
      );

  static List<SupportAsset> rows(List<Row> rs) => rs.map(SupportAsset.fromRow).toList();

  Row toJson() => {
        'id': id,
        'lab_id': labId,
        'name': name,
        'category': category.wire,
        'specifications': specifications,
        'qty': qty,
        'unit': unit,
        'status': status.wire,
        'location': location,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get habis => qty == 0;
  String get qtyLabel => '$qty $unit';
}

class LabStats {
  LabStats({
    required this.labId,
    required this.code,
    required this.name,
    required this.totalPc,
    required this.pcBaik,
    required this.pcButuhPerhatian,
    required this.supportQty,
    required this.supportButuhPerhatian,
    required this.pendingReports,
    required this.pekerjaanBerjalan,
  });

  final String labId;
  final String code;
  final String name;
  final int totalPc;
  final int pcBaik;
  final int pcButuhPerhatian;
  final int supportQty;
  final int supportButuhPerhatian;
  final int pendingReports;
  final int pekerjaanBerjalan;

  factory LabStats.fromRow(Row r) => LabStats(
        labId: s(r, 'lab_id'),
        code: s(r, 'code'),
        name: s(r, 'name'),
        totalPc: i(r, 'total_pc'),
        pcBaik: i(r, 'pc_baik'),
        pcButuhPerhatian: i(r, 'pc_butuh_perhatian'),
        supportQty: i(r, 'support_qty'),
        supportButuhPerhatian: i(r, 'support_butuh_perhatian'),
        pendingReports: i(r, 'pending_reports'),
        pekerjaanBerjalan: i(r, 'pekerjaan_berjalan'),
      );

  static List<LabStats> rows(List<Row> rs) => rs.map(LabStats.fromRow).toList();

  Row toJson() => {
        'lab_id': labId,
        'code': code,
        'name': name,
        'total_pc': totalPc,
        'pc_baik': pcBaik,
        'pc_butuh_perhatian': pcButuhPerhatian,
        'support_qty': supportQty,
        'support_butuh_perhatian': supportButuhPerhatian,
        'pending_reports': pendingReports,
        'pekerjaan_berjalan': pekerjaanBerjalan,
      };

  /// Persentase PC yang siap dipakai. Pembagian nol dikawal: Lab tanpa PC
  /// adalah keadaan nyata (baru di-seed), bukan error.
  double get pcReadyRatio => totalPc == 0 ? 0 : pcBaik / totalPc;
}
