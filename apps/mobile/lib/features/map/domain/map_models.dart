import 'package:latlong2/latlong.dart';

/// Igreja com coordenadas (`GET /churches/map`).
///
/// A API só devolve igrejas com latitude/longitude cadastradas e já filtradas
/// pelo escopo de quem consulta.
class ChurchMapPoint {
  const ChurchMapPoint({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.countryCode,
    required this.pastorCount,
  });

  factory ChurchMapPoint.fromJson(Map<String, dynamic> json) => ChurchMapPoint(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    // Decimal do Prisma chega como string.
    latitude: _double(json['latitude']) ?? 0,
    longitude: _double(json['longitude']) ?? 0,
    countryCode: json['countryCode'] as String? ?? '',
    pastorCount: _int(json['pastorCount']),
  );

  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String countryCode;
  final int pastorCount;

  LatLng get position => LatLng(latitude, longitude);

  String get pastorsText =>
      '$pastorCount ${pastorCount == 1 ? 'pastor' : 'pastores'}';
}

double? _double(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

int _int(Object? value) => switch (value) {
  final num n => n.toInt(),
  final String s => int.tryParse(s) ?? 0,
  _ => 0,
};
