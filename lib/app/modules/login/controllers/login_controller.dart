// ignore_for_file: unused_local_variable
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

class LoginController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool hasBiometric = false.obs;
  final RxBool canUseBiometric = false.obs;
  final RxBool isCheckingBiometric = true.obs;
  final RxBool showPasswordLogin = false.obs;
  final RxString biometricType = ''.obs;
  final RxString lastBiometricUser = ''.obs;
  final RxBool biometricAuthFailed = false.obs;

  final TextEditingController emailC = TextEditingController();
  final TextEditingController passC = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  static const String _keyBiometricEmail = 'biometric_email';
  static const String _keyBiometricPassword = 'biometric_password';
  static const String _keyBiometricUid = 'biometric_uid';

  List<BiometricType>? _availableBiometrics;

  @override
  void onInit() {
    super.onInit();
    _initializeBiometric();
  }

  @override
  void onClose() {
    emailC.dispose();
    passC.dispose();
    super.onClose();
  }

  Future<void> _initializeBiometric() async {
    try {
      isCheckingBiometric.value = true;

      // Check if device supports biometric
      final results = await Future.wait([
        _localAuth.canCheckBiometrics,
        _localAuth.isDeviceSupported(),
      ]);

      final canCheckBiometrics = results[0] as bool;
      final isDeviceSupported = results[1] as bool;

      // If device doesn't support biometric at all, go straight to password
      if (!canCheckBiometrics && !isDeviceSupported) {
        _logger.i('Device does not support biometric authentication');
        showPasswordLogin.value = true;
        return;
      }

      // Get available biometric types
      _availableBiometrics = await _localAuth.getAvailableBiometrics();

      // If no biometric is enrolled, go to password form
      if (_availableBiometrics == null || _availableBiometrics!.isEmpty) {
        _logger.i('No biometric enrolled on device');
        showPasswordLogin.value = true;
        return;
      }

      // Determine biometric type (Face ID, Fingerprint, etc.)
      _determineBiometricType(_availableBiometrics!);
      _logger.i('Biometric type available: ${biometricType.value}');

      // Check if user has saved credentials
      final credentials = await _retrieveStoredCredentials();

      if (credentials != null) {
        // User has saved credentials, show biometric prompt
        _logger.i('Found stored credentials for: ${credentials['email']}');
        hasBiometric.value = true;
        canUseBiometric.value = true;
        lastBiometricUser.value = credentials['email']!;
        emailC.text = credentials['email']!;
        showPasswordLogin.value = false;
      } else {
        // No saved credentials, but biometric is available for future use
        _logger.i('No stored credentials found, showing password form');
        canUseBiometric.value = true; // Device supports it
        hasBiometric.value = false; // But not set up for this user
        showPasswordLogin.value = true;
      }
    } catch (e) {
      _logger.e('Error initializing biometric', error: e);
      showPasswordLogin.value = true;
    } finally {
      isCheckingBiometric.value = false;
    }
  }

  void _determineBiometricType(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      biometricType.value = 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      biometricType.value = 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      biometricType.value = 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      biometricType.value = 'Biometric';
    } else {
      biometricType.value = 'Biometric';
    }
  }

  IconData getBiometricIcon() {
    switch (biometricType.value) {
      case 'Face ID':
        return Icons.face;
      case 'Fingerprint':
        return Icons.fingerprint;
      default:
        return Icons.security;
    }
  }

  Future<Map<String, String>?> _retrieveStoredCredentials() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: _keyBiometricEmail),
        _secureStorage.read(key: _keyBiometricPassword),
        _secureStorage.read(key: _keyBiometricUid),
      ]);

      final email = results[0];
      final password = results[1];
      final uid = results[2];

      if (email == null || password == null || uid == null) {
        return null;
      }

      return {'email': email, 'password': password, 'uid': uid};
    } catch (e) {
      _logger.e('Error retrieving credentials', error: e);
      return null;
    }
  }

  Future<void> _storeCredentialsSecurely(String email, String password) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

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
    }
  }

  Future<void> _clearStoredCredentials() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _keyBiometricEmail),
        _secureStorage.delete(key: _keyBiometricPassword),
        _secureStorage.delete(key: _keyBiometricUid),
      ]);

      hasBiometric.value = false;
      lastBiometricUser.value = '';
      _logger.i('Stored credentials cleared');
    } catch (e) {
      _logger.e('Error clearing credentials', error: e);
    }
  }

  Future<bool> _authenticateWithBiometric({bool isRetry = false}) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: isRetry
            ? 'Try again - authenticate with ${biometricType.value}'
            : 'Authenticate with ${biometricType.value} to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      _logger.i('Biometric authentication result: $authenticated');
      return authenticated;
    } on PlatformException catch (e) {
      _logger.w('Biometric authentication error: ${e.code}');
      _handleBiometricError(e);
      return false;
    } catch (e) {
      _logger.e('Unexpected authentication error', error: e);
      return false;
    }
  }

  void _handleBiometricError(PlatformException e) {
    String title = 'Authentication Failed';
    String message = 'Use password to login';
    Color bgColor = const Color(0xFFF59E0B);
    bool shouldShowSnackbar = true;

    switch (e.code) {
      case 'NotAvailable':
        message = 'Biometric not available';
        break;
      case 'NotEnrolled':
        message = 'No biometric enrolled on device';
        break;
      case 'LockedOut':
        message = 'Too many attempts. Use password.';
        bgColor = const Color(0xFFEF4444);
        break;
      case 'PermanentlyLockedOut':
        message = 'Biometric locked. Use password.';
        bgColor = const Color(0xFFEF4444);
        break;
      case 'PasscodeNotSet':
        message = 'Device passcode not set';
        break;
      case 'AuthenticationCanceled':
      case 'UserCancel':
        // User cancelled, don't show error snackbar
        shouldShowSnackbar = false;
        _logger.i('User cancelled biometric authentication');
        break;
      default:
        message = 'Authentication cancelled';
        shouldShowSnackbar = false;
    }

    biometricAuthFailed.value = true;
    showPasswordLogin.value = true;

    if (shouldShowSnackbar) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: bgColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> loginWithBiometric() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      biometricAuthFailed.value = false;

      _logger.i('Starting biometric login...');

      // Retrieve stored credentials
      final credentials = await _retrieveStoredCredentials();

      if (credentials == null) {
        _logger.w('No saved credentials found');
        throw Exception('No saved credentials');
      }

      // Authenticate with biometric
      final authenticated = await _authenticateWithBiometric();

      if (!authenticated) {
        _logger.w('Biometric authentication failed or cancelled');
        isLoading.value = false;
        showPasswordLogin.value = true;
        biometricAuthFailed.value = true;
        return;
      }

      _logger.i('Biometric authentication successful, signing in...');

      // Decode password and sign in
      final password = utf8.decode(base64.decode(credentials['password']!));

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: credentials['email']!,
        password: password,
      );

      final uid = userCredential.user!.uid;

      _updateLoginTimestamp(uid, 'biometric');

      _logger.i('Login successful for user: $uid');

      Get.offAllNamed(Routes.HOME);

      Get.snackbar(
        'Welcome Back!',
        'Logged in with ${biometricType.value}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: Icon(getBiometricIcon(), color: Colors.white),
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error during biometric login: ${e.code}');
      await _handleFirebaseAuthError(e);
      showPasswordLogin.value = true;
      biometricAuthFailed.value = true;
    } catch (e) {
      _logger.e('Biometric login error', error: e);
      showPasswordLogin.value = true;
      biometricAuthFailed.value = true;

      Get.snackbar(
        'Login Failed',
        'Please use password to login',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login() async {
    if (emailC.text.trim().isEmpty || passC.text.isEmpty) {
      Get.snackbar(
        'Incomplete Data',
        'Email & Password are required',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final email = emailC.text.trim();
      final password = passC.text;

      _logger.i('Attempting password login for: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      final userDoc = await _firestore.collection('pegawai').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final biometricEnabled = userData['biometricEnabled'] ?? false;

        _updateLoginTimestamp(uid, 'password');

        // If biometric is enabled in Firestore and device supports it
        if (biometricEnabled && canUseBiometric.value) {
          _logger.i('Biometric enabled for user, storing credentials');
          await _storeCredentialsSecurely(email, password);
          hasBiometric.value = true;
          lastBiometricUser.value = email;
        }
      }

      _logger.i('Password login successful');

      Get.offAllNamed(Routes.HOME);

      Get.snackbar(
        'Login Successful',
        'Welcome back!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error during password login: ${e.code}');
      await _handleFirebaseAuthError(e);
    } catch (e) {
      _logger.e('Login error', error: e);
      Get.snackbar(
        'Error',
        'Unable to login. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleFirebaseAuthError(FirebaseAuthException e) async {
    String title = 'Login Failed';
    String message = 'An error occurred';

    switch (e.code) {
      case 'user-not-found':
        message = 'Email not registered';
        await _clearStoredCredentials();
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        await _clearStoredCredentials();
        break;
      case 'invalid-email':
        message = 'Invalid email format';
        break;
      case 'user-disabled':
        message = 'Account has been disabled';
        await _clearStoredCredentials();
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Try again later';
        break;
      case 'network-request-failed':
        message = 'Network connection problem';
        break;
      case 'invalid-credential':
        message = 'Invalid credentials';
        await _clearStoredCredentials();
        break;
      default:
        message = e.message ?? 'Login failed';
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _updateLoginTimestamp(String uid, String method) {
    _firestore.collection('pegawai').doc(uid).update({
      method == 'biometric' ? 'lastBiometricLogin' : 'lastLogin':
          FieldValue.serverTimestamp(),
      'lastLoginMethod': method,
    }).catchError((error) {
      _logger.e('Error updating login timestamp', error: error);
    });
  }

  void showPasswordForm() {
    _logger.i('Switching to password form');
    showPasswordLogin.value = true;
  }

  void retryBiometric() {
    _logger.i('Retrying biometric authentication');
    showPasswordLogin.value = false;
    biometricAuthFailed.value = false;
    // Small delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 300), () {
      loginWithBiometric();
    });
  }

  Future<bool> enableBiometricForUser(String email, String password) async {
    try {
      _logger.i('Attempting to enable biometric for user: $email');

      if (_availableBiometrics == null || _availableBiometrics!.isEmpty) {
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        if (!canCheckBiometrics && !isDeviceSupported) {
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

        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        if (_availableBiometrics!.isEmpty) {
          Get.snackbar(
            'Not Enrolled',
            'Please enroll biometric authentication in device settings first',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFF59E0B),
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );
          return false;
        }

        _determineBiometricType(_availableBiometrics!);
      }

      final authenticated = await _authenticateWithBiometric();
      if (!authenticated) {
        return false;
      }

      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _firestore.collection('pegawai').doc(uid).update({
        'biometricEnabled': true,
        'biometricEnabledAt': FieldValue.serverTimestamp(),
        'biometricType': biometricType.value,
      });

      await _storeCredentialsSecurely(email, password);

      hasBiometric.value = true;
      canUseBiometric.value = true;
      lastBiometricUser.value = email;

      _logger.i('Biometric successfully enabled for user');

      Get.snackbar(
        'Success!',
        '${biometricType.value} login enabled',
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
    }
  }

  Future<bool> disableBiometric() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('pegawai').doc(uid).update({
          'biometricEnabled': false,
          'biometricDisabledAt': FieldValue.serverTimestamp(),
        });

        await _clearStoredCredentials();

        _logger.i('Biometric disabled for user');

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
      return false;
    }
  }
}
