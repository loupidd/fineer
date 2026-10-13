import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_pegawai_controller.dart';

class AddPegawaiView extends GetView<AddPegawaiController> {
  const AddPegawaiView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FC.bgDark : const Color(0xFFF0F6FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text('add_emp_title'.tr)),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('add_emp_title'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        )),
                    const SizedBox(height: 2),
                    const Text('Password default: "password"',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
            ]),
          ),
          const SizedBox(height: 20),

          // Form card
          _FormCard(controller: controller, isDark: isDark),
          const SizedBox(height: 20),

          // Warning
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FC.warning.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FC.warning.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  color: FC.warning, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text(
                'Password default pegawai baru adalah "password". '
                'Minta pegawai segera mengganti password setelah login pertama.',
                style: TextStyle(fontSize: 12, color: FC.warning, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 24),

          // Submit button
          Obx(() => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      controller.isLoading.value ? null : controller.addPegawai,
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.person_add_rounded, size: 20),
                  label: Text('add_emp_register'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FC.yellow,
                    foregroundColor: FC.blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              )),
        ]),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final AddPegawaiController controller;
  final bool isDark;
  const _FormCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        _Field('Nama Lengkap', controller.nameC, Icons.person_outline_rounded,
            isDark),
        const SizedBox(height: 16),
        _Field('Email', controller.emailC, Icons.email_outlined, isDark,
            type: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _Field('NIK', controller.nikC, Icons.badge_outlined, isDark,
            type: TextInputType.number),
        const SizedBox(height: 16),
        _Field('Jabatan / Divisi', controller.jobC, Icons.work_outline_rounded,
            isDark),
        const SizedBox(height: 16),
        _Field('Site', controller.siteC, Icons.location_city_outlined, isDark),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool isDark;
  final TextInputType? type;
  const _Field(this.label, this.ctrl, this.icon, this.isDark, {this.type});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    final tt = isDark ? FC.textSecDark : FC.textTerLight;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tt,
              letterSpacing: 0.4)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(fontSize: 15, color: tp),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 17),
        ),
      ),
    ]);
  }
}
