// frontend/lib/pages/review_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 需要 kDebugMode
import 'package:lexilearn/constants.dart'; // 使用你提供的 constants.dart
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
import 'package:lexilearn/models/word_entry.dart'; // Required by AnimatedWordHeader

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ChangeNotifierProvider for WordStateProvider specific to this page instance
    return ChangeNotifierProvider<WordStateProvider>(
      create: (_) => WordStateProvider(),
      child: const _ReviewPageContent(),
    );
  }
}

class _ReviewPageContent extends StatefulWidget {
  const _ReviewPageContent();

  @override
  State<_ReviewPageContent> createState() => _ReviewPageContentState();
}

class _ReviewPageContentState extends State<_ReviewPageContent> {
  final AudioService _audioService = AudioService();
  final HiveService _hiveService = HiveService(); // 实例化 HiveService
  final Stopwatch _sessionStopwatch = Stopwatch(); // **计时器实例**
  String? _currentUserId; // 缓存用户ID
  String? _currentBookId; // 缓存词库ID

  @override
  void initState() {
    super.initState();
    // 在 initState 获取 ID
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

    // **记录复习时长 (如果用户ID和词库ID存在且时长超过5秒)**
    if (_currentUserId != null &&
        _currentBookId != null &&
        _sessionStopwatch.elapsedMilliseconds > 5000) {
      _hiveService.logSessionDuration(
          _currentUserId!, _currentBookId!, _sessionStopwatch.elapsed);
      if (kDebugMode) {
        print(
            "[ReviewPage] Logged session duration: ${_sessionStopwatch.elapsed} for user $_currentUserId, book $_currentBookId");
      }
    } else if (kDebugMode) {
      print(
          "[ReviewPage] Session duration not logged (userId: $_currentUserId, bookId: $_currentBookId, durationMs: ${_sessionStopwatch.elapsedMilliseconds})");
    }
    // ------------

    super.dispose();
  }

  Future<void> _loadWords() async {
    // Get providers using listen: false
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vocabProvider = Provider.of<VocabProvider>(context, listen: false);
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    final wordStateProvider =
        Provider.of<WordStateProvider>(context, listen: false);

    // Ensure user and book are selected
    if (authProvider.userId == null || vocabProvider.selectedBookId == null) {
      if (mounted) {
        ErrorFeedback.showErrorSnackbar(context, "无法加载复习数据：用户或词库信息丢失");
        Navigator.pop(context);
      }
      return;
    }

    // TODO: Potentially check daily review limit here

    await wordStateProvider.loadWordsForSession(
      userId: authProvider.userId!,
      bookId: vocabProvider.selectedBookId!,
      type: SessionType.review, // Specify session type as review
      goal: planProvider.dailyReviewGoal, // Use review goal from plan provider
    );

    // Handle potential loading errors
    if (wordStateProvider.status == SessionStatus.error && mounted) {
      ErrorFeedback.showErrorSnackbar(
          context, wordStateProvider.errorMessage ?? "加载复习单词时出错");
    }
  }

  // Log review events when user makes a judgement
  Future<void> _handleJudgement(bool known) async {
    // known 参数表示用户是否点击了“认识”
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

    // 更新单词进度
    await _hiveService.updateWordProgress(
        userId, word.content.word.wordId, known);
    // 更新 UI 状态
    await wordState.markWord(known);

    // --- *** 修改日志记录逻辑 *** ---
    // 只有在复习页面点击“认识”时，才记录复习事件
    if (known) {
      _hiveService.logReviewEvent(userId, bookId);
      if (kDebugMode) {
        print(
            "[ReviewPage] Logged Review Event (known=true) for $userId, $bookId");
      }
    } else {
      if (kDebugMode) {
        print("[ReviewPage] Marked as unknown, no Review Event logged.");
      }
    }
    // --- *** 结束修改 *** ---
  }
  // --------------------------

