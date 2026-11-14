import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/network_screen.dart';

void main() {
  testWidgets('NetworkScreen renders all simplified elements on standard screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header & Subheader
    expect(find.text('Status Jaringan'), findsOneWidget);
    expect(find.text('Perbarui'), findsOneWidget);
    expect(find.text('Protokol: IPv4/v6'), findsOneWidget);

    // 2. Verify Hero Card: Active Network Connection & Reconnect Button
    expect(find.text('WiFi – Terhubung'), findsOneWidget);
    expect(find.text('SSID: Kantor-Operasional-5G'), findsOneWidget);
    expect(find.text('192.168.1.142'), findsOneWidget);
    expect(find.text('Uji Sambungan Ulang'), findsOneWidget);

    // 3. Verify Network Adapters Card (WiFi & Data Seluler only)
    expect(find.text('Antarmuka Jaringan Aktif'), findsOneWidget);
    expect(find.text('WiFi (5 GHz)'), findsOneWidget);
    expect(find.text('Data Seluler'), findsOneWidget);
    expect(find.text('Ethernet LAN'), findsNothing);
    expect(find.text('Tunnel VPN'), findsNothing);

    // 4. Verify complex elements are removed
    expect(find.text('Simulasi Varian Offline'), findsNothing);
    expect(find.text('Fitur yang Memerlukan Koneksi'), findsNothing);
    expect(find.text('Tabel Kecepatan Jaringan'), findsNothing);
    expect(find.text('Unduh Paket Peta Offline (Jawa Barat)'), findsNothing);

    // 5. Verify Bottom Nav
    expect(find.text('Beranda'), findsNWidgets(2));
    expect(find.text('Kunjungan'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);
  });

  testWidgets('NetworkScreen renders cleanly without overflow on 360px viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status Jaringan'), findsOneWidget);
    expect(find.text('WiFi – Terhubung'), findsOneWidget);
    expect(find.text('Antarmuka Jaringan Aktif'), findsOneWidget);
  });

  testWidgets('Test connection button triggers latency test and success state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final testBtn = find.text('Uji Sambungan Ulang');
    expect(testBtn, findsOneWidget);

    await tester.tap(testBtn);
    await tester.pump(const Duration(milliseconds: 300));

    // Fast forward to complete latency test
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();

    expect(find.textContaining('Sambungan Stabil'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // Let SnackBar settle
  });

  testWidgets('Perbarui button triggers connection probe',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final refreshBtn = find.text('Perbarui');
    expect(refreshBtn, findsOneWidget);

    await tester.tap(refreshBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();

    expect(find.text('Status Jaringan'), findsOneWidget);
  });
}
