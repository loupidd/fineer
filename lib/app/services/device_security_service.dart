import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceSecurityService {
  static Future<Map<String, bool>> checkDeviceSecurity() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

        return {
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'isEmulator': !androidInfo.isPhysicalDevice ||
              androidInfo.model.toLowerCase().contains('sdk') ||
              androidInfo.product.toLowerCase().contains('sdk') ||
              androidInfo.fingerprint.toLowerCase().contains('generic'),
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;

        return {
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'isEmulator': !iosInfo.isPhysicalDevice,
        };
      }

      return {
        'isPhysicalDevice': true,
        'isEmulator': false,
      };
    } catch (e) {
      return {
        'isPhysicalDevice': true,
        'isEmulator': false,
      };
    }
  }

  static Future<bool> isDeviceSecure() async {
    final checks = await checkDeviceSecurity();
    return checks['isPhysicalDevice']! && !checks['isEmulator']!;
  }

  static Future<void> enforceDeviceSecurity() async {
    final checks = await checkDeviceSecurity();

    if (checks['isEmulator']!) {
      throw SecurityException('Emulator Detected',
          'This app must run on a physical device for security reasons.');
    }
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return {
          "platform": "Android",
          "model": androidInfo.model,
          "manufacturer": androidInfo.manufacturer,
          "version": androidInfo.version.sdkInt,
          "isPhysicalDevice": androidInfo.isPhysicalDevice,
          "androidId": androidInfo.id,
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return {
          "platform": "iOS",
          "model": iosInfo.model,
          "name": iosInfo.name,
          "systemVersion": iosInfo.systemVersion,
          "isPhysicalDevice": iosInfo.isPhysicalDevice,
          "identifierForVendor": iosInfo.identifierForVendor,
        };
      }
    } catch (e) {
      // Device info failed
    }
    return {"platform": "unknown"};
  }
}

class SecurityException implements Exception {
  final String title;
  final String message;

  SecurityException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}
