import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  Future<String> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'LembreteAmigoApp/1.0',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final address = data['address'];
          final road =
              address['road'] ??
              address['pedestrian'] ??
              address['suburb'] ??
              '';
          final number = address['house_number'] ?? '';

          if (road.isNotEmpty) {
            return '$road${number.isNotEmpty ? ', $number' : ''}';
          }
        }
        return 'Endereço não encontrado na base';
      }
      return 'Falha ao buscar endereço';
    } catch (e) {
      debugPrint('Erro no geocoding reverso: $e');
      return 'Sem internet para buscar endereço';
    }
  }
}
