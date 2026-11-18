/// Login, signup, dan pemulihan sesi Supabase Auth untuk kedua shell.
///
/// SIBAL mengenal username, Supabase Auth hanya mengenal email, jadi username
/// dipetakan ke email sintetis (`AppEnv.emailForUsername`). Kembarannya ada di
/// SQL: `app.email_for_username()` (0002 §2). Mengubah salah satu tanpa yang
/// lain = seluruh pengguna kehilangan akunnya.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_env.dart';
import '../models/people.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Session? get session => _auth.currentSession;
  String? get userId => _auth.currentSession?.user.id;
  bool get isSignedIn => _auth.currentSession != null;
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Password minimal 8 karakter: aturan ini klien-only (dashboard bisa lebih
  /// longgar), jadi pesan gagalnya harus menjelaskan syarat kita, bukan 422.
  static const int minPasswordLength = 8;

  String? validateUsername(String username) {
    final u = AppEnv.normalizeUsername(username);
    if (u.isEmpty) return 'Username belum diisi.';
    if (!AppEnv.usernameShape.hasMatch(u)) {
      return 'Username 3–32 karakter: huruf kecil, angka, titik, garis bawah, atau strip.';
    }
    return null;
  }

  String? validatePassword(String password) {
    if (password.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter.';
    }
    return null;
  }

  String? validateFullName(String fullName) {
    final n = fullName.trim();
    if (n.length < 2) return 'Nama tampilan minimal 2 karakter.';
    if (n.length > 80) return 'Nama tampilan maksimal 80 karakter.';
    return null;
  }

  Future<Profile> signIn({required String username, required String password}) async {
    final fail = validateUsername(username) ?? _blank(password, 'Password belum diisi.');
    if (fail != null) throw AuthFailure(fail);

    final res = await _guard(
      () => _auth.signInWithPassword(
        email: AppEnv.emailForUsername(username),
        password: password,
      ),
    );
    if (res.session == null) throw const AuthFailure('Login tidak menghasilkan sesi.');
    return await requireProfile(res.session!.user.id);
  }

  /// Signup selalu melahirkan `user`. Role tidak pernah dikirim lewat
  /// user_metadata: field itu dibaca klien dan dulu jadi lubang eskalasi
  /// (ditutup di 0004). Pengangkatan admin hanya lewat sibal_set_user_role.
  Future<Profile> signUp({
    required String username,
    required String fullName,
    required String password,
  }) async {
    final fail = validateUsername(username) ??
        validateFullName(fullName) ??
        validatePassword(password);
    if (fail != null) throw AuthFailure(fail);

    final u = AppEnv.normalizeUsername(username);
    final res = await _guard(
      () => _auth.signUp(
        email: AppEnv.emailForUsername(u),
        password: password,
        data: {'username': u, 'full_name': fullName.trim()},
      ),
    );
    if (res.session == null) {
      throw const AuthFailure(
        'Akun dibuat, tapi sesi belum aktif. Konfirmasi email di dashboard Supabase '
        'harus dimatikan agar login langsung bisa.',
      );
    }
    return await requireProfile(res.session!.user.id);
  }

  Future<void> signOut() => _auth.signOut();

  Future<Profile?> loadProfile(String id) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  /// Sesi tanpa baris profil berarti trigger `handle_new_user` tidak jalan —
  /// lebih baik diberitahu sekarang daripada UI menampilkan nama kosong.
  Future<Profile> requireProfile(String id) async {
    final p = await loadProfile(id);
    if (p == null) {
      throw const AuthFailure(
        'Profil akun belum ada di database. Akun mungkin dibuat langsung di '
        'Authentication tanpa memicu pembuatan profil.',
      );
    }
    if (!p.isActive) throw const AuthFailure('Akun dinonaktifkan admin.');
    return p;
  }

  /// Kolom yang boleh ditulis pemilik akun: full_name, description, avatar_path.
  /// Mengirim kolom lain di sini akan ditolak lapis privilege, jadi daftarnya
  /// sengaja sempit.
  Future<Profile> updateOwnProfile({String? fullName, String? description}) async {
    final id = userId;
    if (id == null) throw const AuthFailure('Tidak ada sesi aktif.');
    final patch = <String, dynamic>{};
    if (fullName != null) {
      final f = fullName.trim();
      if (f.length < 2 || f.length > 80) throw const AuthFailure('Nama tampilan 2–80 karakter.');
      patch['full_name'] = f;
    }
    if (description != null) {
      final d = description.trim();
      if (d.length > 280) throw const AuthFailure('Deskripsi maksimal 280 karakter.');
      patch['description'] = d;
    }
    if (patch.isEmpty) return (await requireProfile(id));

    final row = await Supabase.instance.client
        .from('profiles')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Profile.fromRow(row);
  }

  /// Ganti password pengguna yang sedang login. Sesi aktif adalah bukti
  /// kepemilikan akun — Supabase Auth tidak meminta password lama saat
  /// updateUser dipanggil dari sesi yang masih hidup.
  Future<void> updatePassword(String newPassword) async {
    if (userId == null) throw const AuthFailure('Tidak ada sesi aktif.');
    final fail = validatePassword(newPassword);
    if (fail != null) throw AuthFailure(fail);
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  String? _blank(String v, String msg) => v.isEmpty ? msg : null;

  /// Pesan Supabase berbahasa Inggris dan berisi kode yang tidak dikenal
  /// pengguna lab. Diterjemahkan untuk kasus yang pasti, sisanya lewat apa ada.
  Future<AuthResponse> _guard(Future<AuthResponse> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login credentials')) {
        throw const AuthFailure('Username atau password salah.');
      }
      if (m.contains('already registered') || m.contains('already exists')) {
        throw const AuthFailure('Username itu sudah terpakai.');
      }
      if (m.contains('password should be at least')) {
        throw const AuthFailure('Password terlalu pendek (minimal 8 karakter).');
      }
      if (m.contains('email not confirmed')) {
        throw const AuthFailure('Konfirmasi email masih aktif — matikan di dashboard Supabase.');
      }
      throw AuthFailure(e.message);
    }
  }
}
