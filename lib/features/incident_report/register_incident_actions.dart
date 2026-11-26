import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/hub/cat_action_registry.dart';

/// Registrasi aksi hub profil kucing untuk modul Insiden (PRD §10.2,
/// id baku `incident.report`, tampil selalu). Dipanggil dari
/// `core/hub/register_actions.dart` (milik PM).
void registerIncidentActions() {
  CatActionRegistry.register(
    CatActionSpec(
      id: 'incident.report',
      label: 'Laporkan Kondisi/Insiden',
      icon: Icons.health_and_safety_rounded,
      onTap: (context, catId) {
        final uri = Uri(
          path: '/incidents/create',
          queryParameters: {
            'cat_id': catId,
            'source': 'PROFILE',
            'source_ref': catId,
          },
        );
        context.push(uri.toString());
      },
    ),
  );
}

/// Rute untuk modul lain yang ingin membuka form insiden dengan konteks
/// (mis. Cat Hunter GAME-02 atau Adopsi ADP-13).
String incidentCreateLocation({
  String? catId,
  String source = 'DIRECT',
  String? sourceRef,
  String? category,
}) =>
    Uri(
      path: '/incidents/create',
      queryParameters: {
        if (catId != null && catId.isNotEmpty) 'cat_id': catId,
        'source': source,
        if (sourceRef != null && sourceRef.isNotEmpty) 'source_ref': sourceRef,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).toString();
