/// Tab Riwayat — pekerjaan pemeliharaan.
///
/// Menutup pekerjaan adalah `sibal_complete_maintenance`: satu transaksi yang
/// menandai riwayat selesai, memulihkan status aset, dan (untuk barang) memindahkan
/// stok dengan **delta** — berbeda dari form barang di tab Aset yang menerima
/// angka absolut. Beda bentuk angka ini disengaja dan harus dijelaskan di UI,
/// karena di situlah stok bisa bergerak dua kali kalau admin mengisi keduanya.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/tickets.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

enum _Lihat { terbuka, semua, selesai }

class AdminHistoryPage extends StatefulWidget {
  const AdminHistoryPage({super.key});

  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage> {
  _Lihat _lihat = _Lihat.terbuka;
  String? _lab;

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          final daftar = s.jobs
              .where((j) => switch (_lihat) {
                    _Lihat.terbuka => j.status.terbuka,
                    _Lihat.selesai => j.status == MaintenanceStatus.selesai,
                    _Lihat.semua => true,
                  })
              .where((j) => _lab == null || j.labId == _lab)
              .toList();

          return AdminPage(
            title: 'Riwayat pemeliharaan',
            subtitle: '${s.pekerjaanTerbukaCount} Tugas yang tersedia· '
                '${s.jobs.length} baris dimuat',
            actions: [
              AdminButton('Catat pemeliharaan',
                  icon: Icons.add_rounded,
                  tone: AdminTone.primary,
                  onTap: () => _create(context, s)),
              AdminButton('Muat ulang',
                  icon: Icons.refresh_rounded,
                  tone: AdminTone.primary,
                  onTap: s.state == AdminLoadState.loading ? null : s.refresh),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in _Lihat.values)
                      _Chip(
                        label: switch (l) {
                          _Lihat.terbuka => 'Terbuka',
                          _Lihat.selesai => 'Selesai',
                          _Lihat.semua => 'Semua',
                        },
                        on: _lihat == l,
                        onTap: () => setState(() => _lihat = l),
                      ),
                    const SizedBox(width: 6),
                    _Chip(label: 'Semua Lab', on: _lab == null, onTap: () => setState(() => _lab = null)),
                    for (final lab in s.labs)
                      _Chip(
                        label: lab.code,
                        on: _lab == lab.id,
                        onTap: () => setState(() => _lab = _lab == lab.id ? null : lab.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: daftar.isEmpty
                      ? const AdminEmpty('Tidak ada pekerjaan pada pilihan ini.',
                          icon: Icons.construction_rounded)
                      : SingleChildScrollView(
                          child: AdminTable(
                            headers: const [
                              'Tanggal', 'Target', 'Lab', 'Kategori', 'Status',
                              'Petugas', 'Stok', 'Tindakan', 'Tiket', 'Aksi',
                            ],
                            rows: [for (final j in daftar) _row(context, s, j)],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );

  List<Widget> _row(BuildContext context, AdminState s, MaintenanceJob j) {
    final tiket = j.reportId == null ? null : _cariTiket(s, j.reportId!);
    return [
      AdminTable.muted(j.maintenanceDate == null ? '—' : fd(j.maintenanceDate!)),
      AdminTable.cell(j.assetLabel, weight: FontWeight.w700),
      AdminTable.muted(j.labName ?? s.labLabel(j.labId)),
      AdminTable.muted(j.category.label),
      StatusPill(text: j.status.label, color: jobColor(j.status)),
      AdminTable.muted(j.performedByName),
      AdminTable.cell(
        j.stokBergerak ? (j.qtyDelta > 0 ? '+${j.qtyDelta}' : '${j.qtyDelta}') : '—',
        color: j.stokBergerak ? (j.qtyDelta > 0 ? mint : org) : Colors.white38,
      ),
      AdminTable.cell(j.notes == null ? j.actionTaken : '${j.actionTaken}\n${j.notes}', maxLines: 2),
      AdminTable.muted(tiket == null ? 'inspeksi rutin' : shortId(tiket.id).toUpperCase()),
      AdminActionMenu(
        onSelected: (v) => switch (v) {
          'selesai' => _complete(context, s, j),
          'buka' => _reopen(context, s, tiket!),
          'ubah' => _edit(context, s, j),
          'hapus' => _delete(context, s, j),
          _ => _detail(context, j),
        },
        items: [
          adminMenuItem('detail', 'Detail', Icons.info_outline_rounded, Colors.white70),
          if (j.status.terbuka)
            adminMenuItem('selesai', 'Selesaikan', Icons.check_circle_outline_rounded, mint),
          if (tiket != null && !tiket.status.terbuka)
            adminMenuItem('buka', 'Buka lagi tiket', Icons.replay_rounded, org),
          adminMenuItem('ubah', 'Ubah', Icons.edit_outlined, lil),
          if (j.reportId == null && !j.stokBergerak)
            adminMenuItem('hapus', 'Hapus', Icons.delete_outline_rounded, redAlert),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // CRUD riwayat mandiri (0009) — pemeliharaan/perbaikan di luar pengajuan.
  // ---------------------------------------------------------------------------

  Future<void> _create(BuildContext context, AdminState s) => adminFormDialog(
        context,
        title: 'Catat pemeliharaan',
        subtitle: 'Pekerjaan di luar pengajuan: inspeksi rutin, perbaikan langsung, '
            'atau stok yang masuk/keluar tanpa tiket.',
        submitLabel: 'Simpan riwayat',
        build: (ctx, f) {
          final jenis = f.sel<String>('jenis') ?? 'pc';
          final barang = jenis == 'barang';
          final selesai = f.sel<bool>('selesai') ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormRow(
                label: 'Jenis target',
                field: AdminDropdown<String>(
                  value: jenis,
                  items: const ['pc', 'barang'],
                  labelOf: (w) => w == 'pc' ? 'PC' : 'Barang pendukung',
                  onChanged: (v) {
                    f.pick('jenis', v ?? 'pc');
                    f.pick('target', null);
                  },
                ),
              ),
              FormRow(
                label: 'Target (wajib)',
                field: AdminDropdown<String>(
                  value: f.sel<String>('target'),
                  items: barang
                      ? [for (final i in s.items) i.id]
                      : [for (final p in s.pcs) p.id],
                  hint: 'Pilih target',
                  labelOf: (id) {
                    if (barang) {
                      for (final i in s.items) {
                        if (i.id == id) return '${i.name} · ${s.labLabel(i.labId)}';
                      }
                    } else {
                      for (final p in s.pcs) {
                        if (p.id == id) return '${p.codename} · ${s.labLabel(p.labId)}';
                      }
                    }
                    return id;
                  },
                  onChanged: (v) => f.pick('target', v),
                ),
              ),
              FormRow(
                label: 'Kategori pekerjaan',
                field: AdminDropdown<String>(
                  value: f.sel<String>('kind') ?? MaintenanceKind.inspeksi.wire,
                  items: [for (final k in MaintenanceKind.values) k.wire],
                  labelOf: (w) => MaintenanceKind.parseOr(w).label,
                  onChanged: (v) => f.pick('kind', v ?? MaintenanceKind.inspeksi.wire),
                ),
              ),
              FormRow(
                label: 'Tindakan yang dikerjakan (wajib)',
                hint: 'Minimal 3 karakter; tercatat sebagai action_taken.',
                field: AdminTextField(
                    controller: f.c('action'),
                    maxLines: 3,
                    placeholder: 'Mis. bersihkan debu dan uji POST 10 menit'),
              ),
              FormRow(
                label: 'Catatan (opsional)',
                field: AdminTextField(controller: f.c('notes'), maxLines: 3),
              ),
              FormRow(
                label: 'Tanggal pengerjaan (WIB)',
                hint: 'Format YYYY-MM-DD. Kosongkan berarti hari ini.',
                field: AdminTextField(
                    controller: f.c('tanggal', initial: _hariIni()),
                    placeholder: '2026-11-18'),
              ),
              FormRow(
                label: 'Langsung tandai selesai',
                hint: selesai
                    ? 'Pekerjaan tercatat selesai sekarang; delta stok di bawah ikut bergerak sekarang.'
                    : 'Pekerjaan terbuka dulu (berjalan); stok digeser saat ditutup lewat Selesaikan.',
                field: _Switch(
                  value: selesai,
                  onChanged: (v) => f.pick('selesai', v),
                ),
              ),
              if (barang && selesai) ...[
                FormRow(
                  label: 'Delta stok (opsional, boleh negatif)',
                  hint: 'Bentuk delta: + masuk / - keluar. Wajib beralasan.',
                  field: AdminTextField(
                    controller: f.c('delta', initial: '0'),
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                  ),
                ),
                FormRow(
                  label: 'Alasan perubahan stok',
                  hint: 'Wajib bila delta bukan 0; masuk ke notes riwayat.',
                  field: AdminTextField(controller: f.c('reason'), maxLines: 2),
                ),
              ],
              FormRow(
                label: 'Petugas pelaksana (opsional)',
                hint: 'Kosong berarti Anda sendiri.',
                field: AdminDropdown<String>(
                  value: f.sel<String>('petugas'),
                  items: [for (final p in s.petugas) p.id],
                  hint: 'Saya sendiri',
                  labelOf: (id) {
                    for (final p in s.petugas) {
                      if (p.id == id) return '${p.fullName} · ${p.role.label}';
                    }
                    return id;
                  },
                  onChanged: (v) => f.pick('petugas', v),
                ),
              ),
            ],
          );
        },
        submit: (f) {
          final jenis = f.sel<String>('jenis') ?? 'pc';
          final barang = jenis == 'barang';
          final selesai = f.sel<bool>('selesai') ?? false;
          final target = f.sel<String>('target');
          if (target == null) {
            snack(context, 'Pilih target dulu.', isError: true);
            return Future.value(false);
          }
          if (f.v('action').trim().length < 3) {
            snack(context, 'Tindakan minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          final tanggal = f.v('tanggal').trim().isEmpty
              ? null
              : DateTime.tryParse(f.v('tanggal').trim());
          if (f.v('tanggal').trim().isNotEmpty && tanggal == null) {
            snack(context, 'Tanggal harus format YYYY-MM-DD.', isError: true);
            return Future.value(false);
          }
          final delta = barang && selesai ? f.intV('delta') : 0;
          if (delta != 0 && f.v('reason').trim().length < 3) {
            snack(context, 'Alasan wajib diisi untuk perubahan stok.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: selesai ? 'Pemeliharaan tercatat selesai.' : 'Pekerjaan terbuka dicatat.',
            setBusy: f.setBusy,
            action: () => s.createMaintenance(
              pcId: barang ? null : target,
              itemId: barang ? target : null,
              kind: MaintenanceKind.parseOr(f.sel<String>('kind')),
              actionTaken: f.v('action').trim(),
              notes: f.nullable('notes'),
              date: tanggal,
              selesai: selesai,
              performedBy: f.sel<String>('petugas'),
              qtyDelta: delta,
              reason: f.nullable('reason'),
            ),
          );
        },
      );

  Future<void> _edit(BuildContext context, AdminState s, MaintenanceJob j) => adminFormDialog(
        context,
        title: 'Ubah riwayat ${shortId(j.id)}',
        subtitle: 'Koreksi catatan pekerjaan. Status, target, dan stok tidak bisa '
            'diubah di sini — itu jalur penutupan dan buku stok.',
        submitLabel: 'Simpan perubahan',
        build: (ctx, f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormRow(
              label: 'Kategori pekerjaan',
              field: AdminDropdown<String>(
                value: f.sel<String>('kind') ?? j.category.wire,
                items: [for (final k in MaintenanceKind.values) k.wire],
                labelOf: (w) => MaintenanceKind.parseOr(w).label,
                onChanged: (v) => f.pick('kind', v ?? j.category.wire),
              ),
            ),
            FormRow(
              label: 'Tindakan (wajib)',
              field: AdminTextField(
                  controller: f.c('action', initial: j.actionTaken), maxLines: 3),
            ),
            FormRow(
              label: 'Catatan',
              hint: 'Kosongkan untuk menghapus catatan.',
              field: AdminTextField(
                  controller: f.c('notes', initial: j.notes ?? ''), maxLines: 3),
            ),
            FormRow(
              label: 'Tanggal pengerjaan (WIB)',
              field: AdminTextField(
                controller: f.c('tanggal',
                    initial: j.maintenanceDate == null ? '' : _fmtTanggal(j.maintenanceDate!)),
                placeholder: '2026-11-18',
              ),
            ),
          ],
        ),
        submit: (f) {
          final action = f.v('action').trim();
          if (action.length < 3) {
            snack(context, 'Tindakan minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          final teksTanggal = f.v('tanggal').trim();
          final tanggal = teksTanggal.isEmpty ? null : DateTime.tryParse(teksTanggal);
          if (teksTanggal.isNotEmpty && tanggal == null) {
            snack(context, 'Tanggal harus format YYYY-MM-DD.', isError: true);
            return Future.value(false);
          }
          final kind = MaintenanceKind.parseOr(f.sel<String>('kind'));
          return runAdminAction(
            context,
            successMessage: 'Riwayat diperbarui.',
            setBusy: f.setBusy,
            action: () => s.updateMaintenance(
              jobId: j.id,
              kind: kind == j.category ? null : kind,
              actionTaken: textFieldValue(j.actionTaken, action),
              notes: textFieldValue(j.notes, f.v('notes')),
              date: tanggal == j.maintenanceDate ? null : tanggal,
            ),
          );
        },
      );

  Future<void> _delete(BuildContext context, AdminState s, MaintenanceJob j) async {
    final ya = await confirmDialog(
      context,
      title: 'Hapus riwayat ${shortId(j.id)}?',
      message: 'Catatan mandiri tanpa gerakan stok akan dihapus permanen. '
          'Riwayat terkait pengajuan atau yang menggeser stok tidak bisa dihapus.',
      okLabel: 'Hapus',
      tone: AdminTone.danger,
    );
    if (ya != true) return;
    if (!context.mounted) return;
    await runAdminAction(
      context,
      successMessage: 'Riwayat dihapus.',
      setBusy: (_) {},
      action: () => s.deleteMaintenance(j.id),
    );
  }

  static String _fmtTanggal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _hariIni() =>
      _fmtTanggal(DateTime.now().toUtc().add(const Duration(hours: 7)));

  Report? _cariTiket(AdminState s, String id) {
    for (final r in s.recent) {
      if (r.id == id) return r;
    }
    for (final r in s.queue) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _detail(BuildContext context, MaintenanceJob j) => adminDialog<void>(
        context,
        title: 'Pekerjaan ${shortId(j.id)}',
        subtitle: '${j.assetLabel} · ${j.category.label} · ${j.status.label}',
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx('Tindakan', 11.5, c: Colors.white70, w: FontWeight.w700),
            tx(j.actionTaken, 12.5),
            if ((j.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              tx('Catatan', 11.5, c: Colors.white70, w: FontWeight.w700),
              tx(j.notes!, 12.5, c: Colors.white70),
            ],
            const SizedBox(height: 10),
            tx('Pelaksana: ${j.performedByName}', 11.5, c: Colors.white54),
            tx('Tanggal: ${_tanggal(j)}', 11.5, c: Colors.white54),
            tx('Selesai pada: ${j.completedAt == null ? "-" : wib(j.completedAt)}', 11.5,
                c: Colors.white54),
          ],
        ),
      );

  static String _tanggal(MaintenanceJob j) {
    final d = j.maintenanceDate;
    return d == null ? '-' : fd(d);
  }

  Future<void> _complete(BuildContext context, AdminState s, MaintenanceJob j) {
    final barang = j.pcId == null && j.supportingItemId != null;
    final pilihan = barang
        ? const [AssetStatus.baik, AssetStatus.diperiksa, AssetStatus.rusak, AssetStatus.habis, AssetStatus.purnatugas]
        : const [AssetStatus.baik, AssetStatus.diperiksa, AssetStatus.rusak, AssetStatus.purnatugas];

    return adminFormDialog(
      context,
      title: 'Selesaikan pekerjaan ${shortId(j.id)}',
      subtitle: 'Riwayat ditutup, aset dipulihkan, dan tiket menjadi selesai — satu transaksi.',
      submitLabel: 'Tandai selesai',
      build: (ctx, f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormRow(
            label: 'Status aset setelah selesai',
            hint: 'Biasanya "baik". Pilih purnatugas bila unit berhenti dipakai, atau habis bila '
                'stok barang benar-benar kosong.',
            field: AdminDropdown<String>(
              value: f.sel<String>('outcome') ?? AssetStatus.baik.wire,
              items: [for (final st in pilihan) st.wire],
              labelOf: (w) => AssetStatus.tryParse(w)?.label ?? w,
              onChanged: (v) => f.pick('outcome', v ?? AssetStatus.baik.wire),
            ),
          ),
          FormRow(
            label: 'Catatan hasil (opsional)',
            field: AdminTextField(
                controller: f.c('notes'), maxLines: 3, placeholder: 'Mis. PSU diganti, uji beban 30 menit normal'),
          ),
          if (barang)
            FormRow(
              label: 'Delta stok saat penutupan (opsional)',
              hint: 'BENTUK DELTA (+ masuk / - keluar), bukan angka absolut. Isi 0 kalau stok sudah '
                  'digeser saat approve — mengisi dua kali membuatnya bergerak dua kali.',
              field: AdminTextField(
                controller: f.c('delta', initial: '0'),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
              ),
            ),
        ],
      ),
      submit: (f) => runAdminAction(
        context,
        successMessage: 'Pekerjaan ${shortId(j.id)} selesai.',
        setBusy: f.setBusy,
        action: () => s.complete(
          jobId: j.id,
          notes: f.nullable('notes'),
          outcome: AssetStatus.tryParse(f.sel<String>('outcome') ?? 'baik') ?? AssetStatus.baik,
          qtyDelta: barang ? f.intV('delta') : 0,
        ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, AdminState s, Report r) => adminFormDialog(
        context,
        title: 'Buka lagi tiket ${shortId(r.id)}',
        subtitle: 'Tiket kembali ke antrean dan aset masuk lagi ke status dalam pengajuan.',
        submitLabel: 'Buka kembali',
        tone: AdminTone.warn,
        build: (ctx, f) => FormRow(
          label: 'Alasan membuka kembali (wajib)',
          field: AdminTextField(controller: f.c('reason'), maxLines: 3, placeholder: 'Mis. gejala muncul lagi'),
        ),
        submit: (f) {
          if (f.v('reason').trim().length < 3) {
            snack(context, 'Alasan minimal 3 karakter.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: 'Tiket dibuka kembali.',
            setBusy: f.setBusy,
            action: () => s.reopen(reportId: r.id, reason: f.v('reason').trim()),
          );
        },
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? yel : card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? yel : cardBorder),
          ),
          child: tx(label, 11.5, c: on ? bg : Colors.white70, w: FontWeight.w700),
        ),
      );
}

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
