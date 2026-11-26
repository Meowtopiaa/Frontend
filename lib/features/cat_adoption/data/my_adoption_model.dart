import 'adoption_enums.dart';

/// Satu periode laporan kondisi dari jadwal server (ADP-09).
class MyFollowupPeriod {
  final int periodNo;
  final DateTime? dueAt;
  final DateTime? submittedAt;

  /// PENDING, SUBMITTED, LATE, REVIEWED. Nilai lain dibaca sebagai PENDING.
  final FollowupStatus status;

  const MyFollowupPeriod({
    required this.periodNo,
    required this.status,
    this.dueAt,
    this.submittedAt,
  });

  factory MyFollowupPeriod.fromJson(Map<String, dynamic> json) {
    final raw = json['status']?.toString().trim().toUpperCase();
    return MyFollowupPeriod(
      periodNo: int.tryParse(json['period_no']?.toString() ?? '') ?? 0,
      dueAt: _parseTime(json['due_at']),
      submittedAt: _parseTime(json['submitted_at']),
      status: FollowupStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => FollowupStatus.PENDING,
      ),
    );
  }

  /// Sudah dikirim atau sudah diperiksa admin.
  bool get isDone =>
      status == FollowupStatus.SUBMITTED || status == FollowupStatus.REVIEWED;
}

/// Kucing di halaman Kucing Saya (EN-20, ADP-08). Data dari GET /adoption/mine.
///
/// Sengaja terpisah dari ActiveAdoptionModel lama: id memakai ULID string dan
/// model ini tidak membaca lokasi pengambilan, foto bukti, atau data adopter.
class MyAdoption {
  final String id;
  final String catId;
  final ActiveAdoptionStatus status;
  final String catName;
  final String? catGender; // MALE, FEMALE, UNKNOWN
  final String? catPhotoMediaId;

  /// URL foto untuk data tiruan. Data API hanya membawa media_id.
  final String? catPhotoUrl;
  final DateTime? pickedUpAt;
  final List<MyFollowupPeriod> followups;

  const MyAdoption({
    required this.id,
    required this.catId,
    required this.status,
    required this.catName,
    this.catGender,
    this.catPhotoMediaId,
    this.catPhotoUrl,
    this.pickedUpAt,
    this.followups = const [],
  });

