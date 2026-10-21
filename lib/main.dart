// ignore_for_file: unused_local_variable

import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/services/clock_service.dart';
import 'package:fineer/app/services/locale_service.dart';
import 'package:fineer/app/services/notification_service.dart';
import 'package:fineer/app/services/theme_service.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:fineer/app/translations/app_translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fineer/components/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  // Explicit offline cache: attendance punches made without a connection are
  // queued by the SDK (persisted across restarts) and delivered when online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    // Set system nav bar transparent so AnnotatedRegion in each screen
    // can control the color per-screen without a leftover grey strip
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // Make the navigation bar fully transparent so Flutter draws behind it
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Services — permanent so they survive navigation
  await Get.putAsync(() => ThemeService().init(), permanent: true);
  await Get.putAsync(() => LocaleService().init(), permanent: true);
  Get.put(PageIndexController(), permanent: true);
  Get.put(NotificationService(), permanent: true);

  runApp(const FineerApp());
}

// ─── App root ─────────────────────────────────────────────────────

class FineerApp extends StatelessWidget {
  const FineerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = Get.find<ThemeService>();
    final ls = Get.find<LocaleService>();

    return Obx(() => GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Fineer',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ts.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          locale: ls.locale.value,
          fallbackLocale: const Locale('id', 'ID'),
          translations: AppTranslations(),
          initialRoute: Routes.SPLASH,
          getPages: AppPages.routes,
        ));
  }
}

// ─── Splash screen ────────────────────────────────────────────────
// Preserves original flow: lottie → version check → session check → auth

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 2400));

    // Seed the trusted-clock anchor (best effort, never blocks boot).
    ClockService.seed();

    // 1. Version check
    final supported = await isSupportedVersion();
    if (!supported) {
      _showForceUpdateDialog();
      return;
    }

    // 2. Session check (6-hour limit)
    await checkSessionDuration();
  }

  void _showForceUpdateDialog() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FC.blue.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: FC.blue, size: 28),
            ),
            const SizedBox(height: 16),
            Text('version_update'.tr,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('version_update_msg'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? FC.textSecDark : FC.textSecLight,
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {}, // add Play Store URL here
                child: const Text('Update'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? FC.bgDark : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie plays the real fineer_lottie.json animation
            Lottie.asset(
              'lib/assets/fineer_lottie.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              repeat: false,
              frameRate: FrameRate.max,
              errorBuilder: (_, __, ___) => Image.asset(
                'lib/assets/logo.webp',
                width: 100,
                height: 100,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [FC.blue, FC.blueDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.fingerprint,
                      color: Colors.white, size: 44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Fineer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? FC.yellow : FC.blue,
                  letterSpacing: -1,
                )),
            const SizedBox(height: 4),
            Text('by TripleS',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? FC.textTerDark : FC.textTerLight,
                )),
            const SizedBox(height: 40),
            SizedBox(
              width: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: isDark ? FC.borderDark : FC.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? FC.yellow : FC.blue),
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Session check — identical to original ───────────────────────

Future<void> checkSessionDuration() async {
  final prefs = await SharedPreferences.getInstance();
  final loginTimestamp = prefs.getInt('loginTimestamp') ?? 0;

  if (loginTimestamp == 0) {
    // No session clock yet. If Firebase still has a signed-in user (login
    // happened before the clock was written, or prefs were cleared), resume
    // the session and start the clock instead of forcing a new login.
    if (FirebaseAuth.instance.currentUser != null) {
      await prefs.setInt(
          'loginTimestamp', DateTime.now().millisecondsSinceEpoch);
      Get.offAllNamed(Routes.HOME);
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
    return;
  }

  final currentTime = DateTime.now().millisecondsSinceEpoch;
  const sessionLimit = 6 * 60 * 60 * 1000; // 6 hours

  if ((currentTime - loginTimestamp) > sessionLimit &&
      (await ClockService.check()).online) {
    // (when offline, expiry is deferred so staff aren't locked out)
    final hadUser = FirebaseAuth.instance.currentUser != null;
    await FirebaseAuth.instance.signOut();
    prefs.remove('loginTimestamp');
    // Only tell the user their session ended if they were actually signed in.
    if (hadUser) {
      AppToast.session('session_expired'.tr, 'session_expired_msg'.tr);
    }
    Get.offAllNamed(Routes.LOGIN);
  } else {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Get.offAllNamed(Routes.HOME);
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}

// ─── Version check — identical to original ───────────────────────

Future<bool> isSupportedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final current = int.parse(info.buildNumber);
    final config =
        await FirebaseFirestore.instance.collection('config').doc('app').get();
    final minVersion = config['min_supported_version_android'] as int? ?? 0;
    return current >= minVersion;
  } catch (_) {
    return true; // fail open — don't block users on config error
  }
}

// ─── App lifecycle — identical to original ───────────────────────

class AppLifecycleObserver extends StatefulWidget {
  const AppLifecycleObserver({super.key});
  @override
  AppLifecycleObserverState createState() => AppLifecycleObserverState();
}

class AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      checkSessionDuration();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
