import 'package:flutter/material.dart';

// 1. 统一枚举
enum EditorMode { none, filter, frame, sticker, grain, edit }

// 2. 数据模型
class EditorItem {
  final String id;
  final String name;
  final Color? color;    
  final String iconPath; 

  const EditorItem({required this.id, required this.name, this.color, this.iconPath = ''});
}

class EditorCategory {
  final String title;
  final List<EditorItem> items;
  const EditorCategory({required this.title, required this.items});
}

// 3. 统一 Mock 数据源
class EditorMockData {
  
  // 🌈 滤镜
  static const List<EditorCategory> filterCategories = [
    EditorCategory(title: "胶片", items: [
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "f_c200", name: "C200", color: Colors.orangeAccent),
      EditorItem(id: "f_vista", name: "Vista", color: Colors.blueAccent),
    ]),
    EditorCategory(title: "电影", items: [
      // ✅ 补充 "无"
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "m_cin1", name: "Cin1", color: Colors.purpleAccent),
      EditorItem(id: "m_cin2", name: "Cin2", color: Colors.tealAccent),
    ]),
    EditorCategory(title: "黑白", items: [
      // ✅ 补充 "无"
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
      // ✅ 补充 "无"
      EditorItem(id: "none", name: "无", color: Colors.transparent),
      EditorItem(id: "fr_simple_1", name: "细线", color: Colors.white30),
      EditorItem(id: "fr_simple_2", name: "圆角", color: Colors.white12),
    ]),
  ];

  // ✨ 颗粒
  static const List<EditorCategory> grainCategories = [
    EditorCategory(title: "质感", items: [
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "g_low", name: "细沙"),
      EditorItem(id: "g_med", name: "胶片"),
    ]),
    EditorCategory(title: "光效", items: [
      // ✅ 补充 "无"
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "g_dust", name: "灰尘"),
      EditorItem(id: "g_scratch", name: "划痕"),
    ]),
  ];

  // 🐻 贴纸
  static const List<EditorCategory> stickerCategories = [
    EditorCategory(title: "Emoji", items: [
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "s_smile", name: "😄"),
      EditorItem(id: "s_heart", name: "❤️"),
    ]),
    EditorCategory(title: "文字", items: [
      // ✅ 补充 "无"
      EditorItem(id: "none", name: "无"),
      EditorItem(id: "t_date", name: "日期"),
      EditorItem(id: "t_sign", name: "签名"),
    ]),
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