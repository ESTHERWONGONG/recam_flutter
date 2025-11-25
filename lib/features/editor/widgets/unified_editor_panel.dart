import 'package:flutter/material.dart';
import '../editor_constants.dart';

class UnifiedEditorPanel extends StatefulWidget {
  final List<EditorCategory> categories;
  final VoidCallback onClose;
  final Function(EditorItem item)? onItemTap;

  const UnifiedEditorPanel({
    super.key,
    required this.categories,
    required this.onClose,
    this.onItemTap,
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
        setState(() {
          _selectedCategoryIndex = _tabController.index;
          _selectedItemIndex = 0; 
        });
      }
    });
  }

  @override
  void didUpdateWidget(UnifiedEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    if (widget.categories.isEmpty) return const SizedBox();
    final currentCategory = widget.categories[_selectedCategoryIndex];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // 1. 顶部 TabBar / 标题
          _buildTopBar(currentCategory),

          // 2. 资源列表
          SizedBox(
            height: 120, 
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // ✅ 列表左间距 16，这是我们的对齐基准线
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: currentCategory.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = currentCategory.items[index];
                final isSelected = _selectedItemIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedItemIndex = index);
                    if (widget.onItemTap != null) widget.onItemTap!(item);
                  },
                  child: Column(
                    children: [
                      // 图标区域
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          // 选中：深黄背景 + 粗黄框
                          color: isSelected 
                              ? Colors.yellowAccent.withOpacity(0.2) 
                              : (item.color ?? const Color(0xFF1A1A1A)), 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.yellowAccent : Colors.transparent,
                            width: 3.0, 
                          ),
                        ),
                        alignment: Alignment.center,
                        child: (item.color == null && item.iconPath.isEmpty)
                            ? Text(item.name.isNotEmpty ? item.name[0] : "", 
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white30, 
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold
                                ))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(item.name, 
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey, 
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
                        )
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. 底部控制栏
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.white38, size: 20),
                  onPressed: () {
                    setState(() => _selectedItemIndex = 0); 
                    if (widget.categories.isNotEmpty && widget.categories[_selectedCategoryIndex].items.isNotEmpty) {
                       widget.onItemTap?.call(widget.categories[_selectedCategoryIndex].items[0]);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 28),
                  onPressed: widget.onClose, 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(EditorCategory currentCategory) {
    if (widget.categories.length > 1) {
      return Container(
        height: 44,
        margin: const EdgeInsets.only(top: 8),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          // ✅ [核心对齐修复]
          // 1. 强制靠左对齐 (Flutter 3.13+)
          tabAlignment: TabAlignment.start,
          // 2. 容器左边距设为 16 (对齐基准线)
          padding: const EdgeInsets.only(left: 16), 
          // 3. labelPadding 只设右边距 (拉开 Tab 间距)，左边设 0，保证文字贴着容器边缘
          labelPadding: const EdgeInsets.only(right: 24), 
          
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          unselectedLabelColor: Colors.grey,
          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
          indicatorColor: Colors.yellowAccent,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          dividerColor: Colors.transparent,
          // 去掉点击波纹，看起来更干净
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          tabs: widget.categories.map((c) => Tab(text: c.title)).toList(),
          onTap: (index) => setState(() => _selectedCategoryIndex = index),
        ),
      );
    } else {
      // 单分类标题
      return Container(
        height: 44,
        margin: const EdgeInsets.only(top: 8),
        alignment: Alignment.centerLeft,
        // ✅ 也是左边距 16，绝对对齐
        padding: const EdgeInsets.only(left: 16), 
        child: Text(
          currentCategory.title, 
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)
        ),
      );
    }
  }
}