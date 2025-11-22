import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'recam_native_camera_platform_interface.dart';

/// An implementation of [RecamNativeCameraPlatform] that uses method channels.
class MethodChannelRecamNativeCamera extends RecamNativeCameraPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('recam_native_camera');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
