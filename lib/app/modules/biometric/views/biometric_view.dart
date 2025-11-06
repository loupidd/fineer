import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/biometric_controller.dart';

class BiometricView extends GetView<BiometricController> {
  const BiometricView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1E293B), size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Biometric Authentication',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isCheckingBiometric.value) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          );
        }

        if (!controller.isBiometricAvailable.value) {
          return _buildNotAvailableView();
        }

        return _buildSetupView();
      }),
    );
  }

  Widget _buildNotAvailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fingerprint_outlined,
                size: 60,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Biometric Unavailable',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your device doesn\'t support biometric authentication or no biometrics are enrolled. Please set up biometric authentication in your device settings first.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeroSection(),
          const SizedBox(height: 32),
          _buildStatusCard(),
          const SizedBox(height: 24),
          _buildFeaturesList(),
          const SizedBox(height: 24),
          _buildSecurityNote(),
          const SizedBox(height: 32),
          Obx(() => _buildActionButton()),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Obx(() {
      final isEnabled = controller.isBiometricEnabled.value;
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                controller.getBiometricIcon(),
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.getBiometricTypeName(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEnabled ? 'Enabled & Active' : 'Available on Your Device',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatusCard() {
    return Obx(() {
      final isEnabled = controller.isBiometricEnabled.value;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isEnabled ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEnabled
                    ? const Color(0xFF10B981)
                    : const Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEnabled ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnabled
                        ? 'Biometric Login is Active'
                        : 'Biometric Login Not Set Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? const Color(0xFF065F46)
                          : const Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled
                        ? 'You\'re using quick biometric login'
                        : 'Enable to login faster next time',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? const Color(0xFF059669)
                          : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFeaturesList() {
    return Obx(() {
      final isEnabled = controller.isBiometricEnabled.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnabled ? 'Biometric Benefits' : 'Why Enable Biometric?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.speed,
            title: isEnabled ? 'Fast Login Active' : 'Lightning Fast Login',
            description: isEnabled
                ? 'You\'re already enjoying instant access'
                : 'Access your account in seconds',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.shield,
            title: isEnabled ? 'Secure & Protected' : 'Enhanced Security',
            description: isEnabled
                ? 'Your account is secured with biometric'
                : 'Biometric data never leaves your device',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.touch_app,
            title: isEnabled ? 'Password-Free' : 'No More Passwords',
            description: isEnabled
                ? 'No need to remember your password'
                : 'Just use your fingerprint or face',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      );
    });
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Obx(() {
      final isEnabled = controller.isBiometricEnabled.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF86EFAC),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.verified_user,
              color: Color(0xFF16A34A),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEnabled
                    ? 'Your biometric authentication is active and secure. All biometric data is encrypted and stored locally on your device only.'
                    : 'Your biometric data is encrypted and stored securely on your device only. It is never sent to any server or shared with anyone.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF15803D),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton() {
    final isEnabled = controller.isBiometricEnabled.value;
    final isProcessing = controller.isProcessing.value;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isProcessing
            ? null
            : () async {
                if (isEnabled) {
                  final confirm = await Get.dialog<bool>(
                    AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Disable Biometric Login?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      content: const Text(
                        'You\'ll need to enter your email and password to login next time. You can always re-enable this later.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Disable',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await controller.disableBiometric();
                    if (success) {
                      Get.back();
                    }
                  }
                } else {
                  final success = await controller.enableBiometric();
                  if (success) {
                    await Future.delayed(const Duration(milliseconds: 800));
                    Get.back();
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEnabled ? Icons.lock_outline : Icons.fingerprint,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEnabled
                        ? 'Disable Biometric Login'
                        : 'Enable Biometric Login',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
