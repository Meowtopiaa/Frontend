import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'adoption_constants.dart';
import 'adoption_enums.dart';
import 'adoption_model.dart';
import 'mock_adoption_repository.dart';
import 'my_adoption_model.dart';

/// Sumber data Kucing Saya (EN-20) dan laporan kendala (EN-23).
abstract class MyAdoptionRepository {
  /// GET /adoption/mine. Adopsi yang masih berjalan (ADP-08).
  Future<List<MyAdoption>> getMyAdoptions();

  /// GET /adoption/applications/mine. Terbaru di urutan pertama.
  Future<List<MyEligibility>> getMyEligibility();

  /// POST /adoption/{id}/issues (ADP-13). [idempotencyKey] dipakai ulang
  /// saat pengguna mengirim ulang isian yang sama.
  Future<AdoptionIssueResult> reportIssue({
    required String adoptionId,
    required AdoptionIssueCategory category,
    required String description,
    required bool requestIncident,
    required String idempotencyKey,
    String? photo,
  });

  /// Lampiran foto hanya bisa dikirim bila sudah ada media_id dari
  /// POST /media (Core). Selama itu belum ada, jalur API tidak menerima foto.
  bool get supportsPhoto;

  /// Halaman lama (detail pengajuan, pengembalian) masih memakai id angka
  /// dan data tiruan, jadi hanya bisa dibuka di mode demo.
  bool get supportsLegacyPages;
}

typedef MyAdoptionGet = Future<Response> Function(
  String path, {
  Map<String, dynamic>? queryParameters,
});

typedef MyAdoptionPost = Future<Response> Function(
  String path, {
  dynamic data,
  Map<String, dynamic>? headers,
});

class ApiMyAdoptionRepository implements MyAdoptionRepository {
  final MyAdoptionGet _get;
  final MyAdoptionPost _post;
  final String _baseUrl;

  /// [get], [post], dan [baseUrl] dapat diganti di tes; bawaannya memakai
  /// ApiClient Core.
  ApiMyAdoptionRepository({
    MyAdoptionGet? get,
    MyAdoptionPost? post,
    String? baseUrl,
  })  : _get = get ?? ApiClient().get,
        _post = post ?? ApiClient().post,
        _baseUrl = baseUrl ?? ApiClient().dio.options.baseUrl;

  /// Foto rujukan kucing lewat route publik modul Cat:
  /// GET /cats/{id}/photos/{mediaId} (hanya foto kucing, bukan data pribadi).
  String? _photoUrl(MyAdoption a) {
    final mediaId = a.catPhotoMediaId;
    if (mediaId == null) return null;
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return '$base/cats/${Uri.encodeComponent(a.catId)}'
        '/photos/${Uri.encodeComponent(mediaId)}';
  }

  @override
  bool get supportsPhoto => false;

  @override
  bool get supportsLegacyPages => false;

  @override
  Future<List<MyEligibility>> getMyEligibility() async {
    final body = await _send(
      () => _get('/adoption/applications/mine'),
      fallback: 'Status kelayakan belum bisa dimuat.',
    );
    final data = body['data'];
    if (data is! List) {
      throw ApiException(message: 'Respons status kelayakan tidak dikenali.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(MyEligibility.tryParse)
        .whereType<MyEligibility>()
        .toList(growable: false);
  }

  @override
  Future<List<MyAdoption>> getMyAdoptions() async {
    final body = await _send(
      () => _get('/adoption/mine'),
      fallback: 'Kucing Saya belum bisa dimuat.',
    );
    final data = body['data'];
    if (data is! List) {
      throw ApiException(message: 'Respons Kucing Saya tidak dikenali.');
    }
    // Server sudah menyaring; aplikasi tetap membuang adopsi yang sudah
    // ditutup atau berstatus tidak dikenal (ADP-08).
    return data
        .whereType<Map<String, dynamic>>()
        .map(MyAdoption.tryParse)
        .whereType<MyAdoption>()
        .where((a) => a.isOpen)
        .map((a) => a.withPhotoUrl(_photoUrl(a)))
        .toList(growable: false);
  }

  @override
  Future<AdoptionIssueResult> reportIssue({
    required String adoptionId,
    required AdoptionIssueCategory category,
    required String description,
    required bool requestIncident,
    required String idempotencyKey,
    String? photo,
  }) async {
    if (photo != null) {
      throw ApiException(
        message: 'Lampiran foto belum bisa dikirim. Kirim laporan tanpa foto.',
      );
    }
    final wantsIncident =
        requestIncident && issueCategoryAllowsIncident(category);
    final body = await _send(
      () => _post(
        '/adoption/${Uri.encodeComponent(adoptionId)}/issues',
        data: {
          'category': category.name,
          'description': description,
          'request_incident': wantsIncident,
        },
        headers: {'Idempotency-Key': idempotencyKey},
      ),
      fallback: 'Laporan kendala belum terkirim. Coba lagi.',
    );
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(message: 'Respons laporan kendala tidak dikenali.');
    }
    return AdoptionIssueResult.fromJson(data, incidentRequested: wantsIncident);
  }

  /// Menjalankan permintaan dan memastikan bentuk { success: true, ... }.
  Future<Map<String, dynamic>> _send(
    Future<Response> Function() request, {
    required String fallback,
  }) async {
    final Response response;
    try {
      response = await request();
    } on DioException catch (e) {
      final error = e.error;
      throw error is ApiException ? error : ApiException(message: fallback);
    }
    final body = response.data;
    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw ApiException(message: fallback);
    }
    return body;
  }
}

