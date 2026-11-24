import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:meowtopia/core/hub/cat_action_registry.dart';
import 'package:meowtopia/core/hub/register_actions.dart';
import 'package:meowtopia/core/scanner/qr_parser.dart';
import 'package:meowtopia/core/widgets/loading_indicator.dart';
import 'package:meowtopia/core/widgets/page_transition_overlay.dart';
import 'package:meowtopia/core/widgets/walking_cat_loader.dart';
import 'package:meowtopia/features/feeding_spot/data/feeding_spot_model.dart';
import 'package:meowtopia/features/feeding_spot/feeding_spot_actions.dart';
import 'package:meowtopia/features/feeding_spot/logic/feeding_spot_provider.dart';
import 'package:meowtopia/features/feeding_spot/ui/feeding_widgets.dart';
import 'package:meowtopia/features/feeding_spot/ui/scan_spot_page.dart';

void main() {
  group('QR Parser Unit Tests (MEOW-27 & MEOW-28)', () {
    test('parseQr mengenali MTP1.S.<token> sebagai QR Spot', () {
      final res = parseQr('MTP1.S.TOKEN_SPOT_TULT_01_ABC123');
      expect(res.kind, QrKind.spot);
      expect(res.value, 'TOKEN_SPOT_TULT_01_ABC123');
    });

    test('parseQr mengenali MTP1.C.<token> sebagai QR Kucing', () {
      final res = parseQr('MTP1.C.TOKEN_CAT_01_XYZ789');
      expect(res.kind, QrKind.cat);
      expect(res.value, 'TOKEN_CAT_01_XYZ789');
    });

    test('parseQr memetakan teks lain / kode manual sebagai QrKind.unknown', () {
      final manual = parseQr('SPOT-TULT-01');
      expect(manual.kind, QrKind.unknown);
      expect(manual.value, 'SPOT-TULT-01');

      final invalid = parseQr('https://example.com');
      expect(invalid.kind, QrKind.unknown);
    });
  });

  group('Telkom University 38-Location Denah Mapping Tests (MEOW-26)', () {
    test('Memiliki tepat 38 lokasi resmi sesuai denah Telkom University', () {
      expect(TelkomCampusLocation.all.length, 38);
      expect(TelkomCampusLocation.all.first.number, 1);
      expect(
        TelkomCampusLocation.all.first.name,
        'Telkom University Landmark Tower (TULT)',
      );
      expect(TelkomCampusLocation.all.last.number, 38);
      expect(TelkomCampusLocation.all.last.name, 'Jogging Track');
    });

    test('Resolusi lokasi spot sesuai denah berdasarkan kode dan koordinat', () {
      final tult = TelkomCampusLocation.resolve(
        -6.96930,
        107.62815,
        code: 'SPOT-TULT-01',
      );
      expect(tult.number, 1);
      expect(tult.name, 'Telkom University Landmark Tower (TULT)');

      final gku = TelkomCampusLocation.resolve(
        -6.97195,
        107.62955,
        code: 'SPOT-GKU-01',
      );
      expect(gku.number, 7);
      expect(gku.name, 'Gedung Tokong Nanas (Gd. Kuliah Umum-GKU)');

      final msu = TelkomCampusLocation.resolve(-6.97525, 107.63165);
      expect(msu.number, 37);
      expect(msu.name, 'Masjid Syamsul Ulum');
    });

    test('FeedingSpotModel.fromJson memetakan location_name, image_url, status_reason, dan is_stale', () {
      final model = FeedingSpotModel.fromJson({
        'id': '01JAFS00000000000000000101',
        'code': 'SPOT-GKU-01',
        'name': 'Spot Pakan GKU Gazebo',
        'location_number': 7,
        'location_name': 'Gedung Tokong Nanas (Gd. Kuliah Umum-GKU)',
        'latitude': -6.97195,
        'longitude': 107.62955,
        'status': 'TEMPORARILY_UNAVAILABLE',
        'status_reason': 'Pembersihan wadah pakan',
        'image_url': 'http://127.0.0.1:8000/api/v1/feeding/spots/01JAFS00000000000000000101/photo',
        'has_pending_review': true,
        'aggregate': {
          'verified_count': 5,
          'pending_count': 1,
          'is_stale': false,
        },
      });

      expect(model.code, 'SPOT-GKU-01');
      expect(model.locationNumber, 7);
      expect(model.locationName, 'Gedung Tokong Nanas (Gd. Kuliah Umum-GKU)');
      expect(model.statusReason, 'Pembersihan wadah pakan');
      expect(model.imageUrl, isNotNull);
      expect(model.hasPendingReview, isTrue);
      expect(model.isStale, isFalse);
    });
  });

  group('FeedingSpotProvider QR & Manual Code Scenarios (MEOW-27 & MEOW-28)', () {
    test('Menolak QR kucing dengan pesan QR_WRONG_TYPE', () async {
      final provider = FeedingSpotProvider(isDemo: true);
      expect(
        () => provider.openSession('MTP1.C.CAT_TOKEN_123'),
        throwsA(
          predicate((e) => e.toString().contains('QR_WRONG_TYPE')),
        ),
      );
    });

    test('Membuka sesi dengan QR Spot valid maupun kode manual SPOT-TULT-01', () async {
      final provider = FeedingSpotProvider(isDemo: true);
      final session = await provider.openSession('SPOT-TULT-01');
      expect(session.spot.code, 'SPOT-TULT-01');
      expect(
        session.spot.locationName,
        'Telkom University Landmark Tower (TULT)',
      );
    });
  });

  group('WalkingCatLoader 2.5D Animation Tests', () {
    testWidgets('Merender animasi kucing berjalan dan teks Memuat...', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: WalkingCatLoader())),
        ),
      );

      expect(find.byType(WalkingCatLoader), findsOneWidget);
      expect(find.text('Memuat'), findsOneWidget);
      expect(find.text('.'), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byType(WalkingCatLoader),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // Pastikan animasi melangkah mulus melewati beberapa frame tanpa error
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 2200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Mendukung mode latar gelap (onDark) dan compact', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: WalkingCatLoader(onDark: true, compact: true, size: 120),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Memuat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoadingIndicator global merender WalkingCatLoader dan merapikan titik akhir pesan', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(message: 'Memuat katalog adopsi...'),
          ),
        ),
      );

      expect(find.byType(WalkingCatLoader), findsOneWidget);
      expect(find.text('Memuat katalog adopsi'), findsOneWidget);
      expect(find.text('.'), findsNWidgets(3));

      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('PageTransitionLoaderHost langsung pindah tanpa loading jika halaman cepat, dan tampil tanpa background jika melewati showDelay', (
      tester,
    ) async {
      final transitionNotifier = ValueNotifier<int>(0);
      final router = GoRouter(
        initialLocation: '/a',
        observers: [
          PageTransitionTracker(onTransition: () => transitionNotifier.value++),
        ],
        routes: [
          GoRoute(
            path: '/a',
            builder: (_, __) => const Scaffold(body: Text('Halaman A')),
          ),
          GoRoute(
            path: '/b',
            builder: (_, __) => const Scaffold(body: Text('Halaman B')),
          ),
        ],
      );

      // 1. Skenario cepat (halaman langsung selesai render < showDelay): tidak menampilkan overlay
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PageTransitionLoaderHost(
            router: router,
            transitionListenable: transitionNotifier,
            showDelay: const Duration(milliseconds: 120),
            minVisibleDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 120),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Halaman A'), findsOneWidget);

      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Halaman B'), findsOneWidget);

      // 2. Skenario lag (showDelay = 0 mensimulasikan frame belum selesai saat threshold tercapai)
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PageTransitionLoaderHost(
            router: router,
            transitionListenable: transitionNotifier,
            showDelay: Duration.zero,
            minVisibleDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 120),
            showOnInitialLoad: false,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );

      router.go('/a');
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(WalkingCatLoader), findsOneWidget);
      expect(find.text('Memuat'), findsOneWidget);

      // Setelah selesai render + minVisibleDuration + fade-out, overlay unmount bersih
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Halaman A'), findsOneWidget);
      expect(tester.takeException(), isNull);

      router.dispose();
      transitionNotifier.dispose();
    });

    testWidgets('Pindah branch StatefulShellRoute (/home -> /feeding -> /profile) cepat dan bebas error', (
      tester,
    ) async {
      final transitionNotifier = ValueNotifier<int>(0);
      final router = GoRouter(
        initialLocation: '/home',
        observers: [
          PageTransitionTracker(onTransition: () => transitionNotifier.value++),
        ],
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(body: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, __) => const Center(child: Text('Tab Home')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/feeding',
                    builder: (_, __) =>
                        const Center(child: Text('Tab Feeding')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (_, __) =>
                        const Center(child: Text('Tab Profile')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PageTransitionLoaderHost(
            router: router,
            transitionListenable: transitionNotifier,
            showDelay: const Duration(milliseconds: 120),
            minVisibleDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 120),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Tab Home'), findsOneWidget);

      // Pindah /home -> /feeding langsung tampil tanpa jeda loading buatan
      router.go('/feeding');
      await tester.pump();
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Tab Feeding'), findsOneWidget);

      // Pindah /feeding -> /profile langsung tampil tanpa jeda loading buatan
      router.go('/profile');
      await tester.pump();
      expect(find.byType(WalkingCatLoader), findsNothing);
      expect(find.text('Tab Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);

      router.dispose();
      transitionNotifier.dispose();
    });
  });

  group('Hub Action Registration Tests (MEOW-18)', () {
    testWidgets(
      'registerDefaultCatActions mendaftarkan feeding.start dan menavigasi ke /feeding/scan',
      (tester) async {
        registerDefaultCatActions();
        final action = CatActionRegistry.byId(
          FeedingSpotActions.startFeedingActionKey,
        );
        expect(action, isNotNull);
        expect(action!.id, 'feeding.start');

        String? navigatedUri;
        final router = GoRouter(
          initialLocation: '/cat',
          routes: [
            GoRoute(
              path: '/cat',
              builder: (context, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => action.onTap(context, '01CAT123'),
                  child: const Text('Mulai Makan'),
                ),
              ),
            ),
            GoRoute(
              path: '/feeding/scan',
              builder: (_, state) {
                navigatedUri = state.uri.toString();
                return const Scaffold(body: Text('Scan Page'));
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text('Mulai Makan'));
        await tester.pumpAndSettle();

        expect(navigatedUri, '/feeding/scan?cat_id=01CAT123');
        expect(find.text('Scan Page'), findsOneWidget);
        router.dispose();
      },
    );

    test('openSession menyimpan catId saat dipicu dari aksi Hub kucing', () async {
      final provider = FeedingSpotProvider(isDemo: true);
      final spot = provider.spots.firstWhere((s) => s.isActive);
      final session = await provider.openSession(
        spot.qrToken,
        catId: '01CAT999',
      );
      expect(session.catId, '01CAT999');
    });
  });

  group('Map Tile Error & 14-Day Heatmap Tests (MEOW-26)', () {
    test('FeedingHeatmapPoint.fromJson memetakan kontrak /feeding/heatmap', () {
      final point = FeedingHeatmapPoint.fromJson({
        'spot_id': '01SPOT00000000000000000001',
        'code': 'SPOT-TULT-01',
        'name': 'Shelter TULT',
        'latitude': -6.9693,
        'longitude': 107.62815,
        'window_days': 14,
        'total_feedings': 5,
        'verified_count': 3,
        'pending_count': 2,
        'need_score': 78.57,
        'last_fed_at': '2026-11-24T08:00:00Z',
      });

      expect(point.spotId, '01SPOT00000000000000000001');
      expect(point.verifiedCount, 3);
      expect(point.isLowActivity, isTrue);
      expect(point.activityBucketLabel, 'Jarang tercatat');
      expect(point.coverage, closeTo(3 / 14, 0.001));
    });

    test('FeedingSpotProvider menyediakan heatmapPoints dan toggleHeatmap', () {
      final provider = FeedingSpotProvider(isDemo: true);
      expect(provider.showHeatmap, isFalse);
      expect(provider.heatmapPoints, isNotEmpty);
      expect(
        provider.heatmapPoints.every(
          (p) => provider.spots.any((s) => s.id == p.spotId),
        ),
        isTrue,
      );

      provider.toggleHeatmap();
      expect(provider.showHeatmap, isTrue);
      provider.toggleHeatmap(false);
      expect(provider.showHeatmap, isFalse);
    });

    testWidgets(
      'CampusSpotMap menampilkan banner error tile saat gagal muat & toggle legend heatmap 14 hari',
      (tester) async {
        final provider = FeedingSpotProvider(isDemo: true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CampusSpotMap(
                spots: provider.spots,
                isDemo: true,
                heatmapPoints: provider.heatmapPoints,
                simulateTileError: true,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(
          find.text(
            'Peta gagal dimuat atau tidak ada koneksi. Daftar spot tetap dapat digunakan.',
          ),
          findsOneWidget,
        );
        expect(find.text('Rutin (14h)'), findsNothing);

        await tester.tap(find.byTooltip('Tampilkan heatmap 14 hari'));
        await tester.pump();
        expect(find.text('Jarang'), findsOneWidget);
        expect(find.text('Cukup'), findsOneWidget);
        expect(find.text('Rutin (14h)'), findsOneWidget);

        await tester.tap(find.byTooltip('Tutup peringatan peta'));
        await tester.pump();
        expect(
          find.text(
            'Peta gagal dimuat atau tidak ada koneksi. Daftar spot tetap dapat digunakan.',
          ),
          findsNothing,
        );
      },
    );
  });

  group('Camera Permission UX & QR Error Debounce Tests (MEOW-27)', () {
    test(
      'QrScanCooldown mencegah spam scan QR gagal yang sama selama durasi cooldown',
      () {
        final cooldown = QrScanCooldown(
          cooldown: const Duration(milliseconds: 2500),
        );
        final t0 = DateTime(2026, 11, 25, 10, 0, 0);

        expect(cooldown.shouldIgnore('MTP1.C.CAT01', now: t0), isFalse);

        cooldown.recordFailure('MTP1.C.CAT01', now: t0);
        // Token yang sama dalam 1 detik diabaikan
        expect(
          cooldown.shouldIgnore(
            'MTP1.C.CAT01',
            now: t0.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        // Token berbeda tetap diproses langsung
        expect(
          cooldown.shouldIgnore(
            'MTP1.S.SPOT-TULT-01',
            now: t0.add(const Duration(seconds: 1)),
          ),
          isFalse,
        );
        // Setelah cooldown berlalu, token yang sama boleh dicoba lagi
        expect(
          cooldown.shouldIgnore(
            'MTP1.C.CAT01',
            now: t0.add(const Duration(seconds: 3)),
          ),
          isFalse,
        );

        cooldown.recordFailure('MTP1.C.CAT01', now: t0);
        cooldown.reset();
        expect(
          cooldown.shouldIgnore(
            'MTP1.C.CAT01',
            now: t0.add(const Duration(milliseconds: 500)),
          ),
          isFalse,
        );
      },
    );

    test(
      'describeCameraScannerError membedakan izin ditolak dan kamera tidak tersedia',
      () {
        final denied = describeCameraScannerError(
          MobileScannerErrorCode.permissionDenied,
        );
        expect(denied.title, 'Izin Kamera Ditolak');
        expect(denied.showOpenSettings, isTrue);

        final unsupported = describeCameraScannerError(
          MobileScannerErrorCode.unsupported,
        );
        expect(unsupported.title, 'Kamera Tidak Tersedia');
        expect(unsupported.showOpenSettings, isFalse);

        final generic = describeCameraScannerError(
          MobileScannerErrorCode.genericError,
        );
        expect(generic.title, 'Kamera Tidak Dapat Dibuka');
        expect(generic.showOpenSettings, isTrue);
      },
    );

    testWidgets(
      'ScanSpotPage mendukung input kode manual fallback saat QR salah dan saat valid',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = FeedingSpotProvider(isDemo: true);
        final router = GoRouter(
          initialLocation: '/feeding/scan',
          routes: [
            GoRoute(
              path: '/feeding/scan',
              builder: (_, __) => const ScanSpotPage(),
            ),
            GoRoute(
              path: '/feeding/record',
              builder: (_, __) => const Scaffold(body: Text('Record Page')),
            ),
          ],
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<FeedingSpotProvider>.value(
            value: provider,
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        // Buka dialog input manual dan masukkan QR kucing (harus muncul QR_WRONG_TYPE)
        final manualBtn = find.text('Input kode manual spot');
        await tester.ensureVisible(manualBtn);
        await tester.tap(manualBtn);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'MTP1.C.CAT01');
        await tester.tap(find.text('Gunakan Kode'));
        await tester.pumpAndSettle();

        expect(find.textContaining('QR_WRONG_TYPE'), findsOneWidget);

        // Masukkan kode manual spot valid -> berpindah ke halaman record
        final activeSpot = provider.spots.firstWhere((s) => s.isActive);
        await tester.ensureVisible(manualBtn);
        await tester.tap(manualBtn);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), activeSpot.code);
        await tester.tap(find.text('Gunakan Kode'));
        await tester.pumpAndSettle();

        expect(find.text('Record Page'), findsOneWidget);
        expect(provider.session?.spot.id, activeSpot.id);
        router.dispose();
      },
    );
  });
}
