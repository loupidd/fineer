import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fineer/components/textfield.dart';
import '../controllers/login_controller.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final size = MediaQuery.of(context).size;
    final paddingHorizontal = size.width * 0.08;

    return Scaffold(
      body: Container(
        height: size.height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 55, 130, 236),
              Color.fromARGB(255, 20, 71, 143),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: paddingHorizontal, vertical: 5),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - 20, // Account for vertical padding
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo position
                    SizedBox(height: size.height * 0.08),

                    // App title section with animations
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Image.asset(
                            'lib/assets/appLogo.webp',
                            height: size.height * 0.18,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint("Error loading logo: $error");
                              return const SizedBox.shrink();
                            },
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                        ],
                      ),
                    ),

                    // Flexible spacer
                    SizedBox(height: size.height * 0.1),

                    // Form section - animates from bottom
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.02,
                        vertical: size.height * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email Field
                          MyTextField(
                            controller: controller.emailC,
                            hintText: 'Masukan Email',
                            obscureText: false,
                            labelText: 'Email',
                          ),
                          SizedBox(height: size.height * 0.015),

                          // Password Field
                          MyTextField(
                            controller: controller.passC,
                            hintText: 'Masukan Password',
                            obscureText: true,
                            labelText: 'Password',
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideY(
                          begin: 0.2,
                          end: 0,
                          curve: Curves.easeOutQuad,
                          duration: 600.ms,
                        ),

                    SizedBox(height: size.height * 0.06),

                    // Login Button with animation
                    Center(
                      child: SizedBox(
                        width: min(size.width * 0.7, 250),
                        height: size.height * 0.06,
                        child: Obx(
                          () => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              backgroundColor: Colors.yellow,
                            ),
                            onPressed: controller.isLoading.isFalse
                                ? () async {
                                    try {
                                      await controller.login();
                                    } catch (e) {
                                      debugPrint("Login error: $e");
                                      Get.snackbar('Login Error',
                                          'Your Login process is failed');
                                    }
                                  }
                                : null,
                            child: controller.isLoading.isFalse
                                ? const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: Color.fromARGB(171, 0, 0, 0),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 800.ms).scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutQuad,
                          duration: 500.ms,
                        ),
                    SizedBox(
                      height: 16,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Provided by',
                          style: TextStyle(fontSize: 8, color: Colors.black54),
                        ),
                        Image.asset(
                          'lib/assets/tripleS-transparent-white.webp',
                          height: size.height * 0.04,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),

                    // Bottom spacing
                    SizedBox(height: size.height * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to get minimum of two values
double min(double a, double b) => a < b ? a : b;
