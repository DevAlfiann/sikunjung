import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'widgets/iphone13_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.splashGradientBottom,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Membuka dan menginisialisasi database sebelum runApp agar tabel siap dipakai
  // oleh halaman login dan kunjungan
  await DatabaseService.instance.init();

  runApp(const SiKunjungApp());
}

class SiKunjungApp extends StatelessWidget {
  const SiKunjungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'SiKunjung',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        if (kIsWeb) {
          return IPhone13Wrapper(child: child ?? const SizedBox());
        }
        return child ?? const SizedBox();
      },
      home: const SplashScreen(),
    );
  }
}
