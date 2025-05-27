import 'package:flutter/material.dart';
// import 'package:lexilearn/constants.dart'; // --- 移除 ---
import 'package:lexilearn/providers/plan_provider.dart';
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:provider/provider.dart';

// ... (HomePage 类保持不变) ...
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use watch if the UI should rebuild when these values change (e.g., after saving plan)
    final vocabProvider = context.watch<VocabProvider>();
    final planProvider = context.watch<PlanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('LexiLearn - ${vocabProvider.selectedBookId ?? '词库'}'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '菜单',
            onPressed: () => Navigator.pushNamed(context, '/menu'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.school_outlined),
                label: Text(
                    "开始学习 (${planProvider.dailyLearnGoal}词)"), // Read from watched provider
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: theme.textTheme.titleLarge),
                onPressed: () => Navigator.pushNamed(context, '/learn'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.history_edu_outlined),
                label: Text(
                    "开始复习 (${planProvider.dailyReviewGoal}词)"), // Read from watched provider
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: theme.textTheme.titleLarge,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
                onPressed: () => Navigator.pushNamed(context, '/review'),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
