import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/dashboard_screen.dart';
import 'package:sikunjung/theme/app_theme.dart';

void main() {
  testWidgets('DashboardScreen smoke test on standard mobile screen (390x844)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(agentName: 'admin'),
      ),
    );

    // Header & Greeting Banner
    expect(find.text('SIKUNJUNG MOBILE'), findsOneWidget);
    expect(find.text('Beranda'), findsNWidgets(2)); // in header and bottom nav
    expect(find.text('Halo, admin'), findsOneWidget);
    expect(find.text('GPS Aktif • Akurasi 3m'), findsOneWidget);
    expect(find.text('11 Satelit'), findsOneWidget);

    // Stat Cards
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Ada GPS'), findsOneWidget);
    expect(find.text('124'), findsOneWidget);

    // Menu Utama
    expect(find.text('Menu Utama'), findsOneWidget);
    expect(find.text('Tambah Kunjungan'), findsOneWidget);
    expect(find.text('Daftar Kunjungan'), findsOneWidget);
    expect(find.text('Peta Lokasi'), findsOneWidget);
    expect(find.text('Kompas & Sensor'), findsOneWidget);
    expect(find.text('Status Jaringan'), findsOneWidget);
    expect(find.text('Info Perangkat'), findsOneWidget);

    // Kunjungan Terbaru
    expect(find.text('Kunjungan Terbaru'), findsOneWidget);
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('Surya Mart Mandiri'), findsOneWidget);
    expect(find.text('UD. Sumber Rejeki'), findsOneWidget);

    // Target Harian
    expect(find.text('Target Harian'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);

    // Bottom Navigation
    expect(find.text('Kunjungan'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);

    // Tap Bottom Navigation tab
    await tester.tap(find.text('Peta'));
    await tester.pump();
  });

  testWidgets('DashboardScreen small screen test (360x640) - no overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(agentName: 'admin'),
      ),
    );

    // Ensure it renders smoothly on 360 width
    expect(find.text('Halo, admin'), findsOneWidget);
    expect(find.text('Menu Utama'), findsOneWidget);
  });
}

