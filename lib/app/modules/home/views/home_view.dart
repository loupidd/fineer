// ignore_for_file: prefer_const_constructors
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/modules/biometric/controllers/biometric_controller.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:fineer/app/services/theme_service.dart';
import 'package:fineer/app/services/locale_service.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:fineer/components/fineer_navbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/home_controller.dart';

final _auth = FirebaseAuth.instance;

class HomeView extends GetView<HomeController> {
  HomeView({super.key});

  final pageC = Get.find<PageIndexController>();
  final biometricC = Get.put(BiometricController());
  final _ts = Get.find<ThemeService>();
  final _ls = Get.find<LocaleService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FC.bgDark : const Color(0xFFF0F6FF),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: controller.getUserOnce(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _Shimmer(isDark: isDark);
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return Center(
              child: Text('home_no_record'.tr,
                  style: TextStyle(
                      color: isDark ? FC.textSecDark : FC.textSecLight)),
            );
          }
          final user = snapshot.data!.data()!;
          return _HomeBody(
            user: user,
            isDark: isDark,
            controller: controller,
            pageC: pageC,
            biometricC: biometricC,
            ts: _ts,
            ls: _ls,
          );
        },
      ),
      bottomNavigationBar: FineerNavBar(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDark;
  final HomeController controller;
  final PageIndexController pageC;
  final BiometricController biometricC;
  final ThemeService ts;
  final LocaleService ls;

  const _HomeBody({
    required this.user,
    required this.isDark,
    required this.controller,
    required this.pageC,
    required this.biometricC,
    required this.ts,
    required this.ls,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Top bar: NO grey tint, explicit color, no surface tint ─
        SliverAppBar(
          pinned: true,
          floating: false,
          snap: false,
          automaticallyImplyLeading: false,
          // FIX: explicit bg color, surfaceTintColor transparent, elevation 0
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          forceElevated: false,
          toolbarHeight: 64,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Tappable avatar — opens quick-action sheet
                GestureDetector(
                  onTap: () => _showUserOptions(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [FC.blue, FC.blueDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FC.blue.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials(user['name'] ?? ''),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + dept + site (compact, 2-line)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          user['name'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? FC.textDark : FC.blue,
                            letterSpacing: -0.2,
                            height: 1,
                          ),
                        ),
                        if ((user['role'] ?? '') == 'admin') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FC.yellow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ADMIN',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: FC.blue,
                                )),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        '${user['job'] ?? '-'}  ·  ${user['site'] ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FC.textSecDark : FC.textSecLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Theme toggle
                Obx(() => _IconBtn(
                      icon: ts.isDarkMode.value
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      isDark: isDark,
                      onTap: ts.toggle,
                    )),
                const SizedBox(width: 6),
                // Language
                // in _HomeBody title Row
                Obx(() => _LangBtn(
                      isId: ls.isId, // read here, inside Obx
                      isDark: isDark,
                      onTap: ls.toggle,
                    )),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: isDark ? FC.borderDark : FC.borderLight,
            ),
          ),
        ),

        // ── Content ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // User info card (dept, position, site, NIK)
              _UserInfoCard(user: user, isDark: isDark),
              const SizedBox(height: 14),

              // Today's attendance hero
              _HeroCard(controller: controller, isDark: isDark),
              const SizedBox(height: 14),

              // Biometric prompt
              _BiometricPromptBanner(biometricC: biometricC, isDark: isDark),

              // Admin section
              if ((user['role'] ?? '') == 'admin') ...[
                _AdminCard(isDark: isDark),
                const SizedBox(height: 20),
              ],

              // Recent activity
              _SectionHeader(isDark: isDark),
              const SizedBox(height: 10),
              _HistoryList(controller: controller, isDark: isDark),
            ]),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name.isEmpty
            ? '?'
            : name[0].toUpperCase();
  }

  void _showUserOptions(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? FC.borderDark : FC.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('home_quick_actions'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: FC.blue,
                )),
            const SizedBox(height: 20),
            _SheetItem(
              icon: Icons.person_outline_rounded,
              label: 'home_view_profile'.tr,
              color: FC.blue,
              isDark: isDark,
              onTap: () {
                Get.back();
                Get.toNamed(Routes.PROFILE);
              },
            ),
            const SizedBox(height: 10),
            _SheetItem(
              icon: Icons.fingerprint,
              label: 'home_biometric_settings'.tr,
              color: const Color(0xFF7C3AED),
              isDark: isDark,
              onTap: () {
                Get.back();
                Get.toNamed(Routes.BIOMETRIC_SETUP);
              },
            ),
            const SizedBox(height: 10),
            _SheetItem(
              icon: Icons.logout_rounded,
              label: 'home_logout'.tr,
              color: FC.error,
              isDark: isDark,
              onTap: () {
                Get.back();
                _confirmLogout(isDark);
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  void _confirmLogout(bool isDark) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final tsC = isDark ? FC.textSecDark : FC.textSecLight;

    Get.dialog(Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FC.error.withValues(alpha: isDark ? 0.15 : 0.08),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: FC.error, size: 26)),
            const SizedBox(height: 14),
            Text('home_logout_title'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: tp)),
            const SizedBox(height: 8),
            Text('home_logout_msg'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: tsC, height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tsC,
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 44),
                ),
                child: Text('cancel'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                onPressed: () async {
                  Get.back();
                  await _auth.signOut();
                  Get.offAllNamed(Routes.LOGIN);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FC.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 44),
                ),
                child: Text('home_logout'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
// User info card — department, position, site, NIK
// ─────────────────────────────────────────────────────────────────

class _UserInfoCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDark;
  const _UserInfoCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FC.blue, FC.blueDark],
        ),
        boxShadow: [
          BoxShadow(
            color: FC.blue.withValues(alpha: isDark ? 0.2 : 0.32),
            blurRadius: 18,
            offset: const Offset(0, 7),
          )
        ],
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name
          Text(user['name'] ?? '-',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 4),
          // Job title
          Row(children: [
            const Icon(Icons.work_outline_rounded,
                size: 12, color: Colors.white60),
            const SizedBox(width: 4),
            Expanded(
                child: Text(user['job'] ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70))),
          ]),
          const SizedBox(height: 2),
          // Site
          Row(children: [
            const Icon(Icons.location_city_outlined,
                size: 12, color: Colors.white60),
            const SizedBox(width: 4),
            Expanded(
                child: Text(user['site'] ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70))),
          ]),
        ])),
        const SizedBox(width: 14),
        // NIK badge
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_outlined, color: FC.yellow, size: 24),
          ),
          const SizedBox(height: 6),
          Text('NIK',
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600)),
          Text(user['nik']?.toString() ?? '-',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Hero card — today's times
// ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final HomeController controller;
  final bool isDark;
  const _HeroCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [FC.blue, FC.blueDark]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            const Icon(Icons.today_rounded, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text('home_today'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const Spacer(),
            Text(DateFormat('EEE, d MMM').format(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
        // Times
        Padding(
          padding: const EdgeInsets.all(14),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.streamTodayPresence(),
            builder: (context, snap) {
              bool hasIn = false, hasOut = false;
              String inTime = '--:--', outTime = '--:--';

              if (snap.hasData && snap.data!.exists) {
                final d = snap.data!.data() ?? {};
                try {
                  if (d['masuk']?['date'] != null) {
                    inTime = DateFormat.Hm()
                        .format(DateTime.parse(d['masuk']['date']));
                    hasIn = true;
                  }
                } catch (_) {}
                try {
                  if (d['keluar']?['date'] != null) {
                    outTime = DateFormat.Hm()
                        .format(DateTime.parse(d['keluar']['date']));
                    hasOut = true;
                  }
                } catch (_) {}
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(FC.blue))),
                );
              }

              final pendingSync =
                  snap.hasData && snap.data!.metadata.hasPendingWrites;

              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                      child: _TimeChip(
                          label: 'home_check_in'.tr,
                          time: inTime,
                          done: hasIn,
                          color: FC.success,
                          isDark: isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _TimeChip(
                          label: 'home_check_out'.tr,
                          time: outTime,
                          done: hasOut,
                          color: FC.warning,
                          isDark: isDark)),
                ]),
                if (pendingSync)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              size: 14, color: FC.warning),
                          const SizedBox(width: 6),
                          Text('att_pending'.tr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FC.warning)),
                        ]),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label, time;
  final bool done, isDark;
  final Color color;
  const _TimeChip(
      {required this.label,
      required this.time,
      required this.done,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? FC.card2Dark : const Color(0xFFF8FAFC);
    final border = isDark ? FC.borderDark : FC.borderLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final tp = isDark ? FC.textDark : FC.textLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.07) : bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done ? color.withValues(alpha: 0.3) : border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: ts, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: done ? tp : ts,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(done ? Icons.check_circle : Icons.access_time,
              size: 12, color: done ? color : ts),
          const SizedBox(width: 4),
          Text(done ? 'home_completed'.tr : 'home_pending'.tr,
              style: TextStyle(
                fontSize: 11,
                color: done ? color : ts,
                fontWeight: FontWeight.w600,
              )),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Biometric prompt banner
// ─────────────────────────────────────────────────────────────────

class _BiometricPromptBanner extends StatelessWidget {
  final BiometricController biometricC;
  final bool isDark;
  const _BiometricPromptBanner(
      {required this.biometricC, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!biometricC.isBiometricAvailable.value ||
          biometricC.isBiometricEnabled.value ||
          biometricC.isCheckingBiometric.value) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.toNamed(Routes.BIOMETRIC_SETUP),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(biometricC.getBiometricIcon(),
                    color: Colors.white, size: 28),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('home_enable_bio'.tr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      Text(
                        'home_enable_bio_sub'.tr.replaceAll(
                            '@type@', biometricC.getBiometricTypeName()),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ])),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white70, size: 14),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// Attendance buttons card
// ─────────────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  final PageIndexController pageC;
  final bool isDark;
  const _AttendanceCard({required this.pageC, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FC.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.location_on_rounded, color: FC.blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('home_office'.tr,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text('home_office_sub'.tr,
                    style: TextStyle(fontSize: 12, color: ts)),
              ])),
        ]),
        const SizedBox(height: 14),
        Obx(() {
          final processing = pageC.isProcessingAttendance.value;
          return Row(children: [
            Expanded(
                child: _ABtn(
              label: 'home_check_in'.tr,
              icon: Icons.login_rounded,
              color: FC.success,
              processing: processing,
              onTap: () => pageC.processAttendance(),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ABtn(
              label: 'home_check_out'.tr,
              icon: Icons.logout_rounded,
              color: FC.warning,
              processing: processing,
              onTap: () => pageC.processAttendance(),
            )),
          ]);
        }),
      ]),
    );
  }
}

