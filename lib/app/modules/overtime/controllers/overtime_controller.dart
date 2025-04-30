import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;
FirebaseAuth auth = FirebaseAuth.instance;

class OvertimeController extends GetxController {
  TextEditingController nameC = TextEditingController();
  TextEditingController waktuC = TextEditingController();
  TextEditingController tanggalC = TextEditingController();
  TextEditingController desC = TextEditingController();

  void addLembur() async {
    String uid = auth.currentUser!.uid;
    DateTime now = DateTime.now();
    String todayDocID = DateFormat.yMd().format(now).replaceAll("/", "-");
    CollectionReference<Map<String, dynamic>> colLembur =
        firestore.collection("pegawai").doc(uid).collection("lembur");

    if (nameC.text.isNotEmpty &&
        waktuC.text.isNotEmpty &&
        tanggalC.text.isNotEmpty &&
        desC.text.isNotEmpty) {
      await colLembur.doc(todayDocID).set({
        "nama": nameC.text,
        "waktu": waktuC.text,
        "tanggal": tanggalC.text,
        "deskripsi": desC.text
      });
      Get.toNamed(Routes.HOME);

      Get.snackbar("Berhasil", "Data Lembur Telah Diisi");
    } else {
      Get.back();
      Get.snackbar("Terjadi Kesalahan", "Data Harus diisi");
    }
  }

  void prosesAddLembur() async {
    await Get.defaultDialog(
        title: "Validasi Lembur",
        middleText: "Yakin untuk mengisi Lembur?",
        actions: [
          OutlinedButton(
              onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                addLembur();
              },
              child: const Text("Yes"))
        ]);
  }
}
