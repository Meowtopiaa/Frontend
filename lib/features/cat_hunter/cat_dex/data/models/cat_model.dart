import '../../../constants/app_assets.dart';

enum CatVariant {
  oren,
  putih,
  hitam,
}

class CatModel {
  final String id;
  final String uniqueCode;
  final String name;
  final String qrHash;
  final CatVariant variant;
  final String zone;
  final String? zoneCode;
  final String locationDetail;
  final String avatarAsset;
  final String photoAsset;
  final String healthStatus;
  final String? healthStatusCode;
  final bool? isSterilized;
  final bool? isVaccinated;
  final String personality;
  final String? specialNeeds;
  final String? gender;
  final String? ageGroup;
  final String? primaryColor;
  final String? furPattern;
  final int encounterCount;
  final DateTime? lastScannedDate;
  final bool isNameLocked;
  final bool isCollected;
  final bool isCurrentlyInCafe;
  final bool isFavoriteAvatar;
  final bool? canScanToday;
  final bool? canRename;
  final int renameRequiredEncounters;
  final DateTime? nextAvailableAt;
  final String cafePose; // 'pillow', 'box', 'tree', 'carpet', 'stool'
  final String quote;

  const CatModel({
    required this.id,
    this.uniqueCode = '',
    required this.name,
    required this.qrHash,
    required this.variant,
    required this.zone,
    this.zoneCode,
    required this.locationDetail,
    required this.avatarAsset,
    required this.photoAsset,
    required this.healthStatus,
    this.healthStatusCode,
    this.isSterilized,
    this.isVaccinated,
    required this.personality,
    this.specialNeeds,
    this.gender,
    this.ageGroup,
    this.primaryColor,
    this.furPattern,
    this.encounterCount = 0,
    this.lastScannedDate,
    this.isNameLocked = false,
    this.isCollected = false,
    this.isCurrentlyInCafe = false,
    this.isFavoriteAvatar = false,
    this.canScanToday,
    this.canRename,
    this.renameRequiredEncounters = 5,
    this.nextAvailableAt,
    this.cafePose = 'pillow',
    this.quote = 'Meoong... senangnya dikunjungi!',
  });

