/// Profil pengguna.
///
/// Hanya tiga kolom yang boleh ditulis pemilik akun (`full_name`, `description`,
/// `avatar_path` — lihat grant di 0002 §3). Role dan keaktifan akun bukan hak
/// pengguna: itu tugas admin lewat sibal_set_user_role / sibal_set_user_active,
/// dan pergerakannya tercatat. Metrik "Uptime Lab" dari mockup tidak punya
/// sumber data, jadi diganti metrik nyata (Lab terhubung, unit terkelola,
/// pengajuan saya) — lihat PETA-REVISI-UI.md §7.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mock_ui.dart';
import '../widgets/status_chip.dart';
import '../widgets/sync_banner.dart';
import '../widgets/state_scope.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final pass = TextEditingController();
    final conf = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: tx('Ganti Password', 15, w: FontWeight.w700),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx('Password baru minimal 8 karakter.', 11.5, c: secText),
            const SizedBox(height: 14),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: dec('Password baru'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conf,
              obscureText: true,
              decoration: dec('Konfirmasi password'),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: tx('Batal', 13, c: Colors.white70, w: FontWeight.w600),
          ),
          TextButton(
            onPressed: () async {
              if (pass.text != conf.text) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: tx('Password tidak sama.', 12), backgroundColor: cardSurface),
                  );
                }
                return;
              }
              try {
                await AuthService.instance.updatePassword(pass.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: tx('Password berhasil diubah.', 12), backgroundColor: statusMint),
                  );
                }
              } on AuthFailure catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: tx(e.message, 12), backgroundColor: cardSurface),
                  );
                }
              }
            },
            child: tx('Simpan', 13, c: mint, w: FontWeight.w700),
          ),
        ],
      ),
    ).whenComplete(() {
      pass.dispose();
      conf.dispose();
    });
  }

  Future<void> _edit(BuildContext context, AppState s) async {
    final p = s.profile;
    if (p == null) return;
    final name = TextEditingController(text: p.fullName);
    final desc = TextEditingController(text: p.description);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tx('Edit Profil & Kredensial', 17, w: FontWeight.w700),
              const SizedBox(height: 4),
              tx(
                'Email login sintetis (@sibal.my.id) tidak bisa diubah dari sini.',
                11.5,
                c: secText,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: dec('Nama tampilan'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: desc,
                maxLines: 3,
                decoration: dec('Deskripsi singkat (opsional)'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              btn(
                'Simpan Perubahan',
                () async {
                  try {
                    await AuthService.instance.updateOwnProfile(
                      fullName: name.text,
                      description: desc.text,
                    );
                    s.attachProfile(await AuthService.instance
                        .requireProfile(AuthService.instance.userId!));
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on AuthFailure catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.message), backgroundColor: cardSurface),
                      );
                    }
                  }
                },
                icon: Icons.save_outlined,
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      desc.dispose();
    });

    if (saved == true && context.mounted) {
      snack(context, 'Profil diperbarui.');
    }
  }

  @override
  Widget build(BuildContext context) => stateScope(builder: (context, s) {
        final p = s.profile;
        if (p == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
            children: [
              Panel(tx('Sesi belum dimuat. Muat ulang aplikasi untuk masuk kembali.', 12.5,
                  c: Colors.white70)),
            ],
          );
        }

        final milikSaya = s.myReports;
        final terbuka = milikSaya.where((r) => r.status.terbuka).length;
        final labCount = s.labsWithData.length;
        final unitTerelola = s.pcs.length + s.items.fold<int>(0, (a, e) => a + e.qty);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            SyncBanner(s),

            // Kartu identitas.
            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(p: p),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tx(p.fullName, 16.5, w: FontWeight.w700),
                            const SizedBox(height: 3),
                            tx('@${p.username}', 11.5, c: secText),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                StatusPill(
                                  text: p.role.label,
                                  color: p.isAdmin ? lil : mint,
                                  icon: Icons.verified_outlined,
                                ),
                                if (!p.isActive) ...[
                                  const SizedBox(width: 8),
                                  const StatusPill(text: 'Nonaktif', color: redAlert),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  tx(
                    p.description.isEmpty
                        ? 'Belum diisi. Ceritakan peran Anda di lab — misalnya '
                            '"Pengelola Lab Jaringan, kelas XI."'
                        : p.description,
                    12.5,
                    c: p.description.isEmpty ? Colors.white38 : Colors.white70,
                  ),
                  const SizedBox(height: 14),
                  btn('Edit Profil & Akun', () => _edit(context, s), icon: Icons.edit_outlined),
                ],
              ),
            ),

            // Tiga metrik nyata (menggantikan Uptime Lab yang tak punya sumber).
            Panel(
              Row(
                children: [
                  Expanded(child: _StatCell(value: '$labCount', label: 'Lab Terhubung', color: mint)),
                  Expanded(child: _StatCell(value: '$unitTerelola', label: 'Unit Terkelola', color: yel)),
                  Expanded(child: _StatCell(value: '${milikSaya.length}', label: 'Pengajuan Saya', color: lil)),
                ],
              ),
            ),

            // Kesehatan daemon → connectivity + waktu sinkron terakhir.
            Panel(
              Row(
                children: [
                  MiniRing(
                    value: s.online ? 1.0 : 0.0,
                    color: s.online ? mint : org,
                    icon: Icons.dns_outlined,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tx('Status SIBAL Daemon', 13.5, w: FontWeight.w700),
                        const SizedBox(height: 4),
                        tx(s.online ? 'Sinkron Aktif' : 'Offline — data terakhir',
                            11.5, c: s.online ? statusMint : org, w: FontWeight.w600),
                        const SizedBox(height: 4),
                        tx(
                          s.lastSyncedAt == null
                              ? 'Belum pernah tersinkron'
                              : 'Terakhir diperbarui: ${fdt(s.lastSyncedAt!.toLocal())}',
                          11,
                          c: secText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx('Aktivitas saya', 13.5, w: FontWeight.w700),
                  const SizedBox(height: 12),
                  _StatRow(label: 'Total pengajuan', value: '${milikSaya.length}', color: mint),
                  _StatRow(label: 'Masih menunggu admin', value: '$terbuka', color: yel),
                  _StatRow(
                    label: 'Disetujui & selesai',
                    value: '${milikSaya.where((r) => r.status == ReportStatus.selesai).length}',
                    color: lil,
                  ),
                  _StatRow(
                    label: 'Ditolak / dibatalkan',
                    value: '${milikSaya.where((r) => r.status == ReportStatus.ditolak || r.status == ReportStatus.batal).length}',
                    color: Colors.white38,
                  ),
                ],
              ),
            ),

            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx('Data di perangkat ini', 13.5, w: FontWeight.w700),
                  const SizedBox(height: 8),
                  tx(
                    'Inventaris disimpan sebagai salinan baca-saja supaya tetap bisa dilihat '
                    'saat koneksi hilang. Pengajuan tidak pernah diantrekan di perangkat: '
                    'ia butuh database hidup.',
                    11.5,
                    c: secText,
                  ),
                  const SizedBox(height: 14),
                  btn('Segarkan data cloud', s.refresh, icon: Icons.sync_rounded, tonal: true),
                ],
              ),
            ),

            if (p.isAdmin)
              Panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, color: lil, size: 18),
                        const SizedBox(width: 8),
                        tx('Akun ini admin', 13.5, w: FontWeight.w700, c: lil),
                      ],
                    ),
                    const SizedBox(height: 8),
                    tx(
                      'Tindakan admin (memeriksa, menyetujui, menyesuaikan stok, broadcast) '
                      'disediakan di panel web pada paket yang sama — jalankan dengan '
                      '`-t lib/admin_main.dart`. Peran tetap ditegakkan di server.',
                      11.5,
                      c: secText,
                    ),
                  ],
                ),
                borderColor: a(lil, 0.3),
              ),

            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: mint, size: 18),
                      const SizedBox(width: 8),
                      tx('Keamanan', 13.5, w: FontWeight.w700, c: mint),
                    ],
                  ),
                  const SizedBox(height: 8),
                  tx(
                    'Password akun Anda. Disarankan minimal 8 karakter dengan kombinasi '
                    'huruf dan angka.',
                    11.5,
                    c: secText,
                  ),
                  const SizedBox(height: 14),
                  btn(
                    'Ganti Password',
                    () => _changePassword(context),
                    icon: Icons.key_rounded,
                    tonal: true,
                  ),
                ],
              ),
            ),

            Panel(
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tx('Keluar', 14, w: FontWeight.w700),
                        const SizedBox(height: 4),
                        tx('Salinan data di perangkat ini ikut dihapus.', 11, c: secText),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: tx('Yakin ingin melakukan Logout?', 15, w: FontWeight.w700),
                          content: tx(
                            'Salinan data di perangkat ini ikut dihapus.',
                            12,
                            c: secText,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: tx('Batal', 13, c: Colors.white70, w: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: tx('Logout', 13, c: redAlert, w: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await s.signOut();
                        if (context.mounted) snack(context, 'Anda keluar. Sampai jumpa.');
                      }
                    },
                    child: tx('Keluar', 13, c: redAlert, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        );
      });
}

class _Avatar extends StatelessWidget {
  final dynamic p;
  const _Avatar({required this.p});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [mint, yel]),
              boxShadow: [BoxShadow(color: mint.withAlpha(40), blurRadius: 12)],
            ),
            child: Center(child: tx(p.initials, 20, c: bg, w: FontWeight.w800)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusMint,
                border: Border.all(color: card, width: 2.5),
              ),
            ),
          ),
        ],
      );
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          tx(value, 20, c: color, w: FontWeight.w700),
          const SizedBox(height: 3),
          tx(label, 10.5, c: secText, al: TextAlign.center),
        ],
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 9),
            Expanded(child: tx(label, 12, c: Colors.white70)),
            tx(value, 14, w: FontWeight.w700),
          ],
        ),
      );
}
