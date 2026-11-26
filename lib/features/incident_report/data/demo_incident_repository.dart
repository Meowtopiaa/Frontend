import 'dart:typed_data';

import 'incident_enums.dart';
import 'incident_model.dart';
import 'incident_repository.dart';

/// Repositori lokal untuk mode demo (`MEOWTOPIA_DEMO=true`).
/// Meniru aturan server yang relevan bagi UI: idempotensi pembuatan tiket,
/// status RECEIVED setelah "tersimpan", transisi yang diizinkan (409 bila
/// tidak), dan notifikasi NOT_REQUESTED (tidak ada klaim relawan diberi tahu).
/// Kontak dokter hewan sengaja kosong: PRD EIR-12 melarang data fiktif.
class DemoIncidentRepository implements IncidentRepository {
  DemoIncidentRepository({
    DateTime? now,
    this.latency = const Duration(milliseconds: 450),
    bool seed = true,
  }) {
    if (seed) _seed(now ?? DateTime.now().toUtc());
  }

  final Duration latency;
  final List<IncidentReportModel> _mine = [];
  final List<CaretakerTask> _tasks = [];
  final Map<String, IncidentReportModel> _byIdempotencyKey = {};
  int _counter = 0;
  int _mediaCounter = 0;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  void _seed(DateTime now) {
    final created = now.subtract(const Duration(hours: 26));
    _mine.add(
      IncidentReportModel(
        id: 'demo-inc-0001',
        ticketCode: 'INC-DEMO-0001',
        category: IncidentCategory.damagedQr,
        urgency: IncidentUrgency.low,
        description: 'Kalung QR Mochi lepas dan kodenya tidak terbaca.',
        status: IncidentStatus.inProgress,
        createdAt: created,
        catName: 'Mochi',
        location: const IncidentLocation(lat: -6.97343, lng: 107.63031),
        locationNote: 'Depan Gedung TULT',
        assignedAt: created.add(const Duration(hours: 2)),
        hasAssignee: true,
        statusLogs: [
          IncidentStatusLog(
            toStatus: IncidentStatus.received,
            createdAt: created,
            note: 'Tiket tersimpan.',
          ),
          IncidentStatusLog(
            fromStatus: IncidentStatus.received,
            toStatus: IncidentStatus.assigned,
            createdAt: created.add(const Duration(hours: 2)),
            actorName: 'Admin Insiden',
            note: 'Penanggung jawab utama ditetapkan.',
          ),
          IncidentStatusLog(
            fromStatus: IncidentStatus.assigned,
            toStatus: IncidentStatus.inProgress,
            createdAt: created.add(const Duration(hours: 3)),
            actorName: 'Relawan',
            note: 'Kalung pengganti sedang disiapkan.',
          ),
        ],
      ),
    );

    final offered = now.subtract(const Duration(minutes: 6));
    _tasks.add(
      CaretakerTask(
        id: 'demo-task-0001',
        status: AssignmentStatus.offered,
        offeredAt: offered,
        incident: IncidentReportModel(
          id: 'demo-inc-0101',
          ticketCode: 'INC-DEMO-0101',
          category: IncidentCategory.injured,
          urgency: IncidentUrgency.high,
          description: 'Kucing oranye pincang kaki depan kiri.',
          status: IncidentStatus.waitingAssignment,
          createdAt: offered.subtract(const Duration(minutes: 10)),
          location: const IncidentLocation(lat: -6.97452, lng: 107.63180),
          locationNote: 'Parkiran motor Gedung Selaru',
          statusLogs: [
            IncidentStatusLog(
              toStatus: IncidentStatus.received,
              createdAt: offered.subtract(const Duration(minutes: 10)),
            ),
            IncidentStatusLog(
              fromStatus: IncidentStatus.received,
              toStatus: IncidentStatus.waitingAssignment,
              createdAt: offered,
              actorName: 'Admin Insiden',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<String> uploadMedia(Uint8List bytes,
      {required String filename}) async {
    await _wait();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const IncidentFailure(
        'Ukuran berkas melebihi 5 MB.',
        code: 'VALIDATION_ERROR',
        statusCode: 422,
      );
    }
    _mediaCounter++;
    return 'demo-media-$_mediaCounter';
  }

  @override
  Future<IncidentReportModel> createIncident(
    IncidentDraft draft, {
    required String idempotencyKey,
  }) async {
    await _wait();
    final existing = _byIdempotencyKey[idempotencyKey];
    if (existing != null) return existing;
    if (!draft.location.isValid) {
      throw const IncidentFailure(
        'Koordinat tidak valid.',
        code: 'VALIDATION_ERROR',
        statusCode: 422,
        fieldErrors: {'location': 'Koordinat tidak valid.'},
      );
    }
    _counter++;
    final now = DateTime.now().toUtc();
    final ticket = IncidentReportModel(
      id: 'demo-inc-${now.microsecondsSinceEpoch}',
      ticketCode:
          'INC-${now.year % 100}${_two(now.month)}${_two(now.day)}-${_counter.toString().padLeft(4, '0')}',
      category: draft.category,
      urgency: draft.urgency,
      description: draft.description.trim(),
      status: IncidentStatus.received,
      createdAt: now,
      catId: draft.catId,
      location: draft.location,
      locationNote: draft.locationNote,
      source: draft.source,
      sourceRef: draft.sourceRef,
      mediaCount: draft.mediaIds.length,
      statusLogs: [
        IncidentStatusLog(toStatus: IncidentStatus.received, createdAt: now),
      ],
    );
    _mine.insert(0, ticket);
    _byIdempotencyKey[idempotencyKey] = ticket;
    return ticket;
  }

  @override
  Future<List<IncidentReportModel>> getMyIncidents() async {
    await _wait();
    return List.of(_mine);
  }

  @override
  Future<IncidentReportModel> getIncident(String id) async {
    await _wait();
    for (final item in _mine) {
      if (item.id == id) return item;
    }
    for (final task in _tasks) {
      if (task.incident.id == id && task.status != AssignmentStatus.offered) {
        return task.incident;
      }
    }
    throw const IncidentFailure('Data tidak ditemukan atau tidak dapat diakses.',
        statusCode: 404);
  }

  @override
  Future<List<CaretakerTask>> getCaretakerTasks() async {
    await _wait();
    return List.of(_tasks);
  }

  int _taskIndex(String taskId) {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) {
      throw const IncidentFailure('Tugas tidak ditemukan.', statusCode: 404);
    }
    return i;
  }

  @override
  Future<CaretakerTask> acceptTask(String taskId) async {
    await _wait();
    final i = _taskIndex(taskId);
    final task = _tasks[i];
    if (task.status != AssignmentStatus.offered) {
      throw const IncidentFailure(
        'Tugas ini sudah tidak dapat diterima.',
        code: 'CONFLICT',
        statusCode: 409,
      );
    }
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: AssignmentStatus.accepted,
      incident: task.incident.copyWith(
        status: IncidentStatus.assigned,
        assignedAt: now,
        hasAssignee: true,
        statusLogs: [
          ...task.incident.statusLogs,
          IncidentStatusLog(
            fromStatus: task.incident.status,
            toStatus: IncidentStatus.assigned,
            createdAt: now,
            actorName: 'Anda',
            note: 'Relawan menerima tugas.',
          ),
        ],
      ),
    );
    _tasks[i] = updated;
    return updated;
  }

  @override
  Future<void> declineTask(String taskId, {String? reason}) async {
    await _wait();
    final i = _taskIndex(taskId);
    if (_tasks[i].status != AssignmentStatus.offered) {
      throw const IncidentFailure(
        'Tugas ini sudah tidak dapat ditolak.',
        code: 'CONFLICT',
        statusCode: 409,
      );
    }
    _tasks.removeAt(i);
  }

  @override
  Future<IncidentReportModel> updateStatus(
    String incidentId, {
    required IncidentStatus toStatus,
    required String note,
    required String idempotencyKey,
  }) async {
    await _wait();
    final i = _tasks.indexWhere((t) =>
        t.incident.id == incidentId &&
        (t.status == AssignmentStatus.accepted ||
            t.status == AssignmentStatus.done));
    if (i < 0) {
      throw const IncidentFailure(
        'Akses ditolak. Anda tidak memiliki izin untuk tindakan ini.',
        code: 'FORBIDDEN',
        statusCode: 403,
      );
    }
    final current = _tasks[i].incident;
    if (current.status == toStatus) return current; // retry idempoten
    if (!current.status.caretakerNextStatuses.contains(toStatus)) {
      throw const IncidentFailure(
        'Transisi status tidak diizinkan.',
        code: 'CONFLICT',
        statusCode: 409,
      );
    }
    final now = DateTime.now().toUtc();
    final updated = current.copyWith(
      status: toStatus,
      resolvedAt: toStatus == IncidentStatus.resolved ? now : null,
      resolutionNote: toStatus == IncidentStatus.resolved ? note : null,
      statusLogs: [
        ...current.statusLogs,
        IncidentStatusLog(
          fromStatus: current.status,
          toStatus: toStatus,
          createdAt: now,
          actorName: 'Anda',
          note: note,
        ),
      ],
    );
    _tasks[i] = _tasks[i].copyWith(
      incident: updated,
      status: toStatus == IncidentStatus.resolved
          ? AssignmentStatus.done
          : AssignmentStatus.accepted,
    );
    return updated;
  }

  @override
  Future<List<VetContact>> getVets() async {
    await _wait();
    return const [];
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
