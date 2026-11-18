/// Inventaris barang pendukung.
///
/// Stepper jumlah dari prototipe **sengaja hilang**. Satu klik yang langsung
/// mengubah `qty` di perangkat lokal adalah sebab utama stok lab tidak pernah
/// cocok dengan kenyataan; jumlah sekarang hanya bergerak lewat admin, dan
/// setiap geraknya meninggalkan baris riwayat (0006 §3). Halaman ini baca-saja
/// terhadap stok; satu-satunya tindakan pengguna adalah mengajukan kerusakan.
library;

import 'package:flutter/material.dart';

import '../models/asset_enums.dart';
import '../models/assets.dart';
import '../models/tickets.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mock_ui.dart';
import '../widgets/report_sheet.dart';
import '../widgets/status_chip.dart';
import '../widgets/sync_banner.dart';
import '../widgets/state_scope.dart';

/// Pemetaan kategori barang ke ikon. Sumber nyata `support_category`, bukan
/// nama mockup.
IconData supportCategoryIcon(SupportCategory c) => switch (c) {
      SupportCategory.jaringan => Icons.hub_outlined,
      SupportCategory.tampilan => Icons.videocam_outlined,
      SupportCategory.daya => Icons.power_outlined,
      SupportCategory.periferal => Icons.keyboard_alt_outlined,
      SupportCategory.alat => Icons.handyman_outlined,
      SupportCategory.konsumsi => Icons.inventory_2_outlined,
      SupportCategory.lain => Icons.widgets_outlined,
    };

class SupportInventoryPage extends StatefulWidget {
  const SupportInventoryPage({super.key});

  @override
  State<SupportInventoryPage> createState() => _SupportInventoryPageState();
}

class _SupportInventoryPageState extends State<SupportInventoryPage> {
  final _search = TextEditingController();
  int _statusFilter = 0; // 0 semua, 1 siap pakai, 2 perlu tindakan

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lapor(AppState s, SupportAsset item) async {
    final res = await openReportSheet(
      context,
      assetLabel: '${item.name} · ${item.category.label}',
      itemId: item.id,
      currentStatus: item.status,
    );
    if (!mounted || res == null) return;
    snack(context, res.message, isError: !res.sent);
  }

