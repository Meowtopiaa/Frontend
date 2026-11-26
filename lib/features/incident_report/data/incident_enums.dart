import 'package:flutter/material.dart';

/// Enum modul Emergency Incident Reporting (Optimind).
/// Kode mengikuti PRD v1.1 §5.5, §6.6 (EIR-02), dan §7.4 (bahasa Inggris
/// huruf besar di API); label tampilan berbahasa Indonesia.

/// EIR-02: kategori laporan. Kategori tidak selalu berarti darurat medis.
enum IncidentCategory {
  sick('SICK', 'Sakit', 'Kucing tampak lemas, muntah, atau tidak mau makan.',
      Icons.sick_rounded),
  injured('INJURED', 'Terluka', 'Ada luka, pincang, atau tertabrak.',
      Icons.healing_rounded),
  missing('MISSING', 'Hilang', 'Kucing kampus tidak terlihat di wilayahnya.',
      Icons.search_off_rounded),
  found('FOUND', 'Ditemukan', 'Kucing yang dicari terlihat kembali.',
      Icons.where_to_vote_rounded),
  aggressive('AGGRESSIVE', 'Agresif', 'Kucing menyerang atau membahayakan.',
      Icons.report_gmailerrorred_rounded),
  deceased('DECEASED', 'Meninggal', 'Kucing ditemukan sudah meninggal.',
      Icons.sentiment_very_dissatisfied_rounded),
  newCat('NEW_CAT', 'Kucing Baru',
      'Kucing belum terdaftar. Laporan masuk antrean kurasi data kucing.',
      Icons.fiber_new_rounded),
  damagedQr('DAMAGED_QR', 'QR Rusak', 'Kalung atau QR kucing rusak/hilang.',
      Icons.qr_code_2_rounded),
  other('OTHER', 'Lainnya', 'Hal lain yang perlu diketahui pengelola.',
      Icons.more_horiz_rounded);

  const IncidentCategory(this.code, this.label, this.hint, this.icon);

  final String code;
  final String label;
  final String hint;
  final IconData icon;

  /// Kategori yang dapat dipilih di form laporan baru (keputusan tim Optimind).
  /// Hilang, Ditemukan, Kucing Baru, dan QR Rusak tidak lagi ditawarkan; nilainya
  /// tetap ada agar tiket lama dengan kategori tersebut masih tampil benar.
  static const List<IncidentCategory> reportable = [
    sick,
    injured,
    aggressive,
    deceased,
    other,
  ];

  bool get isReportable => reportable.contains(this);

  static IncidentCategory fromCode(String? code) => values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => IncidentCategory.other,
      );
}

/// Urgensi awal (OQ-10). Tidak ada janji SLA di aplikasi.
enum IncidentUrgency {
  low('LOW', 'Rendah', 'Perlu perhatian, tidak mendesak.', Color(0xFF4388E8)),
  medium('MEDIUM', 'Sedang', 'Kondisi tidak normal, perlu ditangani hari ini.',
      Color(0xFFE59A14)),
  high('HIGH', 'Tinggi', 'Luka berat atau darurat, perlu tindakan segera.',
      Color(0xFFAD343E));

  const IncidentUrgency(this.code, this.label, this.help, this.color);

  final String code;
  final String label;
  final String help;
  final Color color;

  static IncidentUrgency fromCode(String? code) => values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => IncidentUrgency.medium,
      );
}

/// Status tiket (§5.5).
enum IncidentStatus {
  received('RECEIVED', 'Diterima', 'Tiket tersimpan dan masuk antrean.'),
  waitingAssignment('WAITING_ASSIGNMENT', 'Menunggu Petugas',
      'Belum ada penanggung jawab yang menerima.'),
  assigned('ASSIGNED', 'Ditugaskan',
      'Satu penanggung jawab utama ditetapkan atau menerima tugas.'),
  inProgress('IN_PROGRESS', 'Sedang Ditangani', 'Penanganan dimulai.'),
  resolved('RESOLVED', 'Selesai Ditangani',
      'Tindakan lapangan selesai, catatan penanganan tersimpan.'),
  closed('CLOSED', 'Ditutup', 'Admin menutup setelah peninjauan.'),
  rejected('REJECTED', 'Ditolak', 'Ditolak admin dengan alasan.'),
  duplicate('DUPLICATE', 'Duplikat', 'Ditandai admin sebagai laporan ganda.'),
  unknown('UNKNOWN', 'Tidak Diketahui', 'Status belum dikenali aplikasi.');

  const IncidentStatus(this.code, this.label, this.meaning);

  final String code;
  final String label;
  final String meaning;

  bool get isFinal =>
      this == closed || this == rejected || this == duplicate;

  static IncidentStatus fromCode(String? code) => values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => IncidentStatus.unknown,
      );

  /// Transisi yang boleh diajukan relawan dari aplikasi (EIR-07).
  /// Server tetap menjadi penentu akhir dan menolak transisi lain dengan 409.
  /// CLOSED, REJECTED, dan DUPLICATE hanya oleh admin di Filament.
  List<IncidentStatus> get caretakerNextStatuses => switch (this) {
        IncidentStatus.assigned => const [IncidentStatus.inProgress],
        IncidentStatus.inProgress => const [IncidentStatus.resolved],
        _ => const [],
      };
}

/// Asal laporan (EIR-10).
enum IncidentSource {
  direct('DIRECT', 'Langsung'),
  game('GAME', 'Cat Hunter'),
  profile('PROFILE', 'Profil Kucing'),
  adoption('ADOPTION', 'Adopsi');

  const IncidentSource(this.code, this.label);

  final String code;
  final String label;

  static IncidentSource fromCode(String? code) => values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => IncidentSource.direct,
      );
}

/// Status notifikasi tiket (§8.7). Ditampilkan apa adanya; aplikasi
/// tidak pernah mengklaim relawan sudah diberi tahu (FIX-09).
enum IncidentNotificationStatus {
  notRequested('NOT_REQUESTED', 'Belum diminta'),
  pending('PENDING', 'Menunggu pengiriman'),
  sent('SENT', 'Terkirim ke petugas'),
  failed('FAILED', 'Gagal dikirim');

  const IncidentNotificationStatus(this.code, this.label);

  final String code;
  final String label;

  static IncidentNotificationStatus fromCode(String? code) =>
      values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => IncidentNotificationStatus.notRequested,
      );
}

/// Status penugasan relawan (incident_assignments.status).
enum AssignmentStatus {
  offered('OFFERED', 'Ditawarkan'),
  accepted('ACCEPTED', 'Diterima'),
  declined('DECLINED', 'Ditolak'),
  done('DONE', 'Selesai');

  const AssignmentStatus(this.code, this.label);

  final String code;
  final String label;

  static AssignmentStatus fromCode(String? code) => values.firstWhere(
        (e) => e.code == code?.toUpperCase(),
        orElse: () => AssignmentStatus.offered,
      );
}
