/// Tab Pengguna — peran dan keaktifan akun.
///
/// Yang bisa dilakukan panel hanya dua hal: `sibal_set_user_role` dan
/// `sibal_set_user_active`. Membuat akun, mereset password, dan menghapus akun
/// sengaja TIDAK ada di sini: ketiganya menuntut `service_role`, dan apa pun
/// yang masuk bundle `flutter build web` bisa dibaca siapa pun.
///
/// Daftar dibaca dari `public.profiles` (policy `profiles_read` memakai
/// `using (true)`), jadi kolom `last_sign_in_at` dan bentuk email asli memang
/// tidak tersedia — bukan bug, konsekuensi yang diterima.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/people.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _cari = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _cari = _search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          final q = _cari.trim().toLowerCase();
          final daftar = s.profiles
              .where((p) => q.isEmpty ||
                  p.username.toLowerCase().contains(q) ||
                  p.fullName.toLowerCase().contains(q))
              .toList();
          final sendiri = s.me?.id;

          return AdminPage(
            title: 'Pengguna',
            subtitle: '${s.profiles.length} akun · ${s.akunAdmin} admin · '
                'Fungsi CRUD kelola User',
            actions: [
              SizedBox(
                width: 240,
                child: AdminTextField(controller: _search, placeholder: 'cari username / nama'),
              ),
              AdminButton('Muat ulang',
                  icon: Icons.refresh_rounded,
                  tone: AdminTone.primary,
                  onTap: s.state == AdminLoadState.loading ? null : s.refresh),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: a(lil, 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: lil),
                      const SizedBox(width: 10),
                      Expanded(
                        child: tx(
                          'Login memakai username, bukan email: klien memetakan ke '
                          'username@sibal.my.id. Admin pertama diangkat lewat SQL Editor; '
                          'sesudah itu tab inilah yang mengangkat admin lain.',
                          11.5,
                          c: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: daftar.isEmpty
                      ? const AdminEmpty('Tidak ada akun yang cocok.', icon: Icons.group_outlined)
                      : SingleChildScrollView(
                          child: AdminTable(
                            headers: const ['Username', 'Nama', 'Peran', 'Keadaan', 'Deskripsi', 'Dibuat', 'Aksi'],
                            rows: [for (final p in daftar) _row(context, s, p, sendiri)],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );

  List<Widget> _row(BuildContext context, AdminState s, Profile p, String? sendiri) {
    final saya = p.id == sendiri;
    return [
      AdminTable.cell(p.username, weight: FontWeight.w700, color: mint),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminTable.cell(p.fullName),
          if (saya) tx('Anda', 10, c: Colors.white38),
        ],
      ),
      StatusPill(
        text: p.role.label,
        color: p.role == AppRole.admin ? lil : Colors.white38,
        icon: p.role == AppRole.admin ? Icons.shield_moon_outlined : Icons.person_outline_rounded,
      ),
      StatusPill(
        text: p.isActive ? 'Aktif' : 'Nonaktif',
        color: p.isActive ? mint : redAlert,
      ),
      AdminTable.cell(p.description.isEmpty ? '—' : p.description, maxLines: 2),
      AdminTable.muted(p.createdAt == null ? '—' : fd(p.createdAt!.toLocal())),
      _aksiMenu(context, s, p, saya),
    ];
  }

  Widget _aksiMenu(BuildContext context, AdminState s, Profile p, bool saya) =>
      PopupMenuButton<String>(
        tooltip: 'Aksi',
        padding: EdgeInsets.zero,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: a(mint, 0.12)),
        ),
        onSelected: (v) {
          if (saya) return;
          if (v == 'role') {
            _role(context, s, p);
          } else if (v == 'active') {
            _active(context, s, p);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'role',
            enabled: !saya,
            child: Row(
              children: [
                Icon(
                  p.isAdmin ? Icons.person_outline_rounded : Icons.shield_moon_outlined,
                  size: 16,
                  color: p.isAdmin ? org : lil,
                ),
                const SizedBox(width: 10),
                tx(p.isAdmin ? 'Turunkan peran' : 'Jadikan admin', 12.5),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'active',
            enabled: !saya,
            child: Row(
              children: [
                Icon(
                  p.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: p.isActive ? redAlert : mint,
                ),
                const SizedBox(width: 10),
                tx(p.isActive ? 'Nonaktifkan' : 'Aktifkan', 12.5),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: cardBorder),
          ),
          child: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white70),
        ),
      );

  Future<void> _role(BuildContext context, AdminState s, Profile p) async {
    final naik = !p.isAdmin;
    final yakin = await confirmDialog(
      context,
      title: naik ? 'Angkat ${p.username} jadi admin?' : 'Turunkan ${p.username} dari admin?',
      message: naik
          ? 'Yang bersangkutan akan bisa menyetujui pengajuan, mengubah aset, dan mengangkat admin lain.'
          : 'Akses panelnya berhenti pada panggilan RPC berikutnya; datanya tidak berubah.',
      okLabel: naik ? 'Angkat' : 'Turunkan',
      tone: naik ? AdminTone.primary : AdminTone.warn,
    );
    if (!yakin || !context.mounted) return;
    await runAdminAction(
      context,
      successMessage: 'Peran ${p.username} menjadi ${naik ? "admin" : "user"}.',
      setBusy: (_) {},
      action: () => s.setRole(userId: p.id, role: naik ? AppRole.admin : AppRole.user),
    );
  }

  Future<void> _active(BuildContext context, AdminState s, Profile p) async {
    final matikan = p.isActive;
    final yakin = await confirmDialog(
      context,
      title: matikan ? 'Nonaktifkan ${p.username}?' : 'Aktifkan kembali ${p.username}?',
      message: matikan
          ? 'Semua RPC admin dan pembacaan data menolak akun nonaktif, meski sesinya masih ada. '
              'Akun ini tidak bisa dinonaktifkan oleh dirinya sendiri — termasuk Anda.'
          : 'Akun bisa login dan mengajukan kerusakan lagi.',
      okLabel: matikan ? 'Nonaktifkan' : 'Aktifkan',
      tone: matikan ? AdminTone.danger : AdminTone.primary,
    );
    if (!yakin || !context.mounted) return;
    await runAdminAction(
      context,
      successMessage: 'Akun ${p.username} ${matikan ? "dinonaktifkan" : "diaktifkan"}.',
      setBusy: (_) {},
      action: () => s.setActive(userId: p.id, isActive: !matikan),
    );
  }
}
