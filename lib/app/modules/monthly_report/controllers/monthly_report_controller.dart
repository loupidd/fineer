// lib/app/modules/monthly_report/controllers/monthly_report_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart'
    hide Border, BorderStyle; // Fix for ambiguous import

class MonthlyReportController extends GetxController {
  // Observable variables
  final isLoading = false.obs;
  final downloadSuccess = false.obs;
  final downloadPath = ''.obs;
  final errorMessage = ''.obs;
  final dataStats = RxMap<String, dynamic>({});

  // Date range selection
  final Rx<DateTime> selectedStartDate = DateTime.now().obs;
  final Rx<DateTime> selectedEndDate = DateTime.now().obs;

  // Date variables
  final DateTime now = DateTime.now();
  late final DateTime defaultStartDate;
  late final DateTime defaultEndDate;

  @override
  void onInit() {
    super.onInit();
    _initializeDates();
  }

  void _initializeDates() {
    // Set default date range for reporting
    // Default to previous month if current day is <= 20
    // Otherwise use current month
    if (now.day <= 20) {
      final prevMonth = DateTime(now.year, now.month - 1);
      defaultStartDate = DateTime(prevMonth.year, prevMonth.month, 21);
      defaultEndDate = DateTime(now.year, now.month, 20);
    } else {
      defaultStartDate = DateTime(now.year, now.month, 21);
      defaultEndDate = DateTime(now.year, now.month + 1, 20);
    }

    // Initialize selected dates with defaults
    selectedStartDate.value = defaultStartDate;
    selectedEndDate.value = defaultEndDate;
  }

  String getDateRangeText() {
    final formatter = DateFormat('dd MMMM yyyy');
    return '${formatter.format(selectedStartDate.value)} - ${formatter.format(selectedEndDate.value)}';
  }

  // Method to update date range
  Future<void> updateDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: Get.context!,
      initialDateRange: DateTimeRange(
        start: selectedStartDate.value,
        end: selectedEndDate.value,
      ),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      selectedStartDate.value = picked.start;
      selectedEndDate.value = picked.end;

