import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:lexilearn/models/word_entry.dart'; // 虽然不再直接使用，但保留以备将来可能需要
import 'package:lexilearn/services/api_service.dart';
import 'package:lexilearn/services/hive_service.dart';

class VocabService {
  final ApiService _apiService = ApiService();
  final HiveService _hiveService = HiveService();

  Future<({bool success, String? error, int wordsProcessed})>
      fetchAndStoreVocab(int vocabId, String bookId, String userId,
          ValueChanged<double>? onProgress) async {
    int wordsProcessed = 0;
    onProgress?.call(0.0);

    try {
      if (kDebugMode)
        print("[VocabService] Fetching download info for vocabId: $vocabId");
      final infoResponse = await _apiService.getVocabDownloadInfo(vocabId);
      if (!infoResponse['success']) {
        final errorMsg = "获取词库信息失败: ${infoResponse['error']}";
        if (kDebugMode) print("[VocabService] Error: $errorMsg");
        return (success: false, error: errorMsg, wordsProcessed: 0);
      }
      final String downloadUrl = infoResponse['jsonUrl'] ?? '';
      if (downloadUrl.isEmpty) {
        if (kDebugMode)
          print(
              "[VocabService] Error: Received empty download URL from backend.");
        return (success: false, error: "无效的下载链接", wordsProcessed: 0);
      }
      if (kDebugMode)
        print("[VocabService] Received download URL: $downloadUrl");

      onProgress?.call(0.1);

      if (kDebugMode)
        print(
            "[VocabService] Attempting to download file content from: $downloadUrl");
      final downloadResult = await _apiService.downloadJsonlFile(downloadUrl);
      if (!downloadResult.success || downloadResult.data == null) {
        final errorMsg = downloadResult.error ?? '文件下载失败 (未知原因)';
        if (kDebugMode) print("[VocabService] Error: $errorMsg");
        return (success: false, error: errorMsg, wordsProcessed: 0);
      }
      final String jsonlContent = downloadResult.data!;
      if (kDebugMode)
        print(
            "[VocabService] File download successful. Content length: ${jsonlContent.length}");

      onProgress?.call(0.3);

      final lines = jsonlContent.split('\n');
      final totalLines = lines.length > 0 ? lines.length : 1;
      if (kDebugMode)
        print(
            "[VocabService] Processing $totalLines lines for book: $bookId, user: $userId");
      final vocabBox = await _hiveService.openVocabBox(bookId, userId);

      int parseErrors = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final Map<String, dynamic> jsonMap = jsonDecode(line);
          String? wordId;
          final content = jsonMap['content'];
          if (content is Map<String, dynamic>) {
            final word = content['word'];
            if (word is Map<String, dynamic>) {
              wordId = word['wordId']?.toString();
            }
          }

          if (jsonMap.containsKey('headWord') &&
              wordId != null &&
              wordId.isNotEmpty) {
            await vocabBox.put(wordId, line);
            wordsProcessed++;
          } else {
            if (kDebugMode) {
              print(
                  "[VocabService] Skipping line ${i + 1} (missing headWord or wordId): ${line.substring(0, min(line.length, 100))}...");
            }
          }
        } catch (e) {
          parseErrors++;
          if (kDebugMode) {
            print(
                "[VocabService] Error decoding/processing line ${i + 1}: ${line.substring(0, min(line.length, 100))}... \nError: $e");
          }
        }

        if (i % 50 == 0 || i == lines.length - 1) {
          onProgress?.call(0.3 + (i / totalLines) * 0.7);
        }
      }

      onProgress?.call(1.0);
      if (kDebugMode) {
        print(
            "[VocabService] Vocab '$bookId' processed. Stored $wordsProcessed words. Encountered $parseErrors parsing errors.");
      }
      if (parseErrors > 0 && wordsProcessed == 0) {
        return (
          success: false,
          error: "JSONL 文件解析失败，无法存储任何单词。",
          wordsProcessed: 0
        );
      } else if (parseErrors > 0) {
        print(
            "[VocabService] Warning: $parseErrors lines failed to parse during import.");
        return (
          success: true,
          error: "$parseErrors 行解析失败",
          wordsProcessed: wordsProcessed
        );
      }
      return (success: true, error: null, wordsProcessed: wordsProcessed);
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "[VocabService] CRITICAL Error in fetchAndStoreVocab for vocab ID $vocabId: $e\n$s");
      }
      onProgress?.call(1.0);
      return (
        success: false,
        error: '处理词库时发生意外错误: $e',
        wordsProcessed: wordsProcessed
      );
    }
  }
}

// Helper function
int min(int a, int b) => a < b ? a : b;
