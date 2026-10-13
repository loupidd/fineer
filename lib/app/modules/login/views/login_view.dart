import 'dart:math' as math;
import 'package:fineer/app/services/locale_service.dart';
import 'package:fineer/app/services/theme_service.dart';
import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read services
    final ts = Get.find<ThemeService>();
    final ls = Get.find<LocaleService>();
    // isDark from Theme.of(context) — auto-updates when GetMaterialApp
    // rebuilds after Get.changeThemeMode() call.
    // NO local bool cached outside Obx.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Animated background — takes isDark from current build
          SizedBox.expand(child: _AnimatedBg(isDark: isDark)),

          // Toggles — always white overlay style
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _Toggle(
                    onTap: ts.toggle,
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Locale toggle is reactive so it needs Obx for its text
                  Obx(() => _Toggle(
                        onTap: ls.toggle,
                        child: Text(ls.isId ? '🇮🇩' : '🇬🇧',
                            style: const TextStyle(fontSize: 14)),
                      )),
                ]),
              ),
            ),
          ),

          // Content area — reacts to biometric state
          SafeArea(
            child: Obx(() {
              if (controller.isCheckingBiometric.value) {
                return _LoadingState(size: size);
              }
              if (controller.canUseBiometric.value &&
                  !controller.showPasswordLogin.value) {
                return _BiometricPrompt(
                    controller: controller, size: size, isDark: isDark);
              }
              return _PasswordForm(
                  controller: controller, size: size, isDark: isDark);
            }),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final Size size;
  const _LoadingState({required this.size});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('lib/assets/appLogo.webp',
              height: size.height * 0.14,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.business, size: 70, color: Colors.white)),
          const SizedBox(height: 40),
          const CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('login_checking_bio'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
      );
}

class _BiometricPrompt extends StatelessWidget {
  final LoginController controller;
  final Size size;
  final bool isDark;
  const _BiometricPrompt(
      {required this.controller, required this.size, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final card = isDark ? FC.cardDark : Colors.white;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
        child: Column(children: [
          SizedBox(height: size.height * 0.10),
          Image.asset('lib/assets/appLogo.webp',
              height: size.height * 0.13,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.business, size: 70, color: Colors.white)),
          SizedBox(height: size.height * 0.06),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Column(children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: FC.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Obx(() => Icon(
                    controller.biometricType.value == 'Face ID'
                        ? Icons.face
                        : Icons.fingerprint,
                    size: 40,
                    color: FC.blue)),
              ),
              const SizedBox(height: 20),
              Text('login_welcome'.tr,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 5),
              Obx(() => Text(controller.lastBiometricUser.value,
                  style: TextStyle(fontSize: 14, color: ts))),
              const SizedBox(height: 24),
              Obx(() => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.loginWithBiometric(),
                      icon: controller.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Icon(controller.getBiometricIcon(), size: 20),
                      label: Obx(() => Text(
                          '${'login_with_bio'.tr} ${controller.biometricType.value}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FC.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => controller.showPasswordForm(),
                child: Text('login_use_password'.tr,
                    style: TextStyle(color: ts, fontSize: 14)),
              ),
            ]),
          ),
          SizedBox(height: size.height * 0.05),
          _Footer(size: size),
        ]),
      ),
    );
  }
}

