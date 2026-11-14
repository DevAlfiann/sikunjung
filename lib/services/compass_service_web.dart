// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'compass_service.dart';

Stream<CompassReading>? getPlatformCompassStream() {
  final controller = StreamController<CompassReading>.broadcast();

  double currentHeading = 45.0;
  double currentPitch = 12.0;
  double currentRoll = -3.0;
  double? currentAccelX;
  double? currentAccelY;
  double? currentAccelZ;
  double? currentGyroX;
  double? currentGyroY;
  double? currentGyroZ;

  void emit() {
    if (!controller.isClosed) {
      controller.add(CompassReading(
        heading: currentHeading,
        pitch: currentPitch,
        roll: currentRoll,
        accuracy: 1.2,
        accelX: currentAccelX,
        accelY: currentAccelY,
        accelZ: currentAccelZ,
        gyroX: currentGyroX,
        gyroY: currentGyroY,
        gyroZ: currentGyroZ,
      ));
    }
  }

  void handleOrientation(dynamic event) {
    try {
      final webkitHeading = js_util.getProperty(event, 'webkitCompassHeading');
      final alpha = js_util.getProperty(event, 'alpha');
      final beta = js_util.getProperty(event, 'beta');
      final gamma = js_util.getProperty(event, 'gamma');

      if (webkitHeading != null && webkitHeading is num) {
        // iOS provides absolute heading directly (0° = North, clockwise)
        currentHeading = (webkitHeading.toDouble()) % 360.0;
        if (currentHeading < 0) currentHeading += 360.0;
      } else if (alpha != null && alpha is num) {
        // Android Chrome DeviceOrientationEvent:
        // alpha = 0 is North, increases counter-clockwise as device rotates.
        // Therefore clockwise compass heading is (360 - alpha) % 360.
        currentHeading = (360.0 - alpha.toDouble()) % 360.0;
        if (currentHeading < 0) currentHeading += 360.0;
      }

      if (beta != null && beta is num) {
        currentPitch = beta.toDouble();
      }
      if (gamma != null && gamma is num) {
        currentRoll = gamma.toDouble();
      }

      emit();
    } catch (_) {}
  }

  // 1. Android Chrome absolute orientation event
  html.EventListener? absListener;
  try {
    absListener = (html.Event e) => handleOrientation(e);
    html.window.addEventListener('deviceorientationabsolute', absListener);
  } catch (_) {}

  // 2. Standard device orientation event (iOS & fallback)
  StreamSubscription? orientationSub;
  try {
    orientationSub = html.window.onDeviceOrientation.listen((event) {
      handleOrientation(event);
    });
  } catch (_) {}

  // 3. Motion event for accelerometer and gyroscope
  StreamSubscription? motionSub;
  try {
    motionSub = html.window.onDeviceMotion.listen((event) {
      try {
        final accel = event.accelerationIncludingGravity;
        if (accel != null) {
          currentAccelX = accel.x?.toDouble();
          currentAccelY = accel.y?.toDouble();
          currentAccelZ = accel.z?.toDouble();
        }
        final rr = event.rotationRate;
        if (rr != null) {
          currentGyroX = rr.beta?.toDouble();
          currentGyroY = rr.gamma?.toDouble();
          currentGyroZ = rr.alpha?.toDouble();
        }
        emit();
      } catch (_) {}
    });
  } catch (_) {}

  controller.onCancel = () {
    if (absListener != null) {
      try {
        html.window.removeEventListener('deviceorientationabsolute', absListener);
      } catch (_) {}
    }
    orientationSub?.cancel();
    motionSub?.cancel();
  };

  return controller.stream;
}

Future<bool> requestPlatformCompassPermission() async {
  try {
    final devOrientation = js_util.getProperty(html.window, 'DeviceOrientationEvent');
    if (devOrientation != null) {
      final reqPermission = js_util.getProperty(devOrientation, 'requestPermission');
      if (reqPermission != null) {
        final res = await js_util.promiseToFuture(
          js_util.callMethod(devOrientation, 'requestPermission', []),
        );
        return res == 'granted';
      }
    }
    return true;
  } catch (_) {
    return true;
  }
}

