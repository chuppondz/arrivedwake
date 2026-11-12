import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/destination.dart';
import 'alarm_service.dart';

enum PermissionResult { granted, denied, deniedForever, serviceDisabled }

/// ติดตามตำแหน่งต่อเนื่อง (รวมตอนแอพอยู่เบื้องหลัง/จอดับ)
/// และสั่งปลุกเมื่อเข้าใกล้จุดหมายในระยะที่ตั้งไว้
class TrackingService extends ChangeNotifier {
  TrackingService(this._alarm);

  final AlarmService _alarm;
  StreamSubscription<Position>? _sub;

  Destination? _target;
  Position? _position;
  double? _distance;
  bool _tracking = false;
  bool _triggered = false;
  int _ringCount = 0;

  Destination? get target => _target;
  Position? get position => _position;
  double? get distanceMeters => _distance;
  bool get isTracking => _tracking;
  bool get triggered => _triggered;

  /// เพิ่มขึ้นทุกครั้งที่เริ่มปลุก ให้ UI ใช้ตัดสินใจเปิดหน้าจอปลุก
  int get ringCount => _ringCount;

  /// ขอสิทธิ์ตำแหน่ง
  /// - Android: แค่ "ขณะใช้แอพ" ก็พอ เพราะเราใช้ Foreground Service
  /// - iOS: ควรได้ "ตลอดเวลา" (Always) เพื่อให้ทำงานต่อได้เมื่อปิดจอนาน ๆ
  Future<PermissionResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermissionResult.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return PermissionResult.deniedForever;
    }
    if (perm == LocationPermission.denied) return PermissionResult.denied;

    // iOS: ขออัปเกรดเป็น Always (ระบบจะถามเพิ่มอีกครั้ง)
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        perm == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
    return PermissionResult.granted;
  }

  Future<Position?> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updatePosition(p);
      return p;
    } catch (e) {
      debugPrint('อ่านตำแหน่งไม่ได้: $e');
      return Geolocator.getLastKnownPosition();
    }
  }

  void setTarget(Destination? d) {
    _target = d;
    _recalculate();
    notifyListeners();
  }

  /// เรียกเมื่อผู้ใช้เปลี่ยนระยะหรือโหมดระหว่างติดตามอยู่
  void targetChanged() {
    _recalculate();
    notifyListeners();
  }

  Future<void> start() async {
    if (_target == null) return;
    await _sub?.cancel();
    _triggered = false;
    _tracking = true;
    notifyListeners();

    _sub = Geolocator.getPositionStream(locationSettings: _locationSettings())
        .listen(
      _updatePosition,
      onError: (Object e) => debugPrint('location stream error: $e'),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _tracking = false;
    _triggered = false;
    await _alarm.stop();
    notifyListeners();
  }

  /// ปิดเสียงปลุก (หลังปลุกแล้วถือว่าจบทริป หยุดติดตามด้วย)
  Future<void> dismissAlarm() => stop();

  /// เลื่อนปลุก: ปิดเสียงไว้ก่อนแล้วปลุกอีกครั้งหลังจาก [delay]
  Future<void> snooze(Duration delay) async {
    await _alarm.stop();
    _triggered = true; // กันไม่ให้ดังซ้ำทันทีจาก location update ถัดไป
    notifyListeners();
    Timer(delay, () {
      if (_tracking && _target != null) _ring(_target!);
    });
  }

  LocationSettings _locationSettings() {
    const distanceFilter = 15; // อัปเดตเมื่อขยับเกิน 15 ม. (ประหยัดแบต)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'กำลังติดตามระยะทางไปยังจุดหมาย',
          notificationText: 'จะปลุกเมื่อใกล้ถึงจุดหมาย',
          notificationChannelName: 'ติดตามตำแหน่ง',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false, // ห้ามให้ iOS หยุดเองตอนรถติด
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  void _updatePosition(Position p) {
    _position = p;
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    final t = _target;
    final p = _position;
    if (t == null || p == null) {
      _distance = null;
      return;
    }
    _distance = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      t.latitude,
      t.longitude,
    );
    if (_tracking && !_triggered && _distance! <= t.radiusMeters) {
      _triggered = true;
      _ring(t);
    }
  }

  void _ring(Destination t) {
    _ringCount++;
    _alarm.ring(mode: t.mode, destinationName: t.name);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
