import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'compass_service_stub.dart'
    if (dart.library.html) 'compass_service_web.dart' as platform_compass;

class CompassReading {
  final double heading; // 0..360° clockwise from North
  final double pitch; // tilt front/back in degrees
  final double roll; // tilt left/right in degrees
  final double? accuracy;
  final double? accelX;
  final double? accelY;
  final double? accelZ;
  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;
  final double? magX;
  final double? magY;
  final double? magZ;

  const CompassReading({
    required this.heading,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.accuracy,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
  });

  String get cardinalLabel {
    final h = (heading % 360 + 360) % 360;
    if (h >= 337.5 || h < 22.5) return 'Utara (N)';
    if (h >= 22.5 && h < 67.5) return 'Timur Laut (NE)';
    if (h >= 67.5 && h < 112.5) return 'Timur (E)';
    if (h >= 112.5 && h < 157.5) return 'Tenggara (SE)';
    if (h >= 157.5 && h < 202.5) return 'Selatan (S)';
    if (h >= 202.5 && h < 247.5) return 'Barat Daya (SW)';
    if (h >= 247.5 && h < 292.5) return 'Barat (W)';
    return 'Barat Laut (NW)';
  }
}

class CompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  StreamController<CompassReading>? _controller;
  StreamSubscription? _platformSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _accelX = 0.42;
  double _accelY = 9.78;
  double _accelZ = 0.15;

  double _gyroX = -0.012;
  double _gyroY = 0.005;
  double _gyroZ = 0.034;

  double _magX = 24.6;
  double _magY = -18.2;
  double _magZ = 42.1;

  double _heading = 45.0;
  double _pitch = 12.0;
  double _roll = -3.0;

  Stream<CompassReading> get stream {
    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<CompassReading>.broadcast(
        onListen: _startListening,
        onCancel: _stopListening,
      );
    }
    return _controller!.stream;
  }

  Future<bool> requestPermission() async {
    return platform_compass.requestPlatformCompassPermission();
  }

  void _startListening() {
    final webStream = platform_compass.getPlatformCompassStream();
    if (webStream != null) {
      _platformSub = webStream.listen(
        (reading) {
          _heading = reading.heading;
          _pitch = reading.pitch;
          _roll = reading.roll;
          if (reading.accelX != null) _accelX = reading.accelX!;
          if (reading.accelY != null) _accelY = reading.accelY!;
          if (reading.accelZ != null) _accelZ = reading.accelZ!;
          if (reading.gyroX != null) _gyroX = reading.gyroX!;
          if (reading.gyroY != null) _gyroY = reading.gyroY!;
          if (reading.gyroZ != null) _gyroZ = reading.gyroZ!;

          _emitCurrent(accuracy: reading.accuracy);
        },
        onError: (_) {},
      );
      return;
    }

    // Native mobile fallback using sensors_plus
    try {
      _accelSub = accelerometerEventStream().listen((event) {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
        _computeOrientation();
      }, onError: (_) {});
    } catch (_) {}

    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        _gyroX = event.x;
        _gyroY = event.y;
        _gyroZ = event.z;
        _emitCurrent();
      }, onError: (_) {});
    } catch (_) {}

    try {
      _magSub = magnetometerEventStream().listen((event) {
        _magX = event.x;
        _magY = event.y;
        _magZ = event.z;
        _computeOrientation();
      }, onError: (_) {});
    } catch (_) {}
  }

  void _computeOrientation() {
    // 1. Calculate pitch & roll from gravity vector
    final normA = math.sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    if (normA > 0.1) {
      final axN = _accelX / normA;
      final ayN = _accelY / normA;
      final azN = _accelZ / normA;

      // Pitch (rotation around X) and Roll (rotation around Y)
      _pitch = math.atan2(ayN, math.sqrt(axN * axN + azN * azN)) * 180 / math.pi;
      _roll = math.atan2(-axN, azN) * 180 / math.pi;

      final pitchRad = _pitch * math.pi / 180;
      final rollRad = _roll * math.pi / 180;

      // Tilt-compensated magnetic heading
      final cosP = math.cos(pitchRad);
      final sinP = math.sin(pitchRad);
      final cosR = math.cos(rollRad);
      final sinR = math.sin(rollRad);

      final mxComp = _magX * cosP + _magZ * sinP;
      final myComp = _magX * sinR * sinP + _magY * cosR - _magZ * sinR * cosP;

      double heading = math.atan2(-mxComp, myComp) * 180 / math.pi;
      if (heading < 0) heading += 360;
      _heading = heading;
    } else {
      // Flat 2D fallback
      double heading = math.atan2(_magY, _magX) * 180 / math.pi;
      if (heading < 0) heading += 360;
      _heading = heading;
    }

    _emitCurrent();
  }

  void _emitCurrent({double? accuracy}) {
    if (_controller == null || _controller!.isClosed) return;
    _controller!.add(
      CompassReading(
        heading: _heading,
        pitch: _pitch,
        roll: _roll,
        accuracy: accuracy ?? 1.2,
        accelX: _accelX,
        accelY: _accelY,
        accelZ: _accelZ,
        gyroX: _gyroX,
        gyroY: _gyroY,
        gyroZ: _gyroZ,
        magX: _magX,
        magY: _magY,
        magZ: _magZ,
      ),
    );
  }

  void _stopListening() {
    _platformSub?.cancel();
    _platformSub = null;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _magSub?.cancel();
    _magSub = null;
  }
}

