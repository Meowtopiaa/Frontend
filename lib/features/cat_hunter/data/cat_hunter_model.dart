import '../cat_dex/data/models/cat_model.dart';

class ScanCheckResult {
  final CatModel cat;
  final bool canScanToday;
  final bool isAvailable;
  final DateTime? lastScannedAt;
  final DateTime? nextAvailableAt;
  final String message;

  const ScanCheckResult({
    required this.cat,
    required this.canScanToday,
    required this.isAvailable,
    this.lastScannedAt,
    this.nextAvailableAt,
    this.message = '',
  });

  factory ScanCheckResult.fromJson(
    Map<String, dynamic> json, {
    String message = '',
  }) {
    final rawCat = json['cat'] is Map<String, dynamic>
        ? json['cat'] as Map<String, dynamic>
        : <String, dynamic>{};

    return ScanCheckResult(
      cat: CatModel.fromJson(rawCat),
      canScanToday: json['can_scan_today'] == true,
      isAvailable: json['is_available'] != false,
      lastScannedAt: json['last_scanned_at'] != null
          ? DateTime.tryParse(json['last_scanned_at'].toString())?.toLocal()
          : null,
      nextAvailableAt: json['next_available_at'] != null
          ? DateTime.tryParse(json['next_available_at'].toString())?.toLocal()
          : null,
      message: message,
    );
  }
}

class EncounterResult {
  final String catId;
  final int encounterCount;
  final bool isFirstEncounter;
  final DateTime? lastScannedAt;
  final bool canRename;
  final int renameRequiredEncounters;
  final bool isNameLocked;
  final CatModel cat;

  const EncounterResult({
    required this.catId,
    required this.encounterCount,
    required this.isFirstEncounter,
    this.lastScannedAt,
    required this.canRename,
    required this.renameRequiredEncounters,
    required this.isNameLocked,
    required this.cat,
  });

  factory EncounterResult.fromJson(Map<String, dynamic> json) {
    final rawCat = json['cat'] is Map<String, dynamic>
        ? json['cat'] as Map<String, dynamic>
        : <String, dynamic>{};

    return EncounterResult(
      catId: (json['cat_id'] ?? rawCat['id'] ?? '').toString(),
      encounterCount: _asInt(json['encounter_count']),
      isFirstEncounter: json['is_first_encounter'] == true,
      lastScannedAt: json['last_scanned_at'] != null
          ? DateTime.tryParse(json['last_scanned_at'].toString())?.toLocal()
          : null,
      canRename: json['can_rename'] == true,
      renameRequiredEncounters:
          _asInt(json['rename_required_encounters'], fallback: 5),
      isNameLocked: json['is_name_locked'] == true,
      cat: CatModel.fromJson(rawCat),
    );
  }
}

class ProfileMedalModel {
  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final bool isUnlocked;
  final String progressLabel;

  const ProfileMedalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.isUnlocked,
    required this.progressLabel,
  });

  factory ProfileMedalModel.fromJson(Map<String, dynamic> json) {
    final current = _asInt(json['current']);
    final target = _asInt(json['target'], fallback: 1);
    final isUnlocked = json['is_unlocked'] == true || current >= target;

    return ProfileMedalModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      current: current,
      target: target,
      isUnlocked: isUnlocked,
      progressLabel: (json['progress_label'] ??
              (isUnlocked ? 'Tercapai' : '${current.clamp(0, target)}/$target'))
          .toString(),
    );
  }
}

class CatHunterProfileModel {
  final int totalCatsCollected;
  final int totalCatalogCats;
  final int totalEncounters;
  final String title;
  final CatModel? bestBuddy;
  final List<ProfileMedalModel> medals;
  final CatModel? favoriteAvatar;

  const CatHunterProfileModel({
    required this.totalCatsCollected,
    required this.totalCatalogCats,
    required this.totalEncounters,
    required this.title,
    this.bestBuddy,
    required this.medals,
    this.favoriteAvatar,
  });

  factory CatHunterProfileModel.fromJson(Map<String, dynamic> json) {
    final rawMedals = json['medals'];
    final medals = rawMedals is List
        ? rawMedals
            .whereType<Map<String, dynamic>>()
            .map(ProfileMedalModel.fromJson)
            .toList()
        : <ProfileMedalModel>[];

    return CatHunterProfileModel(
      totalCatsCollected: _asInt(json['total_cats_collected']),
      totalCatalogCats: _asInt(json['total_catalog_cats']),
      totalEncounters: _asInt(json['total_encounters']),
      title: (json['title'] ?? 'Pendatang Baru').toString(),
      bestBuddy: json['best_buddy'] is Map<String, dynamic>
          ? CatModel.fromJson(json['best_buddy'] as Map<String, dynamic>)
          : null,
      medals: medals,
      favoriteAvatar: json['favorite_avatar'] is Map<String, dynamic>
          ? CatModel.fromJson(json['favorite_avatar'] as Map<String, dynamic>)
          : null,
    );
  }
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
