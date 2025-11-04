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

  // Processing flag to prevent double-clicks
  RxBool isProcessingAttendance = false.obs;

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

  // Security: Minimum time between location updates (in seconds)
  final int minLocationUpdateInterval = 5;
  DateTime? lastLocationUpdate;

  void changePage(int i) async {
    // Update page index first
    pageIndex.value = i;

    // Handle page navigation based on index
    switch (i) {
      case 1: // Attendance page
        Get.offAllNamed(Routes.HOME);
        break;
      case 2: // Overtime page
        Get.offAllNamed(Routes.PROFILE);
        break;
      default: // Home page
        Get.offAllNamed(Routes.HOME);
    }
  }

  // Improved method with debouncing and security checks
  Future<void> processAttendance() async {
    // Prevent double-clicks with debouncing
    if (isProcessingAttendance.value) {
      Get.snackbar(
        "Mohon Tunggu",
        "Sedang memproses presensi...",
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      // Set processing flag
      isProcessingAttendance.value = true;

      // Show loading indicator
      Get.dialog(
        const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Memverifikasi lokasi..."),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Security check: Rate limiting for location requests
      if (lastLocationUpdate != null) {
        final timeSinceLastUpdate =
            DateTime.now().difference(lastLocationUpdate!).inSeconds;
        if (timeSinceLastUpdate < minLocationUpdateInterval) {
          Get.back(); // Close loading dialog
          Get.snackbar(
            "Terlalu Cepat",
            "Harap tunggu beberapa detik sebelum mencoba lagi",
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }

      // Get current position with security checks
      Map<String, dynamic> dataResponse = await _determinePositionSecure();

      // Close loading dialog
      Get.back();

      if (dataResponse["error"] != true) {
        Position position = dataResponse["position"];
        bool isMocked = dataResponse["isMocked"] ?? false;

        // Security: Check if location is mocked/fake
        if (isMocked) {
          _showErrorNotification(
            "Lokasi Tidak Valid",
            "Terdeteksi penggunaan lokasi palsu. Mohon gunakan lokasi asli.",
          );
          return;
        }

        // Update last location timestamp
        lastLocationUpdate = DateTime.now();

        // GeoCoding - Coordinates to Address
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        String address = " ${placemarks[0].street},"
            "${placemarks[0].subLocality},"
            "${placemarks[0].locality}";

        // Update user position in database
        await updatePosition(position, address);

        // Check if user is in office and process attendance
        await checkPresenceInOffice(position, address);
      } else {
        Get.snackbar("Terjadi Kesalahan", dataResponse["message"]);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        "Error",
        "Gagal memproses presensi: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      // Reset processing flag after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      isProcessingAttendance.value = false;
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

  // Presensi with improved modals
  Future<void> presensi(
    Position position,
    String address,
    double distance,
    bool isInRange,
    String officeName,
  ) async {
    try {
      String uid = auth.currentUser!.uid;
      CollectionReference<Map<String, dynamic>> colPresence =
          firestore.collection("pegawai").doc(uid).collection("presence");

      DateTime now = DateTime.now();
      String todayDocID = DateFormat.yMd().format(now).replaceAll("/", "-");

      String status = isInRange ? "Di dalam Area" : "Di luar Area";
      String locationInfo = isInRange
          ? "📍 $officeName\n📏 ${distance.toStringAsFixed(0)} meter dari kantor"
          : "⚠️ Anda berada ${distance.toStringAsFixed(0)} meter dari $officeName";

      if (isInRange) {
        DocumentSnapshot<Map<String, dynamic>> todayDoc =
            await colPresence.doc(todayDocID).get();

        if (todayDoc.exists) {
          Map<String, dynamic>? dataPresenceToday = todayDoc.data();

          if (dataPresenceToday?["keluar"] != null) {
            _showErrorNotification(
              "Sudah Absen",
              "Anda telah melakukan absen masuk dan keluar hari ini.",
            );
          } else if (dataPresenceToday?["masuk"] != null) {
            // Check out
            await _showAttendanceDialog(
              title: "Absen Keluar",
              message: "Konfirmasi absen keluar sekarang?\n\n$locationInfo",
              isCheckIn: false,
              onConfirm: () async {
                Get.back(); // Close dialog

                await colPresence.doc(todayDocID).update({
                  "keluar": {
                    "date": now.toIso8601String(),
                    "lat": position.latitude,
                    "long": position.longitude,
                    "address": address,
                    "status": status,
                    "distance": distance,
                    "office": officeName,
                    "accuracy": position.accuracy,
                    "timestamp": FieldValue.serverTimestamp(),
                  }
                });

                _showSuccessNotification(
                  "Absen keluar berhasil dicatat",
                  false,
                );
              },
            );
          }
        } else {
          // Check in
          await _showAttendanceDialog(
            title: "Absen Masuk",
            message: "Konfirmasi absen masuk sekarang?\n\n$locationInfo",
            isCheckIn: true,
            onConfirm: () async {
              Get.back(); // Close dialog

              await colPresence.doc(todayDocID).set({
                "date": now.toIso8601String(),
                "office": officeName,
                "masuk": {
                  "date": now.toIso8601String(),
                  "lat": position.latitude,
                  "long": position.longitude,
                  "address": address,
                  "status": status,
                  "distance": distance,
                  "office": officeName,
                  "accuracy": position.accuracy,
                  "timestamp": FieldValue.serverTimestamp(),
                }
              });

              _showSuccessNotification(
                "Absen masuk berhasil dicatat",
                true,
              );
            },
          );
        }
      } else {
        _showErrorNotification(
          "Di Luar Area Kantor",
          "Anda berada di luar radius kantor.\n\n$locationInfo\n\nMohon datang ke kantor untuk melakukan absen.",
        );
      }
    } catch (e) {
      _showErrorNotification(
        "Terjadi Kesalahan",
        "Gagal memproses absensi. Silakan coba lagi.",
      );
    }
  }

  // Modern attendance dialog with better design
  Future<void> _showAttendanceDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isCheckIn = true,
  }) async {
    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCheckIn
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckIn ? Icons.login : Icons.logout,
                  size: 48,
                  color: isCheckIn ? Colors.blue : Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckIn ? Colors.blue : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Ya, Lanjutkan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // Success notification with animation
  void _showSuccessNotification(String message, bool isCheckIn) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated checkmark
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (isCheckIn ? Colors.blue : Colors.green)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 64,
                        color: isCheckIn ? Colors.blue : Colors.green,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Berhasil!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckIn ? Colors.blue : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Auto close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }

  // Error notification
  void _showErrorNotification(String title, String message) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update Position to Firebase with batch write for better performance
  Future<void> updatePosition(Position position, String address) async {
    try {
      String uid = auth.currentUser!.uid;
      await firestore.collection("pegawai").doc(uid).update({
        "position": {
          "lat": position.latitude,
          "long": position.longitude,
          "accuracy": position.accuracy,
          "timestamp": FieldValue.serverTimestamp(),
        },
        "address": address,
      });
    } catch (e) {
      // Log error but don't block attendance process
      print("Error updating position: $e");
    }
  }
}

// Enhanced Location Permission with Security Checks
Future<Map<String, dynamic>> _determinePositionSecure() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return {
      "message": "GPS tidak tersedia. Mohon aktifkan lokasi.",
      "error": true
    };
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return {"message": "Izinkan GPS untuk melanjutkan", "error": true};
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return {
      "message": "Akses penggunaan GPS ditolak secara permanen. "
          "Mohon aktifkan di pengaturan aplikasi.",
      "error": true
    };
  }

  try {
    // Get position with high accuracy and timeout
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 10), // Add timeout
      ),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception("Timeout mendapatkan lokasi");
      },
    );

    // Security: Check if location is mocked
    bool isMocked = position.isMocked;

    // Additional security: Check accuracy
    // If accuracy is too low, it might be suspicious
    if (position.accuracy > 100) {
      return {
        "message":
            "Akurasi lokasi terlalu rendah (${position.accuracy.toStringAsFixed(0)}m). "
                "Mohon pastikan GPS aktif dan sinyal baik.",
        "error": true
      };
    }

    return {
      "position": position,
      "isMocked": isMocked,
      "message": "Berhasil mendapatkan lokasi device",
      "error": false
    };
  } catch (e) {
    return {"message": "Gagal mendapatkan lokasi: $e", "error": true};
  }
}