  static CatVariant _parseVariant(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'putih':
        return CatVariant.putih;
      case 'hitam':
        return CatVariant.hitam;
      case 'oren':
      default:
        return CatVariant.oren;
    }
  }

  static String _headAssetForVariant(CatVariant variant) {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenHead;
      case CatVariant.putih:
        return AppAssets.catPutihHead;
      case CatVariant.hitam:
        return AppAssets.catHitamHead;
    }
  }

  static String _happyAssetForVariant(CatVariant variant) {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenHappy;
      case CatVariant.putih:
        return AppAssets.catPutihHappy;
      case CatVariant.hitam:
        return AppAssets.catHitamHappy;
    }
  }

  static int _parseInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static bool? _parseNullableBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    final lower = raw.toString().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
    return null;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str)?.toLocal();
  }

  factory CatModel.fromJson(Map<String, dynamic> json) {
    final variant = _parseVariant(json['variant']);
    final uniqueCode = (json['unique_code'] ?? json['qr_hash'] ?? '').toString();
    final qrHash = (json['qr_hash'] ?? uniqueCode).toString();
    final encounterCount = _parseInt(json['encounter_count']);
    final isCollected = _parseNullableBool(json['is_collected']) ?? (encounterCount > 0);
    final healthStatusCode = json['health_status']?.toString();
    final healthLabel = json['health_label']?.toString();
    final zone = (json['zone'] ?? 'Kampus Tel-U').toString();
    final locationDetail =
        (json['location_detail'] ?? json['description'] ?? 'Area $zone').toString();
    final personality =
        (json['personality'] ?? json['temperament'] ?? 'Ramah & Bersahabat').toString();
    final quoteRaw = json['quote']?.toString().trim();
    final cafePoseRaw = json['cafe_pose']?.toString();

    return CatModel(
      id: (json['id'] ?? '').toString(),
      uniqueCode: uniqueCode,
      name: (json['name'] ?? 'Kucing Kampus').toString(),
      qrHash: qrHash,
      variant: variant,
      zone: zone,
      zoneCode: json['zone_code']?.toString(),
      locationDetail: locationDetail,
      avatarAsset: _headAssetForVariant(variant),
      photoAsset: _happyAssetForVariant(variant),
      healthStatus: (healthLabel != null && healthLabel.isNotEmpty)
          ? healthLabel
          : (healthStatusCode ?? 'Dalam Pantauan Pengelola'),
      healthStatusCode: healthStatusCode,
      isSterilized: _parseNullableBool(json['is_sterilized']),
      isVaccinated: _parseNullableBool(json['is_vaccinated']),
      personality: personality,
      specialNeeds: json['special_needs']?.toString(),
      gender: json['gender']?.toString(),
      ageGroup: json['age_group']?.toString(),
      primaryColor: json['primary_color']?.toString(),
      furPattern: json['fur_pattern']?.toString(),
      encounterCount: encounterCount,
      lastScannedDate: _parseDate(json['last_scanned_at'] ?? json['last_scanned_date']),
      isNameLocked: _parseNullableBool(json['is_name_locked']) ?? false,
      isCollected: isCollected,
      isCurrentlyInCafe:
          _parseNullableBool(json['is_currently_in_cafe']) ?? isCollected,
      isFavoriteAvatar: _parseNullableBool(json['is_favorite_avatar']) ?? false,
      canScanToday: _parseNullableBool(json['can_scan_today']),
      canRename: _parseNullableBool(json['can_rename']),
      renameRequiredEncounters:
          _parseInt(json['rename_required_encounters'], fallback: 5),
      nextAvailableAt: _parseDate(json['next_available_at']),
      cafePose: (cafePoseRaw != null && cafePoseRaw.isNotEmpty)
          ? cafePoseRaw
          : 'pillow',
      quote: (quoteRaw != null && quoteRaw.isNotEmpty)
          ? quoteRaw
          : 'Meoong... senangnya dikunjungi!',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unique_code': uniqueCode.isNotEmpty ? uniqueCode : qrHash,
      'qr_hash': qrHash,
      'name': name,
      'variant': variant.name,
      'zone': zone,
      'zone_code': zoneCode,
      'location_detail': locationDetail,
      'health_status': healthStatusCode ?? healthStatus,
      'health_label': healthStatus,
      'is_sterilized': isSterilized,
      'is_vaccinated': isVaccinated,
      'personality': personality,
      'special_needs': specialNeeds,
      'gender': gender,
      'age_group': ageGroup,
      'primary_color': primaryColor,
      'fur_pattern': furPattern,
      'quote': quote,
      'encounter_count': encounterCount,
      'last_scanned_at': lastScannedDate?.toIso8601String(),
      'is_collected': isCollected,
      'is_currently_in_cafe': isCurrentlyInCafe,
      'is_favorite_avatar': isFavoriteAvatar,
      'can_scan_today': canScanToday,
      'can_rename': canRename,
      'rename_required_encounters': renameRequiredEncounters,
      'next_available_at': nextAvailableAt?.toIso8601String(),
      'is_name_locked': isNameLocked,
      'cafe_pose': cafePose,
    };
  }

  /// Mengambil path aset pose kepala siap diusap sesuai variasi kucing.
  String get headPoseAsset => _headAssetForVariant(variant);

  /// Mengambil path aset pose tiduran telentang memperlihatkan perut sesuai variasi kucing.
  String get bellyPoseAsset {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenBelly;
      case CatVariant.putih:
        return AppAssets.catPutihBelly;
      case CatVariant.hitam:
        return AppAssets.catHitamBelly;
    }
  }

  /// Mengambil path aset pose bahagia melompat sesuai variasi kucing.
  String get happyPoseAsset => _happyAssetForVariant(variant);

  /// Mengambil path aset pose sedih (untuk pop-up cooldown harian) sesuai variasi kucing.
  String get sadPoseAsset {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenSad;
      case CatVariant.putih:
        return AppAssets.catPutihSad;
      case CatVariant.hitam:
        return AppAssets.catHitamSad;
    }
  }

  /// Mengambil path aset frame 1 animasi berjalan di Kafe Kucing sesuai variasi kucing.
  String get walk1PoseAsset {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenWalk1;
      case CatVariant.putih:
        return AppAssets.catPutihWalk1;
      case CatVariant.hitam:
        return AppAssets.catHitamWalk1;
    }
  }

  /// Mengambil path aset frame 2 animasi berjalan di Kafe Kucing sesuai variasi kucing.
  String get walk2PoseAsset {
    switch (variant) {
      case CatVariant.oren:
        return AppAssets.catOrenWalk2;
      case CatVariant.putih:
        return AppAssets.catPutihWalk2;
      case CatVariant.hitam:
        return AppAssets.catHitamWalk2;
    }
  }

  /// Kucing dalam kondisi siap disapa (tidak sakit/terluka).
  bool get isEncounterable =>
      healthStatusCode != 'SICK' && healthStatusCode != 'INJURED';

  /// Syarat hak memberi nama permanen: pertemuan >= 5 kali dan nama belum dikunci.
  bool get canBeNamed =>
      canRename ?? (encounterCount >= renameRequiredEncounters && !isNameLocked);

  /// Mengecek apakah kucing sudah di-scan pada tanggal kalender hari ini.
  bool get isScannedToday {
    if (canScanToday == true) return false;
    final scanned = lastScannedDate;
    if (canScanToday == false && isEncounterable && scanned != null) {
      return true;
    }
    if (scanned == null) return false;
    final now = DateTime.now();
    return scanned.year == now.year &&
        scanned.month == now.month &&
        scanned.day == now.day;
  }

  /// Format tampilan ringkas waktu pertemuan terakhir.
  String get formattedLastScannedDate {
    final scanned = lastScannedDate;
    if (scanned == null) return 'Belum disapa hari ini';
    final now = DateTime.now();
    final hh = scanned.hour.toString().padLeft(2, '0');
    final mm = scanned.minute.toString().padLeft(2, '0');
    if (scanned.year == now.year &&
        scanned.month == now.month &&
        scanned.day == now.day) {
      return 'Hari ini, $hh:$mm WIB';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (scanned.year == yesterday.year &&
        scanned.month == yesterday.month &&
        scanned.day == yesterday.day) {
      return 'Kemarin, $hh:$mm WIB';
    }
    final dd = scanned.day.toString().padLeft(2, '0');
    final mo = scanned.month.toString().padLeft(2, '0');
    return '$dd/$mo/${scanned.year}';
  }

  CatModel copyWith({
    String? id,
    String? uniqueCode,
    String? name,
    String? qrHash,
    CatVariant? variant,
    String? zone,
    String? zoneCode,
    String? locationDetail,
    String? avatarAsset,
    String? photoAsset,
    String? healthStatus,
    String? healthStatusCode,
    bool? isSterilized,
    bool? isVaccinated,
    String? personality,
    String? specialNeeds,
    String? gender,
    String? ageGroup,
    String? primaryColor,
    String? furPattern,
    int? encounterCount,
    DateTime? lastScannedDate,
    bool clearLastScannedDate = false,
    bool? isNameLocked,
    bool? isCollected,
    bool? isCurrentlyInCafe,
    bool? isFavoriteAvatar,
    bool? canScanToday,
    bool clearCanScanToday = false,
    bool? canRename,
    int? renameRequiredEncounters,
    DateTime? nextAvailableAt,
    bool clearNextAvailableAt = false,
    String? cafePose,
    String? quote,
  }) {
    return CatModel(
      id: id ?? this.id,
      uniqueCode: uniqueCode ?? this.uniqueCode,
      name: name ?? this.name,
      qrHash: qrHash ?? this.qrHash,
      variant: variant ?? this.variant,
      zone: zone ?? this.zone,
      zoneCode: zoneCode ?? this.zoneCode,
      locationDetail: locationDetail ?? this.locationDetail,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      photoAsset: photoAsset ?? this.photoAsset,
      healthStatus: healthStatus ?? this.healthStatus,
      healthStatusCode: healthStatusCode ?? this.healthStatusCode,
      isSterilized: isSterilized ?? this.isSterilized,
      isVaccinated: isVaccinated ?? this.isVaccinated,
      personality: personality ?? this.personality,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      primaryColor: primaryColor ?? this.primaryColor,
      furPattern: furPattern ?? this.furPattern,
      encounterCount: encounterCount ?? this.encounterCount,
      lastScannedDate:
          clearLastScannedDate ? null : (lastScannedDate ?? this.lastScannedDate),
      isNameLocked: isNameLocked ?? this.isNameLocked,
      isCollected: isCollected ?? this.isCollected,
      isCurrentlyInCafe: isCurrentlyInCafe ?? this.isCurrentlyInCafe,
      isFavoriteAvatar: isFavoriteAvatar ?? this.isFavoriteAvatar,
      canScanToday: clearCanScanToday ? null : (canScanToday ?? this.canScanToday),
      canRename: canRename ?? this.canRename,
      renameRequiredEncounters:
          renameRequiredEncounters ?? this.renameRequiredEncounters,
      nextAvailableAt:
          clearNextAvailableAt ? null : (nextAvailableAt ?? this.nextAvailableAt),
      cafePose: cafePose ?? this.cafePose,
      quote: quote ?? this.quote,
    );
  }
}
