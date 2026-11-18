/// Blok bangunan bersama panel admin.
///
/// Sengaja memakai token `theme.dart` yang sama dengan sisi mobile supaya panel
/// dan aplikasi terlihat seperti satu produk, bukan dua sistem yang ketemu di
/// tengah jalan. Tidak ada dependensi ke Hive atau `AppState` di sini.
library;

import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../theme.dart';
import '../admin_state.dart';

Widget adminScope({required Widget Function(BuildContext, AdminState) builder}) =>
    AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) => builder(context, AdminState.instance),
    );

/// Judul halaman + aksi di kanan + isi yang bisa di-scroll.
class AdminPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  const AdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final sempit = MediaQuery.sizeOf(context).width < 700;
    final judul = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tx(title, sempit ? 19 : 22, w: FontWeight.w700),
        const SizedBox(height: 4),
        tx(subtitle, 12, c: Colors.white54),
      ],
    );
    final aksi = Wrap(spacing: 8, runSpacing: 8, children: actions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: sempit
              ? const EdgeInsets.fromLTRB(16, 16, 16, 4)
              : const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: sempit
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [judul, if (actions.isNotEmpty) ...[const SizedBox(height: 12), aksi]],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: judul), aksi],
                ),
        ),
        Expanded(
          child: Padding(
            padding: sempit
                ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
                : const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: child,
          ),
        ),
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final IconData icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
  });

  // Lebar tetap: KpiCard hidup di dalam Wrap yang memberi constraint lebar
  // tak terbatas; tanpa batas ini Row ber-Expanded di dalamnya gagal layout.
  // Di HP kartu melebar penuh (padding AdminPage 16 kiri-kanan).
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: w < 700 ? w - 32 : 216,
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: a(color, 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: tx(label, 13, c: Colors.white, w: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              tx(value, 26, w: FontWeight.w800, c: Colors.white),
              if (sub != null) ...[
                const SizedBox(height: 4),
                tx(sub!, 12, c: a(color, 0.95)),
              ],
            ],
          ),
        ),
    );
  }
}

enum AdminTone { primary, ghost, warn, danger }

class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final AdminTone tone;
  final bool dense;

  /// Lebar penuh (selebar field input) dengan isi di tengah. Dipakai pada
  /// tombol primer layar login; default `false` supaya pemakaian di tabel/dialog
  /// tidak berubah.
  final bool expand;

  const AdminButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.tone = AdminTone.ghost,
    this.dense = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgc, Color fgc, Color bord) = switch (tone) {
      AdminTone.primary => (mint, bg, mint),
      AdminTone.ghost => (cardSurface, Colors.white70, cardBorder),
      AdminTone.warn => (a(org, 0.16), org, a(org, 0.45)),
      AdminTone.danger => (a(redAlert, 0.14), redAlert, a(redAlert, 0.4)),
    };
    final enabled = onTap != null;
    final button = Material(
      color: enabled ? bgc : a(bgc, 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: expand ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 14,
            vertical: dense ? 7 : (expand ? 9 : 10),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: enabled ? bord : a(bord, 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 14 : 16, color: enabled ? fgc : a(fgc, 0.5)),
                const SizedBox(width: 6),
              ],
              tx(label, dense ? 11.5 : 12.5, c: enabled ? fgc : a(fgc, 0.5), w: FontWeight.w700),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Tabel data dengan gaya SIBAL. Kolom dideklarasikan sekali, baris dibangun
/// per halaman.
class AdminTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final bool numericRight;

  const AdminTable({
    super.key,
    required this.headers,
    required this.rows,
    this.numericRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = numericRight ? Alignment.centerRight : Alignment.centerLeft;
    return LayoutBuilder(
      builder: (context, c) {
        // Layar sempit (HP): tabel jadi daftar kartu berlabel — kolom tidak
        // berdesakan. Desktop tetap tabel asli di bawah.
        if (c.maxWidth < 700) return _cards();
        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var j = 0; j < headers.length; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: align,
                          child: tx(headers[j], 12.5, w: FontWeight.w700, c: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(height: 1, color: a(Colors.white, 0.07)),
              for (int i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var j = 0; j < rows[i].length; j++) ...[
                        if (j > 0) const SizedBox(width: 12),
                        Expanded(
                          child: Align(alignment: align, child: rows[i][j]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (i != rows.length - 1) Container(height: 1, color: a(Colors.white, 0.05)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Mode HP: satu kartu per baris. Kolom pertama jadi judul kartu, kolom
  /// "Aksi" pindah ke kanan atas, sisanya pasangan label–nilai vertikal.
  Widget _cards() {
    final aksi = headers.indexOf('Aksi');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: rows[i].isNotEmpty
                          ? rows[i][0]
                          : const SizedBox.shrink(),
                    ),
                    if (aksi > 0 && aksi < rows[i].length) rows[i][aksi],
                  ],
                ),
                for (int j = 1; j < rows[i].length && j < headers.length; j++)
                  if (j != aksi)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 86,
                            child: tx(headers[j], 11, c: Colors.white38, w: FontWeight.w600),
                          ),
                          Expanded(
                            child: Align(alignment: Alignment.centerLeft, child: rows[i][j]),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static Widget cell(String text, {Color? color, int maxLines = 2, FontWeight? weight, double size = 12.5}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: tx(text, size,
            c: color ?? Colors.white,
            w: weight ?? FontWeight.w500,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis),
      );

  static Widget muted(String text, {double size = 12.5}) =>
      cell(text, color: Colors.white54, size: size);
}

/// Menu aksi titik-3 untuk kolom "Aksi" tabel: satu ikon sempit, bukan deret
/// tombol teks yang lebarnya melebihi kolom dan menimbulkan overflow.
class AdminActionMenu extends StatelessWidget {
  final List<PopupMenuItem<String>> items;
  final ValueChanged<String> onSelected;

  const AdminActionMenu({super.key, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Opsi aksi',
        color: cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
        onSelected: onSelected,
        itemBuilder: (_) => items,
      );
}

/// Satu baris menu AdminActionMenu: ikon 16 + jarak 9 + label, tinggi 38.
PopupMenuItem<String> adminMenuItem(String value, String label, IconData icon, Color c) =>
    PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 9),
          tx(label, 12, c: c, w: FontWeight.w600),
        ],
      ),
    );

class AdminEmpty extends StatelessWidget {
  final String text;
  final IconData icon;
  const AdminEmpty(this.text, {super.key, this.icon = Icons.inbox_rounded});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white24, size: 30),
            const SizedBox(height: 10),
            tx(text, 12.5, c: Colors.white54, al: TextAlign.center),
          ],
        ),
      );
}

