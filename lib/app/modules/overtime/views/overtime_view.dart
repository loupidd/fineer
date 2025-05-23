import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/overtime_controller.dart';

class OvertimeView extends GetView<OvertimeController> {
  final pageC = Get.find<PageIndexController>();
  OvertimeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Overtime Request",
          style: TextStyle(
            color: Color(0xFF2069B3),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Show history of overtime requests
              Get.bottomSheet(
                _buildOvertimeHistorySheet(),
                isScrollControlled: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
            },
            icon: Icon(Icons.history_rounded, color: Color(0xFF2069B3)),
          ),
        ],
      ),
      body: Obx(() => Stack(
            children: [
              // Main content
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Color(0xFF2069B3)
                                    .withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.access_time_filled_rounded,
                                color: Color(0xFF2069B3),
                              ),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "New Overtime Request",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Fill in the details below",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 25),

                        // Employee Info Section
                        Obx(() => AnimatedContainer(
                              duration: Duration(milliseconds: 500),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: EdgeInsets.all(15),
                              child: controller.isLoading.value
                                  ? Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFF2069B3)),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Color(0xFF2069B3),
                                          child: Obx(() => Text(
                                                controller.userDataMap[
                                                                'name'] !=
                                                            null &&
                                                        controller.userDataMap
                                                            ['name']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? controller
                                                        .userDataMap['name']
                                                        .toString()
                                                        .substring(0, 2)
                                                        .toUpperCase()
                                                    : "NA",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              )),
                                        ),
                                        SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Obx(() => Text(
                                                    controller.userDataMap
                                                            ['name'] ??
                                                        "Name not available",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  )),
                                              SizedBox(height: 2),
                                              Obx(() => Text(
                                                    "Employee ID: ${controller.userDataMap['employeeId'] ?? 'N/A'}",
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            )),

                        SizedBox(height: 25),

                        // Date and Time Selection
                        Text(
                          "Date & Time",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 15),

                        // Date Selection
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
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
                              controller.tanggalC.text =
                                  DateFormat('dd MMM yyyy').format(picked);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: Color(0xFF2069B3)),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    controller.tanggalC.text.isEmpty
                                        ? "Select Date"
                                        : controller.tanggalC.text,
                                    style: TextStyle(
                                      color: controller.tanggalC.text.isEmpty
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 15),

                        // Time Selection
                        InkWell(
                          onTap: () async {
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
                              final dt = DateTime(now.year, now.month, now.day,
                                  picked.hour, picked.minute);
                              controller.waktuC.text =
                                  DateFormat('HH:mm').format(dt);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    color: Color(0xFF2069B3)),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    controller.waktuC.text.isEmpty
                                        ? "Select Time"
                                        : controller.waktuC.text,
                                    style: TextStyle(
                                      color: controller.waktuC.text.isEmpty
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 25),

                        // Duration
                        Text(
                          "Overtime Duration",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 15),

                        // Duration Selector
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => controller.decrementDuration(),
                                icon: Icon(Icons.remove_circle_outline,
                                    color: Color(0xFF2069B3)),
                              ),
                              Text(
                                "${controller.duration.value} hours",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                onPressed: () => controller.incrementDuration(),
                                icon: Icon(Icons.add_circle_outline,
                                    color: Color(0xFF2069B3)),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 25),

                        // Work Description
                        Text(
                          "Work Description",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 15),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: controller.desC,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "Describe your overtime work...",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(15),
                            ),
                          ),
                        ),

                        SizedBox(height: 25),

                        // Category Selection
                        Text(
                          "Overtime Category",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 15),

                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoryButton(
                                "Urgent",
                                Icons.priority_high_rounded,
                                Colors.red[400]!,
                                controller.selectedCategory.value == "Urgent",
                                () => controller.selectCategory("Urgent"),
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: _buildCategoryButton(
                                "Regular",
                                Icons.work_outline_rounded,
                                Colors.blue[400]!,
                                controller.selectedCategory.value == "Regular",
                                () => controller.selectCategory("Regular"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 25),

                  // Submit Button
                  GestureDetector(
                    onTap: () {
                      if (controller.isFormValid()) {
                        controller.isSubmitting.value = true;
                        controller.submitOvertimeRequest().then((_) {
                          controller.isSubmitting.value = false;
                          controller.isSuccess.value = true;

                          // Auto-hide success message after 3 seconds
                          Future.delayed(Duration(seconds: 3), () {
                            controller.isSuccess.value = false;
                            controller.resetForm();
                          });
                        }).catchError((error) {
                          controller.isSubmitting.value = false;
                          Get.snackbar(
                            "Error",
                            "Failed to submit overtime request: ${error.toString()}",
                            backgroundColor: Colors.red[100],
                            colorText: Colors.red[800],
                            margin: EdgeInsets.all(15),
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        });
                      } else {
                        Get.snackbar(
                          "Form Error",
                          "Please fill all the required fields",
                          backgroundColor: Colors.red[100],
                          colorText: Colors.red[800],
                          margin: EdgeInsets.all(15),
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF2069B3),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2069B3)
                                .withAlpha((0.3 * 255).round()),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Submit Request",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 100), // Space for bottom navigation
                ],
              ),

              // Loading Overlay
              Obx(() => controller.isSubmitting.value
                  ? Container(
                      color: Colors.black..withAlpha((0.3 * 255).round()),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2069B3)),
                              ),
                              SizedBox(height: 15),
                              Text(
                                "Submitting...",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink()),

              // Success Overlay
              Obx(() => controller.isSuccess.value
                  ? Container(
                      color: Colors.black..withAlpha((0.3 * 255).round()),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(30),
                          margin: EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 50,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                "Success!",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Your overtime request has been submitted",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink()),
            ],
          )),

      // Bottom Navigation Bar (replaced with custom implementation)
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.white,
        elevation: 0,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavBarItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: pageC.pageIndex.value == 0,
              ),
              _buildNavBarItem(
                icon: Icons.history,
                label: 'Riwayat',
                index: 1,
                isSelected: pageC.pageIndex.value == 1,
              ),
              _buildNavBarItem(
                icon: Icons.access_time,
                label: 'Overtime',
                index: 2,
                isSelected: pageC.pageIndex.value == 2,
              ),
              _buildNavBarItem(
                icon: Icons.person,
                label: 'Profile',
                index: 3,
                isSelected: pageC.pageIndex.value == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem({
    required IconData icon,
    required String label,
    required int index,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () => changePage(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(
          minWidth: 60,
          maxHeight: 50,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                height: 1.0,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  void changePage(int index) {
    pageC.changePage(index);
    switch (index) {
      case 0:
        Get.offAllNamed(Routes.HOME);
        break;
      case 1:
        Get.offAllNamed(Routes.ALL_PRESENSI);
        break;
      case 2:
        Get.offAllNamed(Routes.OVERTIME);
        break;
      case 3:
        Get.offAllNamed(Routes.PROFILE);
        break;
    }
  }

  Widget _buildCategoryButton(String title, IconData icon, Color color,
      bool isSelected, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withAlpha((0.1 * 255).round()) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeHistorySheet() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Overtime Requests",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // Refresh button
                  IconButton(
                    onPressed: () {
                      controller.isLoadingHistory.value = true;
                      controller.fetchOvertimeHistory().then((_) {
                        controller.isLoadingHistory.value = false;
                      }).catchError((error) {
                        controller.isLoadingHistory.value = false;
                        Get.snackbar(
                          "Error",
                          "Failed to load overtime history: ${error.toString()}",
                          backgroundColor: Colors.red[100],
                          colorText: Colors.red[800],
                        );
                      });
                    },
                    icon: Icon(Icons.refresh),
                    color: Color(0xFF2069B3),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.close),
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 15),
          // Month picker
          InkWell(
            onTap: () => controller.selectMonth(Get.context!),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: Color(0xFF2069B3)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.monthC.text,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          SizedBox(height: 15),
          // Overtime history list (dynamic)
          Flexible(
            child: Obx(() {
              if (controller.isLoadingHistory.value) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2069B3)),
                  ),
                );
              } else if (controller.overtimeHistory.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 10),
                      Text(
                        "No overtime records found",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: controller.overtimeHistory.length,
                  itemBuilder: (context, index) {
                    final record = controller.overtimeHistory[index];

                    // Convert Timestamp to DateTime
                    final startTime = (record['startTime'] != null)
                        ? (record['startTime'] is DateTime
                            ? record['startTime'] as DateTime
                            : (record['startTime'])?.toDate() ?? DateTime.now())
                        : DateTime.now();

                    final endTime = (record['endTime'] != null)
                        ? (record['endTime'] is DateTime
                            ? record['endTime'] as DateTime
                            : (record['endTime'])?.toDate() ?? DateTime.now())
                        : startTime
                            .add(Duration(hours: controller.duration.value));

                    // Format the date and time
                    final date = DateFormat('MMM d, yyyy').format(startTime);
                    final time =
                        "${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}";

                    // Determine status color
                    Color statusColor;
                    final status = record['status'] ?? 'Pending';

                    switch (status) {
                      case 'Approved':
                        statusColor = Colors.green;
                        break;
                      case 'Rejected':
                        statusColor = Colors.red;
                        break;
                      case 'Completed':
                        statusColor = Colors.blue;
                        break;
                      case 'Pending':
                        statusColor = Colors.orange;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return _buildOvertimeHistoryItem(
                      date: date,
                      time: time,
                      status: status,
                      statusColor: statusColor,
                    );
                  },
                );
              }
            }),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOvertimeHistoryItem({
    required String date,
    required String time,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF2069B3).withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: Color(0xFF2069B3),
              size: 20,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to OvertimeController
extension OvertimeControllerExtension on OvertimeController {
  void incrementDuration() {
    duration.value++;
  }

  void decrementDuration() {
    if (duration.value > 1) {
      duration.value--;
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  bool isFormValid() {
    return tanggalC.text.isNotEmpty &&
        waktuC.text.isNotEmpty &&
        desC.text.isNotEmpty &&
        selectedCategory.value.isNotEmpty;
  }

  void resetForm() {
    tanggalC.clear();
    waktuC.clear();
    desC.clear();
    duration.value = 2;
    selectedCategory.value = "";
  }
}
