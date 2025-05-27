import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/providers/vocab_provider.dart'; // Import enum
import 'package:provider/provider.dart'; // Import Provider

class VocabCard extends StatelessWidget {
  final dynamic vocabItem;
  final VoidCallback onTap;
  final bool isSelected;
  final VocabDownloadStatus downloadStatus;
  final double downloadProgress;
  final bool isDisabled;

  const VocabCard({
    required this.vocabItem,
    required this.onTap,
    this.isSelected = false,
    this.downloadStatus = VocabDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.isDisabled = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = vocabItem['name'] ?? '未知词库';
    final String version = vocabItem['version'] ?? '';

    final Color cardBackgroundColor =
        theme.cardTheme.color ?? theme.colorScheme.surface;
    // Use a slightly different color for disabled state in M3
    final Color disabledBackgroundColor = Color.alphaBlend(
        theme.colorScheme.onSurface
            .withOpacity(0.08), // Lighter overlay for disabled
        cardBackgroundColor);
    final Color effectiveBackgroundColor =
        isDisabled ? disabledBackgroundColor : cardBackgroundColor;

    final Color? effectiveForegroundColor =
        isDisabled ? theme.colorScheme.onSurface.withOpacity(0.38) : null;

    final Color borderColor = isSelected
        ? theme.colorScheme.primary
        // Use Color.alphaBlend for border too, blending with surface color
        : Color.alphaBlend(
            theme.dividerColor.withOpacity(isDisabled ? 0.12 : 0.3),
            cardBackgroundColor);

    return Card(
      elevation: isSelected ? elevationHigh : elevationLow,
      color: effectiveBackgroundColor,
      shape: RoundedRectangleBorder(
          borderRadius: globalBorderRadius,
          side: BorderSide(
            color: borderColor,
            width: isSelected ? 2 : 1,
          )),
      child: InkWell(
        borderRadius: globalBorderRadius,
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DefaultTextStyle(
            style: TextStyle(
                color: effectiveForegroundColor), // Apply disabled style
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected && !isDisabled
                        ? theme.colorScheme.primary
                        : effectiveForegroundColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (version.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('v$version',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: effectiveForegroundColor?.withOpacity(0.6))),
                ],
                const Spacer(),
                _buildStatusIndicator(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ThemeData theme) {
    // Get error message safely using Provider.of only when needed
    final String errorMsg = (downloadStatus == VocabDownloadStatus.error)
        ? Provider.of<VocabProvider>(context, listen: false)
                .getDownloadError(vocabItem['bookId'] ?? vocabItem['name']) ??
            '未知错误'
        : '未知错误';

    switch (downloadStatus) {
      case VocabDownloadStatus.checking:
      case VocabDownloadStatus.downloading:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(
            value: downloadStatus == VocabDownloadStatus.downloading
                ? downloadProgress
                : null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Text(
              downloadStatus == VocabDownloadStatus.checking
                  ? '检查中...'
                  : '下载中... ${(downloadProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall),
        ]);
      case VocabDownloadStatus.error:
        return Tooltip(
          message: errorMsg,
          child: Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 32,
          ),
        );
      case VocabDownloadStatus.success:
      case VocabDownloadStatus.idle:
        return Icon(
          isSelected
              ? Icons.check_circle_rounded
              : Icons.download_for_offline_outlined,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          size: 32,
        );
    }
  }
}
