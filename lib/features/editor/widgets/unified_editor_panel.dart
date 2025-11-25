import 'package:flutter/material.dart';
// ✅ 必须引入统一的常量定义
import '../editor_constants.dart';

class UnifiedEditorPanel extends StatefulWidget {
  final List<EditorCategory> categories; // 数据源
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
  void didUpdateWidget(UnifiedEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部传入的分类变了（比如从滤镜切到边框），重置 TabController
    if (widget.categories.length != oldWidget.categories.length) {
      _tabController.dispose();
      _tabController = TabController(length: widget.categories.length, vsync: this);
      _selectedCategoryIndex = 0;
      _selectedItemIndex = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 安全检查：防止空数据崩溃
    if (widget.categories.isEmpty) return const SizedBox();

    final currentCategory = widget.categories[_selectedCategoryIndex];

    return Container(
      color: const Color(0xFF111111),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 高度自适应
        children: [
          // 1. 分类层 (Tabs)
          if (widget.categories.length > 1) // 只有多于1个分类时才显示Tab
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
                // ✅ [修复点 1] 这里改成了 c.title (之前是 c.name)
                tabs: widget.categories.map((c) => Tab(text: c.title)).toList(),
                onTap: (index) => setState(() => _selectedCategoryIndex = index),
              ),
            )
          else 
            // 如果只有一个分类，显示简单的标题或者留空
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5),
              child: Text(currentCategory.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),

          // 2. 资源选择层 (List)
          SizedBox(
            height: 100, 
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              itemCount: currentCategory.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = currentCategory.items[index];
                final isSelected = _selectedItemIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedItemIndex = index),
                  child: Column(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          // ✅ [修复点 2] 兼容颜色和图片逻辑
                          color: item.color ?? Colors.white10, 
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected 
                              ? Border.all(color: Colors.yellowAccent, width: 2.5) 
                              : Border.all(color: Colors.transparent, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        // 如果没有颜色且没有图标，显示首字作为占位
                        child: (item.color == null && item.iconPath.isEmpty)
                            ? Text(item.name.isNotEmpty ? item.name[0] : "", style: const TextStyle(color: Colors.white54))
                            : null,
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
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧预留：清除效果
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.grey, size: 22),
                  onPressed: () { 
                     // TODO: 重置逻辑
                     setState(() => _selectedItemIndex = 0);
                  }, 
                ),
                // 右侧：收起面板
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