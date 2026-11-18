/// Satu-satunya tempat klien menyentuh cloud. Dipakai shell mobile **dan**
/// panel admin, supaya daftar parameter RPC tidak pernah ditulis dua kali.
///
/// Dua hukum yang menjaga seluruh desain keamanan:
///   1. Baca lewat PostgREST (`from(...)`), hak authenticated hanya SELECT.
///   2. Tulis lewat RPC (`sibal_*`). Tidak ada `insert`/`update`/`delete` di
///      file ini kecuali satu: pemilik akun mengoreksi tiga kolom profilnya
///      sendiri — memang itu satu-satunya yang granted di 0002 §3.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/people.dart';
import '../models/tickets.dart';

class CloudFailure implements Exception {
  const CloudFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class SupabaseRepository {
  SupabaseRepository._();

  static final SupabaseRepository instance = SupabaseRepository._();

  SupabaseClient get _c => Supabase.instance.client;

  /// Embed: nama Lab dan nama aset ikut dalam satu request. Tanpa ini daftar
  /// tiket harus menyambungkan sendiri pc_id → codename dari cache, yang di
  /// perangkat offline bisa basi.
  ///
  /// Jebakan yang ditemukan lewat konsol browser, bukan lewat kode: `order()` di
  /// postgrest-dart **default-nya descending** (`ascending = false`), kebalikan
  /// dari SQL dan postgrest-js. Setiap `.order('code')` tanpa `ascending:`
  /// menghasilkan LAB3→LAB1 dan PC-04→PC-01. Karena itu arah ditulis eksplisit
  /// di semua daftar di file ini.
  static const String _reportSelect =
      '*, labs(code, name), pcs(codename), supporting_items(name)';

  /// Versi panel admin: jumlah saksi ikut diambil. `witness_read` (0002 §4)
  /// mengizinkan admin membaca baris saksi siapa pun, sedangkan pengguna biasa
  /// hanya melihat barisnya sendiri — karena itu embed ini TIDAK dipakai
  /// `myReports()`, yang kalau ikut dipakai akan melaporkan jumlah saksi palsu
  /// (selalu 1) di sisi mobile.
  static const String _reportSelectAdmin =
      '*, labs(code, name), pcs(codename), supporting_items(name), report_witness(user_id)';
  static const String _jobSelect = '*, pcs(codename), supporting_items(name), labs(name)';

  // ---------------------------------------------------------------------------
  // Baca
  // ---------------------------------------------------------------------------

  Future<List<Lab>> labs() async => Lab.rows(await _c.from('labs').select().order('code', ascending: true));

  /// `includeInactive` hanya untuk panel admin: policy pcs_read mengizinkan
  /// admin membaca baris non-aktif, pengguna biasa tidak akan pernah melihatnya.
  Future<List<PcAsset>> pcs({String? labId, bool includeInactive = false}) async {
    var q = _c.from('pcs').select();
    if (!includeInactive) q = q.eq('is_active', true);
    if (labId != null) q = q.eq('lab_id', labId);
    return PcAsset.rows(await q.order('lab_id', ascending: true).order('codename', ascending: true));
  }

  Future<List<SupportAsset>> supportingItems(
      {String? labId, bool includeInactive = false}) async {
    var q = _c.from('supporting_items').select();
    if (!includeInactive) q = q.eq('is_active', true);
    if (labId != null) q = q.eq('lab_id', labId);
    return SupportAsset.rows(await q.order('lab_id', ascending: true).order('name', ascending: true));
  }

  /// Pengajuan milik pengguna yang sedang login.
  Future<List<Report>> myReports() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    return Report.rows(await _c
        .from('reports')
        .select(_reportSelect)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100));
  }

  /// Antrean untuk panel admin. Urut `severity` memakai urutan deklarasi enum
  /// di Postgres, jadi descending = darurat paling atas (lihat 0001 §1).
  Future<List<Report>> openReports({
    List<ReportStatus> statuses = const [ReportStatus.menunggu, ReportStatus.diperiksa],
  }) async {
    return Report.rows(await _c
        .from('reports')
        .select(_reportSelectAdmin)
        .inFilter('status', statuses.map((s) => s.wire).toList())
        .order('severity', ascending: false)
        .order('created_at', ascending: true));
  }

  Future<List<Report>> allReports({String? labId}) async {
    var q = _c.from('reports').select(_reportSelectAdmin);
    if (labId != null) q = q.eq('lab_id', labId);
    return Report.rows(await q.order('created_at', ascending: false).limit(300));
  }

  Future<MaintenanceJob?> job(String id) async {
    final row = await _c.from('maintenance_histories').select(_jobSelect).eq('id', id).maybeSingle();
    return row == null ? null : MaintenanceJob.fromRow(row);
  }

  /// Log servis untuk Beranda mobile: riwayat terbbaru, status apa pun.
  Future<List<MaintenanceJob>> recentJobs({int limit = 60}) async =>
      MaintenanceJob.rows(await _c
          .from('maintenance_histories')
          .select(_jobSelect)
          .order('maintenance_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit));

  Future<List<MaintenanceJob>> openJobs() async => MaintenanceJob.rows(await _c
      .from('maintenance_histories')
      .select(_jobSelect)
      .inFilter('status', [MaintenanceStatus.tertunda.wire, MaintenanceStatus.berjalan.wire])
      .order('maintenance_date', ascending: false));

  Future<List<Announcement>> announcements({bool publishedOnly = true}) async {
    var q = _c.from('announcements').select();
    if (publishedOnly) q = q.eq('is_published', true);
    return Announcement.rows(await q.order('published_at', ascending: false).limit(20));
  }

  Future<List<LabStats>> labStats() async =>
      LabStats.rows(await _c.from('v_lab_stats').select().order('code', ascending: true));

  Future<Profile?> profile(String id) async {
    final row = await _c.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  /// Daftar akun untuk tab Pengguna. Hanya kolom publik di `profiles`: schema
  /// `auth` tidak boleh disentuh dari klien mana pun.
  Future<List<Profile>> profiles() async =>
      Profile.rows(await _c.from('profiles').select().order('username', ascending: true));

  // ---------------------------------------------------------------------------
  // Tulis — pengguna
  // ---------------------------------------------------------------------------

  /// Jantung sisi mobile. Fungsi ini yang memutuskan tiket baru atau keluhan
  /// tambahan pada tiket yang sudah terbuka, dan memindahkan status aset ke
  /// `dalam_pengajuan` — semuanya dalam satu transaksi.
  Future<ReportIssueResult> reportIssue({
    String? pcId,
    String? supportingItemId,
    required String issue,
    ReportSeverity severity = ReportSeverity.sedang,
    List<String> evidencePaths = const [],
  }) async {
    final raw = await _rpc('sibal_report_issue', {
      'p_pc_id': pcId,
      'p_supporting_item_id': supportingItemId,
      'p_issue': issue,
      'p_severity': severity.wire,
      'p_evidence_paths': evidencePaths,
    });
    return ReportIssueResult.decode(raw);
  }

  Future<void> cancelReport(String reportId) =>
      _rpc('sibal_cancel_report', {'p_report_id': reportId});

  /// Pemilik akun mengoreksi profilnya sendiri. Ini satu-satunya tulis langsung
  /// yang diizinkan, dan hanya tiga kolom itu yang granted (0002 §3).
  Future<Profile> updateOwnProfile({String? fullName, String? description}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw const CloudFailure('Tidak ada sesi aktif.');
    final patch = <String, dynamic>{};
    if (fullName != null) patch['full_name'] = fullName.trim();
    if (description != null) patch['description'] = description.trim();
    if (patch.isEmpty) throw const CloudFailure('Tidak ada yang diubah.');
    try {
      final row = await _c.from('profiles').update(patch).eq('id', uid).select().single();
      return Profile.fromRow(row);
    } on PostgrestException catch (e) {
      throw CloudFailure(e.message, code: e.code);
    }
  }

  // ---------------------------------------------------------------------------
  // Tulis — panel admin
  // ---------------------------------------------------------------------------
  //
  // `p_operator_email` sengaja tidak pernah diisi. Dengan sesi Supabase Auth,
  // app.resolve_admin() membaca auth.uid(); jalur email hanya ada untuk koneksi
  // langsung (Retool) dan sudah tidak dipakai.

  Future<String> checkReport({
    required String reportId,
    String? notes,
    String? performedBy,
  }) async =>
      await _rpc('sibal_check_report', _clean({
        'p_report_id': reportId,
        'p_notes': notes,
        'p_performed_by': performedBy,
      })) as String;

  Future<String> approveReport({
    required String reportId,
    required String actionTaken,
    MaintenanceKind kind = MaintenanceKind.perbaikan,
    AssetStatus assetStatus = AssetStatus.diperiksa,
    String? performedBy,
    int qtyDelta = 0,
  }) async {
    if (!assetStatus.bolehUntukApprove) {
      throw CloudFailure(
        'Approve hanya boleh menghasilkan status rusak/diperiksa; mengembalikan '
        'aset ke "baik" adalah pekerjaan menyelesaikan riwayat.',
      );
    }
    return await _rpc('sibal_approve_report', _clean({
      'p_report_id': reportId,
      'p_action_taken': actionTaken,
      'p_kind': kind.wire,
      'p_asset_status': assetStatus.wire,
      'p_performed_by': performedBy,
      'p_qty_delta': qtyDelta,
    })) as String;
  }

  Future<void> rejectReport({required String reportId, required String reason}) =>
      _rpc('sibal_reject_report', {'p_report_id': reportId, 'p_reason': reason});

  Future<void> completeMaintenance({
    required String jobId,
    String? notes,
    AssetStatus outcome = AssetStatus.baik,
    int qtyDelta = 0,
  }) =>
      _rpc('sibal_complete_maintenance', _clean({
        'p_maintenance_id': jobId,
        'p_notes': notes,
        'p_outcome': outcome.wire,
        'p_qty_delta': qtyDelta,
      }));

  Future<void> reopenReport({required String reportId, required String reason}) =>
      _rpc('sibal_reopen_report', {'p_report_id': reportId, 'p_reason': reason});

  /// Riwayat pemeliharaan mandiri (0009): di luar alur pengajuan.
  /// [selesai] mencatat pekerjaan yang sudah dikerjakan; delta stok hanya
  /// boleh menyertai bentuk itu — pekerjaan terbuka menggeser stok saat
  /// penutupan lewat [completeMaintenance], supaya tidak bergerak dua kali.
  Future<String> createMaintenance({
    String? pcId,
    String? supportingItemId,
    MaintenanceKind category = MaintenanceKind.inspeksi,
    required String actionTaken,
    String? notes,
    DateTime? maintenanceDate,
    bool selesai = false,
    String? performedBy,
    int qtyDelta = 0,
    String? reason,
  }) async =>
      await _rpc('sibal_create_maintenance', _clean({
        'p_pc_id': pcId,
        'p_supporting_item_id': supportingItemId,
        'p_category': category.wire,
        'p_action_taken': actionTaken,
        'p_notes': notes,
        'p_maintenance_date': maintenanceDate == null
            ? null
            : '${maintenanceDate.year.toString().padLeft(4, '0')}-'
                '${maintenanceDate.month.toString().padLeft(2, '0')}-'
                '${maintenanceDate.day.toString().padLeft(2, '0')}',
        'p_selesai': selesai,
        'p_performed_by': performedBy,
        'p_qty_delta': qtyDelta,
        'p_reason': reason,
      })) as String;

  /// Koreksi deskriptif riwayat (0009 §2). Konvensi teks sama dengan 0006:
  /// null = jangan ubah, '' = kosongkan (notes). Status, target, dan stok
  /// tidak bisa diubah lewat jalur ini — memang tidak ada parameternya.
  Future<void> updateMaintenance({
    required String jobId,
    MaintenanceKind? category,
    String? actionTaken,
    String? notes,
    DateTime? maintenanceDate,
  }) =>
      _rpc('sibal_update_maintenance', {
        'p_maintenance_id': jobId,
        'p_category': category?.wire,
        'p_action_taken': actionTaken,
        'p_notes': notes,
        'p_maintenance_date': maintenanceDate == null
            ? null
            : '${maintenanceDate.year.toString().padLeft(4, '0')}-'
                '${maintenanceDate.month.toString().padLeft(2, '0')}-'
                '${maintenanceDate.day.toString().padLeft(2, '0')}',
      });

  /// Hanya riwayat mandiri tanpa gerakan stok (0009 §3); server menolak
  /// riwayat terkait pengajuan dan riwayat yang menggeser stok.
  Future<void> deleteMaintenance(String jobId) =>
      _rpc('sibal_delete_maintenance', {'p_maintenance_id': jobId});

  Future<void> setAssetStatus({
    String? pcId,
    String? supportingItemId,
    required AssetStatus status,
    required String reason,
  }) =>
      _rpc('sibal_set_asset_status', _clean({
        'p_pc_id': pcId,
        'p_supporting_item_id': supportingItemId,
        'p_status': status.wire,
        'p_reason': reason,
      }));

  Future<void> setUserRole({required String userId, required AppRole role}) =>
      _rpc('sibal_set_user_role', {'p_user_id': userId, 'p_role': role.wire});

  Future<void> setUserActive({required String userId, required bool isActive}) =>
      _rpc('sibal_set_user_active', {'p_user_id': userId, 'p_is_active': isActive});

  /// Kolom teks mengikuti konvensi `app.text_field` (0006 §1):
  /// null = jangan ubah, string kosong = kosongkan. Karena itu nilainya dikirim
  /// apa adanya — trim di sini akan menghancurkan bedanya.
  Future<void> updatePc({
    required String pcId,
    required String processor,
    required String ram,
    String? storage,
    String? gpu,
    String? mouseSpec,
    String? keyboardSpec,
    String? location,
    String? notes,
  }) =>
      _rpc('sibal_update_pc', {
        'p_pc_id': pcId,
        'p_processor': processor,
        'p_ram': ram,
        'p_storage': storage,
        'p_gpu': gpu,
        'p_mouse_spec': mouseSpec,
        'p_keyboard_spec': keyboardSpec,
        'p_location': location,
        'p_notes': notes,
      });

  /// `qty` hanya lewat jalur ini: delta wajib beralasan dan selalu menulis
  /// baris riwayat (0006 §3).
  Future<void> updateSupportItem({
    required String itemId,
    required String name,
    SupportCategory? category,
    String? specifications,
    String? unit,
    String? location,
    String? notes,
    int? qty,
    String? reason,
  }) =>
      _rpc('sibal_update_supporting_item', {
        'p_supporting_item_id': itemId,
        'p_name': name,
        'p_category': category?.wire,
        'p_specifications': specifications,
        'p_unit': unit,
        'p_location': location,
        'p_notes': notes,
        'p_qty': qty,
        'p_reason': reason,
      });

  Future<String> upsertAnnouncement({
    String? id,
    required String title,
    required String body,
    AnnouncementLevel level = AnnouncementLevel.info,
    bool isPublished = true,
    DateTime? expiresAt,
  }) async =>
      await _rpc('sibal_upsert_announcement', _clean({
        'p_id': id,
        'p_title': title,
        'p_body': body,
        'p_level': level.wire,
        'p_is_published': isPublished,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      })) as String;

  Future<void> deleteAnnouncement(String id) =>
      _rpc('sibal_delete_announcement', {'p_id': id});

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// PostgREST memetakan kunci JSON ke nama parameter function. Nama parameter
  /// harus sama persis dengan yang dikirim `sig.js`/SQL Editor, jadi tabel
  /// argumen di atas adalah kontraknya — jangan "dirapikan".
  Future<dynamic> _rpc(String fn, Map<String, dynamic> args) async {
    try {
      return await _c.rpc(fn, params: args);
    } on PostgrestException catch (e) {
      throw CloudFailure(_readable(e.message), code: e.code);
    }
  }

  /// kunci bernilai null tidak perlu dikirim: default parameter function sudah
  /// null. Mengirimnya tetap aman, tapi membuang membuat log request lebih jelas.
  Map<String, dynamic> _clean(Map<String, dynamic> args) =>
      args.entries.where((e) => e.value != null).fold(<String, dynamic>{}, (m, e) => m..putIfAbsent(e.key, () => e.value));

  /// Pesan database sudah berbahasa Indonesia; yang perlu diterjemahkan hanya
  /// kegagalan lapis atas (ACL/RLS) yang bunyinya teknis.
  String _readable(String message) {
    final m = message.toLowerCase();
    if (m.contains('permission denied for function')) {
      return 'Akun ini tidak berhak menjalankan aksi tersebut.';
    }
    if (m.contains('row-level security')) {
      return 'Data tidak tersedia untuk akun ini (kebijakan akses baris).';
    }
    return message;
  }
}

/// Helper kecil supaya AppEnv tetap dipakai di satu tempat untuk validasi bentuk.
bool looksLikeUuid(String v) =>
    RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(v.trim());
