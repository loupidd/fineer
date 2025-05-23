import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/logger_service.dart';

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
  var isLoadingHistory =
      false.obs; // New variable for tracking history loading state
  var duration = 2.obs;
  var selectedCategory = "".obs;

  // Selected date as DateTime object for proper handling
  var selectedDate = Rx<DateTime?>(null);
  var selectedMonth = Rx<DateTime?>(null);

  // Getters for UI convenience
  bool get showSuccess => isSuccess.value;

  // Getter for userData to avoid direct .value access in views
  Map<String, dynamic> get userDataMap => Map<String, dynamic>.from(userData);

  // Additional getters for other Rx properties
  List<Map<String, dynamic>> get overtimeHistory =>
      userOvertimeHistory.toList();

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

          // Set employee name for form
          nameC.text = userData['name'] ?? '';

          // Log retrieved data for debugging
          LoggerService.debug(
              'Retrieved employee data: ${userData.toString()}');
          LoggerService.debug('Employee ID: ${userData['employeeId']}');
          LoggerService.debug('Department: ${userData['job']}');
          LoggerService.debug('Position: ${userData['position']}');

          // Check for missing critical fields
          if (userData['employeeId'] == null ||
              userData['employeeId'].toString().isEmpty) {
            LoggerService.warning('Employee ID is missing');
          }
          if (userData['job'] == null || userData['job'].toString().isEmpty) {
            LoggerService.warning('Job/Department is missing');
          }
          if (userData['position'] == null ||
              userData['position'].toString().isEmpty) {
            LoggerService.warning('Position is missing');
          }
        } else {
          Get.snackbar("Profile Error",
              "User profile not found. Please complete your profile first.",
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              duration: Duration(seconds: 3));
        }
      }
    } catch (e) {
      LoggerService.error('Error fetching user data', e);
      Get.snackbar("Error",
          "Failed to load user data: ${e.toString().split('\n').first}",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch overtime history for current user
  Future<void> fetchOvertimeHistory() async {
    try {
      isLoadingHistory.value = true;
      final User? user = _auth.currentUser;

      if (user != null) {
        // First ensure we have up-to-date user data
        await fetchUserData();

        bool indexCreated = false;
        int retryCount = 0;

        // Try up to 2 times with a small delay to allow for index creation
        while (!indexCreated && retryCount < 2) {
          try {
            // First try with the indexed query (requires a compound index on userId + dateSubmitted)
            final querySnapshot = await _firestore
                .collection('overtime')
                .where('userId', isEqualTo: user.uid)
                .orderBy('dateSubmitted', descending: true)
                .get();

            // Transform the results
            var results = querySnapshot.docs.map((doc) {
              var data = doc.data();

              // Add missing fields if needed to ensure consistent display
              if (data['employeeId'] == null ||
                  data['employeeId'].toString().isEmpty) {
                data['employeeId'] = userData['employeeId'] ?? '';
              }
              if (data['department'] == null ||
                  data['department'].toString().isEmpty) {
                data['department'] = userData['job'] ?? '';
              }
              if (data['position'] == null ||
                  data['position'].toString().isEmpty) {
                data['position'] = userData['position'] ?? '';
              }

              return {
                'id': doc.id,
                ...data,
              };
            }).toList();

            userOvertimeHistory.value = results;
            indexCreated = true;

            LoggerService.info(
                'Successfully fetched ${results.length} overtime records');
          } catch (error) {
            if (error.toString().contains('index')) {
              // This is an index error, let's wait briefly and retry
              if (retryCount == 0) {
                // On first retry, show a message
                Get.snackbar("Optimizing Database",
                    "Setting up query indexes for better performance...",
                    backgroundColor: Colors.blue[100],
                    colorText: Colors.blue[800],
                    duration: Duration(seconds: 2));

                await Future.delayed(Duration(seconds: 1));
              }
              retryCount++;
            } else {
              // Not an index error, rethrow
              rethrow;
            }
          }
        }

        // If we still don't have the index after retries, fall back to client-side sorting
        if (!indexCreated) {
          // Fallback to a basic query if the compound index doesn't exist
          final querySnapshot = await _firestore
              .collection('overtime')
              .where('userId', isEqualTo: user.uid)
              .get();

          // Transform and sort the results in memory
          var results = querySnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();

          // Sort by dateSubmitted in descending order
          results.sort((a, b) {
            var aDate = a['dateSubmitted'] as Timestamp?;
            var bDate = b['dateSubmitted'] as Timestamp?;

            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate); // Descending order
          });

          userOvertimeHistory.value = results;

          // Show a notification about using unoptimized query
          Get.snackbar("Database Notice",
              "Using alternate query method. Performance will improve in future sessions.",
              backgroundColor: Colors.amber[50],
              colorText: Colors.amber[800],
              duration: Duration(seconds: 2));
        }
      } else {
        Get.snackbar("Authentication Error",
            "Please log in to view your overtime history",
            backgroundColor: Colors.amber[100], colorText: Colors.amber[800]);
      }
    } catch (e) {
      Get.snackbar("Error",
          "Failed to load overtime history: ${e.toString().split('\n').first}",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isLoadingHistory.value = false;
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
      isLoadingHistory.value = true;
      final User? user = _auth.currentUser;

      if (user != null) {
        // First ensure we have up-to-date user data
        await fetchUserData();

        // Calculate start and end of month
        final startOfMonth = DateTime(month.year, month.month, 1);
        final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
        final startTimestamp = Timestamp.fromDate(startOfMonth);
        final endTimestamp = Timestamp.fromDate(endOfMonth);

        String monthName = DateFormat('MMMM yyyy').format(month);
        LoggerService.debug(
            'Fetching overtime for $monthName (${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()})');

        try {
          // First try with the indexed query
          final querySnapshot = await _firestore
              .collection('overtime')
              .where('userId', isEqualTo: user.uid)
              .where('dateSubmitted', isGreaterThanOrEqualTo: startTimestamp)
              .where('dateSubmitted', isLessThanOrEqualTo: endTimestamp)
              .orderBy('dateSubmitted', descending: true)
              .get();

          // Transform the results with proper field mapping
          var results = querySnapshot.docs.map((doc) {
            var data = doc.data();

            // Add missing fields if needed to ensure consistent display
            if (data['employeeId'] == null ||
                data['employeeId'].toString().isEmpty) {
              data['employeeId'] = userData['employeeId'] ?? '';
            }
            if (data['department'] == null ||
                data['department'].toString().isEmpty) {
              data['department'] = userData['job'] ?? '';
            }
            if (data['position'] == null ||
                data['position'].toString().isEmpty) {
              data['position'] = userData['position'] ?? '';
            }

            return {
              'id': doc.id,
              ...data,
            };
          }).toList();

          userOvertimeHistory.value = results;
          LoggerService.info(
              'Successfully fetched ${results.length} records for $monthName using optimized query');
        } catch (indexError) {
          LoggerService.error('Optimized query failed', indexError);

          // Inform user about index creation
          if (indexError.toString().contains('index')) {
            Get.snackbar("Database Optimization",
                "Creating index for faster queries. This may take a moment.",
                backgroundColor: Colors.blue[50],
                colorText: Colors.blue[800],
                duration: Duration(seconds: 2));
          }

          // Try alternative approach with a simpler query
          try {
            LoggerService.debug('Trying alternative approach for $monthName');
            // Get all overtime records for this user
            final querySnapshot = await _firestore
                .collection('overtime')
                .where('userId', isEqualTo: user.uid)
                .get();

            // Filter and sort data client-side
            var results = querySnapshot.docs.map((doc) {
              var data = doc.data();

              // Add missing fields if needed to ensure consistent display
              if (data['employeeId'] == null ||
                  data['employeeId'].toString().isEmpty) {
                data['employeeId'] = userData['employeeId'] ?? '';
              }
              if (data['department'] == null ||
                  data['department'].toString().isEmpty) {
                data['department'] = userData['job'] ?? '';
              }
              if (data['position'] == null ||
                  data['position'].toString().isEmpty) {
                data['position'] = userData['position'] ?? '';
              }

              return {
                'id': doc.id,
                ...data,
              };
            }).where((doc) {
              // Filter by date range
              Timestamp? docDate = doc['dateSubmitted'] as Timestamp?;
              if (docDate == null) return false;

              return docDate.compareTo(startTimestamp) >= 0 &&
                  docDate.compareTo(endTimestamp) <= 0;
            }).toList();

            // Sort by date (descending)
            results.sort((a, b) {
              var aDate = a['dateSubmitted'] as Timestamp?;
              var bDate = b['dateSubmitted'] as Timestamp?;

              if (aDate == null || bDate == null) return 0;
              return bDate.compareTo(aDate); // Descending order
            });

            userOvertimeHistory.value = results;
            LoggerService.info(
                'Successfully fetched ${results.length} records for $monthName using alternative approach');
          } catch (fallbackError) {
            // If even the fallback fails, log and show error
            LoggerService.error('Alternative approach failed', fallbackError);
            Get.snackbar("Error",
                "Failed to load overtime history for $monthName: ${fallbackError.toString().split('\n').first}",
                backgroundColor: Colors.red[100], colorText: Colors.red[800]);
          }
        }

        // Handle case of no results found
        if (userOvertimeHistory.isEmpty) {
          Get.snackbar("No Records", "No overtime records found for $monthName",
              backgroundColor: Colors.grey[100],
              colorText: Colors.grey[800],
              duration: Duration(seconds: 2));
        } else {
          // Show success message with count
          Get.snackbar("Records Found",
              "Found ${userOvertimeHistory.length} overtime records for $monthName",
              backgroundColor: Colors.green[50],
              colorText: Colors.green[800],
              duration: Duration(seconds: 2));
        }
      } else {
        Get.snackbar("Authentication Error",
            "Please log in to view your overtime history",
            backgroundColor: Colors.amber[100], colorText: Colors.amber[800]);
      }
    } catch (e) {
      LoggerService.error('Month filtering error', e);
      Get.snackbar("Error",
          "Failed to load overtime history: ${e.toString().split('\n').first}",
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    } finally {
      isLoadingHistory.value = false;
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

  // Validate the submitted overtime request
  bool validateOvertimeRequest() {
    // Basic form validation
    if (!isFormValid()) {
      Get.snackbar(
        "Form Error",
        "Please fill all the required fields",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // Date validation - ensure it's not null and in the future
    if (selectedDate.value == null) {
      Get.snackbar(
        "Date Error",
        "Please select a valid date",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
      );
      return false;
    }

    // Time validation
    if (waktuC.text.isEmpty) {
      Get.snackbar(
        "Time Error",
        "Please select a valid time",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
      );
      return false;
    }

    // Duration check
    if (duration.value < 1 || duration.value > 12) {
      Get.snackbar(
        "Duration Error",
        "Duration must be between 1 and 12 hours",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
      );
      return false;
    }

    // Category validation
    if (selectedCategory.value.isEmpty) {
      Get.snackbar(
        "Category Error",
        "Please select an overtime category",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
      );
      return false;
    }

    return true;
  }

  // Submit overtime request to Firebase
  Future<void> submitOvertimeRequest() async {
    if (!validateOvertimeRequest()) {
      return;
    }

    // Refresh user data to ensure we have the latest information
    await fetchUserData();

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

        // Get correct field values from user data
        final employeeId = userData['employeeId'] ?? '';
        final department =
            userData['job'] ?? ''; // Using job field for department
        final position = userData['position'] ?? '';

        LoggerService.debug('Submitting overtime with employee data:');
        LoggerService.debug('Employee ID: $employeeId');
        LoggerService.debug('Department: $department');
        LoggerService.debug('Position: $position');

        // Create overtime document with correct field mappings
        DocumentReference docRef = await _firestore.collection('overtime').add({
          'userId': user.uid,
          'employeeName': nameC.text,
          'employeeId': employeeId, // NIK
          'startTime': Timestamp.fromDate(selectedDateTime),
          'endTime': Timestamp.fromDate(endDateTime),
          'duration': duration.value,
          'description': desC.text,
          'category': selectedCategory.value,
          'status': 'Pending', // Default status
          'dateSubmitted': Timestamp.fromDate(DateTime.now()),
          'department': department, // Using job field
          'position': position,
          'email': user.email ?? '',
        });

        // Add the new document to the local history with the same field mappings
        userOvertimeHistory.insert(0, {
          'id': docRef.id,
          'userId': user.uid,
          'employeeName': nameC.text,
          'employeeId': employeeId, // NIK
          'startTime': Timestamp.fromDate(selectedDateTime),
          'endTime': Timestamp.fromDate(endDateTime),
          'duration': duration.value,
          'description': desC.text,
          'category': selectedCategory.value,
          'status': 'Pending',
          'dateSubmitted': Timestamp.fromDate(DateTime.now()),
          'department': department, // Using job field
          'position': position,
          'email': user.email ?? '',
        });

        // Show success message
        isSuccess.value = true;
        Get.snackbar(
          "Success",
          "Overtime request submitted successfully",
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          margin: EdgeInsets.all(15),
          duration: Duration(seconds: 2),
        );

        await Future.delayed(Duration(seconds: 2));

        // Reset form
        resetForm();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to submit overtime request: $e",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
      );
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
