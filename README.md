# Dompet Bulanan

Aplikasi pencatat arus keuangan pribadi berbasis Flutter dengan database SQLite lokal. Aplikasi dapat digunakan langsung tanpa login, akun, server, atau koneksi internet.

## Fitur

- Pemasukan dan pengeluaran dengan kategori serta catatan.
- Antarmuka gelap dengan navigasi cepat dan tombol tambah transaksi di tengah.
- Input nominal melalui keypad khusus dengan pilihan nominal cepat.
- Riwayat transaksi yang dikelompokkan per tanggal, lengkap dengan total harian.
- Saldo berjalan dari saldo awal + pemasukan - pengeluaran.
- Batas pengeluaran per siklus dan indikator sisa atau kelebihan.
- Siklus gajian berulang otomatis, misalnya tanggal 25 sampai 24 bulan berikutnya.
- Laporan per siklus, bulan, tahun, dan rentang tanggal kustom.
- Diagram donat pengeluaran per kategori.
- Grafik pengeluaran siklus ini dibandingkan siklus sebelumnya.
- Grafik pemasukan vs pengeluaran bulanan.
- Kategori buatan sendiri dengan pilihan ikon dan warna.
- Database SQLite yang tersimpan di perangkat.

## Menjalankan aplikasi

```sh
flutter pub get
flutter devices
flutter run -d ID_PERANGKAT_ANDROID
```

Aplikasi langsung membuka halaman utama. Tidak ada halaman pendaftaran atau login.

Target utama proyek ini adalah Android. Jalankan pada ponsel Android atau emulator, bukan Chrome, karena database `sqflite` berada di penyimpanan aplikasi perangkat.

## Membuat APK

```sh
flutter build apk --release
```

APK akan dibuat di:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Penyimpanan SQLite

Database bernama `dompet_bulanan.db` dibuat otomatis saat aplikasi pertama kali dijalankan. Tabel yang digunakan:

- `wallets`: saldo awal, batas pengeluaran, mata uang, dan tanggal awal siklus.
- `categories`: kategori pemasukan atau pengeluaran, ikon, dan warna.
- `transactions`: jumlah, jenis, tanggal, kategori, dompet, serta catatan.

Skema, indeks, dompet awal, dan kategori bawaan dibuat otomatis oleh [`lib/repositories/sqlite_finance_repository.dart`](lib/repositories/sqlite_finance_repository.dart).

## Privasi dan batasan

- Seluruh data berada di penyimpanan internal aplikasi.
- Data tidak dikirim ke Supabase, Firebase, atau layanan cloud lainnya.
- Aplikasi tetap berfungsi tanpa internet.
- Menghapus aplikasi akan ikut menghapus database lokal.
- Data belum otomatis tersinkron ke perangkat lain.

Untuk penggunaan jangka panjang, fitur berikut yang paling penting ditambahkan selanjutnya adalah ekspor dan impor backup database, pengunci PIN atau biometrik, serta pengingat transaksi rutin.

## Cara kerja siklus gajian

Pengguna cukup menentukan tanggal awal. Aplikasi menghitung akhir periode sebagai satu hari sebelum siklus berikutnya:

- Awal tanggal 1 → tanggal 1 sampai akhir bulan.
- Awal tanggal 25 → tanggal 25 sampai tanggal 24 bulan berikutnya.
- Awal tanggal 31 → otomatis memakai hari terakhir pada bulan yang tidak mempunyai tanggal 31.

Aturan tersebut tersimpan di SQLite sehingga tidak perlu diatur ulang setiap bulan. Rentang tanggal khusus tetap tersedia pada halaman Laporan.
