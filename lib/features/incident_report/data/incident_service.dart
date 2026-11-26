import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'incident_enums.dart';
import 'incident_model.dart';
import 'incident_repository.dart';

/// Implementasi REST kontrak insiden (PRD §8.7) lewat `ApiClient` Core.
/// Respons selalu berbentuk `{ success, message, data, meta? }`.
class IncidentService implements IncidentRepository {
  IncidentService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Map<String, dynamic> _data(Response response) {
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    throw const IncidentFailure('Respons server tidak sesuai format.');
  }

  List<Map<String, dynamic>> _list(Response response) {
    final body = response.data;
    final list = body is Map ? body['data'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw IncidentFailure.from(e);
    }
  }

  @override
  Future<String> uploadMedia(Uint8List bytes, {required String filename}) =>
      _guard(() async {
        final form = FormData.fromMap({
          'purpose': 'incident_media',
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        });
        final response = await _client.post(
          '/media',
          data: form,
          headers: {'Content-Type': 'multipart/form-data'},
        );
        final id = _data(response)['id']?.toString() ?? '';
        if (id.isEmpty) {
          throw const IncidentFailure('Gagal mengunggah media laporan.');
        }
        return id;
      });

  @override
  Future<IncidentReportModel> createIncident(
    IncidentDraft draft, {
    required String idempotencyKey,
  }) =>
      _guard(() async {
        final response = await _client.post(
          '/incidents',
          data: draft.toJson(),
          headers: {'Idempotency-Key': idempotencyKey},
        );
        final created = IncidentReportModel.fromJson(_data(response));
        // EIR-04: sukses hanya bila server benar-benar mengembalikan tiket.
        if (created.ticketCode.isEmpty ||
            created.status != IncidentStatus.received) {
          throw const IncidentFailure(
            'Server tidak mengonfirmasi tiket. Laporan belum dianggap tersimpan.',
          );
        }
        return created;
      });

  @override
  Future<List<IncidentReportModel>> getMyIncidents() => _guard(() async {
        final response = await _client.get('/incidents/mine');
        return _list(response).map(IncidentReportModel.fromJson).toList();
      });

  @override
  Future<IncidentReportModel> getIncident(String id) => _guard(() async {
        final response = await _client.get('/incidents/$id');
        return IncidentReportModel.fromJson(_data(response));
      });

  @override
  Future<List<CaretakerTask>> getCaretakerTasks() => _guard(() async {
        final response = await _client.get('/caretaker/tasks');
        return _list(response).map(CaretakerTask.fromJson).toList();
      });

  @override
  Future<CaretakerTask> acceptTask(String taskId) => _guard(() async {
        final response =
            await _client.post('/caretaker/tasks/$taskId/accept');
        return CaretakerTask.fromJson(_data(response));
      });

  @override
  Future<void> declineTask(String taskId, {String? reason}) =>
      _guard(() async {
        await _client.post(
          '/caretaker/tasks/$taskId/decline',
          data: {
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          },
        );
      });

  @override
  Future<IncidentReportModel> updateStatus(
    String incidentId, {
    required IncidentStatus toStatus,
    required String note,
    required String idempotencyKey,
  }) =>
      _guard(() async {
        final response = await _client.post(
          '/incidents/$incidentId/status',
          data: {'status': toStatus.code, 'note': note.trim()},
          headers: {'Idempotency-Key': idempotencyKey},
        );
        return IncidentReportModel.fromJson(_data(response));
      });

  @override
  Future<List<VetContact>> getVets() => _guard(() async {
        final response = await _client.get('/vets');
        return _list(response).map(VetContact.fromJson).toList();
      });
}
