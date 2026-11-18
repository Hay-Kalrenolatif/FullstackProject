/// Inisialisasi yang sama untuk kedua shell (mobile dan panel admin).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_env.dart';

/// Harus dipanggil sebelum runApp(). `Supabase.initialize` menahan koneksi dan
/// memulihkan sesi dari penyimpanan perangkat, jadi pengguna tidak perlu login
/// ulang setiap kali aplikasi dibuka.
Future<void> bootstrapSibalApp() async {
  AppEnv.ensureConfigured();
  await Supabase.initialize(
    url: AppEnv.url,
    publishableKey: AppEnv.publishableKey,
  );
}
