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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          height: size.height,
          padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo positioned higher
              SizedBox(height: size.height * 0.2),

              // App title section with animations
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Text(
                      'Fineer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 48,
                        color: Colors.blue,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                    Image.asset(
                      'lib/assets/tripleS-transparent-black.png',
                      height: size.height * 0.04,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint("Error loading logo: $error");
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              // Spacer that takes available space
              const Spacer(),

              // Form section - animates from bottom
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.02,
                  vertical: size.height * 0.02,
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
                    SizedBox(height: size.height * 0.02),

                    // Password Field
                    MyTextField(
                      controller: controller.passC,
                      hintText: 'Masukan Password',
                      obscureText: true,
                      labelText: 'Password',
                    ),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Add forgot password functionality here
                        },
                        child: const Text(
                          'Lupa Password?',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    curve: Curves.easeOutQuad,
                    duration: 600.ms,
                  ),

              SizedBox(height: size.height * 0.04),

              // Login Button with animation
              Center(
                child: SizedBox(
                  width: min(size.width * 0.7, 250),
                  height: size.height * 0.065,
                  child: Obx(
                    () => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: controller.isLoading.isFalse
                          ? () async {
                              try {
                                await controller.login();
                              } catch (e) {
                                debugPrint("Login error: $e");
                                // Show error toast/snackbar if needed
                              }
                            }
                          : null,
                      child: controller.isLoading.isFalse
                          ? const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                          : const SizedBox(
                              height: 24,
                              width: 24,
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

              // Bottom spacing
              SizedBox(height: size.height * 0.08),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper function to get minimum of two values
double min(double a, double b) => a < b ? a : b;
