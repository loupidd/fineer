// Removed math import as it's no longer needed

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../controllers/home_controller.dart';

final _logger = Logger();

FirebaseAuth auth = FirebaseAuth.instance;

class HomeView extends GetView<HomeController> {
  final pageC = Get.find<PageIndexController>();

  HomeView({super.key});

  // Office locations are defined in PageIndexController

  get stackTrace => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          // Changed to FutureBuilder for initial load
          future: controller.getUserOnce(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData) {
              Map<String, dynamic> user = snapshot.data!.data()!;
              return _buildMainContent(context, user);
            } else {
              return const Center(
                child: Text('Unable to load user data'),
              );
            }
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildMainContent(BuildContext context, Map<String, dynamic> user) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildWelcomeSection(user),
        const SizedBox(height: 24),
        _buildHeroSection(user),
        const SizedBox(height: 16),
        _buildAttendanceSection(),
        const SizedBox(height: 24),
        if (user["role"] == "admin") _buildAdminSection(),
        const SizedBox(height: 16),
        if (user["role"] == "admin") _buildAdminPanel(),
        const SizedBox(height: 16),
        _buildPresenceHistoryHeader(),
        const SizedBox(height: 12),
        _buildPresenceHistoryList(),
      ],
    );
  }

  Widget _buildWelcomeSection(Map<String, dynamic> user) {
    // Optimized welcome section with const widgets where possible
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user['name']}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _showUserOptions(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withAlpha(26),
                    border: Border.all(
                      color: Colors.blue.withAlpha(128),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      getUserInitials(user['name']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber,
                  ),
                  child: const Icon(
                    Icons.menu,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Map<String, dynamic> user) {
    // Using more const widgets for better performance
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(33, 150, 243, 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2196F3),
            Color(0xFF0D47A1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Attendance",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Use StreamBuilder instead of direct user data to get real-time updates
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.streamTodayPresence(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                Map<String, dynamic> presenceData = snapshot.data!.data() ?? {};
                _logger.d('Today presence data: $presenceData');

                // Get check-in data
                final checkInData = presenceData['masuk'];
                final hasCheckedIn = checkInData != null;
                String checkInTime = '--:--';

                if (hasCheckedIn && checkInData['date'] != null) {
                  try {
                    checkInTime = DateFormat.Hm().format(
                      DateTime.parse(checkInData['date']),
                    );
                  } catch (e) {
                    _logger.e('Error parsing check-in time', error: e);
                  }
                }

                // Get check-out data
                final checkOutData = presenceData['keluar'];
                final hasCheckedOut = checkOutData != null;
                String checkOutTime = '--:--';

                if (hasCheckedOut && checkOutData['date'] != null) {
                  try {
                    checkOutTime = DateFormat.Hm().format(
                      DateTime.parse(checkOutData['date']),
                    );
                  } catch (e) {
                    _logger.e('Error parsing check-out time', error: e);
                  }
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceCard(
                      title: 'Check In',
                      value: checkInTime,
                      isCompleted: hasCheckedIn,
                    ),
                    _buildAttendanceCard(
                      title: 'Check Out',
                      value: checkOutTime,
                      isCompleted: hasCheckedOut,
                    ),
                  ],
                );
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceCard(
                      title: 'Check In',
                      value: '--:--',
                      isCompleted: false,
                    ),
                    _buildAttendanceCard(
                      title: 'Check Out',
                      value: '--:--',
                      isCompleted: false,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard({
    required String title,
    required String value,
    bool isCompleted = false,
  }) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Modified: Use semi-transparent white for both states, just different opacity
        color: isCompleted
            ? Colors.blue.withAlpha(200)
            : Colors.blue.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.blue.withAlpha((0.6 * 255).round())
              : Colors.blue.withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha((0.9 * 255).round()),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.access_time,
                size: 14,
                color: isCompleted ? Colors.greenAccent : Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                isCompleted ? 'Completed' : 'Pending',
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted ? Colors.greenAccent : Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    // Optimized with const widgets where possible
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Office Presence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Record your attendance by checking in and out',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAttendanceButton(
                  label: 'Check In',
                  icon: Icons.login,
                  color: Colors.blue,
                  onTap: () => presensi('masuk'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttendanceButton(
                  label: 'Check Out',
                  icon: Icons.logout,
                  color: Colors.blueAccent,
                  onTap: () => presensi('keluar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 55, 130, 236),
            Color.fromARGB(255, 20, 71, 143),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.3 * 255).round()),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Access',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Register new employee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(Routes.ADD_PEGAWAI),
              icon: Icon(Icons.person_add, color: Colors.blue),
              label: Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[800],
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 20, 71, 143),
            Color.fromARGB(255, 55, 130, 236),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.3 * 255).round()),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Report',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                ' Get Your Monthly Report Here',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(Routes.MONTHLY_REPORT),
              icon: Icon(Icons.document_scanner, color: Colors.blue),
              label: Text('Get'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[800],
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () => Get.toNamed(Routes.ALL_PRESENSI),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceHistoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: controller.streamLastPresence(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No attendance records found'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              snapshot.data!.docs.length > 5 ? 5 : snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = snapshot.data!.docs[index].data();

            return _buildPresenceHistoryItem(data);
          },
        );
      },
    );
  }

  Widget _buildPresenceHistoryItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(
            Routes.DETAIL_PRESENSI,
            arguments: data,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: data['keluar'] != null
                        ? Colors.green.withAlpha((0.1 * 255).round())
                        : Colors.amber.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    data['keluar'] != null
                        ? Icons.check_circle_outline
                        : Icons.access_time,
                    color: data['keluar'] != null ? Colors.green : Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMMMd().format(
                              DateTime.parse(data['date']),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            data['office'] ?? 'Office',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildAttendanceTimeRow(data),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTimeRow(Map<String, dynamic> data) {
    return Row(
      children: [
        _buildTimeLabel(
          'In',
          data['masuk'] != null
              ? DateFormat.Hm().format(
                  DateTime.parse(data['masuk']['date']),
                )
              : '--:--',
          Colors.green,
        ),
        const SizedBox(width: 16),
        _buildTimeLabel(
          'Out',
          data['keluar'] != null
              ? DateFormat.Hm().format(
                  DateTime.parse(data['keluar']['date']),
                )
              : '--:--',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTimeLabel(String label, String time, Color color) {
    return Row(
      children: [
        Icon(
          label == 'In' ? Icons.login : Icons.logout,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $time',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.white,
        elevation: 0,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavBarItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: pageC.pageIndex.value == 0,
              ),
              _buildNavBarItem(
                icon: Icons.history,
                label: 'Riwayat',
                index: 1,
                isSelected: pageC.pageIndex.value == 1,
              ),
              _buildNavBarItem(
                icon: Icons.access_time,
                label: 'Overtime',
                index: 2,
                isSelected: pageC.pageIndex.value == 2,
              ),
              _buildNavBarItem(
                icon: Icons.person,
                label: 'Profile',
                index: 3,
                isSelected: pageC.pageIndex.value == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem({
    required IconData icon,
    required String label,
    required int index,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () => changePage(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(
          minWidth: 60,
          maxHeight: 50,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                height: 1.0,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  void changePage(int index) {
    pageC.changePage(index);
    switch (index) {
      case 0:
        Get.offAllNamed(Routes.HOME);
      case 1:
        Get.offAllNamed(Routes.ALL_PRESENSI);
      case 2:
        Get.offAllNamed(Routes.OVERTIME);
      case 3:
        Get.offAllNamed(Routes.PROFILE);
    }
  }

  void _showUserOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'User Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Get.offAllNamed(Routes.PROFILE);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Get.defaultDialog(
                  title: 'Sign Out',
                  middleText: 'Are you sure you want to log out?',
                  actions: [
                    TextButton(
                      onPressed: () => {
                        auth.signOut(),
                        Get.offAllNamed(Routes.LOGIN),
                      },
                      child: const Text('Yes'),
                    ),
                    TextButton(
                      onPressed: () => {
                        Get.back(),
                      },
                      child: const Text('No'),
                    ),
                  ],
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getUserInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else {
      return nameParts[0].length > 1
          ? nameParts[0].substring(0, 2)
          : nameParts[0];
    }
  }

  void presensi(String type) async {
    try {
      // Use PageIndexController to handle attendance with proper location checks
      await pageC.processAttendance();
    } catch (e) {
      // Handle errors
      Get.snackbar(
        'Error',
        'Failed to record attendance: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      _logger.e('Error During Attendance', error: e, stackTrace: stackTrace);
    }
  }
}
