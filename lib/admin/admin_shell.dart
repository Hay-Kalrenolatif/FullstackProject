/// Kerangka panel admin: sidebar + isi.
///
/// Enam tab mengikuti kontrak di AGENTS.md Bagian 3. Sidebar bukan NavigationRail
/// bawaan Material karena panel ini harus tetap terlihat seperti produk yang sama
/// dengan aplikasi mobile (token `theme.dart` yang dipakai, bukan Material default).
library;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_state.dart';
import 'assets_page.dart';
import 'broadcast_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'queue_page.dart';
import 'users_page.dart';
import 'widgets/admin_ui.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  static const _judul = ['Dashboard', 'Antrean', 'Aset', 'Riwayat', 'Broadcast', 'Pengguna'];
  static const _ikon = [
    Icons.space_dashboard_rounded,
    Icons.assignment_turned_in_rounded,
    Icons.desktop_windows_rounded,
    Icons.history_rounded,
    Icons.campaign_rounded,
    Icons.group_rounded,
  ];

  Widget get _isi => switch (_tab) {
        0 => const AdminDashboardPage(),
        1 => const AdminQueuePage(),
        2 => const AdminAssetsPage(),
        3 => const AdminHistoryPage(),
        4 => const AdminBroadcastPage(),
        _ => const AdminUsersPage(),
      };

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          if (!s.isAdmin) return _BukanAdmin(state: s);

          final w = MediaQuery.sizeOf(context).width;
          final hp = w < 700;
          final sempit = w < 980;
          final lebar = sempit ? 78.0 : 236.0;

          // HP: sidebar jadi drawer hamburger; tablet tetap rail ikon;
          // desktop sidebar penuh. Isi halaman sama untuk ketiganya.
          if (hp) {
            return Scaffold(
              backgroundColor: bg,
              appBar: AppBar(
                backgroundColor: card,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: tx(_judul[_tab], 15, w: FontWeight.w700),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: cardBorder),
                ),
              ),
              drawer: Drawer(
                width: 264,
                backgroundColor: card,
                child: SafeArea(
                  child: _nav(s, compact: false, onPicked: () => Navigator.pop(context)),
                ),
              ),
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_tab), child: _isi),
              ),
            );
          }

          return Scaffold(
            backgroundColor: bg,
            body: Row(
              children: [
                Container(
                  width: lebar,
                  decoration: BoxDecoration(
                    color: card,
                    border: Border(right: BorderSide(color: cardBorder)),
                  ),
                  child: _nav(s, compact: sempit),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(key: ValueKey(_tab), child: _isi),
                  ),
                ),
              ],
            ),
          );
        },
      );

  /// Isi navigasi yang sama untuk sidebar dan drawer.
  Widget _nav(AdminState s, {required bool compact, VoidCallback? onPicked}) => Column(
        children: [
          const SizedBox(height: 18),
          if (compact)
            const Center(child: Logo(compact: true))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Logo(),
                  const SizedBox(width: 4),
                  tx('ADMIN', 10, c: mint, w: FontWeight.w800),
                ],
              ),
            ),
          const SizedBox(height: 22),
          for (var i = 0; i < _judul.length; i++)
            _NavItem(
              label: _judul[i],
              icon: _ikon[i],
              badge: i == 1 ? s.queue.length : null,
              active: _tab == i,
              compact: compact,
              onTap: () {
                setState(() => _tab = i);
                onPicked?.call();
              },
            ),
          const Spacer(),
          _Akun(state: s, compact: compact),
          const SizedBox(height: 14),
        ],
      );
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool compact;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.compact,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: active ? a(mint, 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? a(mint, 0.45) : Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(icon, size: 19, color: active ? mint : Colors.white54),
                  if (!compact) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: tx(label, 12.5,
                          c: active ? mint : Colors.white70,
                          w: active ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ],
                  if (badge != null && badge! > 0 && !compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: a(org, 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: tx('$badge', 10.5, c: org, w: FontWeight.w800),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Akun extends StatelessWidget {
  final AdminState state;
  final bool compact;
  const _Akun({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = state.me;
    if (p == null) return const SizedBox.shrink();

    final avatar = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: a(mint, 0.16),
        border: Border.all(color: a(mint, 0.5)),
      ),
      child: tx(p.initials, 12, c: mint, w: FontWeight.w800),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: compact
          ? Column(
              children: [
                avatar,
                const SizedBox(height: 4),
                IconButton(
                  tooltip: 'Keluar',
                  onPressed: () => _keluar(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white54),
                ),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx(p.username, 12, w: FontWeight.w700),
                      tx('Peran ${p.role.label}', 10.5, c: Colors.white54),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Keluar',
                  onPressed: () => _keluar(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white54),
                ),
              ],
            ),
    );
  }

  Future<void> _keluar(BuildContext context) async {
    await AuthService.instance.signOut();
    state.detach();
  }
}

/// Layar "Anda bukan admin" — murni kosmetik. Yang menegakkan adalah privilege,
/// RLS, dan app.resolve_admin() di setiap RPC.
class _BukanAdmin extends StatelessWidget {
  final AdminState state;
  const _BukanAdmin({required this.state});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: a(org, 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: org, size: 34),
                  const SizedBox(height: 12),
                  tx('Akun ini bukan admin', 17, w: FontWeight.w700),
                  const SizedBox(height: 8),
                  tx(
                    'Panel menolak menampilkan data, tetapi yang sebenarnya bekerja adalah '
                    'database: peran dibaca dari profiles.role, dan setiap RPC admin memanggil '
                    'app.resolve_admin().',
                    12,
                    c: Colors.white60,
                    al: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  AdminButton('Keluar dan masuk dengan akun admin',
                      tone: AdminTone.primary,
                      icon: Icons.logout_rounded,
                      onTap: () async {
                        await AuthService.instance.signOut();
                        state.detach();
                      }),
                ],
              ),
            ),
          ),
        ),
      );
}
