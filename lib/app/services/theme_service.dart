import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends GetxService {
  static const _key = 'isDarkMode';
  RxBool isDarkMode = false.obs;

  Future<ThemeService> init() async {
    await _load();
    return this;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    isDarkMode.value = p.getBool(_key) ?? false;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggle() async {
    isDarkMode.value = !isDarkMode.value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, isDarkMode.value);
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }
}
