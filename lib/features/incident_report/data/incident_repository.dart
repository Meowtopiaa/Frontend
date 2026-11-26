import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'incident_enums.dart';
import 'incident_model.dart';

/// Kontrak data modul insiden (PRD §8.7). Implementasi:
/// [IncidentService] (REST `/api/v1`) dan [DemoIncidentRepository] (lokal).
abstract class IncidentRepository {
  /// `POST /media` — mengembalikan media_id.
  Future<String> uploadMedia(Uint8List bytes, {required String filename});

  /// `POST /incidents` † — respons 201 berisi ticket_code dan status RECEIVED.
  Future<IncidentReportModel> createIncident(
    IncidentDraft draft, {
    required String idempotencyKey,
  });

  /// `GET /incidents/mine`
  Future<List<IncidentReportModel>> getMyIncidents();

  /// `GET /incidents/{id}` — detail beserta riwayat status.
  Future<IncidentReportModel> getIncident(String id);

  /// `GET /caretaker/tasks`
  Future<List<CaretakerTask>> getCaretakerTasks();

  /// `POST /caretaker/tasks/{id}/accept`
  Future<CaretakerTask> acceptTask(String taskId);

  /// `POST /caretaker/tasks/{id}/decline`
  Future<void> declineTask(String taskId, {String? reason});

  /// `POST /incidents/{id}/status` †
  Future<IncidentReportModel> updateStatus(
    String incidentId, {
    required IncidentStatus toStatus,
    required String note,
    required String idempotencyKey,
  });

  /// `GET /vets`
  Future<List<VetContact>> getVets();
}

/// Kegagalan yang sudah diterjemahkan untuk ditampilkan ke pengguna.
class IncidentFailure implements Exception {
  const IncidentFailure(
    this.message, {
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isForbidden => statusCode == 403 || code == 'FORBIDDEN';
  bool get isConflict => statusCode == 409 || code == 'CONFLICT';
  bool get isNetwork => statusCode == null && code == null;

  factory IncidentFailure.from(Object error) {
    if (error is IncidentFailure) return error;
    ApiException? api;
    if (error is ApiException) api = error;
    if (error is DioException && error.error is ApiException) {
      api = error.error as ApiException;
    }
    if (api != null) {
      final fields = <String, String>{};
      final errs = api.errors;
      if (errs is Map) {
        for (final entry in errs.entries) {
          final value = entry.value;
          fields[entry.key.toString()] = value is List && value.isNotEmpty
              ? value.first.toString()
              : value.toString();
        }
      }
      return IncidentFailure(
        _friendly(api.statusCode, api.code, api.message),
        code: api.code,
        statusCode: api.statusCode,
        fieldErrors: fields,
      );
    }
    if (error is DioException) {
      return const IncidentFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      );
    }
    return IncidentFailure(error.toString());
  }

  static String _friendly(int? status, String? code, String message) {
    if (status == 401) return 'Sesi berakhir. Silakan masuk kembali.';
    if (code == 'EMAIL_NOT_VERIFIED') {
      return 'Verifikasi email terlebih dahulu untuk membuat laporan.';
    }
    if (status == 403 || code == 'FORBIDDEN') {
      return 'Akses ditolak. Anda tidak memiliki izin untuk tindakan ini.';
    }
    if (status == 404) return 'Data tidak ditemukan atau tidak dapat diakses.';
    if (status == 409 || code == 'CONFLICT') {
      return message.isNotEmpty
          ? message
          : 'Status tiket sudah berubah. Muat ulang lalu coba lagi.';
    }
    if (status == 429 || code == 'RATE_LIMITED') {
      return 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.';
    }
    if (status != null && status >= 500) {
      return 'Server sedang bermasalah. Laporan belum tersimpan, coba lagi.';
    }
    return message.isNotEmpty ? message : 'Terjadi kesalahan.';
  }

  @override
  String toString() => message;
}
