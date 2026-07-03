import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class SosLocationResult {
  final double? latitude;
  final double? longitude;
  final String? errorMessage;

  const SosLocationResult._({this.latitude, this.longitude, this.errorMessage});

  factory SosLocationResult.success(Position position) {
    return SosLocationResult._(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  factory SosLocationResult.failure(String message) {
    return SosLocationResult._(errorMessage: message);
  }

  bool get hasLocation => latitude != null && longitude != null;

  String? get mapsUrl {
    if (!hasLocation) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<SosLocationResult> getCurrentSosLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return SosLocationResult.failure('Localizacao desativada no aparelho.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return SosLocationResult.failure('Permissao de localizacao negada.');
      }

      if (permission == LocationPermission.deniedForever) {
        return SosLocationResult.failure(
          'Permissao de localizacao bloqueada nas configuracoes.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return SosLocationResult.success(position);
    } catch (e) {
      debugPrint('Erro ao obter localizacao SOS: $e');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return SosLocationResult.success(lastKnown);
        }
      } catch (_) {}
      return SosLocationResult.failure('Nao foi possivel obter localizacao.');
    }
  }
}
