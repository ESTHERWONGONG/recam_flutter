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
  bool _autoSaveToGallery = true;
  bool _enableFrame = true; // 暂存本地
  
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
        _autoSaveToGallery = prefs.getBool('auto_save_to_gallery') ?? true;
        _enableFrame = prefs.getBool('enable_frame') ?? true;
        _version = info.version;
      });
    }
  }

  // 切换自动保存
  Future<void> _toggleAutoSave(bool value) async {
    setState(() => _autoSaveToGallery = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_save_to_gallery', value);
  }

  // ------------------------------------------------------
  // 🔗 核心业务逻辑：跳转小红书
  // ------------------------------------------------------
  Future<void> _jumpToXiaohongshu() async {
    // 替换成你的小红书 ID
    const String xhsId = "YOUR_XHS_ID"; 
    
    // 1. 尝试 Scheme (拉起 App)
    final Uri appUri = Uri.parse("xhsdiscover://user/$xhsId");
    // 2. 兜底 Web (跳 AppStore 或 网页)
    // 这里填小红书在 AppStore 的链接，或者你的个人主页 Web 版
    final Uri webUri = Uri.parse("https://www.xiaohongshu.com/user/profile/$xhsId");

    try {
      // canLaunchUrl 需要在 Info.plist 配置 LSApplicationQueriesSchemes
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        print("⚠️ 未安装小红书，跳转 Web/Store");
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showError("跳转失败", "无法打开链接: $e");
    }
  }

  // ------------------------------------------------------
  // 💰 核心业务逻辑：模拟内购 (预埋边界情况)
  // ------------------------------------------------------
  Future<void> _handlePurchase() async {
    // TODO: 接入 RevenueCat 后替换这里
    _showLoading("正在连接 App Store...");

    try {
      // 模拟网络延迟
      await Future.delayed(const Duration(seconds: 2));
      
      // 模拟：成功
      // Navigator.pop(context); // 关掉 loading
      // _showSuccess("解锁成功！");

      // 模拟：失败边界情况 (你可以打开这个注释测试)
      throw Exception("无法连接到 iTunes Store");

    } catch (e) {
      if (mounted) Navigator.pop(context); // 关loading
      _showError("支付失败", e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> _restorePurchase() async {
    _showLoading("正在恢复购买...");
    // 模拟恢复逻辑...
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
    _showError("恢复失败", "未找到购买记录");
  }

  // ------------------------------------------------------
  // 🎨 UI 构建 (Standard iOS Style)
  // ------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS 设置页标准灰底
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
          
          // 💎 购买卡片
          _buildProCard(),

          // 📸 拍摄设置组
          _buildSectionHeader("拍摄"),
          _buildGroup([
            _buildSwitchRow("边框效果", _enableFrame, (v) {
              setState(() => _enableFrame = v);
              SharedPreferences.getInstance().then((p) => p.setBool('enable_frame', v));
            }),
            _buildDivider(),
            _buildSwitchRow("保存底片 (存入系统相册)", _autoSaveToGallery, _toggleAutoSave),
            _buildDivider(),
            _buildSwitchRow("Log 模式 (限Pro)", false, null), // 禁用状态演示
          ]),

          // ℹ️ 其他设置组
          _buildSectionHeader("其他 (v$_version)"),
          _buildGroup([
            _buildActionRow("恢复购买", _restorePurchase),
            _buildDivider(),
            _buildActionRow("意见反馈", () => _launchUrl("mailto:support@recam.com")),
            _buildDivider(),
            _buildActionRow("隐私条款", () => _launchUrl("https://your-privacy-url.com")),
          ]),

          const SizedBox(height: 30),
          
          // 🔴 转化按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _jumpToXiaohongshu,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2442), // 小红书红
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

  // --- UI 组件封装 ---

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

  // --- 交互反馈 ---

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.white))
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("好"))],
      ),
    );
  }
}