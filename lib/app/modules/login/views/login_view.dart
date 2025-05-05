// ignore_for_file: prefer_const_constructors

import 'package:fineer/components/textfield.dart';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});
//text editing controllers

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              //Title Text
              SizedBox(
                height: 120,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Row(
                  children: [
                    Column(
                      children: [
                        Text(
                          ' Fineer',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 60,
                              color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'by TripleS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.amber),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 120),

              //Email field
              MyTextField(
                controller: controller.emailC,
                hintText: 'Masukan Email',
                obscureText: false,
                labelText: 'Email',
              ),

              //SizedBox(height: 24),

              //password field
              MyTextField(
                controller: controller.passC,
                hintText: 'Masukan Password',
                obscureText: true,
                labelText: 'Password',
              ),

              SizedBox(height: 40),
              //login button
              SizedBox(
                width: 250,
                height: 45,
                child: Obx(
                  () => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                        backgroundColor: Colors.blue),
                    onPressed: () async {
                      if (controller.isLoading.isFalse) {
                        await controller.login();
                      }
                    },
                    child: Text(
                      controller.isLoading.isFalse ? 'Login' : 'Loading...',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
