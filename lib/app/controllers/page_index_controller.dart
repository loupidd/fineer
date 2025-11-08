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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer';

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
  Position? lastPosition;

  // Track consecutive suspicious attempts
  int suspiciousAttempts = 0;
  final int maxSuspiciousAttempts = 3;

  // Auto-logout timer - check every minute
  Timer? _sessionCheckTimer;
  static const String _loginTimeKey = 'user_login_timestamp';
  static const int _sessionDurationHours = 8;

  @override
  void onInit() {
    super.onInit();
    _initializeSession();
    _startSessionMonitoring();
  }

  Future<void> _initializeSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? loginTimeStr = prefs.getString(_loginTimeKey);

      if (loginTimeStr == null) {
        // First time after login, save current time
        await _saveLoginTime();
      } else {
        // Check if session has expired
        await _checkSessionExpiry();
      }
    } catch (e) {
      log("Error initializing session: $e");
    }
  }

  Future<void> _saveLoginTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String currentTime = DateTime.now().toIso8601String();
      await prefs.setString(_loginTimeKey, currentTime);
      log("Login time saved: $currentTime");
    } catch (e) {
      log("Error saving login time: $e");
    }
  }

  void _startSessionMonitoring() {
    // Check session every minute
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkSessionExpiry();
    });

    // Also check immediately
    _checkSessionExpiry();
  }

  Future<void> _checkSessionExpiry() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? loginTimeStr = prefs.getString(_loginTimeKey);

      if (loginTimeStr == null) {
        // No login time found, save current time
        await _saveLoginTime();
        return;
      }

      DateTime loginTime = DateTime.parse(loginTimeStr);
      DateTime now = DateTime.now();
      Duration sessionDuration = now.difference(loginTime);

      log("Session duration: ${sessionDuration.inHours} hours ${sessionDuration.inMinutes % 60} minutes");

      // Check if 8 hours have passed
      if (sessionDuration.inHours >= _sessionDurationHours) {
        log("Session expired! Logging out...");
        await _performAutoLogout();
      }
    } catch (e) {
      log("Error checking session expiry: $e");
    }
  }

  Future<void> _performAutoLogout() async {
    try {
      // Cancel the timer
      _sessionCheckTimer?.cancel();

      // Clear login time
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginTimeKey);

      // Sign out from Firebase
      await auth.signOut();

      // Navigate to login
      Get.offAllNamed(Routes.LOGIN);

      // Show notification
      Get.snackbar(
        "Sesi Berakhir",
        "Anda telah otomatis keluar setelah 8 jam. Silakan login kembali.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        isDismissible: false,
      );
    } catch (e) {
      log("Error during auto logout: $e");
    }
  }

  void changePage(int i) async {
    pageIndex.value = i;

    switch (i) {
      case 1:
        Get.offAllNamed(Routes.HOME);
        break;
      case 2:
        Get.offAllNamed(Routes.PROFILE);
        break;
      default:
        Get.offAllNamed(Routes.HOME);
    }
  }

  Future<void> processAttendance() async {
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
      isProcessingAttendance.value = true;

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

      if (lastLocationUpdate != null) {
        final timeSinceLastUpdate =
            DateTime.now().difference(lastLocationUpdate!).inSeconds;
        if (timeSinceLastUpdate < minLocationUpdateInterval) {
          Get.back();
          Get.snackbar(
            "Terlalu Cepat",
            "Harap tunggu beberapa detik sebelum mencoba lagi",
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }

      Map<String, dynamic> dataResponse = await _determinePositionSecure();

      Get.back();

      if (dataResponse["error"] != true) {
        Position position = dataResponse["position"];
        bool isMocked = dataResponse["isMocked"] ?? false;

        if (isMocked) {
          suspiciousAttempts++;

          if (suspiciousAttempts >= maxSuspiciousAttempts) {
            _showErrorNotification(
              "Terlalu Banyak Percobaan",
              "Terdeteksi terlalu banyak percobaan menggunakan lokasi palsu. Akun Anda akan ditinjau oleh admin.",
            );
            // Log suspicious activity
            await _logSuspiciousActivity(position);
            suspiciousAttempts = 0;
            return;
          }

          _showErrorNotification(
            "Lokasi Tidak Valid",
            "Terdeteksi penggunaan lokasi palsu. Mohon gunakan lokasi asli.\n\nPercobaan: $suspiciousAttempts/$maxSuspiciousAttempts",
          );
          return;
        }

        // Reset suspicious attempts on success
        suspiciousAttempts = 0;
        lastLocationUpdate = DateTime.now();
        lastPosition = position;

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        String address = " ${placemarks[0].street ?? ''},"
            "${placemarks[0].subLocality ?? ''},"
            "${placemarks[0].locality ?? ''}";

        await updatePosition(position, address);
        await checkPresenceInOffice(position, address);
      } else {
        Get.snackbar("Terjadi Kesalahan", dataResponse["message"]);
      }
    } catch (e) {
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
      await Future.delayed(const Duration(milliseconds: 500));
      isProcessingAttendance.value = false;
    }
  }

  Future<void> _logSuspiciousActivity(Position position) async {
    try {
      String uid = auth.currentUser!.uid;
      await firestore
          .collection("pegawai")
          .doc(uid)
          .collection("suspicious_activities")
          .add({
        "timestamp": FieldValue.serverTimestamp(),
        "type": "mock_location_attempt",
        "position": {
          "lat": position.latitude,
          "long": position.longitude,
          "accuracy": position.accuracy,
          "isMocked": position.isMocked,
          "speed": position.speed,
          "altitude": position.altitude,
        },
        "deviceInfo": await _getDeviceInfo(),
      });
    } catch (e) {
      // Logging failed, continue
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return {
          "platform": "Android",
          "model": androidInfo.model,
          "manufacturer": androidInfo.manufacturer,
          "version": androidInfo.version.sdkInt,
          "isPhysicalDevice": androidInfo.isPhysicalDevice,
          "androidId": androidInfo.id,
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return {
          "platform": "iOS",
          "model": iosInfo.model,
          "name": iosInfo.name,
          "systemVersion": iosInfo.systemVersion,
          "isPhysicalDevice": iosInfo.isPhysicalDevice,
          "identifierForVendor": iosInfo.identifierForVendor,
        };
      }
    } catch (e) {
      // Device info failed
    }
    return {"platform": "unknown"};
  }

  Future<void> checkPresenceInOffice(Position position, String address) async {
    String closestOfficeName = "";
    double shortestDistance = double.infinity;
    bool isInRange = false;

    for (var office in officeLocations) {
      double distance = Geolocator.distanceBetween(
        office["lat"],
        office["long"],
        position.latitude,
        position.longitude,
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        closestOfficeName = office["name"];
      }

      if (distance <= officeRadius) {
        isInRange = true;
        break;
      }
    }

    await presensi(
      position,
      address,
      shortestDistance,
      isInRange,
      closestOfficeName,
    );
  }

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
          ? "$officeName\n ${distance.toStringAsFixed(0)} meter dari kantor"
          : "Anda berada ${distance.toStringAsFixed(0)} meter dari $officeName";

      // First, check if user is in range
      if (!isInRange) {
        _showErrorNotification(
          "Di Luar Area Kantor",
          "Anda berada di luar radius kantor.\n\n$locationInfo\n\nMohon datang ke kantor untuk melakukan absen.",
        );
        return;
      }

      // User is in range, now check attendance status
      DocumentSnapshot<Map<String, dynamic>> todayDoc =
          await colPresence.doc(todayDocID).get();

      if (!todayDoc.exists) {
        // No record for today - this must be check-in
        await _showAttendanceDialog(
          title: "Absen Masuk",
          message: "Konfirmasi absen masuk sekarang?\n\n$locationInfo",
          isCheckIn: true,
          onConfirm: () async {
            Get.back();

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
        return;
      }

      // Document exists, check the status
      Map<String, dynamic>? dataPresenceToday = todayDoc.data();

      // Check if user has already checked out
      if (dataPresenceToday?["keluar"] != null) {
        _showErrorNotification(
          "Sudah Absen",
          "Anda telah melakukan absen masuk dan keluar hari ini.",
        );
        return;
      }

      // Check if user has checked in
      if (dataPresenceToday?["masuk"] == null) {
        // This shouldn't happen, but handle it anyway
        _showErrorNotification(
          "Data Tidak Valid",
          "Data absensi tidak lengkap. Silakan hubungi admin.",
        );
        return;
      }

      // User has checked in but not checked out yet - allow check-out
      // Check if it's before 17:00 WIB
      int currentHour = now.hour;
      int currentMinute = now.minute;

      if (currentHour < 17) {
        int hoursRemaining = 16 - currentHour;
        int minutesRemaining = 60 - currentMinute;

        _showErrorNotification(
          "Belum Waktunya Absen Keluar",
          "Anda hanya dapat absen keluar setelah pukul 17:00 WIB.\n\n"
              "Waktu sekarang: ${DateFormat('HH:mm').format(now)} WIB\n"
              "Sisa waktu: $hoursRemaining jam $minutesRemaining menit",
        );
        return;
      }

      // Time is after 17:00, allow check-out
      await _showAttendanceDialog(
        title: "Absen Keluar",
        message: "Konfirmasi absen keluar sekarang?\n\n$locationInfo",
        isCheckIn: false,
        onConfirm: () async {
          Get.back();

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
    } catch (e) {
      _showErrorNotification(
        "Terjadi Kesalahan",
        "Gagal memproses absensi. Silakan coba lagi.",
      );
    }
  }

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

    Future.delayed(const Duration(seconds: 2), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }

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
      // Position update failed, don't block attendance
    }
  }

  // Enhanced Location Security using only Geolocator and device_info_plus
  Future<Map<String, dynamic>> _determinePositionSecure() async {
    bool serviceEnabled;
    LocationPermission permission;

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
      // SECURITY CHECK 1: Check if running on emulator
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        bool isPhysicalDevice = true;

        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          isPhysicalDevice = androidInfo.isPhysicalDevice;

          // Additional check for common emulator indicators
          if (!isPhysicalDevice ||
              androidInfo.model.toLowerCase().contains('sdk') ||
              androidInfo.product.toLowerCase().contains('sdk') ||
              androidInfo.fingerprint.toLowerCase().contains('generic') ||
              (androidInfo.manufacturer.toLowerCase() == 'google' &&
                  androidInfo.model.toLowerCase().contains('emulator'))) {
            return {
              "message": "Absensi tidak dapat dilakukan dari emulator. "
                  "Mohon gunakan perangkat fisik.",
              "error": true
            };
          }
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          isPhysicalDevice = iosInfo.isPhysicalDevice;

          if (!isPhysicalDevice) {
            return {
              "message": "Absensi tidak dapat dilakukan dari simulator. "
                  "Mohon gunakan perangkat fisik.",
              "error": true
            };
          }
        }
      } catch (e) {
        // Device check failed, continue without blocking
      }

      // SECURITY CHECK 2: Get multiple position samples for validation
      List<Position> positions = [];

      for (int i = 0; i < 3; i++) {
        try {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              timeLimit: Duration(seconds: 5),
            ),
          );
          positions.add(pos);

          if (i < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          // Failed to get position, continue with what we have
          break;
        }
      }

      if (positions.isEmpty) {
        return {
          "message": "Gagal mendapatkan lokasi. Pastikan GPS aktif.",
          "error": true
        };
      }

      Position position = positions.last;

      // SECURITY CHECK 3: Built-in mock detection
      bool isMocked = position.isMocked;

      // SECURITY CHECK 4: Validate position consistency
      if (positions.length >= 2) {
        double maxDistance = 0;
        for (int i = 0; i < positions.length - 1; i++) {
          double distance = Geolocator.distanceBetween(
            positions[i].latitude,
            positions[i].longitude,
            positions[i + 1].latitude,
            positions[i + 1].longitude,
          );
          if (distance > maxDistance) {
            maxDistance = distance;
          }
        }

        // If positions vary by more than 100 meters in 1 second, suspicious
        if (maxDistance > 100) {
          return {
            "message":
                "Lokasi berubah terlalu cepat (${maxDistance.toStringAsFixed(0)}m). "
                    "Terdeteksi potensi manipulasi lokasi.",
            "error": true,
            "isMocked": true
          };
        }
      }

      // SECURITY CHECK 5: Compare with last known position
      if (lastPosition != null && lastLocationUpdate != null) {
        final timeDiff =
            DateTime.now().difference(lastLocationUpdate!).inSeconds;
        final distance = Geolocator.distanceBetween(
          lastPosition!.latitude,
          lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Calculate maximum possible distance based on time (assuming car speed)
        final maxPossibleDistance = timeDiff * 30; // 30 m/s = ~108 km/h

        if (distance > maxPossibleDistance && timeDiff < 300) {
          return {
            "message":
                "Jarak perpindahan tidak wajar (${distance.toStringAsFixed(0)}m dalam ${timeDiff}s). "
                    "Terdeteksi potensi lokasi palsu.",
            "error": true,
            "isMocked": true
          };
        }
      }

      // SECURITY CHECK 6: Accuracy validation
      if (position.accuracy > 50) {
        return {
          "message":
              "Akurasi lokasi terlalu rendah (${position.accuracy.toStringAsFixed(0)}m). "
                  "Mohon pastikan GPS aktif dan sinyal baik. "
                  "Coba pindah ke area terbuka.",
          "error": true
        };
      }

      // SECURITY CHECK 7: Speed check (detect unnatural movement)
      if (position.speed > 50) {
        return {
          "message":
              "Kecepatan pergerakan tidak wajar terdeteksi (${position.speed.toStringAsFixed(1)} m/s). "
                  "Mohon tunggu beberapa saat dan coba lagi saat tidak bergerak.",
          "error": true
        };
      }

      // SECURITY CHECK 8: Altitude check (detect unrealistic altitude)
      if (position.altitude < -500 || position.altitude > 10000) {
        return {
          "message":
              "Data lokasi tidak valid. Altitude: ${position.altitude.toStringAsFixed(0)}m. "
                  "Mohon restart GPS Anda.",
          "error": true
        };
      }

      // SECURITY CHECK 9: Check for suspiciously perfect accuracy
      if (position.accuracy < 1.0) {
        return {
          "message":
              "Akurasi lokasi terlalu sempurna (${position.accuracy.toStringAsFixed(2)}m). "
                  "Ini mungkin indikasi fake GPS. Mohon tunggu hingga GPS stabil.",
          "error": true,
          "isMocked": true
        };
      }

      // SECURITY CHECK 10: Final mock validation
      if (isMocked) {
        return {
          "message": "Terdeteksi penggunaan aplikasi fake GPS/mock location. "
              "Mohon nonaktifkan aplikasi fake GPS dan gunakan lokasi sebenarnya.",
          "error": true,
          "isMocked": true
        };
      }

      return {
        "position": position,
        "isMocked": false,
        "message": "Berhasil mendapatkan lokasi device",
        "error": false
      };
    } catch (e) {
      return {"message": "Gagal mendapatkan lokasi: $e", "error": true};
    }
  }

  @override
  void onClose() {
    // Cancel session monitoring timer when controller is disposed
    _sessionCheckTimer?.cancel();
    super.onClose();
  }
}
