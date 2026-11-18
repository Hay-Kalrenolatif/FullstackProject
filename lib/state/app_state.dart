/// Keadaan data yang dipakai seluruh halaman mobile.
///
/// Polanya Local-First: setiap `refresh()` mencoba cloud; kalau gagal atau
/// perangkat offline, daftar diisi dari cache Hive dan UI menampilkan banner.
/// Tidak ada antrean tulis — pengajuan memang tidak bisa ditunda.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/people.dart';
import '../models/row.dart';
import '../models/tickets.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_cache.dart';
import '../services/supabase_repository.dart';

enum LoadState { idle, loading, ready, offline, error }

class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  final SupabaseRepository _repo = SupabaseRepository.instance;
  final LocalCache _cache = LocalCache.instance;
  final ConnectivityService _net = ConnectivityService.instance;

  Profile? profile;
  List<Lab> labs = const [];
  List<PcAsset> pcs = const [];
  List<SupportAsset> items = const [];
  List<MaintenanceJob> jobs = const [];
  List<Announcement> announcements = const [];
  List<Report> myReports = const [];
  List<LabStats> stats = const [];

  LoadState state = LoadState.idle;
  String? error;

  /// Filter Lab aktif (Beranda & daftar aset). Null berarti semua Lab.
  String? labFilter;

  bool get online => _net.online.value;
  bool get signedIn => AuthService.instance.isSignedIn;
  bool get isAdmin => profile?.isAdmin ?? false;
  DateTime? get lastSyncedAt => _cache.lastSyncedAt;

  Completer<void>? _inFlight;

  Future<void> start() async {
    await _cache.init();
    _net.online.addListener(_onNetChanged);
    await refresh();
  }

  void _onNetChanged() {
    notifyListeners();
    // Pulih koneksi = ada kesempatan mengambil data hidup lagi.
    if (_net.online.value && state == LoadState.offline) refresh();
  }

  /// Satu request penuh untuk semua halaman. Dipanggil saat membuka aplikasi,
  /// setelah penarikan data, dan saat koneksi pulih.
  Future<void> refresh() async {
    // Sebelum login tidak ada yang boleh diminta: RLS menolak role `anon` dengan
    // 401 pada semua tabel bisnis, dan deretan error itu bukan informasi bagi
    // pengguna — hanya kebisingan di konsol. Halaman pralogin tidak menampilkan
    // data apa pun.
    if (!signedIn) {
      state = LoadState.idle;
      notifyListeners();
      return;
    }
    if (_inFlight != null) return _inFlight!.future;
    final completer = Completer<void>();
    _inFlight = completer;

    state = LoadState.loading;
    error = null;
    notifyListeners();

    try {
      if (!online && !kIsWeb) throw const _Offline();

      final results = await Future.wait([
        _repo.labs(),
        _repo.pcs(),
        _repo.supportingItems(),
        _repo.recentJobs(),
        _repo.announcements(),
        _repo.labStats(),
        if (signedIn) _repo.myReports(),
      ]);

      labs = results[0] as List<Lab>;
      pcs = results[1] as List<PcAsset>;
      items = results[2] as List<SupportAsset>;
      jobs = results[3] as List<MaintenanceJob>;
      announcements = results[4] as List<Announcement>;
      stats = results[5] as List<LabStats>;
      myReports = results.length > 6 ? results[6] as List<Report> : const [];

      await _cache.replaceAll(CacheKind.labs, labs.map(_labRow).toList());
      await _cache.replaceAll(CacheKind.pcs, pcs.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.support, items.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.jobs, jobs.map((e) => e.toJson()).toList());
      await _cache.replaceAll(
          CacheKind.announcements, announcements.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.stats, stats.map((e) => e.toJson()).toList());
      await _cache.markSynced();

      state = LoadState.ready;
    } on _Offline {
      _loadFromCache();
      state = LoadState.offline;
    } catch (e) {
      // Jaringan hilang di tengah jalan atau cloud menolak: jangan tampil kosong
      // kalau masih ada salinan terakhir yang bisa dibaca.
      final adaCache = _cache.read(CacheKind.pcs).isNotEmpty;
      if (adaCache) {
        _loadFromCache();
        state = LoadState.offline;
      } else {
        state = LoadState.error;
        error = e is CloudFailure ? e.message : '$e';
      }
    } finally {
      _inFlight = null;
      notifyListeners();
      completer.complete();
    }
  }

  /// Hanya menulis ulang bagian yang relevan, dipakai setelah RPC mengubah
  /// satu aset — lebih murah daripada menarik seluruh Inventaris.
  Future<void> refreshAssets() async {
    try {
      pcs = await _repo.pcs();
      items = await _repo.supportingItems();
      jobs = await _repo.recentJobs();
      stats = await _repo.labStats();
      await _cache.replaceAll(CacheKind.pcs, pcs.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.support, items.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.jobs, jobs.map((e) => e.toJson()).toList());
      await _cache.replaceAll(CacheKind.stats, stats.map((e) => e.toJson()).toList());
      await _cache.markSynced();
      if (state == LoadState.offline) state = LoadState.ready;
    } catch (e) {
      state = LoadState.error;
      error = e is CloudFailure ? e.message : '$e';
    }
    notifyListeners();
  }

  Future<void> refreshMyReports() async {
    if (!signedIn) return;
    try {
      myReports = await _repo.myReports();
    } catch (_) {/* biarkan daftar lama; banner sudah menjelaskan */}
    notifyListeners();
  }

  void _loadFromCache() {
    labs = Lab.rows(_cache.read(CacheKind.labs));
    pcs = PcAsset.rows(_cache.read(CacheKind.pcs));
    items = SupportAsset.rows(_cache.read(CacheKind.support));
    jobs = MaintenanceJob.rows(_cache.read(CacheKind.jobs));
    announcements = Announcement.rows(_cache.read(CacheKind.announcements));
    stats = LabStats.rows(_cache.read(CacheKind.stats));
  }

  void setLabFilter(String? labId) {
    labFilter = labId;
    notifyListeners();
  }

  // ---- turunan untuk UI ----------------------------------------------------

  List<Lab> get labsWithData =>
      labs.where((l) => pcs.any((p) => p.labId == l.id) || items.any((i) => i.labId == l.id)).toList();

  List<PcAsset> get visiblePcs =>
      (labFilter == null ? pcs : pcs.where((p) => p.labId == labFilter)).toList()
        ..sort((a, b) => a.codename.compareTo(b.codename));

  List<SupportAsset> get visibleItems =>
      (labFilter == null ? items : items.where((i) => i.labId == labFilter)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  int get pcTotal => visiblePcs.length;
  int get pcBaikCount => visiblePcs.where((p) => p.status == AssetStatus.baik).length;
  int get pcButuhPerhatianCount =>
      visiblePcs.where((p) => p.status.butuhPerhatian).length;

  LabStats? statsFor(String? labId) {
    if (labId == null) return null;
    for (final s in stats) {
      if (s.labId == labId) return s;
    }
    return null;
  }

  /// Ring Beranda: PC siap pakai dari Lab yang sedang disaring.
  double get pcReadyRatio {
    final total = visiblePcs.length;
    if (total == 0) return 1.0;
    return clh(visiblePcs.where((p) => p.status == AssetStatus.baik).length / total);
  }

  double get supportReadyRatio {
    final totalQty = visibleItems.fold<int>(0, (s, e) => s + e.qty);
    if (totalQty == 0) return 1.0;
    final goodQty = visibleItems
        .where((e) => e.status == AssetStatus.baik)
        .fold<int>(0, (s, e) => s + e.qty);
    return clh(goodQty / totalQty);
  }

  List<Announcement> get liveAnnouncements => announcements.where((a) => a.masihTayang()).toList();

  // ---- tulis ---------------------------------------------------------------

  /// Pengajuan kerusakan. Returns pesan untuk snackbar; null berarti sukses dan
  /// [message] isian UI sudah ditangani pemanggil.
  Future<ReportIssueResult> submitReport({
    String? pcId,
    String? itemId,
    required String issue,
    required ReportSeverity severity,
  }) async {
    final res = await _repo.reportIssue(
      pcId: pcId,
      supportingItemId: itemId,
      issue: issue,
      severity: severity,
    );
    await refreshAssets();
    await refreshMyReports();
    return res;
  }

  Future<void> cancelMyReport(String reportId) async {
    await _repo.cancelReport(reportId);
    await refreshAssets();
    await refreshMyReports();
  }

  Future<void> signIn(Profile p) async {
    profile = p;
    await refresh();
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    profile = null;
    myReports = const [];
    await _cache.clearAll();
    state = LoadState.idle;
    notifyListeners();
  }

  void attachProfile(Profile p) {
    profile = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _net.online.removeListener(_onNetChanged);
    super.dispose();
  }

  static Row _labRow(Lab l) => l.toJson();
}

/// Penanda internal "tidak ada jaringan", supaya beda dari kegagalan cloud
/// yang benar-benar perlu ditampilkan sebagai error.
class _Offline implements Exception {
  const _Offline();
}

double clh(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
