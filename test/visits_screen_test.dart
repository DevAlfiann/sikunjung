import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/visits_screen.dart';
import 'package:sikunjung/theme/app_theme.dart';

void main() {
  testWidgets('VisitsScreen smoke test on standard mobile screen (390x844)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const VisitsScreen(),
      ),
    );

    // Sub-header
    expect(find.text('Daftar Kunjungan'), findsOneWidget);
    expect(find.text('8 Tugas Aktif'), findsOneWidget);

    // Filter Chips
    expect(find.text('Semua (8)'), findsOneWidget);
    expect(find.text('Hari Ini (5)'), findsOneWidget);
    expect(find.text('Selesai (2)'), findsOneWidget);
    expect(find.text('Tertunda (1)'), findsOneWidget);
    expect(find.text('Ada GPS'), findsOneWidget);

    // Segmented toggle
    expect(find.text('Daftar Tugas (8)'), findsOneWidget);
    expect(find.text('Pratinjau Kosong'), findsOneWidget);

    // Visit Cards
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
    expect(find.text('Surya Mart Mandiri'), findsOneWidget);
    expect(find.text('UD. Sumber Rejeki'), findsOneWidget);
    expect(find.text('Apotek Sehat Farma'), findsOneWidget);

    // FAB
    expect(find.text('Tambah Kunjungan'), findsOneWidget);

    // Tap Pratinjau Kosong toggle
    await tester.tap(find.text('Pratinjau Kosong'));
    await tester.pump();
    expect(find.text('Belum ada kunjungan'), findsOneWidget);
    expect(find.text('Segarkan Data'), findsOneWidget);

    // Switch back to active tasks
    await tester.tap(find.text('Daftar Tugas (8)'));
    await tester.pump();
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);

    // Tap filter chip
    await tester.tap(find.text('Hari Ini (5)'));
    await tester.pump();

    // Tap FAB to open modal
    await tester.tap(find.text('Tambah Kunjungan'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Kunjungan Baru'), findsOneWidget);
    expect(find.text('Simpan Kunjungan'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Simpan Kunjungan'));
    await tester.pumpAndSettle();
  });

  testWidgets('VisitsScreen small screen test (360x640) - no overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const VisitsScreen(),
      ),
    );

    expect(find.text('Daftar Kunjungan'), findsOneWidget);
    expect(find.text('Toko Berkah Abadi'), findsOneWidget);
  });
}

