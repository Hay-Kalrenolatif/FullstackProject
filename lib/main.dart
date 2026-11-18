/// Shell mobile SIBAL.
///
/// Rantai layar pembuka: konfigurasi → onboarding (sekali) → login → shell.
/// Onboarding tidak diubah (area ter-commit `46643b8`); yang baru adalah gerbang
/// autentikasi sesudahnya dan sumber datanya, yang sekarang cloud dengan cache
/// Hive sebagai cadangan offline.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_bootstrap.dart';
import 'onboarding/onboarding_page.dart';
import 'pages/login_page.dart';
import 'pages/my_reports_page.dart';
import 'pages/pc_management_page.dart';
import 'pages/profile_page.dart';
import 'pages/summary_page.dart';
import 'pages/support_inventory_page.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_cache.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/app_header.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pembuka (onboarding + login) terkunci potret; isi aplikasi membuka semua
  // orientasi lewat Shell.initState dan mengunci lagi saat logout (dispose).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await bootstrapSibalApp();
  } catch (e) {
    runApp(_ConfigErrorApp(message: '$e'));
    return;
  }

  await LocalCache.instance.init();
  ConnectivityService.instance.start();

  // Sesi lama dipulihkan Supabase saat initialize; profilnya diambil lagi supaya
  // peran (user/admin) dibaca dari database, bukan dari asisi klien.
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    try {
      final p = await AuthService.instance.requireProfile(session.user.id);
      AppState.instance.attachProfile(p);
    } catch (_) {
      // Profil hilang (akun dihapus dashboard?) — biarkan login ulang yang memberes.
      await AuthService.instance.signOut();
    }
  }
  unawaited(AppState.instance.start());

  runApp(const SibalApp());
}

class SibalApp extends StatelessWidget {
  const SibalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIBAL',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          fontFamily: 'Inter',
          colorScheme: const ColorScheme.dark(primary: mint, surface: card),
          bottomAppBarTheme: const BottomAppBarThemeData(
            color: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: const OnboardingGate(),
      );
}

/// Layar gagal yang menjelaskan sebabnya. Tanpa ini, lupa `--dart-define`
/// menghasilkan aplikasi hitam tanpa pesan.
class _ConfigErrorApp extends StatelessWidget {
  final String message;
  const _ConfigErrorApp({required this.message});

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
                  tx('Konfigurasi cloud belum lengkap', 18, w: FontWeight.w700, al: TextAlign.center),
                  const SizedBox(height: 12),
                  tx(
                    message,
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

/// Onboarding → login → shell. Satu-satunya tempat keputusan "layar mana dulu"
/// diambil, supaya tidak ada dua gate yang saling menunggu.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _seen = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _seen = prefs.getBool('sibal_onboarding_seen') ?? false;
      _loading = false;
    });
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sibal_onboarding_seen', true);
    if (!mounted) return;
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: mint)),
      );
    }
    if (!_seen) return OnboardingPage(onCompleted: _complete);
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) => AppState.instance.profile == null
          ? const LoginPage()
          : const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    // Isi aplikasi bebas potret/landscape.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Kembali ke login (logout/sesi habis): kunci potret lagi.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  static const _labels = ['Beranda', 'Unit PC', 'Inventaris', 'Pengajuan', 'Akun'];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.desktop_windows_rounded,
    Icons.inventory_2_outlined,
    Icons.build_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SummaryPage(navigateTo: (i) => setState(() => _activeTab = i)),
      const PCManagementPage(),
      const SupportInventoryPage(),
      MyReportsPage(navigateTo: (i) => setState(() => _activeTab = i)),
      const ProfilePage(),
    ];

    final n = pages.length;

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        // Tinggi header + inset status bar bawaan HP, supaya brand tidak
        // tertutup jam/baterai/notifikasi.
        preferredSize: Size.fromHeight(62 + MediaQuery.of(context).padding.top),
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) => AppHeader(
              subtitle: _labels[_activeTab],
              s: AppState.instance,
              onAvatarTap: () => setState(() => _activeTab = 4),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 0.02), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_activeTab), child: pages[_activeTab]),
        ),
      ),
      bottomNavigationBar: Material(
        color: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: Container(
            height: 58,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(5),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xE60A0A0C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF1E1E21), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 20, offset: const Offset(0, 8)),
                BoxShadow(color: mint.withAlpha(15), blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                // box.maxWidth sekarang = lebar persis area isi Container
                // (sudah dikurangi margin + padding + border), jadi sama
                // dengan lebar Stack dan Row di dalamnya.
                final slot = box.maxWidth / n;
                const size = 42.0;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutCubic,
                      left: _activeTab * slot + (slot - size) / 2,
                      top: 1,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: a(mint, 0.16),
                          border: Border.all(color: mint, width: 1.5),
                          boxShadow: [BoxShadow(color: mint.withAlpha(50), blurRadius: 10, spreadRadius: 1)],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var k = 0; k < n; k++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _activeTab = k),
                              child: Tooltip(
                                message: _labels[k],
                                child: Center(
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    scale: _activeTab == k ? 1.15 : 1.0,
                                    child: Icon(
                                      _icons[k],
                                      size: 21,
                                      color: _activeTab == k ? mint : Colors.white38,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
