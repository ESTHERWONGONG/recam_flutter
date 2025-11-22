import 'dart:async';
import 'package:flutter/services.dart';

import '../models/ai_recommendation.dart';

/// ReCam 原生相机桥接层 —— 以后用来接 Swift 插件。
///
/// 未来 Swift 插件会通过：
/// - MethodChannel (拍照 / 切镜头 / 比例 / 画质)
/// - EventChannel (AI 实时推荐 / Histogram 分析)
///
/// 现在先让它是一个“安静不报错”的占位实现。
class NativeCameraService {
  static const MethodChannel _channel =
      MethodChannel('recam_native_camera/methods');

  static const EventChannel _aiChannel =
      EventChannel('recam_native_camera/ai_stream');

  Stream<AiRecommendation>? _aiStream;

  /// 拍照 —— 以后会真正调用 Swift
  ///
  /// 当前阶段：先返回一个空字符串，避免 MissingPluginException 直接把 App 崩掉。
  Future<String> takePhoto() async {
    try {
      final path = await _channel.invokeMethod<String>("takePhoto");
      return path ?? '';
    } catch (e) {
      // 先不要让整个 App 崩掉，调试阶段打印一下就好
      print('Native takePhoto error: $e');
      return '';
    }
  }

  /// 切换前后镜头（预留）
  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod("switchCamera");
    } catch (e) {
      print('switchCamera error: $e');
    }
  }

  /// 更新比例（3:4 / 1:1）（预留）
  Future<void> setAspectRatio(String aspect) async {
    try {
      await _channel.invokeMethod("setAspectRatio", {"aspect": aspect});
    } catch (e) {
      print('setAspectRatio error: $e');
    }
  }

  /// 更新闪光灯（off / auto / on）（预留）
  Future<void> setFlashMode(String mode) async {
    try {
      await _channel.invokeMethod("setFlashMode", {"mode": mode});
    } catch (e) {
      print('setFlashMode error: $e');
    }
  }

  /// 更新画质（low / medium / high）（预留）
  Future<void> setQuality(String quality) async {
    try {
      await _channel.invokeMethod("setQuality", {"quality": quality});
    } catch (e) {
      print('setQuality error: $e');
    }
  }

  /// AI 实时推荐 —— Swift 通过 EventChannel 推数据（预留）
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
}
