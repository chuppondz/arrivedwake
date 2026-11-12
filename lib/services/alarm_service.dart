import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../models/destination.dart';

/// ดูแลการปลุก: เสียง, สั่น และแจ้งเตือนบนหน้าจอ
///
/// แอพยังรันอยู่เบื้องหลังเพราะมีการติดตามตำแหน่ง
/// (Android = Foreground Service, iOS = Background Location)
/// จึงเล่นเสียงและสั่งสั่นจากฝั่ง Dart ได้โดยตรง
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _alarmNotificationId = 1001;
  static const _channelId = 'arrivedwake_ring';

  final _notifications = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer();
  Timer? _vibrationTimer;
  bool _ringing = false;

  /// ถูกเรียกเมื่อผู้ใช้แตะแจ้งเตือนปลุก
  VoidCallback? onNotificationTap;

  bool get isRinging => _ringing;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
    );

    // ตั้งค่าเสียงให้เป็นแบบ "นาฬิกาปลุก"
    // Android: ใช้ระดับเสียง alarm (ดังแม้เปิดโหมดเงียบของเสียงแจ้งเตือน)
    // iOS: category playback = ดังแม้สวิตช์ปิดเสียงด้านข้าง
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransient,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestFullScreenIntentPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: false);
  }

  Future<void> ring({
    required AlarmMode mode,
    required String destinationName,
  }) async {
    if (_ringing) return;
    _ringing = true;

    await _showNotification(mode, destinationName);

    if (mode.hasSound) {
      try {
        await _player.play(AssetSource('sounds/alarm.wav'), volume: 1.0);
      } catch (e) {
        debugPrint('เล่นเสียงไม่ได้: $e');
      }
    }

    if (mode.hasVibration && (await Vibration.hasVibrator())) {
      // สั่นซ้ำทุก 1.2 วินาทีจนกว่าจะกดหยุด (ใช้ได้ทั้ง Android และ iOS)
      unawaited(Vibration.vibrate(duration: 800));
      _vibrationTimer = Timer.periodic(
        const Duration(milliseconds: 1200),
        (_) => Vibration.vibrate(duration: 800),
      );
    }
  }

  Future<void> stop() async {
    _ringing = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    await Vibration.cancel();
    await _player.stop();
    await _notifications.cancel(id: _alarmNotificationId);
  }

  Future<void> _showNotification(AlarmMode mode, String name) {
    final android = AndroidNotificationDetails(
      _channelId,
      'ปลุกเมื่อถึงจุดหมาย',
      channelDescription: 'แจ้งเตือนเมื่อใกล้ถึงจุดหมาย',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true, // เด้งหน้าจอขึ้นมาแม้ล็อกจออยู่
      ongoing: true,
      autoCancel: false,
      // เสียงและการสั่นจัดการเองใน Dart เพื่อให้ตรงกับโหมดที่เลือก
      playSound: false,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      // สำรองไว้: ถ้าเล่นเสียงจากแอพไม่ได้ อย่างน้อยจะมีเสียงแจ้งเตือนของระบบ
      presentSound: mode.hasSound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return _notifications.show(
      id: _alarmNotificationId,
      title: 'ใกล้ถึงแล้ว!',
      body: 'ใกล้ถึง $name แล้ว แตะเพื่อปิดเสียงปลุก',
      notificationDetails: NotificationDetails(android: android, iOS: ios),
    );
  }
}
