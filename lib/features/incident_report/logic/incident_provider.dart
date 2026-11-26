import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../data/demo_incident_repository.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';
import '../data/incident_repository.dart';
import '../data/incident_service.dart';
import 'incident_form_validator.dart';

/// Lampiran lokal (foto/video dari kamera) yang belum tentu sudah diunggah.
class IncidentAttachment {
  const IncidentAttachment({
    required this.key,
    required this.filename,
    required this.readBytes,
    this.isVideo = false,
  });

  /// Kunci stabil (mis. path berkas) untuk cache hasil unggah saat retry.
  final String key;
  final String filename;
  final Future<Uint8List> Function() readBytes;
  final bool isVideo;
}

class IncidentProvider extends ChangeNotifier {
  IncidentProvider({IncidentRepository? repository, Uuid? uuid})
      : _repo = repository ??
            (AppConstants.demoMode
                ? DemoIncidentRepository()
                : IncidentService()),
        _uuid = uuid ?? const Uuid();

  final IncidentRepository _repo;
  final Uuid _uuid;

  // ---------------- Laporan saya (EIR-05) ----------------
  List<IncidentReportModel> _mine = [];
  bool _loadingMine = false;
  bool _mineLoaded = false;
  IncidentFailure? _mineError;

  List<IncidentReportModel> get myIncidents => List.unmodifiable(_mine);
  bool get isLoadingMine => _loadingMine;
  bool get mineLoaded => _mineLoaded;
  IncidentFailure? get mineError => _mineError;

