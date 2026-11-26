import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/scanner/qr_parser.dart';
import '../../../core/storage/token_storage.dart';
import '../cat_dex/data/models/cat_model.dart';
import '../cat_dex/data/repositories/mock_cat_repository.dart';
import '../constants/app_assets.dart';
import '../data/cat_hunter_model.dart';
import '../data/cat_hunter_service.dart';
import '../map_territory/models/territory_model.dart';

class CatHunterProvider extends ChangeNotifier {
  final CatHunterService _service;
  final TokenStorage _tokenStorage;
  final MockCatRepository _mockRepo;

  List<CatModel> _cats = [];
  List<TerritoryModel> _zones = [];
  CatHunterProfileModel? _profile;

  bool _hasInitialized = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isOfflineFallback = true;
  String? _errorMessage;
  String? _selectedAvatarCatId;

  CatHunterProvider({
    CatHunterService? service,
    TokenStorage? tokenStorage,
    MockCatRepository? mockRepo,
  })  : _service = service ?? CatHunterService(),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _mockRepo = mockRepo ?? MockCatRepository() {
    _seedFromMock();
  }

  void _seedFromMock() {
    _cats = List<CatModel>.from(_mockRepo.allCats);
    _zones = List<TerritoryModel>.from(_mockRepo.territories);
    _selectedAvatarCatId = _mockRepo.selectedAvatarCat?.id;
    _syncZoneUnvisitedFlags();
  }

  // Getters
  List<CatModel> get allCats => List.unmodifiable(_cats);
  List<CatModel> get collectedCats =>
      _cats.where((c) => c.isCollected).toList();
  List<CatModel> get encounteredCats =>
      _cats.where((c) => c.encounterCount > 0).toList();
  List<CatModel> get uncollectedCats =>
      _cats.where((c) => !c.isCollected).toList();
  List<CatModel> get cafeActiveCats =>
      _cats.where((c) => c.isCollected && c.isCurrentlyInCafe).toList();

  List<TerritoryModel> get territories => List.unmodifiable(_zones);
  CatHunterProfileModel? get profile => _profile;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isOfflineFallback => _isOfflineFallback;
  String? get errorMessage => _errorMessage;

  int get totalEncounters =>
      _profile?.totalEncounters ??
      _cats.fold<int>(0, (sum, cat) => sum + cat.encounterCount);

  int get totalCatsCollected =>
      _profile?.totalCatsCollected ?? collectedCats.length;

  int get totalCatalogCats =>
      _profile?.totalCatalogCats ?? _cats.length;

  int get maxEncounterCount {
    var highest = 0;
    for (final cat in _cats) {
      if (cat.encounterCount > highest) {
        highest = cat.encounterCount;
      }
    }
    return highest;
  }

  int get lockedNamesCount => _cats.where((c) => c.isNameLocked).length;

  String get dynamicTitle {
    if (_profile != null && _profile!.title.isNotEmpty) {
      return _profile!.title;
    }
    final total = totalEncounters;
    if (total >= 15) return 'Pawang Kucing Tel-U';
    if (total >= 5) return 'Sahabat Kucing Kampus';
    return 'Pendatang Baru';
  }

  CatModel? get bestBuddyCat {
    if (_profile?.bestBuddy != null) return _profile!.bestBuddy;
    final metCats = encounteredCats;
    if (metCats.isEmpty) return null;
    CatModel best = metCats.first;
    for (final cat in metCats.skip(1)) {
      if (cat.encounterCount > best.encounterCount) {
        best = cat;
      }
    }
    return best;
  }

  CatModel? get selectedAvatarCat {
    final favorite = _cats.where((c) => c.isFavoriteAvatar).toList();
    if (favorite.isNotEmpty) return favorite.first;
    if (_profile?.favoriteAvatar != null) return _profile!.favoriteAvatar;

    final metCats = encounteredCats;
    if (metCats.isEmpty) return null;
    if (_selectedAvatarCatId != null) {
      for (final cat in metCats) {
        if (cat.id == _selectedAvatarCatId) {
          return cat;
        }
      }
    }
    return metCats.first;
  }

