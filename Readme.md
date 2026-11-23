# Panduan DNS Switch untuk Mac

DNS Switch adalah aplikasi sederhana untuk memilih server DNS pada koneksi Wi-Fi atau Ethernet. Source code ditulis dalam Objective-C dan tersedia dalam file `DNS Switch.m`.

Panduan ini menggunakan Mac Apple Silicon, termasuk M1, dengan macOS 13 atau lebih baru.

## Arti folder Downloads

Downloads adalah folder di Mac tempat source code dan hasil aplikasi disimpan dalam panduan ini. Kamu dapat melihatnya melalui Finder.

Proses kompilasi mengubah source code menjadi program yang bisa dijalankan. Hasil akhirnya adalah folder khusus bernama `DNS Switch.app` yang dikenali macOS sebagai aplikasi.

## Cara kerja kode

Aplikasi menampilkan pilihan koneksi jaringan, membaca pengaturan DNS, dan menyediakan kolom alamat DNS. Alamat bawaan yang ditampilkan adalah `1.1.1.1, 1.0.0.1`.

Komponen yang dipakai meliputi berikut.

- Cocoa membuat tampilan aplikasi.
- SystemConfiguration membaca layanan jaringan dan pengaturan DNS.
- `networksetup`, alat bawaan macOS, menerapkan perubahan DNS.
- `osascript`, alat bawaan macOS, meminta izin administrator untuk menjalankan perubahan.
- NSUserDefaults menyimpan pengaturan DNS sebelumnya untuk setiap layanan jaringan.

Jadi, aplikasi memang memanggil alat sistem yang sudah tersedia di macOS. Kode aplikasi sendiri mengatur tampilan, validasi alamat, penyimpanan pengaturan sebelumnya, dan proses perubahan DNS.

Alamat `1.1.1.1` dan `1.0.0.1` merupakan alamat server DNS Cloudflare. Setelah diterapkan, macOS dapat memakai server tersebut untuk mencari alamat situs. Versi ini mengatur alamat DNS biasa. Fitur tunnel WARP dan DNS terenkripsi berada di luar fitur versi ini.

## Membuat aplikasi dari source code

### 1. Simpan source code

Salin file `DNS Switch.m` ke folder Downloads di Mac tujuan, kemudian ubah namanya menjadi `Switch.m`.

Jika menyalin kode melalui editor, simpan sebagai teks biasa dengan nama `Switch.m`. Periksa agar ekstensi akhirnya tetap `.m`.

### 2. Pasang alat kompilasi Apple

Buka Terminal, kemudian jalankan perintah berikut.

```bash
xcode-select --install
```

Selesaikan proses instalasi yang ditampilkan macOS. Jika alat tersebut sudah terpasang, lanjut ke langkah berikutnya.

Unduhan pada langkah ini berisi alat pengembangan Apple yang diperlukan untuk mengompilasi source code.

### 3. Buat aplikasi

Salin seluruh blok berikut ke Terminal. Perintah ini membaca `~/Downloads/Switch.m` dan membuat `~/Downloads/DNS Switch.app`.

```bash
(
set -e

cd "$HOME/Downloads"
test -f Switch.m
mkdir -p "DNS Switch.app/Contents/MacOS"

cat > "DNS Switch.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DNSControl</string>
    <key>CFBundleIdentifier</key>
    <string>local.dnsswitch.mac</string>
    <key>CFBundleName</key>
    <string>DNS Switch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

xcrun clang -fobjc-arc   -target arm64-apple-macos13   -framework Cocoa   -framework SystemConfiguration   Switch.m   -o "DNS Switch.app/Contents/MacOS/DNSControl"

codesign --force --sign - "DNS Switch.app"
codesign --verify --strict "DNS Switch.app"
open "DNS Switch.app"
)
```

Blok perintah berhenti jika salah satu langkah gagal. Jika berhasil, aplikasi terbuka.

`codesign --sign -` memberikan tanda tangan lokal atau ad hoc pada aplikasi. Distribusi dengan identitas pengembang Apple dan notarization memerlukan proses tambahan.

### 4. Pindahkan ke Applications

Buka Finder, masuk ke Downloads, lalu seret `DNS Switch.app` ke folder Applications. Setelah itu, kamu bisa membukanya dari folder Applications.

## Memakai aplikasi

1. Buka DNS Switch.
2. Pilih Wi-Fi atau layanan Ethernet yang ingin diatur, lalu klik Continue.
3. Gunakan alamat bawaan atau masukkan alamat IPv4 maupun IPv6 sendiri, dipisahkan koma.
4. Klik Apply DNS dan setujui permintaan izin administrator dari macOS.
5. Periksa pesan hasil perubahan.

Untuk memakai DNS yang diberikan jaringan, buka kembali aplikasi, pilih layanan yang sama, lalu klik Automatic.

Untuk memulihkan pengaturan yang disimpan sebelum perubahan pertama, pilih layanan yang sama lalu klik Restore Previous. Tombol ini aktif jika aplikasi memiliki pengaturan tersimpan. Setelah pemulihan berhasil, salinan pengaturan tersebut dihapus. Penggunaan berikutnya akan menyimpan kondisi awal yang baru.

Pengaturan DNS diterapkan per layanan jaringan. Wi-Fi dan Ethernet dapat memiliki pengaturan berbeda.

## Memindahkan aplikasi yang sudah jadi

Kamu juga dapat menyalin ZIP yang berisi `DNS Switch.app` ke Mac Apple Silicon lain dengan macOS 13 atau lebih baru. Ekstrak ZIP, kemudian pindahkan aplikasi ke Applications.

Alat kompilasi diperlukan saat membangun atau mengubah source code. Untuk menjalankan aplikasi yang sudah jadi, cukup gunakan file aplikasinya.

## Jika ada kesalahan

- Jika Terminal melaporkan `Switch.m` tidak ditemukan, periksa nama dan lokasinya di Downloads.
- Jika instalasi alat pengembangan belum selesai, selesaikan dahulu sebelum menjalankan perintah kompilasi.
- Jika alamat DNS tidak valid, gunakan alamat IP yang dipisahkan koma, seperti `1.1.1.1, 1.0.0.1`.
- Jika izin administrator dibatalkan, buka kembali aplikasi untuk mencoba perubahan lagi.
- Jika aplikasi gagal memverifikasi perubahan, periksa pengaturan DNS layanan tersebut di System Settings.

## Status pengujian

Build Apple Silicon dan tanda tangan lokal aplikasi awal sudah diperiksa. Penerapan dan pemulihan DNS secara langsung masih perlu diuji pada Mac tujuan.
