/// Jembatan AppState → widget.
///
/// Halaman tidak pernah memanggil repository sendiri; mereka membaca daftar dari
/// sini. Akibatnya satu `refresh()` memperbarui semua tab sekaligus, dan halaman
/// yang sedang dibuka tidak pernah menampilkan dua versi kenyataan.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

Widget stateScope({required Widget Function(BuildContext, AppState) builder}) =>
    AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) => builder(context, AppState.instance),
    );

/// Header halaman dalam: logo + status Lab, sama di semua tab.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tx(title, 22, w: FontWeight.w700),
                  const SizedBox(height: 4),
                  tx(subtitle, 12, c: Colors.white54),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
