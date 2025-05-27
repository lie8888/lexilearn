import 'package:flutter/material.dart';
import 'package:lexilearn/providers/auth_provider.dart';
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:lexilearn/widgets/error_feedback.dart';
import 'package:lexilearn/widgets/vocab_card.dart'; // Ensure VocabCard accepts new status parameters
import 'package:provider/provider.dart';

class VocabSelectPage extends StatefulWidget {
  const VocabSelectPage({super.key});

  @override
  State<VocabSelectPage> createState() => _VocabSelectPageState();
}

class _VocabSelectPageState extends State<VocabSelectPage> {
  // Remove _downloadingVocabId, state is now tracked per-item in provider
  // int? _downloadingVocabId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vocabProvider = Provider.of<VocabProvider>(context, listen: false);
      if (vocabProvider.listStatus == VocabListStatus.initial || vocabProvider.listStatus == VocabListStatus.error) {
          vocabProvider.fetchVocabList();
      }
    });
  }

  Future<void> _handleSelection(dynamic vocabItem) async { // Renamed from _handleDownload
     final authProvider = Provider.of<AuthProvider>(context, listen: false);
     final vocabProvider = Provider.of<VocabProvider>(context, listen: false);

     if (authProvider.userId == null) {
        if (mounted) ErrorFeedback.showErrorSnackbar(context, "用户未登录，无法选择词库");
        return;
     }
      // Prevent concurrent selections while one is processing
      if (vocabProvider.isProcessingSelection) {
         ErrorFeedback.showSnackbar(context, "请稍候，正在处理之前的选择...");
         return;
      }

     bool success = await vocabProvider.selectAndDownloadVocab(vocabItem, authProvider.userId!);

     // Check mounted before interacting with context
     if (mounted) {
        // Get the bookId again for status checking
         final bookId = vocabItem['bookId']?.toString() ?? vocabItem['name']?.toString();
         if (bookId == null) return; // Should not happen if selection worked

         final currentStatus = vocabProvider.getDownloadStatus(bookId);
         final currentError = vocabProvider.getDownloadError(bookId);

        if (success) {
             // Check if there was a partial error during download/processing
             final successMsg = "${vocabItem['name']} 已选择";
            if (currentStatus == VocabDownloadStatus.success && currentError != null) {
               // Success overall, but maybe some lines failed parsing
               ErrorFeedback.showSuccessSnackbar(context, "$successMsg (注意: $currentError)");
            } else {
               ErrorFeedback.showSuccessSnackbar(context, successMsg);
            }
            Navigator.pushReplacementNamed(context, '/home');
        } else {
            // Show specific error for this bookId
            ErrorFeedback.showErrorSnackbar(context, "选择 ${vocabItem['name'] ?? '词库'} 失败: ${currentError ?? '未知错误'}");
        }
     }
  }


  @override
  Widget build(BuildContext context) {
    // Use watch here to react to loading/list/download status changes
    final vocabProvider = context.watch<VocabProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择词库'),
        actions: [
           if (vocabProvider.listStatus == VocabListStatus.loading || vocabProvider.isProcessingSelection) // Show general loading
              const Padding(
                 padding: EdgeInsets.only(right: 16.0),
                 child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
           else if (vocabProvider.listStatus != VocabListStatus.initial)
              IconButton(
                 icon: const Icon(Icons.refresh),
                 tooltip: '刷新列表',
                 onPressed: () => vocabProvider.fetchVocabList(),
              )
        ],
      ),
      body: _buildBody(context, vocabProvider, theme),
    );
  }

  Widget _buildBody(BuildContext context, VocabProvider provider, ThemeData theme) {
    switch (provider.listStatus) {
      case VocabListStatus.initial:
      case VocabListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case VocabListStatus.error:
        // ... (Error UI remains the same) ...
         return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, color: theme.colorScheme.error, size: 48),
                const SizedBox(height: 16),
                Text('加载词库列表失败', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                 Text(provider.listError ?? '未知网络错误', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                   icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                  onPressed: () => provider.fetchVocabList(),
                ),
              ],
            ),
          ),
        );
      case VocabListStatus.loaded:
        if (provider.availableVocabs.isEmpty) {
           return const Center(child: Text('服务器上没有可用的词库。'));
        }
        return RefreshIndicator(
           onRefresh: () => provider.fetchVocabList(),
           child: GridView.builder(
             physics: const AlwaysScrollableScrollPhysics(),
             padding: const EdgeInsets.all(16.0),
             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
               crossAxisSpacing: 16,
               mainAxisSpacing: 16,
               childAspectRatio: 3 / 2.8, // Adjust aspect ratio slightly for status text
             ),
             itemCount: provider.availableVocabs.length,
             itemBuilder: (context, index) {
               final item = provider.availableVocabs[index];
                final bookId = item['bookId']?.toString() ?? item['name']?.toString() ?? 'unknown_$index';
               final isSelected = provider.selectedBookId == bookId;
               // Get status and progress for THIS specific card
               final downloadStatus = provider.getDownloadStatus(bookId);
               final progress = provider.getDownloadProgress(bookId);
               // Disable tap if any selection is processing OR this specific one is downloading/checking
               final bool interactionDisabled = provider.isProcessingSelection ||
                   downloadStatus == VocabDownloadStatus.downloading ||
                   downloadStatus == VocabDownloadStatus.checking;

               // *** Pass download status to VocabCard ***
               return VocabCard(
                 vocabItem: item,
                 onTap: () => _handleSelection(item),
                 isSelected: isSelected,
                 downloadStatus: downloadStatus, // Pass the specific status
                 downloadProgress: progress,
                 isDisabled: interactionDisabled, // Pass disabled state
               );
             },
           ),
        );
    }
  }
}