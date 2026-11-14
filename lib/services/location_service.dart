import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class UserLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String addressName;
  final bool isMock;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy = 3.5,
    this.addressName = 'Posisi Anda Saat Ini',
    this.isMock = false,
  });

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? addressName,
    bool? isMock,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      addressName: addressName ?? this.addressName,
      isMock: isMock ?? this.isMock,
    );
  }
}

class LocationService {
  static UserLocation? _cachedLocation;
  static DateTime? _lastFetchTime;

  /// Reverse geocode coordinates to get real human-readable street/area name
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'SiKunjungApp/2.0 (sikunjung.field.ops@gmail.com)',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] ??
              address['suburb'] ??
              address['neighbourhood'] ??
              address['village'] ??
              address['residential'];
          final city = address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['county'] ??
              address['state'];
          if (road != null && city != null) {
            return '$road, $city';
          } else if (road != null) {
            return '$road';
          } else if (city != null) {
            return '$city';
          }
        }
        if (data['display_name'] != null) {
          final parts = (data['display_name'] as String).split(',');
          return parts.take(2).join(',').trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Request GPS permission using geolocator
  static Future<bool> requestPermission() async {
    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Location permission request error: $e');
      return true;
    }
  }

  /// Detect location via public IP Geolocation
  /// Crucial fallback when running on plain HTTP on LAN (e.g. http://192.168.x.x:5000)
  /// where modern browsers restrict HTML5 Geolocation API to HTTPS or localhost.
  static Future<UserLocation?> getLocationFromIp() async {
    // 1. Try freeipapi.com
    try {
      final res = await http
          .get(Uri.parse('https://freeipapi.com/api/json'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['cityName'] ?? data['regionName'] ?? 'Jawa Timur';
        if (lat != null && lng != null) {
          final realName = await reverseGeocode(lat, lng) ?? '$city, Jawa Timur';
          return UserLocation(
            latitude: lat,
            longitude: lng,
            accuracy: 25.0,
            addressName: '$realName (Jaringan IP)',
            isMock: false,
          );
        }
      }
    } catch (_) {}

    // 2. Try ipapi.co
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final city = data['city'] ?? data['region'] ?? 'Jawa Timur';
        if (lat != null && lng != null) {
          final realName = await reverseGeocode(lat, lng) ?? '$city, Jawa Timur';
          return UserLocation(
            latitude: lat,
            longitude: lng,
            accuracy: 35.0,
            addressName: '$realName (Jaringan IP)',
            isMock: false,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Get current GPS location with high precision, multi-tiered fallbacks, and real address naming
  static Future<UserLocation?> getCurrentLocation({
    bool forceRefresh = false,
    bool enableHighAccuracy = true,
  }) async {
    // Return cache if fresh within 15 seconds
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < 15) {
      return _cachedLocation;
    }

    // Step 1: Try High-Accuracy Hardware GPS (Satellites & Precision Mobile Sensor)
    try {
      await requestPermission();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: enableHighAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 6),
        ),
      );

      String address =
          'GPS Presisi (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      final realName = await reverseGeocode(position.latitude, position.longitude);
      if (realName != null && realName.isNotEmpty) {
        address = realName;
      }

      final loc = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        addressName: address,
        isMock: position.isMocked,
      );

      _cachedLocation = loc;
      _lastFetchTime = DateTime.now();
      return loc;
    } catch (e) {
      debugPrint('High accuracy GPS error / timeout: $e. Falling back to medium accuracy...');
    }

    // Step 2: Try Medium / Low Accuracy (Wi-Fi & Cellular Tower Triangulation - Fast for Laptops & Indoors)
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 4),
        ),
      );

      String address =
          'GPS Lokasi (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      final realName = await reverseGeocode(position.latitude, position.longitude);
      if (realName != null && realName.isNotEmpty) {
        address = realName;
      }

      final loc = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        addressName: address,
        isMock: position.isMocked,
      );

      _cachedLocation = loc;
      _lastFetchTime = DateTime.now();
      return loc;
    } catch (e) {
      debugPrint('Low accuracy GPS error: $e. Trying last known position...');
    }

    // Step 3: Try Last Known Position (Instant if device recently cached fix)
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        String address =
            'GPS Tersimpan (${lastPos.latitude.toStringAsFixed(4)}, ${lastPos.longitude.toStringAsFixed(4)})';
        final realName = await reverseGeocode(lastPos.latitude, lastPos.longitude);
        if (realName != null && realName.isNotEmpty) {
          address = realName;
        }

        final loc = UserLocation(
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
          accuracy: lastPos.accuracy,
          addressName: address,
          isMock: lastPos.isMocked,
        );

        _cachedLocation = loc;
        _lastFetchTime = DateTime.now();
        return loc;
      }
    } catch (_) {}

    // Step 4: Try Real Public IP Geolocation (Crucial for mobile browser over plain HTTP LAN)
    try {
      final ipLoc = await getLocationFromIp();
      if (ipLoc != null) {
        _cachedLocation = ipLoc;
        _lastFetchTime = DateTime.now();
        return ipLoc;
      }
    } catch (_) {}

    // Step 5: Fallback to Malang Raya Center coordinates
    const fallback = UserLocation(
      latitude: -7.9786,
      longitude: 112.6318,
      accuracy: 15.0,
      addressName: 'Alun-Alun Kota Malang (Default GPS)',
      isMock: true,
    );
    _cachedLocation = fallback;
    _lastFetchTime = DateTime.now();
    return fallback;
  }
}
