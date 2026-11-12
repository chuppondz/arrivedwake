import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';

/// บันทึกหมุดที่ใช้บ่อย (บ้าน, ที่ทำงาน ฯลฯ) ลงในเครื่อง
class StorageService {
  static const _savedKey = 'saved_destinations';

  Future<List<Destination>> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Destination.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<Destination> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
