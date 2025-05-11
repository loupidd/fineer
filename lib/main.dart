// ignore_for_file: unused_local_variable

import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

//  main() function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();

  final pageC = Get.put(PageIndexController(), permanent: true);

  runApp(const FineerApp());
}

// SplashScreen Class
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () async {
      // checkSessionDuration before authState
      await checkSessionDuration();

      FirebaseAuth.instance.authStateChanges().first.then((user) {
        if (user != null) {
          Get.offAllNamed(Routes.HOME);
        } else {
          Get.offAllNamed(Routes.LOGIN);
        }
      });
    });

    return Scaffold(
      body: Center(
        child: Lottie.asset('lib/assets/fineer_lottie.json'),
      ),
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
