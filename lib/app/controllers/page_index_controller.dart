// ignore_for_file: await_only_futures, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/modules/home/views/home_view.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class PageIndexController extends GetxController {
  RxInt pageIndex = 0.obs;

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  void changePage(int i) async {
    pageIndex.value = i;
    switch (i) {
      //absensi
      case 1:
        Map<String, dynamic> dataResponse = await _determinePosition();
        if (dataResponse["error"] != true) {
          Position position = dataResponse["position"];

          //GeoCoding - Coordinates to Address
          List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude, position.longitude);
          String address =
              " ${placemarks[0].street},${placemarks[0].subLocality},${placemarks[0].locality}";
          await updatePosition(position, address);

          //check distance between 2 position
          double distance = Geolocator.distanceBetween(
              -6.25791, 106.80538, position.latitude, position.longitude);

          //Presensi
          await presensi(
            position,
            address,
            distance,
          );
        } else {
          Get.snackbar("Terjadi Kesalahan", dataResponse["message"]);
        }

        break;
      case 2:
        pageIndex.value = i;
        Get.offAllNamed(Routes.OVERTIME);
        break;
      default:
        pageIndex.value - i;
        Get.offAllNamed(Routes.HOME);
    }
  }

  //Presensi

  Future<void> presensi(
    Position position,
    String address,
    double distance,
  ) async {
    String uid = await auth.currentUser!.uid;
    CollectionReference<Map<String, dynamic>> colPresence =
        await firestore.collection("pegawai").doc(uid).collection("presence");

    QuerySnapshot<Map<String, dynamic>> snapPresence = await colPresence.get();

    DateTime now = DateTime.now();
    String todayDocID = DateFormat.yMd().format(now).replaceAll("/", "-");

    String status = "Di luar Area";

    if (distance <= 15) {
      status = "Di dalam Area";

      if (snapPresence.docs.isEmpty) {
        //Belum pernah absen

        await Get.defaultDialog(
            title: "Validasi Presensi",
            middleText: "Yakin untuk mengisi absen MASUK sekarang?",
            actions: [
              OutlinedButton(
                  onPressed: () => Get.back(), child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () async {
                    await colPresence.doc(todayDocID).set({
                      "date": now.toIso8601String(),
                      "masuk": {
                        "date": now.toIso8601String(),
                        "lat": position.latitude,
                        "long": position.longitude,
                        "address": address,
                        "status": status,
                        "distance": distance,
                      }
                    });
                    Get.back();
                    Get.snackbar(
                        "Berhasil", "Kamu berhasil mengisi Absen MASUK");
                  },
                  child: const Text("Yes"))
            ]);
      } else {
        //Sudah Pernah Absen -> Cek hari ini sudah absen masuk/keluar
        DocumentSnapshot<Map<String, dynamic>> todayDoc =
            await colPresence.doc(todayDocID).get();

        if (todayDoc.exists == true) {
          //Absen Keluar / Sudah absen masuk & keluar
          Map<String, dynamic>? dataPresenceToday = todayDoc.data();
          if (dataPresenceToday?["keluar"] != null) {
            //Sudah Absen masuk & Keluar
            Get.snackbar("Peringatan", "Kamu telah absen masuk dan keluar");
          } else {
            //absen keluar
            await Get.defaultDialog(
                title: "Validasi Presensi",
                middleText: "Yakin untuk mengisi absen KELUAR sekarang?",
                actions: [
                  OutlinedButton(
                      onPressed: () => Get.back(), child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                        await colPresence.doc(todayDocID).update({
                          "keluar": {
                            "date": now.toIso8601String(),
                            "lat": position.latitude,
                            "long": position.longitude,
                            "address": address,
                            "status": status,
                            "distance": distance,
                          }
                        });
                        Get.back();
                        Get.snackbar(
                            "Berhasil", "Kamu berhasil mengisi Absen KELUAR");
                      },
                      child: const Text("Yes"))
                ]);
          }
        } else {
          //absen masuk
          await Get.defaultDialog(
              title: "Validasi Presensi",
              middleText: "Yakin untuk mengisi absen MASUK sekarang?",
              actions: [
                OutlinedButton(
                    onPressed: () => Get.back(), child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () async {
                      await colPresence.doc(todayDocID).set({
                        "date": now.toIso8601String(),
                        "masuk": {
                          "date": now.toIso8601String(),
                          "lat": position.latitude,
                          "long": position.longitude,
                          "address": address,
                          "status": status,
                          "distance": distance,
                        }
                      }, SetOptions(merge: true));
                      Get.back();
                      Get.snackbar(
                          "Berhasil", "Kamu berhasil mengisi Absen MASUK");
                    },
                    child: const Text("Yes"))
              ]);
        }
      }
    } else {
      Get.back();
      Get.snackbar("Terjadi Kesalahan", "Diluar Area Pekekerjaan");
    }
  }

  //Update Position to Firebase
  Future<void> updatePosition(Position position, String address) async {
    String uid = await auth.currentUser!.uid;
    await firestore.collection("pegawai").doc(uid).update({
      "position": {"lat": position.latitude, "long": position.longitude},
      "address": address,
    });
  }
}

//Location Permission - Geolocator Code
Future<Map<String, dynamic>> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return {"message": "GPS tidak tersedia", "error": true};
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return {"message": "Izinkan GPS untuk melanjutkan", "error": true};
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return {"message": "Akses penggunaan GPS ditolak", "error": true};
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  Position position = await Geolocator.getCurrentPosition(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  );
  return {
    "position": position,
    "message": "Berhasil mendapatkan lokasi device",
    "error": false
  };
}
