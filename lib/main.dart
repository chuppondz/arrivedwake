import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'services/alarm_service.dart';
import 'services/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.instance.init();
  final tracking = TrackingService(AlarmService.instance);
  runApp(ArrivedWakeApp(tracking: tracking));
}

class ArrivedWakeApp extends StatelessWidget {
  const ArrivedWakeApp({super.key, required this.tracking});

  final TrackingService tracking;

  @override
  Widget build(BuildContext context) {
    final seed = Colors.teal;
    return MaterialApp(
      title: 'ArrivedWake',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeScreen(tracking: tracking),
    );
  }
}
