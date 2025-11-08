import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

class BiometricController extends GetxController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Secure storage keys - MUST match LoginController
  static const String _keyBiometricEmail = 'biometric_email';
  static const String _keyBiometricPassword = 'biometric_password';
  static const String _keyBiometricUid = 'biometric_uid';

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
      } else {
        _logger.w('Biometric not available on this device');
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
      if (uid == null) {
        _logger.w('No authenticated user');
        return;
      }

      // Check in Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('pegawai').doc(uid).get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        isBiometricEnabled.value = data?['biometricEnabled'] ?? false;
        _logger
            .i('Biometric enabled in Firestore: ${isBiometricEnabled.value}');
      }

      // Verify credentials are stored
      if (isBiometricEnabled.value) {
        final hasCredentials = await _hasStoredCredentials();
        if (!hasCredentials) {
          _logger.w('Biometric enabled but no stored credentials found');
          isBiometricEnabled.value = false;
        }
      }
    } catch (e) {
      _logger.e('Error checking biometric status', error: e);
      isBiometricEnabled.value = false;
    }
  }

  // Check if credentials are stored
  Future<bool> _hasStoredCredentials() async {
    try {
      final email = await _secureStorage.read(key: _keyBiometricEmail);
      final password = await _secureStorage.read(key: _keyBiometricPassword);
      final uid = await _secureStorage.read(key: _keyBiometricUid);

      return email != null && password != null && uid != null;
    } catch (e) {
      _logger.e('Error checking stored credentials', error: e);
      return false;
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

      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        Get.snackbar(
          'Error',
          'No authenticated user found',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return false;
      }

      // Get current user email
      String? email = _auth.currentUser?.email;
      if (email == null) {
        Get.snackbar(
          'Error',
          'User email not found',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return false;
      }

      // Request password from user
      final password = await _requestPassword();
      if (password == null) {
        _logger.i('User cancelled password entry');
        return false;
      }

      // Verify password by attempting to reauthenticate
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await _auth.currentUser!.reauthenticateWithCredential(credential);
        _logger.i('Password verified successfully');
      } on FirebaseAuthException catch (e) {
        _logger.e('Password verification failed: ${e.code}');
        Get.snackbar(
          'Incorrect Password',
          'The password you entered is incorrect',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return false;
      }

      // Authenticate with biometric
      bool authenticated = await authenticateWithBiometric(
        reason: 'Authenticate to enable ${getBiometricTypeName()} login',
      );

      if (!authenticated) {
        _logger.w('Biometric authentication failed or cancelled');
        return false;
      }

      // Store credentials securely
      await _storeCredentialsSecurely(email, password, uid);

      // Save to Firestore
      await _firestore.collection('pegawai').doc(uid).update({
        'biometricEnabled': true,
        'biometricEnabledAt': FieldValue.serverTimestamp(),
        'biometricType': getBiometricTypeName(),
      });

      isBiometricEnabled.value = true;

      _logger.i('Biometric successfully enabled');

      Get.snackbar(
        'Success!',
        '${getBiometricTypeName()} login has been enabled',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: Icon(getBiometricIcon(), color: Colors.white),
      );
      return true;
    } catch (e) {
      _logger.e('Error enabling biometric', error: e);
      Get.snackbar(
        'Error',
        'Failed to enable biometric login',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  // Request password from user
  Future<String?> _requestPassword() async {
    final TextEditingController passwordController = TextEditingController();

    return await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Confirm Your Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please enter your password to enable biometric login',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Get.back(result: value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isNotEmpty) {
                Get.back(result: passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // Store credentials securely (same as LoginController)
  Future<void> _storeCredentialsSecurely(
      String email, String password, String uid) async {
    try {
      final encodedPassword = base64.encode(utf8.encode(password));

      await Future.wait([
        _secureStorage.write(key: _keyBiometricEmail, value: email),
        _secureStorage.write(
            key: _keyBiometricPassword, value: encodedPassword),
        _secureStorage.write(key: _keyBiometricUid, value: uid),
      ]);

      _logger.i('Credentials stored securely for: $email');
    } catch (e) {
      _logger.e('Error storing credentials', error: e);
      rethrow;
    }
  }

  // Clear stored credentials (same as LoginController)
  Future<void> _clearStoredCredentials() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _keyBiometricEmail),
        _secureStorage.delete(key: _keyBiometricPassword),
        _secureStorage.delete(key: _keyBiometricUid),
      ]);

      _logger.i('Stored credentials cleared');
    } catch (e) {
      _logger.e('Error clearing credentials', error: e);
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

        await _clearStoredCredentials();

        isBiometricEnabled.value = false;

        _logger.i('Biometric disabled successfully');

        Get.snackbar(
          'Disabled',
          'Biometric login has been disabled',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFF59E0B),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error disabling biometric', error: e);
      Get.snackbar(
        'Error',
        'Failed to disable biometric login',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
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
          backgroundColor: const Color(0xFFF59E0B),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
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

      _logger.i('Biometric authentication result: $authenticated');
      return authenticated;
    } on PlatformException catch (e) {
      _logger.e('Biometric authentication error: ${e.code}', error: e);

      String message = 'Authentication failed';
      bool shouldShowSnackbar = true;

      switch (e.code) {
        case 'NotAvailable':
          message = 'Biometric authentication is not available';
          break;
        case 'NotEnrolled':
          message = 'No biometrics enrolled on this device';
          break;
        case 'LockedOut':
          message = 'Too many attempts. Please try again later';
          break;
        case 'PermanentlyLockedOut':
          message = 'Biometric authentication is permanently locked';
          break;
        case 'AuthenticationCanceled':
        case 'UserCancel':
          // User cancelled, don't show error
          shouldShowSnackbar = false;
          break;
        default:
          shouldShowSnackbar = false;
      }

      if (shouldShowSnackbar) {
        Get.snackbar(
          'Authentication Error',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
      return false;
    } catch (e) {
      _logger.e('Unexpected error during authentication', error: e);
      return false;
    }
  }
}
