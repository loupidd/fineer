import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:fineer/app/services/notification_service.dart';

class ProfileController extends GetxController {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final logger = Logger();

  // Get notification service
  NotificationService get notificationService =>
      Get.find<NotificationService>();

  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> userData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> attendanceSummary = <String, dynamic>{}.obs;

  // Bind to notification service state
  RxBool get notificationsEnabled => notificationService.isNotificationEnabled;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    loadAttendanceSummary();
    loadNotificationPreference();
  }

  Future<void> loadUserData() async {
    try {
      isLoading.value = true;
      String uid = auth.currentUser!.uid;

      DocumentSnapshot<Map<String, dynamic>> doc =
          await firestore.collection('pegawai').doc(uid).get();

      if (doc.exists) {
        userData.value = doc.data()!;
        logger.d('User data loaded: $userData');
      } else {
        logger.w('User document does not exist for uid: $uid');
      }
    } catch (e, stackTrace) {
      logger.e('Error loading user data', error: e, stackTrace: stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAttendanceSummary() async {
    try {
      String uid = auth.currentUser!.uid;
      DateTime now = DateTime.now();

      // Start of current month
      DateTime startOfMonth = DateTime(now.year, now.month, 1);

      // Get presence records for current month
      QuerySnapshot<Map<String, dynamic>> presenceSnapshot = await firestore
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .where('date', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .get();

      int totalPresent = presenceSnapshot.docs.length;
      int lateEntries = 0;

      // Calculate late entries (after 8:30 AM)
      for (var doc in presenceSnapshot.docs) {
        Map<String, dynamic> data = doc.data();

        if (data['masuk'] != null) {
          DateTime checkInTime = DateTime.parse(data['masuk']['date']);
          DateTime workStartTime = DateTime(
              checkInTime.year, checkInTime.month, checkInTime.day, 8, 30, 0);

          if (checkInTime.isAfter(workStartTime)) {
            lateEntries++;
          }
        }
      }

      attendanceSummary.value = {
        'totalPresent': totalPresent,
        'lateEntries': lateEntries,
      };

      logger.d('Attendance summary loaded: $attendanceSummary');
    } catch (e, stackTrace) {
      logger.e('Error loading attendance summary',
          error: e, stackTrace: stackTrace);
      attendanceSummary.value = {
        'totalPresent': 0,
        'lateEntries': 0,
      };
    }
  }

  Future<void> loadNotificationPreference() async {
    try {
      String uid = auth.currentUser!.uid;
      DocumentSnapshot<Map<String, dynamic>> doc =
          await firestore.collection('pegawai').doc(uid).get();

      if (doc.exists) {
        bool enabled = doc.data()?['notificationsEnabled'] ?? false;
        notificationService.isNotificationEnabled.value = enabled;
        logger.d('Notification preference loaded: $enabled');
      }
    } catch (e) {
      logger.e('Error loading notification preference', error: e);
    }
  }

  Future<void> updateNotificationPreference(bool value) async {
    try {
      await notificationService.toggleNotifications(value);
      logger.i('Notification preference updated to: $value');
    } catch (e) {
      logger.e('Error updating notification preference', error: e);
      Get.snackbar(
        'Error',
        'Failed to update notification settings',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
      Get.offAllNamed('/login');
    } catch (e) {
      logger.e('Error signing out', error: e);
      Get.snackbar(
        'Error',
        'Failed to sign out',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String formatJoinDate(dynamic dateString) {
    if (dateString == null) return 'N/A';

    try {
      if (dateString is String) {
        DateTime date = DateTime.parse(dateString);
        return '${date.day}/${date.month}/${date.year}';
      } else if (dateString is Timestamp) {
        DateTime date = dateString.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else {
        return 'N/A';
      }
    } catch (e) {
      logger.e('Error formatting join date', error: e);
      return 'N/A';
    }
  }

  String getUserInitials(dynamic name) {
    if (name == null) return 'U';

    String nameStr;
    if (name is String) {
      nameStr = name;
    } else if (name is Map) {
      nameStr = name['name']?.toString() ?? 'U';
    } else {
      nameStr = name.toString();
    }

    if (nameStr.isEmpty) return 'U';

    List<String> nameParts = nameStr.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else {
      return nameParts[0].length > 1
          ? nameParts[0].substring(0, 2)
          : nameParts[0];
    }
  }
}
