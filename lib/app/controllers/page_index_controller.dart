// ignore_for_file: await_only_futures, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:fineer/app/services/security_logger.dart';
import 'package:fineer/app/services/rate_limiter_service.dart';
import 'package:fineer/app/services/validation_service.dart';
import 'package:fineer/app/services/secure_storage_service.dart';
import 'package:fineer/app/config/environment.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:fineer/app/theme/app_theme.dart';

class PageIndexController extends GetxController {
  RxInt pageIndex = 0.obs;
  RxBool isProcessingAttendance = false.obs;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Office locations — kept from original real code
  final List<Map<String, dynamic>> officeLocations = [
    {
      'name': 'Essence Darmawangsa',
      'lat': -6.25885702739295,
      'long': 106.80418446522982
    },
    {
      'name': 'Nifarro Park',
      'lat': -6.263531780484561,
      'long': 106.84382629294092
    },
  ];
  final double officeRadius = 1000.0;

  // Security counters
  int suspiciousAttempts = 0;
  final int maxSuspiciousAttempts = 3;
  DateTime? lastLocationUpdate;
  Position? lastPosition;
  final int minLocationUpdateInterval = 5;

  // Session
  Timer? _sessionCheckTimer;
  static const _loginTimeKey = 'user_login_timestamp';
  static const _sessionDurationHours = 8;

  // Time thresholds (seconds)
  // ENHANCED: suspicious threshold lowered to 180s (3 min) — previously 600s
  static const _timeDeltaWarning = 120; // 2 min
  static const _timeDeltaSuspicious = 180; // 3 min — BLOCKS attendance

  @override
  void onInit() {
    super.onInit();
    _initializeSession();
    _startSessionMonitoring();
  }

  @override
  void onClose() {
    _sessionCheckTimer?.cancel();
    super.onClose();
  }

  // ── Session management (original logic) ──────────────────────────

