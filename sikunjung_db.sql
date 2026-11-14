-- ==============================================================
-- Database SiKunjung Mobile (Sistem Informasi Kunjungan Lapangan)
-- Dibuat untuk XAMPP MySQL (MariaDB)
-- Host: 127.0.0.1 | Port: 3306 | User: root
-- ==============================================================

CREATE DATABASE IF NOT EXISTS `sikunjung_db` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `sikunjung_db`;

-- -------------------------------------------------------------
-- 1. Tabel Petugas (Officers / Users)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `officers`;
CREATE TABLE `officers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `nip` VARCHAR(20) NOT NULL UNIQUE,
  `username` VARCHAR(50) NOT NULL UNIQUE,
  `name` VARCHAR(100) NOT NULL,
  `password_hash` VARCHAR(64) NOT NULL COMMENT 'SHA-256 Hash',
  `role` ENUM('officer', 'supervisor', 'admin') DEFAULT 'officer',
  `phone` VARCHAR(20) DEFAULT NULL,
  `email` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Password default 'admin123' di-hash SHA-256
-- SHA256('admin123') = 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO `officers` (`id`, `nip`, `username`, `name`, `password_hash`, `role`, `phone`, `email`) VALUES
(1, 'PK-0482', 'officer.andi', 'Andi Pratama, S.Kom', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'officer', '081234567890', 'andi.pratama@sikunjung.id'),
(2, 'PK-0483', 'officer.budi', 'Budi Santoso', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'officer', '081234567801', 'budi.santoso@sikunjung.id'),
(3, 'SPV-0101', 'supervisor.siti', 'Siti Rahmawati', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'supervisor', '081234567802', 'siti.rahma@sikunjung.id');

-- -------------------------------------------------------------
-- 2. Tabel Outlet / Toko / Pelanggan
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `outlets`;
CREATE TABLE `outlets` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `code` VARCHAR(20) NOT NULL UNIQUE,
  `name` VARCHAR(150) NOT NULL,
  `short_name` VARCHAR(50) NOT NULL,
  `category` VARCHAR(50) NOT NULL,
  `address` TEXT NOT NULL,
  `phone` VARCHAR(20) DEFAULT NULL,
  `latitude` DECIMAL(10, 7) NOT NULL,
  `longitude` DECIMAL(10, 7) NOT NULL,
  `operating_hours` VARCHAR(50) DEFAULT 'Buka s/d 21:00',
  `traffic_info` VARCHAR(100) DEFAULT 'Lalu lintas lancar',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `outlets` (`id`, `code`, `name`, `short_name`, `category`, `address`, `phone`, `latitude`, `longitude`, `operating_hours`, `traffic_info`) VALUES
(1, 'OUT-001', 'Toko Berkah Abadi', 'Toko Berkah', 'FMCG Retail', 'Jl. Malioboro No. 42, Danurejan, Kota Yogyakarta (Sebelah Barat Pasar Beringharjo)', '081234567891', -7.7928000, 110.3658000, 'Buka s/d 21:00', 'Lalu lintas cerah • Jalan utama'),
(2, 'OUT-002', 'Surya Mart Mandiri', 'Surya Mart', 'Minimarket', 'Jl. Gejayan No. 18, Sleman, Yogyakarta (Dekat SPBU)', '081234567892', -7.7712000, 110.3892000, 'Buka 24 Jam', 'Lalu lintas lancar'),
(3, 'OUT-003', 'UD. Sumber Rejeki', 'Sumber Rejeki', 'Grosir Sembako', 'Jl. Kaliurang Km 5.5, Depok, Sleman', '081234567893', -7.7600000, 110.3820000, 'Buka s/d 17:00', 'Padat merayap simpang Kentungan'),
(4, 'OUT-004', 'Apotek Sehat Farma', 'Apotek Sehat', 'Kesehatan / Farma', 'Jl. Solo Km 9, Kalasan, Sleman', '081234567894', -7.7810000, 110.4350000, 'Buka s/d 22:00', 'Lancar jalur bandara'),
(5, 'OUT-005', 'Koperasi Warga Makmur', 'Koperasi Makmur', 'Koperasi Retail', 'Jl. Wonosari Km 4, Banguntapan, Bantul', '081234567895', -7.8120000, 110.4050000, 'Buka s/d 16:30', 'Lalu lintas normal'),
(6, 'OUT-006', 'Toko Kelontong Bu Sari', 'Toko Bu Sari', 'Toko Tradisional', 'Jl. Magelang Km 6, Mlati, Sleman', '081234567896', -7.7420000, 110.3620000, 'Buka s/d 20:00', 'Lalu lintas ramai lancar'),
(7, 'OUT-007', 'Minimarket Prima Indah', 'Prima Indah', 'Minimarket Lokal', 'Jl. Palagan Tentara Pelajar, Ngaglik, Sleman', '081234567897', -7.7280000, 110.3780000, 'Buka s/d 22:00', 'Lalu lintas lancar'),
(8, 'OUT-008', 'Warung Madura 24 Jam', 'Warung Madura', 'Kelontong Modern', 'Jl. Seturan Raya No. 5, Caturtunggal, Depok, Sleman', '081234567898', -7.7780000, 110.4120000, 'Buka 24 Jam', 'Lalu lintas ramai');

-- -------------------------------------------------------------
-- 3. Tabel Kunjungan (Visits)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `visits`;
CREATE TABLE `visits` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `visit_code` VARCHAR(20) NOT NULL UNIQUE,
  `outlet_id` INT NOT NULL,
  `officer_id` INT NOT NULL,
  `task` TEXT NOT NULL,
  `priority` VARCHAR(30) NOT NULL DEFAULT 'Reguler',
  `status` ENUM('Belum Dikunjungi', 'Sedang Berjalan', 'Pending Sync', 'Selesai') DEFAULT 'Belum Dikunjungi',
  `scheduled_date` DATE NOT NULL,
  `scheduled_time` VARCHAR(30) NOT NULL,
  `distance` VARCHAR(20) DEFAULT NULL,
  `eta` VARCHAR(20) DEFAULT NULL,
  `has_gps` TINYINT(1) DEFAULT 1,
  `checkin_lat` DECIMAL(10, 7) DEFAULT NULL,
  `checkin_lng` DECIMAL(10, 7) DEFAULT NULL,
  `checkin_time` TIMESTAMP NULL DEFAULT NULL,
  `checkout_time` TIMESTAMP NULL DEFAULT NULL,
  `notes` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`outlet_id`) REFERENCES `outlets`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`officer_id`) REFERENCES `officers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `visits` (`id`, `visit_code`, `outlet_id`, `officer_id`, `task`, `priority`, `status`, `scheduled_date`, `scheduled_time`, `distance`, `eta`, `has_gps`, `checkin_lat`, `checkin_lng`, `checkin_time`, `checkout_time`, `notes`) VALUES
