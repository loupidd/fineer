import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../controllers/all_presensi_controller.dart';
import 'package:fineer/app/controllers/page_index_controller.dart';

class AllPresensiView extends GetView<AllPresensiController> {
  AllPresensiView({super.key});

  final pageC = Get.find<PageIndexController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue,
        title: const Text(
          'Riwayat Presensi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show date range picker dialog
              _showDateRangePickerDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status header section with animation
          AnimatedBuilder(
            animation: controller.statsAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.95 + (0.05 * controller.statsAnimation.value),
                child: Opacity(
                  opacity: controller.statsAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Color(0xFF1565C0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha((0.3 * 255).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Obx(
                      () {
                        // Get actual data from controller
                        int onTimeCount = controller.onTimeCount.value;
                        int lateCount = controller.lateCount.value;
                        int absentCount = controller.absentCount.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Periode Laporan',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withAlpha((0.2 * 255).round()),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    controller.filterText ?? 'Semua',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Tepat Waktu',
                                  onTimeCount.toString(),
                                  Icons.check_circle_outline,
                                  Colors.greenAccent,
                                ),
                                _buildStatItem(
                                  'Terlambat',
                                  lateCount.toString(),
                                  Icons.warning_outlined,
                                  Colors.orangeAccent,
                                ),
                                _buildStatItem(
                                  'Tidak Hadir',
                                  absentCount.toString(),
                                  Icons.cancel_outlined,
                                  Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 16, top: 24),
              child: Text("Riwayat Kehadiran",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          // List of attendance entries
          Expanded(
            child: Obx(
              () => controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : controller.allPresence.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada riwayat presensi',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          itemCount: controller.presenceLength,
                          itemBuilder: (context, index) {
                            DocumentSnapshot doc =
                                controller.allPresence[index];
                            Map<String, dynamic> data =
                                doc.data() as Map<String, dynamic>;

                            // Helper function to get date string from either field
                            String? getDateString(Map<String, dynamic>? dataMap,
                                String fieldName) {
                              if (dataMap == null) {
                                return null;
                              }
                              String? result = dataMap[fieldName] as String? ??
                                  dataMap["${fieldName}time"] as String?;
                              return result;
                            }

                            // Safely parse date
                            DateTime? parseDate(String? dateStr) {
                              if (dateStr == null) return null;
                              try {
                                return DateTime.parse(dateStr);
                              } catch (e) {
                                return null;
                              }
                            }

                            // Parse main date
                            DateTime? date;
                            String? dateStr = getDateString(data, 'date');
                            if (dateStr != null) {
                              date = parseDate(dateStr);
                            }

                            // Format day of month, day name, and full date
                            String dayOfMonth = date != null
                                ? DateFormat('d').format(date)
                                : "--";
                            String dayName = date != null
                                ? DateFormat('EEEE').format(date)
                                : "Unknown";
                            String fullDate = date != null
                                ? DateFormat('MMMM d, yyyy').format(date)
                                : "--";

                            // Get status color
                            Color statusColor = Colors.red;

                            if (data['masuk'] != null) {
                              try {
                                statusColor = controller.getStatusColor(data);
                              } catch (e) {
                                statusColor = Colors.red;
                              }
                            }

                            // Get check-in time
                            String checkInTime = '--:--';
                            if (data['masuk'] != null) {
                              Map<String, dynamic>? masukData;
                              try {
                                masukData =
                                    data['masuk'] as Map<String, dynamic>?;
                                if (masukData != null) {
                                  String? masukDateStr =
                                      getDateString(masukData, 'date');
                                  DateTime? masukDate = parseDate(masukDateStr);
                                  if (masukDate != null) {
                                    checkInTime =
                                        DateFormat.Hm().format(masukDate);
                                  }
                                }
                              } catch (e) {
                                Get.log('Error parsing check-in data: $e');
                              }
                            }

                            // Get check-out time
                            String checkOutTime = '--:--';
                            if (data['keluar'] != null) {
                              Map<String, dynamic>? keluarData;
                              try {
                                keluarData =
                                    data['keluar'] as Map<String, dynamic>?;
                                if (keluarData != null) {
                                  String? keluarDateStr =
                                      getDateString(keluarData, 'date');
                                  DateTime? keluarDate =
                                      parseDate(keluarDateStr);
                                  if (keluarDate != null) {
                                    checkOutTime =
                                        DateFormat.Hm().format(keluarDate);
                                  }
                                }
                              } catch (e) {
                                Get.log('Error parsing check-out data: $e');
                              }
                            }

                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 500),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(13),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Map<String, dynamic> normalizedData =
                                            _prepareDataForDetailView(
                                                data, doc.id);
                                        Get.toNamed(
                                          Routes.DETAIL_PRESENSI,
                                          arguments: normalizedData,
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          // Date circle
                                          Container(
                                            width: 80,
                                            padding: const EdgeInsets.all(16),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.blue.withAlpha(26),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  dayOfMonth,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Content area
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            dayName,
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            fullDate,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 16),
                                                        child: Container(
                                                          width: 12,
                                                          height: 12,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: statusColor,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Masuk',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.login,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .blue,
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  checkInTime,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Keluar',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.logout,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .orange,
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  checkOutTime,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildBottomNavBar(),
    );
  }

  // Helper method to build stat item
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // Date range picker dialog
  void _showDateRangePickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Periode',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: SfDateRangePicker(
                  controller: controller.dateRangePickerController,
                  view: DateRangePickerView.month,
                  selectionMode: DateRangePickerSelectionMode.range,
                  showActionButtons: true,
                  cancelText: 'Batal',
                  confirmText: 'Terapkan',
                  onCancel: () {
                    Get.back();
                  },
                  onSubmit: (value) {
                    if (value != null && value is PickerDateRange) {
                      controller.filterByDateRange(
                          value.startDate, value.endDate);
                      Get.back();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Implement the bottom navigation bar
  Widget buildBottomNavBar() {
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
              buildNavBarItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: pageC.pageIndex.value == 0,
              ),
              buildNavBarItem(
                icon: Icons.history,
                label: 'Riwayat',
                index: 1,
                isSelected: pageC.pageIndex.value == 1,
              ),
              buildNavBarItem(
                icon: Icons.person,
                label: 'Profile',
                index: 2,
                isSelected: pageC.pageIndex.value == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNavBarItem({
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
        Get.offAllNamed(Routes.PROFILE);
        break;
    }
  }

  // Helper method to prepare data structure for detail view
  Map<String, dynamic> _prepareDataForDetailView(
      Map<String, dynamic> originalData, String docId) {
    // Use the controller's normalize method which has proper data handling
    return controller.normalizePresenceData(originalData, docId);
  }
}
