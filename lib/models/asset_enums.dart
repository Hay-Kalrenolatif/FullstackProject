/// Domain enum yang persis sama dengan Postgres.
///
/// `wire` adalah label di database dan satu-satunya yang boleh dikirim ke RPC.
/// `label` untuk tampilan. Nama identifier Dart tidak bisa memakai tanda hubung
/// atau nilai yang sama dengan kata kunci, jadi anggotanya memakai nama camelCase
/// sementara `wire` menjaga ejaan database — termasuk `pelengkapan` yang dulu
/// salah saya tulis `perlengkapan` dan baru terlihat saat dieksekusi.
library;

T? _fromWire<T>(List<T> values, String? wire, String Function(T) of) {
  if (wire == null) return null;
  for (final v in values) {
    if (of(v) == wire) return v;
  }
  return null;
}

enum AppRole {
  user('user', 'Anggota'),
  admin('admin', 'Admin');

  const AppRole(this.wire, this.label);
  final String wire;
  final String label;
  static AppRole? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static AppRole parse(String? w) => tryParse(w) ?? user;
}

enum TargetKind {
  pc('pc', 'PC'),
  supportingItem('supporting_item', 'Barang pendukung');

  const TargetKind(this.wire, this.label);
  final String wire;
  final String label;
  static TargetKind? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static TargetKind parseOr(String? w, TargetKind fallback) => tryParse(w) ?? fallback;
}

enum AssetStatus {
  baik('baik', 'Baik'),
  dalamPengajuan('dalam_pengajuan', 'Dalam pengajuan'),
  diperiksa('diperiksa', 'Diperiksa'),
  rusak('rusak', 'Rusak'),
  habis('habis', 'Habis'),
  purnatugas('purnatugas', 'Purnatugas');

  const AssetStatus(this.wire, this.label);
  final String wire;
  final String label;
  static AssetStatus? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);

  /// Status yang masih membutuhkan tindakan — dipakai Beranda dan Dashboard.
  bool get butuhPerhatian => this == rusak || this == diperiksa || this == dalamPengajuan;

  /// Nilai yang boleh dipilih Approve. Kembali `baik` adalah pekerjaan
  /// sibal_complete_maintenance, bukan approve — dan database menolaknya.
  bool get bolehUntukApprove => this == rusak || this == diperiksa;
}

enum ReportStatus {
  menunggu('menunggu', 'Menunggu'),
  diperiksa('diperiksa', 'Diperiksa'),
  diproses('diproses', 'Diproses'),
  selesai('selesai', 'Selesai'),
  ditolak('ditolak', 'Ditolak'),
  batal('batal', 'Batal');

  const ReportStatus(this.wire, this.label);
  final String wire;
  final String label;
  static ReportStatus? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);

  bool get terbuka => this == menunggu || this == diperiksa || this == diproses;
  bool get bisaDibatalkanPemilik => this == menunggu;
}

enum ReportSeverity {
  ringan('ringan', 'Ringan', 0),
  sedang('sedang', 'Sedang', 1),
  darurat('darurat', 'Darurat', 2);

  const ReportSeverity(this.wire, this.label, this.rank);
  final String wire;
  final String label;

  /// Urut antrean: darurat paling atas. Database tidak punya peringkat untuk
  /// enum, jadi urutannya hidup di sini dan di query admin.
  final int rank;
  static ReportSeverity? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static ReportSeverity parseOr(String? w) => tryParse(w) ?? sedang;
}

enum MaintenanceStatus {
  tertunda('tertunda', 'Tertunda'),
  berjalan('berjalan', 'Berjalan'),
  selesai('selesai', 'Selesai'),
  dibatalkan('dibatalkan', 'Dibatalkan');

  const MaintenanceStatus(this.wire, this.label);
  final String wire;
  final String label;
  static MaintenanceStatus? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  bool get terbuka => this == tertunda || this == berjalan;
}

enum MaintenanceKind {
  perbaikan('perbaikan', 'Perbaikan'),
  penggantian('penggantian', 'Penggantian'),
  pembersihan('pembersihan', 'Pembersihan'),
  pelengkapan('pelengkapan', 'Pelengkapan'),
  inspeksi('inspeksi', 'Inspeksi'),
  pemindahan('pemindahan', 'Pemindahan'),
  purnatugas('purnatugas', 'Purnatugas');

  const MaintenanceKind(this.wire, this.label);
  final String wire;
  final String label;
  static MaintenanceKind? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static MaintenanceKind parseOr(String? w) => tryParse(w) ?? perbaikan;
}

enum SupportCategory {
  jaringan('jaringan', 'Jaringan'),
  tampilan('tampilan', 'Tampilan'),
  daya('daya', 'Daya'),
  periferal('periferal', 'Periferal'),
  alat('alat', 'Alat'),
  konsumsi('konsumsi', 'Konsumsi'),
  lain('lain', 'Lainnya');

  const SupportCategory(this.wire, this.label);
  final String wire;
  final String label;
  static SupportCategory? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static SupportCategory parseOr(String? w) => tryParse(w) ?? lain;
}

enum AnnouncementLevel {
  info('info', 'Info'),
  peringatan('peringatan', 'Peringatan'),
  penting('penting', 'Penting');

  const AnnouncementLevel(this.wire, this.label);
  final String wire;
  final String label;
  static AnnouncementLevel? tryParse(String? w) => _fromWire(values, w, (e) => e.wire);
  static AnnouncementLevel parseOr(String? w) => tryParse(w) ?? info;
}
