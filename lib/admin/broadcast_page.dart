/// Tab Broadcast — pengumuman untuk aplikasi mobile.
///
/// `sibal_upsert_announcement` selalu menerima judul dan isi (bukan konvensi
/// `null`/`''` seperti kolom deskriptif aset), jadi form selalu mengirim keduanya.
/// Batas tayang wajib sesudah waktu tayang; itu constraint database
/// (`ann_window_sane`), bukan aturan UI.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/people.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  bool _hanyaTayang = false;

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          final daftar = s.announcements
              .where((ann) => !_hanyaTayang || ann.masihTayang())
              .toList();

          return AdminPage(
            title: 'Broadcast',
            subtitle: '${s.announcements.length} pengumuman · '
                '${s.announcements.where((ann) => ann.masihTayang()).length} sedang tayang di mobile',
            actions: [
              AdminButton(
                _hanyaTayang ? 'Tampilkan semua' : 'Hanya yang tayang',
                icon: Icons.filter_alt_outlined,
                onTap: () => setState(() => _hanyaTayang = !_hanyaTayang),
              ),
              AdminButton('Pengumuman baru',
                  icon: Icons.add_rounded,
                  tone: AdminTone.primary,
                  onTap: () => _edit(context, s, null)),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: daftar.isEmpty
                      ? const AdminEmpty('Belum ada pengumuman.', icon: Icons.campaign_rounded)
                      : SingleChildScrollView(
                          child: AdminTable(
                            headers: const [
                              'Judul', 'Level', 'Keadaan', 'Tayang sejak', 'Batas tayang', 'Isi', 'Aksi',
                            ],
                            rows: [for (final ann in daftar) _row(context, s, ann)],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );

  List<Widget> _row(BuildContext context, AdminState s, Announcement ann) => [
        AdminTable.cell(ann.title, weight: FontWeight.w700, maxLines: 2),
        StatusPill(text: ann.level.label, color: _levelColor(ann.level)),
        StatusPill(text: _keadaan(ann), color: _keadaanColor(ann)),
        AdminTable.muted(ann.publishedAt == null ? 'belum' : wib(ann.publishedAt)),
        AdminTable.muted(ann.expiresAt == null ? 'tanpa batas' : wib(ann.expiresAt)),
        AdminTable.cell(ann.body, maxLines: 2),
        _aksiMenu(context, s, ann),
      ];

  Widget _aksiMenu(BuildContext context, AdminState s, Announcement ann) =>
      PopupMenuButton<String>(
        tooltip: 'Aksi',
        padding: EdgeInsets.zero,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: a(mint, 0.12)),
        ),
        onSelected: (v) {
          if (v == 'edit') {
            _edit(context, s, ann);
          } else if (v == 'toggle') {
            _toggle(context, s, ann);
          } else if (v == 'hapus') {
            _hapus(context, s, ann);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 16, color: mint),
                const SizedBox(width: 10),
                tx('Edit', 12.5),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  ann.isPublished ? Icons.unpublished_rounded : Icons.publish_rounded,
                  size: 16,
                  color: ann.isPublished ? org : mint,
                ),
                const SizedBox(width: 10),
                tx(ann.isPublished ? 'Tarik dari Beranda' : 'Terbitkan', 12.5),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'hapus',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, size: 16, color: redAlert),
                const SizedBox(width: 10),
                tx('Hapus', 12.5),
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

  static String _keadaan(Announcement ann) {
    if (!ann.isPublished) return 'Draf';
    if (ann.masihTayang()) return 'Tayang';
    if (ann.publishedAt != null && DateTime.now().toUtc().isBefore(ann.publishedAt!)) return 'Jadual';
    return 'Kadaluarsa';
  }

  static Color _keadaanColor(Announcement ann) => switch (_keadaan(ann)) {
        'Tayang' => mint,
        'Draf' => Colors.white38,
        'Jadual' => yel,
        _ => org,
      };

  static Color _levelColor(AnnouncementLevel l) => switch (l) {
        AnnouncementLevel.info => lil,
        AnnouncementLevel.peringatan => yel,
        AnnouncementLevel.penting => org,
      };

  Future<void> _edit(BuildContext context, AdminState s, Announcement? ann) => adminFormDialog(
        context,
        title: ann == null ? 'Pengumuman baru' : 'Ubah pengumuman',
        subtitle: 'Tampil di Beranda mobile selama masih dalam jendela tayang.',
        submitLabel: 'Simpan',
        init: ann == null
            ? null
            : (f) {
                f
                  ..set('id', ann.id)
                  ..set('level', ann.level.wire)
                  ..set('pub', ann.isPublished)
                  ..set('exp', ann.expiresAt);
                f.c('title', initial: ann.title);
                f.c('body', initial: ann.body);
              },
        build: (ctx, f) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormRow(
                label: 'Judul (3–120 karakter)',
                field: AdminTextField(controller: f.c('title'), placeholder: 'Mis. Lab tutup Jumat siang'),
              ),
              FormRow(
                label: 'Isi (maksimal 2000 karakter)',
                field: AdminTextField(controller: f.c('body'), maxLines: 5),
              ),
              FormRow(
                label: 'Level',
                field: AdminDropdown<String>(
                  value: f.sel<String>('level') ?? AnnouncementLevel.info.wire,
                  items: [for (final l in AnnouncementLevel.values) l.wire],
                  labelOf: (w) => AnnouncementLevel.parseOr(w).label,
                  onChanged: (v) => f.pick('level', v ?? AnnouncementLevel.info.wire),
                ),
              ),
              FormRow(
                label: 'Langsung terbit',
                hint: 'Bila dimatikan, pengumuman tersimpan sebagai draf dan tidak tampil di mobile.',
                field: _Switch(
                  value: f.sel<bool>('pub') ?? true,
                  onChanged: (v) => f.pick('pub', v),
                ),
              ),
              FormRow(
                label: 'Batas tayang (opsional)',
                hint: 'Tanggal dianggap sampai 23:59 waktu perangkat ini. Harus sesudah waktu tayang.',
                field: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1410),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: a(mint, 0.12)),
                        ),
                        child: tx(_tanggalLabel(f.sel<DateTime>('exp')), 12.5,
                            c: f.sel<DateTime>('exp') == null ? Colors.white38 : Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AdminButton('Pilih', dense: true, onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: f.sel<DateTime>('exp') ?? now.add(const Duration(days: 7)),
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        f.pick('exp', DateTime(picked.year, picked.month, picked.day, 23, 59));
                      }
                    }),
                    const SizedBox(width: 6),
                    AdminButton('Bersihkan', dense: true, onTap: () => f.pick<DateTime>('exp', null)),
                  ],
                ),
              ),
            ],
          ),
        submit: (f) {
          final title = f.v('title').trim();
          final body = f.v('body').trim();
          if (title.length < 3) {
            snack(context, 'Judul minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          if (title.length > 120) {
            snack(context, 'Judul maksimal 120 karakter.', isError: true);
            return Future.value(false);
          }
          if (body.isEmpty) {
            snack(context, 'Isi pengumuman wajib diisi.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: ann == null ? 'Pengumuman dibuat.' : 'Pengumuman diperbarui.',
            setBusy: f.setBusy,
            action: () async {
              await s.saveAnnouncement(
                id: f.sel<String>('id'),
                title: title,
                body: body,
                level: AnnouncementLevel.parseOr(f.sel<String>('level')),
                isPublished: f.sel<bool>('pub') ?? true,
                expiresAt: f.sel<DateTime>('exp'),
              );
            },
          );
        },
      );

  Future<void> _toggle(BuildContext context, AdminState s, Announcement ann) => runAdminAction(
        context,
        successMessage: ann.isPublished ? 'Pengumuman ditarik dari Beranda.' : 'Pengumuman diterbitkan.',
        setBusy: (_) {},
        action: () => s.saveAnnouncement(
          id: ann.id,
          title: ann.title,
          body: ann.body,
          level: ann.level,
          isPublished: !ann.isPublished,
          expiresAt: ann.expiresAt,
        ),
      );

  Future<void> _hapus(BuildContext context, AdminState s, Announcement ann) async {
    final yakin = await confirmDialog(
      context,
      title: 'Hapus pengumuman?',
      message: '"${ann.title}" hilang permanen dari daftar. Riwayat tiket dan aset tidak tersentuh.',
      okLabel: 'Hapus',
      tone: AdminTone.danger,
    );
    if (!yakin || !context.mounted) return;
    await runAdminAction(
      context,
      successMessage: 'Pengumuman dihapus.',
      setBusy: (_) {},
      action: () => s.deleteAnnouncement(ann.id),
    );
  }
}

String _tanggalLabel(DateTime? d) =>
    d == null ? 'Tanpa batas tayang' : '${fd(d)} · ${ft(d)}';

class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Switch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: bg,
        activeTrackColor: mint,
        inactiveTrackColor: cardSurface,
        inactiveThumbColor: Colors.white38,
      );
}
