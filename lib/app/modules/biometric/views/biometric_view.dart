import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/biometric_controller.dart';

class BiometricView extends GetView<BiometricController> {
  const BiometricView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? FC.bgDark : const Color(0xFFF0F6FF),
      appBar: AppBar(title: Text('bio_title'.tr)),
      body: Obx(() {
        if (controller.isCheckingBiometric.value) {
          return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(FC.blue),
                  strokeWidth: 2.5));
        }
        if (!controller.isBiometricAvailable.value) {
          return _NotAvailable(isDark: isDark);
        }
        return _SetupView(controller: controller, isDark: isDark);
      }),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  final bool isDark;
  const _NotAvailable({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: FC.warning.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fingerprint_outlined,
                size: 54, color: FC.warning),
          ),
          const SizedBox(height: 28),
          Text('bio_unavailable'.tr,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: tp)),
          const SizedBox(height: 12),
          Text(
            'Your device doesn\'t support biometric authentication or no biometrics are enrolled.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: ts, height: 1.6),
          ),
          const SizedBox(height: 28),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Get.back(), child: const Text('Go Back'))),
        ]),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  final BiometricController controller;
  final bool isDark;
  const _SetupView({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _HeroCard(controller: controller, isDark: isDark),
        const SizedBox(height: 16),
        _StatusCard(controller: controller, isDark: isDark),
        const SizedBox(height: 16),
        _FeaturesList(controller: controller, isDark: isDark),
        const SizedBox(height: 16),
        _SecurityNote(isDark: isDark),
        const SizedBox(height: 24),
        Obx(() => _ActionButton(controller: controller, isDark: isDark)),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final BiometricController controller;
  final bool isDark;
  const _HeroCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.isBiometricEnabled.value;
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [const Color(0xFF059669), const Color(0xFF047857)]
                : [FC.blue, FC.blueDark],
          ),
          boxShadow: [
            BoxShadow(
              color: (enabled ? const Color(0xFF059669) : FC.blue)
                  .withValues(alpha: isDark ? 0.2 : 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(controller.getBiometricIcon(),
                size: 46, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(controller.getBiometricTypeName(),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(enabled ? 'bio_active'.tr : 'bio_not_setup'.tr,
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ]),
      );
    });
  }
}

class _StatusCard extends StatelessWidget {
  final BiometricController controller;
  final bool isDark;
  const _StatusCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.isBiometricEnabled.value;
      final accent = enabled ? const Color(0xFF059669) : FC.blue;
      final bgAlpha = isDark ? 0.12 : 0.07;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            child: Icon(enabled ? Icons.check_circle : Icons.info_outline,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  enabled
                      ? 'Biometric Login is Active'
                      : 'Biometric Login Not Set Up',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: accent),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'You\'re using quick biometric login'
                      : 'Enable for faster access',
                  style: TextStyle(
                      fontSize: 13, color: accent.withValues(alpha: 0.7)),
                ),
              ])),
        ]),
      );
    });
  }
}

class _FeaturesList extends StatelessWidget {
  final BiometricController controller;
  final bool isDark;
  const _FeaturesList({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    return Obx(() {
      final enabled = controller.isBiometricEnabled.value;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(enabled ? 'Biometric Benefits' : 'Why Enable Biometric?',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: tp)),
        const SizedBox(height: 12),
        _Feat(
            icon: Icons.speed,
            title: enabled ? 'Fast Login Active' : 'Lightning Fast Login',
            body: enabled
                ? 'You\'re enjoying instant access'
                : 'Access in seconds',
            color: FC.blue,
            isDark: isDark),
        const SizedBox(height: 10),
        _Feat(
            icon: Icons.shield_outlined,
            title: enabled ? 'Secure & Protected' : 'Enhanced Security',
            body: enabled
                ? 'Secured with biometric'
                : 'Biometric data never leaves device',
            color: const Color(0xFF059669),
            isDark: isDark),
        const SizedBox(height: 10),
        _Feat(
            icon: Icons.touch_app,
            title: enabled ? 'Password-Free' : 'No More Passwords',
            body: enabled
                ? 'No need to remember passwords'
                : 'Use fingerprint or face ID',
            color: const Color(0xFF7C3AED),
            isDark: isDark),
      ]);
    });
  }
}

class _Feat extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  final bool isDark;
  const _Feat(
      {required this.icon,
      required this.title,
      required this.body,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: tp)),
          const SizedBox(height: 2),
          Text(body, style: TextStyle(fontSize: 12, color: ts)),
        ])),
      ]),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final bool isDark;
  const _SecurityNote({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF059669).withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_user, color: Color(0xFF059669), size: 18),
        const SizedBox(width: 10),
        const Expanded(
            child: Text(
          'Your biometric data is encrypted and stored securely on your device only. '
          'It is never sent to any server or shared with anyone.',
          style: TextStyle(fontSize: 12, color: Color(0xFF059669), height: 1.5),
        )),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final BiometricController controller;
  final bool isDark;
  const _ActionButton({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final enabled = controller.isBiometricEnabled.value;
    final processing = controller.isProcessing.value;
    final btnColor = enabled ? FC.error : const Color(0xFF059669);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: processing ? null : () => _handleTap(enabled),
        icon: processing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Icon(enabled ? Icons.lock_outline : Icons.fingerprint, size: 20),
        label: Text(
          enabled ? 'bio_disable'.tr : 'bio_enable'.tr,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _handleTap(bool enabled) async {
    if (enabled) {
      final confirm = await Get.dialog<bool>(AlertDialog(
        title: const Text('Disable Biometric Login?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text(
          'You\'ll need to enter your email and password next time. You can re-enable this later.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FC.error,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Disable'),
          ),
        ],
      ));
      if (confirm == true) {
        final ok = await controller.disableBiometric();
        if (ok) Get.back();
      }
    } else {
      final ok = await controller.enableBiometric();
      if (ok) {
        await Future.delayed(const Duration(milliseconds: 800));
        Get.back();
      }
    }
  }
}
