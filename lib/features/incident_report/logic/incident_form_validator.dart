import '../data/incident_model.dart';
import 'incident_location_helper.dart';

/// Validasi form insiden di klien. Server tetap memvalidasi ulang (EIR-03).
class IncidentFormValidator {
  static const int maxMedia = 5; // OQ-11: opsional, maksimal 5 berkas
  static const int minDescription = 10;
  static const int maxDescription = 1000;
  static const int maxLocationNote = 255;

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Deskripsi kondisi wajib diisi.';
    if (text.length < minDescription) {
      return 'Deskripsi minimal $minDescription karakter.';
    }
    if (text.length > maxDescription) {
      return 'Deskripsi maksimal $maxDescription karakter.';
    }
    return null;
  }

  static String? location(IncidentLocation? value) {
    if (value == null) {
      return 'Tentukan lokasi lewat GPS atau pilih pin di peta.';
    }
    if (!value.isValid) return 'Koordinat lokasi tidak valid.';
    if (!IncidentLocationHelper.isInsideCampus(value.lat, value.lng)) {
      return IncidentLocationHelper.outsideCampusMessage;
    }
    return null;
  }

  static String? locationNote(String? value) {
    if ((value?.trim().length ?? 0) > maxLocationNote) {
      return 'Patokan lokasi maksimal $maxLocationNote karakter.';
    }
    return null;
  }

  static String? mediaCount(int count) =>
      count > maxMedia ? 'Maksimal $maxMedia foto atau video.' : null;

  static String? statusNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Catatan wajib diisi untuk riwayat tiket.';
    if (text.length > maxDescription) {
      return 'Catatan maksimal $maxDescription karakter.';
    }
    return null;
  }

  /// Mengembalikan peta field → pesan; kosong bila valid.
  static Map<String, String> validate({
    required String description,
    required IncidentLocation? location,
    String? locationNote,
    int mediaCount = 0,
  }) {
    final errors = <String, String>{};
    void put(String key, String? msg) {
      if (msg != null) errors[key] = msg;
    }

    put('description', IncidentFormValidator.description(description));
    put('location', IncidentFormValidator.location(location));
    put('location_note', IncidentFormValidator.locationNote(locationNote));
    put('media_ids', IncidentFormValidator.mediaCount(mediaCount));
    return errors;
  }
}