  String get selectedProfileAvatarAsset =>
      selectedAvatarCat?.headPoseAsset ?? AppAssets.catOrenHead;

  CatModel getCatById(String id) {
    for (final cat in _cats) {
      if (cat.id == id) return cat;
    }
    return _cats.isNotEmpty ? _cats.first : _mockRepo.allCats.first;
  }

  CatModel? findCatByIdOrNull(String id) {
    for (final cat in _cats) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  CatModel getCatByQr(String qr) {
    final normalized = qr.trim().toUpperCase();
    for (final cat in _cats) {
      if (cat.qrHash.toUpperCase() == normalized ||
          cat.uniqueCode.toUpperCase() == normalized ||
          cat.id == qr) {
        return cat;
      }
    }
    return _cats.isNotEmpty ? _cats.first : _mockRepo.allCats.first;
  }

  bool isScannedToday(String catId) {
    return getCatById(catId).isScannedToday;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isNetworkOrAuthFailure(Object error) {
    if (error is ApiException) {
      final status = error.statusCode;
      // Error 401 (belum login/token kadaluarsa), null (timeout/offline), atau 5xx
      // ditangani dengan Graceful Fallback ke MockCatRepository.
      return status == null || status == 401 || status >= 500;
    }
    return true;
  }

  void _activateFallback({String? note}) {
    if (!_isOfflineFallback) {
      _isOfflineFallback = true;
    }
    if (_cats.isEmpty) {
      _seedFromMock();
    }
    _errorMessage = note;
  }

  void _replaceCat(CatModel updated) {
    final index = _cats.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _cats[index] = updated;
    } else {
      _cats.add(updated);
    }
    _syncZoneUnvisitedFlags();
  }

  void _syncZoneUnvisitedFlags() {
    if (_zones.isEmpty) return;
    _zones = _zones.map((zone) {
      final residentIds = zone.residentCatIds.isNotEmpty
          ? zone.residentCatIds
          : _cats
              .where((c) => c.zone == zone.name || c.zoneCode == zone.code)
              .map((c) => c.id)
              .toList();

      final hasUnvisited = residentIds.any((id) {
        final cat = findCatByIdOrNull(id);
        if (cat == null) return false;
        return !cat.isScannedToday && cat.isEncounterable;
      });

      final collectedInZone = residentIds
          .where((id) => findCatByIdOrNull(id)?.isCollected ?? false)
          .length;

      return zone.copyWith(
        residentCatIds: residentIds,
        activeCatsCount:
            residentIds.isNotEmpty ? residentIds.length : zone.activeCatsCount,
        collectedCatsCount: collectedInZone,
        hasUnvisitedCatToday: hasUnvisited,
      );
    }).toList();
  }

  // ------------------------------------------------------------------
  // Sinkronisasi Data Backend (dengan Graceful Fallback)
  // ------------------------------------------------------------------

  Future<void> loadAll({bool force = false}) async {
    if (_isLoading) return;
    if (_hasInitialized && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasToken = await _tokenStorage.hasToken();
      if (!hasToken) {
        _isOfflineFallback = true;
        if (!_hasInitialized) {
          _seedFromMock();
        }
        _hasInitialized = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final results = await Future.wait<dynamic>([
        _service.getCats(),
        _service.getZones(),
        _service.getProfile(),
      ]);

      final cats = results[0] as List<CatModel>;
      final zones = results[1] as List<TerritoryModel>;
      final profile = results[2] as CatHunterProfileModel;

      if (cats.isNotEmpty) {
        _cats = cats;
      }
      if (zones.isNotEmpty) {
        _zones = zones;
      }
      _profile = profile;
      _selectedAvatarCatId = profile.favoriteAvatar?.id;
      _isOfflineFallback = false;
      _hasInitialized = true;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
        _hasInitialized = true;
      } else {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCatalog() async {
    try {
      if (!await _tokenStorage.hasToken()) {
        _activateFallback();
        notifyListeners();
        return;
      }
      final cats = await _service.getCats();
      if (cats.isNotEmpty) {
        _cats = cats;
      }
      _isOfflineFallback = false;
      _errorMessage = null;
      _syncZoneUnvisitedFlags();
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
      } else {
        _errorMessage = e.toString();
      }
    }
    notifyListeners();
  }

  Future<void> refreshZones() async {
    try {
      if (!await _tokenStorage.hasToken()) {
        _activateFallback();
        notifyListeners();
        return;
      }
      final zones = await _service.getZones();
      if (zones.isNotEmpty) {
        _zones = zones;
      }
      _isOfflineFallback = false;
      _errorMessage = null;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
      } else {
        _errorMessage = e.toString();
      }
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      if (!await _tokenStorage.hasToken()) {
        _activateFallback();
        notifyListeners();
        return;
      }
      _profile = await _service.getProfile();
      _selectedAvatarCatId = _profile?.favoriteAvatar?.id;
      _isOfflineFallback = false;
      _errorMessage = null;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
      } else {
        _errorMessage = e.toString();
      }
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Aksi Permainan: Scan-Check, Encounter, Rename, Avatar
  // ------------------------------------------------------------------

  /// Mengecek QR kalung & cooldown harian kucing via API (fallback ke cache/mock jika offline).
  Future<ScanCheckResult> checkScan(String catId, {String? qrCode}) async {
    _errorMessage = null;
    String? trimmedCode;

    if (qrCode != null && qrCode.trim().isNotEmpty) {
      final parsed = parseQr(qrCode);
      if (parsed.kind == QrKind.spot) {
        throw ApiException(
          message: 'QR ini milik Feeding Spot, bukan kalung kucing.',
          statusCode: 422,
          code: 'QR_MISMATCH',
        );
      }
      trimmedCode = qrCode.trim();
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      final hasToken = await _tokenStorage.hasToken();
      if (!hasToken) {
        _activateFallback();
        return _localScanCheck(catId);
      }

      final result = await _service.scanCheck(catId, code: trimmedCode);
      _isOfflineFallback = false;
      _replaceCat(result.cat);
      return result;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
        return _localScanCheck(catId);
      }
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  ScanCheckResult _localScanCheck(String catId) {
    final cat = getCatById(catId);
    final available = cat.isEncounterable;
    final canScan = available && !cat.isScannedToday;
    return ScanCheckResult(
      cat: cat,
      canScanToday: canScan,
      isAvailable: available,
      lastScannedAt: cat.lastScannedDate,
      nextAvailableAt: cat.nextAvailableAt,
      message: canScan
          ? 'Kucing siap disapa.'
          : 'Kamu sudah menyapa kucing ini hari ini.',
    );
  }

  /// Mengirim penyelesaian 2 fase mengelus ke backend (fallback ke mock jika offline/belum login).
  Future<CatModel?> completeEncounter(String catId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasToken = await _tokenStorage.hasToken();
      if (!hasToken) {
        _activateFallback();
        return _recordLocalEncounter(catId);
      }

      final result = await _service.completeEncounter(catId, phasesCompleted: 2);
      _isOfflineFallback = false;
      _replaceCat(result.cat);

      // Segarkan zona & profil secara senyap agar indikator zona dan statistik tetap sinkron.
      _refreshZonesAndProfileQuietly();
      return result.cat;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
        return _recordLocalEncounter(catId);
      }
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  CatModel _recordLocalEncounter(String catId) {
    final isInMock = _mockRepo.allCats.any((c) => c.id == catId);
    if (isInMock) {
      final updatedMock = _mockRepo.recordEncounter(catId);
      _replaceCat(updatedMock);
      return updatedMock;
    }
    final old = getCatById(catId);
    final updated = old.copyWith(
      isCollected: true,
      isCurrentlyInCafe: true,
      encounterCount: old.encounterCount + 1,
      lastScannedDate: DateTime.now(),
      canScanToday: false,
    );
    _replaceCat(updated);
    return updated;
  }

  Future<void> _refreshZonesAndProfileQuietly() async {
    try {
      final zones = await _service.getZones();
      final profile = await _service.getProfile();
      if (zones.isNotEmpty) {
        _zones = zones;
      }
      _profile = profile;
      _selectedAvatarCatId = profile.favoriteAvatar?.id;
      notifyListeners();
    } catch (_) {
      // Abaikan kegagalan sinkronisasi sekunder; cache lokal sudah terbarui.
    }
  }

  /// Memberi nama permanen baru (5x pertemuan). Mengembalikan null jika sukses, atau pesan error.
  Future<String?> renameCat(String catId, String newName) async {
    final trimmed = newName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return 'Nama tidak boleh kosong.';
    }
    if (trimmed.length < 2 || trimmed.length > 20) {
      return 'Panjang nama harus 2–20 karakter.';
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasToken = await _tokenStorage.hasToken();
      if (!hasToken) {
        _activateFallback();
        return _renameLocally(catId, trimmed);
      }

      final updated = await _service.renameCat(catId, trimmed);
      _isOfflineFallback = false;
      _replaceCat(updated);
      _refreshZonesAndProfileQuietly();
      return null;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
        return _renameLocally(catId, trimmed);
      }
      final message = e.toString();
      _errorMessage = message;
      return message;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  String? _renameLocally(String catId, String trimmed) {
    final isInMock = _mockRepo.allCats.any((c) => c.id == catId);
    if (isInMock) {
      final err = _mockRepo.renameCat(catId, trimmed);
      if (err != null) return err;
      _replaceCat(_mockRepo.getCatById(catId));
      return null;
    }

    final normalized = trimmed.toLowerCase();
    final duplicate = _cats.any(
      (c) => c.id != catId && c.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) {
      return 'Nama ini sudah dipakai kucing lain, pilih nama lain ya!';
    }

    final old = getCatById(catId);
    if (!old.canBeNamed) {
      return 'Kucing ini belum memenuhi syarat 5x pertemuan atau namanya sudah terkunci.';
    }

    _replaceCat(
      old.copyWith(
        name: trimmed,
        isNameLocked: true,
        canRename: false,
      ),
    );
    return null;
  }

  /// Menyimpan pilihan avatar favorit. Mengembalikan null jika sukses, atau pesan error.
  Future<String?> setFavoriteAvatar(String catId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasToken = await _tokenStorage.hasToken();
      if (!hasToken) {
        _activateFallback();
        _selectLocalAvatar(catId);
        return null;
      }

      final updated = await _service.setFavoriteAvatar(catId);
      _isOfflineFallback = false;
      _selectedAvatarCatId = updated.id;
      _cats = _cats
          .map((c) => c.id == updated.id
              ? updated.copyWith(isFavoriteAvatar: true)
              : c.copyWith(isFavoriteAvatar: false))
          .toList();
      _refreshZonesAndProfileQuietly();
      return null;
    } catch (e) {
      if (_isNetworkOrAuthFailure(e)) {
        _activateFallback();
        _selectLocalAvatar(catId);
        return null;
      }
      final message = e.toString();
      _errorMessage = message;
      return message;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _selectLocalAvatar(String catId) {
    _mockRepo.selectProfileAvatar(catId);
    _selectedAvatarCatId = catId;
    _cats = _cats
        .map((c) => c.copyWith(isFavoriteAvatar: c.id == catId))
        .toList();
  }

  // ------------------------------------------------------------------
  // Simulasi Demo Debug Sheet (Mode Demo / Lokal)
  // ------------------------------------------------------------------

  void resetAllDailyCooldowns() {
    _mockRepo.resetAllDailyCooldowns();
    _cats = _cats
        .map((c) => c.copyWith(
              clearLastScannedDate: true,
              canScanToday: c.isEncounterable,
              clearNextAvailableAt: true,
            ))
        .toList();
    _syncZoneUnvisitedFlags();
    notifyListeners();
  }

  void simulateFourEncounters(String catId) {
    _mockRepo.simulateFourEncounters(catId);
    final old = getCatById(catId);
    _replaceCat(
      old.copyWith(
        encounterCount: 4,
        isNameLocked: false,
        canRename: false,
        isCollected: true,
        isCurrentlyInCafe: true,
        clearLastScannedDate: true,
        canScanToday: old.isEncounterable,
        clearNextAvailableAt: true,
      ),
    );
    notifyListeners();
  }
}
