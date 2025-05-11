import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detail_presensi_controller.dart';
import 'package:intl/intl.dart';

class DetailPresensiView extends GetView<DetailPresensiController> {
  const DetailPresensiView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.blue,
        title: const Text(
          'Detail Presensi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Show error message if available
        if (controller.errorMessage.value != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    controller.errorMessage.value!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        if (controller.presenceData.value == null) {
          return const Center(child: Text('Data tidak ditemukan'));
        }

        final data = controller.presenceData.value!;
        
        // Make sure required fields exist
        if (data["date"] == null) {
          return const Center(
            child: Text('Data tanggal tidak ditemukan'),
          );
        }

        // Safely parse the date
        DateTime? parseDate(String? dateStr) {
          if (dateStr == null) return null;
          try {
            return DateTime.parse(dateStr);
          } catch (e) {
            print('Error parsing date: $e');
            return null;
          }
        }

        // Parse the main date
        final DateTime? date = parseDate(data["date"] as String?);
        if (date == null) {
          return const Center(
            child: Text('Format tanggal tidak valid'),
          );
        }
        
        // Calculate duration if both check-in and check-out exist
        String calculateDuration() {
          if (data["masuk"] != null &&
              data["keluar"] != null &&
              data["keluar"]?["date"] != null) {
            final DateTime? masuk = parseDate(data["masuk"]!["date"] as String?);
            final DateTime? keluar = parseDate(data["keluar"]!["date"] as String?);
            
            if (masuk != null && keluar != null) {
              final Duration duration = keluar.difference(masuk);
              final int hours = duration.inHours;
              final int minutes = duration.inMinutes % 60;
              return '$hours jam $minutes menit';
            }
          }
          return '-';
        }

        // Calculate late duration if check-in is after 8:15 AM
        String calculateLateDuration() {
          if (data["masuk"] != null && data["masuk"]?["date"] != null) {
            final DateTime? masuk = parseDate(data["masuk"]!["date"] as String?);
            if (masuk != null) {
              final DateTime expectedTime =
                  DateTime(masuk.year, masuk.month, masuk.day, 8, 15);
              
              if (masuk.isAfter(expectedTime)) {
                final Duration lateDuration = masuk.difference(expectedTime);
                final int hours = lateDuration.inHours;
                final int minutes = lateDuration.inMinutes % 60;
                
                if (hours > 0) {
                  return '$hours jam $minutes menit';
                } else {
                  return '$minutes menit';
                }
              }
            }
          }
          return '';
        }

        final bool isLate = calculateLateDuration().isNotEmpty;
        
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Card with Gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE').format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMMM y').format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Ringkasan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Check In Summary
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.login_rounded,
                                  color: Colors.green,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Column(
                                  children: [
                                    Text(
                                      data["masuk"]?["date"] == null
                                        ? "--:--"
                                        : DateFormat.Hm().format(
                                            parseDate(data["masuk"]!["date"] as String?) ?? DateTime.now()),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isLate)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withAlpha(30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Terlambat ${calculateLateDuration()}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Divider
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey[300],
                          ),

                          // Check Out Summary
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Keluar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data["keluar"]?["date"] == null
                                      ? "-"
                                      : DateFormat.Hm().format(
                                          parseDate(data["keluar"]!["date"] as String?) ?? DateTime.now()),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Late Status
                      if (isLate)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Terlambat ${calculateLateDuration()} dari jadwal (08:15)',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Duration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Durasi:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            calculateDuration(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Detail Cards
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Detail Kehadiran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Check In Details
                _buildDetailCard(
                  title: 'Masuk',
                  iconData: Icons.login_rounded,
                  iconColor: Colors.green,
                  details: [
                    DetailItem(
                      icon: Icons.access_time_rounded,
                      label: 'Waktu',
                      value: data["masuk"]?["date"] == null
                          ? "-"
                          : DateFormat.jms().format(
                              parseDate(data["masuk"]!["date"] as String?) ?? DateTime.now()),
                    ),
                    DetailItem(
                      icon: Icons.location_on_outlined,
                      label: 'Posisi',
                      value: data["masuk"]?["lat"] != null && data["masuk"]?["long"] != null
                          ? '${data["masuk"]!["lat"]}, ${data["masuk"]!["long"]}'
                          : '-',
                    ),
                    DetailItem(
                      icon: Icons.check_circle_outline,
                      label: 'Status',
                      value: data["masuk"]?["status"] ?? "-",
                    ),
                    DetailItem(
                      icon: Icons.home_work_outlined,
                      label: 'Alamat',
                      value: data["masuk"]?["address"] ?? "-",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Check Out Details
                _buildDetailCard(
                  title: 'Keluar',
                  iconData: Icons.logout_rounded,
                  iconColor: Colors.red,
                  details: [
                    DetailItem(
                      icon: Icons.access_time_rounded,
                      label: 'Waktu',
                      value: data["keluar"]?["date"] == null
                          ? "-"
                          : DateFormat.jms().format(
                              parseDate(data["keluar"]!["date"] as String?) ?? DateTime.now()),
                    ),
                    DetailItem(
                      icon: Icons.location_on_outlined,
                      label: 'Posisi',
                      value: data["keluar"]?["lat"] != null && data["keluar"]?["long"] != null
                          ? '${data["keluar"]!["lat"]}, ${data["keluar"]!["long"]}'
                          : '-',
                    ),
                    DetailItem(
                      icon: Icons.check_circle_outline,
                      label: 'Status',
                      value: data["keluar"]?["status"] ?? "-",
                    ),
                    DetailItem(
                      icon: Icons.home_work_outlined,
                      label: 'Alamat',
                      value: data["keluar"]?["address"] ?? "-",
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData iconData,
    required Color iconColor,
    required List<DetailItem> details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...details.map((detail) => _buildDetailRow(detail)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(DetailItem detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            detail.icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              '${detail.label}:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              detail.value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailItem {
  final IconData icon;
  final String label;
  final String value;

  DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
