import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'dart:math' as math;

final _logger = Logger();

class AllPresensiController extends GetxController
    with GetTickerProviderStateMixin {
  // Animation controllers
  late AnimationController _statsAnimationController;
  late Animation<double> _statsAnimation;

  // Variables for attendance counts
  var onTimeCount = 0.obs;
  var lateCount = 0.obs;
  var absentCount = 0.obs;
  var isLoading = true.obs;

  // Date range picker controller
  final DateRangePickerController dateRangePickerController =
      DateRangePickerController();

  // For date filtering
  DateTime? startDate;
  DateTime? endDate;
  String? filterText;

  // Store all presence data
  var allPresence = <DocumentSnapshot>[].obs;

  // Computed getter to access presence list length for UI
  int get presenceLength {
    int length = allPresence.length;
    if (length == 0) {
      _logger.w('presenceLength called but allPresence is empty');
    }
    return length;
  }

  // For UI animation
  bool get isFilterActive => startDate != null && endDate != null;

  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Get current user ID from Firebase Auth
  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'user_not_found';
  }

  @override
  void onInit() {
    super.onInit();

    // Initialize animation controllers
    _statsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _statsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.easeOutQuart,
      ),
    );

    // Call method to calculate attendance stats when controller initializes
    loadAttendanceStatistics();
  }

  // Helper functions for date handling
  String? getDateString(Map<String, dynamic>? dataMap, String fieldName) {
    if (dataMap == null) {
      _logger.d('getDateString: dataMap is null for $fieldName');
      return null;
    }
    
    String? result = dataMap[fieldName] as String? ?? dataMap["${fieldName}time"] as String?;
    _logger.d('getDateString: $fieldName string: $result');
    return result;
  }
  
  DateTime? parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      _logger.e('Error parsing date: $e');
      return null;
    }
  }

  @override
  void onClose() {
    _statsAnimationController.dispose();
    dateRangePickerController.dispose();
    super.onClose();
  }

  // Animation getter for UI
  Animation<double> get statsAnimation => _statsAnimation;

  // Method to play animation
  void playStatsAnimation() {
    _statsAnimationController.reset();
    _statsAnimationController.forward();
  }

  // Method to load attendance stats from Firestore
  Future<void> loadAttendanceStatistics() async {
    try {
      isLoading.value = true;
      update();
      
      _logger.d('Loading attendance statistics...');

      // Get all attendance records and update allPresence list
      await getAllPresenceForStats();

      // Reset counters
      int onTime = 0;
      int late = 0;
      int absent = 0;

      // Count attendance by category
      for (var doc in allPresence) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          _logger.d('Processing document: ${doc.id}, data: $data');

          // Check if absent
          if (data["masuk"] == null) {
            _logger.d('Document ${doc.id}: No check-in data, marking as absent');
            absent++;
            continue;
          }

          // Check if masuk data is valid
          Map<String, dynamic>? masukData;
          try {
            masukData = data["masuk"] as Map<String, dynamic>?;
            _logger.d('Document ${doc.id}: masuk data: $masukData');
          } catch (e) {
            _logger.e('Error casting masuk data: $e');
            absent++;
            continue;
          }

          if (masukData == null) {
            _logger.d('Document ${doc.id}: masuk data is null, marking as absent');
            absent++;
            continue;
          }

          // Get date string from either "date" or "datetime" field
          String? masukDateStr = getDateString(masukData, 'date');
          _logger.d('Document ${doc.id}: masuk date string: $masukDateStr');

          if (masukDateStr == null) {
            _logger.d('Document ${doc.id}: No date string, marking as absent');
            absent++;
            continue;
          }

          // Parse date
          DateTime? masukDateTime = parseDate(masukDateStr);
          _logger.d('Document ${doc.id}: parsed masuk date: $masukDateTime');

          if (masukDateTime == null) {
            _logger.d('Document ${doc.id}: Failed to parse date, marking as absent');
            absent++;
            continue;
          }

          // Check if late
          String masukTime = DateFormat.Hm().format(masukDateTime);
          _logger.d('Document ${doc.id}: check-in time: $masukTime');

          if (masukTime.compareTo("09:00") > 0) {
            _logger.d('Document ${doc.id}: Late check-in');
            late++;
          } else {
            _logger.d('Document ${doc.id}: On-time check-in');
            onTime++;
          }
        } catch (e) {
          // If there's an error processing the document, count as absent
          _logger.e('Error processing document: $e');
          absent++;
        }
      }

      // Update the observable variables
      onTimeCount.value = onTime;
      lateCount.value = late;
      absentCount.value = absent;

      isLoading.value = false;
      update();

      // Log attendance statistics summary
      _logger.d('Attendance statistics calculated: On-time: $onTime, Late: $late, Absent: $absent, Total: ${allPresence.length}');
      
      // Play animation after data is loaded
      playStatsAnimation();
    } catch (e, stackTrace) {
      _logger.e('Error loading attendance statistics',
          error: e, stackTrace: stackTrace);

      // Set default values if there's an error
      onTimeCount.value = 0;
      lateCount.value = 0;
      absentCount.value = 0;
      allPresence.value = [];

      isLoading.value = false;
      update();
    }
  }

  // Get all presence data for statistics calculation and display
  Future<void> getAllPresenceForStats() async {
    // Apply date filter if set
    QuerySnapshot<Map<String, dynamic>> presenceData;

    if (startDate != null && endDate != null) {
      // Format dates for Firestore query
      String start = DateFormat('yyyy-MM-dd').format(startDate!);
      // Add one day to end date to make it inclusive
      String end = DateFormat('yyyy-MM-dd')
          .format(endDate!.add(const Duration(days: 1)));

      presenceData = await firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .orderBy('date', descending: true)
          .get();
    } else {
      // Get all presence records if no date filter
      presenceData = await firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .orderBy('date', descending: true)
          .get();
    }

    // Update the observable list
    allPresence.value = presenceData.docs;
    
    // Log the number of records found
    _logger.d('Found ${allPresence.length} presence records');
    
    // Verify presence data is loaded correctly
    if (allPresence.isEmpty) {
      _logger.w('No attendance records found. Check Firestore collection structure.');
    }
    
    // Debug: examine the first few records
    if (allPresence.isNotEmpty) {
      for (int i = 0; i < math.min(3, allPresence.length); i++) {
        Map<String, dynamic> data = allPresence[i].data() as Map<String, dynamic>;
        _logger.d('Sample record $i: ${allPresence[i].id}, data: $data');
        
        // Check date fields
        if (data.containsKey('date')) {
          _logger.d('Record $i has date field: ${data['date']}');
        } else {
          _logger.w('Record $i is missing date field!');
        }
        
        if (data.containsKey('masuk')) {
          _logger.d('Record $i has masuk field: ${data['masuk']}');
          
          var masukData = data['masuk'];
          if (masukData is Map<String, dynamic>) {
            if (masukData.containsKey('date')) {
              _logger.d('Record $i masuk has date: ${masukData['date']}');
            } else if (masukData.containsKey('datetime')) {
              _logger.d('Record $i masuk has datetime: ${masukData['datetime']}');
            } else {
              _logger.w('Record $i masuk does not have date or datetime fields!');
            }
          } else {
            _logger.w('Record $i masuk is not a Map: ${masukData.runtimeType}');
          }
        } else {
          _logger.w('Record $i does not have masuk field (counted as absent)');
        }
      }
    }
    
    return;
  }

  // Filter by date range - for SfDateRangePicker
  void filterByDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      startDate = start;
      endDate = end;

      // Format date range for display
      filterText =
          "${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}";
    } else {
      resetFilter();
    }

    // Reload attendance statistics with new date range
    loadAttendanceStatistics();
    update();
  }

  // Method to apply date filter (legacy method to maintain compatibility)
  void pickDate(DateTime start, DateTime end) {
    filterByDateRange(start, end);
  }

  // Method to reset date filter
  void resetFilter() {
    startDate = null;
    endDate = null;
    filterText = null;

    // Reload attendance statistics without date filter
    loadAttendanceStatistics();
    update();
  }

  // Helper method to determine status color based on check-in time
  Color getStatusColor(Map<String, dynamic> data) {
    _logger.d('getStatusColor called with data: $data');
    
    if (data["masuk"] == null) {
      _logger.d('masuk data is null, returning red (absent)');
      return Colors.red;
    }

    try {
      Map<String, dynamic>? masukData = data["masuk"] as Map<String, dynamic>?;
      if (masukData == null) {
        _logger.d('masuk data is null after casting, returning red');
        return Colors.red;
      }

      String? dateStr = masukData["date"] as String? ?? masukData["datetime"] as String?;
      if (dateStr == null) {
        _logger.d('No date string found in masuk data, returning red');
        return Colors.red;
      }

      DateTime? masukDateTime = DateTime.tryParse(dateStr);
      if (masukDateTime == null) {
        _logger.e('Failed to parse date: $dateStr, returning red');
        return Colors.red;
      }

      // Create target time (8:15 AM) on the same day
      DateTime targetTime = DateTime(
        masukDateTime.year,
        masukDateTime.month,
        masukDateTime.day,
        8,
        15,
      );

      _logger.d('Check-in time: $masukDateTime, Target time: $targetTime');
      
      // Use isAfter for more accurate comparison (instead of string comparison)
      bool isLate = masukDateTime.isAfter(targetTime);
      _logger.d('Is late? $isLate');
      
      if (isLate) {
        _logger.d('Check-in time is after target time, returning orange (late)');
        return Colors.orange;
      }
      
      _logger.d('Check-in time is before target time, returning green (on-time)');
      return Colors.green;
    } catch (e) {
      _logger.e('Error in getStatusColor: $e');
      return Colors.red;
    }
  }

  // Helper function for normalizing presence data for detail view
  Map<String, dynamic> normalizePresenceData(Map<String, dynamic> data, String docId) {
    _logger.d('Normalizing presence data for document: $docId');
    
    _logger.d('Original data: $data');
    
    // Create a deep copy to avoid modifying the original data
    Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
    
    // Helper function to normalize time data
    Map<String, dynamic> normalizeTimeData(Map<String, dynamic> timeData, String type) {
      Map<String, dynamic> result = Map<String, dynamic>.from(timeData);
      
      // Extract date string from either field
      String? dateStr = timeData["date"] as String? ?? timeData["datetime"] as String?;
      
      if (dateStr != null) {
        try {
          // Validate date string by parsing it
          DateTime? parsedDate = DateTime.tryParse(dateStr);
          if (parsedDate != null) {
            // Use ISO format for consistency
            String isoDate = parsedDate.toIso8601String();
            result["date"] = isoDate;
            result["datetime"] = isoDate;
            _logger.d('Normalized $type date: $isoDate (from $dateStr)');
          } else {
            _logger.w('Could not parse $type date: $dateStr, using original');
            result["date"] = dateStr;
            result["datetime"] = dateStr;
          }
        } catch (e) {
          _logger.e('Error normalizing $type date: $e');
          result["date"] = dateStr;
          result["datetime"] = dateStr;
        }
      } else {
        _logger.w('No date found in $type data');
      }
      
      return result;
    }
    
    // Ensure masuk data exists and is properly structured
    if (normalized["masuk"] != null && normalized["masuk"] is Map<String, dynamic>) {
      normalized["masuk"] = normalizeTimeData(normalized["masuk"] as Map<String, dynamic>, "masuk");
      _logger.d('Normalized masuk data: ${normalized["masuk"]}');
    } else {
      // Create empty masuk data if missing
      normalized["masuk"] = <String, dynamic>{};
      _logger.d('Created empty masuk data');
    }
    
    // Ensure keluar data exists and is properly structured
    if (normalized["keluar"] != null && normalized["keluar"] is Map<String, dynamic>) {
      normalized["keluar"] = normalizeTimeData(normalized["keluar"] as Map<String, dynamic>, "keluar");
      _logger.d('Normalized keluar data: ${normalized["keluar"]}');
    } else {
      // Create empty keluar data if missing
      normalized["keluar"] = <String, dynamic>{};
      _logger.d('Created empty keluar data');
    }
    
    // Ensure main date field exists
    if (!normalized.containsKey("date") || normalized["date"] == null) {
      Map<String, dynamic>? masukData = normalized["masuk"] as Map<String, dynamic>?;
      if (masukData != null) {
        String? dateStr = masukData["date"] as String? ?? masukData["datetime"] as String?;
        if (dateStr != null) {
          normalized["date"] = dateStr;
          _logger.d('Set main date from masuk data: $dateStr');
        }
      }
    }
    
    // Add document ID
    normalized["id"] = docId;
    
    // Add status information
    try {
      // Determine status color
      Color statusColor = getStatusColor(data);
      
      // Convert status color to text representation
      String status = "Tidak Hadir";
      String statusColorStr = "red";
      
      if (statusColor == Colors.green) {
        status = "Tepat Waktu";
        statusColorStr = "green";
      } else if (statusColor == Colors.orange) {
        status = "Terlambat";
        statusColorStr = "orange";
      }
      
      // Add status information to normalized data
      normalized["status"] = status;
      normalized["statusColor"] = statusColorStr;
      
      _logger.d('Added status: $status, color: $statusColorStr');
    } catch (e) {
      _logger.e('Error adding status information: $e');
      normalized["status"] = "Tidak Hadir";
      normalized["statusColor"] = "red";
    }
    
    _logger.d('Final normalized data: $normalized');
    return normalized;
  }
}
