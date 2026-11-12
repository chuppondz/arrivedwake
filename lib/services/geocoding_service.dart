import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  PlaceResult(this.name, this.point);
  final String name;
  final LatLng point;
}

/// ค้นหาสถานที่ด้วย OpenStreetMap Nominatim (ฟรี ไม่ต้องใช้ API key)
///
/// นโยบายการใช้งาน: ไม่เกิน 1 request/วินาที และต้องระบุ User-Agent ของแอพ
/// ถ้าจะขึ้น production ที่มีผู้ใช้เยอะ ควรเปลี่ยนไปใช้ Google Places / Mapbox
/// หรือเซิร์ฟเวอร์ Nominatim ของตัวเอง
class GeocodingService {
  static const _userAgent = 'arrivedwake/1.0 (com.arrivedwake.app)';

  Future<List<PlaceResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '8',
      'accept-language': 'th,en',
    });
    final res = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (res.statusCode != 200) {
      throw Exception('ค้นหาไม่สำเร็จ (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return PlaceResult(
        m['display_name'] as String,
        LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
      );
    }).toList();
  }
}
