import 'package:fineer/app/routes/app_pages.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../controllers/all_presensi_controller.dart';

class AllPresensiView extends GetView<AllPresensiController> {
  const AllPresensiView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FC.bgDark : const Color(0xFFF0F6FF);
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('history_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showDatePicker(context, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          AnimatedBuilder(
            animation: controller.statsAnimation,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + 0.05 * controller.statsAnimation.value,
              child: Opacity(
                opacity: controller.statsAnimation.value,
                child: _StatsCard(controller: controller, isDark: isDark),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Row(children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: FC.blue,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 8),
              Text('Riwayat Kehadiran',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: tp)),
            ]),
          ),
          // List
          Expanded(child: Obx(() {
            if (controller.isLoading.value) {
              return Column(
                  children: List.generate(
                      4,
                      (i) => Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            height: 80,
                            decoration: BoxDecoration(
                              color: isDark ? FC.card2Dark : FC.borderLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          )));
            }
            if (controller.allPresence.isEmpty) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_toggle_off,
                    size: 64, color: isDark ? FC.textTerDark : FC.textTerLight),
                const SizedBox(height: 12),
                Text('history_empty'.tr,
                    style: TextStyle(
                        fontSize: 15,
                        color: isDark ? FC.textTerDark : FC.textTerLight)),
              ]));
            }
            return AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: controller.presenceLength,
                itemBuilder: (ctx, i) {
                  final doc = controller.allPresence[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final norm = controller.normalizePresenceData(data, doc.id);
                  return AnimationConfiguration.staggeredList(
                    position: i,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      verticalOffset: 30,
                      child: FadeInAnimation(
                        child: _PresenceCard(
                          data: norm,
                          isDark: isDark,
                          statusColor: controller.getStatusColor(data),
                          onTap: () => Get.toNamed(Routes.DETAIL_PRESENSI,
                              arguments: norm),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          })),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context, bool isDark) {
    Get.dialog(Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('history_period'.tr,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: SfDateRangePicker(
              controller: controller.dateRangePickerController,
              selectionMode: DateRangePickerSelectionMode.range,
              showActionButtons: true,
              cancelText: 'cancel'.tr,
              confirmText: 'ok'.tr,
              onCancel: () => Get.back(),
              onSubmit: (v) {
                if (v is PickerDateRange && v.startDate != null) {
                  controller.filterByDateRange(v.startDate, v.endDate);
                  Get.back();
                }
              },
            ),
          ),
        ]),
      ),
    ));
  }
}

class _StatsCard extends StatelessWidget {
  final AllPresensiController controller;
  final bool isDark;
  const _StatsCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FC.blue, FC.blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: FC.blue.withValues(alpha: isDark ? 0.18 : 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('history_period'.tr,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w500)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(controller.filterText ?? 'history_all'.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Stat(
                  'history_on_time'.tr,
                  controller.onTimeCount.value.toString(),
                  Icons.check_circle_outline,
                  Colors.greenAccent),
              _Stat('history_late'.tr, controller.lateCount.value.toString(),
                  Icons.warning_outlined, Colors.orangeAccent),
              _Stat(
                  'history_absent'.tr,
                  controller.absentCount.value.toString(),
                  Icons.cancel_outlined,
                  Colors.redAccent),
            ]),
          ]),
        ));
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ]),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]);
}

class _PresenceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final Color statusColor;
  final VoidCallback onTap;
  const _PresenceCard({
    required this.data,
    required this.isDark,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    DateTime? date;
    try {
      date = DateTime.parse(data['date'] ?? '');
    } catch (_) {}

    final dayNum = date != null ? DateFormat('d').format(date) : '--';
    final dayName = date != null ? DateFormat('EEEE').format(date) : '—';
    final fullDate =
        date != null ? DateFormat('MMMM d, yyyy').format(date) : '--';

    String inTime = '--:--', outTime = '--:--';
    try {
      final ms = data['masuk'] as Map?;
      final ds = ms?['date'] as String? ?? ms?['datetime'] as String?;
      if (ds != null) inTime = DateFormat.Hm().format(DateTime.parse(ds));
    } catch (_) {}
    try {
      final ks = data['keluar'] as Map?;
      final ds = ks?['date'] as String? ?? ks?['datetime'] as String?;
      if (ds != null) outTime = DateFormat.Hm().format(DateTime.parse(ds));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(children: [
            // Date circle
            Container(
              width: 70,
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FC.blue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Text(dayNum,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FC.blue,
                    )),
              ),
            ),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(dayName,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tp)),
                            Text(fullDate,
                                style: TextStyle(fontSize: 12, color: ts)),
                          ])),
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.login, size: 15, color: FC.success),
                      const SizedBox(width: 4),
                      Text(inTime,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tp)),
                      const SizedBox(width: 20),
                      Icon(Icons.logout, size: 15, color: FC.warning),
                      const SizedBox(width: 4),
                      Text(outTime,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tp)),
                    ]),
                  ]),
            )),
          ]),
        ),
      ),
    );
  }
}
