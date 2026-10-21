import 'dart:async';
import 'dart:math' as math;

import 'package:fineer/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ResultKind { success, error, warning, queued }

Color resultColor(ResultKind k) {
  switch (k) {
    case ResultKind.success:
      return FC.success;
    case ResultKind.error:
      return FC.error;
    case ResultKind.warning:
      return FC.warning;
    case ResultKind.queued:
      return FC.blue;
  }
}

/// Lightweight vector animation for attendance results.
///
/// Everything is drawn with a single CustomPainter driven by ONE
/// AnimationController (no Lottie, no images, no per-frame widget rebuilds).
/// Per frame: one arc, one tiny path/lines, and at most ~20 small draw calls.
///
///  success  ring draws → check strokes in → ring pops → ray/dot burst
///  error    ring draws → X strokes in → icon shakes → pulse ring
///  warning  ring draws → "!" strokes in → pulse ring
///  queued   ring draws → clock hands sweep in → pulse ring
///
/// Honours the system "remove animations" setting (jumps to the end state).
class AnimatedResultIcon extends StatefulWidget {
  final ResultKind kind;
  final double size;

  const AnimatedResultIcon({super.key, required this.kind, this.size = 96});

  @override
  State<AnimatedResultIcon> createState() => _AnimatedResultIconState();
}

class _AnimatedResultIconState extends State<AnimatedResultIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final ms = widget.kind == ResultKind.success
        ? 1250
        : widget.kind == ResultKind.error
            ? 1050
            : widget.kind == ResultKind.queued
                ? 1100
                : 950;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _ResultPainter(widget.kind, _c)),
      ),
    );
  }
}

class _ResultPainter extends CustomPainter {
  final ResultKind kind;
  final Animation<double> t;

  _ResultPainter(this.kind, this.t) : super(repaint: t);

  static double _seg(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final color = resultColor(kind);
    final r = size.width * 0.29;
    final stroke = size.width * 0.045;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // Error: horizontal shake that decays
    if (kind == ResultKind.error) {
      final s = _seg(v, 0.40, 1.0);
      canvas.translate(
          math.sin(s * math.pi * 7) * (1 - s) * size.width * 0.04, 0);
    }

    // ── Core (scaled with a small pop) ─────────────────────────────
    canvas.save();
    final pop = 1 + 0.08 * math.sin(_seg(v, 0.45, 0.8) * math.pi);
    canvas.scale(pop);

    // Soft disc fill
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = color.withValues(alpha: 0.12 * _seg(v, 0.35, 0.8)),
    );

    // Ring draws clockwise from the top
    final ringP = Curves.easeOutCubic.transform(_seg(v, 0.0, 0.5));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      -math.pi / 2,
      2 * math.pi * ringP,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    void line(Offset a, Offset b, double p) {
      if (p <= 0) return;
      canvas.drawLine(a, Offset.lerp(a, b, p)!, glyph);
    }

    switch (kind) {
      case ResultKind.success:
        final g = Curves.easeOutCubic.transform(_seg(v, 0.38, 0.72));
        if (g > 0) {
          final path = Path()
            ..moveTo(-0.36 * r, 0.02 * r)
            ..lineTo(-0.10 * r, 0.28 * r)
            ..lineTo(0.38 * r, -0.26 * r);
          final m = path.computeMetrics().first;
          canvas.drawPath(m.extractPath(0, m.length * g), glyph);
        }
        break;
      case ResultKind.error:
        line(Offset(-0.28 * r, -0.28 * r), Offset(0.28 * r, 0.28 * r),
            Curves.easeOut.transform(_seg(v, 0.38, 0.58)));
        line(Offset(0.28 * r, -0.28 * r), Offset(-0.28 * r, 0.28 * r),
            Curves.easeOut.transform(_seg(v, 0.52, 0.72)));
        break;
      case ResultKind.warning:
        line(Offset(0, -0.40 * r), Offset(0, 0.06 * r),
            Curves.easeOut.transform(_seg(v, 0.38, 0.62)));
        final d = Curves.easeOutBack.transform(_seg(v, 0.62, 0.8));
        if (d > 0) {
          canvas.drawCircle(Offset(0, 0.34 * r), 0.075 * r * d,
              Paint()..color = color);
        }
        break;
      case ResultKind.queued:
        line(Offset.zero, Offset(0, -0.38 * r),
            Curves.easeOut.transform(_seg(v, 0.38, 0.58)));
        line(Offset.zero, Offset(0.27 * r, 0.15 * r),
            Curves.easeOut.transform(_seg(v, 0.52, 0.72)));
        final d = _seg(v, 0.38, 0.5);
        if (d > 0) {
          canvas.drawCircle(Offset.zero, stroke * 0.7 * d,
              Paint()..color = color);
        }
        break;
    }
    canvas.restore();

