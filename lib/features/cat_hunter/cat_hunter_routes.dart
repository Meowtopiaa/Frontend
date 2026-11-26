import 'package:go_router/go_router.dart';

import 'qr_scan/views/qr_scan_screen.dart';
import 'ui/cat_dex_page.dart';

final List<RouteBase> catHunterRoutes = [
  GoRoute(
    path: '/hunter',
    builder: (context, state) => const CatDexPage(),
    routes: [
      GoRoute(
        path: 'encounter',
        builder: (context, state) => const QrScanScreen(),
      ),
    ],
  ),
];
