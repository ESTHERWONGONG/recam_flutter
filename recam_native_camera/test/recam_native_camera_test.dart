import 'package:flutter_test/flutter_test.dart';
import 'package:recam_native_camera/recam_native_camera.dart';
import 'package:recam_native_camera/recam_native_camera_platform_interface.dart';
import 'package:recam_native_camera/recam_native_camera_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRecamNativeCameraPlatform
    with MockPlatformInterfaceMixin
    implements RecamNativeCameraPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RecamNativeCameraPlatform initialPlatform = RecamNativeCameraPlatform.instance;

  test('$MethodChannelRecamNativeCamera is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRecamNativeCamera>());
  });

  test('getPlatformVersion', () async {
    RecamNativeCamera recamNativeCameraPlugin = RecamNativeCamera();
    MockRecamNativeCameraPlatform fakePlatform = MockRecamNativeCameraPlatform();
    RecamNativeCameraPlatform.instance = fakePlatform;

    expect(await recamNativeCameraPlugin.getPlatformVersion(), '42');
  });
}
