# Panduan Tes SIBAL — Role User (HP) & Role Admin (PC)

Tujuan: memastikan seluruh sistem berjalan normal tanpa bug — pengajuan dari HP,
persetujuan dari panel admin, dan data berubah benar di kedua sisi.

Satu hal yang **sudah** kamu putuskan: data demo (tiket & riwayat) akan diisi
manual lewat alur tes di bawah. Lab/PC/barang sudah ter-seed oleh `0003_seed.sql`.

---

## 0. Persiapan sekali (Supabase dashboard)

1. **Matikan Confirm email** agar pendaftaran mandiri dari aplikasi tidak
   tersangkut batas kirim email:
   `Authentication → Providers → Email → Confirm email → OFF`.
2. **Bootstrap admin pertama** (tidak ada jalur resmi mengangkat diri sendiri).
   Buka `SQL Editor`, jalankan sebagai pemilik database:
   ```sql
   update public.profiles set role = 'admin' where username = 'nama_admin_kamu';
   ```
   Akun admin harus sudah ada lebih dulu (bisa dibuat lewat signup di HP, atau
   `Authentication → Add user`).
3. Pastikan `.env` berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`
   (skrip launcher membacanya; nilai tidak pernah dicetak).

---

## 1. Role USER — di HP (Android)

**Pasang aplikasi**

- APK sudah dibangun dengan kredensial tertanam: jalankan `build_mobile.cmd`,
  hasilnya di `build\app\outputs\flutter-apk\app-debug.apk`.
- Salin APK ke HP lalu pasang (izinkan "install dari sumber tidak dikenal"),
  **atau** colok HP via USB (USB debugging aktif) lalu `run_mobile.cmd` untuk
  `flutter run` (mendukung hot reload, cocok untuk iterasi).

**Langkah tes**

1. Buka aplikasi → onboarding sekali → **Daftar** dengan username & kata sandi
   (role otomatis `user`, tidak bisa jadi admin).
2. Cek **Beranda**: chip Lab, kartu kesiapan, kategori inventaris, aktivitas —
   datanya dari seed, bukan kosong.
3. **Unit PC** → pilih PC → **Ajukan Kerusakan** → isi gejala + tingkat urgensi
   → Kirim. Pastikan muncul pesan sukses dan PC berubah jadi "dalam pengajuan".
4. **Pengajuan** → tiket baru tampil berstatus **Menunggu**. Coba
   **Batalkan Pengajuan** (hanya bisa selama belum diproses admin).
5. Ajukan lagi satu tiket dan **biarkan** untuk diproses admin (lihat bagian 2).
6. **Uji offline**: matikan internet → banner kuning muncul, tombol ajukan
   terkunci, data masih tampil dari cache. Hidupkan kembali → banner hilang.

---

## 2. Role ADMIN — di komputer ini

**Jalankan panel**

- Klik dua kali `run_admin.cmd` → server web aktif di `http://localhost:8080`
  (dari perangkat lain di jaringan lab: `http://<IP-PC>:8080`).
- Login dengan username + kata sandi akun yang sudah di-promote admin.
- Akun non-admin yang login akan melihat layar "Anda bukan admin" (kosmetik;
  penegakan aslinya di server).

**Langkah tes (siklus penuh)**

1. **Antrean** → tiket dari HP tampil, urut berdasarkan urgensi.
   Klik **Periksa** (status → Diperiksa), lalu **Setujui** — pilih status aset
   `Rusak` atau `Diperiksa` (kembali `Baik` adalah tugas Selesai, bukan Setujui).
2. Cek di HP: status tiket dan status aset ikut berubah setelah refresh.
3. **Riwayat** → pekerjaan dari tiket itu muncul. Klik **Selesaikan**
   (isi `qty_delta = 0` kecuali ada barang keluar/masuk tambahan) → aset kembali
   **Baik**, tiket **Selesai**.
   ⚠ Jangan isi `qty_delta` di Setujui **dan** Selesaikan — stok bergerak dua kali.
4. **Aset** → coba koreksi spek PC / barang, ubah status, dan penyesuaian stok
   (angka absolut `p_qty` + alasan minimal 3 karakter).
5. **Broadcast** → buat/terbitkan pengumuman → muncul di Beranda HP.
6. **Pengguna** → angkat/turunkan peran, aktif/nonaktif akun. Uji dengan akun
   `user` lain untuk memastikan non-admin memang ditolak.

**Uji penolakan (pastikan tidak ada celah)**

- Login panel dengan akun `user` → hanya layar "bukan admin".
- Coba daftar akun baru via HP dengan harapan jadi admin → tetap `user`.

---

## 3. Cek "normal tanpa bug" — ringkasan

- Beranda/Unit PC/Inventaris menampilkan data seed (tidak kosong).
- Siklus report → periksa → setujui → selesai mengubah status tiket & aset di
  kedua sisi, dan konsisten setelah refresh.
- Batalkan hanya berhasil saat tiket masih `menunggu`; ditolak setelah diproses.
- Stok hanya bergerak lewat panel admin, selalu meninggalkan baris riwayat.
- Offline: baca dari cache, ajukan terkunci; online: banner hilang.

Jika ada langkah yang menyimpang dari ini, catat pesannya (teks persis) dan
laporkan — jangan perbaiki sendiri dulu agar akar masalahnya tidak tertutup.
