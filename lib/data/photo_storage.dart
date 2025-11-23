import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 照片数据模型
class ReCamPhoto {
  final String id;
  final String path;
  final DateTime createdAt;

  ReCamPhoto({
    required this.id,
    required this.path,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReCamPhoto.fromJson(Map<String, dynamic> json) {
    return ReCamPhoto(
      id: json['id'],
      path: json['path'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// 档案管理员
class PhotoStorage {
  static const String _key = 'recam_gallery_v1';

  /// 1. 存一张新照片（自动插到最前面）
  static Future<void> savePhoto(String path) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 获取旧数据
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    // 创建新记录
    final newPhoto = ReCamPhoto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      createdAt: DateTime.now(),
    );

    // 插队到第一位
    history.insert(0, jsonEncode(newPhoto.toJson()));

    // 保存
    await prefs.setStringList(_key, history);
    print("📒 数据持久化成功：${newPhoto.id}");
  }

  /// 2. 获取所有照片（分页/全部）
  static Future<List<ReCamPhoto>> getAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];

    return history
        .map((item) => ReCamPhoto.fromJson(jsonDecode(item)))
        .toList();
  }
  
  /// 3. 删除一张照片 (可选功能)
  static Future<void> deletePhoto(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];
    
    history.removeWhere((item) {
      final photo = ReCamPhoto.fromJson(jsonDecode(item));
      return photo.id == id;
    });
    
    await prefs.setStringList(_key, history);
  }
}