  @override
  Widget build(BuildContext context) {
    // Use watch here to rebuild UI based on WordStateProvider changes
    final wordState = context.watch<WordStateProvider>();
    final theme = Theme.of(context);

    // Same Scaffold structure as LearnPage, just different session type logic
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: _buildAppBarTitle(
            context, wordState), // Use the same AppBar title widget
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            tooltip: '结束复习',
            onPressed: () => _showExitConfirmationDialog(
                context), // Use specific exit dialog
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
          colors: [primaryColor.withAlpha(150), secondaryColor.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(color: Colors.white.withAlpha(30)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                    top: wordState.showDetails
                        ? (MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            90)
                        : (MediaQuery.of(context).padding.top + kToolbarHeight),
                    left: 0,
                    right: 0,
                    bottom: 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _buildMainContent(
                      context, wordState), // Use the same main content builder
                ),
              ),
            ),
            AnimatedWordHeader(
              // Use the same animated header
              wordEntry: wordState.currentWord,
              showDetails: wordState.showDetails,
              audioService: _audioService,
            ),
            // Show completion overlay
            if (wordState.status == SessionStatus.completed)
              _buildCompletionOverlay(
                  context, theme, wordState), // Pass wordState here
          ],
        ),
      ),
      // Floating Action Button for "Next Word"
      floatingActionButton:
          wordState.showDetails && wordState.status == SessionStatus.active
              ? FloatingActionButton.extended(
                  onPressed: wordState.nextWord,
                  backgroundColor: secondaryColor,
                  foregroundColor: theme.colorScheme.primary,
                  label: const Text('下一词'),
                  icon: const Icon(Icons.skip_next_rounded),
                  shape: const StadiumBorder(),
                  elevation: elevationMedium,
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --- Reusable Widgets (Identical to LearnPage, can be refactored later if desired) ---

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
                : "复习", // Label as "Review"
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 5.0,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, WordStateProvider wordState) {
    final key = ValueKey<bool>(wordState.showDetails);

    if (!wordState.showDetails) {
      if (wordState.status == SessionStatus.active && wordState.hasWords) {
        return Align(
          key: key,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(
                left: 32.0, right: 32.0, bottom: 90.0, top: 16.0),
            child: _buildJudgementButtons(context),
          ),
        );
      } else {
        return SizedBox.shrink(key: key);
      }
    } else {
      if (wordState.currentWord != null) {
        return Container(
          // Removed margin
          key: key,
          child: Column(
            children: [
              const DetailTabs(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  child: DetailContent(wordEntry: wordState.currentWord!),
                ),
              ),
            ],
          ),
        );
      } else {
        return SizedBox.shrink(key: key);
      }
    }
  }

  Widget _buildJudgementButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 28),
            label: const Text("不认识", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.errorContainer.withAlpha(204),
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: elevationLow,
            ),
            onPressed: () => _handleJudgement(false),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 28),
            label: const Text("认识", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700.withAlpha(230),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: globalBorderRadius),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: elevationLow,
            ),
            onPressed: () => _handleJudgement(true),
          ),
        ),
      ],
    );
  }

  // Modified to accept wordState to determine message
  Widget _buildCompletionOverlay(
      BuildContext context, ThemeData theme, WordStateProvider wordState) {
    // Message specific to review completion
    final String message = wordState.hasWords
        ? '本次复习完成！'
        : '当前没有需要复习的单词。'; // Different message if no words were loaded

    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(153),
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

  // Shows a confirmation dialog specific to exiting review
  Future<void> _showExitConfirmationDialog(BuildContext context) async {
    final wordState = Provider.of<WordStateProvider>(context, listen: false);

    // Exit directly if completed with no words
    if (wordState.isSessionComplete && !wordState.hasWords) {
      wordState.resetSession();
      Navigator.pop(context);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认退出复习'), // Dialog title specific to review
          content: const Text('确定要结束本次复习吗？\n（复习进度已自动保存）'),
          actions: <Widget>[
            TextButton(
              child: const Text('继续复习'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
                child: const Text('确定退出', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                }),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      wordState.resetSession();
      Navigator.pop(context);
    }
  }
}
