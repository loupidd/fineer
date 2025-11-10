// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_pegawai_controller.dart';

class AddPegawaiView extends GetView<AddPegawaiController> {
  const AddPegawaiView({super.key});

  @override
  Widget build(BuildContext context) {
    // Dropdown options
    final List<String> siteOptions = ['Essence Darmawangsa', 'Nifarro Park'];
    final List<String> roleOptions = ['pegawai', 'admin', 'direktur'];
    final List<String> jobOptions = [
      'Field Engineer',
      'Supervisor',
      'Assistant Manager',
      'Admin Staff',
      'HRGA',
      'Director'
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        foregroundColor: Colors.blue[700],
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Register Employee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 20, 71, 143),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment(0.7, 1),
                  colors: <Color>[
                    Color.fromARGB(255, 55, 130, 236),
                    Color.fromARGB(255, 32, 105, 179),
                    Color.fromARGB(255, 20, 71, 143),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Employee',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Registration Form',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fill in all to complete registration',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Form Section
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Personal Information
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 16),
                      inputField(
                        controller: controller.nameC,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 16),
                      inputField(
                        controller: controller.emailC,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),
                      inputField(
                        controller: controller.nikC,
                        label: 'NIK (Employee ID)',
                        icon: Icons.badge_outlined,
                      ),
                      SizedBox(height: 30),

                      // Job Information
                      Text(
                        'Job Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Job Dropdown
                      dropdownField(
                        label: 'Job Position',
                        icon: Icons.work_outline,
                        value: controller.jobC.text.isNotEmpty
                            ? controller.jobC.text
                            : null,
                        items: jobOptions,
                        onChanged: (value) => controller.jobC.text = value!,
                      ),
                      SizedBox(height: 16),

                      // Site Dropdown
                      dropdownField(
                        label: 'Site Location',
                        icon: Icons.location_on_outlined,
                        value: controller.siteC.text.isNotEmpty
                            ? controller.siteC.text
                            : null,
                        items: siteOptions,
                        onChanged: (value) => controller.siteC.text = value!,
                      ),
                      SizedBox(height: 16),

                      // Role Dropdown
                      dropdownField(
                        label: 'Role',
                        icon: Icons.person_outline,
                        value: controller.roleC.text.isNotEmpty
                            ? controller.roleC.text
                            : null,
                        items: roleOptions,
                        onChanged: (value) => controller.roleC.text = value!,
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(bottom: 16),
              height: 55,
              child: ElevatedButton(
                onPressed: () => controller.addPegawai(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 32, 105, 179),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                ),
                child: Text(
                  'REGISTER EMPLOYEE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Input Field Widget
  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 5,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[700]),
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Dropdown Field Widget
  Widget dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 5,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
        ),
      ),
    );
  }
}
