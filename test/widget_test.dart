import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/screens/splash_screen.dart';
import 'package:sikunjung/theme/app_theme.dart';

void main() {
  testWidgets('SplashScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SplashScreen(autoNavigate: false),
      ),
    );
    expect(find.text('Si Kunjung'), findsOneWidget);
    expect(find.text('Sistem Informasi Kunjungan Lapangan'), findsOneWidget);
    expect(find.text('V2.4 PRO LAPANGAN'), findsNothing);
    expect(find.text('PRO LAPANGAN'), findsNothing);
  });
}
