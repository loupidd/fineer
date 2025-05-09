// ignore_for_file: unused_local_variable

import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginController extends GetxController {
  RxBool isLoading = false.obs;
  TextEditingController emailC = TextEditingController();
  TextEditingController passC = TextEditingController();

  FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> login() async {
    if (emailC.text.isNotEmpty && passC.text.isNotEmpty) {
      isLoading.value = true;

      try {
        UserCredential userCredential = await auth.signInWithEmailAndPassword(
            email: emailC.text, password: passC.text);

        //Login Timestamp
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

        //Login Logics
        Get.offAllNamed(Routes.HOME);
      } on FirebaseAuthException catch (e) {
        //Firebase Error handling
        isLoading.value = false;
        Get.back();

        if (e.code == 'user-not-found') {
          Get.snackbar('Terjadi Kesalahan', 'User tidak ditemukan');
        } else if (e.code == 'wrong-password') {
          Get.snackbar('Terjadi Kesalahan', 'Password Salah');
        } else {
          Get.snackbar('Terjadi Kesalahan', 'Tidak Dapat Login');
        }
      } catch (e) {
        isLoading.value = false; // Reset Login State
        Get.back();
        Get.snackbar(('Terjadi Kesalahan'), 'Tidak Dapat Login');
      }
    } else {
      // Error ifEmpty
      isLoading.value = false;
      Get.back();
      Get.snackbar('Terjadi Kesalahan', 'Email & Password harus diisi');
    }
  }
}
