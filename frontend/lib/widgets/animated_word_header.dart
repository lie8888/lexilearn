import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/models/word_entry.dart';
import 'package:lexilearn/services/audio_service.dart';

class AnimatedWordHeader extends StatelessWidget {
  final WordEntry? wordEntry;
  final bool showDetails;
  final AudioService audioService;

  const AnimatedWordHeader({
    Key? key,
    required this.wordEntry,
    required this.showDetails,
    required this.audioService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // --- 动画目标值 ---
    final double targetTop = mediaQuery.padding.top + 10;
    final double targetLeft = 16.0;
    final double targetMaxWidth = screenWidth * 0.7;
    final EdgeInsets targetPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final Alignment initialAlignment = Alignment.center;
    final Alignment targetAlignment = Alignment.topLeft;
    // 调整初始 Padding
    final EdgeInsets initialPadding =
        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0);

    // 文本样式 (判断和详情阶段一致)
    final TextStyle wordStyle =
        (theme.textTheme.displaySmall ?? const TextStyle(fontSize: 36))
            .copyWith(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor, // 统一使用深色
                height: 1.3);
    final TextStyle phoneticStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
            .copyWith(color: theme.colorScheme.onSurfaceVariant);
    const double phoneticIconSize = 18;

    // 背景和阴影 (始终透明/无)
    const Color backgroundColor = Colors.transparent;
    const List<BoxShadow> boxShadow = [];

    final wordDetails = wordEntry?.content.word.content;
    final String headWord = wordEntry?.headWord ?? "...";
    final String currentWordId = wordEntry?.content.word.wordId ??
        'loading_${DateTime.now().millisecondsSinceEpoch}';

    // ***** 使用 AnimatedAlign 和 AnimatedContainer 控制位置和样式 *****
    return AnimatedAlign(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: showDetails ? targetAlignment : initialAlignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(
          top: showDetails ? targetTop : 0,
          left: showDetails ? targetLeft : 0,
        ),
        // 详情阶段限制最大宽度，判断阶段不限制
        constraints:
            showDetails ? BoxConstraints(maxWidth: targetMaxWidth) : null,
        padding: showDetails ? targetPadding : initialPadding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: globalBorderRadius,
          boxShadow: boxShadow,
        ),
        key: ValueKey<String>(
            "anim_header_${currentWordId}_${showDetails ? 'detail' : 'judge'}"),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 高度自适应内容
          crossAxisAlignment: showDetails
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              style: wordStyle, // 两个阶段都用这个样式
              textAlign: showDetails ? TextAlign.left : TextAlign.center,
              child: Text(
                headWord,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedDefaultTextStyle(
              // 音标也使用动画样式
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              style: phoneticStyle, // 两个阶段都用这个样式
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: wordEntry != null ? 1.0 : 0.0, // 无单词时隐藏
                child: Wrap(
                  spacing: showDetails ? 8.0 : 16.0, // 间距变化
                  runSpacing: 4.0,
                  alignment:
                      showDetails ? WrapAlignment.start : WrapAlignment.center,
                  children: [
                    if (wordDetails != null && wordDetails.ukphone.isNotEmpty)
                      _buildPronunciationButton(
                          context,
                          "英 [${wordDetails.ukphone}]",
                          phoneticIconSize,
                          phoneticStyle.color,
                          () => audioService.playPronunciation(
                              wordDetails.ukspeech,
                              isUK: true)),
                    if (wordDetails != null && wordDetails.usphone.isNotEmpty)
                      _buildPronunciationButton(
                          context,
                          "美 [${wordDetails.usphone}]",
                          phoneticIconSize,
                          phoneticStyle.color,
                          () => audioService.playPronunciation(
                              wordDetails.usspeech,
                              isUK: false)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPronunciationButton(BuildContext context, String label,
      double iconSize, Color? color, VoidCallback onPressed) {
    final currentStyle = DefaultTextStyle.of(context).style;
    return TextButton.icon(
      icon: Icon(Icons.volume_up_outlined, size: iconSize, color: color),
      label:
          Text(label, style: currentStyle.copyWith(color: color)), // 使用动画文本样式
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
        foregroundColor: color,
      ),
    );
  }
}
