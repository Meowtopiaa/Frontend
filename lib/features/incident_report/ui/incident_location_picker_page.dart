import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_model.dart';
import '../logic/incident_location_helper.dart';

/// Koreksi pin manual (EIR-03). Ketuk peta untuk memindahkan pin.
/// Mengembalikan [IncidentLocation] lewat `Navigator.pop`.
class IncidentLocationPickerPage extends StatefulWidget {
  const IncidentLocationPickerPage({super.key, this.initial});
  final IncidentLocation? initial;

  @override
  State<IncidentLocationPickerPage> createState() =>
      _IncidentLocationPickerPageState();
}

class _IncidentLocationPickerPageState
    extends State<IncidentLocationPickerPage> {
  final MapController _map = MapController();
  late LatLng _pin;
  bool _fromGps = false;
  double? _accuracy;
  bool _locating = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    final initInside = init != null &&
        IncidentLocationHelper.isInsideCampus(init.lat, init.lng);
    _pin = initInside
        ? LatLng(init.lat, init.lng)
        : const LatLng(
            IncidentLocationHelper.campusLat,
            IncidentLocationHelper.campusLng,
          );
    _fromGps = initInside && init.fromGps;
    _accuracy = initInside ? init.accuracyM : null;
  }

  /// Hanya titik di dalam kampus Telkom University Bandung yang diterima.
  void _onMapTap(LatLng point) {
    if (!IncidentLocationHelper.isInsideCampus(
        point.latitude, point.longitude)) {
      setState(() => _gpsError = IncidentLocationHelper.outsideCampusMessage);
      return;
    }
    setState(() {
      _pin = point;
      _fromGps = false; // pin dikoreksi manual
      _accuracy = null;
      _gpsError = null;
    });
  }

  /// Area luar kampus diarsir (poligon dunia dengan lubang berbentuk kampus).
  static final List<Polygon> _campusOverlay = () {
    final view = IncidentLocationHelper.campusViewBounds;
    const pad = 0.05;
    return [
      Polygon(
        points: [
          LatLng(view.north + pad, view.west - pad),
          LatLng(view.north + pad, view.east + pad),
          LatLng(view.south - pad, view.east + pad),
          LatLng(view.south - pad, view.west - pad),
        ],
        holePointsList: [IncidentLocationHelper.campusBoundary],
        color: Colors.black.withValues(alpha: 0.28),
        borderStrokeWidth: 0,
      ),
      Polygon(
        points: IncidentLocationHelper.campusBoundary,
        color: Colors.transparent,
        borderColor: MeowStyle.orange,
        borderStrokeWidth: 3,
      ),
    ];
  }();

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    final res = await IncidentLocationHelper.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.location != null) {
        _pin = LatLng(res.location!.lat, res.location!.lng);
        _fromGps = true;
        _accuracy = res.location!.accuracyM;
        _map.move(_pin, 18);
      } else {
        _gpsError = res.error;
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      IncidentLocation(
        lat: _pin.latitude,
        lng: _pin.longitude,
        accuracyM: _fromGps ? _accuracy : null,
        fromGps: _fromGps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentukan Lokasi')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _pin,
              initialZoom: 17,
              minZoom: 15,
              // Titik tengah peta dikunci di sekitar kampus. Memakai containCenter
              // (bukan contain) agar tetap bisa digeser di layar lebar/desktop.
              cameraConstraint: CameraConstraint.containCenter(
                bounds: IncidentLocationHelper.campusViewBounds,
              ),
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.meowtopia.meowtopia',
              ),
              // Hanya tampilan: poligon tidak boleh menangkap ketukan/geseran,
              // agar ketukan diteruskan ke peta untuk memindahkan pin.
              IgnorePointer(child: PolygonLayer(polygons: _campusOverlay)),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pin,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: MeowStyle.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                _gpsError ??
                    'Ketuk di dalam garis oranye (kampus Telkom University) '
                        'untuk memindahkan pin ke lokasi kucing. '
                        '${_fromGps ? 'Sumber: GPS' : 'Sumber: pin manual'}'
                        '${_accuracy != null ? ' (±${_accuracy!.round()} m)' : ''}',
                style: TextStyle(
                  color: _gpsError != null ? MeowStyle.danger : MeowStyle.ink,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MeowButton(
                label: 'Gunakan Lokasi GPS Saya',
                icon: Icons.my_location_rounded,
                secondary: true,
                busy: _locating,
                onPressed: _useGps,
              ),
              const SizedBox(height: 10),
              MeowButton(
                label: 'Pakai Lokasi Ini',
                icon: Icons.check_rounded,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
