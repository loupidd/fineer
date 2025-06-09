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

  // Define our office locations
  final List<Map<String, dynamic>> officeLocations = [
    {
      "name": "Essence Darmawangsa",
      "lat": -6.25885702739295,
      "long": 106.80418446522982,
    },
    {
      "name": "Nifarro Park",
      "lat": -6.263531780484561,
      "long": 106.84382629294092,
    },
  ];

  // Define radius in meters
  final double officeRadius = 1000.0;

  void changePage(int i) async {
    // Update page index first
    pageIndex.value = i;

    // Handle page navigation based on index
    switch (i) {
      case 1: // Attendance page
        // Don't automatically trigger attendance - just navigate to the page
        Get.offAllNamed(Routes
            .HOME); // Navigate back to home or to a dedicated attendance page
        break;
      case 2: // Overtime page
        Get.offAllNamed(Routes.PROFILE);
        break;
      default: // Home page
        Get.offAllNamed(Routes.HOME);
    }
  }

  // New method to explicitly handle attendance check-in/check-out
  Future<void> processAttendance() async {
    // First get the current position
    Map<String, dynamic> dataResponse = await _determinePosition();

    if (dataResponse["error"] != true) {
      Position position = dataResponse["position"];

      // GeoCoding - Coordinates to Address
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String address =
          " ${placemarks[0].street},${placemarks[0].subLocality},${placemarks[0].locality}";

      // Update user position in database
      await updatePosition(position, address);

      // Check if user is in office and process attendance
      await checkPresenceInOffice(position, address);
    } else {
      Get.snackbar("Terjadi Kesalahan", dataResponse["message"]);
    }
  }

  // Check if user is near any office location
  Future<void> checkPresenceInOffice(Position position, String address) async {
    // Initialize variables to track closest office and distance
    String closestOfficeName = "";
    double shortestDistance = double.infinity;
    bool isInRange = false;

    // Check distance to each office location
    for (var office in officeLocations) {
      double distance = Geolocator.distanceBetween(
        office["lat"],
        office["long"],
        position.latitude,
        position.longitude,
      );

      // Keep track of the closest office
      if (distance < shortestDistance) {
        shortestDistance = distance;
        closestOfficeName = office["name"];
      }

      // If within radius of any office, mark as in range
      if (distance <= officeRadius) {
        isInRange = true;
        break;
      }
    }

    // Proceed with attendance
    await presensi(
      position,
      address,
      shortestDistance,
      isInRange,
      closestOfficeName,
    );
  }

  //Presensi
  Future<void> presensi(
    Position position,
    String address,
    double distance,
    bool isInRange,
    String officeName,
  ) async {
    String uid = await auth.currentUser!.uid;
    CollectionReference<Map<String, dynamic>> colPresence =
        await firestore.collection("pegawai").doc(uid).collection("presence");

    QuerySnapshot<Map<String, dynamic>> snapPresence = await colPresence.get();

    DateTime now = DateTime.now();
    String todayDocID = DateFormat.yMd().format(now).replaceAll("/", "-");

    String status = isInRange ? "Di dalam Area" : "Di luar Area";
    String locationInfo = isInRange
        ? "Lokasi: $officeName (${distance.toStringAsFixed(2)}m)"
        : "Jarak ke lokasi terdekat: ${distance.toStringAsFixed(2)}m ($officeName)";

    if (isInRange) {
      if (snapPresence.docs.isEmpty) {
        //Belum pernah absen
        await Get.defaultDialog(
            title: "Validasi Presensi",
            middleText:
                "Yakin untuk mengisi absen MASUK sekarang?\n$locationInfo",
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
                        "office": officeName,
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
                middleText:
                    "Yakin untuk mengisi absen KELUAR sekarang?\n$locationInfo",
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
                            "office": officeName,
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
              middleText:
                  "Yakin untuk mengisi absen MASUK sekarang?\n$locationInfo",
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
                          "office": officeName,
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
      Get.snackbar(
          "Terjadi Kesalahan", "Diluar Area Pekerjaan ($locationInfo)");
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
