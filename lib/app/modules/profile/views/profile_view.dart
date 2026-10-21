import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:fineer/app/services/locale_service.dart';
import 'package:fineer/app/services/notification_service.dart';
import 'package:fineer/app/services/theme_service.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:fineer/components/fineer_navbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? FC.bgDark : const Color(0xFFF0F6FF),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: controller.streamUser(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(FC.blue),
                    strokeWidth: 2.5));
          }
          final user = snap.data?.data() ?? {};
          return _ProfileScaffold(
              user: user, isDark: isDark, controller: controller);
        },
      ),
      bottomNavigationBar: FineerNavBar(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Main scaffold — no AppBar, full-bleed hero
// ─────────────────────────────────────────────────────────────────

class _ProfileScaffold extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDark;
  final ProfileController controller;

  const _ProfileScaffold(
      {required this.user, required this.isDark, required this.controller});

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name.isEmpty
            ? '?'
            : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ts = Get.find<ThemeService>();
    final ls = Get.find<LocaleService>();
    NotificationService? ns;
    try {
      ns = Get.find<NotificationService>();
    } catch (_) {}

    final name = user['name'] as String? ?? '-';
    final job = user['job'] as String? ?? '-';
    final site = user['site'] as String? ?? '-';
    final nik = user['nik']?.toString() ?? '-';
    final email = user['email'] as String? ?? '-';
    final isAdmin = (user['role'] as String? ?? '') == 'admin';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Full-bleed hero SliverAppBar ─────────────────────────
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: FC.blue,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          forceElevated: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          actions: [
            // Theme toggle in profile header
            Obx(() => IconButton(
                  icon: Icon(
                    ts.isDarkMode.value
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: ts.toggle,
                )),
            // Language toggle
            Obx(() => GestureDetector(
                  onTap: ls.toggle,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(ls.isId ? '🇮🇩' : '🇬🇧',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(ls.isId ? 'ID' : 'EN',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
                )),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [FC.blue, Color(0xFF003A8C)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Avatar — blue gradient circle with initials
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(_initials(name),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 4),
                    // Job + site in a pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$job  ·  $site',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: FC.yellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: FC.blue,
                            )),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Stats strip ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _StatsStrip(controller: controller, isDark: isDark),
        ),

        // ── Content ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Personal info
              _Section(title: 'profile_info'.tr, isDark: isDark, children: [
                _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'NIK',
                    value: nik,
                    isDark: isDark),
                _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                    isDark: isDark),
                _InfoTile(
                    icon: Icons.work_outline_rounded,
                    label: 'Jabatan',
                    value: job,
                    isDark: isDark),
                _InfoTile(
                    icon: Icons.location_city_outlined,
                    label: 'Site',
                    value: site,
                    isDark: isDark,
                    isLast: true),
              ]),
              const SizedBox(height: 16),

              // Preferences
              _Section(title: 'profile_settings'.tr, isDark: isDark, children: [
                Obx(() => _SwitchTile(
                      icon: ts.isDarkMode.value
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: ts.isDarkMode.value
                          ? 'dark_mode'.tr
                          : 'light_mode'.tr,
                      isDark: isDark,
                      value: ts.isDarkMode.value,
                      onChanged: (_) => ts.toggle(),
                    )),
                _Divider(isDark: isDark),
                Obx(() => _ActionTile(
                      icon: Icons.language_rounded,
                      label: 'language'.tr,
                      isDark: isDark,
                      trailing: _LangPill(isId: ls.isId),
                      onTap: ls.toggle,
                      isLast: ns == null,
                    )),
                if (ns != null) ...[
                  _Divider(isDark: isDark),
                  Obx(() => _SwitchTile(
                        icon: Icons.notifications_outlined,
                        label: 'profile_notifications'.tr,
                        sublabel: 'profile_notif_sub'.tr,
                        isDark: isDark,
                        value: ns!.isNotificationEnabled.value,
                        onChanged: (v) => ns!.toggleNotifications(v),
                        isLast: true,
                      )),
                ],
              ]),
              const SizedBox(height: 16),

              // Admin section
              if (isAdmin) ...[
                _Section(title: 'Admin', isDark: isDark, children: [
                  _ActionTile(
                    icon: Icons.person_add_outlined,
                    label: 'home_add_emp'.tr,
                    isDark: isDark,
                    color: FC.blue,
                    onTap: () => Get.toNamed(Routes.ADD_PEGAWAI),
                    isLast: false,
                  ),
                  _Divider(isDark: isDark),
                  _ActionTile(
                    icon: Icons.fingerprint,
                    label: 'home_biometric_settings'.tr,
                    isDark: isDark,
                    color: const Color(0xFF7C3AED),
                    onTap: () => Get.toNamed(Routes.BIOMETRIC_SETUP),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
              ] else ...[
                _Section(title: 'Biometrik', isDark: isDark, children: [
                  _ActionTile(
                    icon: Icons.fingerprint,
                    label: 'home_biometric_settings'.tr,
                    isDark: isDark,
                    color: const Color(0xFF7C3AED),
                    onTap: () => Get.toNamed(Routes.BIOMETRIC_SETUP),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
              ],

              // App info
              _AppInfoSection(isDark: isDark),
              const SizedBox(height: 24),

              // Logout
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmLogout(context, isDark),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text('home_logout'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FC.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                  child: Text('Fineer by TripleS',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FC.textTerDark : FC.textTerLight))),
            ]),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, bool isDark) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final border = isDark ? FC.borderDark : FC.borderLight;
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
                offset: const Offset(0, 8))
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
                    color: FC.error.withValues(alpha: isDark ? 0.15 : 0.08)),
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
                style: TextStyle(fontSize: 13, color: ts, height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ts,
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44)),
                child: Text('cancel'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                onPressed: () async {
                  Get.back();
                  try {
                    await Get.find<NotificationService>()
                        .toggleNotifications(false);
                  } catch (_) {}

                  await controller.logout();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: FC.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 44)),
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

