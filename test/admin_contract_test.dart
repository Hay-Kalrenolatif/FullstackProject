/// Uji kontrak form panel admin.
///
/// Yang diuji di sini adalah tiga aturan yang kalau salah menghasilkan data
/// rusak di database, bukan sekadar tampilan jelek:
///   1. `app.text_field`: tidak diubah (null) vs dikosongkan ('').
///   2. stok hanya bergerak lewat angka absolut + alasan.
///   3. status yang boleh dipilih lewat `sibal_set_asset_status`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sibal/admin/admin_state.dart';
import 'package:sibal/admin/widgets/admin_ui.dart';
import 'package:sibal/models/asset_enums.dart';

void main() {
  group('textFieldValue — konvensi app.text_field (0006 §1)', () {
    test('kolom yang tidak disentuh dikirim null, bukan string', () {
      expect(textFieldValue('Intel Core i5', 'Intel Core i5'), isNull);
    });

    test('perbedaan spasi saja tetap dianggap tidak berubah', () {
      expect(textFieldValue(' 16 GB DDR4 ', '16 GB DDR4'), isNull);
    });

    test('dikosongkan dikirim string kosong, dan itu beda dengan null', () {
      expect(textFieldValue('ada isinya', ''), isEmpty);
      expect(textFieldValue('ada isinya', ''), isNotNull);
      expect(textFieldValue(null, ''), isNull, reason: 'kolom sudah kosong: jangan kirim apa pun');
    });

    test('nilai baru dikirim sudah di-trim', () {
      expect(textFieldValue('lama', '  nilai baru  '), 'nilai baru');
    });

    test('kolom yang semula null lalu diisi mengirim nilainya', () {
      expect(textFieldValue(null, 'GPU terpasang'), 'GPU terpasang');
    });
  });

  group('qtyIfChanged — stok hanya lewat p_qty + p_reason', () {
    test('angka sama berarti tidak ada pergerakan stok', () {
      expect(qtyIfChanged(10, 10), isNull);
    });

    test('angka berbeda dikirim sebagai nilai absolut baru', () {
      expect(qtyIfChanged(10, 8), 8);
      expect(qtyIfChanged(0, 3), 3);
    });
  });

  group('statusUntukPerubahan — daftar yang ditawarkan tab Aset', () {
    test('dalam_pengajuan tidak pernah ditawarkan', () {
      final pilihan = AdminState.statusUntukPerubahan(AssetStatus.baik, pc: true);
      expect(pilihan, isNot(contains(AssetStatus.dalamPengajuan)));
    });

    test('habis bukan pilihan untuk PC (dijaga pcs_status_check)', () {
      final pc = AdminState.statusUntukPerubahan(AssetStatus.baik, pc: true);
      final barang = AdminState.statusUntukPerubahan(AssetStatus.baik, pc: false);
      expect(pc, isNot(contains(AssetStatus.habis)));
      expect(barang, contains(AssetStatus.habis));
    });

    test('status sekarang tidak ditawarkan ulang', () {
      final pilihan = AdminState.statusUntukPerubahan(AssetStatus.rusak, pc: true);
      expect(pilihan, isNot(contains(AssetStatus.rusak)));
      expect(pilihan, contains(AssetStatus.baik));
    });

    test('status untuk approve hanya rusak dan diperiksa', () {
      expect(AssetStatus.values.where((s) => s.bolehUntukApprove).toSet(),
          {AssetStatus.rusak, AssetStatus.diperiksa});
    });
  });

  group('bantuan tampilan', () {
    test('shortId memotong uuid menjadi 8 karakter', () {
      expect(shortId('0f6c1e2a-7b3d-4e5f-9a0b-1c2d3e4f5a6b'), '0f6c1e2a');
      expect(shortId('pendek'), 'pendek');
    });

    test('umur tiket memakai satuan pendek', () {
      final now = DateTime.now().toUtc();
      expect(ago(now), 'baru');
      expect(ago(now.subtract(const Duration(minutes: 12))), '12m');
      expect(ago(now.subtract(const Duration(hours: 3))), '3j');
      expect(ago(now.subtract(const Duration(days: 4))), '4h');
      expect(ago(null), '—');
    });

    test('AdminForm menyimpan nilai per kunci dan nullable menormalkan kosong', () {
      final f = AdminForm();
      f.c('notes', initial: '  halo  ');
      expect(f.v('notes'), '  halo  ');
      expect(f.nullable('notes'), 'halo');
      f.c('kosong', initial: '   ');
      expect(f.nullable('kosong'), isNull);
      f.c('delta', initial: '-2');
      expect(f.intV('delta'), -2);
      expect(f.intV('tidak ada', fallback: 0), 0);
      f.set('level', 'penting');
      expect(f.sel<String>('level'), 'penting');
      f.dispose();
    });
  });
}
