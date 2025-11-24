import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 开关状态
  bool _enableAiRecommendation = true; // ✅ [新增] AI 开关
  bool _autoSaveToGallery = true;
  bool _enableFrame = true; 
  
  String _version = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    
    if (mounted) {
      setState(() {
        // 读取配置，默认为 true
        _enableAiRecommendation = prefs.getBool('enable_ai_recommendation') ?? true;
        _autoSaveToGallery = prefs.getBool('auto_save_to_gallery') ?? true;
        _enableFrame = prefs.getBool('enable_frame') ?? true;
        _version = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), 
      appBar: AppBar(
        title: const Text("设置", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          _buildProCard(),

          _buildSectionHeader("拍摄"),
          _buildGroup([
            // ✅ [新增] AI 推荐开关
            _buildSwitchRow(
              "智能胶片推荐", 
              _enableAiRecommendation, 
              (v) async {
                setState(() => _enableAiRecommendation = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('enable_ai_recommendation', v);
              }
            ),
            _buildDivider(),
            
            _buildSwitchRow("边框效果", _enableFrame, (v) {
              setState(() => _enableFrame = v);
              SharedPreferences.getInstance().then((p) => p.setBool('enable_frame', v));
            }),
            _buildDivider(),
            
            _buildSwitchRow("保存底片 (存入系统相册)", _autoSaveToGallery, (v) async {
              setState(() => _autoSaveToGallery = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('auto_save_to_gallery', v);
            }),
            _buildDivider(),
            
            _buildSwitchRow("Log 模式 (限Pro)", false, null),
          ]),

          _buildSectionHeader("其他 (v$_version)"),
          _buildGroup([
            _buildActionRow("恢复购买", _restorePurchase),
            _buildDivider(),
            _buildActionRow("意见反馈", () => _launchUrl("mailto:support@recam.com")),
            _buildDivider(),
            _buildActionRow("隐私条款", () => _launchUrl("https://your-privacy-url.com")),
          ]),

          const SizedBox(height: 30),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _jumpToXiaohongshu,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2442),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("去小红书留言，解锁 6 款相机 📷", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- 辅助方法 (保持不变) ---
  // 为了篇幅，省略了部分未变动的业务逻辑函数(_jumpToXiaohongshu等)，
  // 你只需要复制上面 build 里的结构即可。
  // 如果你之前那个文件是好的，只需要把 build 方法里的 _buildGroup 内容改了就行。
  // 但为了防止出错，我下面还是把完整辅助函数贴上：

  Future<void> _jumpToXiaohongshu() async {
    const String xhsId = "YOUR_XHS_ID"; 
    final Uri appUri = Uri.parse("xhsdiscover://user/$xhsId");
    final Uri webUri = Uri.parse("https://www.xiaohongshu.com/user/profile/$xhsId");
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) { _showError("跳转失败", "$e"); }
  }

  Future<void> _handlePurchase() async {
    // 模拟逻辑
  }

  Future<void> _restorePurchase() async {
    // 模拟逻辑
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showError(String title, String message) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("好"))]));
  }

  Widget _buildProCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("ReCam Pro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)),
                child: const Text("¥4.99", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          const Text("解锁永久使用权，支持独立开发者。", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handlePurchase,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text("立即解锁"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }

  Widget _buildSwitchRow(String title, bool value, Function(bool)? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildActionRow(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, indent: 16);
  }
}