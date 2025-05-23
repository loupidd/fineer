// lib/app/modules/monthly_report/views/monthly_report_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fineer/cons.dart';
import 'package:fineer/components/custom_appbar.dart';
import 'package:fineer/components/custom_button.dart';
import '../controllers/monthly_report_controller.dart';

class MonthlyReportView extends GetView<MonthlyReportController> {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Laporan Bulanan Kehadiran',
        showBackButton: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        color: ColorConstants.bgColor,
        child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodCard(),
                const SizedBox(height: 16),
                _buildGenerateReportCard(),
                const SizedBox(height: 16),
                if (controller.dataStats.isNotEmpty) _buildResultCard(),
                if (controller.errorMessage.value.isNotEmpty) _buildErrorCard(),
              ],
            )),
      ),
    );
  }

  Widget _buildPeriodCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: ColorConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Periode Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    ColorConstants.primaryColor.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    controller.getDateRangeText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cut-off setiap tanggal 20 pada bulan berjalan',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateReportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: ColorConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Generate Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Laporan akan diunduh sebagai file Excel (.xlsx) dengan sheet terpisah untuk setiap pegawai, berisi data kehadiran, keterlambatan, dan pulang awal.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: controller.isLoading.value
                    ? 'Memproses...'
                    : controller.downloadSuccess.value
                        ? 'Unduh Lagi'
                        : 'Generate Laporan',
                icon: controller.isLoading.value
                    ? null
                    : controller.downloadSuccess.value
                        ? Icons.refresh
                        : Icons.download,
                isLoading: controller.isLoading.value,
                onPressed: controller.isLoading.value
                    ? null
                    : () async {
                        await controller.generateMonthlyAttendanceReport();
                        if (controller.downloadSuccess.value) {
                          controller.showDownloadOptionsDialog();
                        }
                      },
                color: ColorConstants.primaryColor,
              ),
            ),
            if (controller.downloadSuccess.value &&
                controller.downloadPath.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File berhasil disimpan',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => controller.showDownloadOptionsDialog(),
                      child: Text(
                        'Opsi Lain',
                        style: TextStyle(
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: ColorConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Hasil Analisis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatItem(
                'Total Pegawai',
                '${controller.totalEmployees} pegawai',  // Use getter instead of dataStats access
                Icons.people),
            const Divider(),
            _buildStatItem(
                'Total Hari Kehadiran',
                '${controller.totalPresentDays} hari',  // Use getter instead of dataStats access
                Icons.check_circle),
            const Divider(),
            _buildStatItem(
                'Total Hari Ketidakhadiran',
                '${controller.totalAbsentDays} hari',  // Use getter instead of dataStats access
                Icons.person_off),
            const Divider(),
            _buildStatItem(
                'Total Hari Keterlambatan',
                '${controller.totalLateDays} hari',  // Use getter instead of dataStats access
                Icons.timer_off),
            const Divider(),
            _buildStatItem(
                'Total Hari Pulang Awal',
                '${controller.totalEarlyLeaveDays} hari',  // Use getter instead of dataStats access
                Icons.exit_to_app),
            const Divider(),
            _buildStatItem(
                'Periode',
                controller.period,  // Use getter instead of dataStats access
                Icons.date_range),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: Icon(Icons.bar_chart, color: ColorConstants.primaryColor),
                label: Text(
                  'Lihat Detail Statistik',
                  style: TextStyle(color: ColorConstants.primaryColor),
                ),
                onPressed: () => controller.showStatisticsDialog(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.errorMessage.value,
                style: TextStyle(
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
}
