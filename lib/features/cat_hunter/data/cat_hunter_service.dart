import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../cat_dex/data/models/cat_model.dart';
import '../map_territory/models/territory_model.dart';
import 'cat_hunter_model.dart';

class CatHunterService {
  final ApiClient _client;
  final Uuid _uuid;

  CatHunterService({ApiClient? client, Uuid? uuid})
      : _client = client ?? ApiClient(),
        _uuid = uuid ?? const Uuid();

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return body;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _extractDataList(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    } else if (body is List) {
      return body;
    }
    return const <dynamic>[];
  }

  Never _rethrowApiError(Object error) {
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) {
        throw inner;
      }
      throw ApiException(
        message: error.message ?? 'Koneksi ke server bermasalah.',
        statusCode: error.response?.statusCode,
      );
    }
    if (error is ApiException) {
      throw error;
    }
    throw ApiException(message: error.toString());
  }

  /// 1. GET /api/v1/cat-hunter/cats
  Future<List<CatModel>> getCats() async {
    try {
      final response = await _client.get('/cat-hunter/cats');
      final list = _extractDataList(response.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(CatModel.fromJson)
          .toList();
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 2. POST /api/v1/cat-hunter/cats/{cat}/scan-check
  Future<ScanCheckResult> scanCheck(String catId, {String? code}) async {
    try {
      final body = <String, dynamic>{};
      if (code != null && code.trim().isNotEmpty) {
        body['code'] = code.trim();
      }
      final response = await _client.post(
        '/cat-hunter/cats/$catId/scan-check',
        data: body.isEmpty ? null : body,
      );
      final data = _extractDataMap(response.data);
      final message = response.data is Map<String, dynamic>
          ? (response.data['message']?.toString() ?? '')
          : '';
      return ScanCheckResult.fromJson(data, message: message);
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 3. POST /api/v1/cat-hunter/cats/{cat}/encounters
  Future<EncounterResult> completeEncounter(
    String catId, {
    int phasesCompleted = 2,
  }) async {
    try {
      final response = await _client.post(
        '/cat-hunter/cats/$catId/encounters',
        data: {'phases_completed': phasesCompleted},
        headers: {'Idempotency-Key': _uuid.v4()},
      );
      return EncounterResult.fromJson(_extractDataMap(response.data));
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 4. PATCH /api/v1/cat-hunter/cats/{cat}/name
  Future<CatModel> renameCat(String catId, String name) async {
    try {
      final response = await _client.patch(
        '/cat-hunter/cats/$catId/name',
        data: {'name': name},
        headers: {'Idempotency-Key': _uuid.v4()},
      );
      return CatModel.fromJson(_extractDataMap(response.data));
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 5. GET /api/v1/cat-hunter/zones
  Future<List<TerritoryModel>> getZones() async {
    try {
      final response = await _client.get('/cat-hunter/zones');
      final list = _extractDataList(response.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(TerritoryModel.fromJson)
          .toList();
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 6. GET /api/v1/cat-hunter/profile
  Future<CatHunterProfileModel> getProfile() async {
    try {
      final response = await _client.get('/cat-hunter/profile');
      return CatHunterProfileModel.fromJson(_extractDataMap(response.data));
    } catch (e) {
      _rethrowApiError(e);
    }
  }

  /// 7. PATCH /api/v1/cat-hunter/profile/avatar
  Future<CatModel> setFavoriteAvatar(String catId) async {
    try {
      final response = await _client.patch(
        '/cat-hunter/profile/avatar',
        data: {'cat_id': catId},
        headers: {'Idempotency-Key': _uuid.v4()},
      );
      return CatModel.fromJson(_extractDataMap(response.data));
    } catch (e) {
      _rethrowApiError(e);
    }
  }
}
