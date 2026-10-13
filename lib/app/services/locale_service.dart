import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends GetxService {
  static const _key = 'locale';
  Rx<Locale> locale = const Locale('id', 'ID').obs;

  Future<LocaleService> init() async {
    await _load();
    return this;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_key) ?? 'id';
    locale.value =
        saved == 'en' ? const Locale('en', 'US') : const Locale('id', 'ID');
  }

  bool get isId => locale.value.languageCode == 'id';

  Future<void> toggle() async {
    locale.value = isId ? const Locale('en', 'US') : const Locale('id', 'ID');
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, locale.value.languageCode);
    Get.updateLocale(locale.value);
  }
}
