import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../models/destination.dart';
import '../services/alarm_service.dart';
import '../services/geocoding_service.dart';
import '../services/storage_service.dart';
import '../services/tracking_service.dart';
import 'alarm_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.tracking});

  final TrackingService tracking;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _defaultCenter = LatLng(13.7563, 100.5018); // กรุงเทพฯ
  static const _radiusPresets = <double>[100, 200, 500, 1000, 2000, 5000];

  final _map = MapController();
  final _storage = StorageService();
  final _geocoding = GeocodingService();
  final _searchCtrl = TextEditingController();

  List<Destination> _saved = [];
  List<PlaceResult> _results = [];
  bool _searching = false;
  bool _alarmScreenOpen = false;
  int _lastRingCount = 0;

  TrackingService get _t => widget.tracking;

  @override
  void initState() {
    super.initState();
    _t.addListener(_onTrackingChanged);
    AlarmService.instance.onNotificationTap = _openAlarmScreen;
    _storage.loadSaved().then((v) => setState(() => _saved = v));
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _t.removeListener(_onTrackingChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final res = await _t.ensurePermission();
    if (!mounted) return;
    if (res != PermissionResult.granted) {
      _showPermissionHelp(res);
      return;
    }
    await AlarmService.instance.requestPermissions();
    final p = await _t.currentPosition();
    if (p != null && mounted) {
      _map.move(LatLng(p.latitude, p.longitude), 15);
    }
  }

  void _onTrackingChanged() {
    if (_t.ringCount != _lastRingCount) {
      _lastRingCount = _t.ringCount;
      _openAlarmScreen();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openAlarmScreen() async {
    if (_alarmScreenOpen || !AlarmService.instance.isRinging || !mounted) return;
    _alarmScreenOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AlarmScreen(tracking: _t),
      ),
    );
    _alarmScreenOpen = false;
  }

  // ---------- ปักหมุด / ค้นหา ----------

  void _pin(LatLng point, {String? name}) {
    final old = _t.target;
    _t.setTarget(Destination(
      name: name ?? 'จุดหมาย (${point.latitude.toStringAsFixed(4)}, '
          '${point.longitude.toStringAsFixed(4)})',
      latitude: point.latitude,
      longitude: point.longitude,
      radiusMeters: old?.radiusMeters ?? 500,
      mode: old?.mode ?? AlarmMode.both,
    ));
  }

  Timer? _debounce;
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await _geocoding.search(q);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(PlaceResult r) {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() => _results = []);
    _pin(r.point, name: r.name.split(',').first);
    _map.move(r.point, 15);
  }

  // ---------- บันทึกหมุด ----------

  Future<void> _saveCurrent() async {
    final t = _t.target;
    if (t == null) return;
    final ctrl = TextEditingController(text: t.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('บันทึกหมุด'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ชื่อ เช่น บ้าน, ที่ทำงาน'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    t.name = name;
    final copy = Destination.fromJson(t.toJson());
    setState(() => _saved = [..._saved, copy]);
    await _storage.saveAll(_saved);
    _t.targetChanged();
    _snack('บันทึก "$name" แล้ว');
  }

  void _openSaved() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (_saved.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Text('ยังไม่มีหมุดที่บันทึกไว้'),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < _saved.length; i++)
                ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(_saved[i].name),
                  subtitle: Text(
                    'ระยะปลุก ${formatDistance(_saved[i].radiusMeters)} · ${_saved[i].mode.label}',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final d = Destination.fromJson(_saved[i].toJson());
                    _t.setTarget(d);
                    _map.move(LatLng(d.latitude, d.longitude), 15);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      setState(() => _saved = [..._saved]..removeAt(i));
                      setSheet(() {});
                      await _storage.saveAll(_saved);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------- เริ่ม / หยุด ----------

  Future<void> _toggleTracking() async {
    if (_t.isTracking) {
      await _t.stop();
      return;
    }
    final res = await _t.ensurePermission();
    if (res != PermissionResult.granted) {
      _showPermissionHelp(res);
      return;
    }
    await _t.start();
    _snack('เริ่มติดตามแล้ว ปิดจอได้เลย จะปลุกเมื่อเหลือ '
        '${formatDistance(_t.target!.radiusMeters)}');
  }

  void _showPermissionHelp(PermissionResult r) {
    final msg = switch (r) {
      PermissionResult.serviceDisabled => 'กรุณาเปิด GPS / Location Services',
      PermissionResult.deniedForever =>
        'แอพต้องใช้สิทธิ์ตำแหน่ง กรุณาเปิดในการตั้งค่า (iOS: เลือก "ตลอดเวลา")',
      _ => 'แอพต้องใช้สิทธิ์ตำแหน่งเพื่อปลุกเมื่อใกล้ถึง',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: 'ตั้งค่า',
        onPressed: () => r == PermissionResult.serviceDisabled
            ? Geolocator.openLocationSettings()
            : Geolocator.openAppSettings(),
      ),
    ));
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = _t.target;
    final pos = _t.position;
    final targetPoint =
        target == null ? null : LatLng(target.latitude, target.longitude);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 12,
              onTap: (_, p) {
                if (_t.isTracking) {
                  _snack('หยุดติดตามก่อนจึงจะย้ายหมุดได้');
                  return;
                }
                _pin(p);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.destination_alarm',
              ),
              if (targetPoint != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: targetPoint,
                    radius: target!.radiusMeters,
                    useRadiusInMeter: true,
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderColor: scheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (pos != null)
                  Marker(
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                      ),
                    ),
                  ),
                if (targetPoint != null)
                  Marker(
                    point: targetPoint,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on, size: 44, color: scheme.error),
                  ),
              ]),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          SafeArea(child: _buildSearchBar(scheme)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'saved',
              tooltip: 'หมุดที่บันทึกไว้',
              onPressed: _openSaved,
              child: const Icon(Icons.bookmarks_outlined),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'me',
              tooltip: 'ตำแหน่งของฉัน',
              onPressed: () async {
                final p = await _t.currentPosition();
                if (p != null) _map.move(LatLng(p.latitude, p.longitude), 16);
              },
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildPanel(scheme),
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(28),
            color: scheme.surface,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ค้นหาสถานที่ หรือแตะแผนที่เพื่อปักหมุด',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final r in _results)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectResult(r),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel(ColorScheme scheme) {
    final target = _t.target;
    final text = Theme.of(context).textTheme;

    if (target == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: scheme.primary),
              const SizedBox(width: 12),
              const Expanded(child: Text('แตะบนแผนที่เพื่อปักหมุดจุดหมาย')),
            ],
          ),
        ),
      );
    }

    final distance = _t.distanceMeters;
    final locked = _t.isTracking;

    return Material(
      elevation: 8,
      color: scheme.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      target.name,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'บันทึกหมุด',
                    icon: const Icon(Icons.bookmark_add_outlined),
                    onPressed: _saveCurrent,
                  ),
                ],
              ),
              Text(
                distance == null
                    ? 'กำลังหาตำแหน่งปัจจุบัน…'
                    : 'ห่างจากจุดหมาย ${formatDistance(distance)}',
                style: text.bodyLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 12),
              Text('ปลุกเมื่อเหลือระยะ ${formatDistance(target.radiusMeters)}',
                  style: text.labelLarge),
              Slider(
                min: 50,
                max: 5000,
                divisions: 99,
                value: target.radiusMeters.clamp(50, 5000),
                label: formatDistance(target.radiusMeters),
                onChanged: (v) {
                  target.radiusMeters = v.roundToDouble();
                  _t.targetChanged();
                },
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final r in _radiusPresets)
                    ChoiceChip(
                      label: Text(formatDistance(r)),
                      selected: target.radiusMeters == r,
                      onSelected: (_) {
                        target.radiusMeters = r;
                        _t.targetChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('รูปแบบการปลุก', style: text.labelLarge),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AlarmMode>(
                  segments: const [
                    ButtonSegment(
                      value: AlarmMode.sound,
                      icon: Icon(Icons.volume_up),
                      label: Text('เสียง'),
                    ),
                    ButtonSegment(
                      value: AlarmMode.vibrate,
                      icon: Icon(Icons.vibration),
                      label: Text('สั่น'),
                    ),
                    ButtonSegment(
                      value: AlarmMode.both,
                      icon: Icon(Icons.notifications_active),
                      label: Text('ทั้งคู่'),
                    ),
                  ],
                  selected: {target.mode},
                  onSelectionChanged: (s) {
                    target.mode = s.first;
                    _t.targetChanged();
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: locked
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        )
                      : null,
                  icon: Icon(locked ? Icons.stop : Icons.play_arrow),
                  label: Text(locked ? 'หยุดติดตาม' : 'เริ่มติดตาม'),
                  onPressed: _toggleTracking,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
