import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OvertimeController extends GetxController {
  // Text controllers
  final TextEditingController nameC = TextEditingController();
  final TextEditingController tanggalC = TextEditingController();
  final TextEditingController waktuC = TextEditingController();
  final TextEditingController desC = TextEditingController();

  // Observable values for UI states
  var isSubmitting = false.obs;
  var isSuccess = false.obs;
  var duration = 2.obs;
  var selectedCategory = "".obs;

  // Methods for duration modification
  void incrementDuration() {
    if (duration.value < 12) {
      duration.value++;
    }
  }

  void decrementDuration() {
    if (duration.value > 1) {
      duration.value--;
    }
  }

  // Category selection
  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  // Validate form
  bool isFormValid() {
    return nameC.text.isNotEmpty &&
        tanggalC.text.isNotEmpty &&
        waktuC.text.isNotEmpty &&
        desC.text.isNotEmpty &&
        selectedCategory.value.isNotEmpty;
  }

  // For backward compatibility
  void prosesAddLembur() {
    if (isFormValid()) {
      isSubmitting.value = true;
      Future.delayed(Duration(seconds: 2), () {
        isSubmitting.value = false;
        isSuccess.value = true;
        Future.delayed(Duration(seconds: 2), () {
          isSuccess.value = false;
          resetForm();
        });
      });
    } else {
      Get.snackbar(
        "Form Error",
        "Please fill all the required fields",
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
        margin: EdgeInsets.all(15),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Reset form
  void resetForm() {
    nameC.clear();
    tanggalC.clear();
    waktuC.clear();
    desC.clear();
    duration.value = 2;
    selectedCategory.value = "";
  }

  @override
  void onClose() {
    nameC.dispose();
    tanggalC.dispose();
    waktuC.dispose();
    desC.dispose();
    super.onClose();
  }
}
