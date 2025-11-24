import 'package:flutter/material.dart';
import '../editor_constants.dart';

class UnifiedEditorPanel extends StatefulWidget {
  final List<EditorCategory> categories; // 数据源
  // ❌ 删掉了 showSlider，不再由内部控制
  final VoidCallback onClose;            // 关闭回调

  const UnifiedEditorPanel({
    super.key,
    required this.categories,
    required this.onClose,
  });

  @override
  State<UnifiedEditorPanel> createState() => _UnifiedEditorPanelState();
}

class _UnifiedEditorPanelState extends State<UnifiedEditorPanel> with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0; 
  int _selectedItemIndex = 0;     
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedCategoryIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = widget.categories[_selectedCategoryIndex];

    return Container(
      color: const Color(0xFF111111),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 高度自适应，不撑满
        children: [
          // 1. 分类层 (Tabs) - 样式微调更精致
          Container(
            height: 40,
            margin: const EdgeInsets.only(top: 10),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.yellowAccent,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.yellowAccent,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: widget.categories.map((c) => Tab(text: c.name)).toList(),
              onTap: (index) => setState(() => _selectedCategoryIndex = index),
            ),
          ),

          // 2. 资源选择层 (List)
          SizedBox(
            height: 100, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              itemCount: currentCategory.items.length,
              itemBuilder: (context, index) {
                final item = currentCategory.items[index];
                final isSelected = _selectedItemIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedItemIndex = index),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: item.color, // 以后换成 Image.asset
                          borderRadius: BorderRadius.circular(8), // 圆角矩形 (Dazz风格)
                          border: isSelected 
                              ? Border.all(color: Colors.yellowAccent, width: 2.5) 
                              : Border.all(color: Colors.transparent, width: 2.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(item.name, 
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey, 
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. 底部控制层 (Action Bar)
          // 跟你的截图 2 保持一致：左边禁止，右边收起
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.grey, size: 22),
                  onPressed: () { }, // TODO: 清除效果
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                  onPressed: widget.onClose, 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}