class _ABtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool processing;
  final VoidCallback onTap;
  const _ABtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.processing,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: processing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (processing)
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color)))
            else
              Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(processing ? '...' : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Admin card
// ─────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final bool isDark;
  const _AdminCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FC.blue, FC.blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: FC.blue.withValues(alpha: isDark ? 0.2 : 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('home_admin'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              )),
          const SizedBox(height: 3),
          Text('home_add_emp'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        ElevatedButton.icon(
          onPressed: () => Get.toNamed(Routes.ADD_PEGAWAI),
          icon: const Icon(Icons.person_add_rounded, color: FC.blue, size: 16),
          label: const Text('Tambah'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: FC.blue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section header + history list
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final bool isDark;
  const _SectionHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
              color: FC.blue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text('home_recent'.tr,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const Spacer(),
      TextButton(
        onPressed: () => Get.toNamed(Routes.ALL_PRESENSI),
        style: TextButton.styleFrom(
            foregroundColor: FC.blue,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text('home_view_all'.tr),
      ),
    ]);
  }
}

class _HistoryList extends StatelessWidget {
  final HomeController controller;
  final bool isDark;
  const _HistoryList({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: controller.streamLastPresence(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
              children: List.generate(
                  3,
                  (_) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        height: 76,
                        decoration: BoxDecoration(
                          color: isDark ? FC.card2Dark : FC.borderLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      )));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            height: 90,
            alignment: Alignment.center,
            child: Text('home_no_record'.tr,
                style: TextStyle(
                    color: isDark ? FC.textTerDark : FC.textTerLight,
                    fontSize: 13)),
          );
        }
        return Column(
          children: docs.take(5).map((doc) {
            final d = doc.data();
            return _HistoryItem(data: d, isDark: isDark);
          }).toList(),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  const _HistoryItem({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final complete = data['keluar'] != null;
    final accent = complete ? FC.success : FC.warning;

    String dateStr = '', inTime = '--:--', outTime = '--:--';
    String office = data['office'] as String? ?? '';
    try {
      dateStr = DateFormat.yMMMd().format(DateTime.parse(data['date']));
    } catch (_) {}
    try {
      if (data['masuk']?['date'] != null) {
        inTime = DateFormat.Hm().format(DateTime.parse(data['masuk']['date']));
      }
    } catch (_) {}
    try {
      if (data['keluar']?['date'] != null) {
        outTime =
            DateFormat.Hm().format(DateTime.parse(data['keluar']['date']));
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(Routes.DETAIL_PRESENSI, arguments: data),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    complete
                        ? Icons.check_circle_outline_rounded
                        : Icons.access_time_rounded,
                    color: accent,
                    size: 21,
                  )),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(dateStr,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: tp))),
                      if (office.isNotEmpty)
                        Text(office,
                            style: const TextStyle(
                                color: FC.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.login, size: 13, color: FC.success),
                      const SizedBox(width: 3),
                      Text(inTime,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tp)),
                      const SizedBox(width: 14),
                      Icon(Icons.logout, size: 13, color: FC.warning),
                      const SizedBox(width: 3),
                      Text(outTime,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tp)),
                    ]),
                  ])),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: isDark ? FC.textTerDark : FC.textTerLight),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Utility widgets ──────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? FC.card2Dark : const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? FC.borderDark : FC.borderLight),
        ),
        child: Icon(icon,
            size: 16, color: isDark ? FC.textSecDark : FC.textSecLight),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final bool isId, isDark;
  final VoidCallback onTap;
  const _LangBtn(
      {required this.isId, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? FC.card2Dark : const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? FC.borderDark : FC.borderLight),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isId ? '🇮🇩' : '🇬🇧', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(isId ? 'ID' : 'EN',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isDark ? FC.textSecDark : FC.textSecLight,
              )),
        ]),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _SheetItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ))),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: color.withValues(alpha: 0.4)),
          ]),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final bool isDark;
  const _Shimmer({required this.isDark});
  @override
  Widget build(BuildContext context) {
    final col = isDark ? FC.card2Dark : FC.borderLight;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 70),
        Container(
            height: 90,
            decoration: BoxDecoration(
                color: col, borderRadius: BorderRadius.circular(18))),
        const SizedBox(height: 14),
        Container(
            height: 120,
            decoration: BoxDecoration(
                color: col, borderRadius: BorderRadius.circular(16))),
        const SizedBox(height: 14),
        Container(
            height: 100,
            decoration: BoxDecoration(
                color: col, borderRadius: BorderRadius.circular(16))),
      ]),
    );
  }
}
