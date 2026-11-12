# ปลุกเมื่อใกล้ถึง (destination_alarm)

แอพ Flutter (Android + iOS) สำหรับปักหมุดจุดหมาย แล้วให้มือถือปลุกเมื่อเข้าใกล้ในระยะที่ตั้งไว้

## ฟีเจอร์
- แผนที่ OpenStreetMap: แตะเพื่อปักหมุด หรือค้นหาสถานที่ (ไม่ต้องใช้ API key)
- ตั้งระยะปลุกได้ 50 ม. – 5 กม. (มีปุ่มลัด 100 ม. / 200 ม. / 500 ม. / 1 กม. / 2 กม. / 5 กม.) และวาดวงรัศมีบนแผนที่
- โหมดปลุก: **เสียง / สั่น / เสียง + สั่น**
- ติดตามตำแหน่งต่อได้ตอนจอดับ (Android ใช้ Foreground Service, iOS ใช้ Background Location)
- หน้าจอปลุกเต็มจอ มีปุ่ม "หยุดปลุก" และ "เลื่อนปลุก 1 นาที"
- บันทึกหมุดที่ใช้บ่อยไว้ในเครื่อง

## วิธีรัน
```bash
flutter pub get
flutter run            # เสียบมือถือจริง (GPS ใน emulator ต้องจำลองเอง)
```
- iOS: ต้องใช้ Mac + Xcode เปิด `ios/Runner.xcworkspace` แล้วตั้ง Signing Team ก่อน
- ทดสอบใน emulator: Android Studio → Extended controls → Location → Routes, หรือ Xcode → Debug → Simulate Location

## โครงสร้างโค้ด
| ไฟล์ | หน้าที่ |
|---|---|
| `lib/main.dart` | จุดเริ่มแอพ |
| `lib/models/destination.dart` | โมเดลจุดหมาย, โหมดปลุก |
| `lib/services/tracking_service.dart` | ติดตาม GPS, คำนวณระยะ, สั่งปลุกเมื่อเข้ารัศมี |
| `lib/services/alarm_service.dart` | เสียงปลุก (loop), สั่น, แจ้งเตือนเต็มจอ |
| `lib/services/geocoding_service.dart` | ค้นหาสถานที่ (Nominatim) |
| `lib/services/storage_service.dart` | บันทึกหมุด |
| `lib/screens/home_screen.dart` | แผนที่ + แผงตั้งค่า |
| `lib/screens/alarm_screen.dart` | หน้าจอปลุก |
| `assets/sounds/alarm.wav` | เสียงปลุก (เปลี่ยนเป็นไฟล์ของคุณเองได้) |

## ข้อควรรู้ก่อนขึ้น Store
- **iOS + โหมดเงียบ**: เสียงจะเล่นผ่าน audio session แบบ playback ซึ่งดังแม้เปิดสวิตช์เงียบ ถ้าอยากให้ปลุกได้ชัวร์ระดับนาฬิกาปลุกจริง ให้เพิ่ม **AlarmKit** (iOS 26+) ผ่าน platform channel
- **iOS Time Sensitive**: เปิด capability "Time Sensitive Notifications" ใน Xcode ด้วย เพื่อให้แจ้งเตือนทะลุโหมด Focus
- **Android 14+**: Google Play อนุญาตสิทธิ์ `USE_FULL_SCREEN_INTENT` แค่กับแอพนาฬิกาปลุก/โทรศัพท์ ต้องกรอกแบบฟอร์มประกาศตอนส่งแอพ (แอพนี้เข้าข่ายนาฬิกาปลุก)
- **Android Foreground Service (location)**: ต้องกรอก declaration ใน Play Console และแนบวิดีโออธิบายการใช้งาน
- **แผนที่/ค้นหา**: tile และ Nominatim ของ OSM ห้ามใช้หนักใน production ควรเปลี่ยนไปใช้ผู้ให้บริการ tile (MapTiler, Stadia, Mapbox) หรือ Google Maps
- เปลี่ยน `com.example.destination_alarm` เป็น bundle id ของคุณเอง
- แบตเตอรี่: ตอนนี้ใช้ GPS ความแม่นยำสูง + `distanceFilter` 15 ม. ถ้าจุดหมายยังไกลมาก ปรับให้ใช้ความแม่นยำต่ำก่อนแล้วค่อยเพิ่มเมื่อใกล้ จะประหยัดแบตขึ้นมาก
