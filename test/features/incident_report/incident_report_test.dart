import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowtopia/features/incident_report/data/demo_incident_repository.dart';
import 'package:meowtopia/features/incident_report/data/incident_enums.dart';
import 'package:meowtopia/features/incident_report/data/incident_model.dart';
import 'package:meowtopia/features/incident_report/data/incident_repository.dart';
import 'package:meowtopia/features/incident_report/logic/incident_form_validator.dart';
import 'package:meowtopia/features/incident_report/logic/incident_provider.dart';

/// Repositori yang gagal N kali pertama saat membuat tiket (mis. jaringan
/// putus setelah server menyimpan) sambil mencatat Idempotency-Key.
class _FlakyRepository extends DemoIncidentRepository {
  _FlakyRepository({this.failures = 1})
      : super(latency: Duration.zero, seed: false);

  int failures;
  final List<String> keys = [];
  int uploads = 0;

  @override
  Future<String> uploadMedia(Uint8List bytes, {required String filename}) {
    uploads++;
    return super.uploadMedia(bytes, filename: filename);
  }

  @override
  Future<IncidentReportModel> createIncident(
    IncidentDraft draft, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    // Server tetap menyimpan, tetapi respons tidak sampai ke klien.
    final saved =
        await super.createIncident(draft, idempotencyKey: idempotencyKey);
    if (failures > 0) {
      failures--;
      throw const IncidentFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      );
    }
    return saved;
  }
}

class _ForbiddenRepository extends DemoIncidentRepository {
  _ForbiddenRepository() : super(latency: Duration.zero, seed: false);

  @override
  Future<List<CaretakerTask>> getCaretakerTasks() async =>
      throw const IncidentFailure('Akses ditolak.',
          code: 'FORBIDDEN', statusCode: 403);
}

IncidentDraft _draft({
  String description = 'Kucing oranye pincang di depan kantin.',
  IncidentLocation? location =
      const IncidentLocation(lat: -6.9734, lng: 107.6303),
  IncidentSource source = IncidentSource.direct,
  String? sourceRef,
  String? catId,
}) =>
    IncidentDraft(
      category: IncidentCategory.injured,
      urgency: IncidentUrgency.high,
      description: description,
      location: location ?? const IncidentLocation(lat: 999, lng: 999),
      source: source,
      sourceRef: sourceRef,
      catId: catId,
    );

IncidentAttachment _attachment(String key) => IncidentAttachment(
      key: key,
      filename: '$key.jpg',
      readBytes: () async => Uint8List.fromList([1, 2, 3]),
    );

