/// รูปแบบการปลุก
enum AlarmMode {
  sound('เสียง'),
  vibrate('สั่น'),
  both('เสียง + สั่น');

  const AlarmMode(this.label);
  final String label;

  bool get hasSound => this == sound || this == both;
  bool get hasVibration => this == vibrate || this == both;
}

/// จุดหมายที่ปักหมุด / บันทึกไว้
class Destination {
  Destination({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500,
    this.mode = AlarmMode.both,
  });

  String name;
  double latitude;
  double longitude;
  double radiusMeters;
  AlarmMode mode;

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'mode': mode.name,
      };

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        name: json['name'] as String? ?? 'จุดหมาย',
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        radiusMeters: (json['radius'] as num?)?.toDouble() ?? 500,
        mode: AlarmMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => AlarmMode.both,
        ),
      );
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} ม.';
  final km = (meters / 1000).toStringAsFixed(meters < 10000 ? 2 : 1);
  // ตัดศูนย์ท้าย: 1.00 -> 1, 1.50 -> 1.5
  return '${km.replaceFirst(RegExp(r'\.?0+$'), '')} กม.';
}
