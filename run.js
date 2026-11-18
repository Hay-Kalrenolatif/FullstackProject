#!/usr/bin/env node
'use strict';

/**
 * Peluncur Flutter untuk SIBAL — mobile & panel admin.
 *
 * Membaca nilai Supabase dari `.env` sendiri (nilainya TIDAK pernah dicetak),
 * lalu memanggil `flutter` dengan `--dart-define` yang tepat. Alasan pakai
 * skrip: hasil `flutter build web` adalah berkas statis yang bisa dibaca siapa
 * pun, jadi hanya publishable key yang boleh ikut. Skrip ini memastikan
 * password DB / service_role di `.env` TIDAK terbawa ke perintah flutter.
 *
 * Penggunaan:
 *   node run.js admin         # flutter run web-server (panel admin) di :8080
 *   node run.js mobile        # flutter run (perangkat/emulator terhubung)
 *   node run.js build-admin   # flutter build web -t lib/admin_main.dart
 *   node run.js build-mobile  # flutter build apk --debug (APK siap pasang, ada dart-define)
 *   node run.js check         # hanya cek .env terbaca, tanpa menjalankan
 *
 * Pintasan Windows (klik dua kali): run_admin.cmd, run_mobile.cmd, build_admin.cmd,
 * build_mobile.cmd
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
// Override jalur .env (untuk uji) lewat SIBAL_ENV.
const ENV_PATH = process.env.SIBAL_ENV || path.join(ROOT, '.env');

function parseDotEnv(text) {
  const out = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith(';')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (val.length >= 2) {
      const first = val[0];
      const last = val[val.length - 1];
      if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
        val = val.slice(1, -1);
      }
    }
    out[key] = val;
  }
  return out;
}

function main() {
  if (!fs.existsSync(ENV_PATH)) {
    console.error('Tidak menemukan .env di root proyek. Salin .env.example → .env lalu isi.');
    process.exit(1);
  }
  const env = parseDotEnv(fs.readFileSync(ENV_PATH, 'utf8'));

  const url = env.SUPABASE_URL || '';
  // Nama variabel publishable key bisa dua-duanya (lihat .env.example vs app_env.dart);
  // dukung keduanya.
  const key = env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY || '';

  if (!url || !key) {
    console.error('Gagal: .env belum berisi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY (atau SUPABASE_ANON_KEY).');
    process.exit(1);
  }

  const mode = (process.argv[2] || 'admin').toLowerCase();

  if (mode === 'check') {
    console.log('OK · SUPABASE_URL & publishable key terbaca dari .env.');
    return;
  }

  const defines = [
    `--dart-define=SUPABASE_URL=${url}`,
    `--dart-define=SUPABASE_PUBLISHABLE_KEY=${key}`,
  ];

  let args;
  let label;
  switch (mode) {
    case 'mobile':
      args = ['run', ...defines];
      label = 'run (mobile, perangkat/emulator)';
      break;
    case 'mobile-web':
      args = [
        'run', '-d', 'web-server',
        '--web-hostname', '0.0.0.0', '--web-port', '8081',
        '-t', 'lib/main.dart',
        ...defines,
      ];
      label = 'run web-server (mobile) di http://localhost:8081';
      break;
    case 'build-admin':
      args = ['build', 'web', '-t', 'lib/admin_main.dart', ...defines];
      label = 'build web (panel admin)';
      break;
    case 'build-mobile':
      args = ['build', 'apk', '--debug', ...defines];
      label = 'build APK debug (mobile, kredensial tertanam)';
      break;
    case 'admin':
    default:
      args = [
        'run', '-d', 'web-server',
        '--web-hostname', '0.0.0.0', '--web-port', '8080',
        '-t', 'lib/admin_main.dart',
        ...defines,
      ];
      label = 'run web-server (panel admin) di http://localhost:8080';
      break;
  }

  console.log(`SIBAL · ${label}`);
  const res = spawnSync('flutter', args, {
    cwd: ROOT,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  process.exit(res.status == null ? 1 : res.status);
}

main();
