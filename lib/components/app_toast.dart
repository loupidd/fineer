import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum ToastType { success, error, warning, info }

/// Fineer toast — replaces Get.snackbar everywhere.
///
/// Floats at the TOP of the screen (the bottom is owned by the floating
/// navbar), uses the app surface/border tokens so it works in light and
/// dark mode, shows a tinted icon tile, and a thin countdown line that
/// shrinks over the toast's duration. Swipe sideways to dismiss.
///
/// Cost: one small widget tree and one AnimationController per toast.
class AppToast {
  AppToast._();

  // key -> time until which an identical toast is considered "still on screen"
  static final Map<String, DateTime> _activeUntil = {};

  static void success(String title, String message,
          {Duration? duration, IconData? icon, bool dismissible = true}) =>
      show(ToastType.success, title, message,
          duration: duration, icon: icon, dismissible: dismissible);

  static void error(String title, String message,
          {Duration? duration, IconData? icon, bool dismissible = true}) =>
      show(ToastType.error, title, message,
          duration: duration, icon: icon, dismissible: dismissible);

  static void warning(String title, String message,
          {Duration? duration, IconData? icon, bool dismissible = true}) =>
      show(ToastType.warning, title, message,
          duration: duration, icon: icon, dismissible: dismissible);

  static void info(String title, String message,
          {Duration? duration, IconData? icon, bool dismissible = true}) =>
      show(ToastType.info, title, message,
          duration: duration, icon: icon, dismissible: dismissible);

  /// Session ended — warning style with a lock icon, not swipe-dismissible.
  static void session(String title, String message, {Duration? duration}) =>
      show(ToastType.warning, title, message,
          duration: duration ?? const Duration(milliseconds: 3600),
          icon: Icons.lock_clock_rounded,
          dismissible: false);

  /// For legacy call sites that picked a colour instead of a type.
  static void fromColor(String title, String message,
      {required Color color, Duration? duration}) {
    final type = color == const Color(0xFF10B981) || color == FC.success
        ? ToastType.success
        : color == const Color(0xFFF59E0B) || color == FC.warning
            ? ToastType.warning
            : color == FC.blue
                ? ToastType.info
                : ToastType.error;
    show(type, title, message, duration: duration);
  }

  static void show(
    ToastType type,
    String title,
    String message, {
    Duration? duration,
    IconData? icon,
    bool dismissible = true,
  }) {
    final d = duration ??
        (type == ToastType.error
            ? const Duration(milliseconds: 3600)
            : type == ToastType.warning
                ? const Duration(milliseconds: 3200)
                : const Duration(milliseconds: 2400));

    // Never stack the same toast: skip it while an identical one is still on
    // screen (or queued behind the current one).
    final key = '${type.name}|$title|$message';
    final now = DateTime.now();
    final until = _activeUntil[key];
    if (until != null && now.isBefore(until)) return;
    _activeUntil[key] = now.add(d + const Duration(milliseconds: 900));
    _activeUntil.removeWhere((_, t) => now.isAfter(t));

    switch (type) {
      case ToastType.success:
        HapticFeedback.lightImpact();
        break;
      case ToastType.error:
        HapticFeedback.mediumImpact();
        break;
      case ToastType.warning:
        HapticFeedback.selectionClick();
        break;
      case ToastType.info:
        break;
    }

    Get.showSnackbar(GetSnackBar(
      snackPosition: SnackPosition.TOP,
      snackStyle: SnackStyle.FLOATING,
      backgroundColor: Colors.transparent,
      boxShadows: const [],
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      maxWidth: 360,
      borderRadius: 0,
      onTap: (_) => Get.closeCurrentSnackbar(),
      duration: d,
      animationDuration: const Duration(milliseconds: 320),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      isDismissible: dismissible,
      dismissDirection: DismissDirection.horizontal,
      messageText: _ToastBody(
        type: type,
        title: title,
        message: message,
        duration: d,
        icon: icon,
      ),
    ));
  }
}

class _ToastBody extends StatefulWidget {
  final ToastType type;
  final String title;
  final String message;
  final Duration duration;
  final IconData? icon;

  const _ToastBody({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    this.icon,
  });

  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.type) {
      case ToastType.success:
        return FC.success;
      case ToastType.error:
        return FC.error;
      case ToastType.warning:
        return FC.warning;
      case ToastType.info:
        return FC.blue;
    }
  }

  IconData get _icon {
    if (widget.icon != null) return widget.icon!;
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_rounded;
      case ToastType.error:
        return Icons.close_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FC.cardDark : Colors.white;
    final border = dark ? FC.borderDark : FC.borderLight;
    final tp = dark ? FC.textDark : FC.textLight;
    final ts = dark ? FC.textSecDark : FC.textSecLight;
    final accent = _accent;
    final hasMessage = widget.message.trim().isNotEmpty;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Color.alphaBlend(accent.withValues(alpha: 0.28), border)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: dark ? 0.22 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 13),
              child: Row(children: [
                // Icon tile pops in with a light elastic scale
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: 0.5 + 0.5 * v, child: child),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(_icon, color: accent, size: 19),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: tp,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (hasMessage) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: ts,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            // Countdown line
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: AnimatedBuilder(
                animation: _timer,
                builder: (_, __) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _timer.value,
                    child: ColoredBox(
                        color: accent.withValues(alpha: 0.55),
                        child: const SizedBox.expand()),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