  Future<void> fetchMyIncidents() async {
    if (_loadingMine) return;
    _loadingMine = true;
    _mineError = null;
    notifyListeners();
    try {
      _mine = await _repo.getMyIncidents();
      _mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _mineLoaded = true;
    } catch (e) {
      _mineError = IncidentFailure.from(e);
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
  }

  // ---------------- Detail ----------------
  final Map<String, IncidentReportModel> _details = {};
  final Set<String> _loadingDetail = {};
  final Map<String, IncidentFailure> _detailErrors = {};

  IncidentReportModel? detailOf(String id) =>
      _details[id] ?? _findLocal(id);
  bool isLoadingDetail(String id) => _loadingDetail.contains(id);
  IncidentFailure? detailErrorOf(String id) => _detailErrors[id];

  IncidentReportModel? _findLocal(String id) {
    for (final item in _mine) {
      if (item.id == id) return item;
    }
    for (final task in _tasks) {
      if (task.incident.id == id) return task.incident;
    }
    return null;
  }

  Future<void> fetchDetail(String id) async {
    if (_loadingDetail.contains(id)) return;
    _loadingDetail.add(id);
    _detailErrors.remove(id);
    notifyListeners();
    try {
      _details[id] = await _repo.getIncident(id);
    } catch (e) {
      _detailErrors[id] = IncidentFailure.from(e);
    } finally {
      _loadingDetail.remove(id);
      notifyListeners();
    }
  }

  // ---------------- Pembuatan tiket (EIR-01..04, EIR-10) ----------------
  bool _submitting = false;
  String _submitStage = '';
  IncidentFailure? _submitError;
  String? _submitKey;
  String? _submitFingerprint;
  final Map<String, String> _uploadedMedia = {};

  bool get isSubmitting => _submitting;
  String get submitStage => _submitStage;
  IncidentFailure? get submitError => _submitError;

  /// Untuk uji: kunci idempotensi yang sedang dipakai.
  @visibleForTesting
  String? get currentSubmitKey => _submitKey;

  void clearSubmitError() {
    _submitError = null;
    notifyListeners();
  }

  /// EIR-10: tiket aktif yang sudah dibuat dari sumber yang sama.
  IncidentReportModel? activeTicketFromSource(
    IncidentSource source,
    String? sourceRef,
  ) {
    if (source == IncidentSource.direct ||
        sourceRef == null ||
        sourceRef.isEmpty) {
      return null;
    }
    for (final item in _mine) {
      if (item.source == source &&
          item.sourceRef == sourceRef &&
          !item.status.isFinal) {
        return item;
      }
    }
    return null;
  }

  /// Mengunggah lampiran lalu membuat tiket. Mengembalikan tiket hanya bila
  /// server mengonfirmasi tersimpan (status RECEIVED); selain itu `null` dan
  /// [submitError] terisi. Retry dengan isi sama memakai Idempotency-Key sama
  /// sehingga tidak membuat tiket ganda.
  Future<IncidentReportModel?> submit(
    IncidentDraft draft, {
    List<IncidentAttachment> attachments = const [],
  }) async {
    if (_submitting) return null;
    final errors = IncidentFormValidator.validate(
      description: draft.description,
      location: draft.location,
      locationNote: draft.locationNote,
      mediaCount: attachments.length,
    );
    if (errors.isNotEmpty) {
      _submitError = IncidentFailure(
        errors.values.first,
        code: 'VALIDATION_ERROR',
        fieldErrors: errors,
      );
      notifyListeners();
      return null;
    }

    _submitting = true;
    _submitError = null;
    notifyListeners();
    try {
      final mediaIds = <String>[];
      for (var i = 0; i < attachments.length; i++) {
        final a = attachments[i];
        var id = _uploadedMedia[a.key];
        if (id == null) {
          _submitStage = 'Mengunggah media ${i + 1}/${attachments.length}...';
          notifyListeners();
          final bytes = await a.readBytes();
          id = await _repo.uploadMedia(bytes, filename: a.filename);
          _uploadedMedia[a.key] = id;
        }
        mediaIds.add(id);
      }

      final finalDraft = draft.withMedia(mediaIds);
      final fp = finalDraft.fingerprint;
      if (_submitKey == null || _submitFingerprint != fp) {
        _submitKey = _uuid.v4();
        _submitFingerprint = fp;
      }

      _submitStage = 'Menyimpan laporan...';
      notifyListeners();
      final ticket =
          await _repo.createIncident(finalDraft, idempotencyKey: _submitKey!);

      // Berhasil: kunci dilepas agar laporan baru berikutnya mendapat kunci baru.
      _submitKey = null;
      _submitFingerprint = null;
      _uploadedMedia.clear();
      _mine.removeWhere((e) => e.id == ticket.id);
      _mine.insert(0, ticket);
      _details[ticket.id] = ticket;
      return ticket;
    } catch (e) {
      _submitError = IncidentFailure.from(e);
      return null;
    } finally {
      _submitting = false;
      _submitStage = '';
      notifyListeners();
    }
  }

  /// Dipanggil saat form dibuka ulang untuk laporan baru.
  void resetDraftSession() {
    _submitKey = null;
    _submitFingerprint = null;
    _uploadedMedia.clear();
    _submitError = null;
  }

  // ---------------- Tugas relawan (EIR-05, EIR-06, EIR-07) ----------------
  List<CaretakerTask> _tasks = [];
  bool _loadingTasks = false;
  bool _tasksLoaded = false;
  IncidentFailure? _tasksError;
  final Set<String> _busyTasks = {};

  List<CaretakerTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoadingTasks => _loadingTasks;
  bool get tasksLoaded => _tasksLoaded;
  IncidentFailure? get tasksError => _tasksError;
  bool isTaskBusy(String id) => _busyTasks.contains(id);

  Future<void> fetchTasks() async {
    if (_loadingTasks) return;
    _loadingTasks = true;
    _tasksError = null;
    notifyListeners();
    try {
      _tasks = await _repo.getCaretakerTasks();
      _tasksLoaded = true;
    } catch (e) {
      _tasksError = IncidentFailure.from(e);
    } finally {
      _loadingTasks = false;
      notifyListeners();
    }
  }

  Future<IncidentFailure?> _taskAction(
    String busyId,
    Future<void> Function() run,
  ) async {
    if (_busyTasks.contains(busyId)) return null;
    _busyTasks.add(busyId);
    notifyListeners();
    try {
      await run();
      return null;
    } catch (e) {
      return IncidentFailure.from(e);
    } finally {
      _busyTasks.remove(busyId);
      notifyListeners();
    }
  }

  Future<IncidentFailure?> acceptTask(String taskId) =>
      _taskAction(taskId, () async {
        final updated = await _repo.acceptTask(taskId);
        _replaceTask(updated);
      });

  Future<IncidentFailure?> declineTask(String taskId, {String? reason}) =>
      _taskAction(taskId, () async {
        await _repo.declineTask(taskId, reason: reason);
        _tasks = _tasks.where((t) => t.id != taskId).toList();
      });

  /// Kunci idempotensi baru untuk satu dialog perubahan status.
  String newStatusKey() => _uuid.v4();

  Future<IncidentFailure?> updateStatus(
    String incidentId, {
    required IncidentStatus toStatus,
    required String note,
    required String idempotencyKey,
  }) {
    final noteError = IncidentFormValidator.statusNote(note);
    if (noteError != null) {
      return Future.value(
        IncidentFailure(noteError, code: 'VALIDATION_ERROR'),
      );
    }
    return _taskAction(incidentId, () async {
      final updated = await _repo.updateStatus(
        incidentId,
        toStatus: toStatus,
        note: note,
        idempotencyKey: idempotencyKey,
      );
      _details[incidentId] = updated;
      _tasks = [
        for (final t in _tasks)
          if (t.incident.id == incidentId)
            t.copyWith(
              incident: updated,
              status: updated.status == IncidentStatus.resolved
                  ? AssignmentStatus.done
                  : t.status,
            )
          else
            t,
      ];
    });
  }

  void _replaceTask(CaretakerTask updated) {
    _tasks = [
      for (final t in _tasks)
        if (t.id == updated.id) updated else t,
    ];
    _details[updated.incident.id] = updated.incident;
  }

  // ---------------- Dokter hewan (EIR-12, P1) ----------------
  List<VetContact> _vets = [];
  bool _loadingVets = false;
  bool _vetsLoaded = false;
  IncidentFailure? _vetsError;

  List<VetContact> get vets => List.unmodifiable(_vets);
  bool get isLoadingVets => _loadingVets;
  bool get vetsLoaded => _vetsLoaded;
  IncidentFailure? get vetsError => _vetsError;

  Future<void> fetchVets() async {
    if (_loadingVets) return;
    _loadingVets = true;
    _vetsError = null;
    notifyListeners();
    try {
      _vets = await _repo.getVets();
      _vetsLoaded = true;
    } catch (e) {
      _vetsError = IncidentFailure.from(e);
    } finally {
      _loadingVets = false;
      notifyListeners();
    }
  }
}