/// Data tiruan untuk mode demo. Memakai [MockAdoptionRepository] yang sama
/// dengan provider supaya kucing hasil pengambilan ikut muncul.
class MockMyAdoptionRepository implements MyAdoptionRepository {
  final MockAdoptionRepository _source;
  int _ticketSeq = 0;

  MockMyAdoptionRepository(this._source);

  @override
  bool get supportsPhoto => true;

  @override
  bool get supportsLegacyPages => true;

  @override
  Future<List<MyEligibility>> getMyEligibility() async {
    final apps = await _source.getMyApplications();
    return apps
        .map((a) => MyEligibility(
              id: a.id.toString(),
              status: a.status,
              adminNote: a.adminNotes,
              submittedAt: a.submittedAt,
            ))
        .toList(growable: false);
  }

  @override
  Future<List<MyAdoption>> getMyAdoptions() async {
    final adoptions = await _source.getMyActiveAdoptions();
    final result = <MyAdoption>[];
    for (final a in adoptions.where((a) => !a.isClosedReturned)) {
      result.add(_fromMock(a, await _source.getFollowups(a.id)));
    }
    return result;
  }

  @override
  Future<AdoptionIssueResult> reportIssue({
    required String adoptionId,
    required AdoptionIssueCategory category,
    required String description,
    required bool requestIncident,
    required String idempotencyKey,
    String? photo,
  }) async {
    final id = int.tryParse(adoptionId);
    final adoption =
        id == null ? null : await _source.getActiveAdoptionById(id);
    if (adoption == null) {
      throw ApiException(message: 'Adopsi tidak ditemukan.', statusCode: 404);
    }
    final report = await _source.reportIssue(
      adoptionId: adoption.id,
      catId: adoption.catId,
      category: category,
      description: description,
      photoPath: photo,
    );
    final wantsIncident =
        requestIncident && issueCategoryAllowsIncident(category);
    return AdoptionIssueResult(
      id: report.id,
      status: 'OPEN',
      incidentRequested: wantsIncident,
      incident: wantsIncident
          ? IssueIncidentTicket(
              ticketCode:
                  'DEMO-INC-${(++_ticketSeq).toString().padLeft(4, '0')}',
              status: 'RECEIVED',
            )
          : null,
    );
  }

  static MyAdoption _fromMock(
    ActiveAdoptionModel a,
    List<AdoptionFollowupModel> recorded,
  ) {
    final total =
        a.totalFollowups > 0 ? a.totalFollowups : kTotalFollowupCycles;
    final byCycle = {for (final f in recorded) f.cycleNumber: f};
    final periods = List.generate(total, (i) {
      final no = i + 1;
      final f = byCycle[no];
      return MyFollowupPeriod(
        periodNo: no,
        status: f?.status ?? FollowupStatus.PENDING,
        dueAt: f?.dueDate ??
            a.adoptedAt.add(Duration(days: kFollowupCycleDays * no)),
        submittedAt: f?.submittedAt,
      );
    });
    final cat = a.cat;
    return MyAdoption(
      id: a.id.toString(),
      catId: a.catId.toString(),
      status: a.status,
      catName: cat?.name ?? 'Kucing adopsi',
      catGender: switch (cat?.gender.toLowerCase()) {
        'male' => 'MALE',
        'female' => 'FEMALE',
        _ => null,
      },
      catPhotoUrl: cat?.primaryPhotoUrl,
      pickedUpAt: a.adoptedAt,
      followups: periods,
    );
  }
}
