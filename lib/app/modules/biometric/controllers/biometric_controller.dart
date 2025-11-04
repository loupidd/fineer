import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class BiometricController extends GetxController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Observable states
  RxBool isBiometricAvailable = false.obs;
  RxBool isBiometricEnabled = false.obs;
  RxBool isCheckingBiometric = true.obs;
  RxList<BiometricType> availableBiometrics = <BiometricType>[].obs;
  RxBool isProcessing = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkBiometricSupport();
    checkBiometricStatus();
  }

  // Check if device supports biometric authentication
  Future<void> checkBiometricSupport() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();

      isBiometricAvailable.value = canCheckBiometrics || isDeviceSupported;

      if (isBiometricAvailable.value) {
        availableBiometrics.value = await _localAuth.getAvailableBiometrics();
        _logger.d('Available biometrics: $availableBiometrics');
      }
    } catch (e) {
      _logger.e('Error checking biometric support', error: e);
      isBiometricAvailable.value = false;
    } finally {
      isCheckingBiometric.value = false;
    }
  }

  // Check if user has enabled biometric authentication
  Future<void> checkBiometricStatus() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // Check in Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('pegawai').doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        isBiometricEnabled.value = data?['biometricEnabled'] ?? false;
      }

      // Also check secure storage for backup
      String? biometricStatus =
          await _secureStorage.read(key: 'biometric_$uid');
      if (biometricStatus == 'enabled') {
        isBiometricEnabled.value = true;
      }
    } catch (e) {
      _logger.e('Error checking biometric status', error: e);
      isBiometricEnabled.value = false;
    }
  }

  // Get biometric type name for display
  String getBiometricTypeName() {
    if (availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (availableBiometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    }
    return 'Biometric';
  }

  // Get biometric icon
  IconData getBiometricIcon() {
    if (availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    }
    return Icons.security;
  }

  // Enable biometric authentication
  Future<bool> enableBiometric() async {
    if (isProcessing.value) return false;

    try {
      isProcessing.value = true;

      // First authenticate with biometric
      bool authenticated = await authenticateWithBiometric(
        reason: 'Please authenticate to enable biometric login',
      );

      if (!authenticated) {
        Get.snackbar(
          'Authentication Failed',
          'Biometric authentication was not successful',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Save to Firestore
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('pegawai').doc(uid).update({
          'biometricEnabled': true,
          'biometricEnabledAt': FieldValue.serverTimestamp(),
        });

        // Save to secure storage as backup
        await _secureStorage.write(key: 'biometric_$uid', value: 'enabled');

        isBiometricEnabled.value = true;

        Get.snackbar(
          'Success',
          'Biometric login has been enabled',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: Icon(getBiometricIcon(), color: Colors.white),
        );
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error enabling biometric', error: e);
      Get.snackbar(
        'Error',
        'Failed to enable biometric login: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  // Disable biometric authentication
  Future<bool> disableBiometric() async {
    if (isProcessing.value) return false;

    try {
      isProcessing.value = true;

      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('pegawai').doc(uid).update({
          'biometricEnabled': false,
          'biometricDisabledAt': FieldValue.serverTimestamp(),
        });

        // Remove from secure storage
        await _secureStorage.delete(key: 'biometric_$uid');

        isBiometricEnabled.value = false;

        Get.snackbar(
          'Success',
          'Biometric login has been disabled',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error disabling biometric', error: e);
      Get.snackbar(
        'Error',
        'Failed to disable biometric login: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  // Authenticate with biometric
  Future<bool> authenticateWithBiometric({String? reason}) async {
    try {
      if (!isBiometricAvailable.value) {
        Get.snackbar(
          'Not Available',
          'Biometric authentication is not available on this device',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Please authenticate to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      _logger.e('Biometric authentication error', error: e);

      String message = 'Authentication failed';
      if (e.code == 'NotAvailable') {
        message = 'Biometric authentication is not available';
      } else if (e.code == 'NotEnrolled') {
        message = 'No biometrics enrolled on this device';
      } else if (e.code == 'LockedOut') {
        message = 'Too many attempts. Please try again later';
      } else if (e.code == 'PermanentlyLockedOut') {
        message = 'Biometric authentication is permanently locked';
      }

      Get.snackbar(
        'Authentication Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } catch (e) {
      _logger.e('Unexpected error during authentication', error: e);
      return false;
    }
  }

  // Quick biometric login (for login screen)
  Future<bool> quickBiometricLogin() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      bool authenticated = await authenticateWithBiometric(
        reason: 'Authenticate to login quickly',
      );

      if (authenticated) {
        // Verify biometric is still enabled in Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('pegawai').doc(uid).get();

        if (userDoc.exists) {
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          bool isEnabled = data?['biometricEnabled'] ?? false;

          if (!isEnabled) {
            Get.snackbar(
              'Biometric Disabled',
              'Biometric login has been disabled. Please login with credentials.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
            return false;
          }

          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error during quick biometric login', error: e);
      return false;
    }
  }
}
