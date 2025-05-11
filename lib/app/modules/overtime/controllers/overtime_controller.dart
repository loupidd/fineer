import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OvertimeController extends GetxController {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User data
  var userData = {}.obs;
  var userOvertimeHistory = <Map<String, dynamic>>[].obs;

  // Text controllers
  final TextEditingController nameC = TextEditingController();
  final TextEditingController tanggalC = TextEditingController();
  final TextEditingController waktuC = TextEditingController();
  final TextEditingController desC = TextEditingController();
  final TextEditingController monthC =
      TextEditingController(); // For month selection

  // Observable values for UI states
  var isSubmitting = false.obs;
  var isSuccess = false.obs;
  var isLoading = true.obs;
  var duration = 2.obs;
  var selectedCategory = "".obs;

  // Selected date as DateTime object for proper handling
  var selectedDate = Rx<DateTime?>(null);
  var selectedMonth = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchUserData();
    fetchOvertimeHistory();

    // Set current month in the month controller
    final now = DateTime.now();
    monthC.text = DateFormat('MMMM yyyy').format(now);
    selectedMonth.value = now;
  }

  // Fetch current user data
  Future<void> fetchUserData() async {
    try {
      isLoading.value = true;
      final User? user = _auth.currentUser;

      if (user != null) {
        final docSnapshot =
            await _firestore.collection('employees').doc(user.uid).get();

        if (docSnapshot.exists) {
          userData.value = docSnapshot.data() ?? {};
          nameC.text = userData['name'] ?? '';
        } else {
          Get.snackbar("Error", "User profile not found",
              backgroundColor: Colors.red[100], colorText: Colors.red[800]);
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load user data: $e",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch overtime history for current user
  Future<void> fetchOvertimeHistory() async {
    try {
      final User? user = _auth.currentUser;

      if (user != null) {
        final querySnapshot = await _firestore
            .collection('overtime')
            .where('userId', isEqualTo: user.uid)
            .orderBy('dateSubmitted', descending: true)
            .get();

        userOvertimeHistory.value = querySnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load overtime history: $e",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    }
  }

  // Date picker method
  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2069B3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedDate.value = picked;
      tanggalC.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  // Time picker method
  Future<void> selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2069B3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      waktuC.text = DateFormat('HH:mm').format(dt);
    }
  }

  // Month picker method
  Future<void> selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth.value ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2069B3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedMonth.value = picked;
      monthC.text = DateFormat('MMMM yyyy').format(picked);

      // Optionally refresh overtime data for the selected month
      fetchOvertimeHistoryByMonth(picked);
    }
  }

  // Fetch overtime history for specific month
  Future<void> fetchOvertimeHistoryByMonth(DateTime month) async {
    try {
      isLoading.value = true;
      final User? user = _auth.currentUser;

      if (user != null) {
        // Calculate start and end of month
        final startOfMonth = DateTime(month.year, month.month, 1);
        final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

        final querySnapshot = await _firestore
            .collection('overtime')
            .where('userId', isEqualTo: user.uid)
            .where('dateSubmitted',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('dateSubmitted',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .orderBy('dateSubmitted', descending: true)
            .get();

        userOvertimeHistory.value = querySnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load overtime history: $e",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isLoading.value = false;
    }
  }

  // Methods for duration modification
  void incrementDuration() {
    if (duration.value < 12) {
      duration.value++;
    }
  }

  void decrementDuration() {
    if (duration.value > 1) {
      duration.value--;
    }
  }

  // Category selection
  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  // Validate form
  bool isFormValid() {
    return nameC.text.isNotEmpty &&
        tanggalC.text.isNotEmpty &&
        waktuC.text.isNotEmpty &&
        desC.text.isNotEmpty &&
        selectedCategory.value.isNotEmpty;
  }

  // Submit overtime request to Firebase
  Future<void> submitOvertimeRequest() async {
    if (!isFormValid()) {
      Get.snackbar(
        "Form Error",
        "Please fill all the required fields",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isSubmitting.value = true;
      final User? user = _auth.currentUser;

      if (user != null && selectedDate.value != null) {
        // Parse time string to get hours and minutes
        final timeParts = waktuC.text.split(':');
        final hours = int.parse(timeParts[0]);
        final minutes = int.parse(timeParts[1]);

        // Create a DateTime that combines the selected date and time
        final selectedDateTime = DateTime(selectedDate.value!.year,
            selectedDate.value!.month, selectedDate.value!.day, hours, minutes);

        // Calculate end time based on duration
        final endDateTime =
            selectedDateTime.add(Duration(hours: duration.value));

        // Create overtime document
        await _firestore.collection('overtime').add({
          'userId': user.uid,
          'employeeName': nameC.text,
          'employeeId': userData['employeeId'] ?? '',
          'startTime': Timestamp.fromDate(selectedDateTime),
          'endTime': Timestamp.fromDate(endDateTime),
          'duration': duration.value,
          'description': desC.text,
          'category': selectedCategory.value,
          'status': 'Pending', // Default status
          'dateSubmitted': Timestamp.fromDate(DateTime.now()),
        });

        // Show success message
        isSuccess.value = true;
        await Future.delayed(Duration(seconds: 2));

        // Reset form and refresh history
        resetForm();
        fetchOvertimeHistory();
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to submit overtime request: $e",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isSubmitting.value = false;
      isSuccess.value = false;
    }
  }

  // Reset form
  void resetForm() {
    // Keep the name as it comes from user profile
    tanggalC.clear();
    waktuC.clear();
    desC.clear();
    duration.value = 2;
    selectedCategory.value = "";
    selectedDate.value = null;
  }

  @override
  void onClose() {
    nameC.dispose();
    tanggalC.dispose();
    waktuC.dispose();
    desC.dispose();
    monthC.dispose();
    super.onClose();
  }
}
