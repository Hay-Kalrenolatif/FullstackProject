/// Pembaca baris PostgREST yang dipakai bersama.
///
/// PostgREST mengirim JSON, jadi angka bisa datang sebagai int atau double dan
/// kolom nullable bisa hilang sama sekali. Model tidak boleh mewarisi kerapuhan
/// itu: semua pembacaan lewat fungsi di sini sehingga sisanya deklaratif.
library;

typedef Row = Map<String, dynamic>;

String? sOrNull(Row r, String k) => r[k]?.toString();

String s(Row r, String k, {String fallback = ''}) => sOrNull(r, k) ?? fallback;

int i(Row r, String k, {int fallback = 0}) {
  final v = r[k];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool b(Row r, String k, {bool fallback = false}) {
  final v = r[k];
  if (v is bool) return v;
  if (v is String) return v == 'true';
  if (v is num) return v != 0;
  return fallback;
}

/// timestamptz -> DateTime UTC. Nilai database sudah benar; konversi ke zona
/// lokal adalah urusan tampilan, bukan model.
DateTime? dt(Row r, String k) => DateTime.tryParse(sOrNull(r, k) ?? '')?.toUtc();

/// `date` kalender (maintenance_date) tidak punya zona waktu; jangan dipaksa
/// ke UTC supaya tidak bergeser satu hari saat ditampilkan di WIB.
DateTime? dateOnly(Row r, String k) {
  final v = sOrNull(r, k);
  if (v == null) return null;
  final p = DateTime.tryParse(v);
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

List<String> strList(Row r, String k) {
  final v = r[k];
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

/// Hasil embed `table(join)` dari PostgREST: Map, null, atau (kalau hubungannya
/// tak ada) tidak dikirim sama sekali.
Row? emb(Row r, String k) {
  final v = r[k];
  return v is Map ? Row.from(v.cast<String, dynamic>()) : null;
}

String? embText(Row r, String table, String column) =>
    emb(r, table) == null ? null : sOrNull(emb(r, table)!, column);
