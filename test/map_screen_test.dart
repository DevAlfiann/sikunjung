import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/map_screen.dart';
import 'package:sikunjung/services/app_state.dart';

void main() {
  testWidgets('MapScreen renders essential elements on standard screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: MapScreen(initialOfflineBanner: true)),
    );
    await tester.pumpAndSettle();

    // Verify app bar title
    expect(find.text('Sikunjung'), findsOneWidget);

    // Verify search & notification icons
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    // Verify scope pill
    expect(find.text('Malang Raya (Kota & Batu)'), findsOneWidget);
    expect(find.text('4 Titik Kunjungan Aktif'), findsOneWidget);

    // Verify offline banner
    expect(find.text('Mode Offline Aktif'), findsOneWidget);
    expect(find.text('Coba Hubungkan'), findsOneWidget);

    // Verify destination sheet content
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('Prioritas Tinggi'), findsOneWidget);
    expect(find.text('Navigasi'), findsOneWidget);
    expect(find.text('Rincian'), findsOneWidget);

    // Verify bottom nav items
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Kunjungan'), findsOneWidget);
    expect(find.text('Peta'), findsOneWidget);
  });

  testWidgets('MapScreen renders without overflow on 360px small screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: MapScreen(initialOfflineBanner: true)),
    );
    await tester.pumpAndSettle();

    // Verify essential widgets exist without overflow
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('Navigasi'), findsOneWidget);
  });

  testWidgets('Dismiss offline warning works in MapScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: MapScreen(initialOfflineBanner: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mode Offline Aktif'), findsOneWidget);

    // Tap dismiss icon
    final closeBtn = find.byIcon(Icons.close_rounded);
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Verify offline banner is dismissed
    expect(find.text('Mode Offline Aktif'), findsNothing);
  });

  testWidgets('Navigasi button triggers feedback SnackBar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: MapScreen(initialOfflineBanner: true)),
    );
    await tester.pumpAndSettle();

    // Drag bottom sheet up so action buttons are in view
    await tester.drag(find.text('Toko Berkah Abadi'), const Offset(0, -300));
    await tester.pumpAndSettle();

    final navigasiBtn = find.text('Navigasi');
    expect(navigasiBtn, findsOneWidget);
    await tester.tap(navigasiBtn);
    await tester.pump();

    expect(find.textContaining('Memulai panduan navigasi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // Let SnackBar settle
  });

  testWidgets('MapScreen renders and calculates detailed route for newly added destination', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final newDest = VisitItem(
      id: '#KUN-8825',
      outletName: 'Kios Kopi Kayutangan',
      category: 'FMCG Retail',
      address: 'Jl. Basuki Rahmat No. 12, Klojen, Kota Malang',
      time: 'Hari ini, 14:00 WIB',
      priority: 'Prioritas Tinggi',
      status: 'Sedang Berjalan',
      hasGps: true,
      coordinates: '-7.9790, 112.6300',
      phone: '081234567895',
      task: 'Audit stok promo cold brew',
      distance: '1.2 km',
      eta: 'Est. 5 mnt',
    );
    AppState.instance.addVisit(newDest);

    await tester.pumpWidget(
      MaterialApp(home: MapScreen(targetVisitId: newDest.numericId)),
    );
    await tester.pumpAndSettle();

    // Verify newly added destination appears on the map screen
    expect(find.text('Kios Kopi Kayutangan'), findsWidgets);
    expect(find.text('5 Titik Kunjungan Aktif'), findsOneWidget);
  });
}
