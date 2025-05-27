import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lexilearn/providers/auth_provider.dart'; // 需要获取 userId
import 'package:lexilearn/providers/plan_provider.dart';
import 'package:lexilearn/widgets/error_feedback.dart';
import 'package:provider/provider.dart';
import 'package:lexilearn/constants.dart'; // 需要 UI 常量

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late TextEditingController _learnGoalController;
  late TextEditingController _reviewGoalController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    _learnGoalController =
        TextEditingController(text: planProvider.dailyLearnGoal.toString());
    _reviewGoalController =
        TextEditingController(text: planProvider.dailyReviewGoal.toString());
  }

  @override
  void dispose() {
    _learnGoalController.dispose();
    _reviewGoalController.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId == null) {
        if (mounted) ErrorFeedback.showErrorSnackbar(context, "无法保存计划：用户未登录");
        return;
      }

      final planProvider = Provider.of<PlanProvider>(context, listen: false);
      final int? newLearnGoal = int.tryParse(_learnGoalController.text);
      final int? newReviewGoal = int.tryParse(_reviewGoalController.text);

      if (newLearnGoal == null ||
          newLearnGoal <= 0 ||
          newReviewGoal == null ||
          newReviewGoal < 0) {
        if (mounted) {
          ErrorFeedback.showErrorSnackbar(context, "请输入有效的正整数作为目标值");
        }
        return;
      }

      await planProvider.savePlan(
        userId: userId, // 传递 userId
        newLearnGoal: newLearnGoal,
        newReviewGoal: newReviewGoal,
      );
      if (mounted) {
        ErrorFeedback.showSuccessSnackbar(context, "学习计划已保存");
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>(); // Use watch to react to changes
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('制定计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存计划',
            onPressed: _savePlan,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                "设置每日学习和复习的目标单词数量。",
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _learnGoalController,
                decoration: const InputDecoration(
                  labelText: '每日新学单词数',
                  hintText: '例如: 10',
                  prefixIcon: Icon(Icons.school_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '不能为空';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return '请输入大于0的整数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reviewGoalController,
                decoration: const InputDecoration(
                  labelText: '每日复习单词数',
                  hintText: '例如: 20',
                  prefixIcon: Icon(Icons.history_edu_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '不能为空';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    return '请输入非负整数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('保存计划'),
                onPressed: _savePlan,
              ),
              const SizedBox(height: 16),
              Text(
                "提示：当前计划 - 学习: ${plan.dailyLearnGoal}, 复习: ${plan.dailyReviewGoal}",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
