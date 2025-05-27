// frontend/lib/pages/learn_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 需要 kDebugMode
import 'package:lexilearn/constants.dart'; // 使用你提供的 constants.dart
import 'package:lexilearn/models/word_entry.dart';
import 'package:lexilearn/providers/auth_provider.dart';
import 'package:lexilearn/providers/plan_provider.dart';
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:lexilearn/providers/word_state_provider.dart';
import 'package:lexilearn/widgets/animated_word_header.dart';
import 'package:lexilearn/widgets/detail_content.dart';
import 'package:lexilearn/widgets/detail_tabs.dart';
import 'package:lexilearn/widgets/error_feedback.dart';
import 'package:lexilearn/services/audio_service.dart';
import 'package:lexilearn/services/hive_service.dart'; // HiveService 用于记录
import 'package:provider/provider.dart';
import 'dart:ui'; // 需要 ImageFilter

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ChangeNotifierProvider for WordStateProvider specific to this page instance
    return ChangeNotifierProvider<WordStateProvider>(
      create: (_) => WordStateProvider(),
      child: const _LearnPageContent(),
    );
  }
}

class _LearnPageContent extends StatefulWidget {
  const _LearnPageContent();

  @override
  State<_LearnPageContent> createState() => _LearnPageContentState();
}

class _LearnPageContentState extends State<_LearnPageContent> {
  final AudioService _audioService = AudioService();
  final HiveService _hiveService = HiveService(); // 实例化 HiveService
  final Stopwatch _sessionStopwatch = Stopwatch(); // **计时器实例**
  String? _currentUserId; // 缓存用户ID
  String? _currentBookId; // 缓存词库ID

  @override
  void initState() {
    super.initState();
    // 在 initState 获取 ID，避免在 dispose 时 context 可能失效的问题
    _currentUserId = Provider.of<AuthProvider>(context, listen: false).userId;
    _currentBookId =
        Provider.of<VocabProvider>(context, listen: false).selectedBookId;

    _sessionStopwatch.start(); // **启动计时器**

    // Load words after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWords();
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    _sessionStopwatch.stop(); // **停止计时**

    // **记录学习时长 (如果用户ID和词库ID存在且时长超过5秒)**
    if (_currentUserId != null &&
        _currentBookId != null &&
        _sessionStopwatch.elapsedMilliseconds > 5000) {
      _hiveService.logSessionDuration(
          _currentUserId!, _currentBookId!, _sessionStopwatch.elapsed);
      if (kDebugMode) {
        print(
            "[LearnPage] Logged session duration: ${_sessionStopwatch.elapsed} for user $_currentUserId, book $_currentBookId");
      }
    } else if (kDebugMode) {
      print(
          "[LearnPage] Session duration not logged (userId: $_currentUserId, bookId: $_currentBookId, durationMs: ${_sessionStopwatch.elapsedMilliseconds})");
    }
    // ------------

    super.dispose();
  }

  Future<void> _loadWords() async {
    // Get providers using listen: false as this is a one-time action
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vocabProvider = Provider.of<VocabProvider>(context, listen: false);
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    final wordStateProvider =
        Provider.of<WordStateProvider>(context, listen: false);

    // Ensure user and book are selected
    if (authProvider.userId == null || vocabProvider.selectedBookId == null) {
      if (mounted) {
        ErrorFeedback.showErrorSnackbar(context, "无法加载学习数据：用户或词库信息丢失");
        Navigator.pop(context); // Go back if essential info is missing
      }
      return;
    }

    // TODO: Potentially check daily learning limit here before loading

    await wordStateProvider.loadWordsForSession(
      userId: authProvider.userId!,
      bookId: vocabProvider.selectedBookId!,
      type: SessionType.learn, // Specify session type
      goal: planProvider.dailyLearnGoal, // Use goal from plan provider
    );

    // Handle potential loading errors
    if (wordStateProvider.status == SessionStatus.error && mounted) {
      ErrorFeedback.showErrorSnackbar(
          context, wordStateProvider.errorMessage ?? "加载单词时出错");
      // Optionally navigate back on error
      // Navigator.pop(context);
    }
  }

