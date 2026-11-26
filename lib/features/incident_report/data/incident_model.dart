import 'incident_enums.dart';

/// Koordinat sesuai konvensi API §8.1: `{ lat, lng, accuracy_m? }`.
class IncidentLocation {
  const IncidentLocation({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.fromGps = false,
  });

  final double lat;
  final double lng;
  final double? accuracyM;

  /// Hanya untuk tampilan di klien (GPS vs pin manual); tidak dikirim.
  final bool fromGps;

  bool get isValid =>
      lat.isFinite && lng.isFinite && lat.abs() <= 90 && lng.abs() <= 180;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM!.round(),
      };

  static IncidentLocation? tryParse(dynamic json) {
    if (json is! Map) return null;
    final lat = _toDouble(json['lat'] ?? json['latitude']);
    final lng = _toDouble(json['lng'] ?? json['longitude']);
    if (lat == null || lng == null) return null;
    return IncidentLocation(
      lat: lat,
      lng: lng,
      accuracyM: _toDouble(json['accuracy_m']),
    );
  }

  IncidentLocation copyWith({double? accuracyM, bool? fromGps}) =>
      IncidentLocation(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM ?? this.accuracyM,
        fromGps: fromGps ?? this.fromGps,
      );

  String get label =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// Satu baris incident_status_logs.
class IncidentStatusLog {
  const IncidentStatusLog({
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.actorName,
    this.note,
  });

  final IncidentStatus? fromStatus;
  final IncidentStatus toStatus;
  final String? actorName;
  final String? note;
  final DateTime createdAt;