      // Clear previous report data when date range changes
      dataStats.clear();
      downloadSuccess.value = false;
      downloadPath.value = '';
    }
  }

  Future<void> generateMonthlyAttendanceReport() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      downloadSuccess.value = false;
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount <= maxRetries) {
        try {
          // Check and request permissions based on platform
          Get.snackbar(
            'Memeriksa Izin',
            'Memeriksa izin penyimpanan...',
            backgroundColor: Colors.blue.withAlpha((0.5 * 255).round()),
            colorText: Colors.white,
            duration: const Duration(seconds: 1),
          );

          bool permissionsGranted = await _checkAndRequestPermissions();

          if (!permissionsGranted) {
            // If permissions are still not granted after requesting
            errorMessage.value =
                'Izin penyimpanan ditolak. Harap berikan izin penyimpanan untuk menyimpan laporan.';

            if (retryCount < maxRetries) {
              retryCount++;
              Get.snackbar(
                'Mencoba Kembali',
                'Mencoba kembali ($retryCount/$maxRetries)...',
                backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
              await Future.delayed(Duration(seconds: 1));
              continue;
            }

            Get.snackbar(
              'Izin Diperlukan',
              'Aplikasi memerlukan izin penyimpanan untuk menyimpan laporan Excel.',
              backgroundColor: Colors.orange.withAlpha((0.7 * 255).round()),
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
              mainButton: TextButton(
                onPressed: () async {
                  // Try to open app settings
                  await openAppSettings();
                },
                child: Text(
                  'Buka Pengaturan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
            break;
          }

          // Show progress update
          Get.snackbar(
            'Memproses',
            'Mengambil data kehadiran...',
            backgroundColor: Colors.blue.withAlpha((0.5 * 255).round()),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );

          // Fetch data based on selected date range
          await _fetchAttendanceData();

          // Show progress update
          Get.snackbar(
            'Memproses',
            'Membuat file Excel...',
            backgroundColor: Colors.blue.withAlpha((0.5 * 255).round()),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );

          // Generate actual report file with retry mechanism
          String? filePath;
          Exception? saveError;

          for (int attempt = 0; attempt < 3; attempt++) {
            try {
              filePath = await _generateExcelFile();
              saveError = null;
              break;
            } catch (e) {
              debugPrint('Error saving file (attempt ${attempt + 1}): $e');
              saveError = e is Exception ? e : Exception(e.toString());

              if (attempt < 2) {
                Get.snackbar(
                  'Mencoba Ulang',
                  'Mencoba menyimpan file kembali (${attempt + 1}/3)...',
                  backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
                await Future.delayed(Duration(seconds: 1));
              }
            }
          }

          if (filePath != null) {
            downloadSuccess.value = true;
            downloadPath.value = filePath;

            // Verify the file actually exists
            final file = File(filePath);
            if (await file.exists()) {
              Get.snackbar(
                'Sukses',
                'Laporan berhasil disimpan ke: $filePath',
                backgroundColor: Colors.green.withAlpha((0.7 * 255).round()),
                colorText: Colors.white,
                duration: const Duration(seconds: 5),
              );
            } else {
              throw Exception(
                  'File created but not found at expected location');
            }
          } else if (saveError != null) {
            throw saveError;
          }

          // Break out of retry loop on success
          break;
        } catch (e) {
          debugPrint('Error generating report: $e');
          String errorMsg = e.toString();

          // Provide more user-friendly error messages
          if (errorMsg.contains('permission')) {
            errorMsg =
                'Aplikasi tidak memiliki izin untuk menyimpan file. Periksa pengaturan aplikasi.';
          } else if (errorMsg.contains('path')) {
            errorMsg =
                'Tidak dapat menemukan lokasi penyimpanan yang valid. Pastikan penyimpanan tersedia.';
          } else if (errorMsg.contains('write')) {
            errorMsg =
                'Tidak dapat menulis ke penyimpanan. Pastikan ada cukup ruang.';
          } else if (errorMsg.contains('not found')) {
            errorMsg =
                'File tidak dapat ditemukan setelah penyimpanan. Mungkin terhalang oleh pembatasan sistem.';
          }

          errorMessage.value = 'Gagal membuat laporan: $errorMsg';
          downloadSuccess.value = false;

          if (retryCount < maxRetries) {
            retryCount++;
            Get.snackbar(
              'Mencoba Kembali',
              'Mencoba membuat laporan kembali ($retryCount/$maxRetries)...',
              backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
            await Future.delayed(Duration(seconds: 2));
            continue;
          }

          Get.snackbar(
            'Error',
            errorMessage.value,
            backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          break;
        }
      }
    } catch (e) {
      // Final catch for any unexpected errors
      debugPrint('Unexpected error in generateMonthlyAttendanceReport: $e');
      errorMessage.value =
          'Terjadi kesalahan yang tidak terduga: ${e.toString()}';
      downloadSuccess.value = false;

      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Helper method to check and request necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    debugPrint('Checking storage permissions...');

    // For iOS and other platforms, we don't need explicit storage permissions for app-specific directories
    if (!Platform.isAndroid) {
      debugPrint(
          'Non-Android platform detected, no explicit permissions needed');
      return true;
    }

    try {
      // Permission check is implemented below, no need for duplicate check here

      // First try the storage permission (this works for most Android versions)
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        debugPrint('Requesting storage permission...');
        storageStatus = await Permission.storage.request();

        // If storage permission is granted, that's usually enough
        if (storageStatus.isGranted) {
          debugPrint('Storage permission granted');
          return true;
        } else if (storageStatus.isPermanentlyDenied) {
          debugPrint('Storage permission permanently denied');
          // Inform the user they need to enable permissions in settings
          Get.snackbar(
            'Izin Diperlukan',
            'Izin penyimpanan ditolak secara permanen. Harap aktifkan di pengaturan aplikasi.',
            backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
            colorText: Colors.white,
            duration: Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: Text(
                'Pengaturan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      } else {
        // Storage permission already granted
        debugPrint('Storage permission already granted');
        return true;
      }

      // For Android 11+ (API level 30+), we also need MANAGE_EXTERNAL_STORAGE permission
      // For older versions, we need WRITE_EXTERNAL_STORAGE permission

      // Try manage external storage permission (Android 11+)
      try {
        // First try the more permissive MANAGE_EXTERNAL_STORAGE permission
        var externalStorageStatus =
            await Permission.manageExternalStorage.status;
        debugPrint('MANAGE_EXTERNAL_STORAGE status: $externalStorageStatus');

        if (!externalStorageStatus.isGranted) {
          // Show explanation before requesting the permission
          Get.snackbar(
            'Izin Tambahan',
            'Untuk penyimpanan laporan, aplikasi memerlukan izin penyimpanan eksternal.',
            backgroundColor: Colors.blue.withAlpha((0.7 * 255).round()),
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );

          // Request the permission
          externalStorageStatus =
              await Permission.manageExternalStorage.request();
          if (externalStorageStatus.isGranted) {
            debugPrint('MANAGE_EXTERNAL_STORAGE granted');
            return true;
          } else {
            debugPrint(
                'MANAGE_EXTERNAL_STORAGE denied: $externalStorageStatus');
          }
        } else {
          // External storage permission already granted
          debugPrint('MANAGE_EXTERNAL_STORAGE already granted');
          return true;
        }
      } catch (e) {
        debugPrint('Error requesting MANAGE_EXTERNAL_STORAGE permission: $e');
      }

      // Try write external storage permission (older Android versions)
      try {
        var writeStorageStatus = await Permission.storage.status;
        debugPrint('WRITE_EXTERNAL_STORAGE status: $writeStorageStatus');

        if (!writeStorageStatus.isGranted) {
          writeStorageStatus = await Permission.storage.request();
          if (writeStorageStatus.isGranted) {
            debugPrint('WRITE_EXTERNAL_STORAGE granted');
            return true;
          } else {
            debugPrint('WRITE_EXTERNAL_STORAGE denied: $writeStorageStatus');
          }
        } else {
          // Write storage permission already granted
          debugPrint('WRITE_EXTERNAL_STORAGE already granted');
          return true;
        }
      } catch (e) {
        debugPrint('Error requesting external storage permission: $e');
        // Continue with app-specific directories even if external storage permission fails
      }

      // If we reach here, regular storage permission was denied
      // We'll try to use app-specific directories instead
      Get.snackbar(
        'Izin Penyimpanan',
        'Laporan akan disimpan di lokasi khusus aplikasi karena izin penyimpanan terbatas.',
        backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      // Return true to try using app-specific directories
      return true;
    } catch (e) {
      debugPrint('Error in permission handling: $e');
      return false;
    }
  }

  Future<void> _fetchAttendanceData() async {
    try {
      // Query Firebase for attendance data within the selected date range
      final startTimestamp = Timestamp.fromDate(selectedStartDate.value);
      final endTimestamp = Timestamp.fromDate(selectedEndDate.value
          .add(const Duration(days: 1))); // Include end date

      // Calculate working days (excluding weekends)
      final daysBetween =
          selectedEndDate.value.difference(selectedStartDate.value).inDays + 1;
      int workingDays = 0;

      // More accurate working days calculation
      for (int i = 0; i < daysBetween; i++) {
        final day = selectedStartDate.value.add(Duration(days: i));
        // Skip weekends (Saturday = 6, Sunday = 7)
        if (day.weekday < 6) {
          workingDays++;
        }
      }

      // Get all employees
      final employeesSnapshot =
          await FirebaseFirestore.instance.collection('pegawai').get();
      final totalEmployees = employeesSnapshot.docs.length;

      // Query attendance records for the date range
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThan: endTimestamp)
          .get();

      // Process attendance data
      int presentDays = 0;
      int absentDays = 0;
      int lateDays = 0;
      int earlyLeaveDays = 0;

      // Keep track of employee performance for best/worst calculation
      Map<String, int> employeePresenceDays = {};
      Map<String, int> employeeWorkingDays = {};
      Map<String, String> employeeNames = {};
      Map<String, String> employeeSites = {};
      Map<String, int> sitePresenceDays = {};
      Map<String, int> siteWorkingDays = {};
      Map<String, int> siteEmployeeCounts = {}; // Count employees per site
      Map<String, String> nikToEmployeeIdMap =
          {}; // Mapping between NIK and employee ID
      Map<String, String> employeePositions = {}; // Track employee positions
      Map<String, String> employeeJobs = {}; // Track employee jobs
      Map<String, String> employeeNiks = {}; // Track employee NIKs

      // Initialize employee tracking
      for (var empDoc in employeesSnapshot.docs) {
        final empId = empDoc.id;
        // Add error handling for missing fields
        final empData = empDoc.data();

        // Extract fields with robust null safety and validation
        final empName = _extractStringValue(empData['name'], 'Unknown Name');
        if (empName == 'Unknown Name') {
          debugPrint('Warning: Employee $empId has missing name information');
        }

        // Handle site information with enhanced validation
        final empSite = _extractStringValue(empData['site'], '');
        if (empSite.isEmpty) {
          debugPrint(
              'Warning: Employee $empId has missing or empty site information');
          // Log this issue to help identify data problems
          FirebaseFirestore.instance.collection('data_validation_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'issue': 'missing_site',
            'employeeId': empId,
            'message': 'Employee has missing site information'
          }).catchError((e) {
            debugPrint('Error logging validation issue: $e');
            // Create and return a new document reference
            final docRef = FirebaseFirestore.instance
                .collection('data_validation_logs')
                .doc('error_log_${DateTime.now().millisecondsSinceEpoch}');
            return docRef.set({
              'timestamp': FieldValue.serverTimestamp(),
              'issue': 'error_logging',
              'error': e.toString()
            }).then((_) => docRef);
          });
        }

        // Validate site name format (should not contain special characters except dash and space)
        final RegExp validSiteFormat = RegExp(r'^[a-zA-Z0-9\s\-]+$');
        final String validatedSite;

        if (empSite.trim().isNotEmpty == true) {
          if (validSiteFormat.hasMatch(empSite)) {
            validatedSite = empSite;
          } else {
            debugPrint(
                'Warning: Employee $empId has invalid site format: $empSite');
            validatedSite = 'Invalid Site Format';
          }
        } else {
          validatedSite = 'Unknown Site';
        }

        // Handle position field with validation
        // Enhanced validation for position field
        String validatedPosition;
        if (empData.containsKey('position')) {
          final posData = empData['position'];
          if (posData is Map<String, dynamic>) {
            validatedPosition = posData['value']?.toString() ?? 'Not Specified';
          } else {
            validatedPosition = posData?.toString() ?? 'Not Specified';
          }
        } else if (empData.containsKey('department')) {
          // Try to use department as fallback for backward compatibility
          final deptData = empData['department'];
          if (deptData is Map<String, dynamic>) {
            validatedPosition = deptData['value']?.toString() ?? 'Not Specified';
          } else {
            validatedPosition = deptData?.toString() ?? 'Not Specified';
          }
          debugPrint(
              'Using department as fallback for position for employee $empId');
        } else {
          validatedPosition = 'Not Specified';
          debugPrint(
              'Warning: Employee $empId has no position or department information');
        }

        // Enhanced validation for job field
        final empJob = _extractStringValue(empData['job'], '');
        final String validatedJob;

        if (empJob.isNotEmpty) {
          validatedJob = empJob;
        } else {
          validatedJob = 'Not Specified';
          debugPrint('Warning: Employee $empId has no job information');
        }

        // Enhanced NIK validation with format checking and logging
        final empNik = _extractStringValue(empData['nik'], '');
        final String validatedNik;

        // Typical Indonesian NIK format is 16 digits
        final RegExp nikFormat = RegExp(r'^\d{16}$');

        if (empNik.isNotEmpty) {
          if (nikFormat.hasMatch(empNik)) {
            validatedNik = empNik;
          } else {
            debugPrint(
                'Warning: Employee $empId has invalid NIK format: $empNik (should be 16 digits)');
            // Still use the provided NIK even if format is invalid
            validatedNik = empNik;
          }
        } else {
          debugPrint(
              'Warning: Employee $empId has missing NIK, using document ID as fallback');
          validatedNik = empId;

          // Log this issue to help identify data problems
          FirebaseFirestore.instance.collection('data_validation_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'issue': 'missing_nik',
            'employeeId': empId,
            'message': 'Employee has missing NIK information'
          }).catchError((e) {
            debugPrint('Error logging validation issue: $e');
            // Create and return a new document reference
            final docRef = FirebaseFirestore.instance
                .collection('data_validation_logs')
                .doc('error_log_${DateTime.now().millisecondsSinceEpoch}');
            return docRef.set({
              'timestamp': FieldValue.serverTimestamp(),
              'issue': 'error_logging',
              'error': e.toString()
            }).then((_) => docRef);
          });
        }

        // Create a mapping between NIK and employee ID for better cross-referencing
        if (validatedNik != empId) {
          // Store the mapping in a local map for reference during this report generation
          nikToEmployeeIdMap[validatedNik] = empId;
        }

        // Initialize employee tracking data with validated fields
        // Store all employee data in our tracking maps
        employeePresenceDays[empId] = 0;
        employeeWorkingDays[empId] = workingDays;
        employeeNames[empId] = empName;
        employeeSites[empId] = validatedSite;
        employeePositions[empId] = validatedPosition;
        employeeJobs[empId] = validatedJob;
        employeeNiks[empId] = validatedNik;

        // Optimize site statistics initialization and calculation with validated site
        if (!sitePresenceDays.containsKey(validatedSite)) {
          sitePresenceDays[validatedSite] = 0;
          siteWorkingDays[validatedSite] = 0;
          debugPrint('Initialized tracking for site: $validatedSite');
        }
        siteWorkingDays[validatedSite] =
            (siteWorkingDays[validatedSite] ?? 0) + workingDays;

        // Track number of employees per site for better statistics
        if (!siteEmployeeCounts.containsKey(validatedSite)) {
          siteEmployeeCounts[validatedSite] = 0;
        }
        siteEmployeeCounts[validatedSite] =
            (siteEmployeeCounts[validatedSite] ?? 0) + 1;
      }

      // Process attendance records
      for (var attendanceDoc in attendanceQuery.docs) {
        final data = attendanceDoc.data();
        // Enhanced validation for nik field with detailed error messages
        String empId = '';

        // First try nik field (new structure)
        if (data.containsKey('nik') &&
            data['nik'] is String &&
            (data['nik'] as String).isNotEmpty) {
          final nikValue = data['nik'] as String;

          // Check if this NIK is in our mapping
          if (nikToEmployeeIdMap.containsKey(nikValue)) {
            empId = nikToEmployeeIdMap[nikValue]!;
            debugPrint('Using mapped employee ID for NIK: $nikValue -> $empId');
          } else {
            empId = nikValue;
          }
        }
        // Then try employeeId field (old structure)
        else if (data.containsKey('employeeId') &&
            data['employeeId'] is String &&
            (data['employeeId'] as String).isNotEmpty) {
          final employeeIdValue = data['employeeId'] as String;
          empId = employeeIdValue;
          debugPrint(
              'Using legacy employeeId field instead of nik field: $employeeIdValue');
        } else {
          // No valid ID found
          debugPrint(
              'Warning: Attendance record has no valid employee identifier, skipping');
          continue;
        }

        // Skip processing if employee ID is missing
        if (empId.isEmpty) {
          debugPrint(
              'Warning: Skipping attendance record with empty employee ID: ${data['date']}');
          continue;
        }

        // Verify employee exists in our employee maps
        if (!employeeNames.containsKey(empId)) {
          debugPrint(
              'Warning: Attendance record references unknown employee ID: $empId');
          // Continue processing but track that this is an unknown employee
        }

        if (data['status'] == 'present') {
          presentDays++;
          employeePresenceDays[empId] = (employeePresenceDays[empId] ?? 0) + 1;

          // More efficient site presence tracking with better error handling
          final site = employeeSites[empId];
          if (site != null && site.isNotEmpty) {
            sitePresenceDays[site] = (sitePresenceDays[site] ?? 0) + 1;
          } else {
            // Handle case where site information is missing
            final unknownSite = 'Unknown Site';
            debugPrint(
                'Warning: No site information for employee $empId, using "$unknownSite"');

            // Initialize tracking for unknown site if needed
            if (!sitePresenceDays.containsKey(unknownSite)) {
              sitePresenceDays[unknownSite] = 0;
              siteWorkingDays[unknownSite] = 0;
            }

            // Update tracking for unknown site
            sitePresenceDays[unknownSite] =
                (sitePresenceDays[unknownSite] ?? 0) + 1;
            siteWorkingDays[unknownSite] =
                (siteWorkingDays[unknownSite] ?? 0) + 1;
          }

          // Check for late arrival
          if (data['isLate'] == true) {
            lateDays++;
          }

          // Check for early departure
          if (data['isEarlyLeave'] == true) {
            earlyLeaveDays++;
          }
        } else if (data['status'] == 'absent') {
          absentDays++;
        }
      }

      // Find best and worst employees
      String bestEmployee = '';
      String worstEmployee = '';
      double bestAttendance = 0;
      double worstAttendance = 100;

      employeePresenceDays.forEach((empId, presentCount) {
        final workingCount =
            employeeWorkingDays[empId] ?? 1; // Avoid division by zero
        final attendance = (presentCount / workingCount) * 100;

        if (attendance > bestAttendance) {
          bestAttendance = attendance;
          bestEmployee = employeeNames[empId] ?? empId;
        }

        if (attendance < worstAttendance) {
          worstAttendance = attendance;
          worstEmployee = employeeNames[empId] ?? empId;
        }
      });

      // Find best and worst sites
      String bestSite = '';
      String worstSite = '';
      double bestSiteAttendance = 0;
      double worstSiteAttendance = 100;

      sitePresenceDays.forEach((site, presentCount) {
        final workingCount =
            siteWorkingDays[site] ?? 1; // Avoid division by zero
        final attendance = (presentCount / workingCount) * 100;

        if (attendance > bestSiteAttendance) {
          bestSiteAttendance = attendance;
          bestSite = site;
        }

        if (attendance < worstSiteAttendance && site != bestSite) {
          // Ensure different from best
          worstSiteAttendance = attendance;
          worstSite = site;
        }
      });

      // Store the computed statistics
      dataStats.value = {
        'totalEmployees': totalEmployees,
        'totalPresentDays': presentDays,
        'totalAbsentDays': absentDays,
        'totalLateDays': lateDays,
        'totalEarlyLeaveDays': earlyLeaveDays,
        'period': getDateRangeText(),
        'workingDays': workingDays,
        'bestEmployee': '$bestEmployee (${bestAttendance.toStringAsFixed(0)}%)',
        'worstEmployee':
            '$worstEmployee (${worstAttendance.toStringAsFixed(0)}%)',
        'bestSite': '$bestSite (${bestSiteAttendance.toStringAsFixed(0)}%)',
        'worstSite': '$worstSite (${worstSiteAttendance.toStringAsFixed(0)}%)',
      };
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      errorMessage.value = 'Gagal mengambil data absensi: ${e.toString()}';

      // Provide more specific error messages for collection issues with new field structure details
      if (e.toString().contains('pegawai')) {
        errorMessage.value =
            'Gagal mengakses data pegawai. Pastikan koleksi pegawai sudah tersedia dan memiliki field yang diperlukan (name, site, position, job, nik).';
      } else if (e.toString().contains('attendance')) {
        errorMessage.value =
            'Gagal mengakses data kehadiran. Pastikan koleksi attendance sudah tersedia dengan field yang benar.';
      } else if (e.toString().contains('nik')) {
        errorMessage.value =
            'Terdapat masalah dengan field nik di koleksi pegawai atau attendance. Pastikan field nik sudah tersedia dan valid.';
      } else if (e.toString().contains('site')) {
        errorMessage.value =
            'Terdapat masalah dengan field site di koleksi pegawai. Pastikan semua pegawai memiliki informasi site yang valid.';
      }

      rethrow; // Rethrow to be caught by the caller
    }
  }

  Future<String> _generateExcelFile() async {
    try {
      // Create Excel document
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Create main summary sheet
      final summarySheet = excel['Summary'];

      // Add report title and period
      final titleStyle = CellStyle(
          bold: true, fontSize: 16, horizontalAlign: HorizontalAlign.Center);

      // Add title row spanning multiple columns
      final titleCell = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('LAPORAN KEHADIRAN BULANAN');
      titleCell.cellStyle = titleStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));

      // Add period row
      final periodCell = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      periodCell.value = TextCellValue('Periode: ${getDateRangeText()}');
      periodCell.cellStyle = CellStyle(bold: true);
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1));

      // Add some spacing
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = TextCellValue('');

      // Create header style
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('DDDDDD'),
      );

      // Add summary statistics header
      final statHeader = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
      statHeader.value = TextCellValue('STATISTIK KEHADIRAN');
      statHeader.cellStyle = headerStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3));

      // Use the statistics already calculated in _fetchAttendanceData
      int totalEmployees = dataStats['totalEmployees'] ?? 0;
      int workingDays = dataStats['workingDays'] ?? 0;
      int totalPresentDays = dataStats['totalPresentDays'] ?? 0;
      int totalAbsentDays = dataStats['totalAbsentDays'] ?? 0;
      int totalLateDays = dataStats['totalLateDays'] ?? 0;
      int totalEarlyLeaveDays = dataStats['totalEarlyLeaveDays'] ?? 0;

      // Add statistics rows
      _addStatisticRow(
          summarySheet, 4, 'Total Karyawan', totalEmployees.toString());
      _addStatisticRow(
          summarySheet, 5, 'Total Hari Kerja', workingDays.toString());
      _addStatisticRow(
          summarySheet, 6, 'Total Kehadiran', totalPresentDays.toString());
      _addStatisticRow(
          summarySheet, 7, 'Total Absen', totalAbsentDays.toString());
      _addStatisticRow(
          summarySheet, 8, 'Total Terlambat', totalLateDays.toString());
      _addStatisticRow(
          summarySheet, 9, 'Total Pulang Awal', totalEarlyLeaveDays.toString());

      // Add spacing
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10))
          .value = TextCellValue('');

      // Add performance section header
      final perfHeader = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11));
      perfHeader.value = TextCellValue('PERFORMA');
      perfHeader.cellStyle = headerStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 11));

      // Add performance rows
      _addStatisticRow(summarySheet, 12, 'Karyawan dengan Kehadiran Terbaik',
          dataStats['bestEmployee'] ?? '-');
      _addStatisticRow(summarySheet, 13, 'Karyawan dengan Kehadiran Terburuk',
          dataStats['worstEmployee'] ?? '-');
      _addStatisticRow(
          summarySheet, 14, 'Site Terbaik', dataStats['bestSite'] ?? '-');
      _addStatisticRow(
          summarySheet, 15, 'Site Terburuk', dataStats['worstSite'] ?? '-');

      // Add percentage statistics
      double attendanceRate = 0;
      if ((totalPresentDays + totalAbsentDays) > 0) {
        attendanceRate =
            totalPresentDays / (totalPresentDays + totalAbsentDays) * 100;
      }

      double lateRate = 0;
      if (totalPresentDays > 0) {
        lateRate = totalLateDays / totalPresentDays * 100;
      }

      double earlyLeaveRate = 0;
      if (totalPresentDays > 0) {
        earlyLeaveRate = totalEarlyLeaveDays / totalPresentDays * 100;
      }

      _addStatisticRow(summarySheet, 16, 'Rata-rata Kehadiran',
          '${attendanceRate.toStringAsFixed(1)}%');
      _addStatisticRow(summarySheet, 17, 'Rata-rata Keterlambatan',
          '${lateRate.toStringAsFixed(1)}%');
      _addStatisticRow(summarySheet, 18, 'Rata-rata Pulang Awal',
          '${earlyLeaveRate.toStringAsFixed(1)}%');

      // Create a second sheet with detailed data if available
      final detailSheet = excel['Detail Kehadiran'];

      // Add headers for detail sheet
      final detailHeaders = [
        'No.',
        'Tanggal',
        'Nama Karyawan',
        'Site',
        'Posisi',
        'Status',
        'Jam Masuk',
        'Jam Keluar',
        'Terlambat',
        'Pulang Awal'
      ];

      for (int i = 0; i < detailHeaders.length; i++) {
        final cell = detailSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(detailHeaders[i]);
        cell.cellStyle = headerStyle;
      }

      // Attempt to fetch detailed attendance data for the sheet
      try {
        final startTimestamp = Timestamp.fromDate(selectedStartDate.value);
        final endTimestamp = Timestamp.fromDate(
            selectedEndDate.value.add(const Duration(days: 1)));

        final detailQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: startTimestamp)
            .where('date', isLessThan: endTimestamp)
            .orderBy('date')
            .get();

        // Get employee mapping for names
        final employeesSnapshot =
            await FirebaseFirestore.instance.collection('pegawai').get();
        Map<String, Map<String, dynamic>> employeeMap = {};

        for (var empDoc in employeesSnapshot.docs) {
          final empData = empDoc.data();
          
          // Extract name with proper null and type checking
          final name = empData['name'] is Map 
              ? empData['name']['value']?.toString() ?? 'Unknown Name'
              : empData['name']?.toString() ?? 'Unknown Name';

          // Extract site with proper null and type checking
          final site = empData['site'] is Map
              ? empData['site']['value']?.toString() ?? 'Unknown Site'
              : empData['site']?.toString() ?? 'Unknown Site';

          // Extract position with proper null and type checking
          String position;
          if (empData.containsKey('position')) {
            final posData = empData['position'];
            if (posData is Map<String, dynamic>) {
              position = posData['value']?.toString() ?? 'Not Specified';
            } else {
              position = posData?.toString() ?? 'Not Specified';
            }
          } else if (empData.containsKey('department')) {
            final deptData = empData['department'];
            if (deptData is Map<String, dynamic>) {
              position = deptData['value']?.toString() ?? 'Not Specified';
            } else {
              position = deptData?.toString() ?? 'Not Specified';
            }
          } else {
            position = 'Not Specified';
          }

          // Extract job with proper null and type checking
          final jobData = empData['job'];
          final String job;
          if (jobData is Map<String, dynamic>) {
            job = jobData['value']?.toString() ?? 'Not Specified';
          } else {
            job = jobData?.toString() ?? 'Not Specified';
          }

          // Extract NIK with proper null and type checking
          final nikData = empData['nik'];
          final String nik;
          if (nikData is Map<String, dynamic>) {
            nik = nikData['value']?.toString() ?? empDoc.id;
          } else {
            nik = nikData?.toString() ?? empDoc.id;
          }
          
          // Log warnings for missing data
          if (name == 'Unknown Name') {
            debugPrint('Warning: Employee ${empDoc.id} has missing name information');
          }
          
          if (site == 'Unknown Site') {
            debugPrint('Warning: Employee ${empDoc.id} has missing site information');
          }
          
          if (position == 'Not Specified' && empData.containsKey('department')) {
            debugPrint('Using department as fallback for position for employee ${empDoc.id}');
          }
          
          if (nik == empDoc.id) {
            debugPrint('Warning: Employee ${empDoc.id} has missing NIK, using document ID as fallback');
          }

          // Create a new map with properly processed string values
          employeeMap[empDoc.id] = {
            'name': name,
            'site': site,
            'position': position,
            'job': job,
            'nik': nik
          };
        }

        // Populate detail rows
        int rowIndex = 1;
        for (var attendanceDoc in detailQuery.docs) {
          final data = attendanceDoc.data();
          String empId = '';

          // Try to get employee ID from nik or employeeId field with validation
          if (data.containsKey('nik') &&
              data['nik'] is String &&
              (data['nik'] as String).isNotEmpty) {
            empId = data['nik'] as String;
          } else if (data.containsKey('employeeId') &&
              data['employeeId'] is String &&
              (data['employeeId'] as String).isNotEmpty) {
            empId = data['employeeId'] as String;
          } else {
            // Skip records with no valid employee identifier
            debugPrint(
                'Warning: Skipping attendance record with no valid employee identifier');
            continue;
          }

          final empData = employeeMap[empId] ?? {};

          // If no employee data found, create basic placeholder data
          if (empData.isEmpty) {
            debugPrint('Warning: No employee data found for ID: $empId');
            empData['name'] = 'Unknown Employee';
            empData['site'] = 'Unknown Site';
            empData['position'] = 'Unknown Position';
          }

          // Date formatting
          String dateStr = '';
          if (data['date'] is Timestamp) {
            final timestamp = data['date'] as Timestamp;
            dateStr = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
          }

          // Time formatting
          String timeIn = data['timeIn'] ?? '-';
          String timeOut = data['timeOut'] ?? '-';

          // Status formatting
          String status = (data['status'] == 'present') ? 'Hadir' : 'Absen';

          // Populate the row
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 0, rowIndex: rowIndex))
              .value = IntCellValue(rowIndex);
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 1, rowIndex: rowIndex))
              .value = TextCellValue(dateStr);
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 2, rowIndex: rowIndex))
              .value = TextCellValue(empData['name'] ?? 'Unknown');
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 3, rowIndex: rowIndex))
              .value = TextCellValue(empData['site'] ?? '-');
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 4, rowIndex: rowIndex))
              .value = TextCellValue(empData['position'] ?? '-');
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 5, rowIndex: rowIndex))
              .value = TextCellValue(status);
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 6, rowIndex: rowIndex))
              .value = TextCellValue(timeIn);
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 7, rowIndex: rowIndex))
              .value = TextCellValue(timeOut);
          detailSheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 8, rowIndex: rowIndex))
              .value = TextCellValue(data['isLate'] == true ? 'Ya' : 'Tidak');
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 9, rowIndex: rowIndex))
                  .value =
              TextCellValue(data['isEarlyLeave'] == true ? 'Ya' : 'Tidak');

          rowIndex++;
        }

        // Auto-fit columns for better readability
        for (int i = 0; i < detailHeaders.length; i++) {
          detailSheet.setColumnWidth(i, 15.0);
        }
      } catch (e) {
        // If getting detail data fails, just leave basic info in the detail sheet
        _addStatisticRow(detailSheet, 1, 'Error',
            'Tidak dapat memuat data detail: ${e.toString()}');
      }

      // Auto-fit columns for better readability
      for (int i = 0; i < 6; i++) {
        summarySheet.setColumnWidth(i, 20.0);
      }

      // Determine the appropriate directory for saving based on platform
      String? saveDirectory;
      try {
        // Use the existing implementation
        saveDirectory = await _getSaveDirectory();
        debugPrint('Save directory: $saveDirectory');
      } catch (e) {
        debugPrint('Error getting save directory: $e');
        // Try to use a fallback directory if the primary one fails
        try {
          final tempDir = await getTemporaryDirectory();
          saveDirectory = '${tempDir.path}/Reports';
          debugPrint('Using fallback directory: $saveDirectory');
        } catch (fallbackError) {
          debugPrint('Error getting fallback directory: $fallbackError');
          throw Exception(
              'Cannot find a valid directory for saving the report: $e');
        }
      }

      if (saveDirectory.isEmpty) {
        throw Exception('Invalid save directory');
      }

      // Create the directory if it doesn't exist
      Directory downloadDir = Directory(saveDirectory);
      if (!await downloadDir.exists()) {
        try {
          await downloadDir.create(recursive: true);

          // Double-check that directory was created successfully
          if (!await downloadDir.exists()) {
            throw Exception(
                'Directory creation appeared to succeed but directory does not exist');
          }
          debugPrint('Created directory: ${downloadDir.path}');
        } catch (e) {
          debugPrint('Error creating directory: $e');
          throw Exception('Cannot create directory for saving: $e');
        }
      }

      // Create a meaningful filename with date
      final formattedDate =
          DateFormat('MMM_yyyy').format(selectedStartDate.value);
      final fileName = 'Monthly_Attendance_Report_$formattedDate.xlsx';
      final filePath = '${downloadDir.path}/$fileName';

      debugPrint('Preparing to save file to: $filePath');

      // Check if we have write permission to the directory
      try {
        // Try writing a test file to verify permissions
        final testFile = File('${downloadDir.path}/test_write.tmp');
        await testFile.writeAsString('test');

        // Verify the file was actually created
        if (await testFile.exists()) {
          debugPrint('Write permission verified successfully');
          await testFile.delete();
        } else {
          debugPrint(
              'Test file not created even though no exception was thrown');
          throw Exception(
              'Could not verify write permissions (file not created)');
        }
      } catch (e) {
        debugPrint('No write permission to directory: $e');

        // Try to create a fallback directory in the app's internal storage
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fallbackPath = '${appDir.path}/Reports';
          final fallbackDir = Directory(fallbackPath);

          if (!await fallbackDir.exists()) {
            await fallbackDir.create(recursive: true);
          }

          // Update the download directory to use the fallback
          downloadDir = fallbackDir;
          debugPrint('Using fallback directory: ${downloadDir.path}');

          // Show notification to user
          Get.snackbar(
            'Menggunakan Direktori Alternatif',
            'Laporan akan disimpan ke direktori aplikasi internal.',
            backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
        } catch (fallbackError) {
          debugPrint('Failed to create fallback directory: $fallbackError');
          throw Exception(
              'Tidak dapat menulis ke direktori penyimpanan. Silakan periksa izin aplikasi.');
        }
      }

      // Show progress notification for file writing
      Get.snackbar(
        'Menyimpan Laporan',
        'Menyimpan file Excel...',
        backgroundColor: Colors.blue.withAlpha((0.5 * 255).round()),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Convert Excel to bytes
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Gagal menghasilkan data Excel');
      }

      // Write file with retry mechanism
      File file = File('${downloadDir.path}/$fileName');
      int writeAttempts = 0;
      const maxWriteAttempts = 3;

      while (writeAttempts < maxWriteAttempts) {
        try {
          debugPrint('Writing file (attempt ${writeAttempts + 1})...');
          await file.writeAsBytes(fileBytes);

          // Check if file was actually created and has content
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              debugPrint(
                  'File successfully saved: ${file.path} ($fileSize bytes)');
              // Success - return the file path
              return file.path;
            } else {
              throw Exception('File was created but has zero size');
            }
          } else {
            throw Exception('File could not be created at path: ${file.path}');
          }
        } catch (e) {
          debugPrint('Error writing file (attempt ${writeAttempts + 1}): $e');
          writeAttempts++;

          if (writeAttempts < maxWriteAttempts) {
            // Show retry notification
            Get.snackbar(
              'Mencoba Ulang',
              'Mencoba menyimpan file kembali ($writeAttempts/$maxWriteAttempts)...',
              backgroundColor: Colors.amber.withAlpha((0.7 * 255).round()),
              colorText: Colors.white,
              duration: const Duration(seconds: 1),
            );

            // Wait before retrying
            await Future.delayed(Duration(seconds: 1));
          } else {
            // Max retries reached - throw exception
            throw Exception(
                'Gagal menyimpan file setelah $maxWriteAttempts percobaan: $e');
          }
        }
      }

      // This should never be reached due to the return statement above
      throw Exception('Unexpected error in file writing process');
    } catch (e) {
      debugPrint('Error in _generateExcelFile: $e');
      rethrow;
    }
  }

  // Helper method to calculate working days between two dates

  // These methods are now unused since we calculate statistics in _fetchAttendanceData
  // and store them in dataStats map, but keeping the calculation method for reference

  // Helper method to determine the best directory for saving files
  Future<String> _getSaveDirectory() async {
    try {
      if (Platform.isAndroid) {
        // For Android, try these directories in order of preference

        // 1. First try Downloads directory via external storage
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final path = '${externalDir.path}/Download';
            debugPrint('Using Android external storage path: $path');

            // Create directory if it doesn't exist
            final directory = Directory(path);
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }

            return path;
          }
        } catch (e) {
          debugPrint('Error accessing external storage: $e');
        }

        // 2. Try app's documents directory as fallback
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final path = '${appDir.path}/Reports';
          debugPrint('Using Android documents directory: $path');

          // Create directory if it doesn't exist
          final directory = Directory(path);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          return path;
        } catch (e) {
          debugPrint('Error accessing documents directory: $e');
        }

        // 3. Last resort - try temporary directory
        try {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/Reports';
          debugPrint('Using Android temporary directory: $path');

          // Create directory if it doesn't exist
          final directory = Directory(path);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          return path;
        } catch (e) {
          debugPrint('Error accessing temporary directory: $e');
        }

        // If all else fails, throw an exception
        throw Exception('No valid storage location available on this device');
      } else if (Platform.isIOS) {
        // For iOS, use app's documents directory
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final path = '${appDir.path}/Reports';
          debugPrint('Using iOS documents directory: $path');

          // Create directory if it doesn't exist
          final directory = Directory(path);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          return path;
        } catch (e) {
          debugPrint('Error accessing iOS documents directory: $e');

          // Try temporary directory as fallback
          try {
            final tempDir = await getTemporaryDirectory();
            final path = '${tempDir.path}/Reports';
            debugPrint('Using iOS temporary directory: $path');

            // Create directory if it doesn't exist
            final directory = Directory(path);
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }

            return path;
          } catch (e) {
            debugPrint('Error accessing iOS temporary directory: $e');
          }
        }

        // If all else fails, throw an exception
        throw Exception('No valid storage location available on this device');
      } else {
        // For other platforms, use temp directory
        try {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/Reports';
          debugPrint('Using generic temporary directory: $path');

          // Create directory if it doesn't exist
          final directory = Directory(path);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          return path;
        } catch (e) {
          debugPrint('Error accessing temporary directory: $e');
        }

        // If all else fails, throw an exception
        throw Exception('No valid storage location available on this platform');
      }
    } catch (e) {
      debugPrint('Error determining save directory: $e');
      throw Exception('Could not determine a valid save location: $e');
    }
  }

  // Helper method to safely extract string values from various data types
  String _extractStringValue(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is Map) {
      return value['value']?.toString() ?? 
             value['display']?.toString() ?? 
             defaultValue;
    }
    try {
      return value.toString();
    } catch (_) {
      return defaultValue;
    }
  }

  // Helper method to add statistic rows to Excel sheet
  void _addStatisticRow(Sheet sheet, int rowIndex, String label, String value) {
    // Set label
    final labelCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    labelCell.value =
        TextCellValue(label); // Fixed: Convert String to TextCellValue
    labelCell.cellStyle = CellStyle(bold: true);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));

    // Set value
    final valueCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
    valueCell.value =
        TextCellValue(value); // Fixed: Convert String to TextCellValue
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
  }

  int get totalEmployees => dataStats['totalEmployees'] ?? 0;
  int get totalPresentDays => dataStats['totalPresentDays'] ?? 0;
  int get totalAbsentDays => dataStats['totalAbsentDays'] ?? 0;
  int get totalLateDays => dataStats['totalLateDays'] ?? 0;
  int get totalEarlyLeaveDays => dataStats['totalEarlyLeaveDays'] ?? 0;
  String get period => dataStats['period'] ?? '';
  int get workingDays => dataStats['workingDays'] ?? 0;
  String get bestSite => dataStats['bestSite']?.toString().split(' ')[0] ?? '';
  String get worstSite =>
      dataStats['worstSite']?.toString().split(' ')[0] ?? '';

  void showDownloadOptionsDialog() {
    if (!downloadSuccess.value) {
      Get.snackbar(
        'Perhatian',
        'Laporan belum diunduh. Silakan generate laporan terlebih dahulu.',
        backgroundColor: Colors.orange.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Opsi Unduhan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Bagikan'),
              onTap: () {
                Get.back();
                _shareFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.green),
              title: const Text('Buka File'),
              onTap: () {
                Get.back();
                _openFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.amber),
              title: const Text('Lihat Informasi File'),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Informasi File',
                  'Lokasi: ${downloadPath.value}\nUkuran: ${_getFileSize()}',
                  backgroundColor: Colors.blue.withAlpha((0.7 * 255).round()),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 5),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // Helper method to get file size
  String _getFileSize() {
    try {
      final file = File(downloadPath.value);
      if (file.existsSync()) {
        final sizeInBytes = file.lengthSync();
        if (sizeInBytes < 1024) {
          return '$sizeInBytes B';
        } else if (sizeInBytes < 1024 * 1024) {
          return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
        } else {
          return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
        }
      }
      return 'Tidak tersedia';
    } catch (e) {
      return 'Tidak tersedia';
    }
  }

  Future<void> _shareFile() async {
    try {
      final file = File(downloadPath.value);
      if (await file.exists()) {
        // Convert File to XFile
        final xFile = XFile(file.path);
        // Use shareXFiles instead of deprecated shareFiles
        await Share.shareXFiles([xFile],
            text: 'Laporan Absensi Bulanan ${getDateRangeText()}');
      } else {
        throw Exception('File tidak ditemukan');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal membagikan file: ${e.toString()}',
        backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _openFile() async {
    try {
      final file = File(downloadPath.value);
      if (await file.exists()) {
        final result = await OpenFile.open(downloadPath.value);
        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      } else {
        throw Exception('File tidak ditemukan');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal membuka file: ${e.toString()}',
        backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
    }
  }

  void showStatisticsDialog() {
    if (dataStats.isEmpty) {
      Get.snackbar(
        'Perhatian',
        'Data statistik belum tersedia. Silakan generate laporan terlebih dahulu.',
        backgroundColor: Colors.orange.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
      return;
    }

    // Calculate statistics based on actual data
    double attendanceRate = 0;
    if ((totalPresentDays + totalAbsentDays) > 0) {
      attendanceRate =
          totalPresentDays / (totalPresentDays + totalAbsentDays) * 100;
    }

    double lateRate = 0;
    if (totalPresentDays > 0) {
      lateRate = totalLateDays / totalPresentDays * 100;
    }

    double earlyLeaveRate = 0;
    if (totalPresentDays > 0) {
      earlyLeaveRate = totalEarlyLeaveDays / totalPresentDays * 100;
    }

    Get.dialog(
      AlertDialog(
        title: Text('Detail Statistik: ${getDateRangeText()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatisticItem('Kehadiran Rata-rata',
                  '${attendanceRate.toStringAsFixed(1)}%'),
              _buildStatisticItem(
                  'Keterlambatan Rata-rata', '${lateRate.toStringAsFixed(1)}%'),
              _buildStatisticItem('Pulang Awal Rata-rata',
                  '${earlyLeaveRate.toStringAsFixed(1)}%'),
              _buildStatisticItem('Total Hari Kerja', '$workingDays hari'),
              _buildStatisticItem('Pegawai dengan Kehadiran Terbaik',
                  dataStats['bestEmployee'] ?? '-'),
              _buildStatisticItem('Pegawai dengan Kehadiran Terburuk',
                  dataStats['worstEmployee'] ?? '-'),
              _buildStatisticItem('Site Terbaik', dataStats['bestSite'] ?? '-'),
              _buildStatisticItem(
                  'Site Terburuk', dataStats['worstSite'] ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(color: Colors.blue),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Method to display chart of attendance data
  void showAttendanceChart() {
    if (dataStats.isEmpty) {
      Get.snackbar(
        'Perhatian',
        'Data statistik belum tersedia. Silakan generate laporan terlebih dahulu.',
        backgroundColor: Colors.orange.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
      return;
    }

    Get.toNamed('/monthly-report/chart', arguments: {
      'presentDays': totalPresentDays,
      'absentDays': totalAbsentDays,
      'lateDays': totalLateDays,
      'earlyLeaveDays': totalEarlyLeaveDays,
      'period': period,
    });
  }

  // Method to display comparative chart with previous periods
  Future<void> showComparativeAnalysis() async {
    try {
      isLoading.value = true;

      // Get current period month and year
      final currentMonth = selectedStartDate.value.month;
      final currentYear = selectedStartDate.value.year;

      // Calculate previous 3 months
      List<Map<String, dynamic>> monthlyData = [];

      // Current month data
      monthlyData.add({
        'month':
            DateFormat('MMM yyyy').format(DateTime(currentYear, currentMonth)),
        'presentDays': totalPresentDays,
        'absentDays': totalAbsentDays,
        'lateDays': totalLateDays,
        'earlyLeaveDays': totalEarlyLeaveDays,
      });

      // Try to fetch data for previous 3 months
      for (int i = 1; i <= 3; i++) {
        final prevMonth = DateTime(currentYear, currentMonth - i);
        final startDate = DateTime(prevMonth.year, prevMonth.month, 21);
        final endDate = DateTime(prevMonth.year, prevMonth.month + 1, 20);

        final startTimestamp = Timestamp.fromDate(startDate);
        final endTimestamp =
            Timestamp.fromDate(endDate.add(const Duration(days: 1)));

        // Query attendance for this period
        final attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: startTimestamp)
            .where('date', isLessThan: endTimestamp)
            .get();

        // Process data
        int presentDays = 0;
        int absentDays = 0;
        int lateDays = 0;
        int earlyLeaveDays = 0;

        for (var doc in attendanceQuery.docs) {
          final data = doc.data();
          if (data['status'] == 'present') {
            presentDays++;
            if (data['isLate'] == true) lateDays++;
            if (data['isEarlyLeave'] == true) earlyLeaveDays++;
          } else if (data['status'] == 'absent') {
            absentDays++;
          }
        }

        monthlyData.add({
          'month': DateFormat('MMM yyyy').format(prevMonth),
          'presentDays': presentDays,
          'absentDays': absentDays,
          'lateDays': lateDays,
          'earlyLeaveDays': earlyLeaveDays,
        });
      }

      // Navigate to comparative chart view
      Get.toNamed('/monthly-report/comparative', arguments: {
        'monthlyData': monthlyData,
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memuat data perbandingan: ${e.toString()}',
        backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Method to export report in PDF format
  Future<void> exportToPdf() async {
    // This would require a PDF generation library like pdf or flutter_pdfview
    Get.snackbar(
      'Info',
      'Fitur export ke PDF akan segera hadir',
      backgroundColor: Colors.blue.withAlpha((0.7 * 255).round()),
      colorText: Colors.white,
    );
  }

  // Method to clear current report data
  void clearReportData() {
    dataStats.clear();
    downloadSuccess.value = false;
    downloadPath.value = '';
    errorMessage.value = '';

    // Reset date range to default
    _initializeDates();

    Get.snackbar(
      'Info',
      'Data laporan berhasil dihapus',
      backgroundColor: Colors.green.withAlpha((0.7 * 255).round()),
      colorText: Colors.white,
    );
  }

  // Helper method to get month name in Indonesian
  String getIndonesianMonth(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return months[month - 1];
  }

  // Helper method to generate formatted report title
  String getReportTitle() {
    final startMonth = getIndonesianMonth(selectedStartDate.value.month);
    final endMonth = getIndonesianMonth(selectedEndDate.value.month);

    if (selectedStartDate.value.month == selectedEndDate.value.month &&
        selectedStartDate.value.year == selectedEndDate.value.year) {
      return 'Laporan Kehadiran Bulan $startMonth ${selectedStartDate.value.year}';
    } else {
      return 'Laporan Kehadiran Periode $startMonth - $endMonth ${selectedEndDate.value.year}';
    }
  }

  // Method to show help/instructions dialog
  void showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Bantuan Laporan Bulanan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Cara Menggunakan:'),
              SizedBox(height: 8),
              Text('1. Pilih rentang tanggal laporan'),
              Text(
                  '2. Klik tombol "Generate Laporan" untuk menghasilkan laporan'),
              Text(
                  '3. Laporan akan disimpan di folder Download perangkat Anda'),
              Text(
                  '4. Anda dapat melihat statistik, membagikan, atau membuka file'),
              SizedBox(height: 16),
              Text('Informasi:'),
              SizedBox(height: 8),
              Text(
                  '• Informasi karyawan dan site terbaik/terburuk didasarkan pada persentase kehadiran'),
              Text('• Format laporan adalah Excel (.xlsx)'),
              Text(
                  '• Anda dapat melihat grafik kehadiran dan analisis perbandingan')
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    // Clean up any resources
    super.onClose();
  }
}
