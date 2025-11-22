import 'dart:async';
import 'package:flutter/services.dart';

import '../models/ai_recommendation.dart';

/// ReCam 原生相机桥接层 —— 用来连接 Swift 插件。
///
/// 负责把 Flutter 的指令（拍照、变焦）发给 Swift，
/// 并把 Swift 的 AI 推荐数据接回来。
class NativeCameraService {
  static const MethodChannel _channel =
      MethodChannel('recam_native_camera/methods');

  static const EventChannel _aiChannel =
      EventChannel('recam_native_camera/ai_stream');

  Stream<AiRecommendation>? _aiStream;

  /// 拍照
  Future<String> takePhoto() async {
    try {
      final path = await _channel.invokeMethod<String>("takePhoto");
      return path ?? '';
    } catch (e) {
      print('Native takePhoto error: $e');
      return '';
    }
  }

  /// 切换前后镜头
  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod("switchCamera");
    } catch (e) {
      print('switchCamera error: $e');
    }
  }

  /// [新增] 设置变焦 (0.5 / 1.0 / 2.0)
  Future<void> setZoom(double zoom) async {
    try {
      await _channel.invokeMethod("setZoom", {"zoom": zoom});
    } catch (e) {
      print('setZoom error: $e');
    }
  }

  /// 更新比例（3:4 / 1:1）
  Future<void> setAspectRatio(String aspect) async {
    try {
      await _channel.invokeMethod("setAspectRatio", {"aspect": aspect});
    } catch (e) {
      print('setAspectRatio error: $e');
    }
  }

  /// 更新闪光灯（off / auto / on）
  Future<void> setFlashMode(String mode) async {
    try {
      await _channel.invokeMethod("setFlashMode", {"mode": mode});
    } catch (e) {
      print('setFlashMode error: $e');
    }
  }

  /// 更新画质（low / medium / high）
  Future<void> setQuality(String quality) async {
    try {
      await _channel.invokeMethod("setQuality", {"quality": quality});
    } catch (e) {
      print('setQuality error: $e');
    }
  }

  /// AI 实时推荐 —— 监听 Swift 发来的数据流
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