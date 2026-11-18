/// AppBar tetap yang sama di semua tab mobile.
///
/// Menggantikan `PageHeader` per halaman: brand + subtitle nama layar di kiri,
/// pill `ONLINE`/`OFFLINE` berdenyut (sumber `connectivity_service`) + lonceng +
/// avatar di kanan. Pill ONLINE adalah tempat alami status koneksi — mint saat
/// online, amber saat putus (keadaan offline tidak digambar mockup, jadi ini
/// keputusan kita, lihat PETA-REVISI-UI.md §2).
library;

import 'package:flutter/material.dart';

import '../models/people.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

class AppHeader extends StatelessWidget {
  final String subtitle;
  final AppState s;
  final VoidCallback? onAvatarTap;

  const AppHeader({super.key, required this.subtitle, required this.s, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final online = s.online;
    final p = s.profile;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE60A0A0C),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E21), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                tx('SIBAL', 17, w: FontWeight.w700),
                const SizedBox(height: 1),
                tx(subtitle, 11, c: secText),
              ],
            ),
          ),
          _StatusPill(online: online),
          const SizedBox(width: 14),
          const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 14),
          _Avatar(p: p, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool online;
  const _StatusPill({required this.online});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: a(online ? mint : org, 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: a(online ? mint : org, 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseBadge(color: online ? mint : org),
            const SizedBox(width: 6),
            tx(online ? 'ONLINE' : 'OFFLINE', 10.5,
                c: online ? mint : org, w: FontWeight.w700),
          ],
        ),
      );
}

class _Avatar extends StatelessWidget {
  final Profile? p;
  final VoidCallback? onTap;
  const _Avatar({required this.p, this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = p?.initials ?? '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [mint, yel]),
          boxShadow: [BoxShadow(color: mint.withAlpha(35), blurRadius: 8)],
        ),
        child: Center(child: tx(initials, 12.5, c: bg, w: FontWeight.w800)),
      ),
    );
  }
}
