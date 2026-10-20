import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Result of a trusted-time check.
///
/// [level]:
///  - `normal`      clock agrees with a trusted reference
///  - `warning`     small drift (>= 2 min)
///  - `suspicious`  large drift or clock moved backwards (>= 3 min) → block
///  - `unverified`  offline and no in-process reference; punch is allowed
///                  but flagged for server-side review
class ClockCheck {
  final bool online;
  final String level;
  final int deltaSeconds;

  /// Best estimate of the real current time (local DateTime).
  final DateTime trustedNow;

  /// Server time (ms since epoch, UTC) at the last successful sync, or null.
  final int? anchorServerMs;

  const ClockCheck({
    required this.online,
    required this.level,
    required this.deltaSeconds,
    required this.trustedNow,
    required this.anchorServerMs,
  });

  bool get blocked => level == 'suspicious';
}

/// Trusted time without writing to Firestore.
///
/// Online:  reads the HTTP `Date` header from Google's API host (no auth,
///          no Firestore write, doubles as a connectivity probe).
/// Offline: uses the last server anchor plus a monotonic [Stopwatch].
///          The stopwatch only survives while the process lives, so after
///          an app restart we can only detect the clock going *backwards*;
///          the Cloud Function re-checks everything when the punch syncs.
class ClockService {
  ClockService._();

  static const _kServerMs = 'clock_anchor_server_ms';
  static const _kDeviceMs = 'clock_anchor_device_ms';
  static const _warnSeconds = 120;
  static const _suspiciousSeconds = 180;

  static final Stopwatch _sw = Stopwatch();
  static int? _anchorServerMs; // server time at anchor
  static bool _hasLiveAnchor = false;

  static Future<DateTime?> _fetchServerTime() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client
          .headUrl(Uri.parse('https://firestore.googleapis.com/'))
          .timeout(const Duration(seconds: 4));
      final res = await req.close().timeout(const Duration(seconds: 4));
      final header = res.headers.value(HttpHeaders.dateHeader);
      await res.drain<void>();
      if (header == null) return null;
      return HttpDate.parse(header); // UTC
    } catch (e) {
      log('ClockService: server time unavailable ($e)');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _saveAnchor(DateTime serverUtc, DateTime device) async {
    _anchorServerMs = serverUtc.millisecondsSinceEpoch;
    _sw
      ..reset()
      ..start();
    _hasLiveAnchor = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kServerMs, _anchorServerMs!);
      await p.setInt(_kDeviceMs, device.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Seeds the anchor in the background (call from splash / login).
  static Future<void> seed() async {
    final device = DateTime.now();
    final server = await _fetchServerTime();
    if (server != null) await _saveAnchor(server, device);
  }

  static Future<ClockCheck> check() async {
    final device = DateTime.now();
    final server = await _fetchServerTime();

    // ── Online ────────────────────────────────────────────────────
    if (server != null) {
      final delta = server.difference(device.toUtc()).inSeconds.abs();
      await _saveAnchor(server, device);
      return ClockCheck(
        online: true,
        level: _level(delta),
        deltaSeconds: delta,
        trustedNow: server.toLocal(),
        anchorServerMs: _anchorServerMs,
      );
    }

    // ── Offline, live anchor (same process run) ───────────────────
    if (_hasLiveAnchor && _anchorServerMs != null) {
      final estimated = DateTime.fromMillisecondsSinceEpoch(
          _anchorServerMs! + _sw.elapsedMilliseconds,
          isUtc: true);
      final delta = estimated.difference(device.toUtc()).inSeconds.abs();
      return ClockCheck(
        online: false,
        level: _level(delta),
        deltaSeconds: delta,
        trustedNow: estimated.toLocal(),
        anchorServerMs: _anchorServerMs,
      );
    }

    // ── Offline, restarted process: only persisted anchor ─────────
    try {
      final p = await SharedPreferences.getInstance();
      final sMs = p.getInt(_kServerMs);
      final dMs = p.getInt(_kDeviceMs);
      if (sMs != null && dMs != null) {
        // The device clock must not be earlier than when we last saw it.
        final backwards = (dMs - device.millisecondsSinceEpoch) ~/ 1000;
        if (backwards >= _suspiciousSeconds) {
          return ClockCheck(
            online: false,
            level: 'suspicious',
            deltaSeconds: backwards,
            trustedNow: device,
            anchorServerMs: sMs,
          );
        }
        return ClockCheck(
          online: false,
          level: 'unverified',
          deltaSeconds: -1,
          trustedNow: device,
          anchorServerMs: sMs,
        );
      }
    } catch (_) {}

    return ClockCheck(
      online: false,
      level: 'unverified',
      deltaSeconds: -1,
      trustedNow: device,
      anchorServerMs: null,
    );
  }

  static String _level(int delta) {
    if (delta >= _suspiciousSeconds) return 'suspicious';
    if (delta >= _warnSeconds) return 'warning';
    return 'normal';
  }
}