(1, '#KUN-8821', 1, 1, 'Pengiriman faktur tagihan & audit stok display', 'Prioritas Tinggi', 'Selesai', CURDATE(), 'Hari ini, 10:15 WIB', '850 m', 'Est. 4 mnt', 1, -7.7928000, 110.3658000, '2026-11-13 10:15:00', '2026-11-13 10:45:00', 'Faktur diterima lunas oleh kasir utama.'),
(2, '#KUN-8822', 2, 1, 'Restock produk unggulan & pemasangan banner promosi', 'Reguler', 'Sedang Berjalan', CURDATE(), 'Hari ini, 11:30 WIB', '1.8 km', 'Est. 9 mnt', 1, -7.7712000, 110.3892000, '2026-11-13 11:32:00', NULL, 'Sedang dalam proses pemasangan standing banner.'),
(3, '#KUN-8823', 3, 1, 'Pengecekan piutang tempo & rekonsiliasi order lokal', 'Perhatian', 'Pending Sync', CURDATE(), 'Hari ini, 13:00 WIB', '3.2 km', 'Est. 15 mnt', 1, -7.7600000, 110.3820000, '2026-11-13 13:05:00', '2026-11-13 13:40:00', 'Data menunggu sinkronisasi batch lokal.'),
(4, '#KUN-8824', 4, 1, 'Pengantaran suplemen paket kuartal & tanda tangan PO', 'Jadwal Siang', 'Belum Dikunjungi', CURDATE(), 'Jadwal: 15:30 WIB', '4.5 km', 'Est. 25 mnt', 1, NULL, NULL, NULL, NULL, NULL),
(5, '#KUN-8825', 5, 1, 'Audit display rak depan & cek ketersediaan stok', 'Normal', 'Belum Dikunjungi', CURDATE(), 'Jadwal: 16:00 WIB', '5.1 km', 'Est. 28 mnt', 1, NULL, NULL, NULL, NULL, NULL),
(6, '#KUN-8826', 6, 1, 'Pengambilan retur barang cacat kemasan', 'Normal', 'Belum Dikunjungi', CURDATE(), 'Jadwal: 16:45 WIB', '6.3 km', 'Est. 32 mnt', 1, NULL, NULL, NULL, NULL, NULL),
(7, '#KUN-8827', 7, 1, 'Konfirmasi pesanan PO mingguan & tandatangan faktur', 'Normal', 'Belum Dikunjungi', CURDATE(), 'Jadwal: 17:30 WIB', '7.0 km', 'Est. 36 mnt', 1, NULL, NULL, NULL, NULL, NULL),
(8, '#KUN-8828', 8, 1, 'Penawaran program promo akhir pekan', 'Normal', 'Belum Dikunjungi', CURDATE(), 'Jadwal: 18:15 WIB', '2.4 km', 'Est. 12 mnt', 1, NULL, NULL, NULL, NULL, NULL);

