import 'package:flutter/material.dart';

// =========================================================
// 1. 统一枚举定义 (App 全局通用)
// =========================================================

enum EditorMode {
  none,    // 正常模式 (显示快门/主菜单)
  filter,  // 滤镜
  frame,   // 边框
  sticker, // 贴纸
  grain,   // 颗粒
  edit,    // 基础编辑 (裁剪/旋转/亮度等)
}

// =========================================================
// 2. 数据模型
// =========================================================

class EditorItem {
  final String id;
  final String name;
  final Color? color;    // Camera 用的颜色占位
  final String iconPath; // Gallery 用的图标路径

  const EditorItem({
    required this.id,
    required this.name,
    this.color,
    this.iconPath = '',
  });
}

class EditorCategory {
  final String title;
  final List<EditorItem> items;

  const EditorCategory({
    required this.title,
    required this.items,
  });
}

// =========================================================
// 3. 统一 Mock 数据源
// =========================================================

class EditorMockData {
  
  // 🌈 滤镜
  static const List<EditorCategory> filterCategories = [
    EditorCategory(
      title: "胶片",
      items: [
        EditorItem(id: "none", name: "原图", color: Colors.transparent),
        EditorItem(id: "f_c200", name: "C200", color: Colors.orangeAccent),
        EditorItem(id: "f_vista", name: "Vista", color: Colors.blueAccent),
        EditorItem(id: "f_kd400", name: "KD400", color: Colors.redAccent),
      ],
    ),
    EditorCategory(
      title: "黑白",
      items: [
        EditorItem(id: "b_bw1", name: "BW1", color: Colors.grey),
        EditorItem(id: "b_bw2", name: "BW2", color: Colors.blueGrey),
      ],
    ),
  ];

  // 🖼️ 边框
  static const List<EditorCategory> frameCategories = [
    EditorCategory(
      title: "拍立得",
      items: [
        EditorItem(id: "none", name: "无", color: Colors.transparent),
        EditorItem(id: "fr_white", name: "白框", color: Colors.white),
        EditorItem(id: "fr_black", name: "黑框", color: Colors.black87),
        EditorItem(id: "fr_check", name: "棋盘", color: Colors.grey),
      ],
    ),
  ];

  // ✨ 颗粒 (Camera / Gallery 通用)
  static const List<EditorCategory> grainCategories = [
    EditorCategory(
      title: "胶片质感",
      items: [
        EditorItem(id: "none", name: "无"),
        EditorItem(id: "g_low", name: "细沙"),
        EditorItem(id: "g_med", name: "胶片"),
        EditorItem(id: "g_high", name: "粗砺"),
        EditorItem(id: "g_bw", name: "黑白噪点"),
      ],
    ),
  ];

  // 🛠️ 基础编辑 (Gallery 用) - ✅ 已更新为你要求的三个功能
  static const List<EditorCategory> editCategories = [
    EditorCategory(
      title: "调整",
      items: [
        EditorItem(id: "brightness", name: "亮度"),
        EditorItem(id: "mirror", name: "左右翻转"),
        EditorItem(id: "vignette", name: "暗角"),
      ],
    ),
  ];
  
  // 🐻 贴纸
  static const List<EditorCategory> stickerCategories = [
    EditorCategory(
      title: "Emoji",
      items: [
        EditorItem(id: "s_smile", name: "😄"),
        EditorItem(id: "s_heart", name: "❤️"),
        EditorItem(id: "s_fire", name: "🔥"),
      ],
    ),
  ];
}