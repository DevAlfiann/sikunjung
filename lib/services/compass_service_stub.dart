import 'dart:async';
import 'compass_service.dart';

Stream<CompassReading>? getPlatformCompassStream() {
  return null;
}

Future<bool> requestPlatformCompassPermission() async {
  return true;
}

