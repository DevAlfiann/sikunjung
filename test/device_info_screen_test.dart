import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/device_info_screen.dart';

void main() {
  testWidgets(
      'DeviceInfoScreen renders only device identity and permission status on standard screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceInfoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header & Sub-header
    expect(find.text('Info Perangkat'), findsOneWidget);
    expect(find.text('Terverifikasi'), findsOneWidget);

    // 2. Verify Device Identity Card (Merek, Model, Operation System)
    expect(find.text('Identitas Perangkat'), findsOneWidget);
    expect(find.text('Merek'), findsOneWidget);
    expect(find.text('Samsung Electronics'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Galaxy A54 5G (SM-A546B/DS)'), findsOneWidget);
    expect(find.text('Operation System'), findsOneWidget);
    expect(find.text('Android 14'), findsOneWidget);

    // 3. Verify Status Izin Card
    expect(find.text('Status Izin'), findsOneWidget);
    expect(find.text('3 Izin Siaga'), findsOneWidget);
    expect(find.text('GPS Presisi & Lokasi'), findsOneWidget);
    expect(find.text('Kamera Dokumentasi'), findsOneWidget);
    expect(find.text('Notifikasi Kunjungan'), findsOneWidget);
    expect(find.text('Diizinkan'), findsNWidgets(3));

    // 4. Verify complex elements are completely removed
    expect(find.text('Diagnostik Hardware & Sistem Operasi'), findsNothing);
    expect(find.text('Linux 5.15-arm64-v8a'), findsNothing);
    expect(find.text('Level 34 (Target SDK 34)'), findsNothing);
    expect(find.text('Kirim Log Diagnostik'), findsNothing);
    expect(find.text('Periksa Pembaruan Aplikasi'), findsNothing);
    expect(find.text('SKJ-UUID-88910-YGY'), findsNothing);
    expect(find.text('Salin'), findsNothing);

    // 5. Verify Bottom Nav
    expect(find.text('Beranda'), findsNWidgets(2)); // One in header, one in bottom nav
    expect(find.text('Kunjungan'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);
  });

  testWidgets(
      'DeviceInfoScreen renders cleanly without overflow on 360px viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceInfoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Info Perangkat'), findsOneWidget);
    expect(find.text('Identitas Perangkat'), findsOneWidget);
    expect(find.text('Status Izin'), findsOneWidget);
  });

  testWidgets('DeviceInfoScreen displays all permission rows with active indicators',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceInfoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS Presisi & Lokasi'), findsOneWidget);
    expect(find.text('Kamera Dokumentasi'), findsOneWidget);
    expect(find.text('Notifikasi Kunjungan'), findsOneWidget);
  });
}
