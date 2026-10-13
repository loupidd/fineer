import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ─── Attendance state for fingerprint button ──────────────────────
// 0 = not checked in  → blink/shine (action needed)
// 1 = checked in, before 17:00 → steady (no action needed yet)
// 2 = checked in, after 17:00, no checkout → blink/shine (action needed)
// 3 = fully completed → steady green

class FineerNavBar extends StatelessWidget {
  FineerNavBar({super.key});
  final _pageC = Get.find<PageIndexController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;

    return Obx(() {
      final sel = _pageC.pageIndex.value;
      // AnnotatedRegion colors the system navigation bar (gesture bar / 3-button nav)
      // to match our background so there's no grey strip below the navbar.
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: isDark ? FC.bgDark : Colors.white,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: Container(
          // Fill the full bottom area including system nav bar inset
          color: isDark ? FC.bgDark : Colors.white,
          child: SafeArea(
            top: false,
            // bottom: false so our Container color extends behind the gesture bar,
            // but SafeArea still adds padding for the home indicator height
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: FC.blue.withValues(alpha: isDark ? 0.1 : 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Home
                    Expanded(
                        child: _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'nav_home'.tr,
                      selected: sel == 0,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _pageC.changePage(0);
                      },
                    )),

                    // Center: Fingerprint attendance button
                    _FingerprintNavBtn(pageC: _pageC, isDark: isDark),

                    // Profile
                    Expanded(
                        child: _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person_rounded,
                      label: 'nav_profile'.tr,
                      selected: sel == 2,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _pageC.changePage(2);
                      },
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ─── Fingerprint center button ─────────────────────────────────────
// Reads today's presence stream to determine attendance state
// and animates accordingly.

class _FingerprintNavBtn extends StatefulWidget {
  final PageIndexController pageC;
  final bool isDark;
  const _FingerprintNavBtn({required this.pageC, required this.isDark});

  @override
  State<_FingerprintNavBtn> createState() => _FingerprintNavBtnState();
}

class _FingerprintNavBtnState extends State<_FingerprintNavBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox(width: 80);

    final todayDocID = DateFormat('M-d-yyyy').format(DateTime.now());

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pegawai')
          .doc(uid)
          .collection('presence')
          .doc(todayDocID)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final hasIn = data?['masuk'] != null;
        final hasOut = data?['keluar'] != null;
        final now = DateTime.now();
        final isAfterCheckout = now.hour >= 17; // 17:00 = checkout time

        // Determine attendance state
        final int state;
        if (hasOut) {
          state = 3; // fully done — steady green, no pulse
        } else if (hasIn && !isAfterCheckout) {
          state = 1; // checked in, not checkout time — steady blue
        } else if (hasIn && isAfterCheckout) {
          state = 2; // need to check out — pulse amber
        } else {
          state = 0; // need to check in — pulse blue
        }

        final shouldPulse = state == 0 || state == 2;
        if (shouldPulse && !_glowCtrl.isAnimating) {
          _glowCtrl.repeat(reverse: true);
        } else if (!shouldPulse && _glowCtrl.isAnimating) {
          _glowCtrl.stop();
          _glowCtrl.value = 0;
        }

        // Colors per state
        final Color btnColor;
        final Color glowColor;
        final String label;
        switch (state) {
          case 3:
            btnColor = FC.success;
            glowColor = FC.success;
            label = 'Selesai';
            break;
          case 2:
            btnColor = FC.warning;
            glowColor = FC.warning;
            label = 'Check Out';
            break;
          case 1:
            btnColor = FC.blue;
            glowColor = FC.blue;
            label = 'Hadir';
            break;
          default:
            btnColor = FC.blue;
            glowColor = FC.blue;
            label = 'Check In';
        }

        return Obx(() {
          final processing = widget.pageC.isProcessingAttendance.value;

          return SizedBox(
            width: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, child) {
                    final glowAlpha =
                        shouldPulse ? 0.2 + _glowAnim.value * 0.5 : 0.0;
                    final scale =
                        shouldPulse ? 1.0 + _glowAnim.value * 0.08 : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: glowAlpha),
                              blurRadius: 20,
                              spreadRadius: shouldPulse ? 4 : 0,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: processing || state == 3
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            widget.pageC.processAttendance();
                          },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            btnColor,
                            Color.lerp(btnColor, Colors.black, 0.2)!,
                          ],
                        ),
                      ),
                      child: processing
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : state == 3
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 26)
                              : const Icon(Icons.fingerprint,
                                  color: Colors.white, size: 26),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  processing ? '...' : label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: btnColor,
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

// ─── Regular nav item ─────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected, isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = FC.blue;
    final inactive = isDark ? FC.textTerDark : FC.textTerLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
                horizontal: selected ? 14 : 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? active.withValues(alpha: isDark ? 0.18 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              selected ? activeIcon : icon,
              color: selected ? active : inactive,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? active : inactive,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
