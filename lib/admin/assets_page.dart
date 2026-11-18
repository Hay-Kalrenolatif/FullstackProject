/// Tab Aset — PC dan barang pendukung.
///
/// Dua jalur tulis yang berbeda dan sengaja tidak dicampur:
///   * **Koreksi kolom deskriptif** → `sibal_update_pc` / `sibal_update_supporting_item`.
///     Mengikuti konvensi `app.text_field`: tidak diubah = `null`, dikosongkan = `''`.
///   * **Perubahan status** → `sibal_set_asset_status` dengan alasan, dan hanya
///     status yang boleh dipilih (bukan teks bebas, dan bukan `dalam_pengajuan`
///     yang merupakan wilayah tiket).
///
/// Stok barang bergerak lewat field `qty` di form barang — angkanya **absolut**
/// (bukan delta), wajib disertai alasan, dan server membukukannya sebagai baris
/// riwayat `pelengkapan`/`purnatugas`.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

enum _Jenis { pc, barang }

class AdminAssetsPage extends StatefulWidget {
  const AdminAssetsPage({super.key});

  @override
  State<AdminAssetsPage> createState() => _AdminAssetsPageState();
}

class _AdminAssetsPageState extends State<AdminAssetsPage> {
  _Jenis _jenis = _Jenis.pc;
  String? _lab;
  bool _arsip = false;
  final _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cari.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => adminScope(
        builder: (context, s) {
          final pcs = _filterPc(s);
          final items = _filterItem(s);

          return AdminPage(
            title: 'Aset lab',
            subtitle: _jenis == _Jenis.pc
                ? '${pcs.length} unit PC ditampilkan · ${s.pcs.length} baris termasuk arsip'
                : '${items.length} jenis barang ditampilkan · stok hanya bergerak lewat form barang',
            actions: [
              AdminButton(
                _arsip ? 'Sembunyikan arsip' : 'Tampilkan arsip',
                icon: Icons.archive_outlined,
                tone: _arsip ? AdminTone.warn : AdminTone.ghost,
                onTap: () => setState(() => _arsip = !_arsip),
              ),
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tab(_Jenis.pc, 'PC', _jenis, () => setState(() => _jenis = _Jenis.pc)),
                    _Tab(_Jenis.barang, 'Barang', _jenis, () => setState(() => _jenis = _Jenis.barang)),
                    const SizedBox(width: 6),
                    _Pill(label: 'Semua Lab', on: _lab == null, onTap: () => setState(() => _lab = null)),
                    for (final l in s.labs)
                      _Pill(
                        label: l.code,
                        on: _lab == l.id,
                        onTap: () => setState(() => _lab = _lab == l.id ? null : l.id),
                      ),
                    SizedBox(
                      width: 240,
                      child: AdminTextField(
                        controller: _cari,
                        placeholder: 'cari kode / nama / lokasi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _jenis == _Jenis.pc
                      ? (pcs.isEmpty
                          ? const AdminEmpty('Tidak ada PC yang cocok dengan filter.',
                              icon: Icons.desktop_windows_rounded)
                          : SingleChildScrollView(
                              child: AdminTable(
                                headers: const [
                                  'Lab', 'Kode', 'Prosesor', 'RAM', 'Storage',
                                  'Mouse', 'Keyboard', 'Status', 'Aksi',
                                ],
                                rows: [for (final p in pcs) _pcRow(context, s, p)],
                              ),
                            ))
                      : (items.isEmpty
                          ? const AdminEmpty('Tidak ada barang yang cocok dengan filter.',
                              icon: Icons.devices_other_rounded)
                          : SingleChildScrollView(
                              child: AdminTable(
                                headers: const [
                                  'Lab', 'Nama', 'Kategori', 'Stok', 'Spesifikasi',
                                  'Catatan', 'Status', 'Aksi',
                                ],
                                rows: [for (final i in items) _itemRow(context, s, i)],
                              ),
                            )),
                ),
              ],
            ),
          );
        },
      );

