import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowtopia/core/network/api_exception.dart';
import 'package:meowtopia/features/cat_adoption/data/adoption_enums.dart';
import 'package:meowtopia/features/cat_adoption/data/mock_adoption_repository.dart';
import 'package:meowtopia/features/cat_adoption/data/my_adoption_model.dart';
import 'package:meowtopia/features/cat_adoption/data/my_adoption_repository.dart';
import 'package:meowtopia/features/cat_adoption/logic/adoption_provider.dart';
import 'package:meowtopia/features/cat_adoption/ui/adoption_issue_report_page.dart';
import 'package:meowtopia/features/cat_adoption/ui/my_cats_page.dart';
import 'package:provider/provider.dart';

const _adoptionId = '01JD7Q8Z5X6Y7Z8A9B0C1D2E3F';
const _catId = '01JD7Q8Z5X6Y7Z8A9B0C1D2E3G';

Map<String, dynamic> _adoptionJson({String status = 'ACTIVE', String? id}) => {
      'id': id ?? _adoptionId,
      'cat_id': _catId,
      'status': status,
      'picked_up_at': '2026-10-01T03:00:00Z',
      'cat': {'name': 'Oyen', 'gender': 'MALE'},
      'followup_schedule': [
        {'period_no': 2, 'due_at': '2026-10-29T03:00:00Z', 'status': 'PENDING'},
        {
          'period_no': 1,
          'due_at': '2026-10-15T03:00:00Z',
          'status': 'REVIEWED',
          'submitted_at': '2026-10-14T03:00:00Z',
        },
      ],
    };

Response _ok(Object data, {String path = '/'}) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'success': true, 'message': 'OK', 'data': data},
    );

DioException _apiError(String code, String message, int status) => DioException(
      requestOptions: RequestOptions(path: '/'),
      error: ApiException(message: message, code: code, statusCode: status),
    );

/// Repository tiruan untuk tes provider dan widget.
class _FakeRepo implements MyAdoptionRepository {
  List<MyAdoption> adoptions = [];
  Object? loadError;
  Object? issueError;
  AdoptionIssueResult? issueResult;
  final List<String> usedKeys = [];
  final List<bool> incidentRequests = [];

  List<MyEligibility> eligibility = [];
  Object? eligibilityError;

  @override
  bool get supportsPhoto => false;

  /// Seperti mode API: halaman lama berbasis id angka tidak dibuka.
  @override
  bool get supportsLegacyPages => false;

  @override
  Future<List<MyEligibility>> getMyEligibility() async {
    if (eligibilityError != null) throw eligibilityError!;
    return eligibility;
  }

  @override
  Future<List<MyAdoption>> getMyAdoptions() async {
    if (loadError != null) throw loadError!;
    return adoptions;
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
    usedKeys.add(idempotencyKey);
    incidentRequests.add(requestIncident);
    if (issueError != null) throw issueError!;
    return issueResult ??
        AdoptionIssueResult(
          id: 'ISSUE-1',
          status: 'OPEN',
          incidentRequested: requestIncident,
        );
  }
}