    // ── Effects outside the scaled core ────────────────────────────
    if (kind == ResultKind.success) {
      final e = Curves.easeOutCubic.transform(_seg(v, 0.5, 1.0));
      if (e > 0 && e < 1) {
        final a = 1 - e;
        final ray = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.7
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: a);
        final dot = Paint()..color = color.withValues(alpha: a * 0.8);
        for (var i = 0; i < 10; i++) {
          final ang = i * math.pi / 5 + math.pi / 10;
          final d = Offset(math.cos(ang), math.sin(ang));
          final r0 = r * (1.18 + 0.42 * e);
          final r1 = r0 + r * 0.20 * (1 - e * 0.5);
          canvas.drawLine(d * r0, d * r1, ray);

          final ang2 = i * math.pi / 5;
          final d2 = Offset(math.cos(ang2), math.sin(ang2));
          canvas.drawCircle(d2 * (r * (1.05 + 0.75 * e)),
              stroke * 0.55 * (1 - e * 0.4), dot);
        }
      }
    } else {
      final e = Curves.easeOut.transform(_seg(v, 0.45, 1.0));
      if (e > 0 && e < 1) {
        canvas.drawCircle(
          Offset.zero,
          r * (1 + 0.55 * e),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 0.6
            ..color = color.withValues(alpha: 0.35 * (1 - e)),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ResultPainter old) => old.kind != kind;
}

/// Centered result dialog for attendance: animated icon, title, message and
/// an optional time chip. Success / queued auto-close; tap anywhere to close.
class AttendanceResultDialog {
  AttendanceResultDialog._();

  static int _token = 0;
  static bool _open = false;

  static Future<void> show({
    required ResultKind kind,
    required String title,
    required String message,
    String? timeLabel,
    IconData? timeIcon,
    Duration autoClose = const Duration(milliseconds: 2800),
  }) async {
    final token = ++_token;
    _open = true;

    Timer(autoClose, () {
      if (token == _token && _open && (Get.isDialogOpen ?? false)) Get.back();
    });

    await Get.dialog(
      _ResultCard(
        kind: kind,
        title: title,
        message: message,
        timeLabel: timeLabel,
        timeIcon: timeIcon,
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      transitionCurve: Curves.easeOutCubic,
    );
    _open = false;
  }
}

class _ResultCard extends StatelessWidget {
  final ResultKind kind;
  final String title;
  final String message;
  final String? timeLabel;
  final IconData? timeIcon;

  const _ResultCard({
    required this.kind,
    required this.title,
    required this.message,
    this.timeLabel,
    this.timeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FC.cardDark : Colors.white;
    final border = dark ? FC.borderDark : FC.borderLight;
    final tp = dark ? FC.textDark : FC.textLight;
    final ts = dark ? FC.textSecDark : FC.textSecLight;
    final color = resultColor(kind);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: Color.alphaBlend(color.withValues(alpha: 0.2), border)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: dark ? 0.22 : 0.14),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedResultIcon(kind: kind, size: 132),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: tp,
                )),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: ts)),
            if (timeLabel != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: dark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(timeIcon ?? Icons.schedule_rounded,
                      size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(timeLabel!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.2,
                      )),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
