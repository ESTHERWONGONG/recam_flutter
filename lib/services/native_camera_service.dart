import 'dart:async';
import 'package:flutter/services.dart';
import '../models/ai_recommendation.dart';

class NativeCameraService {
  static const MethodChannel _channel =
      MethodChannel('recam_native_camera/methods');

  static const EventChannel _aiChannel =
      EventChannel('recam_native_camera/ai_stream');

  Stream<AiRecommendation>? _aiStream;

  // ✅ [修改] 拍照方法增加了 ratio 参数
  Future<String> takePhoto(String ratio) async {
    try {
      // 把 ratio 传给 Swift
      final path = await _channel.invokeMethod<String>("takePhoto", {"ratio": ratio});
      return path ?? '';
    } catch (e) {
      print('Native takePhoto error: $e');
      return '';
    }
  }

  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod("switchCamera");
    } catch (e) { print('switchCamera error: $e'); }
  }

  Future<void> setZoom(double zoom) async {
    try {
      await _channel.invokeMethod("setZoom", {"zoom": zoom});
    } catch (e) { print('setZoom error: $e'); }
  }

  Future<void> setFlashMode(String mode) async {
    try {
      await _channel.invokeMethod("setFlashMode", {"mode": mode});
    } catch (e) { print('setFlashMode error: $e'); }
  }

  Future<void> setAspectRatio(String aspect) async {
    try {
      await _channel.invokeMethod("setAspectRatio", {"aspect": aspect});
    } catch (e) { print('setAspectRatio error: $e'); }
  }

  Future<void> setQuality(String quality) async {
    try {
      await _channel.invokeMethod("setQuality", {"quality": quality});
    } catch (e) { print('setQuality error: $e'); }
  }

  Stream<AiRecommendation> get aiStream {
    return _aiStream ??=
        _aiChannel.receiveBroadcastStream().map((data) {
      final map = Map<String, dynamic>.from(data as Map);
      return AiRecommendation(
        filmId: map["filmId"] ?? '',
        message: map["message"] ?? '',
        score: (map["score"] as num?)?.toDouble() ?? 0,
        sceneType: map["sceneType"] ?? '',
      );
    });
  }

  Future<bool> saveToGallery(String filePath) async {
    try {
      final success = await _channel.invokeMethod<bool>("saveToGallery", {"path": filePath});
      return success ?? false;
    } catch (e) {
      print('saveToGallery error: $e');
      return false;
    }
  }
}