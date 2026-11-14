import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/sensors_screen.dart';

void main() {
  testWidgets('SensorsScreen renders all essential elements on standard screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SensorsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header & Sub-Header
    expect(find.text('Sikunjung Peta Operasional'), findsOneWidget);
    expect(find.text('GPS Akurat - 3m'), findsOneWidget);
    expect(find.text('Pembacaan Aktif (50Hz)'), findsOneWidget);
    expect(find.text('Diagnostik Hardware'), findsOneWidget);

    // 2. Verify Hero Card
    expect(find.text('Kompas & Orientasi'), findsOneWidget);
    expect(find.text('Aksis Real-Time 3D'), findsOneWidget);
    expect(find.text('Presisi'), findsOneWidget);
    expect(find.text('45°'), findsOneWidget);
    expect(find.text('Timur Laut (NE)'), findsOneWidget);
    expect(find.text('Akurasi'), findsOneWidget);
    expect(find.text('Kemiringan Pitch'), findsOneWidget);
    expect(find.text('Rotasi Roll'), findsOneWidget);
    expect(find.text('Kalibrasi Kompas (Pola Angka 8)'), findsOneWidget);

    // 3. Verify Telemetry Section
    expect(find.text('Data Telemetri'), findsOneWidget);
    expect(find.text('3 Aktif • 1 Tidak Aktif'), findsOneWidget);

    // 4. Verify 4 Telemetry Cards
    expect(find.text('Akselerometer'), findsOneWidget);
    expect(find.text('Total: 9.81 m/s²'), findsOneWidget);

    expect(find.text('Giroskop'), findsOneWidget);
    expect(find.text('Dinamis'), findsOneWidget);

    expect(find.text('Magnetometer'), findsOneWidget);
    expect(find.text('48.2 µT (Ideal)'), findsOneWidget);

    expect(find.text('Sensor Barometer'), findsOneWidget);
    expect(find.text('Hardware Tidak Terpasang'), findsOneWidget);
    expect(find.textContaining('GPS Barometrik Fallback Aktif'), findsOneWidget);

    // 5. Verify Bottom Nav
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Kunjungan'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);
  });

  testWidgets('SensorsScreen renders cleanly without overflow on 360px viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SensorsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kompas & Orientasi'), findsOneWidget);
    expect(find.text('Data Telemetri'), findsOneWidget);
    expect(find.text('Akselerometer'), findsOneWidget);
  });

  testWidgets('Compass calibration triggers animation and success state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SensorsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final calibrateBtn = find.text('Kalibrasi Kompas (Pola Angka 8)');
    expect(calibrateBtn, findsOneWidget);

    // Tap button to trigger calibration
    await tester.tap(calibrateBtn);
    await tester.pump(const Duration(milliseconds: 300));

    // Fast-forward animation to complete
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    // Verify success feedback
    expect(find.textContaining('Kalibrasi kompas selesai'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // Let SnackBar and timer settle
  });

  testWidgets('Calibrate-all sync button triggers full telemetry calibration',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SensorsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final syncBtn = find.byIcon(Icons.sync_rounded);
    expect(syncBtn, findsOneWidget);

    await tester.tap(syncBtn);
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.textContaining('Semua sensor hardware'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // Let SnackBar settle
  });
}

