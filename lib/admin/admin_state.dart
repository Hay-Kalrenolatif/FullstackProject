/// Keadaan data panel admin.
///
/// Sengaja **terpisah** dari `AppState` sisi mobile dan sengaja **tidak** menyentuh
/// `LocalCache`: panel yang menampilkan data basi adalah panel yang menyetujui
/// tiket di atas kenyataan yang salah. Karena itu berkas ini tidak mengimpor
/// Hive sama sekali — kalau suatu hari ada yang "merapikan" dengan menyatukan
/// kedua state, aturan itu hilang tanpa jejak.
///
/// Semua tulis lewat `SupabaseRepository` (RPC). Tidak ada `insert`/`update`
/// langsung di sisi admin, dan `p_operator_email` tidak pernah dikirim:
/// `auth.uid()` yang bicara.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/people.dart';
import '../models/tickets.dart';
import '../services/supabase_repository.dart';

enum AdminLoadState { idle, loading, ready, error }

class AdminState extends ChangeNotifier {
  AdminState._();

  static final AdminState instance = AdminState._();

  final SupabaseRepository _repo = SupabaseRepository.instance;

  Profile? me;
  AdminLoadState state = AdminLoadState.idle;
  String? error;
  DateTime? loadedAt;

  List<Lab> labs = const [];

  /// Panel melihat yang diarsipkan juga; policy `pcs_read` mengizinkannya.
  List<PcAsset> pcs = const [];
  List<SupportAsset> items = const [];

  /// Tiket yang masih menunggu tindakan admin.
  List<Report> queue = const [];

  /// Pandangan luas untuk tab Riwayat/Dashboard (semua status).
  List<Report> recent = const [];

  List<MaintenanceJob> jobs = const [];
  List<Announcement> announcements = const [];
  List<Profile> profiles = const [];
  List<LabStats> stats = const [];

  bool get isAdmin => me?.isAdmin ?? false;

  /// Antrean terbuka menurut domain, dipakai chip filter.
  static const List<ReportStatus> _terbuka = [
    ReportStatus.menunggu,
    ReportStatus.diperiksa,
    ReportStatus.diproses,
  ];

  Completer<void>? _inFlight;

  Future<void> attach(Profile p) async {
    me = p;
    await refresh();
  }

  void detach() {
    me = null;
    state = AdminLoadState.idle;
    queue = const [];
    recent = const [];
    jobs = const [];
    announcements = const [];
    profiles = const [];
    stats = const [];
    notifyListeners();
  }

  Future<void> refresh() async {
    if (me == null) return;
    if (_inFlight != null) return _inFlight!.future;
    final done = Completer<void>();
    _inFlight = done;
    state = AdminLoadState.loading;
    error = null;
    notifyListeners();

    try {
      final r = await Future.wait([
        _repo.labs(),
        _repo.pcs(includeInactive: true),
        _repo.supportingItems(includeInactive: true),
        _repo.openReports(statuses: _terbuka),
        _repo.allReports(),
        _repo.recentJobs(limit: 150),
        _repo.openJobs(),
        _repo.announcements(publishedOnly: false),
        _repo.profiles(),
        _repo.labStats(),
      ]);

      labs = r[0] as List<Lab>;
      pcs = r[1] as List<PcAsset>;
      items = r[2] as List<SupportAsset>;
      queue = r[3] as List<Report>;
      recent = r[4] as List<Report>;
      jobs = _gabungPekerjaan(r[5] as List<MaintenanceJob>, r[6] as List<MaintenanceJob>);
      announcements = r[7] as List<Announcement>;
      profiles = r[8] as List<Profile>;
      stats = r[9] as List<LabStats>;

      queue.sort(_urutTiket);
      loadedAt = DateTime.now();
      state = AdminLoadState.ready;
    } on CloudFailure catch (e) {
      state = AdminLoadState.error;
      error = e.message;
    } catch (e) {
      state = AdminLoadState.error;
      error = '$e';
    } finally {
      _inFlight = null;
      notifyListeners();
      done.complete();
    }
  }