  List<PcAsset> _filterPc(AdminState s) {
    final q = _cari.text.trim().toLowerCase();
    return s.pcs
        .where((p) => _arsip || p.isActive)
        .where((p) => _lab == null || p.labId == _lab)
        .where((p) => q.isEmpty ||
            p.codename.toLowerCase().contains(q) ||
            p.processor.toLowerCase().contains(q) ||
            (p.location ?? '').toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.codename.compareTo(b.codename));
  }

  List<SupportAsset> _filterItem(AdminState s) {
    final q = _cari.text.trim().toLowerCase();
    return s.items
        .where((i) => _arsip || i.isActive)
        .where((i) => _lab == null || i.labId == _lab)
        .where((i) => q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            i.category.label.toLowerCase().contains(q) ||
            (i.location ?? '').toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ---------------------------------------------------------------------------
  // Baris
  // ---------------------------------------------------------------------------

  List<Widget> _pcRow(BuildContext context, AdminState s, PcAsset p) => [
        AdminTable.muted(s.labLabel(p.labId), size: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            tx(p.codename, 12.5, w: FontWeight.w700, c: mint),
            if (!p.isActive) tx('diarsipkan', 10, c: Colors.white38),
          ],
        ),
        AdminTable.cell(p.processor, maxLines: 1, size: 12),
        AdminTable.cell(p.ram, maxLines: 1, size: 12),
        AdminTable.muted(p.storage ?? '—', size: 12),
        AdminTable.muted(p.mouseSpec ?? '—', size: 12),
        AdminTable.muted(p.keyboardSpec ?? '—', size: 12),
        AssetChip(p.status),
        _aksiMenu(context, s, pc: p),
      ];

  List<Widget> _itemRow(BuildContext context, AdminState s, SupportAsset i) => [
        AdminTable.muted(s.labLabel(i.labId)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            tx(i.name, 12.5, w: FontWeight.w700, c: mint),
            if (!i.isActive) tx('diarsipkan', 10, c: Colors.white38),
          ],
        ),
        AdminTable.muted(i.category.label),
        AdminTable.cell(i.qtyLabel, weight: FontWeight.w700),
        AdminTable.muted(i.specifications ?? '—'),
        AdminTable.cell(i.notes ?? '—', maxLines: 2),
        AssetChip(i.status),
        _aksiMenu(context, s, item: i),
      ];

  // ---------------------------------------------------------------------------
  // Menu aksi (titik tiga)
  // ---------------------------------------------------------------------------

