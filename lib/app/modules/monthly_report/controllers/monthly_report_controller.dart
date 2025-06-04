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
    isLoading.value = true;
    errorMessage.value = '';
    downloadSuccess.value = false;

    try {
      // Check storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }

      // Fetch data based on selected date range
      await _fetchAttendanceData();

      // Generate actual report file
      final filePath = await _generateExcelFile();

      downloadSuccess.value = true;
      downloadPath.value = filePath;

      Get.snackbar(
        'Sukses',
        'Laporan berhasil diunduh ke: $filePath',
        backgroundColor: Colors.green.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      errorMessage.value = 'Gagal membuat laporan: ${e.toString()}';
      downloadSuccess.value = false;

      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
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
          await FirebaseFirestore.instance.collection('employees').get();
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
      Map<String, String> employeeDepartments = {};
      Map<String, int> departmentPresenceDays = {};
      Map<String, int> departmentWorkingDays = {};

      // Initialize employee tracking
      for (var empDoc in employeesSnapshot.docs) {
        final empId = empDoc.id;
        final empName = empDoc.data()['name'] as String;
        final empDepartment = empDoc.data()['department'] as String;

        employeePresenceDays[empId] = 0;
        employeeWorkingDays[empId] = workingDays;
        employeeNames[empId] = empName;
        employeeDepartments[empId] = empDepartment;

        // Initialize department tracking if not already done
        if (!departmentPresenceDays.containsKey(empDepartment)) {
          departmentPresenceDays[empDepartment] = 0;
          departmentWorkingDays[empDepartment] = 0;
        }
        departmentWorkingDays[empDepartment] =
            departmentWorkingDays[empDepartment]! + workingDays;
      }

      // Process attendance records
      for (var attendanceDoc in attendanceQuery.docs) {
        final data = attendanceDoc.data();
        final empId = data['employeeId'] as String;

        if (data['status'] == 'present') {
          presentDays++;
          employeePresenceDays[empId] = (employeePresenceDays[empId] ?? 0) + 1;

          final dept = employeeDepartments[empId];
          if (dept != null) {
            departmentPresenceDays[dept] =
                (departmentPresenceDays[dept] ?? 0) + 1;
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

      // Find best and worst departments
      String bestDepartment = '';
      String worstDepartment = '';
      double bestDeptAttendance = 0;
      double worstDeptAttendance = 100;

      departmentPresenceDays.forEach((dept, presentCount) {
        final workingCount =
            departmentWorkingDays[dept] ?? 1; // Avoid division by zero
        final attendance = (presentCount / workingCount) * 100;

        if (attendance > bestDeptAttendance) {
          bestDeptAttendance = attendance;
          bestDepartment = dept;
        }

        if (attendance < worstDeptAttendance && dept != bestDepartment) {
          // Ensure different from best
          worstDeptAttendance = attendance;
          worstDepartment = dept;
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
        'bestDepartment':
            '$bestDepartment (${bestDeptAttendance.toStringAsFixed(0)}%)',
        'worstDepartment':
            '$worstDepartment (${worstDeptAttendance.toStringAsFixed(0)}%)',
      };
    } catch (e) {
      errorMessage.value = 'Gagal mengambil data absensi: ${e.toString()}';
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
      titleCell.value = TextCellValue(
          'LAPORAN KEHADIRAN BULANAN'); // Fixed: Convert String to TextCellValue
      titleCell.cellStyle = titleStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));

      // Add period row
      final periodCell = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      periodCell.value = TextCellValue(
          'Periode: ${getDateRangeText()}'); // Fixed: Convert String to TextCellValue
      periodCell.cellStyle = CellStyle(bold: true);
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1));

      // Add some spacing
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = TextCellValue(''); // Fixed: Convert String to TextCellValue

      // Create header style
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('DDDDDD'),
        // Fixed: Removed the incorrect 'border' property
      );

      // Add summary statistics header
      final statHeader = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
      statHeader.value = TextCellValue(
          'STATISTIK KEHADIRAN'); // Fixed: Convert String to TextCellValue
      statHeader.cellStyle = headerStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3));

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
          .value = TextCellValue(''); // Fixed: Convert String to TextCellValue

      // Add performance section header
      final perfHeader = summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11));
      perfHeader.value =
          TextCellValue('PERFORMA'); // Fixed: Convert String to TextCellValue
      perfHeader.cellStyle = headerStyle;
      summarySheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 11));

      // Add performance rows
      _addStatisticRow(summarySheet, 12, 'Karyawan dengan Kehadiran Terbaik',
          dataStats['bestEmployee'] ?? '-');
      _addStatisticRow(summarySheet, 13, 'Karyawan dengan Kehadiran Terburuk',
          dataStats['worstEmployee'] ?? '-');
      _addStatisticRow(summarySheet, 14, 'Departemen Terbaik',
          dataStats['bestDepartment'] ?? '-');
      _addStatisticRow(summarySheet, 15, 'Departemen Terburuk',
          dataStats['worstDepartment'] ?? '-');

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
        'Departemen',
        'Status',
        'Jam Masuk',
        'Jam Keluar',
        'Terlambat',
        'Pulang Awal'
      ];
      for (int i = 0; i < detailHeaders.length; i++) {
        final cell = detailSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(
            detailHeaders[i]); // Fixed: Convert String to TextCellValue
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
            await FirebaseFirestore.instance.collection('employees').get();
        Map<String, Map<String, dynamic>> employeeMap = {};

        for (var empDoc in employeesSnapshot.docs) {
          employeeMap[empDoc.id] = empDoc.data();
        }

        // Populate detail rows
        int rowIndex = 1;
        for (var attendanceDoc in detailQuery.docs) {
          final data = attendanceDoc.data();
          final empId = data['employeeId'] as String;
          final empData = employeeMap[empId] ?? {};

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
              .value = IntCellValue(rowIndex); // Fixed: Use IntCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 1, rowIndex: rowIndex))
                  .value =
              TextCellValue(dateStr); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 2, rowIndex: rowIndex))
                  .value =
              TextCellValue(empData['name'] ??
                  'Unknown'); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 3, rowIndex: rowIndex))
                  .value =
              TextCellValue(empData['department'] ??
                  '-'); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 4, rowIndex: rowIndex))
                  .value =
              TextCellValue(status); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 5, rowIndex: rowIndex))
                  .value =
              TextCellValue(timeIn); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 6, rowIndex: rowIndex))
                  .value =
              TextCellValue(timeOut); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 7, rowIndex: rowIndex))
                  .value =
              TextCellValue(data['isLate'] == true
                  ? 'Ya'
                  : 'Tidak'); // Fixed: Convert String to TextCellValue
          detailSheet
                  .cell(CellIndex.indexByColumnRow(
                      columnIndex: 8, rowIndex: rowIndex))
                  .value =
              TextCellValue(data['isEarlyLeave'] == true
                  ? 'Ya'
                  : 'Tidak'); // Fixed: Convert String to TextCellValue

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

      // Save the Excel file
      final directory = await getExternalStorageDirectory();
      final downloadDir = Directory('${directory!.path}/Download');

      // Create the directory if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName =
          'Monthly_Attendance_Report_${DateFormat('MMM_yyyy').format(selectedStartDate.value)}.xlsx';
      final filePath = '${downloadDir.path}/$fileName';

      // Convert Excel to bytes and write to file
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
      } else {
        throw Exception('Failed to encode Excel file');
      }

      return filePath;
    } catch (e) {
      errorMessage.value = 'Gagal membuat file Excel: ${e.toString()}';
      rethrow;
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
              leading: const Icon(Icons.share),
              title: const Text('Bagikan'),
              onTap: () {
                Get.back();
                _shareFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Kirim Email'),
              onTap: () {
                Get.back();
                _sendEmail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Buka File'),
              onTap: () {
                Get.back();
                _openFile();
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

  Future<void> _shareFile() async {
    try {
      final file = File(downloadPath.value);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(downloadPath.value)],
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

  Future<void> _sendEmail() async {
    try {
      // Implement email functionality
      // You might use a package like flutter_email_sender
      Get.snackbar(
        'Email',
        'Mengirim laporan melalui email...',
        backgroundColor: Colors.blue.withAlpha((0.7 * 255).round()),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengirim email: ${e.toString()}',
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
              _buildStatisticItem(
                  'Departemen Terbaik', dataStats['bestDepartment'] ?? '-'),
              _buildStatisticItem(
                  'Departemen Terburuk', dataStats['worstDepartment'] ?? '-'),
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
              Text('• Laporan mencakup data kehadiran semua karyawan'),
              Text(
                  '• Informasi karyawan dan departemen terbaik/terburuk didasarkan pada persentase kehadiran'),
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
