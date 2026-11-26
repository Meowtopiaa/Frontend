import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/incident_model.dart';
import 'campus_boundary.dart';

/// Hasil pengambilan lokasi GPS untuk form insiden (EIR-03).
class GpsResult {
  const GpsResult.ok(IncidentLocation this.location) : error = null;
  const GpsResult.fail(String this.error) : location = null;

  final IncidentLocation? location;
  final String? error;
}

/// Lokasi GPS diminta hanya saat pengguna menekan tombol (bukan latar
/// belakang, §4.6). Bila izin ditolak, pengguna tetap bisa memilih pin manual.
class IncidentLocationHelper {
  /// Titik tengah awal peta: kampus Telkom University.
  static const double campusLat = -6.97319;
  static const double campusLng = 107.63044;

  static const String outsideCampusMessage =
      'Lokasi berada di luar kampus Telkom University Bandung. '
      'Laporan insiden hanya untuk area kampus.';

  /// Poligon batas kampus Telkom University Bandung.
  static List<LatLng> get campusBoundary => CampusBoundary.points;

  /// Area peta yang boleh dijelajahi: batas kampus ditambah sedikit margin.
  static LatLngBounds get campusViewBounds {
    final b = LatLngBounds.fromPoints(campusBoundary);
    const pad = 0.002; // ~200 m
    return LatLngBounds(
      LatLng(b.south - pad, b.west - pad),
      LatLng(b.north + pad, b.east + pad),
    );
  }

  static bool isInsideCampus(double lat, double lng) =>
      CampusBoundary.contains(LatLng(lat, lng));

  static Future<GpsResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GpsResult.fail(
          'Layanan lokasi mati. Aktifkan GPS atau pilih lokasi lewat peta.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const GpsResult.fail(
          'Izin lokasi ditolak. Anda tetap bisa memilih lokasi lewat peta.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const GpsResult.fail(
          'Izin lokasi diblokir di pengaturan. Pilih lokasi lewat peta.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!isInsideCampus(pos.latitude, pos.longitude)) {
        return const GpsResult.fail(
          '$outsideCampusMessage Pindahkan pin ke lokasi kucing di peta.',
        );
      }
      return GpsResult.ok(
        IncidentLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracyM: pos.accuracy,
          fromGps: true,
        ),
      );
    } catch (_) {
      return const GpsResult.fail(
        'Lokasi GPS tidak dapat diambil. Coba lagi atau pilih lewat peta.',
      );
    }
  }
}
