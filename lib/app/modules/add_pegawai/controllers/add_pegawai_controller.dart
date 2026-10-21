// ignore_for_file: unnecessary_overrides, prefer_const_constructors, unused_local_variable, unnecessary_string_interpolations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fineer/components/app_toast.dart';

class AddPegawaiController extends GetxController {
  TextEditingController nameC = TextEditingController();
  TextEditingController nikC = TextEditingController();
  TextEditingController emailC = TextEditingController();
  TextEditingController passAdminC = TextEditingController();
  TextEditingController jobC = TextEditingController();
  TextEditingController siteC = TextEditingController();
  TextEditingController roleC = TextEditingController();
  final isLoading = false.obs;

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> prosesAddPegawai() async {
    if (passAdminC.text.isNotEmpty) {
      try {
        String emailAdmin = auth.currentUser!.email!;

        UserCredential userCredentialAdmin =
            await auth.signInWithEmailAndPassword(
          email: emailAdmin,
          password: passAdminC.text,
        );

        UserCredential pegawaiCredential =
            await auth.createUserWithEmailAndPassword(
                email: emailC.text, password: "password");

        if (pegawaiCredential.user != null) {
          String uid = pegawaiCredential.user!.uid;

          await firestore.collection('pegawai').doc(uid).set({
            "nik": nikC.text,
            "name": nameC.text,
            "email": emailC.text,
            "uid": uid,
            "role": roleC.text,
            "site": siteC.text,
            "job": jobC.text,
            "createdAt": DateTime.now().toIso8601String(),
          });

          //current User Sign Out
          await auth.signOut();

          userCredentialAdmin = await auth.signInWithEmailAndPassword(
              email: emailAdmin, password: passAdminC.text);
          Get.back(); // Tutup dialog
          Get.back(); //Back to home
          AppToast.success("Berhasil", "Berhasil menambahkan pegawai");
          //Relogin

          //await auth.signInWithEmailAndPassword(email: email, password: password)
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          AppToast.error("Terjadi Kesalahan", 'Password terlalu lemah');
        } else if (e.code == 'email-already-in-use') {
          AppToast.error("Terjadi Kesalahan", 'Email Sudah Terdaftar');
        } else if (e.code == 'Wrong-password') {
          AppToast.error('Terjadi Kesalahan', 'Password Salah');
        } else {
          AppToast.error('Terjadi Kesalahan', '${e.code}');
        }
      } catch (e) {
        AppToast.error("Terjadi Kesalahan", 'Coba Kembali');
      }
    } else {
      AppToast.error('Terjadi Kesalahan', 'Password Wajib Diisi');
    }
  }

  void addPegawai() async {
    if (nameC.text.isNotEmpty &&
        nikC.text.isNotEmpty &&
        emailC.text.isNotEmpty &&
        jobC.text.isNotEmpty &&
        siteC.text.isNotEmpty) {
      Get.defaultDialog(
          title: " Validasi Admin",
          content: Column(
            children: [
              Text("Masukan Password Untuk Validasi Admin"),
              TextField(
                controller: passAdminC,
                autocorrect: false,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              )
            ],
          ),
          actions: [
            OutlinedButton(
                onPressed: () => Get.back(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await prosesAddPegawai();
              },
              child: const Text('ADD PEGAWAI'),
            ),
          ]);
    } else {
      AppToast.error("Terjadi Kesalahan", 'Semua Data Harus Diisi');
    }
  }
}
