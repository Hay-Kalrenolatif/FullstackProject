/// Login panel admin.
///
/// Akun yang dipakai sama dengan aplikasi mobile — tidak ada identitas kedua.
/// Username dipetakan ke email sintetis oleh `AuthService` (AppEnv.emailDomain),
/// dan peran dibaca dari `profiles.role`, bukan dari asersi klien.
library;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_state.dart';
import 'widgets/admin_ui.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await AuthService.instance.signIn(
        username: _username.text,
        password: _password.text,
      );
      await AdminState.instance.attach(p);
      if (!mounted) return;
      snack(context, 'Panel terbuka sebagai ${p.username}.');
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: a(mint, 0.25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Logo(),
                        const SizedBox(width: 6),
                        tx('ADMIN', 10, c: mint, w: FontWeight.w800),
                      ],
                    ),
                    const SizedBox(height: 22),
                    tx('Panel administrator', 20, w: FontWeight.w700),
                    const SizedBox(height: 6),
                    tx(
                      'Silahkan masuk sebagai admin',
                      12,
                      c: Colors.white54,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: dec('Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: dec(
                        'Password',
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18, color: Colors.white38),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: a(redAlert, 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: a(redAlert, 0.35)),
                        ),
                        child: tx(_error!, 11.5, c: redAlert),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AdminButton(
                      _busy ? 'Memeriksa…' : 'Masuk',
                      tone: AdminTone.primary,
                      icon: Icons.login_rounded,
                      expand: true,
                      onTap: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    tx(
                      'Lupa password?, Gabisa dipulihkan hhe:>',
                      10.5,
                      c: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
