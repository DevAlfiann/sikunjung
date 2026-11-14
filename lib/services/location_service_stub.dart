import 'location_service.dart';

Future<bool> requestLocationPermission() async {
  return true;
}

Future<UserLocation?> getUserCurrentLocation() async {
  return const UserLocation(
    latitude: -7.9786,
    longitude: 112.6318,
    accuracy: 3.0,
    addressName: 'Jl. Besar Ijen, Kota Malang (GPS Terdeteksi)',
    isMock: true,
  );
}