  /// Buka sheet pilih barang, lalu lempar ke sheet laporan untuk pilihan itu.
  Future<void> _laporDariHeader(AppState s) async {
    final items = s.visibleItems;
    if (items.isEmpty) return;
    final chosen = await showModalBottomSheet<SupportAsset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemPickerSheet(items: items),
    );
    if (chosen == null || !mounted) return;
    await _lapor(s, chosen);
  }

  Future<void> _batalkan(AppState s, Report r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: tx('Batalkan pengajuan?', 16, w: FontWeight.w700),
        content: tx(
          'Status barang kembali ke ${r.prevAssetStatus.label}. Hanya bisa selama '
          'admin belum memprosesnya.',
          12.5,
          c: Colors.white70,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: tx('Batal', 13, c: secText)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: tx('Ya, batalkan', 13, c: org, w: FontWeight.w700),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await s.cancelMyReport(r.id);
      if (mounted) snack(context, 'Pengajuan dibatalkan dan status barang dipulihkan.');
    } catch (e) {
      if (mounted) snack(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => stateScope(builder: (context, s) {
        final q = _search.text.trim().toLowerCase();
        var all = s.visibleItems;
        if (_statusFilter == 1) {
          all = all.where((e) => e.status == AssetStatus.baik).toList();
        } else if (_statusFilter == 2) {
          all = all.where((e) => e.status.butuhPerhatian || e.habis).toList();
        }
        final shown = q.isEmpty
            ? all
            : all
                .where((e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.category.label.toLowerCase().contains(q) ||
                    (e.location ?? '').toLowerCase().contains(q) ||
                    (e.specifications ?? '').toLowerCase().contains(q))
                .toList();

        final groups = <String, List<SupportAsset>>{};
        for (final e in shown) {
          groups.putIfAbsent(e.labId, () => []).add(e);
        }
        for (final g in groups.values) {
          g.sort((a, b) => a.name.compareTo(b.name));
        }
        final byLab = <String, Lab>{for (final l in s.labs) l.id: l};

        final totalQty = s.visibleItems.fold<int>(0, (a, e) => a + e.qty);
        final siap = s.visibleItems.where((e) => e.status == AssetStatus.baik).length;
        final perlu = s.visibleItems.where((e) => e.status.butuhPerhatian || e.habis).length;

        final itemCounts = <String, int>{};
        for (final i in s.items) {
          itemCounts[i.labId] = (itemCounts[i.labId] ?? 0) + 1;
        }

        final openByItem = <String, Report>{};
        for (final r in s.myReports) {
          if (r.status.terbuka && r.supportingItemId != null) {
            openByItem[r.supportingItemId!] = r;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            SyncBanner(s),

            Row(
              children: [
                Expanded(child: tx('PILIH RUANG LABORATORIUM', 10.5, c: secText, w: FontWeight.w700)),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: s.online ? statusMint : org),
                    ),
                    const SizedBox(width: 6),
                    tx(s.online ? 'Node Aktif' : 'Node Offline', 10.5, c: secText),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LabPicker(
              labs: s.labsWithData,
              selectedId: s.labFilter,
              counts: itemCounts,
              onSelect: (id) => s.setLabFilter(id),
            ),
            const SizedBox(height: 18),

            Panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx('Inventaris Pendukung Lab', 18, w: FontWeight.w700),
                  const SizedBox(height: 3),
                  tx('Barang non-PC beserta jumlah stoknya', 11.5, c: secText),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          value: '$totalQty',
                          unit: 'Unit',
                          label: 'Total Alat Terdata',
                          sublabel: '${s.visibleItems.length} jenis tercatat',
                          accent: statusMint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricTile(
                          value: '$perlu',
                          unit: 'Jenis',
                          label: 'Dalam Pengajuan',
                          sublabel: 'Butuh tindakan admin',
                          accent: org,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  btn(
                    'Ajukan Kerusakan / Pengajuan',
                    s.online ? () => _laporDariHeader(s) : () {},
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx('Barang Pendukung', 18, w: FontWeight.w700),
                      const SizedBox(height: 2),
                      tx(
                        byLab[s.labFilter] == null
                            ? 'Semua laboratorium'
                            : (byLab[s.labFilter]!.code.isEmpty
                                ? byLab[s.labFilter]!.name
                                : '${byLab[s.labFilter]!.code} · ${byLab[s.labFilter]!.name}'),
                        11.5,
                        c: secText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ChipCount(
                    label: 'Semua', count: s.visibleItems.length, active: _statusFilter == 0,
                    onTap: () => setState(() => _statusFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'Siap Pakai', count: siap, active: _statusFilter == 1,
                    onTap: () => setState(() => _statusFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  ChipCount(
                    label: 'Perlu Tindakan', count: perlu, active: _statusFilter == 2,
                    onTap: () => setState(() => _statusFilter = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: dec(
                'Cari nama barang, kategori, atau lokasi',
                prefix: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),

            if (shown.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Tidak Ada Barang Ditemukan',
                body: all.isEmpty
                    ? 'Belum ada barang pendukung yang terdata di laboratorium ini.'
                    : 'Tidak ada barang yang sesuai dengan filter yang Anda pilih.',
              )
            else
              for (final entry in groups.entries) ...[
                _GroupTitle(lab: byLab[entry.key], count: entry.value.length),
                for (final item in entry.value)
                  _ItemCard(
                    item: item,
                    report: openByItem[item.id],
                    online: s.online,
                    onReport: () => _lapor(s, item),
                    onCancel: (r) => _batalkan(s, r),
                  ),
              ],
          ],
        );
      });
}

class _ItemCard extends StatelessWidget {
  final SupportAsset item;
  final Report? report;
  final bool online;
  final VoidCallback onReport;
  final ValueChanged<Report> onCancel;

  const _ItemCard({
    required this.item,
    required this.report,
    required this.online,
    required this.onReport,
    required this.onCancel,
  });

  bool get _bermasalah => item.status.butuhPerhatian || item.habis;

  @override
  Widget build(BuildContext context) => Panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: a(_bermasalah ? org : statusMint, 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: a(_bermasalah ? org : statusMint, 0.25)),
                  ),
                  child: Icon(
                    supportCategoryIcon(item.category),
                    color: _bermasalah ? org : statusMint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tx(item.name, 15, c: _bermasalah ? org : Colors.white, w: FontWeight.w700),
                      const SizedBox(height: 3),
                      tx(
                        [
                          item.category.label,
                          if (item.specifications != null) item.specifications!,
                        ].join(' · '),
                        11,
                        c: secText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    tx(item.qtyLabel, 14, w: FontWeight.w800, c: item.habis ? redAlert : yel),
                    const SizedBox(height: 4),
                    AssetChip(item.status),
                  ],
                ),
              ],
            ),
            if (item.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.pin_drop_outlined, color: Colors.white38, size: 15),
                  const SizedBox(width: 6),
                  Expanded(child: tx('Posisi: ${item.location}', 11, c: Colors.white60)),
                ],
              ),
            ],
            if (report != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a(org, 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a(org, 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: org, size: 15),
                        const SizedBox(width: 6),
                        tx('Catatan Tiket', 10.5, c: org, w: FontWeight.w700),
                      ],
                    ),
                    const SizedBox(height: 6),
                    tx(report!.issue, 11.5, c: Colors.white70),
                  ],
                ),
              ),
            ] else if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: a(mint, 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a(mint, 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, color: statusMint, size: 15),
                        const SizedBox(width: 6),
                        tx('Catatan kondisi', 10.5, c: statusMint, w: FontWeight.w700),
                      ],
                    ),
                    const SizedBox(height: 6),
                    tx(item.notes!, 11.5, c: Colors.white70),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: item.updatedAt == null
                      ? tx('Tidak ada riwayat', 11, c: Colors.white38)
                      : Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: Colors.white38, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: tx(
                                'Terakhir dicek: ${rel(item.updatedAt!)}',
                                11,
                                c: secText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                if (report != null)
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: online ? () => onCancel(report!) : null,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Batalkan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: a(org, 0.16),
                        foregroundColor: org,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: online ? onReport : null,
                      icon: const Icon(Icons.report_gmailerrorred_rounded, size: 14),
                      label: Text(
                        item.habis ? 'Lapor Habis' : 'Ajukan Kerusakan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: a(yel, 0.16),
                        foregroundColor: yel,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        borderColor: _bermasalah ? a(org, 0.28) : null,
      );
}

class _ItemPickerSheet extends StatelessWidget {
  final List<SupportAsset> items;
  const _ItemPickerSheet({required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: cardBorder, width: 1.2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx('Pilih Barang Laboratorium', 17, w: FontWeight.w700),
            const SizedBox(height: 4),
            tx('Pilih barang yang ingin dilaporkan kerusakannya.', 12, c: secText),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: a(mint, 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(supportCategoryIcon(e.category), color: mint, size: 18),
                      ),
                      title: tx(e.name, 13.5, w: FontWeight.w600),
                      subtitle: tx('${e.qtyLabel} · ${e.category.label}', 11, c: secText),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () => Navigator.pop(context, e),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _GroupTitle extends StatelessWidget {
  final Lab? lab;
  final int count;

  const _GroupTitle({required this.lab, required this.count});

  @override
  Widget build(BuildContext context) {
    final l = lab;
    final title = l == null ? 'Lab' : (l.code.isEmpty ? l.name : '${l.code} · ${l.name}');
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          tx(title, 12.5, c: mint, w: FontWeight.w700),
          const SizedBox(width: 8),
          tx('$count jenis', 11, c: secText),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
