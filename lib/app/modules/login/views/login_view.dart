import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fineer/components/textfield.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF1E40AF),
            ],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            // Show loading state
            if (controller.isCheckingBiometric.value) {
              return _buildLoadingState(size);
            }

            // Show biometric prompt if available and password form not shown
            if (controller.canUseBiometric.value &&
                !controller.showPasswordLogin.value) {
              return _buildBiometricPrompt(size);
            }

            // Show password login form
            return _buildPasswordForm(size);
          }),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Size size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'lib/assets/appLogo.webp',
            height: size.height * 0.15,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.business, size: 80, color: Colors.white);
            },
          ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Checking biometric...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricPrompt(Size size) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.12),

            // Logo
            Image.asset(
              'lib/assets/appLogo.webp',
              height: size.height * 0.15,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business,
                    size: 80, color: Colors.white);
              },
            ),

            SizedBox(height: size.height * 0.08),

            // Biometric prompt card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Biometric icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      controller.biometricType.value == 'Face ID'
                          ? Icons.face
                          : Icons.fingerprint,
                      size: 40,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Welcome Back!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // User email
                  Obx(() => Text(
                        controller.lastBiometricUser.value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      )),
                  const SizedBox(height: 24),

                  // Biometric button
                  Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.loginWithBiometric(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      controller.biometricType.value ==
                                              'Face ID'
                                          ? Icons.face
                                          : Icons.fingerprint,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Obx(() => Text(
                                          'Login with ${controller.biometricType.value}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )),
                                  ],
                                ),
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Use password instead
                  TextButton(
                    onPressed: () => controller.showPasswordForm(),
                    child: const Text(
                      'Use password instead',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: size.height * 0.08),

            // Footer
            _buildFooter(size),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordForm(Size size) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
        child: Column(
          children: [
            SizedBox(height: size.height * 0.08),

            // Logo
            Image.asset(
              'lib/assets/appLogo.webp',
              height: size.height * 0.15,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business,
                    size: 80, color: Colors.white);
              },
            ),

            SizedBox(height: size.height * 0.06),

            // Login form card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your credentials to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Field
                  MyTextField(
                    controller: controller.emailC,
                    hintText: 'Enter your email',
                    obscureText: false,
                    labelText: 'Email',
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  MyTextField(
                    controller: controller.passC,
                    hintText: 'Enter your password',
                    obscureText: true,
                    labelText: 'Password',
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.login(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1E293B)),
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      )),

                  // Biometric option
                  Obx(() {
                    if (controller.canUseBiometric.value) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => controller.retryBiometric(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side:
                                    const BorderSide(color: Color(0xFF3B82F6)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    controller.biometricType.value == 'Face ID'
                                        ? Icons.face
                                        : Icons.fingerprint,
                                    size: 20,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 8),
                                  Obx(() => Text(
                                        'Use ${controller.biometricType.value}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),

            SizedBox(height: size.height * 0.04),

            // Footer
            _buildFooter(size),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(Size size) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Provided by',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 4),
            Image.asset(
              'lib/assets/tripleS-transparent-white.webp',
              height: size.height * 0.04,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'Triple S',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