  factory IncidentStatusLog.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    return IncidentStatusLog(
      fromStatus: json['from_status'] == null
          ? null
          : IncidentStatus.fromCode(json['from_status']?.toString()),
      toStatus: IncidentStatus.fromCode(json['to_status']?.toString()),
      actorName: actor is Map
          ? actor['name']?.toString()
          : json['actor_name']?.toString(),
      note: _nonEmpty(json['note']),
      createdAt: _toDate(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}

/// Tiket insiden (incident_reports). Respons publik tidak memuat
/// nomor kontak pelapor; model ini juga tidak menyimpannya.
class IncidentReportModel {
  const IncidentReportModel({
    required this.id,
    required this.ticketCode,
    required this.category,
    required this.urgency,
    required this.description,
    required this.status,
    required this.createdAt,
    this.catId,
    this.catName,
    this.location,
    this.locationNote,
    this.source = IncidentSource.direct,
    this.sourceRef,
    this.assignedAt,
    this.resolvedAt,
    this.closedAt,
    this.resolutionNote,
    this.notificationStatus = IncidentNotificationStatus.notRequested,
    this.hasAssignee = false,
    this.mediaCount = 0,
    this.statusLogs = const [],
  });

  final String id;
  final String ticketCode;
  final IncidentCategory category;
  final IncidentUrgency urgency;
  final String description;
  final IncidentStatus status;
  final DateTime createdAt;
  final String? catId;
  final String? catName;
  final IncidentLocation? location;
  final String? locationNote;
  final IncidentSource source;
  final String? sourceRef;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? resolutionNote;
  final IncidentNotificationStatus notificationStatus;
  final bool hasAssignee;
  final int mediaCount;
  final List<IncidentStatusLog> statusLogs;

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) {
    final cat = json['cat'];
    final logs = json['status_logs'] ?? json['history'];
    final media = json['media'] ?? json['media_ids'];
    return IncidentReportModel(
      id: json['id']?.toString() ?? '',
      ticketCode: json['ticket_code']?.toString() ?? '',
      category: IncidentCategory.fromCode(json['category']?.toString()),
      urgency: IncidentUrgency.fromCode(json['urgency']?.toString()),
      description: json['description']?.toString() ?? '',
      status: IncidentStatus.fromCode(json['status']?.toString()),
      createdAt: _toDate(json['created_at']) ?? DateTime.now().toUtc(),
      catId: _nonEmpty(json['cat_id'] ?? (cat is Map ? cat['id'] : null)),
      catName: cat is Map ? _nonEmpty(cat['name']) : null,
      location: IncidentLocation.tryParse(json['location']),
      locationNote: _nonEmpty(json['location_note']),
      source: IncidentSource.fromCode(json['source']?.toString()),
      sourceRef: _nonEmpty(json['source_ref']),
      assignedAt: _toDate(json['assigned_at']),
      resolvedAt: _toDate(json['resolved_at']),
      closedAt: _toDate(json['closed_at']),
      resolutionNote: _nonEmpty(json['resolution_note']),
      notificationStatus: IncidentNotificationStatus.fromCode(
        json['notification_status']?.toString(),
      ),
      hasAssignee: json['has_assignee'] == true ||
          json['assigned_to'] != null ||
          json['assigned_at'] != null,
      mediaCount: (json['media_count'] as num?)?.toInt() ??
          (media is List ? media.length : 0),
      statusLogs: logs is List
          ? (logs
              .whereType<Map>()
              .map((e) =>
                  IncidentStatusLog.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
          : const [],
    );
  }

  IncidentReportModel copyWith({
    IncidentStatus? status,
    List<IncidentStatusLog>? statusLogs,
    DateTime? assignedAt,
    DateTime? resolvedAt,
    String? resolutionNote,
    bool? hasAssignee,
  }) =>
      IncidentReportModel(
        id: id,
        ticketCode: ticketCode,
        category: category,
        urgency: urgency,
        description: description,
        status: status ?? this.status,
        createdAt: createdAt,
        catId: catId,
        catName: catName,
        location: location,
        locationNote: locationNote,
        source: source,
        sourceRef: sourceRef,
        assignedAt: assignedAt ?? this.assignedAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        closedAt: closedAt,
        resolutionNote: resolutionNote ?? this.resolutionNote,
        notificationStatus: notificationStatus,
        hasAssignee: hasAssignee ?? this.hasAssignee,
        mediaCount: mediaCount,
        statusLogs: statusLogs ?? this.statusLogs,
      );
}

/// Tugas relawan dari `GET /caretaker/tasks`.
class CaretakerTask {
  const CaretakerTask({
    required this.id,
    required this.status,
    required this.incident,
    this.offeredAt,
  });

  /// ID penugasan (incident_assignments.id).
  final String id;
  final AssignmentStatus status;
  final IncidentReportModel incident;
  final DateTime? offeredAt;

  factory CaretakerTask.fromJson(Map<String, dynamic> json) {
    final incident = json['incident'];
    return CaretakerTask(
      id: json['id']?.toString() ?? '',
      status: AssignmentStatus.fromCode(json['status']?.toString()),
      incident: IncidentReportModel.fromJson(
        incident is Map ? Map<String, dynamic>.from(incident) : json,
      ),
      offeredAt: _toDate(json['offered_at'] ?? json['created_at']),
    );
  }

  CaretakerTask copyWith({
    AssignmentStatus? status,
    IncidentReportModel? incident,
  }) =>
      CaretakerTask(
        id: id,
        status: status ?? this.status,
        incident: incident ?? this.incident,
        offeredAt: offeredAt,
      );
}

/// Kontak dokter hewan atau klinik mitra (EIR-12, P1).
class VetContact {
  const VetContact({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.whatsapp,
    this.openHours,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? whatsapp;
  final String? openHours;

  factory VetContact.fromJson(Map<String, dynamic> json) => VetContact(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        address: _nonEmpty(json['address']),
        phone: _nonEmpty(json['phone']),
        whatsapp: _nonEmpty(json['whatsapp']),
        openHours: _nonEmpty(json['open_hours']),
      );
}

/// Isi form laporan (body `POST /incidents`).
class IncidentDraft {
  const IncidentDraft({
    required this.category,
    required this.urgency,
    required this.description,
    required this.location,
    this.locationNote,
    this.catId,
    this.source = IncidentSource.direct,
    this.sourceRef,
    this.mediaIds = const [],
  });

  final IncidentCategory category;
  final IncidentUrgency urgency;
  final String description;
  final IncidentLocation location;
  final String? locationNote;
  final String? catId;
  final IncidentSource source;
  final String? sourceRef;
  final List<String> mediaIds;

  IncidentDraft withMedia(List<String> ids) => IncidentDraft(
        category: category,
        urgency: urgency,
        description: description,
        location: location,
        locationNote: locationNote,
        catId: catId,
        source: source,
        sourceRef: sourceRef,
        mediaIds: ids,
      );

  Map<String, dynamic> toJson() => {
        'category': category.code,
        'urgency': urgency.code,
        'description': description.trim(),
        'location': location.toJson(),
        if (_nonEmpty(locationNote) != null)
          'location_note': locationNote!.trim(),
        'media_ids': mediaIds,
        if (_nonEmpty(catId) != null) 'cat_id': catId!.trim(),
        'source': source.code,
        if (_nonEmpty(sourceRef) != null) 'source_ref': sourceRef!.trim(),
      };

  /// Sidik isi draft untuk memutuskan apakah Idempotency-Key lama
  /// masih boleh dipakai ulang saat retry.
  String get fingerprint => toJson().toString();
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