// ─── Stats strip ──────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final ProfileController controller;
  final bool isDark;
  const _StatsStrip({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;

    return Obx(() => Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            _Stat(
              label: 'profile_present'.tr,
              value: controller.presentDays.value.toString(),
              icon: Icons.check_circle_outline,
              color: FC.success,
              isDark: isDark,
            ),
            _StatDivider(isDark: isDark),
            _Stat(
              label: 'profile_late'.tr,
              value: controller.lateDays.value.toString(),
              icon: Icons.watch_later_outlined,
              color: FC.warning,
              isDark: isDark,
            ),
            _StatDivider(isDark: isDark),
            _Stat(
              label: 'profile_this_month'.tr,
              value: DateFormat('MMM y').format(DateTime.now()),
              icon: Icons.calendar_month_outlined,
              color: FC.blue,
              isDark: isDark,
              isDate: true,
            ),
          ]),
        ));
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark, isDate;
  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark,
      this.isDate = false});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    // NO Expanded — this sits inside Row inside Container inside SliverList
    // Expanded without a bounded Flex parent causes unconstrained layout
    return Flexible(
      fit: FlexFit.tight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDate ? 13 : 22,
                fontWeight: FontWeight.w800,
                color: tp,
                letterSpacing: isDate ? 0 : -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: ts)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool isDark;
  const _StatDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 50, color: isDark ? FC.borderDark : FC.borderLight);
}

// ─── Section card ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _Section(
      {required this.title, required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final tt = isDark ? FC.textTerDark : FC.textTerLight;
    final border = isDark ? FC.borderDark : FC.borderLight;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: tt)),
      ),
      Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark, isLast;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FC.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: FC.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: ts, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: tp)),
              ])),
        ]),
      ),
      if (!isLast) Divider(height: 1, indent: 62, color: border),
    ]);
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool isDark, value, isLast;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(
      {required this.icon,
      required this.label,
      required this.isDark,
      required this.value,
      required this.onChanged,
      this.sublabel,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final border = isDark ? FC.borderDark : FC.borderLight;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FC.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: FC.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: tp)),
                if (sublabel != null)
                  Text(sublabel!, style: TextStyle(fontSize: 11, color: ts)),
              ])),
          Switch.adaptive(
              value: value, activeColor: FC.blue, onChanged: onChanged),
        ]),
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 62,
            color: isDark ? FC.borderDark : FC.borderLight),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark, isLast;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.isDark,
      required this.onTap,
      this.isLast = false,
      this.color = FC.blue,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final tp = isDark ? FC.textDark : FC.textLight;
    final border = isDark ? FC.borderDark : FC.borderLight;
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: tp))),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: isDark ? FC.textTerDark : FC.textTerLight),
          ]),
        ),
      ),
      if (!isLast) Divider(height: 1, indent: 62, color: border),
    ]);
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 62, color: isDark ? FC.borderDark : FC.borderLight);
}

class _LangPill extends StatelessWidget {
  final bool isId;
  const _LangPill({required this.isId});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FC.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FC.blue.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isId ? '🇮🇩' : '🇬🇧', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(isId ? 'Indonesia' : 'English',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: FC.blue)),
        ]),
      );
}

class _AppInfoSection extends StatelessWidget {
  final bool isDark;

  const _AppInfoSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About Fineer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tp,
                ),
              ),
              const SizedBox(height: 8),
              _appInfoRow('Application', info?.appName ?? 'Fineer', tp, ts),
              _appInfoRow('Version', info?.version ?? '-', tp, ts),
              _appInfoRow(
                  'Build',
                  info == null
                      ? '-'
                      : '${(int.tryParse(info.buildNumber) ?? 0) % 1000}',
                  tp,
                  ts),
            ],
          ),
        );
      },
    );
  }

  Widget _appInfoRow(
    String label,
    String value,
    Color primary,
    Color secondary,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: secondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