class _PasswordForm extends StatelessWidget {
  final LoginController controller;
  final Size size;
  final bool isDark;
  const _PasswordForm(
      {required this.controller, required this.size, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final card = isDark ? FC.cardDark : Colors.white;
    final border = isDark ? FC.borderDark : FC.borderLight;
    final tp = isDark ? FC.textDark : FC.textLight;
    final ts = isDark ? FC.textSecDark : FC.textSecLight;
    final tt = isDark ? FC.textTerDark : FC.textTerLight;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
        child: Column(children: [
          SizedBox(height: size.height * 0.08),
          Image.asset('lib/assets/appLogo.webp',
              height: size.height * 0.13,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.business, size: 70, color: Colors.white)),
          SizedBox(height: size.height * 0.05),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10))
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('login_subtitle'.tr,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: tp)),
              const SizedBox(height: 5),
              Text('login_welcome'.tr,
                  style: TextStyle(fontSize: 14, color: ts)),
              const SizedBox(height: 22),
              Text('login_email'.tr,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tt,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              TextField(
                controller: controller.emailC,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: TextStyle(fontSize: 15, color: tp),
                decoration: InputDecoration(
                    hintText: 'login_email_hint'.tr,
                    prefixIcon: const Icon(Icons.email_outlined, size: 18)),
              ),
              const SizedBox(height: 14),
              Text('login_password'.tr,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tt,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              _PasswordField(ctrl: controller.passC, tp: tp),
              const SizedBox(height: 22),
              Obx(() => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.login(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FC.yellow,
                        foregroundColor: FC.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      child: controller.isLoading.value
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(FC.blue)))
                          : Text('login_btn'.tr),
                    ),
                  )),
              Obx(() {
                if (!controller.canUseBiometric.value) {
                  return const SizedBox.shrink();
                }
                return Column(children: [
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Divider(color: border)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(fontSize: 11, color: tt))),
                    Expanded(child: Divider(color: border)),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => controller.retryBiometric(),
                      icon: Icon(controller.getBiometricIcon(),
                          size: 20, color: FC.blue),
                      label: Obx(() => Text(
                          'Use ${controller.biometricType.value}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: FC.blue))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FC.blue, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]);
              }),
            ]),
          ),
          SizedBox(height: size.height * 0.04),
          _Footer(size: size),
        ]),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController ctrl;
  final Color tp;
  const _PasswordField({required this.ctrl, required this.tp});
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.ctrl,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        style: TextStyle(fontSize: 15, color: widget.tp),
        decoration: InputDecoration(
          hintText: 'login_password_hint'.tr,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}

class _Footer extends StatelessWidget {
  final Size size;
  const _Footer({required this.size});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('Provided by',
            style: TextStyle(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 4),
        Image.asset('lib/assets/tripleS-transparent-white.webp',
            height: size.height * 0.04,
            errorBuilder: (_, __, ___) => const Text('Triple S',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 20),
      ]);
}

class _Toggle extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Toggle({required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      );
}

class _AnimatedBg extends StatefulWidget {
  final bool isDark;
  const _AnimatedBg({required this.isDark});
  @override
  State<_AnimatedBg> createState() => _AnimatedBgState();
}

class _AnimatedBgState extends State<_AnimatedBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
            painter: _BgPainter(progress: _ctrl.value, isDark: widget.isDark)),
      );
}

class _BgPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  const _BgPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF060D1F), Color(0xFF0A1628)]
                : const [Color(0xFF0078D7), Color(0xFF0052A3)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));

    final dotP = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    const sp = 32.0;
    for (double x = 0; x < w + sp; x += sp)
      for (double y = 0; y < h + sp; y += sp) {
        canvas.drawCircle(Offset(x, y), 1.0, dotP);
      }

    final rng = math.Random(42);
    final traceP = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final pulseP = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 14; i++) {
      final isH = rng.nextBool();
      final pos = rng.nextDouble();
      final s = rng.nextDouble() * 0.4;
      final e = s + 0.2 + rng.nextDouble() * 0.35;
      final spd = 0.3 + rng.nextDouble() * 0.5;
      final ph = rng.nextDouble();
      final a = isH ? Offset(s * w, pos * h) : Offset(pos * w, s * h);
      final b = isH ? Offset(e * w, pos * h) : Offset(pos * w, e * h);
      canvas.drawLine(a, b, traceP);
      final t = (progress * spd + ph) % 1.0;
      final px = a.dx + (b.dx - a.dx) * t;
      final py = a.dy + (b.dy - a.dy) * t;
      pulseP.shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.6),
        Colors.white.withValues(alpha: 0.0),
      ]).createShader(Rect.fromCircle(center: Offset(px, py), radius: 12));
      canvas.drawCircle(Offset(px, py), 3.5, pulseP);
    }
    final bP = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const bs = 18.0;
    const bp = 22.0;
    canvas.drawPath(
        Path()
          ..moveTo(bp, bp + bs)
          ..lineTo(bp, bp)
          ..lineTo(bp + bs, bp),
        bP);
    canvas.drawPath(
        Path()
          ..moveTo(w - bp - bs, bp)
          ..lineTo(w - bp, bp)
          ..lineTo(w - bp, bp + bs),
        bP);
    canvas.drawPath(
        Path()
          ..moveTo(bp, h - bp - bs)
          ..lineTo(bp, h - bp)
          ..lineTo(bp + bs, h - bp),
        bP);
    canvas.drawPath(
        Path()
          ..moveTo(w - bp - bs, h - bp)
          ..lineTo(w - bp, h - bp)
          ..lineTo(w - bp, h - bp - bs),
        bP);
  }

  @override
  bool shouldRepaint(_BgPainter old) =>
      old.progress != progress || old.isDark != isDark;
}