/// Dialog bertema untuk form admin. Isi form dibangun halaman masing-masing.
Future<T?> adminDialog<T>(BuildContext context, {
  required String title,
  required String subtitle,
  required Widget Function(BuildContext) builder,
  double width = 520,
}) =>
    showDialog<T>(
      context: context,
      barrierColor: Colors.black.withAlpha(170),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: a(mint, 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tx(title, 16, w: FontWeight.w700),
                            const SizedBox(height: 3),
                            tx(subtitle, 11.5, c: Colors.white54),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: cardBorder),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: SizedBox(width: double.infinity, child: builder(dialogCtx)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Ya, jalankan',
  AdminTone tone = AdminTone.warn,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tx(title, 15, w: FontWeight.w700),
              const SizedBox(height: 8),
              tx(message, 12.5, c: Colors.white70),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdminButton('Batal', onTap: () => Navigator.of(ctx).pop(false)),
                  const SizedBox(width: 8),
                  AdminButton(
                    okLabel,
                    tone: tone,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return r ?? false;
}

/// Label + kontrol form, dipakai semua dialog.
class FormRow extends StatelessWidget {
  final String label;
  final Widget field;
  final String? hint;

  const FormRow({super.key, required this.label, required this.field, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tx(label, 11.5, c: Colors.white70, w: FontWeight.w700),
            const SizedBox(height: 6),
            field,
            if (hint != null) ...[
              const SizedBox(height: 5),
              tx(hint!, 10.5, c: Colors.white38),
            ],
          ],
        ),
      );
}

class AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? placeholder;
  final int maxLines;
  final TextInputType? keyboardType;

  const AdminTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: dec(placeholder ?? '', prefix: null, suffix: null),
      );
}

class AdminDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final String? hint;

  const AdminDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1410),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a(mint, 0.12)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: tx(hint ?? 'Pilih…', 13, c: Colors.white38),
            dropdownColor: cardSurface,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            items: [
              for (final i in items)
                DropdownMenuItem(value: i, child: tx(labelOf(i), 13)),
            ],
            onChanged: onChanged,
          ),
        ),
      );
}

/// Baris tombol di dasar dialog.
class DialogActions extends StatelessWidget {
  final String submitLabel;
  final VoidCallback? onSubmit;
  final VoidCallback onCancel;
  final bool busy;
  final AdminTone tone;

  const DialogActions({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
    this.busy = false,
    this.tone = AdminTone.primary,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AdminButton('Batal', onTap: busy ? null : onCancel),
          const SizedBox(width: 8),
          busy
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: mint),
                  ),
                )
              : AdminButton(submitLabel, tone: tone, icon: Icons.check_rounded, onTap: onSubmit),
        ],
      );
}

/// Isi bersama semua dialog aksi: controller dan pilihan yang disimpan per kunci,
/// rebuild didelegasikan ke [AdminFormDialog], dan `busy` dijaga di satu tempat.
///
/// Kenapa per kunci dan bukan satu kelas form per halaman: dialog admin hanya
/// berbeda di daftar field, bukan di cara kerjanya. Menyalin kelas form untuk
/// enam halaman berarti enam tempat yang harus diingat saat aturan `null` vs
/// `''` berubah.
class AdminForm {
  final Map<String, TextEditingController> _c = {};
  final Map<String, Object?> _sel = {};

  void Function(void Function())? _rebuild;
  void Function(bool)? _busy;
  bool busy = false;

  TextEditingController c(String key, {String initial = ''}) =>
      _c.putIfAbsent(key, () => TextEditingController(text: initial));

