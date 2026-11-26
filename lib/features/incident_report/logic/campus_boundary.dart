import 'package:latlong2/latlong.dart';

/// Batas kampus Telkom University Bandung untuk validasi lokasi insiden.
///
/// Salinan persis poligon peta Spot Makan (`CampusSpotMap` di
/// `features/feeding_spot/ui/feeding_widgets.dart`, 76 titik OSM Way 557649490
/// + Kantin Teknik) yang juga dipakai backend
/// (`FeedingSpotManagementService::TELKOM_BOUNDARY`). Poligon aslinya privat,
/// jadi disalin di sini; bila batas kampus diubah, samakan ketiganya.
class CampusBoundary {
  CampusBoundary._();

  static const List<LatLng> points = [
    LatLng(-6.9697046, 107.6307312),
    LatLng(-6.9702850, 107.6309752),
    LatLng(-6.9703549, 107.6310401),
    LatLng(-6.9704453, 107.6311774),
    LatLng(-6.9709586, 107.6319851),
    LatLng(-6.9714512, 107.6326704),
    LatLng(-6.9720409, 107.6335066),
    LatLng(-6.9721221, 107.6334442),
    LatLng(-6.9721713, 107.6335354),
    LatLng(-6.9730965, 107.6334992),
    LatLng(-6.9731498, 107.6334415),
    LatLng(-6.9732669, 107.6333047),
    LatLng(-6.9739019, 107.6326382),
    LatLng(-6.9739511, 107.6326248),
    LatLng(-6.9740250, 107.6326088),
    LatLng(-6.9740603, 107.6325980),
    LatLng(-6.9744437, 107.6325403),
    LatLng(-6.9747597, 107.6324340),
    LatLng(-6.9748191, 107.6324698),
    LatLng(-6.9750573, 107.6325926),
    LatLng(-6.9752184, 107.6326986),
    LatLng(-6.9754460, 107.6329333),
    LatLng(-6.9755306, 107.6329688),
    LatLng(-6.9756371, 107.6329654),
    LatLng(-6.9760504, 107.6329319),
    LatLng(-6.9761877, 107.6328865),
    LatLng(-6.9762394, 107.6327978),
    LatLng(-6.9774654, 107.6315466),
    LatLng(-6.9776200, 107.6313900),
    LatLng(-6.9779500, 107.6317500),
    LatLng(-6.9786500, 107.6310800),
    LatLng(-6.9778500, 107.6306200),
    LatLng(-6.9777357, 107.6305917),
    LatLng(-6.9776897, 107.6301411),
    LatLng(-6.9776505, 107.6299500),
    LatLng(-6.9776405, 107.6298387),
    LatLng(-6.9776425, 107.6297320),
    LatLng(-6.9776837, 107.6294491),
    LatLng(-6.9777157, 107.6292425),
    LatLng(-6.9777250, 107.6290642),
    LatLng(-6.9771872, 107.6290481),
    LatLng(-6.9756444, 107.6290561),
    LatLng(-6.9753076, 107.6290521),
    LatLng(-6.9752314, 107.6290444),
    LatLng(-6.9752204, 107.6290434),
    LatLng(-6.9751658, 107.6289844),
    LatLng(-6.9748710, 107.6287074),
    LatLng(-6.9743039, 107.6282313),
    LatLng(-6.9738060, 107.6277861),
    LatLng(-6.9732909, 107.6282461),
    LatLng(-6.9731484, 107.6283976),
    LatLng(-6.9719577, 107.6283936),
    LatLng(-6.9719437, 107.6284074),
    LatLng(-6.9719344, 107.6284312),
    LatLng(-6.9719360, 107.6284644),
    LatLng(-6.9719360, 107.6284781),
    LatLng(-6.9713819, 107.6284996),
    LatLng(-6.9713727, 107.6281416),
    LatLng(-6.9713512, 107.6280972),
    LatLng(-6.9712548, 107.6268379),
    LatLng(-6.9712235, 107.6267521),
    LatLng(-6.9707124, 107.6267702),
    LatLng(-6.9702045, 107.6267943),
    LatLng(-6.9696254, 107.6275329),
    LatLng(-6.9696164, 107.6275597),
    LatLng(-6.9694956, 107.6277231),
    LatLng(-6.9685079, 107.6275742),
    LatLng(-6.9684786, 107.6280342),
    LatLng(-6.9684853, 107.6284620),
    LatLng(-6.9692014, 107.6286001),
    LatLng(-6.9696267, 107.6303470),
    LatLng(-6.9697046, 107.6307312),
  ];

  /// Ray-casting, rumus yang sama dengan Spot Makan dan backend.
  static bool contains(LatLng point) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final xi = points[i].latitude;
      final yi = points[i].longitude;
      final xj = points[j].latitude;
      final yj = points[j].longitude;
      final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