void main() {
  group('MyAdoption.tryParse (EN-20)', () {
    test(
        'membaca field publik, mengurutkan jadwal, dan mengabaikan data privat',
        () {
      final a = MyAdoption.tryParse({
        ..._adoptionJson(),
        'pickup_location': {'lat': -6.97, 'lng': 107.63},
        'adopter_phone': '0812',
      })!;

      expect(a.id, _adoptionId);
      expect(a.catName, 'Oyen');
      expect(a.genderLabel, 'Jantan');
      expect(a.followups.map((p) => p.periodNo), [1, 2]);
      expect(a.completedFollowups, 1);
      expect(a.totalFollowups, 2);
      expect(a.nextFollowup!.periodNo, 2);
      expect(a.isNextFollowupLate(DateTime.utc(2026, 10, 20)), isFalse);
      expect(a.isNextFollowupLate(DateTime.utc(2026, 11, 1)), isTrue);
    });

    test('status tidak dikenali atau id kosong tidak dianggap adopsi', () {
      expect(MyAdoption.tryParse(_adoptionJson(status: 'APPROVED')), isNull);
      expect(MyAdoption.tryParse(_adoptionJson(id: '')), isNull);
    });

    test('jadwal kosong tidak dikarang', () {
      final a = MyAdoption.tryParse({
        'id': _adoptionId,
        'cat_id': _catId,
        'status': 'ACTIVE',
      })!;
      expect(a.hasSchedule, isFalse);
      expect(a.nextFollowup, isNull);
      expect(a.catName, 'Kucing adopsi');
      expect(a.pickedUpAt, isNull);
    });
  });

  group('ApiMyAdoptionRepository.getMyAdoptions', () {
    test(
        'membaca bentuk respons backend (cat.id) dan membentuk URL foto publik',
        () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1/',
        get: (path, {queryParameters}) async => _ok([
          {
            'id': _adoptionId,
            'status': 'ACTIVE',
            'picked_up_at': '2026-10-01T03:00:00+00:00',
            'trial_ends_at': '2027-01-01T03:00:00+00:00',
            'cat': {
              'id': _catId,
              'name': 'Oyen',
              'primary_photo_media_id': 'MEDIA1',
            },
          },
        ]),
      );

      final result = await repo.getMyAdoptions();
      expect(result, hasLength(1));
      expect(result.single.catId, _catId);
      expect(result.single.catName, 'Oyen');
      expect(result.single.hasSchedule, isFalse);
      expect(result.single.catPhotoUrl,
          'http://api.test/api/v1/cats/$_catId/photos/MEDIA1');
    });

    test('adopsi yang sudah ditutup atau berstatus asing tidak ditampilkan',
        () async {
      String? calledPath;
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        get: (path, {queryParameters}) async {
          calledPath = path;
          return _ok([
            _adoptionJson(),
            _adoptionJson(status: 'CLOSED_RETURNED', id: 'B'),
            _adoptionJson(status: 'RETURN_REQUESTED', id: 'C'),
            _adoptionJson(status: 'APPROVED', id: 'D'),
          ]);
        },
      );

      final result = await repo.getMyAdoptions();
      expect(calledPath, '/adoption/mine');
      // Pengembalian yang masih diproses tetap tampil (ADP-12).
      expect(result.map((a) => a.id), [_adoptionId, 'C']);
    });

    test('meneruskan pesan error server (akses ditolak)', () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        get: (path, {queryParameters}) async =>
            throw _apiError('NOT_STUDENT', 'Fitur ini khusus mahasiswa.', 403),
      );
      expect(
        repo.getMyAdoptions(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Fitur ini khusus mahasiswa.')),
      );
    });

    test('menolak respons yang bentuknya tidak dikenali', () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        get: (path, {queryParameters}) async => _ok({'unexpected': true}),
      );
      expect(repo.getMyAdoptions(), throwsA(isA<ApiException>()));
    });
  });

  group('ApiMyAdoptionRepository.getMyEligibility', () {
    test('membaca status kelayakan dan membuang status asing', () async {
      String? calledPath;
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        get: (path, {queryParameters}) async {
          calledPath = path;
          return _ok([
            {
              'id': 'APP2',
              'status': 'APPROVED',
              'submitted_at': '2026-11-01T03:00:00+00:00',
            },
            {'id': 'APP1', 'status': 'ENTAH'},
          ]);
        },
      );

      final result = await repo.getMyEligibility();
      expect(calledPath, '/adoption/applications/mine');
      expect(result.map((e) => e.id), ['APP2']);
      expect(result.single.status.name, 'APPROVED');
      expect(result.single.adminNote, isNull);
    });

    test('akses ditolak diteruskan sebagai error', () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        get: (path, {queryParameters}) async =>
            throw _apiError('NOT_STUDENT', 'Fitur ini khusus mahasiswa.', 403),
      );
      expect(
        repo.getMyEligibility(),
        throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'NOT_STUDENT')),
      );
    });
  });

  group('ApiMyAdoptionRepository.reportIssue (EN-23)', () {
    test('mengirim ke endpoint adopsi dengan Idempotency-Key dan membaca tiket',
        () async {
      late String path;
      late Map<String, dynamic> body;
      Map<String, dynamic>? sentHeaders;
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        post: (p, {data, headers}) async {
          path = p;
          body = data as Map<String, dynamic>;
          sentHeaders = headers;
          return _ok({
            'id': 'ISSUE-9',
            'status': 'OPEN',
            'incident': {'ticket_code': 'INC-0042', 'status': 'RECEIVED'},
          });
        },
      );

      final result = await repo.reportIssue(
        adoptionId: _adoptionId,
        category: AdoptionIssueCategory.SICK,
        description: 'Tidak mau makan sejak kemarin.',
        requestIncident: true,
        idempotencyKey: 'key-1',
      );

      expect(path, '/adoption/$_adoptionId/issues');
      expect(sentHeaders, {'Idempotency-Key': 'key-1'});
      expect(body, {
        'category': 'SICK',
        'description': 'Tidak mau makan sejak kemarin.',
        'request_incident': true,
      });
      expect(result.incident!.ticketCode, 'INC-0042');
      expect(result.incidentRequested, isTrue);
    });

    test('tanpa tiket di respons, aplikasi tidak mengklaim tiket dibuat',
        () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        post: (p, {data, headers}) async => _ok({'id': 'ISSUE-9'}),
      );
      final result = await repo.reportIssue(
        adoptionId: _adoptionId,
        category: AdoptionIssueCategory.CARE,
        description: 'Perlu perawatan luka.',
        requestIncident: true,
        idempotencyKey: 'key-2',
      );
      expect(result.incidentRequested, isTrue);
      expect(result.incident, isNull);
    });

    test('kategori non-medis tidak pernah meminta tiket insiden', () async {
      late Map<String, dynamic> body;
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        post: (p, {data, headers}) async {
          body = data as Map<String, dynamic>;
          return _ok({'id': 'ISSUE-9'});
        },
      );
      await repo.reportIssue(
        adoptionId: _adoptionId,
        category: AdoptionIssueCategory.DAMAGED_QR,
        description: 'Kalung putus.',
        requestIncident: true,
        idempotencyKey: 'key-3',
      );
      expect(body['request_incident'], isFalse);
    });

    test('foto ditolak di jalur API sampai media_id tersedia', () async {
      var called = false;
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        post: (p, {data, headers}) async {
          called = true;
          return _ok({});
        },
      );
      await expectLater(
        repo.reportIssue(
          adoptionId: _adoptionId,
          category: AdoptionIssueCategory.SICK,
          description: 'x',
          requestIncident: false,
          idempotencyKey: 'k',
          photo: '/tmp/a.jpg',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(called, isFalse);
    });

    test('validasi gagal dari server diteruskan apa adanya', () async {
      final repo = ApiMyAdoptionRepository(
        baseUrl: 'http://api.test/api/v1',
        post: (p, {data, headers}) async =>
            throw _apiError('VALIDATION_ERROR', 'Deskripsi wajib diisi.', 422),
      );
      expect(
        repo.reportIssue(
          adoptionId: _adoptionId,
          category: AdoptionIssueCategory.SICK,
          description: '',
          requestIncident: false,
          idempotencyKey: 'k',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')),
      );
    });
  });

  group('MockMyAdoptionRepository', () {
    test('Kucing Saya berisi adopsi ACTIVE dengan jadwal enam laporan',
        () async {
      final repo = MockMyAdoptionRepository(MockAdoptionRepository());
      final list = await repo.getMyAdoptions();
      expect(list, isNotEmpty);
      expect(list.every((a) => a.isActive), isTrue);
      expect(list.first.totalFollowups, 6);
    });

    test('laporan kendala tidak menutup adopsi', () async {
      final source = MockAdoptionRepository();
      final repo = MockMyAdoptionRepository(source);
      final before = await repo.getMyAdoptions();

      final result = await repo.reportIssue(
        adoptionId: before.first.id,
        category: AdoptionIssueCategory.SICK,
        description: 'Batuk pilek.',
        requestIncident: false,
        idempotencyKey: 'k',
      );

      expect(result.incident, isNull);
      final after = await repo.getMyAdoptions();
      expect(after.first.status, ActiveAdoptionStatus.ACTIVE);
    });

    test('adopsi yang tidak dikenal ditolak 404', () async {
      final repo = MockMyAdoptionRepository(MockAdoptionRepository());
      expect(
        repo.reportIssue(
          adoptionId: 'tidak-ada',
          category: AdoptionIssueCategory.SICK,
          description: 'x',
          requestIncident: false,
          idempotencyKey: 'k',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('AdoptionProvider Kucing Saya dan kendala', () {
    test('kegagalan memuat menjadi error, bukan daftar kosong', () async {
      final fake = _FakeRepo()..loadError = ApiException(message: 'Gagal.');
      final provider = AdoptionProvider(myAdoptionRepository: fake);
      await provider.fetchMyAdoptions();
      expect(provider.myAdoptionsError, 'Gagal.');
      expect(provider.isMyAdoptionsLoading, isFalse);
    });

    test('kirim kendala gagal menyimpan pesan dan mengembalikan null',
        () async {
      final fake = _FakeRepo()
        ..issueError =
            ApiException(message: 'Bukan adopsimu.', statusCode: 403);
      final provider = AdoptionProvider(myAdoptionRepository: fake);
      final result = await provider.submitAdoptionIssue(
        adoptionId: _adoptionId,
        category: AdoptionIssueCategory.SICK,
        description: 'x',
        requestIncident: false,
        idempotencyKey: 'k',
      );
      expect(result, isNull);
      expect(provider.issueError, 'Bukan adopsimu.');
      expect(provider.isIssueSubmitting, isFalse);
    });
  });

  group('Widget', () {
    Widget wrap(AdoptionProvider provider, Widget child) =>
        ChangeNotifierProvider<AdoptionProvider>.value(
          value: provider,
          child: MaterialApp(home: child),
        );

    /// Provider dibuat di luar fake-async karena konstruktornya memuat data
    /// tiruan awal yang memakai Future.delayed.
    Future<AdoptionProvider> makeProvider(
        WidgetTester tester, _FakeRepo fake) async {
      late AdoptionProvider provider;
      await tester.runAsync(() async {
        provider = AdoptionProvider(myAdoptionRepository: fake);
        await provider.fetchInitialData();
      });
      return provider;
    }

    /// Majukan jam tiruan agar Future.delayed dari data tiruan selesai.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> setLargeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Kucing Saya menampilkan adopsi aktif dari repository',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..adoptions = [MyAdoption.tryParse(_adoptionJson())!];
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(provider, const MyCatsPage()));
      await settle(tester);

      expect(find.text('Oyen'), findsOneWidget);
      expect(find.text('1 dari 2 terkirim'), findsOneWidget);
      expect(find.text('Kirim laporan ke-2'), findsOneWidget);
      // Alur pengembalian belum tersambung: tidak membuka halaman lama.
      expect(
        find.text('Belum tersedia di aplikasi. Hubungi pengurus adopsi.'),
        findsOneWidget,
      );
    });

    testWidgets('status kelayakan dari server tampil terpisah dari adopsi',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..eligibility = [
          MyEligibility.tryParse({
            'id': 'APP1',
            'status': 'REVISION_REQUESTED',
            'admin_note': 'Foto kamar kurang jelas.',
            // Field pribadi yang tidak dipakai halaman ini.
            'housing_type': 'KOS',
            'answers': {'alamat': 'rahasia'},
          })!,
        ];
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(provider, const MyCatsPage()));
      await settle(tester);

      expect(find.text('Kamu belum mengadopsi kucing'), findsOneWidget);
      expect(find.text('Catatan pengurus: Foto kamar kurang jelas.'),
          findsOneWidget);
      // Halaman detail lama tidak ditautkan di mode API.
      expect(find.text('Lihat rincian'), findsNothing);
      expect(find.textContaining('rahasia'), findsNothing);
    });

    testWidgets('gagal memuat kelayakan tidak dianggap belum ada pengajuan',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..eligibilityError = ApiException(message: 'Server mati.');
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(provider, const MyCatsPage()));
      await settle(tester);

      expect(find.text('Belum ada pengajuan.'), findsNothing);
      expect(find.text('Isi form kelayakan'), findsNothing);
      expect(find.textContaining('Status kelayakan belum bisa dimuat'),
          findsOneWidget);
    });

    testWidgets('Kucing Saya menampilkan error dan tombol coba lagi',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..loadError = ApiException(message: 'Server mati.');
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(provider, const MyCatsPage()));
      await settle(tester);

      expect(find.text('Server mati.'), findsOneWidget);
      expect(find.text('Oyen'), findsNothing);
    });

    testWidgets('form kendala: validasi, persetujuan tiket, dan hasil jujur',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..issueResult = const AdoptionIssueResult(
          id: 'ISSUE-1',
          status: 'OPEN',
          incidentRequested: true,
          incident:
              IssueIncidentTicket(ticketCode: 'INC-0042', status: 'RECEIVED'),
        );
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(
        provider,
        const AdoptionIssueReportPage(adoptionId: _adoptionId, catName: 'Oyen'),
      ));
      await settle(tester);

      // Deskripsi kosong ditolak sebelum ada permintaan ke server.
      await tester.tap(find.text('Kirim laporan'));
      await settle(tester);
      expect(find.text('Ceritakan kejadiannya dulu.'), findsOneWidget);
      expect(fake.usedKeys, isEmpty);

      // Kategori non-medis tidak menawarkan tiket insiden.
      await tester.tap(find.text('Kalung atau QR Rusak'));
      await settle(tester);
      expect(find.byKey(const Key('issue_request_incident')), findsNothing);

      await tester.tap(find.text('Kucing Sakit'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('issue_request_incident')));
      await tester.enterText(
          find.byKey(const Key('issue_description')), 'Lemas sejak pagi.');
      await tester.tap(find.text('Kirim laporan'));
      await settle(tester);

      expect(fake.incidentRequests, [true]);
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(find.text('Tiket insiden INC-0042'), findsOneWidget);
    });

    testWidgets('kirim ulang setelah gagal memakai Idempotency-Key yang sama',
        (tester) async {
      await setLargeScreen(tester);
      final fake = _FakeRepo()
        ..issueError = ApiException(message: 'Koneksi terputus.');
      final provider = await makeProvider(tester, fake);

      await tester.pumpWidget(wrap(
        provider,
        const AdoptionIssueReportPage(adoptionId: _adoptionId, catName: 'Oyen'),
      ));
      await settle(tester);

      await tester.enterText(
          find.byKey(const Key('issue_description')), 'Tidak mau makan.');
      await tester.tap(find.text('Kirim laporan'));
      await settle(tester);
      expect(find.text('Koneksi terputus.'), findsOneWidget);
      expect(find.text('Laporan tersimpan'), findsNothing);

      fake.issueError = null;
      await tester.tap(find.text('Kirim laporan'));
      await settle(tester);

      expect(fake.usedKeys, hasLength(2));
      expect(fake.usedKeys[0], fake.usedKeys[1]);
      // Tanpa permintaan tiket, tidak ada klaim tiket.
      expect(find.text('Laporan tersimpan'), findsOneWidget);
      expect(find.textContaining('Tiket insiden'), findsNothing);
    });

    testWidgets('id adopsi kosong tidak menampilkan form', (tester) async {
      await setLargeScreen(tester);
      final provider = await makeProvider(tester, _FakeRepo());
      await tester.pumpWidget(wrap(
        provider,
        const AdoptionIssueReportPage(adoptionId: '', catName: 'Oyen'),
      ));
      await settle(tester);
      expect(find.text('Adopsi tidak ditemukan'), findsOneWidget);
      expect(find.text('Kirim laporan'), findsNothing);
    });
  });
}