  String v(String key) => _c[key]?.text ?? '';
  String? nullable(String key) {
    final t = v(key).trim();
    return t.isEmpty ? null : t;
  }

  int intV(String key, {int fallback = 0}) => int.tryParse(v(key).trim()) ?? fallback;

  T? sel<T>(String key) => _sel[key] as T?;

  /// Isi tanpa memicu rebuild — khusus prefill di `init` dialog.
  void set<T>(String key, T? value) => _sel[key] = value;

  void pick<T>(String key, T? value) => update(() => _sel[key] = value);

  void update(VoidCallback f) => _rebuild?.call(f);

  void setBusy(bool value) {
    busy = value;
    _busy?.call(value);
  }

  void bind(void Function(void Function()) rebuild, void Function(bool) busySink) {
    _rebuild = rebuild;
    _busy = busySink;
  }

  void dispose() {
    for (final ctrl in _c.values) {
      ctrl.dispose();
    }
    _c.clear();
    _sel.clear();
    _rebuild = null;
    _busy = null;
  }
}

/// Membuka dialog form dan menutupnya **hanya** kalau [submit] mengembalikan
/// true — yaitu setelah RPC sukses. Kalau gagal, form tetap terbuka supaya
/// admin tidak kehilangan isian.
Future<void> adminFormDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  String submitLabel = 'Simpan',
  AdminTone tone = AdminTone.primary,
  double width = 560,
  void Function(AdminForm form)? init,
  required Widget Function(BuildContext, AdminForm) build,
  required Future<bool> Function(AdminForm) submit,
}) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(170),
      builder: (dialogCtx) => _AdminFormDialog(
        title: title,
        subtitle: subtitle,
        submitLabel: submitLabel,
        tone: tone,
        width: width,
        init: init,
        build: build,
        submit: submit,
      ),
    );

class _AdminFormDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String submitLabel;
  final AdminTone tone;
  final double width;
  final void Function(AdminForm form)? init;
  final Widget Function(BuildContext, AdminForm) build;
  final Future<bool> Function(AdminForm) submit;

  const _AdminFormDialog({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.tone,
    required this.width,
    required this.init,
    required this.build,
    required this.submit,
  });

  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  final _form = AdminForm();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _form.bind(setState, (v) => setState(() => _busy = v));
    // Prefill dilakukan di sini, bukan di dalam build(): memanggil pick()/c()
    // saat build berjalan berarti setState di tengah build.
    widget.init?.call(_form);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.width),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: a(mint, 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tx(widget.title, 15.5, w: FontWeight.w700),
                            const SizedBox(height: 3),
                            tx(widget.subtitle, 11.5, c: Colors.white54),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: cardBorder),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: SizedBox(width: double.infinity, child: widget.build(context, _form)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: DialogActions(
                    submitLabel: widget.submitLabel,
                    busy: _busy,
                    tone: widget.tone,
                    onCancel: () => Navigator.of(context).pop(),
                    onSubmit: _busy
                        ? null
                        : () async {
                            final ok = await widget.submit(_form);
                            if (ok && context.mounted) Navigator.of(context).pop();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Membungkus satu aksi admin: atur busy, panggil, tampilkan hasil/kesalahan.
///
/// Mengembalikan true kalau aksi berhasil, supaya pemanggil bisa menutup dialog
/// **sesudah** aksinya sukses — bukan sebelum.
Future<bool> runAdminAction(
  BuildContext context, {
  required String successMessage,
  required Future<void> Function() action,
  required void Function(bool) setBusy,
}) async {
  setBusy(true);
  try {
    await action();
    if (context.mounted) snack(context, successMessage);
    return true;
  } on CloudFailure catch (e) {
    if (context.mounted) snack(context, e.message, isError: true);
    return false;
  } catch (e) {
    if (context.mounted) snack(context, 'Aksi gagal: $e', isError: true);
    return false;
  } finally {
    setBusy(false);
  }
}

/// Konvensi `app.text_field` (0006 §1): nilai yang tidak berubah dikirim `null`
/// (jangan ubah), nilai yang dikosongkan dikirim `''` (kosongkan), sisanya
/// dikirim sebagai teks. Helper ini yang menjaga bedanya tetap ada — kalau
/// form selalu mengirim string, kolom yang tidak disentuh akan ikut terhapus.
String? textFieldValue(String? original, String now) {
  final trimmed = now.trim();
  final before = (original ?? '').trim();
  if (trimmed == before) return null;
  return trimmed;
}

/// `qty` hanya lewat `p_qty` + `p_reason`; delta nol tidak perlu dikirim.
int? qtyIfChanged(int original, int now) => now == original ? null : now;

String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// Durasi tiket/riwayat dalam bahasa pendek: 12m, 3j, 2h, 14d.
String ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().toUtc().difference(t);
  if (d.inMinutes < 1) return 'baru';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}j';
  if (d.inDays < 30) return '${d.inDays}h';
  return '${(d.inDays / 30).floor()}bl';
}

String wib(DateTime? t) {
  if (t == null) return '—';
  final local = t.toLocal();
  return '${fd(local)} ${ft(local)}';
}