void main() {
  group('Enum dan model (EIR-02, §5.5)', () {
    test('sembilan kategori sesuai PRD', () {
      expect(IncidentCategory.values.map((e) => e.code), [
        'SICK',
        'INJURED',
        'MISSING',
        'FOUND',
        'AGGRESSIVE',
        'DECEASED',
        'NEW_CAT',
        'DAMAGED_QR',
        'OTHER',
      ]);
    });

    test('urgensi hanya LOW, MEDIUM, HIGH', () {
      expect(IncidentUrgency.values.map((e) => e.code),
          ['LOW', 'MEDIUM', 'HIGH']);
    });

    test('relawan tidak bisa menutup, menolak, atau menandai duplikat', () {
      for (final s in IncidentStatus.values) {
        expect(s.caretakerNextStatuses, isNot(contains(IncidentStatus.closed)));
        expect(
            s.caretakerNextStatuses, isNot(contains(IncidentStatus.rejected)));
        expect(
            s.caretakerNextStatuses, isNot(contains(IncidentStatus.duplicate)));
      }
      expect(IncidentStatus.received.caretakerNextStatuses, isEmpty);
    });

    test('fromJson membaca format API dan riwayat status terurut', () {
      final m = IncidentReportModel.fromJson({
        'id': '01JD0000000000000000000000',
        'ticket_code': 'INC-261126-0001',
        'category': 'SICK',
        'urgency': 'HIGH',
        'description': 'Muntah',
        'status': 'WAITING_ASSIGNMENT',
        'created_at': '2026-11-26T03:00:00Z',
        'location': {'lat': -6.97, 'lng': 107.63, 'accuracy_m': 8},
        'source': 'GAME',
        'source_ref': 'enc-1',
        'notification_status': 'FAILED',
        'status_logs': [
          {
            'to_status': 'WAITING_ASSIGNMENT',
            'from_status': 'RECEIVED',
            'created_at': '2026-11-26T03:10:00Z',
          },
          {'to_status': 'RECEIVED', 'created_at': '2026-11-26T03:00:00Z'},
        ],
      });
      expect(m.category, IncidentCategory.sick);
      expect(m.urgency, IncidentUrgency.high);
      expect(m.status, IncidentStatus.waitingAssignment);
      expect(m.source, IncidentSource.game);
      expect(m.notificationStatus, IncidentNotificationStatus.failed);
      expect(m.location?.accuracyM, 8);
      expect(m.hasAssignee, isFalse);
      expect(m.statusLogs.first.toStatus, IncidentStatus.received);
    });

    test('toJson draft memakai kontrak POST /incidents', () {
      final json = _draft(catId: 'CAT1', sourceRef: 'enc-9',
              source: IncidentSource.game)
          .withMedia(['m1'])
          .toJson();
      expect(json['category'], 'INJURED');
      expect(json['urgency'], 'HIGH');
      expect(json['location'], {'lat': -6.9734, 'lng': 107.6303});
      expect(json['media_ids'], ['m1']);
      expect(json['cat_id'], 'CAT1');
      expect(json['source'], 'GAME');
      expect(json['source_ref'], 'enc-9');
      expect(json.containsKey('title'), isFalse);
    });
  });

  group('Validasi form', () {
    test('deskripsi wajib dan minimal 10 karakter', () {
      expect(IncidentFormValidator.description(''), isNotNull);
      expect(IncidentFormValidator.description('pendek'), isNotNull);
      expect(IncidentFormValidator.description('Kucing pincang kaki'), isNull);
    });

    test('lokasi wajib dan koordinat harus valid', () {
      expect(IncidentFormValidator.location(null), isNotNull);
      expect(
        IncidentFormValidator.location(
            const IncidentLocation(lat: 120, lng: 0)),
        isNotNull,
      );
      expect(
        IncidentFormValidator.location(
            const IncidentLocation(lat: -6.97, lng: 107.63)),
        isNull,
      );
    });

    test('maksimal 5 lampiran (OQ-11)', () {
      expect(IncidentFormValidator.mediaCount(5), isNull);
      expect(IncidentFormValidator.mediaCount(6), isNotNull);
    });
  });

  group('Pembuatan tiket (EIR-01, EIR-04)', () {
    test('sukses hanya dengan ticket_code dan status RECEIVED', () async {
      final p = IncidentProvider(
        repository: DemoIncidentRepository(latency: Duration.zero, seed: false),
      );
      final ticket = await p.submit(_draft());
      expect(ticket, isNotNull);
      expect(ticket!.ticketCode, isNotEmpty);
      expect(ticket.status, IncidentStatus.received);
      expect(ticket.notificationStatus,
          IncidentNotificationStatus.notRequested);
      expect(p.submitError, isNull);
      expect(p.myIncidents.single.id, ticket.id);
    });

    test('validasi gagal tidak memanggil server dan tidak sukses', () async {
      final repo = _FlakyRepository(failures: 0);
      final p = IncidentProvider(repository: repo);
      final ticket = await p.submit(_draft(description: 'x'));
      expect(ticket, isNull);
      expect(p.submitError?.code, 'VALIDATION_ERROR');
      expect(p.submitError?.fieldErrors.containsKey('description'), isTrue);
      expect(repo.keys, isEmpty);
    });

    test('lebih dari 5 lampiran ditolak', () async {
      final repo = _FlakyRepository(failures: 0);
      final p = IncidentProvider(repository: repo);
      final ticket = await p.submit(
        _draft(),
        attachments: [for (var i = 0; i < 6; i++) _attachment('f$i')],
      );
      expect(ticket, isNull);
      expect(repo.uploads, 0);
    });

    test('retry setelah gagal memakai Idempotency-Key sama, satu tiket',
        () async {
      final repo = _FlakyRepository(failures: 1);
      final p = IncidentProvider(repository: repo);
      final draft = _draft();
      final attachments = [_attachment('a'), _attachment('b')];

      final first = await p.submit(draft, attachments: attachments);
      expect(first, isNull);
      expect(p.submitError, isNotNull);
      expect(p.myIncidents, isEmpty);

      final second = await p.submit(draft, attachments: attachments);
      expect(second, isNotNull);
      expect(repo.keys, hasLength(2));
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.uploads, 2, reason: 'media tidak diunggah ulang');
      final mine = await repo.getMyIncidents();
      expect(mine, hasLength(1), reason: 'tidak ada tiket ganda');
    });

    test('isi berubah setelah gagal memakai kunci baru', () async {
      final repo = _FlakyRepository(failures: 1);
      final p = IncidentProvider(repository: repo);
      await p.submit(_draft());
      await p.submit(_draft(description: 'Deskripsi yang sudah diperbaiki.'));
      expect(repo.keys[0], isNot(repo.keys[1]));
    });

    test('laporan berikutnya setelah sukses mendapat kunci baru', () async {
      final repo = _FlakyRepository(failures: 0);
      final p = IncidentProvider(repository: repo);
      await p.submit(_draft());
      expect(p.currentSubmitKey, isNull);
      await p.submit(_draft());
      expect(repo.keys[0], isNot(repo.keys[1]));
    });
  });

  group('Sumber laporan (EIR-10, IT-04)', () {
    test('mendeteksi tiket aktif dari sumber dan source_ref sama', () async {
      final p = IncidentProvider(
        repository: DemoIncidentRepository(latency: Duration.zero, seed: false),
      );
      expect(p.activeTicketFromSource(IncidentSource.game, 'enc-1'), isNull);
      await p.submit(_draft(
        source: IncidentSource.game,
        sourceRef: 'enc-1',
        catId: 'CAT1',
      ));
      expect(p.activeTicketFromSource(IncidentSource.game, 'enc-1'),
          isNotNull);
      expect(p.activeTicketFromSource(IncidentSource.game, 'enc-2'), isNull);
      expect(
          p.activeTicketFromSource(IncidentSource.direct, 'enc-1'), isNull);
    });
  });

  group('Relawan (EIR-05..07)', () {
    test('terima tugas lalu ubah status lewat transisi yang diizinkan',
        () async {
      final p = IncidentProvider(
        repository: DemoIncidentRepository(latency: Duration.zero),
      );
      await p.fetchTasks();
      final task = p.tasks.single;
      expect(task.status, AssignmentStatus.offered);

      expect(await p.acceptTask(task.id), isNull);
      final accepted = p.tasks.single;
      expect(accepted.status, AssignmentStatus.accepted);
      expect(accepted.incident.status, IncidentStatus.assigned);

      final noNote = await p.updateStatus(
        accepted.incident.id,
        toStatus: IncidentStatus.inProgress,
        note: '',
        idempotencyKey: p.newStatusKey(),
      );
      expect(noNote?.code, 'VALIDATION_ERROR');

      final invalid = await p.updateStatus(
        accepted.incident.id,
        toStatus: IncidentStatus.resolved,
        note: 'Langsung selesai',
        idempotencyKey: p.newStatusKey(),
      );
      expect(invalid?.isConflict, isTrue);

      final ok = await p.updateStatus(
        accepted.incident.id,
        toStatus: IncidentStatus.inProgress,
        note: 'Menuju lokasi.',
        idempotencyKey: p.newStatusKey(),
      );
      expect(ok, isNull);
      expect(p.tasks.single.incident.status, IncidentStatus.inProgress);
      expect(p.tasks.single.incident.statusLogs.last.note, 'Menuju lokasi.');
    });

    test('tolak tugas menghapusnya dari daftar', () async {
      final p = IncidentProvider(
        repository: DemoIncidentRepository(latency: Duration.zero),
      );
      await p.fetchTasks();
      expect(await p.declineTask(p.tasks.single.id, reason: 'Di luar kampus'),
          isNull);
      expect(p.tasks, isEmpty);
    });

    test('pengguna non-relawan mendapat penolakan akses', () async {
      final p = IncidentProvider(repository: _ForbiddenRepository());
      await p.fetchTasks();
      expect(p.tasksError?.isForbidden, isTrue);
      expect(p.tasks, isEmpty);
    });

    test('ubah status tiket yang bukan tugasnya ditolak', () async {
      final p = IncidentProvider(
        repository: DemoIncidentRepository(latency: Duration.zero),
      );
      final failure = await p.updateStatus(
        'demo-inc-0001',
        toStatus: IncidentStatus.resolved,
        note: 'Coba ubah',
        idempotencyKey: p.newStatusKey(),
      );
      expect(failure?.isForbidden, isTrue);
    });
  });

  test('kontak dokter hewan demo kosong, tidak fiktif (EIR-12)', () async {
    final p = IncidentProvider(
      repository: DemoIncidentRepository(latency: Duration.zero),
    );
    await p.fetchVets();
    expect(p.vets, isEmpty);
    expect(p.vetsLoaded, isTrue);
  });
}
