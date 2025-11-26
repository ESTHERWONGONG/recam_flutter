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
  final String assetPath;// ✅ 真实素材路径

  const EditorItem({
    required this.id,
    required this.name,
    this.color,
    this.iconPath = '',
    this.assetPath = '', // 默认为空
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
    EditorCategory(title: "胶片", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "f_c200", name: "C200", color: Colors.orangeAccent),
      EditorItem(id: "f_vista", name: "Vista", color: Colors.blueAccent),
    ]),
    EditorCategory(title: "电影", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "m_cin1", name: "Cin1", color: Colors.purpleAccent),
      EditorItem(id: "m_cin2", name: "Cin2", color: Colors.tealAccent),
    ]),
    EditorCategory(title: "黑白", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "b_bw1", name: "BW1", color: Colors.grey),
    ]),
  ];

  // 🖼️ 边框
  static const List<EditorCategory> frameCategories = [
    EditorCategory(title: "拍立得", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "fr_white", name: "白框", color: Colors.white),
      EditorItem(id: "fr_black", name: "黑框", color: Colors.black87),
    ]),
    EditorCategory(title: "极简", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "fr_simple_1", name: "细线", color: Colors.white30),
      EditorItem(id: "fr_simple_2", name: "圆角", color: Colors.white12),
    ]),
  ];

  // ✨ 颗粒/光效
  static const List<EditorCategory> grainCategories = [
    EditorCategory(title: "质感", items: [
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "g_low", name: "细沙"),
      EditorItem(id: "g_med", name: "胶片"),
    ]),
    EditorCategory(title: "光效", items: [
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "g_dust", name: "灰尘"),
      EditorItem(id: "g_scratch", name: "划痕"),
    ]),
  ];

  // 🐻 贴纸 (已更新)
  static const List<EditorCategory> stickerCategories = [
    // ✅ Tab 1: 时间戳
    EditorCategory(
      title: "时间戳", 
      items: [
        EditorItem(id: "none", name: "无"),
        // 👇 你的 001.png 在这里
        EditorItem(
          id: "s_classic_time", 
          name: "经典时间", 
          assetPath: "assets/stickers/001.png" // 确保文件已放入 assets/stickers/
        ),
      ]
    ),
    // Tab 2: Emoji (保留作参考)
    EditorCategory(
      title: "Emoji", 
      items: [
        EditorItem(id: "none", name: "无"),
        EditorItem(id: "s_smile", name: "😄"),
        EditorItem(id: "s_heart", name: "❤️"),
      ]
    ),
  ];

  // 🛠️ 基础编辑
  static const List<EditorCategory> editCategories = [
    EditorCategory(title: "调整", items: [
      EditorItem(id: "brightness", name: "亮度"),
      EditorItem(id: "mirror", name: "左右翻转"),
      EditorItem(id: "vignette", name: "暗角"),
    ]),
  ];
}