  // Log learn/review events when user makes a judgement
   Future<void> _handleJudgement(bool known) async {
    final wordState = Provider.of<WordStateProvider>(context, listen: false);
    final word = wordState.currentWord;
    final userId = _currentUserId;
    final bookId = _currentBookId;
    if (word == null ||
        userId == null ||
        bookId == null ||
        wordState.showDetails) {
      return;
    }

    bool firstTimeKnown = false;
    if (known) {
      try {
        final progressBox = _hiveService.getProgressBox(userId);
        final existingProgress = progressBox.get(word.content.word.wordId);
        if (existingProgress == null) {
          firstTimeKnown = true;
        }
      } catch (e) {
        if (kDebugMode) print("Error checking progress box: $e");
      }
    }

    // 更新单词进度
    await _hiveService.updateWordProgress(
        userId, word.content.word.wordId, known);
    // 更新 UI 状态
    await wordState.markWord(known);

    // --- *** 修改日志记录逻辑 *** ---
    if (firstTimeKnown) {
      // 只有在第一次认识这个单词时，才记录“学习事件”
      _hiveService.logLearnEvent(userId, bookId);
      if (kDebugMode) {
        print("[LearnPage] Logged Learn Event for $userId, $bookId");
      }
    }
    // *** 移除 else 分支，学习页面不再记录任何复习事件 ***
    // else {
    //   _hiveService.logReviewEvent(userId, bookId);
    //   if (kDebugMode) print("[LearnPage] Logged Review Event for $userId, $bookId");
    // }
    // --- *** 结束修改 *** ---
  }

