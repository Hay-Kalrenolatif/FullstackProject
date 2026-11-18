/// Cache lokal. Hive bukan lagi sumber kebenaran — ia hanya salinan terakhir
/// dari cloud, dipakai ketika perangkat kehilangan koneksi.
///
/// Isinya hanya **baca**. Tidak ada antrean tulis offline: pengajuan kerusakan
/// menuntut status aset berpindah di database, jadi ia tidak bisa ditunda.
/// Ketika offline, tombol pengajuan dikunci (lihat Bagian 2 Langkah 3).
library;

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/row.dart';

enum CacheKind { labs, pcs, support, jobs, announcements, stats }

class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  static const String _prefix = 'sibal_cache_';
  static const String _metaBoxName = '${_prefix}meta';
  static const String _keySyncedAt = 'synced_at';

  final Map<CacheKind, Box> _boxes = {};
  Box? _meta;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _meta = await Hive.openBox(_metaBoxName);
    for (final kind in CacheKind.values) {
      _boxes[kind] = await Hive.openBox('$_prefix${kind.name}');
    }
    _ready = true;
  }

  bool get isReady => _ready;

  /// Overwrite penuh, bukan merge. Salinan yang kedaluwarsa lebih berbahaya
  /// daripada salinan yang kurang lengkap: baris sisa dari aset yang sudah
  /// di-purnatugaskan akan tetap muncul di daftar.
  Future<void> replaceAll(CacheKind kind, List<Row> rows) async {
    final box = _boxes[kind];
    if (box == null) return;
    await box.clear();
    for (final r in rows) {
      final id = (r['id'] ?? r['lab_id'])?.toString();
      if (id != null) await box.put(id, r);
    }
  }

  List<Row> read(CacheKind kind) {
    final box = _boxes[kind];
    if (box == null) return const [];
    return box
        .values
        .whereType<Map>()
        .map((m) => Row.from(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> markSynced() async {
    await _meta?.put(_keySyncedAt, DateTime.now().toUtc().toIso8601String());
  }

  DateTime? get lastSyncedAt {
    final raw = _meta?.get(_keySyncedAt);
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  /// Dipakai saat logout: cache milik pengguna lain tidak boleh tersisa.
  Future<void> clearAll() async {
    for (final box in _boxes.values) {
      await box.clear();
    }
    await _meta?.clear();
  }
}