  /// Satu tiket boleh punya banyak baris riwayat sepanjang waktu, tapi hanya satu
  /// yang terbuka (`mh_one_open_job`). Daftar riwayat digabung lalu dibuang
  /// duplikatnya berdasarkan id.
  static List<MaintenanceJob> _gabungPekerjaan(
    List<MaintenanceJob> terbaru,
    List<MaintenanceJob> terbuka,
  ) {
    final byId = <String, MaintenanceJob>{};
    for (final j in terbuka) {
      byId[j.id] = j;
    }
    for (final j in terbaru) {
      byId.putIfAbsent(j.id, () => j);
    }
    final all = byId.values.toList()
      ..sort((a, b) {
        final t = (b.maintenanceDate ?? DateTime(1970))
            .compareTo(a.maintenanceDate ?? DateTime(1970));
        return t != 0 ? t : b.id.compareTo(a.id);
      });
    return all;
  }

  static int _urutTiket(Report a, Report b) {
    final s = b.severity.rank.compareTo(a.severity.rank);
    if (s != 0) return s;
    final ca = a.createdAt ?? DateTime(1970);
    final cb = b.createdAt ?? DateTime(1970);
    return ca.compareTo(cb);
  }

  // ---------------------------------------------------------------------------
  // Aksi — setiap panggilan diikuti refresh supaya tabel tidak menampilkan
  // keadaan sebelum transaksi.
  // ---------------------------------------------------------------------------

  Future<String> check({required String reportId, String? notes, String? performedBy}) async {
    final id = await _repo.checkReport(reportId: reportId, notes: notes, performedBy: performedBy);
    await refresh();
    return id;
  }

  Future<String> approve({
    required String reportId,
    required String actionTaken,
    required MaintenanceKind kind,
    required AssetStatus assetStatus,
    String? performedBy,
    int qtyDelta = 0,
  }) async {
    final id = await _repo.approveReport(
      reportId: reportId,
      actionTaken: actionTaken,
      kind: kind,
      assetStatus: assetStatus,
      performedBy: performedBy,
      qtyDelta: qtyDelta,
    );
    await refresh();
    return id;
  }

  Future<void> reject({required String reportId, required String reason}) async {
    await _repo.rejectReport(reportId: reportId, reason: reason);
    await refresh();
  }

  Future<void> complete({
    required String jobId,
    String? notes,
    required AssetStatus outcome,
    int qtyDelta = 0,
  }) async {
    await _repo.completeMaintenance(jobId: jobId, notes: notes, outcome: outcome, qtyDelta: qtyDelta);
    await refresh();
  }

  Future<void> reopen({required String reportId, required String reason}) async {
    await _repo.reopenReport(reportId: reportId, reason: reason);
    await refresh();
  }

  /// CRUD riwayat mandiri (0009) — pemeliharaan/perbaikan di luar pengajuan.
  Future<String> createMaintenance({
    String? pcId,
    String? itemId,
    required MaintenanceKind kind,
    required String actionTaken,
    String? notes,
    DateTime? date,
    bool selesai = false,
    String? performedBy,
    int qtyDelta = 0,
    String? reason,
  }) async {
    final id = await _repo.createMaintenance(
      pcId: pcId,
      supportingItemId: itemId,
      category: kind,
      actionTaken: actionTaken,
      notes: notes,
      maintenanceDate: date,
      selesai: selesai,
      performedBy: performedBy,
      qtyDelta: qtyDelta,
      reason: reason,
    );
    await refresh();
    return id;
  }

  Future<void> updateMaintenance({
    required String jobId,
    MaintenanceKind? kind,
    String? actionTaken,
    String? notes,
    DateTime? date,
  }) async {
    await _repo.updateMaintenance(
      jobId: jobId,
      category: kind,
      actionTaken: actionTaken,
      notes: notes,
      maintenanceDate: date,
    );
    await refresh();
  }

  Future<void> deleteMaintenance(String jobId) async {
    await _repo.deleteMaintenance(jobId);
    await refresh();
  }

  /// `dalam_pengajuan` sengaja tidak ditawarkan: trigger invariant menolak status
  /// itu tanpa pengajuan terbuka, dan jalur normalnya adalah laporan pengguna.
  /// `habis` hanya untuk barang (CHECK `pcs_status_check` melarangnya di PC).
  static List<AssetStatus> statusUntukPerubahan(AssetStatus sekarang, {required bool pc}) =>
      AssetStatus.values.where((s) {
        if (s == AssetStatus.dalamPengajuan) return false;
        if (pc && s == AssetStatus.habis) return false;
        return s != sekarang;
      }).toList();

