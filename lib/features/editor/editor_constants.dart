import 'package:flutter/material.dart';

// 1. 编辑模式枚举
enum EditorMode {
  none,    // 正常拍摄模式 (显示快门)
  filter,  // 滤镜模式
  frame,   // 边框模式
  sticker, // 贴纸模式
}

// 2. 模拟分类数据 (以后这里换成真实数据)
class EditorCategory {
  final String name;
  final List<EditorItem> items;
  EditorCategory(this.name, this.items);
}

class EditorItem {
  final String id;
  final String name;
  final Color color; // 暂时用颜色代替缩略图
  EditorItem(this.id, this.name, this.color);
}

// 3. 生成一点假数据供测试
class EditorMockData {
  static List<EditorCategory> get filterCategories => [
    EditorCategory("胶片", [
      EditorItem("f1", "C1", Colors.orangeAccent),
      EditorItem("f2", "C2", Colors.blueAccent),
      EditorItem("f3", "C3", Colors.redAccent),
    ]),
    EditorCategory("电影", [
      EditorItem("m1", "M1", Colors.purpleAccent),
      EditorItem("m2", "M2", Colors.tealAccent),
    ]),
    EditorCategory("黑白", [
      EditorItem("b1", "BW1", Colors.grey),
      EditorItem("b2", "BW2", Colors.blueGrey),
    ]),
  ];

  static List<EditorCategory> get frameCategories => [
    EditorCategory("拍立得", [
      EditorItem("fr1", "白框", Colors.white),
      EditorItem("fr2", "黑框", Colors.grey[800]!),
    ]),
  ];
}
