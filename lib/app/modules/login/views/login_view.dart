import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fineer/components/textfield.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 120),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Fineer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 60,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'by TripleS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 120),

              // Email Field
              MyTextField(
                controller: controller.emailC,
                hintText: 'Masukan Email',
                obscureText: false,
                labelText: 'Email',
              ),

              // Password Field
              MyTextField(
                controller: controller.passC,
                hintText: 'Masukan Password',
                obscureText: true,
                labelText: 'Password',
              ),

              const SizedBox(height: 40),

              // Login Button
              SizedBox(
                width: 250,
                height: 45,
                child: Obx(
                  () => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: controller.isLoading.isFalse
                        ? () async => await controller.login()
                        : null, // Disable saat loading
                    child: controller.isLoading.isFalse
                        ? const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
