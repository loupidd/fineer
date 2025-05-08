import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../controllers/all_presensi_controller.dart';

class AllPresensiView extends GetView<AllPresensiController> {
  const AllPresensiView({super.key});
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
                            controller.isLoading.value
                                ? const Center(
                                    child: SizedBox(
                                      height: 70,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _StatItem(
                                        label: 'Tepat Waktu',
                                        value: onTimeCount.toString(),
                                        iconData: Icons.check_circle_outline,
                                        color: Colors.greenAccent,
                                        animationValue:
                                            controller.statsAnimation.value,
                                      ),
                                      _StatItem(
                                        label: 'Terlambat',
                                        value: lateCount.toString(),
                                        iconData: Icons.access_time,
                                        color: Colors.orangeAccent,
                                        animationValue:
                                            controller.statsAnimation.value,
                                        animationDelay: 0.2,
                                      ),
                                      _StatItem(
                                        label: 'Absen',
                                        value: absentCount.toString(),
                                        iconData: Icons.cancel_outlined,
                                        color: Colors.redAccent,
                                        animationValue:
                                            controller.statsAnimation.value,
                                        animationDelay: 0.4,
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

          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Riwayat Kehadiran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // Clear Filter button - only shown when filter is active
                GetBuilder<AllPresensiController>(
                  builder: (c) => c.isFilterActive
                      ? TextButton.icon(
                          onPressed: () => c.resetFilter(),
                          icon: const Icon(Icons.filter_list_off, size: 16),
                          label: const Text('Hapus Filter'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: -8),
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),

          // Attendance list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: controller.getPresenceStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: snapshot.data!.docs.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      // Apply list animation
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildAttendanceCard(
                                snapshot.data!.docs[index].data()),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Overtime',
          ),
        ],
        onTap: (index) {
          // Handle navigation based on the selected index
          switch (index) {
            case 0:
              Get.toNamed(Routes.HOME);
              break;
            case 2:
              Get.toNamed(Routes.OVERTIME);
              break;
          }
        },
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    String dateStr = data["date"] ?? "";
    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (e) {
      date = DateTime.now();
    }

    String masukTime = "--:--";
    if (data["masuk"] != null && data["masuk"]["date"] != null) {
      try {
        masukTime =
            DateFormat.Hm().format(DateTime.parse(data["masuk"]["date"]));
      } catch (e) {
        // Keep default value
      }
    }

    String keluarTime = "--:--";
    if (data["keluar"] != null && data["keluar"]["date"] != null) {
      try {
        keluarTime =
            DateFormat.Hm().format(DateTime.parse(data["keluar"]["date"]));
      } catch (e) {
        // Keep default value
      }
    }

    // Get status color from controller
    Color statusColor = controller.getStatusColor(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => Get.toNamed(
          Routes.DETAIL_PRESENSI,
          arguments: data,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat.d().format(date),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.EEEE().format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMd().format(date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Hero(
                    tag: 'status-${data["date"]}',
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TimeCard(
                      title: 'Masuk',
                      time: masukTime,
                      iconData: Icons.login,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeCard(
                      title: 'Keluar',
                      time: keluarTime,
                      iconData: Icons.logout,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat presensi',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data kehadiran akan muncul di sini',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showDateRangePickerDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Rentang Tanggal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (controller.filterText != null)
                    TextButton(
                      onPressed: () {
                        controller.resetFilter();
                        Get.back();
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SfDateRangePicker(
                  monthViewSettings: const DateRangePickerMonthViewSettings(
                    firstDayOfWeek: 1,
                  ),
                  selectionMode: DateRangePickerSelectionMode.range,
                  showActionButtons: true,
                  confirmText: 'Terapkan',
                  cancelText: 'Batal',
                  todayHighlightColor: Colors.blue,
                  selectionColor: Colors.blue,
                  rangeSelectionColor:
                      Colors.blue.withAlpha((0.2 * 255).round()),
                  startRangeSelectionColor: Colors.blue,
                  endRangeSelectionColor: Colors.blue,
                  onCancel: () => Get.back(),
                  onSubmit: (obj) {
                    if (obj != null) {
                      if ((obj as PickerDateRange).endDate != null) {
                        controller.pickDate(obj.startDate!, obj.endDate!);
                      }
                    }
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData iconData;
  final Color color;
  final double animationValue;
  final double animationDelay;

  const _StatItem({
    required this.label,
    required this.value,
    required this.iconData,
    required this.color,
    required this.animationValue,
    this.animationDelay = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate delay offset for staggered animation
    final double delayedValue = animationDelay >= animationValue
        ? 0
        : (animationValue - animationDelay) / (1 - animationDelay);

    final double scale = 0.5 + (0.5 * delayedValue);
    final double opacity = delayedValue;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData iconData;
  final Color color;

  const _TimeCard({
    required this.title,
    required this.time,
    required this.iconData,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withAlpha((0.1 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            iconData,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: time == "--:--" ? Colors.grey : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