  Future<void> setAssetStatus({
    String? pcId,
    String? itemId,
    required AssetStatus status,
    required String reason,
  }) async {
    await _repo.setAssetStatus(pcId: pcId, supportingItemId: itemId, status: status, reason: reason);
    await refresh();
  }

  Future<void> savePc({
    required String pcId,
    required String processor,
    required String ram,
    String? storage,
    String? gpu,
    String? mouseSpec,
    String? keyboardSpec,
    String? location,
    String? notes,
  }) async {
    await _repo.updatePc(
      pcId: pcId,
      processor: processor,
      ram: ram,
      storage: storage,
      gpu: gpu,
      mouseSpec: mouseSpec,
      keyboardSpec: keyboardSpec,
      location: location,
      notes: notes,
    );
    await refresh();
  }

  Future<void> saveItem({
    required String itemId,
    required String name,
    SupportCategory? category,
    String? specifications,
    String? unit,
    String? location,
    String? notes,
    int? qty,
    String? reason,
  }) async {
    await _repo.updateSupportItem(
      itemId: itemId,
      name: name,
      category: category,
      specifications: specifications,
      unit: unit,
      location: location,
      notes: notes,
      qty: qty,
      reason: reason,
    );
    await refresh();
  }

  Future<String> saveAnnouncement({
    String? id,
    required String title,
    required String body,
    required AnnouncementLevel level,
    required bool isPublished,
    DateTime? expiresAt,
  }) async {
    final saved = await _repo.upsertAnnouncement(
      id: id,
      title: title,
      body: body,
      level: level,
      isPublished: isPublished,
      expiresAt: expiresAt,
    );
    await refresh();
    return saved;
  }

  Future<void> deleteAnnouncement(String id) async {
    await _repo.deleteAnnouncement(id);
    await refresh();
  }

  Future<void> setRole({required String userId, required AppRole role}) async {
    await _repo.setUserRole(userId: userId, role: role);
    await refresh();
  }

  Future<void> setActive({required String userId, required bool isActive}) async {
    await _repo.setUserActive(userId: userId, isActive: isActive);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Turunan untuk UI
  // ---------------------------------------------------------------------------

  int get menungguCount => queue.where((r) => r.status == ReportStatus.menunggu).length;
  int get diperiksaCount => queue.where((r) => r.status == ReportStatus.diperiksa).length;
  int get diprosesCount => queue.where((r) => r.status == ReportStatus.diproses).length;
  int get pekerjaanTerbukaCount => jobs.where((j) => j.status.terbuka).length;

  int get pcTotal => pcs.where((p) => p.isActive).length;
  int get pcBaik => pcs.where((p) => p.isActive && p.status == AssetStatus.baik).length;
  int get pcPerhatian => pcs.where((p) => p.isActive && p.status.butuhPerhatian).length;
  int get itemTotal => items.where((i) => i.isActive).length;
  int get itemQty => items.where((i) => i.isActive).fold<int>(0, (s, i) => s + i.qty);
  int get itemPerhatian => items.where((i) => i.isActive && i.status.butuhPerhatian).length;
  int get akunAktif => profiles.where((p) => p.isActive).length;
  int get akunAdmin => profiles.where((p) => p.isAdmin).length;

  String labLabel(String labId) {
    for (final l in labs) {
      if (l.id == labId) return l.code;
    }
    return 'Lab';
  }

  PcAsset? pcById(String? id) {
    if (id == null) return null;
    for (final p in pcs) {
      if (p.id == id) return p;
    }
    return null;
  }

  SupportAsset? itemById(String? id) {
    if (id == null) return null;
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Kandidat petugas (`p_performed_by`) — siapa pun yang aktif.
  List<Profile> get petugas => profiles.where((p) => p.isActive).toList();

  MaintenanceJob? jobForReport(String reportId) {
    for (final j in jobs) {
      if (j.reportId == reportId && j.status.terbuka) return j;
    }
    return null;
  }
}
