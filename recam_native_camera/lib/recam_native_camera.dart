
import 'recam_native_camera_platform_interface.dart';

class RecamNativeCamera {
  Future<String?> getPlatformVersion() {
    return RecamNativeCameraPlatform.instance.getPlatformVersion();
  }
}
