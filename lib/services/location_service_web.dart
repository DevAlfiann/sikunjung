// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'location_service.dart';

Future<bool> requestLocationPermission() async {
  try {
    final pos = await html.window.navigator.geolocation
        .getCurrentPosition(enableHighAccuracy: true)
        .timeout(const Duration(seconds: 8));
    return pos.coords != null;
  } catch (_) {
    return false;
  }
}

Future<UserLocation?> getUserCurrentLocation() async {
  try {
    final pos = await html.window.navigator.geolocation
        .getCurrentPosition(enableHighAccuracy: true)
        .timeout(const Duration(seconds: 8));
    final coords = pos.coords;
    if (coords != null) {
      final lat = coords.latitude?.toDouble() ?? -7.7956;
      final lng = coords.longitude?.toDouble() ?? 110.3695;
      final acc = coords.accuracy?.toDouble() ?? 3.5;
      return UserLocation(
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        addressName:
            'Lokasi GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        isMock: false,
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}
