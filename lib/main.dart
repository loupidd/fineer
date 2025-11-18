// ignore_for_file: unused_local_variable

import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

//  main() function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  // Initialize Controllers
  final pageC = Get.put(PageIndexController(), permanent: true);

  // Initialize Notification Service
  await Get.putAsync(() => NotificationService().init());

  runApp(const FineerApp());
}

// SplashScreen Class
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
    await Future.delayed(const Duration(seconds: 2));

    // 1. VERSION CHECK
    final supported = await isSupportedVersion();

    if (!supported) {
      _showForceUpdateDialog();
      return; // stop flow
    }

    // 2. SESSION CHECK
    await checkSessionDuration();

    // 3. AUTH CHECK
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      if (user != null) {
        Get.offAllNamed(Routes.HOME);
      } else {
        Get.offAllNamed(Routes.LOGIN);
      }
    });
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // cannot close
      builder: (_) {
        return AlertDialog(
          title: const Text("Update Required"),
          content: const Text(
            "A new version of Fineer is available.\nPlease update the app to continue.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                // If you have no Play Store link, simply close app:
                // SystemNavigator.pop();

                // Or redirect to your internal APK link if you have one:
                // launchUrl(Uri.parse(YOUR_URL));
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Lottie.asset('lib/assets/fineer_lottie.json')),
    );
  }
}

//Main Widget - FineerApp
class FineerApp extends StatelessWidget {
  const FineerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Fineer",
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}

// Login TimeStamp & Duration Logics

Future<void> checkSessionDuration() async {
  final prefs = await SharedPreferences.getInstance();
  final loginTimestamp = prefs.getInt('loginTimestamp') ?? 0;

  if (loginTimestamp == 0) {
    Get.offAllNamed(Routes.LOGIN);
    return;
  }

  final currentTime = DateTime.now().millisecondsSinceEpoch;
  const sessionLimit = 6 * 60 * 60 * 1000; // 6 Hours in milliseconds

  // OverDuration Logics - If user has log in for more than 6 hours
  if ((currentTime - loginTimestamp) > sessionLimit) {
    //SESSION EXPIRED
    await FirebaseAuth.instance.signOut();
    prefs.remove('loginTimestamp');
    Get.snackbar('Sesi Berakhir', 'Silakan Login Kembali');
    Get.offAllNamed(Routes.LOGIN);
  } else {
    // Still in Session Duration
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Get.offAllNamed(Routes.HOME);
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}

//  --------------

// App-Cycle Handling | Foreground and Background

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

    //If the app goes to the foreground, check session
    if (state == AppLifecycleState.resumed) {
      checkSessionDuration(); // Check logging session when app is resumed
    }
  }

  //AppCycle Monitoring

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

Future<bool> isSupportedVersion() async {
  final info = await PackageInfo.fromPlatform();
  final currentVersion = int.parse(info.buildNumber);

  final config =
      await FirebaseFirestore.instance.collection('config').doc('app').get();

  final minVersion = config['min_supported_version_android'];

  return currentVersion >= minVersion;
}
