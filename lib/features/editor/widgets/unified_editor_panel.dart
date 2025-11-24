import 'package:flutter/material.dart';
import '../editor_constants.dart';

class UnifiedEditorPanel extends StatefulWidget {
  final List<EditorCategory> categories; // 数据源
  final bool showSlider;                 // 是否显示强度滑杆
  final VoidCallback onClose;            // 点击关闭/确认的回调

  const UnifiedEditorPanel({
    super.key,
    required this.categories,
    this.showSlider = true,
    required this.onClose,
  });

  @override
  State<UnifiedEditorPanel> createState() => _UnifiedEditorPanelState();
}

class _UnifiedEditorPanelState extends State<UnifiedEditorPanel> with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0; // 当前选中的分类 Tab
  int _selectedItemIndex = 0;     // 当前选中的资源
  double _intensity = 0.8;        // 滑杆强度 (0.0 - 1.0)
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
      color: const Color(0xFF111111), // 深色底板
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 调节层 (Slider) - 可选
          if (widget.showSlider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.grey, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: _intensity,
                        activeColor: Colors.yellowAccent,
                        inactiveColor: Colors.grey[800],
                        onChanged: (v) => setState(() => _intensity = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("${(_intensity * 100).toInt()}", 
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

          // 2. 分类层 (Tabs)
          TabBar(
            controller: _tabController,
            isScrollable: true, // 允许横向滚动
            labelColor: Colors.yellowAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.yellowAccent,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: widget.categories.map((c) => Tab(text: c.name)).toList(),
            onTap: (index) {
              setState(() => _selectedCategoryIndex = index);
            },
          ),

          // 3. 资源选择层 (List)
          SizedBox(
            height: 90, // 固定高度
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: currentCategory.items.length,
              itemBuilder: (context, index) {
                final item = currentCategory.items[index];
                final isSelected = _selectedItemIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedItemIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 60,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.2),
                      border: isSelected 
                          ? Border.all(color: Colors.yellowAccent, width: 2) 
                          : Border.all(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 假装这是缩略图
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(item.name, 
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey, 
                            fontSize: 10
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. 底部控制层 (Action Bar)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左边：无效果 / 撤销 (暂时放个禁止图标)
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.grey, size: 20),
                  onPressed: () {
                    // TODO: 清除滤镜逻辑
                  },
                ),
                // 右边：确认/收起 (核心交互：回到拍摄模式)
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                  onPressed: widget.onClose, // 调用外部传入的关闭逻辑
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
