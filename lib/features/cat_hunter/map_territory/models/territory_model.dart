import '../../constants/app_assets.dart';

class _ZoneVisualMeta {
  final String shortLabel;
  final String imageAsset;
  final double latitude;
  final double longitude;
  final double mapDx;
  final double mapDy;

  const _ZoneVisualMeta({
    required this.shortLabel,
    required this.imageAsset,
    required this.latitude,
    required this.longitude,
    required this.mapDx,
    required this.mapDy,
  });
}

class TerritoryModel {
  final String id;
  final String code;
  final String name;
  final String shortLabel;
  final String description;
  final String landmark;
  final int activeCatsCount;
  final int collectedCatsCount;
  final bool hasUnvisitedCatToday;
  final String imageAsset;
  final List<String> residentCatIds;
  final double latitude;
  final double longitude;
  final double mapDx;
  final double mapDy;

  const TerritoryModel({
    required this.id,
    this.code = '',
    required this.name,
    required this.shortLabel,
    required this.description,
    required this.landmark,
    required this.activeCatsCount,
    this.collectedCatsCount = 0,
    this.hasUnvisitedCatToday = true,
    required this.imageAsset,
    required this.residentCatIds,
    required this.latitude,
    required this.longitude,
    required this.mapDx,
    required this.mapDy,
  });

  static const Map<String, _ZoneVisualMeta> _zoneVisualDefaults = {
    'TULT_ASRAMA': _ZoneVisualMeta(
      shortLabel: '🏢 TULT & Asrama',
      imageAsset: AppAssets.zoneTult,
      latitude: -6.9730,
      longitude: 107.6300,
      mapDx: 0.31,
      mapDy: 0.18,
    ),
    'GKU': _ZoneVisualMeta(
      shortLabel: '🏫 GKU',
      imageAsset: AppAssets.campusMap,
      latitude: -6.9745,
      longitude: 107.6315,
      mapDx: 0.37,
      mapDy: 0.43,
    ),
    'CACUK': _ZoneVisualMeta(
      shortLabel: '🏛️ Cacuk',
      imageAsset: AppAssets.campusMap,
      latitude: -6.9710,
      longitude: 107.6285,
      mapDx: 0.48,
      mapDy: 0.58,
    ),
    'FAKULTAS_DEPAN': _ZoneVisualMeta(
      shortLabel: '🎓 Fakultas Depan',
      imageAsset: AppAssets.zoneTult,
      latitude: -6.9720,
      longitude: 107.6330,
      mapDx: 0.74,
      mapDy: 0.50,
    ),
  };

  static int _parseInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static double _parseDouble(dynamic raw, {required double fallback}) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  factory TerritoryModel.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString().toUpperCase();
    final name = (json['name'] ?? code).toString();
    final meta = _zoneVisualDefaults[code] ??
        _zoneVisualDefaults.entries
            .firstWhere(
              (entry) =>
                  name.toLowerCase().contains(entry.key.split('_').first.toLowerCase()),
              orElse: () => const MapEntry(
                'GKU',
                _ZoneVisualMeta(
                  shortLabel: '📍 Zona Kampus',
                  imageAsset: AppAssets.campusMap,
                  latitude: -6.9730,
                  longitude: 107.6300,
                  mapDx: 0.50,
                  mapDy: 0.50,
                ),
              ),
            )
            .value;

    final rawResidents = json['resident_cat_ids'];
    final residentCatIds = rawResidents is List
        ? rawResidents.map((e) => e.toString()).toList()
        : <String>[];

    final rawShort = json['short_label']?.toString().trim();
    final shortLabel = (meta.shortLabel.isNotEmpty)
        ? meta.shortLabel
        : ((rawShort != null && rawShort.isNotEmpty) ? rawShort : name);

    final idRaw = json['id']?.toString();
    final id = (idRaw != null && idRaw.isNotEmpty)
        ? idRaw
        : 'zone_${code.toLowerCase()}';

    return TerritoryModel(
      id: id,
      code: code,
      name: name,
      shortLabel: shortLabel,
      description: (json['description'] ?? '').toString(),
      landmark: (json['landmark'] ?? name).toString(),
      activeCatsCount:
          _parseInt(json['active_cats_count'], fallback: residentCatIds.length),
      collectedCatsCount: _parseInt(json['collected_cats_count']),
      hasUnvisitedCatToday: json['has_unvisited_cat_today'] is bool
          ? json['has_unvisited_cat_today'] as bool
          : true,
      imageAsset: meta.imageAsset,
      residentCatIds: residentCatIds,
      latitude: _parseDouble(json['latitude'], fallback: meta.latitude),
      longitude: _parseDouble(json['longitude'], fallback: meta.longitude),
      mapDx: _parseDouble(json['map_dx'], fallback: meta.mapDx),
      mapDy: _parseDouble(json['map_dy'], fallback: meta.mapDy),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'short_label': shortLabel,
      'description': description,
      'landmark': landmark,
      'active_cats_count': activeCatsCount,
      'collected_cats_count': collectedCatsCount,
      'has_unvisited_cat_today': hasUnvisitedCatToday,
      'resident_cat_ids': residentCatIds,
      'latitude': latitude,
      'longitude': longitude,
      'map_dx': mapDx,
      'map_dy': mapDy,
    };
  }

  TerritoryModel copyWith({
    String? id,
    String? code,
    String? name,
    String? shortLabel,
    String? description,
    String? landmark,
    int? activeCatsCount,
    int? collectedCatsCount,
    bool? hasUnvisitedCatToday,
    String? imageAsset,
    List<String>? residentCatIds,
    double? latitude,
    double? longitude,
    double? mapDx,
    double? mapDy,
  }) {
    return TerritoryModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      description: description ?? this.description,
      landmark: landmark ?? this.landmark,
      activeCatsCount: activeCatsCount ?? this.activeCatsCount,
      collectedCatsCount: collectedCatsCount ?? this.collectedCatsCount,
      hasUnvisitedCatToday: hasUnvisitedCatToday ?? this.hasUnvisitedCatToday,
      imageAsset: imageAsset ?? this.imageAsset,
      residentCatIds: residentCatIds ?? this.residentCatIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapDx: mapDx ?? this.mapDx,
      mapDy: mapDy ?? this.mapDy,
    );
  }
}
