import 'package:flutter/material.dart';
import 'package:lexilearn/providers/auth_provider.dart';
import 'package:lexilearn/providers/plan_provider.dart';
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:provider/provider.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  // ***** 使用 async/await 并进行显式导航 *****
  Future<void> _handleLogout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout(); // 等待 Provider 完成状态更新和清理

    // 确保在异步操作后 context 仍然有效 (虽然 pushNamedAndRemoveUntil 通常没问题)
    if (context.mounted) {
      // 使用 rootNavigator 确保从根部导航
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
  // ----------------------------------------

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('确定退出', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ).then((confirmed) {
      // then 回调不是 async
      if (confirmed == true) {
        // 在 then 回调中调用 async 方法
        _handleLogout(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabProvider>();
    final plan = context.watch<PlanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('菜单'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('切换词库'),
            subtitle: Text('当前: ${vocab.selectedBookId ?? "未选择"}'),
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/vocab_select', (route) => false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('制定计划'),
            subtitle: Text(
                '学习: ${plan.dailyLearnGoal} / 复习: ${plan.dailyReviewGoal}'),
            onTap: () => Navigator.pushNamed(context, '/plan'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('学习数据'),
            subtitle: const Text('查看学习统计'),
            onTap: () {
              // *** 日志：导航前 ***
              print("[MenuPage] Navigating to /stats...");
              Navigator.pushNamed(context, '/stats');
              // *** 日志：导航后 ***
              // 注意：这行日志会在 pushNamed 返回后立即打印，并不代表 StatsPage 构建完成
              print("[MenuPage] Navigator.pushNamed('/stats') call completed.");
            },
          ),
          const Divider(),
          ListTile(
            leading:
                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('切换账号',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: Text('退出当前账号 (${auth.email ?? ""})'),
            onTap: () => _showLogoutConfirmationDialog(context),
          ),
        ],
      ),
    );
  }
}
