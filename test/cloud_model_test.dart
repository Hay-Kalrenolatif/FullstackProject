/// Uji model cloud: konvensi login, domain enum, dan round-trip baris.
///
/// Round-trip (`fromRow` → `toJson` → `fromRow`) adalah uji yang menjaga jalur
/// cache: cache Hive menyimpan hasil `toJson`, jadi kalau satu kunci tertulis
/// beda dari yang dibaca, perangkat offline akan menampilkan data rusak — dan
/// itu tidak akan ketahuan sampai demo hari-H.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sibal/core/app_env.dart';
import 'package:sibal/models/asset_enums.dart';
import 'package:sibal/models/assets.dart';
import 'package:sibal/models/people.dart';
import 'package:sibal/models/row.dart';
import 'package:sibal/models/tickets.dart';

void main() {
  group('AppEnv — konvensi login', () {
    test('username dipetakan ke email sintetis, huruf kecil & trim', () {
      expect(AppEnv.emailForUsername('  Botan_01 '), 'botan_01@sibal.my.id');
      expect(AppEnv.normalizeUsername('Rian.P'), 'rian.p');
    });

    test('domain bukan yang dicadangkan RFC — GoTrue menolaknya saat signup', () {
      expect(AppEnv.emailDomain.endsWith('.invalid'), false);
      expect(AppEnv.emailDomain, '@sibal.my.id');
    });

    test('bentuk username sama dengan CHECK profiles_username_shape', () {
      expect(AppEnv.usernameShape.hasMatch('botan'), true);
      expect(AppEnv.usernameShape.hasMatch('a.b-c_1'), true);
      expect(AppEnv.usernameShape.hasMatch('ab'), false); // terlalu pendek
      expect(AppEnv.usernameShape.hasMatch('Botan'), false); // huruf besar
      expect(AppEnv.usernameShape.hasMatch('botan!'), false); // karakter terlarang
      expect(AppEnv.usernameShape.hasMatch('a' * 33), false);
    });
  });

  group('Domain enum', () {
    test('label wire sama dengan nilai enum Postgres', () {
      expect(AssetStatus.dalamPengajuan.wire, 'dalam_pengajuan');
      expect(ReportStatus.diproses.wire, 'diproses');
      expect(TargetKind.supportingItem.wire, 'supporting_item');
      // Kategori ini dulu salah ditulis 'perlengkapan' dan baru terbaca saat
      // dieksekusi — uji ini menutup regressinya.
      expect(MaintenanceKind.pelengkapan.wire, 'pelengkapan');
    });

    test('nilai asing tidak lolos diam-diam', () {
      expect(AssetStatus.tryParse('rusak'), AssetStatus.rusak);
      expect(AssetStatus.tryParse('Rusak'), null);
      expect(AssetStatus.tryParse(null), null);
      expect(ReportSeverity.parseOr('tidak-ada'), ReportSeverity.sedang);
    });

    test('himpunan status yang dijaga database', () {
      expect(AssetStatus.rusak.bolehUntukApprove, true);
      expect(AssetStatus.diperiksa.bolehUntukApprove, true);
      expect(AssetStatus.baik.bolehUntukApprove, false);
      expect(AssetStatus.dalamPengajuan.butuhPerhatian, true);
      expect(AssetStatus.purnatugas.butuhPerhatian, false);
      expect(ReportStatus.menunggu.terbuka, true);
      expect(ReportStatus.selesai.terbuka, false);
      expect(MaintenanceStatus.dibatalkan.terbuka, false);
    });
  });

  group('PcAsset round-trip', () {
    final row = <String, dynamic>{
      'id': '00000000-0000-0000-0000-0000000001a1',
      'lab_id': '00000000-0000-0000-0000-000000000001',
      'codename': 'PC-01',
      'processor': 'Intel Core i5-12400',
      'ram': '16 GB DDR4',
      'storage': '512 GB NVMe',
      'gpu': null,
      'mouse_spec': 'Logitech M170',
      'keyboard_spec': null,
      'status': 'dalam_pengajuan',
      'location': 'Baris depan kiri',
      'notes': null,
      'is_active': true,
      'created_at': '2026-11-03T01:00:00+00:00',
      'updated_at': '2026-11-03T02:30:00+00:00',
    };

    test('status dan kolom nullable terbaca apa adanya', () {
      final pc = PcAsset.fromRow(row);
      expect(pc.status, AssetStatus.dalamPengajuan);
      expect(pc.gpu, null);
      expect(pc.notes, null);
      expect(pc.isActive, true);
      expect(pc.updatedAt, DateTime.utc(2026, 11, 3, 2, 30));
    });

    test('toJson bisa dibaca kembali (jalur cache Hive)', () {
      final sekali = PcAsset.fromRow(row);
      final dua = PcAsset.fromRow(sekali.toJson());
      expect(dua.codename, sekali.codename);
      expect(dua.status, sekali.status);
      expect(dua.gpu, sekali.gpu);
      expect(dua.updatedAt, sekali.updatedAt);
      expect(dua.specLine, contains('Intel Core i5-12400'));
    });
  });

  group('SupportAsset', () {
    test('qty = 0 berarti habis, dan label ikut satuan', () {
      final a = SupportAsset.fromRow(<String, dynamic>{
        'id': 'x', 'lab_id': 'l', 'name': 'UPS', 'category': 'daya',
        'qty': 0, 'unit': 'unit', 'status': 'habis', 'is_active': true,
      });
      expect(a.habis, true);
      expect(a.qtyLabel, '0 unit');
      expect(a.category, SupportCategory.daya);
      expect(a.status, AssetStatus.habis);
    });

    test('round-trip lewat toJson', () {
      final a = SupportAsset.fromRow(<String, dynamic>{
        'id': 'x', 'lab_id': 'l', 'name': 'Switch', 'category': 'jaringan',
        'specifications': '24 port', 'qty': 2, 'unit': 'unit', 'status': 'baik',
        'location': 'Rak', 'notes': 'tip', 'is_active': true,
        'updated_at': '2026-11-03T04:05:06+00:00',
      });
      final b = SupportAsset.fromRow(a.toJson());
      expect(b.name, a.name);
      expect(b.qty, a.qty);
      expect(b.specifications, a.specifications);
      expect(b.updatedAt, a.updatedAt);
    });
  });

  group('Report', () {
    final row = <String, dynamic>{
      'id': 'r1',
      'user_id': 'u1',
      'reporter_name': 'Rian Pratama',
      'lab_id': 'l1',
      'pc_id': 'p1',
      'supporting_item_id': null,
      'target_kind': 'pc',
      'prev_asset_status': 'baik',
      'issue_description': 'Monitor mati total',
      'severity': 'darurat',
      'evidence_paths': ['a.jpg', 'b.jpg'],
      'status': 'menunggu',
      'reviewed_by': null,
      'admin_notes': null,
      'created_at': '2026-11-03T03:00:00+00:00',
      'labs': {'code': 'LAB1', 'name': 'Lab Jaringan'},
      'pcs': {'codename': 'PC-04'},
    };

    test('embed dipakai untuk label, tanpa perlu query kedua', () {
      final r = Report.fromRow(row);
      expect(r.assetName, 'PC-04');
      expect(r.targetKind, TargetKind.pc);
      expect(r.severity, ReportSeverity.darurat);
      expect(r.evidencePaths.length, 2);
      expect(r.status.terbuka, true);
    });

    test('round-trip menyimpan bekal pemulihan status (prev_asset_status)', () {
      final b = Report.fromRow(Report.fromRow(row).toJson());
      expect(b.prevAssetStatus, AssetStatus.baik);
      expect(b.issue, 'Monitor mati total');
      expect(b.assetName, 'PC-04');
      expect(b.labLabel, 'LAB1');
    });
  });

  group('MaintenanceJob', () {
    test('maintenance_date adalah tanggal kalender, bukan timestamp UTC', () {
      final j = MaintenanceJob.fromRow(<String, dynamic>{
        'id': 'j1', 'lab_id': 'l1', 'pc_id': null, 'supporting_item_id': 'i1',
        'target_kind': 'supporting_item', 'category': 'pelengkapan',
        'status': 'selesai', 'action_taken': 'Menambah stok mouse',
        'performed_by_name': 'Admin', 'maintenance_date': '2026-11-03',
        'qty_delta': 5,
      });
      expect(j.maintenanceDate, DateTime(2026, 11, 3));
      expect(j.qtyDelta, 5);
      expect(j.stokBergerak, true);
      expect(j.category, MaintenanceKind.pelengkapan);
      expect(MaintenanceJob.fromRow(j.toJson()).maintenanceDate, j.maintenanceDate);
    });
  });

  group('Announcement jendela tayang', () {
    Announcement a({required bool pub, DateTime? exp, DateTime? start}) => Announcement.fromRow({
          'id': 'x', 'title': 'T', 'body': 'B', 'level': 'info',
          'is_published': pub,
          'published_at': start?.toIso8601String(),
          'expires_at': exp?.toIso8601String(),
        });

    test('belum tayang / kedaluwarsa / tayang', () {
      final now = DateTime.utc(2026, 11, 3, 10);
      expect(a(pub: true, start: now.subtract(const Duration(hours: 1))).masihTayang(now), true);
      expect(a(pub: true, start: now.add(const Duration(hours: 1))).masihTayang(now), false);
      expect(
        a(pub: true,
            start: now.subtract(const Duration(hours: 2)),
            exp: now.subtract(const Duration(minutes: 1))).masihTayang(now),
        false,
      );
      expect(a(pub: false).masihTayang(now), false);
    });
  });

  group('Profile', () {
    test('peran dan inisial', () {
      final p = Profile.fromRow(<String, dynamic>{
        'id': 'u1', 'username': 'botan', 'full_name': 'Btan Zy',
        'description': '', 'role': 'admin', 'is_active': true,
      });
      expect(p.isAdmin, true);
      expect(p.initials, 'BZ');
      expect(Profile.fromRow(p.toJson()).role, AppRole.admin);
    });

    test('admin nonaktif kehilangan hak di sisi klien juga', () {
      final p = Profile.fromRow(<String, dynamic>{
        'id': 'u1', 'username': 'botan', 'full_name': 'X', 'description': '',
        'role': 'admin', 'is_active': false,
      });
      expect(p.isAdmin, false);
    });
  });

  group('ReportIssueResult decode', () {
    test('PostgREST mengirim RETURNS TABLE sebagai array', () {
      final r = ReportIssueResult.decode([
        {'report_id': 'x1', 'status': 'menunggu', 'reused': false, 'msg': 'Pengajuan terkirim.'}
      ]);
      expect(r.ok, true);
      expect(r.status, ReportStatus.menunggu);
      expect(r.reused, false);
    });

    test('tiket yang sudah terbuka tetap punya report_id, dengan reused true', () {
      final r = ReportIssueResult.decode([
        {'report_id': 'x1', 'status': 'diproses', 'reused': true, 'msg': 'Sudah ada pengajuan terbuka.'}
      ]);
      expect(r.reused, true);
      expect(r.ok, true);
    });

    test('balasan tanpa report_id dianggap kegagalan, bukan sukses hampa', () {
      final r = ReportIssueResult.decode([
        {'report_id': null, 'status': null, 'reused': false, 'msg': 'Pilih salah satu target.'}
      ]);
      expect(r.ok, false);
      expect(r.message, contains('Pilih salah satu'));
    });
  });

  group('LabStats', () {
    test('rasio kesiapan aman untuk Lab tanpa PC', () {
      final s = LabStats.fromRow(<String, dynamic>{
        'lab_id': 'l1', 'code': 'LAB3', 'name': 'Lab',
        'total_pc': 0, 'pc_baik': 0, 'pc_butuh_perhatian': 0,
        'support_qty': 0, 'support_butuh_perhatian': 0,
        'pending_reports': 0, 'pekerjaan_berjalan': 0,
      });
      expect(s.pcReadyRatio, 0);
    });

    test('bigint Postgres terbaca sebagai int', () {
      final s = LabStats.fromRow(<String, dynamic>{
        'lab_id': 'l1', 'code': 'LAB1', 'name': 'Lab',
        'total_pc': 4, 'pc_baik': 3, 'pc_butuh_perhatian': 1,
        'support_qty': 9, 'support_butuh_perhatian': 0,
        'pending_reports': 2, 'pekerjaan_berjalan': 1,
      });
      expect(s.pcReadyRatio, closeTo(0.75, 0.001));
      expect(LabStats.fromRow(s.toJson()).supportQty, 9);
    });
  });

  group('Pembaca baris toleran', () {
    test('angka dari JSON bisa int, double, atau string', () {
      const r = <String, dynamic>{'a': 5, 'b': 5.0, 'c': '5', 'd': 'x'};
      expect(i(r, 'a'), 5);
      expect(i(r, 'b'), 5);
      expect(i(r, 'c'), 5);
      expect(i(r, 'd', fallback: 7), 7);
      expect(b(<String, dynamic>{'v': 'true'}, 'v'), true);
      expect(strList(<String, dynamic>{'v': ['a', 1]}, 'v'), ['a', '1']);
      expect(strList(<String, dynamic>{}, 'v'), isEmpty);
    });
  });
}
