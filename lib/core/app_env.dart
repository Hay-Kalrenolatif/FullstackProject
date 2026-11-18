/// Konfigurasi cloud SIBAL.
///
/// Nilainya masuk lewat `--dart-define` saat build, bukan dari file yang
/// di-commit. Alasannya bukan sekadar kerapian: hasil `flutter build web` adalah
/// berkas statis yang isinya bisa dibaca siapa pun, jadi hanya publishable key
/// yang boleh ada di sana. `SUPABASE_SECRET_KEY` / service_role tidak pernah
/// dipakai oleh kedua target.
library;

class AppEnv {
  AppEnv._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Kembaran persis dari `app.email_for_username()` (0002 §2, domain dipindah di
  /// 0007). Supabase Auth hanya mengenal email, jadi username dipetakan ke alamat
  /// sintetis. Domain `.invalid` tidak bisa dipakai: GoTrue menolaknya saat
  /// signup (`email_address_invalid`). Kalau konstanta ini dan function SQL tidak
  /// sama, seluruh login berubah jadi "Invalid login credentials".
  static const String emailDomain = '@sibal.my.id';

  /// Bentuk username yang sama dengan CHECK `profiles_username_shape` di 0001.
  /// Dikawal di sisi klien supaya pesannya muncul sebelum request, bukan sebagai
  /// error 23514 dari database.
  static final RegExp usernameShape = RegExp(r'^[a-z0-9._-]{3,32}$');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String emailForUsername(String username) =>
      '${username.trim().toLowerCase()}$emailDomain';

  static String normalizeUsername(String username) => username.trim().toLowerCase();

  /// Validasi dini. Kegagalannya sengaja memakai kata "dart-define" karena
  /// gejala tanpa pesan ini adalah NullCheckError jauh di dalam SDK yang tidak
  /// memberi petunjuk apa pun kepada pembaca kode.
  static void ensureConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase belum dikonfigurasi. Build dengan:\n'
      '  flutter run --dart-define=SUPABASE_URL=<url project> '
      '--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>\n'
      'Nilai ada di .env (tidak di-commit). Jangan gunakan SUPABASE_SECRET_KEY.',
    );
  }
}