-- -------------------------------------------------------------
-- 4. Tabel Notifikasi (Notifications)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `notifications`;
CREATE TABLE `notifications` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `officer_id` INT NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `message` TEXT NOT NULL,
  `time_ago` VARCHAR(50) DEFAULT 'Baru saja',
  `icon` VARCHAR(30) DEFAULT 'bell',
  `is_read` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`officer_id`) REFERENCES `officers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `notifications` (`id`, `officer_id`, `title`, `message`, `time_ago`, `icon`, `is_read`) VALUES
(1, 1, 'Rute Kunjungan Diperbarui', 'Supervisor telah menetapkan rute optimal wilayah Sleman.', '10 mnt lalu', 'route', 0),
(2, 1, 'GPS Terkunci Presisi', 'Satelit GLONASS & GPS siap untuk audit geotagging.', '25 mnt lalu', 'gps', 0),
(3, 1, 'Pengingat Target Harian', 'Selesaikan 6 kunjungan sebelum pukul 17:00 WIB.', '1 jam lalu', 'target', 1);

-- -------------------------------------------------------------
-- 5. Tabel Log GPS Pelacakan (GPS Audit Logs)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `gps_logs`;
CREATE TABLE `gps_logs` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `officer_id` INT NOT NULL,
  `latitude` DECIMAL(10, 7) NOT NULL,
  `longitude` DECIMAL(10, 7) NOT NULL,
  `accuracy` FLOAT DEFAULT NULL,
  `speed` FLOAT DEFAULT NULL,
  `battery_level` INT DEFAULT NULL,
  `is_mock` TINYINT(1) DEFAULT 0,
  `recorded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`officer_id`) REFERENCES `officers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `gps_logs` (`officer_id`, `latitude`, `longitude`, `accuracy`, `speed`, `battery_level`, `is_mock`) VALUES
(1, -7.7828000, 110.3670000, 4.2, 18.5, 85, 0),
(1, -7.7850000, 110.3665000, 3.8, 22.1, 84, 0),
(1, -7.7928000, 110.3658000, 2.5, 0.0, 83, 0);

