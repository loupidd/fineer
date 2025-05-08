import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';

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

  // For date filtering
  DateTime? startDate;
  DateTime? endDate;
  String? filterText;

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

  @override
  void onClose() {
    _statsAnimationController.dispose();
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

      // Get reference to all attendance records
      QuerySnapshot<Map<String, dynamic>> presenceData =
          await getAllPresenceForStats();

      // Reset counters
      int onTime = 0;
      int late = 0;
      int absent = 0;

      // Count attendance by category
      for (var doc in presenceData.docs) {
        Map<String, dynamic> data = doc.data();

        // Check if absent
        if (data["masuk"] == null) {
          absent++;
          continue;
        }

        // Check if late
        try {
          String masukTime =
              DateFormat.Hm().format(DateTime.parse(data["masuk"]["date"]));

          if (masukTime.compareTo("09:00") > 0) {
            late++;
          } else {
            onTime++;
          }
        } catch (e) {
          // If there's an error parsing the date, count as absent
          absent++;
        }
      }

      // Update the observable variables
      onTimeCount.value = onTime;
      lateCount.value = late;
      absentCount.value = absent;

      isLoading.value = false;
      update();

      // Play animation after data is loaded
      playStatsAnimation();
    } catch (e, stackTrace) {
      _logger.e('Error loading attendance statistics',
          error: e, stackTrace: stackTrace);

      // Set default values if there's an error
      onTimeCount.value = 0;
      lateCount.value = 0;
      absentCount.value = 0;

      isLoading.value = false;
      update();
    }
  }

  // Get all presence data for statistics calculation
  Future<QuerySnapshot<Map<String, dynamic>>> getAllPresenceForStats() async {
    // Apply date filter if set
    if (startDate != null && endDate != null) {
      // Format dates for Firestore query
      String start = DateFormat('yyyy-MM-dd').format(startDate!);
      // Add one day to end date to make it inclusive
      String end = DateFormat('yyyy-MM-dd')
          .format(endDate!.add(const Duration(days: 1)));

      return await firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .get();
    } else {
      // Get all presence records if no date filter
      return await firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .get();
    }
  }

  // Get presence data for the list display with pagination
  Stream<QuerySnapshot<Map<String, dynamic>>> getPresenceStream() {
    // Apply date filter if set
    if (startDate != null && endDate != null) {
      // Format dates for Firestore query
      String start = DateFormat('yyyy-MM-dd').format(startDate!);
      // Add one day to end date to make it inclusive
      String end = DateFormat('yyyy-MM-dd')
          .format(endDate!.add(const Duration(days: 1)));

      return firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .orderBy('date', descending: true)
          .snapshots();
    } else {
      // Get all presence records if no date filter
      return firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .orderBy('date', descending: true)
          .snapshots();
    }
  }

  // Method to apply date filter
  void pickDate(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;

    // Format date range for display
    filterText =
        "${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}";

    // Reload attendance statistics with new date range
    loadAttendanceStatistics();
    update();
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
    if (data["masuk"] == null) {
      return Colors.red;
    }

    try {
      String masukTime =
          DateFormat.Hm().format(DateTime.parse(data["masuk"]["date"]));

      if (masukTime.compareTo("09:00") > 0) {
        return Colors.orange;
      }
      return Colors.green;
    } catch (e) {
      return Colors.red;
    }
  }
}
