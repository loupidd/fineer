// ignore_for_file: unused_local_variable

import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:lottie/lottie.dart';

//  main() function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final pageC = Get.put(PageIndexController(), permanent: true);

  runApp(const FineerApp());
}

// SplashScreen Class
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
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
        scaffoldBackgroundColor: Colors.white, // 👈 Set global background
      ),
    );
  }
}
