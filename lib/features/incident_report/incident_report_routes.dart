import 'package:go_router/go_router.dart';

import 'data/incident_enums.dart';
import 'ui/caretaker_tasks_page.dart';
import 'ui/create_incident_page.dart';
import 'ui/incident_detail_page.dart';
import 'ui/incident_list_page.dart';
import 'ui/vet_contacts_page.dart';

/// Route modul Emergency Incident Reporting (Optimind).
///
/// - `/incidents` — beranda Lapor dan daftar tiket saya
/// - `/incidents/create?cat_id=&source=&source_ref=&category=` — form laporan
///   (juga menerima `extra: {'cat_id': ...}` dari hub aksi)
/// - `/incidents/tasks` — tugas relawan
/// - `/incidents/vets` — kontak dokter hewan
/// - `/incidents/:id` — detail tiket dan riwayat status
final List<RouteBase> incidentReportRoutes = [
  GoRoute(
    path: '/incidents',
    builder: (context, state) => const IncidentListPage(),
    routes: [
      GoRoute(
        path: 'create',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final extra = state.extra is Map ? state.extra as Map : const {};
          String? pick(String key) {
            final v = (q[key] ?? extra[key])?.toString().trim();
            return (v == null || v.isEmpty) ? null : v;
          }

          final catId = pick('cat_id');
          final rawSource = pick('source');
          final source = rawSource == null
              ? (catId != null ? IncidentSource.profile : IncidentSource.direct)
              : IncidentSource.fromCode(rawSource);
          final rawCategory = pick('category');
          return CreateIncidentPage(
            catId: catId,
            source: source,
            sourceRef: pick('source_ref') ??
                (source == IncidentSource.profile ? catId : null),
            initialCategory: rawCategory == null
                ? null
                : IncidentCategory.fromCode(rawCategory),
          );
        },
      ),
      GoRoute(
        path: 'tasks',
        builder: (context, state) => const CaretakerTasksPage(),
      ),
      GoRoute(
        path: 'vets',
        builder: (context, state) => const VetContactsPage(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            IncidentDetailPage(incidentId: state.pathParameters['id']!),
      ),
    ],
  ),
];