  /// Mengembalikan null bila status tidak dikenali, supaya tidak ditampilkan
  /// sebagai adopsi aktif berdasarkan tebakan.
  ///
  /// Bentuk dari backend: { id, status, picked_up_at, trial_ends_at,
  /// cat: { id, name, primary_photo_media_id } }. cat_id di level atas juga
  /// diterima sesuai draf OpenAPI.
  static MyAdoption? tryParse(Map<String, dynamic> json) {
    final cat = json['cat'] is Map<String, dynamic>
        ? json['cat'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final id = json['id']?.toString().trim() ?? '';
    final catId = (json['cat_id'] ?? cat['id'])?.toString().trim() ?? '';
    final rawStatus = json['status']?.toString().trim().toUpperCase();
    final status = ActiveAdoptionStatus.values
        .where((s) => s.name == rawStatus)
        .firstOrNull;
    if (id.isEmpty || catId.isEmpty || status == null) return null;

    final name = (cat['name'] ?? json['cat_name'])?.toString().trim();

    final schedule = json['followup_schedule'] is List
        ? (json['followup_schedule'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MyFollowupPeriod.fromJson)
            .where((p) => p.periodNo > 0)
            .toList()
        : <MyFollowupPeriod>[];
    schedule.sort((a, b) => a.periodNo.compareTo(b.periodNo));

    return MyAdoption(
      id: id,
      catId: catId,
      status: status,
      catName: (name == null || name.isEmpty) ? 'Kucing adopsi' : name,
      catGender: cat['gender']?.toString().trim().toUpperCase(),
      catPhotoMediaId: _nonEmpty(cat['primary_photo_media_id']),
      pickedUpAt: _parseTime(json['picked_up_at']),
      followups: List.unmodifiable(schedule),
    );
  }

  bool get isActive => status == ActiveAdoptionStatus.ACTIVE;

  /// Adopsi masih berjalan (belum ditutup admin). Selama pengembalian
  /// diproses, adopsi tetap berjalan sampai diverifikasi (ADP-12), sama
  /// dengan scope Adoption::open() di backend.
  bool get isOpen => status != ActiveAdoptionStatus.CLOSED_RETURNED;

  /// Menyalin dengan URL foto yang sudah dibentuk oleh repository.
  MyAdoption withPhotoUrl(String? url) => MyAdoption(
        id: id,
        catId: catId,
        status: status,
        catName: catName,
        catGender: catGender,
        catPhotoMediaId: catPhotoMediaId,
        catPhotoUrl: url,
        pickedUpAt: pickedUpAt,
        followups: followups,
      );

  String? get genderLabel => switch (catGender) {
        'MALE' => 'Jantan',
        'FEMALE' => 'Betina',
        _ => null,
      };

  bool get hasSchedule => followups.isNotEmpty;
  int get totalFollowups => followups.length;
  int get completedFollowups => followups.where((p) => p.isDone).length;

  /// Periode pertama yang belum dikirim, atau null bila semua sudah dikirim.
  MyFollowupPeriod? get nextFollowup =>
      followups.where((p) => !p.isDone).firstOrNull;

  /// Laporan berikutnya terlambat menurut status server atau batas waktunya.
  bool isNextFollowupLate(DateTime now) {
    final next = nextFollowup;
    if (next == null) return false;
    if (next.status == FollowupStatus.LATE) return true;
    return next.dueAt != null && now.isAfter(next.dueAt!);
  }
}

/// Ringkasan pengajuan kelayakan untuk Kucing Saya (ADP-08: kelulusan calon
/// adopter ditampilkan terpisah dari adopsi). Data dari
/// GET /adoption/applications/mine. Jawaban form dan foto tempat tinggal
/// sengaja tidak dibaca karena tidak dipakai di halaman ini.
class MyEligibility {
  final String id;
  final ApplicationStatus status;
  final String? adminNote;
  final DateTime? submittedAt;

  const MyEligibility({
    required this.id,
    required this.status,
    this.adminNote,
    this.submittedAt,
  });

  /// Null bila id kosong atau status tidak dikenali.
  static MyEligibility? tryParse(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final raw = json['status']?.toString().trim().toUpperCase();
    final status =
        ApplicationStatus.values.where((s) => s.name == raw).firstOrNull;
    if (id.isEmpty || status == null) return null;
    return MyEligibility(
      id: id,
      status: status,
      adminNote: _nonEmpty(json['admin_note']),
      submittedAt: _parseTime(json['submitted_at']),
    );
  }
}

/// Tiket insiden yang benar-benar dibuat server untuk sebuah kendala.
class IssueIncidentTicket {
  final String ticketCode;
  final String status;

  const IssueIncidentTicket({required this.ticketCode, required this.status});
}

/// Hasil POST /adoption/{id}/issues (EN-23, ADP-13).
class AdoptionIssueResult {
  final String id;
  final String status;

  /// Pengguna meminta kendala ini diteruskan sebagai tiket insiden.
  final bool incidentRequested;

  /// Diisi hanya bila respons server memuat tiket. Null berarti belum ada tiket.
  final IssueIncidentTicket? incident;

  const AdoptionIssueResult({
    required this.id,
    required this.status,
    required this.incidentRequested,
    this.incident,
  });

  factory AdoptionIssueResult.fromJson(
    Map<String, dynamic> json, {
    required bool incidentRequested,
  }) {
    final rawIncident = json['incident'];
    IssueIncidentTicket? ticket;
    if (rawIncident is Map<String, dynamic>) {
      final code = _nonEmpty(rawIncident['ticket_code']);
      if (code != null) {
        ticket = IssueIncidentTicket(
          ticketCode: code,
          status: _nonEmpty(rawIncident['status'])?.toUpperCase() ?? 'RECEIVED',
        );
      }
    }
    return AdoptionIssueResult(
      id: json['id']?.toString() ?? '',
      status: _nonEmpty(json['status'])?.toUpperCase() ?? 'OPEN',
      incidentRequested: incidentRequested,
      incident: ticket,
    );
  }
}

/// Kategori yang boleh disertai permintaan tiket insiden: kucing butuh bantuan.
bool issueCategoryAllowsIncident(AdoptionIssueCategory category) =>
    category == AdoptionIssueCategory.SICK ||
    category == AdoptionIssueCategory.CARE;

DateTime? _parseTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
