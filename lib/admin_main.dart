/// Entrypoint panel admin (Flutter Web).
///
/// Build:
///   flutter build web -t lib/admin_main.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
/// Jalankan tanpa hosting di jaringan lab:
///   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 -t lib/admin_main.dart
///
/// Berkas ini TIDAK mengimpor shell mobile, `AppState`, maupun Hive. Yang dipakai
/// bersama hanya model, repository, service auth, dan tema — jadi tidak ada
/// kesempatan bagi panel untuk membaca data basi dari cache perangkat.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_login.dart';
import 'admin/admin_shell.dart';
import 'admin/admin_state.dart';
import 'core/app_bootstrap.dart';
import 'services/auth_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await bootstrapSibalApp();
  } catch (e) {
    runApp(_KonfigurasiBuruk(message: '$e'));
    return;
  }

  // Sesi dipulihkan oleh Supabase.initialize. Peran dibaca ulang dari database:
  // kalau akun diturunkan atau dinonaktifkan sejak sesi terakhir, panel harus
  // tahu sekarang, bukan nanti saat admin menekan Setujui.
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    try {
      final p = await AuthService.instance.requireProfile(session.user.id);
      await AdminState.instance.attach(p);
    } catch (_) {
      await AuthService.instance.signOut();
    }
  }

  runApp(const SibalAdminApp());
}

class SibalAdminApp extends StatelessWidget {
  const SibalAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIBAL Admin',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(primary: mint, surface: card),
        ),
        home: AnimatedBuilder(
          animation: AdminState.instance,
          builder: (context, _) =>
              AdminState.instance.me == null ? const AdminLoginPage() : const AdminShell(),
        ),
      );
}

class _KonfigurasiBuruk extends StatelessWidget {
  final String message;
  const _KonfigurasiBuruk({required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, scaffoldBackgroundColor: bg),
        home: Scaffold(
          backgroundColor: bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tx('Panel admin belum punya konfigurasi cloud', 18,
                      w: FontWeight.w700, al: TextAlign.center),
                  const SizedBox(height: 12),
                  tx(
                    '$message\n\nJalankan dengan:\n'
                    'flutter run -d web-server -t lib/admin_main.dart '
                    '--dart-define=SUPABASE_URL=<url> '
                    '--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>',
                    12.5,
                    c: Colors.white70,
                    al: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
