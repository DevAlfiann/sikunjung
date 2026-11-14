# 📱 SiKunjung - Presensi & Pelacakan Kunjungan Lapangan

Aplikasi presensi dan pelacakan rute petugas lapangan berbasis **Flutter** dengan arsitektur **Offline-First**, dilengkapi integrasi sensor kompas *real-time*, GPS & pemetaan rute interaktif, serta sinkronisasi data lokal (SQLite) ke basis data pusat (MySQL).

---

## 🚀 Fitur Unggulan

1. **Keamanan & Autentikasi (Mobile Security)**
   - Autentikasi petugas dengan *cryptographic random salt* dan algoritma *hashing* SHA-256.
   - Proteksi *Brute-Force Rate Limiting* (lockout otomatis setelah 5 kali gagal login).
   - Pengingat sesi login (*Remember Me*).

2. **Penyimpanan Offline-First & Sinkronisasi (Data Persistence)**
   - Database lokal **SQLite** (`sikunjung.db`) pada perangkat mobile agar tetap beroperasi saat tidak ada jaringan/sinyal.
   - Antrean sinkronisasi otomatis (`sync_queue`) yang mendorong pembaruan data ke server **MySQL** saat koneksi kembali stabil.

3. **Layanan Berbasis Lokasi & Navigasi (LBS & GPS)**
   - Integrasi **OpenStreetMap** interaktif via `flutter_map` & `latlong2`.
   - Perhitungan jarak (*distance*) dan estimasi waktu tempuh (*ETA*) ke lokasi kunjungan secara dinamis.
   - Visualisasi rute perjalanan dan penanda lokasi (*custom markers*).

4. **Sensor Perangkat Real-Time (Mobile Sensor)**
   - Kompas digital langsung (*real-time magnetometer sensor*) dengan sudut *azimuth* 0–360° dan visualisasi jarum kompas aktif.

5. **Antarmuka Modern & Responsif (Mobile Interface)**
   - Tipografi elegan dengan **Plus Jakarta Sans**.
   - Animasi vektor interaktif berbasis **Lottie**.
   - Simulasi layar mobile (*iPhone frame wrapper*) saat dibuka di browser desktop.

---

## 🛠️ Tech Stack

- **Framework:** Flutter SDK & Dart
- **Database:**
  - Lokal: SQLite (`sqflite`)
  - Server: MySQL / MariaDB (`mysql1`)
- **Sensor & LBS:** `flutter_compass`, `geolocator`, `latlong2`, `flutter_map`
- **Animasi & UI:** `lottie`, `google_fonts`, `lucide_icons`, `cupertino_icons`
- **Web Distribution Server:** Node.js HTTP Server (`tool/serve_web.js`)

---

## 📂 Struktur Direktori

```
sikunjung/
├── android/             # Konfigurasi native Android, Gradle & Proguard
├── assets/              # Animasi Lottie (globe, map_pin, loading) & Gambar
├── lib/
│   ├── main.dart        # Entry point aplikasi
│   ├── screens/         # Tampilan UI (Splash, Login, Dashboard, Peta, Kunjungan)
│   ├── services/        # Service (Auth, SQLite, MySQL, Database, Compass)
│   ├── theme/           # Konfigurasi warna, tipografi, dan tema aplikasi
│   └── widgets/         # Komponen reusable (iPhone frame, textfield, custom button)
├── test/                # Unit test, widget test, dan integration test
├── tool/                # Script utilitas & local server (serve_web.js)
└── web/                 # Konfigurasi PWA & Web entrypoint
```

---

## ⚡ Cara Menjalankan

### 1. Jalankan di Web
```bash
flutter run -d chrome
```
*Atau jalankan server rilis lokal:*
```bash
node tool/serve_web.js
# Buka di browser: http://localhost:5000
```

### 2. Kompilasi APK Android
```bash
flutter build apk --release
# File APK tersedia di: build/app/outputs/flutter-apk/app-release.apk
```

### 3. Menjalankan Seluruh Pengujian (Testing)
```bash
flutter test
```

---

## 👤 Author
- **GitHub:** [@DevAlfiann](https://github.com/DevAlfiann)
