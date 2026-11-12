import 'package:destination_alarm/models/destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDistance แสดงเมตร/กิโลเมตร', () {
    expect(formatDistance(250), '250 ม.');
    expect(formatDistance(1000), '1 กม.');
    expect(formatDistance(1500), '1.5 กม.');
    expect(formatDistance(2345), '2.35 กม.');
    expect(formatDistance(12345), '12.3 กม.');
  });

  test('AlarmMode flags', () {
    expect(AlarmMode.sound.hasSound, isTrue);
    expect(AlarmMode.sound.hasVibration, isFalse);
    expect(AlarmMode.vibrate.hasVibration, isTrue);
    expect(AlarmMode.both.hasSound && AlarmMode.both.hasVibration, isTrue);
  });

  test('Destination JSON round-trip', () {
    final d = Destination(
      name: 'บ้าน',
      latitude: 13.75,
      longitude: 100.5,
      radiusMeters: 800,
      mode: AlarmMode.vibrate,
    );
    final back = Destination.fromJson(d.toJson());
    expect(back.name, 'บ้าน');
    expect(back.radiusMeters, 800);
    expect(back.mode, AlarmMode.vibrate);
  });
}
