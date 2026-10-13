import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/detail_presensi_controller.dart';

class DetailPresensiView extends GetView<DetailPresensiController> {
  const DetailPresensiView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FC.bgDark : const Color(0xFFF0F6FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text('detail_title'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(FC.blue),
                  strokeWidth: 2.5));
        }
        if (controller.errorMessage.value != null) {
          return _ErrorState(
              message: controller.errorMessage.value!, isDark: isDark);
        }
        if (controller.presenceData.value == null) {
          return Center(
              child: Text('Data tidak ditemukan',
                  style: TextStyle(
                      color: isDark ? FC.textSecDark : FC.textSecLight)));
        }
        return _DetailBody(
            data: controller.presenceData.value!, isDark: isDark);
      }),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _DetailBody({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Date parsing helpers
    String? getDateStr(Map? m) =>
        m?['date'] as String? ?? m?['datetime'] as String?;
    DateTime? parseDate(String? s) {
      try {
        return s != null ? DateTime.parse(s) : null;
      } catch (_) {
        return null;
      }
    }

    final date = parseDate(data['date'] as String?);
    final masukRaw = data['masuk'] as Map?;
    final keluarRaw = data['keluar'] as Map?;
    final masukDt = parseDate(getDateStr(masukRaw));
    final keluarDt = parseDate(getDateStr(keluarRaw));
    final officeName = data['office'] as String? ?? '';

    // Late calculation (08:15 WIB)
    String lateDuration = '';
    if (masukDt != null) {
      final schedule =
          DateTime(masukDt.year, masukDt.month, masukDt.day, 8, 15);
      if (masukDt.isAfter(schedule)) {
        final d = masukDt.difference(schedule);
        lateDuration = d.inHours > 0
            ? '${d.inHours}j ${d.inMinutes % 60}m'
            : '${d.inMinutes}m';
      }
    }

    // Work duration
    String duration = '-';
    if (masukDt != null && keluarDt != null) {
      final d = keluarDt.difference(masukDt);
      duration = '${d.inHours}j ${d.inMinutes % 60}m';
    }

    if (date == null) {
      return Center(
          child: Text('Format tanggal tidak valid',
              style:
                  TextStyle(color: isDark ? FC.textSecDark : FC.textSecLight)));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Date banner — full gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FC.blue, FC.blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            if (officeName.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(officeName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            Text(DateFormat('EEEE').format(date),
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(DateFormat('d MMMM y').format(date),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
          ]),
        ),
        const SizedBox(height: 16),

        // Summary card
        _SummaryCard(
          masukDt: masukDt,
          keluarDt: keluarDt,
          lateDuration: lateDuration,
          duration: duration,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Detail header
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: FC.blue,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 8),
              Text('detail_kehadiran'.tr,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),

        // Check-in detail card
        _DetailCard(
          title: 'detail_masuk'.tr,
          icon: Icons.login_rounded,
          color: FC.success,
          isDark: isDark,
          entries: masukRaw != null
              ? [
                  _DetailEntry(Icons.access_time_rounded, 'detail_time'.tr,
                      masukDt != null ? DateFormat.jms().format(masukDt) : '-'),
                  _DetailEntry(Icons.location_on_outlined, 'detail_location'.tr,
                      '${masukRaw['lat'] ?? '-'}, ${masukRaw['long'] ?? '-'}',
                      copyable: true),
                  _DetailEntry(Icons.check_circle_outline, 'detail_status'.tr,
                      masukRaw['status']?.toString() ?? '-'),
                  _DetailEntry(Icons.home_work_outlined, 'Alamat',
                      masukRaw['address']?.toString() ?? '-'),
                ]
              : [],
        ),
        const SizedBox(height: 14),

        // Check-out detail card
        _DetailCard(
          title: 'detail_keluar'.tr,
          icon: Icons.logout_rounded,
          color: FC.warning,
          isDark: isDark,
          entries: keluarRaw != null
              ? [
                  _DetailEntry(
                      Icons.access_time_rounded,
                      'detail_time'.tr,
                      keluarDt != null
                          ? DateFormat.jms().format(keluarDt)
                          : '-'),
                  _DetailEntry(Icons.location_on_outlined, 'detail_location'.tr,
                      '${keluarRaw['lat'] ?? '-'}, ${keluarRaw['long'] ?? '-'}',
                      copyable: true),
                  _DetailEntry(Icons.check_circle_outline, 'detail_status'.tr,
                      keluarRaw['status']?.toString() ?? '-'),
                  _DetailEntry(Icons.home_work_outlined, 'Alamat',
                      keluarRaw['address']?.toString() ?? '-'),
                ]
              : [],
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DateTime? masukDt, keluarDt;
  final String lateDuration, duration;
  final bool isDark;
  const _SummaryCard({
    required this.masukDt,
    required this.keluarDt,
    required this.lateDuration,
    required this.duration,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final isLate = lateDuration.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        Text('detail_summary'.tr,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FC.blue,
            )),
        const SizedBox(height: 16),
        Row(children: [
          // Masuk
          Expanded(
              child: Column(children: [
            const Icon(Icons.login_rounded, color: FC.success, size: 24),
            const SizedBox(height: 6),
            Text('detail_masuk'.tr,
                style: TextStyle(
                    fontSize: 13, color: ts, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(masukDt != null ? DateFormat.Hm().format(masukDt!) : '--:--',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tp,
                )),
            if (isLate)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FC.error.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Terlambat $lateDuration',
                    style: const TextStyle(
                      color: FC.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ])),
          Container(width: 1, height: 60, color: border),
          // Keluar
          Expanded(
              child: Column(children: [
            const Icon(Icons.logout_rounded, color: FC.warning, size: 24),
            const SizedBox(height: 6),
            Text('detail_keluar'.tr,
                style: TextStyle(
                    fontSize: 13, color: ts, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(keluarDt != null ? DateFormat.Hm().format(keluarDt!) : '-',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tp,
                )),
          ])),
        ]),
        if (isLate) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: FC.error.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FC.error.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: FC.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Terlambat $lateDuration ${'detail_schedule'.tr}',
                style: const TextStyle(
                  color: FC.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )),
            ]),
          ),
        ],
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.timer_outlined, color: FC.warning, size: 20),
          const SizedBox(width: 8),
          Text('detail_duration'.tr,
              style: TextStyle(fontWeight: FontWeight.w500, color: ts)),
          const SizedBox(width: 6),
          Text(duration, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _DetailEntry {
  final IconData icon;
  final String label, value;
  final bool copyable;
  const _DetailEntry(this.icon, this.label, this.value,
      {this.copyable = false});
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final List<_DetailEntry> entries;
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: entries.isEmpty ? border : color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: tp)),
        ]),
        if (entries.isEmpty) ...[
          const SizedBox(height: 14),
          Center(
              child: Text('Tidak ada data',
                  style: TextStyle(fontSize: 13, color: ts))),
        ] else ...[
          Divider(height: 24, color: border),
          ...entries.map((e) => _EntryRow(entry: e, isDark: isDark)),
        ],
      ]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _DetailEntry entry;
  final bool isDark;
  const _EntryRow({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final tp = isDark ? FC.textDark : FC.textLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(entry.icon, size: 15, color: ts),
        const SizedBox(width: 10),
        SizedBox(
            width: 68,
            child: Text('${entry.label}:',
                style: TextStyle(fontSize: 13, color: ts))),
        const SizedBox(width: 4),
        Expanded(
            child: Text(entry.value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: tp))),
        if (entry.copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: entry.value));
              Get.snackbar('Disalin', entry.value,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2));
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.copy_rounded, size: 14, color: ts),
            ),
          ),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final bool isDark;
  const _ErrorState({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline,
                color: FC.error.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? FC.textSecDark : FC.textSecLight,
                    fontSize: 14)),
          ]),
        ),
      );
}
