

library;

import 'package:flutter/material.dart';

// Kanvas & lapisan permukaan.
const bg = Color(0xFF0E0E10), card = Color(0xFF1A1A1D);
const cardSurface = Color(0xFF222225), cardSubtle = Color(0xFF161618);
const cardBorder = Color(0xFF2A2A2D);

// Aksen.
const mint = Color(0xFF58E2C2), yel = Color(0xFFC1D045), lil = Color(0xFFC084FC), org = Color(0xFFF59E0B);
const redAlert = Color(0xFFFFB4AB);
const statusMint = Color(0xFF3BD6B0);

// Teks. Judul tetap putih; isi dan sekunder memakai nada abu-biru mockup.
const onMint = Color(0xFF00382D), onYel = Color(0xFF2E3300);
const bodyText = Color(0xFFDEE3EB), secText = Color(0xFF94A3B8);

Color a(Color c, double o) => c.withAlpha((o * 255).round());
double cl(num x) => x.clamp(0.0, 1.0).toDouble();

const dn = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

bool same(DateTime x, DateTime y) => x.year == y.year && x.month == y.month && x.day == y.day;

String fd(DateTime d) => '${d.day} ${bulan[d.month - 1]} ${d.year}';
String ft(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String fdt(DateTime d) => '${fd(d)}, ${ft(d)}';

/// Waktu relatif gaya mockup: `baru saja`, `12m lalu`, `3j lalu`, `2h lalu`,
/// lalu tanggal. Dipakai Aktivitas Terkini dan footer kartu tiket.
String rel(DateTime d) {
  final local = d.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.isNegative || diff.inSeconds < 30) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
  if (diff.inHours < 24) return '${diff.inHours}j lalu';
  if (diff.inDays < 7) return '${diff.inDays}h lalu';
  return fd(local);
}

String numFmt(num n) {
  final s = n.toInt().toString();
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
}

Text tx(String s, double z, {Color c = Colors.white, FontWeight w = FontWeight.w500, TextAlign? al, int? maxLines, TextOverflow? overflow}) =>
    Text(
      s,
      textAlign: al,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: z,
        color: c,
        fontWeight: w,
        letterSpacing: -0.2,
      ),
    );

// Helper UI umum
Widget btn(String l, VoidCallback f, {bool tonal = false, IconData? icon}) => FilledButton.icon(
      onPressed: f,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(l, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      style: FilledButton.styleFrom(
        backgroundColor: tonal ? a(mint, .15) : mint,
        foregroundColor: tonal ? mint : bg,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );

InputDecoration dec(String l, {Widget? prefix, Widget? suffix}) => InputDecoration(
      labelText: l,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF141416),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: a(mint, 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: mint, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );

void snack(BuildContext c, String m, {bool isError = false}) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? org : mint,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(m, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isError ? a(org, 0.4) : a(mint, 0.3)),
      ),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    ),
  );
}