  Widget _aksiMenu(BuildContext context, AdminState s, {PcAsset? pc, SupportAsset? item}) =>
      PopupMenuButton<String>(
        tooltip: 'Aksi',
        padding: EdgeInsets.zero,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: a(mint, 0.12)),
        ),
        onSelected: (v) {
          if (v == 'status') {
            _status(context, s, pc: pc, item: item);
          } else if (pc != null) {
            _editPc(context, s, pc);
          } else if (item != null) {
            _editItem(context, s, item);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'status',
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 16, color: org),
                const SizedBox(width: 10),
                tx('Ubah status', 12.5),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 16, color: mint),
                const SizedBox(width: 10),
                tx('Edit data', 12.5),
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

  // ---------------------------------------------------------------------------
  // Dialog koreksi
  // ---------------------------------------------------------------------------

  Future<void> _editPc(BuildContext context, AdminState s, PcAsset p) => adminFormDialog(
        context,
        title: 'Koreksi ${p.codename}',
        subtitle: 'Kolom yang tidak diubah dikirim sebagai null dan tetap seperti semula.',
        submitLabel: 'Simpan',
        build: (ctx, f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormRow(
              label: 'Prosesor (wajib)',
              field: AdminTextField(controller: f.c('processor', initial: p.processor)),
            ),
            FormRow(
              label: 'RAM (wajib)',
              field: AdminTextField(controller: f.c('ram', initial: p.ram)),
            ),
            FormRow(
              label: 'Storage',
              hint: 'Kosongkan untuk menghapus isi kolom.',
              field: AdminTextField(controller: f.c('storage', initial: p.storage ?? '')),
            ),
            FormRow(label: 'GPU', field: AdminTextField(controller: f.c('gpu', initial: p.gpu ?? ''))),
            FormRow(
              label: 'Mouse',
              field: AdminTextField(controller: f.c('mouse', initial: p.mouseSpec ?? '')),
            ),
            FormRow(
              label: 'Keyboard',
              field: AdminTextField(controller: f.c('keyboard', initial: p.keyboardSpec ?? '')),
            ),
            FormRow(
              label: 'Lokasi / posisi',
              field: AdminTextField(controller: f.c('location', initial: p.location ?? '')),
            ),
            FormRow(
              label: 'Catatan',
              field: AdminTextField(controller: f.c('notes', initial: p.notes ?? ''), maxLines: 3),
            ),
          ],
        ),
        submit: (f) {
          if (f.v('processor').trim().isEmpty || f.v('ram').trim().isEmpty) {
            snack(context, 'Prosesor dan RAM wajib diisi.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: 'Spesifikasi ${p.codename} diperbarui.',
            setBusy: f.setBusy,
            action: () => s.savePc(
              pcId: p.id,
              processor: f.v('processor').trim(),
              ram: f.v('ram').trim(),
              storage: textFieldValue(p.storage, f.v('storage')),
              gpu: textFieldValue(p.gpu, f.v('gpu')),
              mouseSpec: textFieldValue(p.mouseSpec, f.v('mouse')),
              keyboardSpec: textFieldValue(p.keyboardSpec, f.v('keyboard')),
              location: textFieldValue(p.location, f.v('location')),
              notes: textFieldValue(p.notes, f.v('notes')),
            ),
          );
        },
      );

  Future<void> _editItem(BuildContext context, AdminState s, SupportAsset i) => adminFormDialog(
        context,
        title: 'Koreksi ${i.name}',
        subtitle: 'Stok adalah angka absolut. Bergerak tanpa alasan akan ditolak server.',
        submitLabel: 'Simpan',
        build: (ctx, f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormRow(
              label: 'Nama barang (wajib)',
              hint: 'Unik per Lab; tabrakan menghasilkan pesan dari server.',
              field: AdminTextField(controller: f.c('name', initial: i.name)),
            ),
            FormRow(
              label: 'Kategori',
              field: AdminDropdown<String>(
                value: f.sel<String>('category') ?? i.category.wire,
                items: [for (final c in SupportCategory.values) c.wire],
                labelOf: (w) => SupportCategory.parseOr(w).label,
                onChanged: (v) => f.pick('category', v ?? i.category.wire),
              ),
            ),
            FormRow(
              label: 'Spesifikasi',
              field: AdminTextField(controller: f.c('spec', initial: i.specifications ?? ''), maxLines: 2),
            ),
            FormRow(
              label: 'Satuan',
              hint: 'Mis. unit, rol, paket.',
              field: AdminTextField(controller: f.c('unit', initial: i.unit)),
            ),
            FormRow(
              label: 'Lokasi',
              field: AdminTextField(controller: f.c('location', initial: i.location ?? '')),
            ),
            FormRow(
              label: 'Catatan',
              field: AdminTextField(controller: f.c('notes', initial: i.notes ?? ''), maxLines: 3),
            ),
            const Divider(color: cardBorder),
            FormRow(
              label: 'Jumlah stok (absolut)',
              hint: 'Sekarang ${i.qty} ${i.unit}. Setiap perubahan wajib alasan minimal 3 karakter '
                  'dan otomatis tercatat di riwayat sebagai pelengkapan atau purnatugas.',
              field: AdminTextField(
                controller: f.c('qty', initial: '${i.qty}'),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
              ),
            ),
            FormRow(
              label: 'Alasan perubahan stok',
              field: AdminTextField(
                  controller: f.c('reason'), maxLines: 2, placeholder: 'Mis. 2 unit purnatugas ke gudang'),
            ),
          ],
        ),
        submit: (f) {
          final baru = int.tryParse(f.v('qty').trim());
          final berubah = baru != null && baru != i.qty;
          if (f.v('name').trim().isEmpty) {
            snack(context, 'Nama barang wajib diisi.', isError: true);
            return Future.value(false);
          }
          if (baru == null || baru < 0) {
            snack(context, 'Jumlah stok harus angka ≥ 0.', isError: true);
            return Future.value(false);
          }
          if (berubah && f.v('reason').trim().length < 3) {
            snack(context, 'Perubahan stok wajib disertai alasan.', isError: true);
            return Future.value(false);
          }
          return runAdminAction(
            context,
            successMessage: berubah
                ? 'Stok ${i.name}: ${i.qty} → $baru, tercatat di riwayat.'
                : 'Data ${i.name} diperbarui.',
            setBusy: f.setBusy,
            action: () => s.saveItem(
              itemId: i.id,
              name: f.v('name').trim(),
              category: SupportCategory.tryParse(f.sel<String>('category')),
              specifications: textFieldValue(i.specifications, f.v('spec')),
              unit: textFieldValue(i.unit, f.v('unit')),
              location: textFieldValue(i.location, f.v('location')),
              notes: textFieldValue(i.notes, f.v('notes')),
              qty: qtyIfChanged(i.qty, baru),
              reason: berubah ? f.v('reason').trim() : null,
            ),
          );
        },
      );

  Future<void> _status(BuildContext context, AdminState s, {PcAsset? pc, SupportAsset? item}) {
    final nama = pc?.codename ?? item?.name ?? 'aset';
    final sekarang = (pc?.status ?? item?.status) ?? AssetStatus.baik;
    final pilihan = AdminState.statusUntukPerubahan(sekarang, pc: pc != null);

    return adminFormDialog(
      context,
      title: 'Ubah status $nama',
      subtitle: 'Status sekarang: ${sekarang.label}. Perubahan status selalu menulis riwayat.',
      submitLabel: 'Terapkan status',
      tone: AdminTone.warn,
      width: 480,
      build: (ctx, f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormRow(
            label: 'Status baru',
            hint: 'Dalam pengajuan tidak ditawarkan: itu wilayah tiket dari aplikasi mobile.',
            field: AdminDropdown<String>(
              value: f.sel<String>('next') ?? pilihan.first.wire,
              items: [for (final st in pilihan) st.wire],
              labelOf: (w) => AssetStatus.tryParse(w)?.label ?? w,
              onChanged: (v) => f.pick('next', v ?? pilihan.first.wire),
            ),
          ),
          FormRow(
            label: 'Alasan (wajib)',
            hint: 'Menjadi action_taken pada baris riwayat baru.',
            field: AdminTextField(
                controller: f.c('reason'), maxLines: 3, placeholder: 'Mis. hasil uji: adaptor lemah, ganti unit'),
          ),
        ],
      ),
      submit: (f) {
        final next = AssetStatus.tryParse(f.sel<String>('next') ?? '') ?? pilihan.first;
        if (f.v('reason').trim().length < 3) {
          snack(context, 'Alasan minimal 3 karakter.', isError: true);
          return Future.value(false);
        }
        return runAdminAction(
          context,
          successMessage: 'Status $nama menjadi ${next.label}.',
          setBusy: f.setBusy,
          action: () => s.setAssetStatus(
            pcId: pc?.id,
            itemId: item?.id,
            status: next,
            reason: f.v('reason').trim(),
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  final _Jenis value;
  final String label;
  final _Jenis selected;
  final VoidCallback onTap;

  const _Tab(this.value, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: value == selected ? mint : card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value == selected ? mint : cardBorder),
          ),
          child: tx(label, 12.5, c: value == selected ? bg : Colors.white70, w: FontWeight.w700),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.on, required this.onTap});

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
