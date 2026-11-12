import 'package:material_ui/material_ui.dart';

import '../models/destination.dart';
import '../services/tracking_service.dart';

/// หน้าจอปลุกเต็มจอ พร้อมปุ่มหยุดและเลื่อนปลุก
class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key, required this.tracking});

  final TrackingService tracking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = tracking.target;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.errorContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.alarm_on, size: 120, color: scheme.onErrorContainer),
                const SizedBox(height: 24),
                Text(
                  'ใกล้ถึงแล้ว!',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  target?.name ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
                ListenableBuilder(
                  listenable: tracking,
                  builder: (context, _) {
                    final d = tracking.distanceMeters;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        d == null ? '' : 'อีก ${formatDistance(d)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('หยุดปลุก'),
                    onPressed: () async {
                      await tracking.dismissAlarm();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.snooze),
                    label: const Text('เลื่อนปลุก 1 นาที'),
                    onPressed: () async {
                      await tracking.snooze(const Duration(minutes: 1));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