  @override
  Widget build(BuildContext context) {
    // Use watch here to rebuild UI based on WordStateProvider changes
    final wordState = context.watch<WordStateProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true, // Allows content to draw behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, // No back button
        titleSpacing: 0, // Remove default title spacing
        title: _buildAppBarTitle(context, wordState), // Custom progress title
        actions: [
          IconButton(
            icon:
                const Icon(Icons.close, color: Colors.black54), // Close button
            tooltip: '结束学习',
            onPressed: () => _showExitConfirmationDialog(context),
          ),
          const SizedBox(width: 8), // Padding for the close button
        ],
      ),
      body: Container(
        // Background gradient and blur effect
        decoration: BoxDecoration(
            gradient: LinearGradient(
          colors: [primaryColor.withAlpha(150), secondaryColor.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
        child: Stack(
          children: [
            // Background blur layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: Colors.white.withAlpha(30)),
              ),
            ),
            // Main content area, adjusted for AppBar and AnimatedWordHeader
            SafeArea(
              bottom: false, // Allow content near bottom FAB
              child: Padding(
                padding: EdgeInsets.only(
                    // Dynamically adjust top padding based on whether details are shown
                    top: wordState.showDetails
                        ? (MediaQuery.of(context).padding.top + // Status bar
                            kToolbarHeight + // AppBar height
                            90) // Approximate height of header in detail view
                        : (MediaQuery.of(context).padding.top + // Status bar
                            kToolbarHeight), // AppBar height
                    left: 0,
                    right: 0,
                    bottom: 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _buildMainContent(context, wordState),
                ),
              ),
            ),
            // Animated header for the word itself
            AnimatedWordHeader(
              wordEntry: wordState.currentWord,
              showDetails: wordState.showDetails,
              audioService: _audioService, // Pass audio service instance
            ),
            // Completion overlay shown when session is done
            if (wordState.status == SessionStatus.completed)
              _buildCompletionOverlay(context, theme, wordState),
          ],
        ),
      ),
      // Floating Action Button for "Next Word"
      floatingActionButton:
          wordState.showDetails && wordState.status == SessionStatus.active
              ? FloatingActionButton.extended(
                  onPressed: wordState.nextWord,
                  backgroundColor: secondaryColor, // Use theme color
                  foregroundColor: theme.colorScheme.primary, // Contrast color
                  label: const Text('下一词'),
                  icon: const Icon(Icons.skip_next_rounded),
                  shape: const StadiumBorder(), // Rounded FAB
                  elevation: elevationMedium,
                )
              : null, // Hide if details not shown or session inactive
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Builds the AppBar title with progress indicator
  Widget _buildAppBarTitle(BuildContext context, WordStateProvider wordState) {
    final theme = Theme.of(context);
    final bool showProgress =
        wordState.status == SessionStatus.active && wordState.hasWords;
    final double progress = showProgress && wordState.totalWordsInSession > 0
        ? (wordState.currentIndex + 1) / wordState.totalWordsInSession
        : 0;

    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showProgress
                ? "进度: ${wordState.currentIndex + 1} / ${wordState.totalWordsInSession}"
                : "学习", // Show "Learning" if no words or not active
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent, // Part of AppBar background
            valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary), // Use primary color for progress
            minHeight: 5.0,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  // Builds the main content area (either judgement buttons or word details)
  Widget _buildMainContent(BuildContext context, WordStateProvider wordState) {
    // Use ValueKey to help AnimatedSwitcher differentiate between states
    final key = ValueKey<bool>(wordState.showDetails);

    if (!wordState.showDetails) {
      // Show judgement buttons if active and has words
      if (wordState.status == SessionStatus.active && wordState.hasWords) {
        return Align(
          key: key,
          alignment: Alignment.bottomCenter, // Position buttons at the bottom
          child: Padding(
            padding: const EdgeInsets.only(
                left: 32.0,
                right: 32.0,
                bottom: 90.0,
                top: 16.0), // Add padding
            child: _buildJudgementButtons(context),
          ),
        );
      } else {
        // Show nothing if loading, completed, or error state before details shown
        return SizedBox.shrink(key: key);
      }
    } else {
      // Show word details if available
      if (wordState.currentWord != null) {
        return Container(
          // Removed margin
          key: key,
          child: Column(
            children: [
              const DetailTabs(), // Tabs for switching detail views
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(), // Nice scroll physics
                  padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                  child: DetailContent(wordEntry: wordState.currentWord!),
                ),
              ),
            ],
          ),
        );
      } else {
        // Should not happen if showDetails is true, but handle defensively
        return SizedBox.shrink(key: key);
      }
    }
  }

  // Builds the "Known" / "Unknown" buttons
  Widget _buildJudgementButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 28),
            label: const Text("不认识", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withAlpha(204), // Use theme error color
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: elevationLow,
            ),
            onPressed: () => _handleJudgement(false), // Mark as unknown
          ),
        ),
        const SizedBox(width: 24), // Spacing between buttons
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 28),
            label: const Text("认识", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.green.shade700.withAlpha(230), // Use green for known
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: elevationLow,
            ),
            onPressed: () => _handleJudgement(true), // Mark as known
          ),
        ),
      ],
    );
  }

  // Builds the overlay shown when the session is completed
  Widget _buildCompletionOverlay(
      BuildContext context, ThemeData theme, WordStateProvider wordState) {
    // Determine message based on whether there were words in the session
    final String message = wordState.hasWords ? '本次学习完成！' : '今天没有新单词要学啦！';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(153), // Semi-transparent overlay
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              style:
                  theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Reset session state and navigate back
                Provider.of<WordStateProvider>(context, listen: false)
                    .resetSession();
                Navigator.pop(context);
              },
              child: const Text("返回首页"),
            )
          ]),
        ),
      ),
    );
  }

  // Shows a confirmation dialog before exiting the learning session
  Future<void> _showExitConfirmationDialog(BuildContext context) async {
    final wordState = Provider.of<WordStateProvider>(context, listen: false);

    // If session completed because there were no words, exit directly
    if (wordState.isSessionComplete && !wordState.hasWords) {
      wordState.resetSession(); // Ensure state is reset
      Navigator.pop(context);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly choose an action
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认退出学习'),
          content: const Text('确定要结束本次学习吗？\n（学习进度已自动保存）'),
          actions: <Widget>[
            TextButton(
              child: const Text('继续学习'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false), // Return false
            ),
            TextButton(
                child: const Text('确定退出', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true); // Return true
                }),
          ],
        );
      },
    );

    // If user confirmed exit ('确定退出' was pressed)
    if (result == true && context.mounted) {
      wordState.resetSession(); // Reset state before navigating
      Navigator.pop(
          context); // Go back to the previous screen (likely HomePage)
    }
  }
}
