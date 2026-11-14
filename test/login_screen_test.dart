import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/login_screen.dart';
import 'package:sikunjung/theme/app_theme.dart';

void main() {
  testWidgets('LoginScreen smoke test and interaction test', (WidgetTester tester) async {
    // Provide a standard mobile viewport (390 x 844)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );

    // Initial check
    expect(find.text('Selamat datang kembali'), findsOneWidget);
    expect(find.text('Presensi & Pelacakan Lapangan'), findsOneWidget);
    expect(find.text('SiKunjung'), findsOneWidget);
    expect(find.text('Username / NIP Petugas'), findsOneWidget);
    expect(find.text('Kata Sandi'), findsOneWidget);
    expect(find.text('Ingat Saya'), findsOneWidget);
    expect(find.text('Lupa Sandi?'), findsOneWidget);
    expect(find.text('MASUK SEKARANG'), findsOneWidget);
    expect(find.text('Dilindungi Enkripsi GPS Lapangan'), findsOneWidget);

    // Verify fields are empty initially
    expect(find.text('officer.andi'), findsNothing);
    expect(find.text('admin123'), findsNothing);

    // Enter username & password
    await tester.enterText(find.byType(TextFormField).first, 'officer.andi');
    await tester.enterText(find.byType(TextFormField).last, 'admin123');
    await tester.pump();
    expect(find.text('officer.andi'), findsOneWidget);

    // Tap Login button
    await tester.tap(find.text('MASUK SEKARANG'));
    await tester.pump();
    expect(find.text('Memverifikasi...'), findsOneWidget);

    // Advance time to complete simulated login and snackbars
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('BERHASIL MASUK!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