  Future<void> _initializeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_loginTimeKey) == null) {
        await _saveLoginTime();
      } else {
        await _checkSessionExpiry();
      }
    } catch (e) {
      log('Session init error: $e');
    }
  }

  Future<void> _saveLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());
  }

  void _startSessionMonitoring() {
    _sessionCheckTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => _checkSessionExpiry());
    _checkSessionExpiry();
  }

  Future<void> _checkSessionExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginStr = prefs.getString(_loginTimeKey);
      if (loginStr == null) {
        await _saveLoginTime();
        return;
      }

      final elapsed = DateTime.now().difference(DateTime.parse(loginStr));
      if (elapsed.inHours >= _sessionDurationHours) {
        await _performAutoLogout();
      }
    } catch (e) {
      log('Session check error: $e');
    }
  }

  Future<void> _performAutoLogout() async {
    _sessionCheckTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTimeKey);
    await auth.signOut();
    Get.offAllNamed(Routes.LOGIN);
    Get.snackbar('session_expired'.tr, 'session_expired_msg'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
        isDismissible: false);
  }

  // ── Navigation ───────────────────────────────────────────────────

  void changePage(int i) {
    switch (i) {
      case 1:
        // Fingerprint center button → attendance action, not navigation
        processAttendance();
        break;
      case 2:
        pageIndex.value = 2;
        Get.offAllNamed(Routes.PROFILE);
        break;
      default:
        pageIndex.value = 0;
        Get.offAllNamed(Routes.HOME);
    }
  }

  // ── TIME MANIPULATION CHECK (ENHANCED) ───────────────────────────
  // Uses Firestore serverTimestamp as ground truth.
  // ENHANCEMENT: "suspicious" level now BLOCKS attendance entirely
  // and logs to suspicious_activities. Previously it only warned.

  Future<Map<String, dynamic>> _validateDeviceTime() async {
    try {
      final uid = auth.currentUser!.uid;
      final deviceTime = DateTime.now();

      final ref = firestore
          .collection('pegawai')
          .doc(uid)
          .collection('time_checks')
          .doc();

      await ref.set({
        'deviceTime': deviceTime.toIso8601String(),
        'serverTime': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
      });

      final snap = await ref.get();
      ref.delete().catchError((_) {});

      final data = snap.data();
      if (data == null || data['serverTime'] == null) {
        return {'ok': true, 'deltaSeconds': 0, 'level': 'unknown'};
      }

      final serverTime = (data['serverTime'] as Timestamp).toDate();
      final deltaSeconds = serverTime.difference(deviceTime).inSeconds.abs();

      log('Time check → device: $deviceTime | server: $serverTime | delta: ${deltaSeconds}s');

      if (deltaSeconds >= _timeDeltaSuspicious) {
        return {
          'ok': false,
          'deltaSeconds': deltaSeconds,
          'level': 'suspicious'
        };
      } else if (deltaSeconds >= _timeDeltaWarning) {
        return {'ok': false, 'deltaSeconds': deltaSeconds, 'level': 'warning'};
      }
      return {'ok': true, 'deltaSeconds': deltaSeconds, 'level': 'normal'};
    } catch (e) {
      log('Time validation error: $e');
      return {'ok': true, 'deltaSeconds': -1, 'level': 'unknown'};
    }
  }

  Future<void> _logTimeManipulation(int delta, String level) async {
    try {
      await firestore
          .collection('pegawai')
          .doc(auth.currentUser!.uid)
          .collection('suspicious_activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'time_manipulation_attempt',
        'deltaSeconds': delta,
        'level': level,
        'deviceTime': DateTime.now().toIso8601String(),
        'deviceInfo': await _getDeviceInfo(),
      });
    } catch (_) {}
  }

  // ── Main attendance flow ─────────────────────────────────────────

  Future<void> processAttendance() async {
    if (isProcessingAttendance.value) {
      Get.snackbar('att_waiting'.tr, '',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2));
      return;
    }

    try {
      isProcessingAttendance.value = true;

      // Show processing dialog
      Get.dialog(
        _ProcessingDialog(message: 'att_processing'.tr),
        barrierDismissible: false,
      );

      // ── 1. TIME CHECK ────────────────────────────────────────────
      final timeCheck = await _validateDeviceTime();
      final timeLevel = timeCheck['level'] as String? ?? 'unknown';
      final timeDelta = timeCheck['deltaSeconds'] as int? ?? 0;

      if (timeLevel == 'suspicious') {
        await _logTimeManipulation(timeDelta, timeLevel);
        if (Get.isDialogOpen ?? false) Get.back();
        // BLOCKS attendance — does NOT write to Firestore
        _showSecurityAlert(
          title: 'sec_time_invalid'.tr,
          message: 'Jam perangkat berbeda $timeDelta detik dari server.\n\n'
              'Absensi DIBATALKAN. Aktifkan "Tanggal & Waktu Otomatis" '
              'di pengaturan perangkat Anda.',
          icon: Icons.access_time_rounded,
        );
        suspiciousAttempts++;
        return;
      }

      if (timeLevel == 'warning') {
        // Log but allow — admin can review
        await _logTimeManipulation(timeDelta, timeLevel);
        log('Time WARNING: ${timeDelta}s — proceeding');
      }

      // ── 2. RATE LIMIT ────────────────────────────────────────────
      if (lastLocationUpdate != null) {
        final elapsed =
            DateTime.now().difference(lastLocationUpdate!).inSeconds;
        if (elapsed < minLocationUpdateInterval) {
          if (Get.isDialogOpen ?? false) Get.back();
          Get.snackbar('Terlalu Cepat', 'Tunggu beberapa detik.',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
      }

      // ── 3. LOCATION ──────────────────────────────────────────────
      final dataResponse = await _determinePositionSecure();
      if (Get.isDialogOpen ?? false) Get.back();

      if (dataResponse['error'] == true) {
        _showSecurityAlert(
          title: 'Lokasi Error',
          message: dataResponse['message'],
          icon: Icons.location_off_rounded,
        );
        return;
      }

      final position = dataResponse['position'] as Position;
      final isMocked = dataResponse['isMocked'] as bool? ?? false;

      if (isMocked) {
        suspiciousAttempts++;
        await _logSuspiciousActivity(position);
        if (suspiciousAttempts >= maxSuspiciousAttempts) {
          _showSecurityAlert(
            title: 'sec_too_fast'.tr,
            message:
                'Terlalu banyak percobaan lokasi palsu. Akun ditinjau admin.',
            icon: Icons.gpp_bad_rounded,
          );
          suspiciousAttempts = 0;
          return;
        }
        _showSecurityAlert(
          title: 'sec_mock_loc'.tr,
          message:
              '${'sec_mock_loc_msg'.tr}\n\nPercobaan: $suspiciousAttempts/$maxSuspiciousAttempts',
          icon: Icons.gpp_bad_rounded,
        );
        return;
      }

      suspiciousAttempts = 0;
      lastLocationUpdate = DateTime.now();
      lastPosition = position;

      // Geocode
      String address = '';
      try {
        final marks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        address =
            '${marks[0].street ?? ''}, ${marks[0].subLocality ?? ''}, ${marks[0].locality ?? ''}';
      } catch (_) {
        address = '${position.latitude}, ${position.longitude}';
      }

      await updatePosition(position, address);
      await checkPresenceInOffice(position, address, timeLevel, timeDelta);
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      _showSecurityAlert(
        title: 'error'.tr,
        message: 'Gagal memproses presensi: $e',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      isProcessingAttendance.value = false;
    }
  }

  Future<void> checkPresenceInOffice(
      Position pos, String address, String timeLevel, int timeDelta) async {
    String closestName = '';
    double shortest = double.infinity;
    bool inRange = false;

    for (final office in officeLocations) {
      final d = Geolocator.distanceBetween(
          office['lat']!, office['long']!, pos.latitude, pos.longitude);
      if (d < shortest) {
        shortest = d;
        closestName = office['name']!;
      }
      if (d <= officeRadius) {
        inRange = true;
        break;
      }
    }

    await presensi(
        pos, address, shortest, inRange, closestName, timeLevel, timeDelta);
  }

  Future<void> presensi(
    Position pos,
    String address,
    double distance,
    bool inRange,
    String officeName,
    String timeLevel,
    int timeDelta,
  ) async {
    try {
      final uid = auth.currentUser!.uid;
      final col =
          firestore.collection('pegawai').doc(uid).collection('presence');
      final now = DateTime.now();
      final docID = DateFormat.yMd().format(now).replaceAll('/', '-');
      final status = inRange ? 'Di dalam Area' : 'Di luar Area';
      final locInfo = inRange
          ? '$officeName\n${distance.toStringAsFixed(0)}m dari kantor'
          : 'Anda ${distance.toStringAsFixed(0)}m dari $officeName';

      if (!inRange) {
        _showSecurityAlert(
          title: 'att_outside'.tr,
          message:
              '${'att_outside_msg'.tr}\n\n$locInfo\n\nMohon datang ke kantor.',
          icon: Icons.location_off_rounded,
          color: FC.error,
        );
        return;
      }

      final todayDoc = await col.doc(docID).get();

      if (!todayDoc.exists) {
        // CHECK-IN
        await _showAttendanceDialog(
          title: 'att_validate'.tr,
          message: '${'att_confirm_in'.tr}\n\n$locInfo',
          isCheckIn: true,
          onConfirm: () async {
            Get.back();
            await col.doc(docID).set({
              'date': now.toIso8601String(),
              'office': officeName,
              'masuk': _buildEntry(now, pos, address, status, distance,
                  officeName, timeDelta, timeLevel),
              'masuk_server_ts': FieldValue.serverTimestamp(),
            });
            _showSuccess('att_success_in'.tr, isIn: true);
          },
        );
        return;
      }

      final d = todayDoc.data()!;

      if (d['keluar'] != null) {
        _showSecurityAlert(
          title: 'Sudah Absen',
          message: 'att_already_done'.tr,
          icon: Icons.check_circle_rounded,
          color: FC.success,
        );
        return;
      }

      if (d['masuk'] == null) {
        _showSecurityAlert(
          title: 'Data Tidak Valid',
          message: 'Data absensi tidak lengkap. Hubungi admin.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }

      // CHECK-OUT time gate: only after 16:30
      final allowed = now.hour > 16 || (now.hour == 16 && now.minute >= 30);
      if (!allowed) {
        final remaining =
            DateTime(now.year, now.month, now.day, 16, 30).difference(now);
        _showSecurityAlert(
          title: 'att_checkout_time'.tr,
          message:
              '${'att_checkout_time_msg'.tr}\n\nWaktu sekarang: ${DateFormat('HH:mm').format(now)} WIB\nSisa: ${remaining.inHours}j ${remaining.inMinutes % 60}m',
          icon: Icons.schedule_rounded,
          color: FC.warning,
        );
        return;
      }

      // CHECK-OUT — also verify server timestamp order
      final masukServerTs = d['masuk_server_ts'];
      if (masukServerTs != null) {
        final masukTs = (masukServerTs as Timestamp).toDate();
        if (now.toUtc().isBefore(masukTs.toUtc())) {
          // Device clock is BEHIND the server-recorded check-in time
          // This means clock was rolled back after check-in
          await _logTimeManipulation(
              masukTs.toUtc().difference(now.toUtc()).inSeconds.abs(),
              'suspicious');
          _showSecurityAlert(
            title: 'sec_time_invalid'.tr,
            message: 'Waktu keluar tidak valid. Jam perangkat lebih awal '
                'dari waktu masuk yang tercatat server.\n\n'
                'Absensi keluar DIBATALKAN.',
            icon: Icons.access_time_rounded,
          );
          return;
        }
      }

      await _showAttendanceDialog(
        title: 'att_validate'.tr,
        message: '${'att_confirm_out'.tr}\n\n$locInfo',
        isCheckIn: false,
        onConfirm: () async {
          Get.back();
          await col.doc(docID).update({
            'keluar': _buildEntry(now, pos, address, status, distance,
                officeName, timeDelta, timeLevel),
            'keluar_server_ts': FieldValue.serverTimestamp(),
          });
          _showSuccess('att_success_out'.tr, isIn: false);
        },
      );
    } catch (e) {
      _showSecurityAlert(
        title: 'error'.tr,
        message: 'Gagal memproses absensi. Coba lagi.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Map<String, dynamic> _buildEntry(
    DateTime t,
    Position p,
    String addr,
    String status,
    double dist,
    String office,
    int timeDelta,
    String timeLevel,
  ) =>
      {
        'date': t.toIso8601String(),
        'lat': p.latitude,
        'long': p.longitude,
        'address': addr,
        'status': status,
        'distance': dist,
        'office': office,
        'accuracy': p.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceTime': t.toIso8601String(),
        'timeDeltaSeconds': timeDelta,
        'timeIntegrityLevel': timeLevel,
      };

  // ── Dialogs (themed) ─────────────────────────────────────────────

  void _showSecurityAlert({
    required String title,
    required String message,
    required IconData icon,
    Color color = FC.error,
  }) {
    final ctx = Get.context;
    final dark = ctx != null && Theme.of(ctx).brightness == Brightness.dark;
    final surf = dark ? FC.cardDark : Colors.white;
    final border = dark ? FC.borderDark : FC.borderLight;
    final tp = dark ? FC.textDark : FC.textLight;
    final ts = dark ? FC.textSecDark : FC.textSecLight;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: dark ? 0.2 : 0.1),
                blurRadius: 28,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: dark ? 0.15 : 0.08),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ts, height: 1.5)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('sec_understand'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _showAttendanceDialog({
    required String title,
    required String message,
    required bool isCheckIn,
    required VoidCallback onConfirm,
  }) async {
    final ctx = Get.context;
    final dark = ctx != null && Theme.of(ctx).brightness == Brightness.dark;
    final surf = dark ? FC.cardDark : Colors.white;
    final border = dark ? FC.borderDark : FC.borderLight;
    final tp = dark ? FC.textDark : FC.textLight;
    final ts = dark ? FC.textSecDark : FC.textSecLight;
    final color = isCheckIn ? FC.blue : FC.success;

    await Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.5 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: dark ? 0.15 : 0.08),
                ),
                child: Icon(
                    isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: color,
                    size: 26),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ts, height: 1.5)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ts,
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text('cancel'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text('yes'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showSuccess(String msg, {required bool isIn}) {
    Get.snackbar(
      'success'.tr,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isIn ? FC.blue : FC.success,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded,
          color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }

  // ── Location validation (original real logic) ─────────────────────

  Future<Map<String, dynamic>> _determinePositionSecure() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return {'message': 'GPS tidak tersedia. Aktifkan lokasi.', 'error': true};
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        return {'message': 'Izinkan GPS untuk melanjutkan.', 'error': true};
      }
    }
    if (perm == LocationPermission.deniedForever) {
      return {
        'message': 'GPS ditolak permanen. Aktifkan di pengaturan.',
        'error': true
      };
    }

    try {
      // Emulator detection
      final di = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final ai = await di.androidInfo;
        if (!ai.isPhysicalDevice ||
            ai.model.toLowerCase().contains('sdk') ||
            ai.product.toLowerCase().contains('sdk') ||
            ai.fingerprint.toLowerCase().contains('generic')) {
          return {
            'message': 'Absensi tidak dapat dilakukan dari emulator.',
            'error': true
          };
        }
      } else if (Platform.isIOS) {
        final ii = await di.iosInfo;
        if (!ii.isPhysicalDevice) {
          return {
            'message': 'Absensi tidak dapat dilakukan dari simulator.',
            'error': true
          };
        }
      }

      // Multi-sample positions for consistency check
      final positions = <Position>[];
      for (int i = 0; i < 3; i++) {
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              timeLimit: Duration(seconds: 5),
            ),
          );
          positions.add(p);
          if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {
          break;
        }
      }
      if (positions.isEmpty) {
        return {
          'message': 'Gagal mendapatkan lokasi. Pastikan GPS aktif.',
          'error': true
        };
      }

      final pos = positions.last;

      // Consistency check
      if (positions.length >= 2) {
        double maxD = 0;
        for (int i = 0; i < positions.length - 1; i++) {
          final d = Geolocator.distanceBetween(
              positions[i].latitude,
              positions[i].longitude,
              positions[i + 1].latitude,
              positions[i + 1].longitude);
          if (d > maxD) maxD = d;
        }
        if (maxD > 100) {
          return {
            'message':
                'Lokasi berubah terlalu cepat (${maxD.toStringAsFixed(0)}m). '
                    'Terdeteksi potensi manipulasi.',
            'error': true,
            'isMocked': true,
          };
        }
      }

      // Speed / accuracy / altitude checks
      if (pos.accuracy > 50) {
        return {
          'message':
              'Akurasi GPS terlalu rendah (${pos.accuracy.toStringAsFixed(0)}m).',
          'error': true
        };
      }
      if (pos.speed > 50) {
        return {
          'message':
              'Kecepatan tidak wajar (${pos.speed.toStringAsFixed(1)} m/s).',
          'error': true
        };
      }
      if (pos.altitude < -500 || pos.altitude > 10000) {
        return {'message': 'Data altitude tidak valid.', 'error': true};
      }
      if (pos.accuracy < 1.0) {
        return {
          'message': 'Akurasi terlalu sempurna — kemungkinan fake GPS.',
          'error': true,
          'isMocked': true
        };
      }
      if (pos.isMocked) {
        return {
          'message': 'Terdeteksi fake GPS / mock location.',
          'error': true,
          'isMocked': true
        };
      }

      return {
        'position': pos,
        'isMocked': false,
        'message': '',
        'error': false
      };
    } catch (e) {
      return {'message': 'Gagal mendapatkan lokasi: $e', 'error': true};
    }
  }

  Future<void> _logSuspiciousActivity(Position pos) async {
    try {
      await firestore
          .collection('pegawai')
          .doc(auth.currentUser!.uid)
          .collection('suspicious_activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'mock_location_attempt',
        'position': {
          'lat': pos.latitude,
          'long': pos.longitude,
          'accuracy': pos.accuracy,
          'isMocked': pos.isMocked,
          'speed': pos.speed,
          'altitude': pos.altitude,
        },
        'deviceInfo': await _getDeviceInfo(),
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final di = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final ai = await di.androidInfo;
        return {
          'platform': 'Android',
          'model': ai.model,
          'manufacturer': ai.manufacturer,
          'version': ai.version.sdkInt,
          'isPhysical': ai.isPhysicalDevice
        };
      } else if (Platform.isIOS) {
        final ii = await di.iosInfo;
        return {
          'platform': 'iOS',
          'model': ii.model,
          'systemVersion': ii.systemVersion,
          'isPhysical': ii.isPhysicalDevice
        };
      }
    } catch (_) {}
    return {'platform': 'unknown'};
  }

  Future<void> updatePosition(Position pos, String address) async {
    try {
      await firestore.collection('pegawai').doc(auth.currentUser!.uid).update({
        'position': {
          'lat': pos.latitude,
          'long': pos.longitude,
          'accuracy': pos.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'address': address,
      });
    } catch (_) {}
  }
}

// ─── Processing dialog ────────────────────────────────────────────

class _ProcessingDialog extends StatelessWidget {
  final String message;
  const _ProcessingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(FC.blue), strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(message,
                style: TextStyle(
                  fontSize: 14,
                  color: dark ? FC.textSecDark : FC.textSecLight,
                )),
          ]),
        ),
      ),
    );
  }
}
