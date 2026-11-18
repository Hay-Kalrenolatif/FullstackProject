/// Login & daftar akun.
///
/// Username, bukan email: yang dikirim ke Supabase adalah `username@sibal.my.id`
/// (AppEnv.emailForUsername). Pendaftaran selalu menghasilkan peran `user` —
/// role tidak pernah dikirim dari sini.
library;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _register = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = _register
          ? await AuthService.instance.signUp(
              username: _username.text,
              fullName: _fullName.text,
              password: _password.text,
            )
          : await AuthService.instance.signIn(
              username: _username.text,
              password: _password.text,
            );
      await AppState.instance.signIn(profile);
      if (!mounted) return;
      snack(context, 'Halo, ${profile.fullName.split(' ').first}. Data lab dimuat.');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Tidak terhubung ke cloud: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Logo()),
                const SizedBox(height: 26),
                tx('Masuk ke Lab Anda', 23, w: FontWeight.w700, al: TextAlign.center),
                const SizedBox(height: 6),
                tx(
                  'Inventaris, status unit, dan pengajuan kerusakan dalam satu tempat.',
                  12.5,
                  c: Colors.white54,
                  al: TextAlign.center,
                ),
                const SizedBox(height: 26),

                Panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_register) ...[
                        TextField(
                          controller: _fullName,
                          textCapitalization: TextCapitalization.words,
                          decoration: dec('Nama tampilan', prefix: const Icon(Icons.badge_outlined, color: Colors.white38, size: 18)),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _username,
                        autocorrect: false,
                        decoration: dec('Username', prefix: const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 18)),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        obscuringCharacter: '•',
                        enableInteractiveSelection: true,
                        decoration: dec(
                          'Password',
                          prefix: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 18),
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white38, size: 18),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: org, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: tx(_error!, 12, c: org, w: FontWeight.w600)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      btn(
                        _busy
                            ? (_register ? 'Membuat akun…' : 'Masuk…')
                            : (_register ? 'Daftar & Masuk' : 'Masuk'),
                        _submit,
                        icon: _register ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    tx(_register ? 'Sudah punya akun?' : 'Belum terdaftar?', 12.5, c: Colors.white54),
                    TextButton(
                      onPressed: () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                      child: tx(
                        _register ? 'Masuk' : 'Daftar',
                        13,
                        c: mint,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                tx(
                  _register
                      ? 'Akun baru selalu berperan sebagai anggota. Admin mengangkat '
                          'peran lain dari panel admin.'
                      : 'Butuh akun? Daftar sendiri, lalu mintakan akses bila perlu '
                          'melihat data yang disembunyikan.',
                  11,
                  c: Colors.white38,
                  al: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
