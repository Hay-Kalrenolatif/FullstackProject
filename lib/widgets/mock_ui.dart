/// Komponen tampilan baru untuk revisi UI mockup (docs/design/).
///
/// Semuanya presentasi murni: menerima data lewat parameter, tidak menyentuh
/// repository/state. Dipakai lintas layar (Dashboard, Unit PC, Inventaris,
/// Pengajuan, Akun). Angka/nama selalu datang dari pemanggil (data nyata),
/// tidak ada nilai contoh di sini.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/assets.dart';
import '../theme.dart';

/// Baris pill pemilih Lab: dot mint + nama + jumlah, aktif lime (gelap).
/// `selectedId == null` berarti "Semua". Dipakai 4 layar.
class LabPicker extends StatelessWidget {
  final List<Lab> labs;
  final String? selectedId;
  final Map<String, int> counts;
  final ValueChanged<String?> onSelect;

  const LabPicker({
    super.key,
    required this.labs,
    required this.selectedId,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _pill(
            label: 'Semua',
            count: total,
            active: selectedId == null,
            onTap: () => onSelect(null),
          ),
          for (final l in labs) ...[
            const SizedBox(width: 8),
            _pill(
              label: l.code.isEmpty ? l.name : '${l.code} · ${l.name}',
              count: counts[l.id] ?? 0,
              active: selectedId == l.id,
              onTap: () => onSelect(selectedId == l.id ? null : l.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? yel : cardSubtle,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? yel : cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? bg : statusMint,
                ),
              ),
              const SizedBox(width: 7),
              tx(label, 12, c: active ? bg : Colors.white70, w: FontWeight.w700),
              const SizedBox(width: 7),
              tx('$count', 11, c: active ? bg.withAlpha(180) : secText, w: FontWeight.w600),
            ],
          ),
        ),
      );
}

/// Progress bar terbelah dua warna (mis. mint 75% + amber 25%) + legenda dot.
class SplitBar extends StatelessWidget {
  final List<Color> colors;
  final List<double> weights;
  final double height;

  const SplitBar({
    super.key,
    required this.colors,
    required this.weights,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < colors.length; i++)
              Expanded(
                flex: (weights[i] / total * 1000).round(),
                child: ColoredBox(color: colors[i]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Legenda kecil ber-dot untuk SplitBar.
class SplitLegend extends StatelessWidget {
  final List<(Color, String)> items;

  const SplitLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (color, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 6),
                tx(label, 11, c: Colors.white60),
              ],
            ),
        ],
      );
}

/// Kartu metrik: angka `display-stat` 28px + unit + label + sublabel + dot.
class MetricTile extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final String? sublabel;
  final Color accent;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.sublabel,
    this.accent = mint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: tx(label, 11.5, c: secText, w: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  tx(value, 28, c: Colors.white, w: FontWeight.w700),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    tx(unit!, 12, c: secText),
                  ],
                ],
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 3),
                tx(sublabel!, 11, c: accent, w: FontWeight.w600),
              ],
            ],
          ),
        ),
      );
}

/// Chip filter dengan badge hitung. Aktif lime (atau `activeColor`), bisa mint.
class ChipCount extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const ChipCount({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.activeColor = yel,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeColor : cardSubtle,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? activeColor : cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tx(label, 12, c: active ? bg : Colors.white70, w: FontWeight.w700),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? bg.withAlpha(30) : a(Colors.white, 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: tx('$count', 10.5,
                    c: active ? bg.withAlpha(200) : secText, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

/// Keadaan kosong: tile ikon bulat + judul + isi.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: a(mint, 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: a(mint, 0.22)),
              ),
              child: Icon(icon, color: mint, size: 26),
            ),
            const SizedBox(height: 14),
            tx(title, 15, w: FontWeight.w700),
            const SizedBox(height: 6),
            tx(body, 12, c: secText, al: TextAlign.center),
          ],
        ),
      );
}

/// Baris field sheet baca-saja: ikon + label + nilai + chevron.
class SheetField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const SheetField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: a(iconColor ?? mint, 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? mint, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx(label, 11, c: secText),
                  const SizedBox(height: 2),
                  tx(value, 13.5, w: FontWeight.w600),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
          ],
        ),
      );
}

/// Cincin tunggal kecil berikon pusat (mis. status daemon 48px).
class MiniRing extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final IconData icon;
  final double size;

  const MiniRing({
    super.key,
    required this.value,
    required this.color,
    required this.icon,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: cl(value)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          size: Size.square(size),
          painter: _MiniRingPainter(v, color),
          child: Center(child: Icon(icon, color: color, size: size * 0.42)),
        ),
      );
}

class _MiniRingPainter extends CustomPainter {
  final double v;
  final Color color;
  _MiniRingPainter(this.v, this.color);

  @override
  void paint(Canvas cv, Size s) {
    const w = 4.0;
    final c = s.center(Offset.zero);
    final r = s.width / 2 - w / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = a(cardSurface, 0.6);
    cv.drawCircle(c, r, track);

    if (v > 0.01) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color;
      cv.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * v, false, arc);
    }
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.v != v || old.color != color;
}
