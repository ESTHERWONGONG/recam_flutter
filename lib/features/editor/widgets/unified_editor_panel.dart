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
  int _selectedItemIndex = -1; 
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
    if (widget.categories.length != oldWidget.categories.length) {
      _tabController.dispose();
      _tabController = TabController(length: widget.categories.length, vsync: this);
      _selectedCategoryIndex = 0;
      _selectedItemIndex = -1;
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
      // ✅ [核心修改] 删除了这里的 padding: bottomPadding
      // 因为父页面已经套了 SafeArea，这里不需要再加，否则会有双下巴
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // 1. 顶部 TabBar
          if (widget.categories.length > 1) 
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
                tabs: widget.categories.map((c) => Tab(text: c.title)).toList(),
                onTap: (index) => setState(() => _selectedCategoryIndex = index),
              ),
            )
          else 
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5),
              child: Text(currentCategory.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),

          // 2. 资源列表
          SizedBox(
            height: 120, 
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
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
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: item.color ?? const Color(0xFF222222), 
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected 
                              ? Border.all(color: Colors.yellowAccent, width: 2) 
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: (item.color == null && item.iconPath.isEmpty)
                            ? Text(item.name.isNotEmpty ? item.name[0] : "", style: const TextStyle(color: Colors.white30, fontSize: 20))
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
                  onPressed: () => setState(() => _selectedItemIndex = -1), 
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
}