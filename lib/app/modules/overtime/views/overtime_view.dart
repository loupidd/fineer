import 'package:fineer/app/controllers/page_index_controller.dart';
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
                        AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: EdgeInsets.all(15),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Color(0xFF2069B3),
                                child: Text(
                                  "FT",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Fauzi Tanjung",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Employee ID: EMP-2023",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

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
                        Future.delayed(Duration(seconds: 2), () {
                          controller.isSubmitting.value = false;
                          controller.isSuccess.value = true;
                          Future.delayed(Duration(seconds: 2), () {
                            controller.isSuccess.value = false;
                            controller.resetForm();
                          });
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

              // Loading and Success Overlays
              if (controller.isSubmitting.value || controller.isSuccess.value)
                Container(
                  color: Colors.black.withAlpha((0.5 * 255).round()),
                  child: Center(
                    child: controller.isSubmitting.value
                        ? Container(
                            padding: EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2069B3)),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "Submitting request...",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(30),
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
                ),
            ],
          )),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, -2),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Obx(() => BottomNavigationBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                selectedItemColor: Color(0xFF2069B3),
                unselectedItemColor: Colors.grey[400],
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 11,
                ),
                type: BottomNavigationBarType.fixed,
                currentIndex: pageC.pageIndex.value,
                onTap: (index) => pageC.changePage(index),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF3782EC),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3782EC)
                                .withAlpha((0.05 * 255).round()),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.access_time_outlined),
                    activeIcon: Icon(Icons.access_time_rounded),
                    label: 'Overtime',
                  ),
                ],
              )),
        ),
      ),
    );
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
              IconButton(
                onPressed: () => Get.back(),
                icon: Icon(Icons.close),
                color: Colors.grey[700],
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildOvertimeHistoryItem(
            date: "May 5, 2025",
            time: "18:00 - 21:00",
            status: "Approved",
            statusColor: Colors.green,
          ),
          _buildOvertimeHistoryItem(
            date: "Apr 28, 2025",
            time: "17:30 - 20:30",
            status: "Completed",
            statusColor: Colors.blue,
          ),
          _buildOvertimeHistoryItem(
            date: "Apr 15, 2025",
            time: "18:00 - 22:00",
            status: "Rejected",
            statusColor: Colors.red,
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
  // These methods would need to be implemented in your controller
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

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  bool isFormValid() {
    return nameC.text.isNotEmpty &&
        tanggalC.text.isNotEmpty &&
        waktuC.text.isNotEmpty &&
        desC.text.isNotEmpty &&
        selectedCategory.value.isNotEmpty;
  }

  void resetForm() {
    nameC.clear();
    tanggalC.clear();
    waktuC.clear();
    desC.clear();
    duration.value = 2;
    selectedCategory.value = "";
  }
}
