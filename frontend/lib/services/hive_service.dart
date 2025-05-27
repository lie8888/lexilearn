// frontend/lib/services/hive_service.dart

import 'dart:convert';
import 'dart:math'; // 需要 pow 和 max
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // 需要 DateFormat
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/models/word_entry.dart';
import 'package:lexilearn/providers/stats_provider.dart'; // 需要 StatsChartDataPoint

class HiveService {
  // --- Box 名称生成助手 ---

  /// 为指定用户和 bookId 生成安全的 Hive Box 名称
  String getSafeVocabBoxName(String bookId, String userId) {
    // Base64Url 编码 bookId 以处理特殊字符
    final encodedBookId = base64UrlEncode(utf8.encode(bookId));
    final boxName = '$HIVE_BOX_VOCAB_PREFIX${encodedBookId}_$userId';
    // Hive Box 名称长度限制通常是 255
    if (boxName.length > 255) {
      if (kDebugMode) {
        print("[HiveService] 警告: 生成的 Hive Box 名称超过 255 个字符: $boxName");
      }
      // 可以考虑截断或哈希处理，但目前仅打印警告
    }
    return boxName;
  }

  /// 获取用户进度 Box 名称
  String _getProgressBoxName(String userId) =>
      '${HIVE_BOX_PROGRESS}_$userId'; // 使用 v3

  /// 获取用户计划 Box 名称
  String _getPlanBoxName(String userId) => '${HIVE_BOX_PLAN}_$userId';

  /// 获取用户错词本 Box 名称
  String _getWrongWordsBoxName(String userId) =>
      '${HIVE_BOX_WRONG_WORDS}_$userId';

  /// 获取用户配置 Box 名称
  String _getConfigBoxName(String userId) => '${HIVE_BOX_CONFIG}_$userId';

  /// 获取用户每日统计 Box 名称
  String _getDailyStatsBoxName(String userId) =>
      '${HIVE_BOX_DAILY_STATS}_$userId';

  // --------------------

  /// 初始化 Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    // 注意：这里不需要注册 Adapter，因为我们直接存储 JSON 字符串或 Map
  }

  /// 打开指定用户的所有标准 Box (不包括词库 Box)
  Future<void> openUserBoxes(String userId) async {
    final progressBoxName = _getProgressBoxName(userId);
    final dailyStatsBoxName = _getDailyStatsBoxName(userId);
    final configBoxName = _getConfigBoxName(userId);
    final planBoxName = _getPlanBoxName(userId);
    final wrongWordsBoxName = _getWrongWordsBoxName(userId);

    // 按顺序尝试打开各个 Box
    try {
      if (!Hive.isBoxOpen(configBoxName)) {
        await Hive.openBox(configBoxName);
      }
      if (!Hive.isBoxOpen(planBoxName)) {
        await Hive.openBox(planBoxName);
      }
      if (!Hive.isBoxOpen(wrongWordsBoxName)) {
        await Hive.openBox<String>(wrongWordsBoxName);
      }
      if (!Hive.isBoxOpen(progressBoxName)) {
        // 指定类型为 <Map<String, dynamic>> 或 <Map>
        // 强制指定类型有助于类型安全，但如果旧数据格式不兼容可能导致问题
        // 使用 <Map> 更灵活，但在读取时需要做类型检查
        await Hive.openBox<Map>(progressBoxName);
      }
      if (!Hive.isBoxOpen(dailyStatsBoxName)) {
        await Hive.openBox<Map>(dailyStatsBoxName);
      }
      if (kDebugMode) {
        print("[HiveService] Standard user boxes opened for $userId.");
      }
    } catch (e, s) {
      // 如果任何一个 Box 打开失败，则抛出异常，让调用者处理
      if (kDebugMode) {
        print(
            "[HiveService] CRITICAL Error opening user boxes for $userId: $e\n$s");
      }
      // 可以选择性地关闭已成功打开的 Box，或者直接 rethrow
      rethrow;
    }
  }

  /// 关闭指定用户的所有标准 Box (不包括词库 Box)
  Future<void> closeUserBoxes(String userId) async {
    if (kDebugMode) {
      print(
          "[HiveService] Attempting to close standard boxes for user $userId.");
    }
    // 获取所有 Box 名称
    final configBoxName = _getConfigBoxName(userId);
    final planBoxName = _getPlanBoxName(userId);
    final wrongWordsBoxName = _getWrongWordsBoxName(userId);
    final progressBoxName = _getProgressBoxName(userId);
    final dailyStatsBoxName = _getDailyStatsBoxName(userId);

    // 依次安全关闭
    await _safeCloseBox(configBoxName);
    await _safeCloseBox(planBoxName);
    await _safeCloseBox<String>(wrongWordsBoxName);
    await _safeCloseBox<Map>(progressBoxName);
    await _safeCloseBox<Map>(dailyStatsBoxName);
    // TODO: 需要一个机制来查找并关闭该用户所有打开的词库 Box
    // (这比较复杂，可能需要在 AuthProvider 中维护一个打开的词库 Box 列表)
  }

  /// 安全地关闭一个 Box，如果它已打开
  Future<void> _safeCloseBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<T>(boxName).close();
        if (kDebugMode) {
          print("[HiveService] Closed box: $boxName");
        }
      }
    } catch (e) {
      // 记录错误，但不中断流程
      if (kDebugMode) {
        print("[HiveService] Error closing box $boxName: $e");
      }
    }
  }

  /// 清理指定用户的所有标准 Box 内容 (不删除 Box 文件)
  Future<void> clearAllUserBoxes(String userId) async {
    if (kDebugMode) {
      print(
          "[HiveService] Clearing content of standard boxes for user $userId.");
    }
    // 获取所有 Box 名称
    final configBoxName = _getConfigBoxName(userId);
    final planBoxName = _getPlanBoxName(userId);
    final wrongWordsBoxName = _getWrongWordsBoxName(userId);
    final progressBoxName = _getProgressBoxName(userId);
    final dailyStatsBoxName = _getDailyStatsBoxName(userId);

    // 依次安全清理
    await _safeClearBox(configBoxName);
    await _safeClearBox(planBoxName);
    await _safeClearBox<String>(wrongWordsBoxName);
    await _safeClearBox<Map>(progressBoxName);
    await _safeClearBox<Map>(dailyStatsBoxName);
    // TODO: 需要机制来清理词库 Box
  }

  /// 安全地清理一个 Box 的内容
  Future<void> _safeClearBox<T>(String boxName) async {
    try {
      // 确保 Box 是打开的才能清理
      if (!Hive.isBoxOpen(boxName)) {
        if (kDebugMode) {
          print("[HiveService] Box $boxName not open, opening to clear.");
        }
        // 如果需要清理未打开的 Box，需要先打开它
        await Hive.openBox<T>(boxName);
      }
      await Hive.box<T>(boxName).clear();
      if (kDebugMode) {
        print("[HiveService] Cleared box: $boxName");
      }
      // 可选：清理后关闭 Box
      // await Hive.box<T>(boxName).close();
    } catch (e) {
      // 记录错误，但不中断流程
      if (kDebugMode) {
        print("[HiveService] Error clearing box $boxName: $e");
      }
    }
  }

  // --- 词库相关 ---

  /// 打开指定用户和 bookId 的词库 Box
  Future<Box<String>> openVocabBox(String bookId, String userId) async {
    final boxName = getSafeVocabBoxName(bookId, userId);
    if (Hive.isBoxOpen(boxName)) {
      // 如果已打开，确保返回正确的类型
      try {
        return Hive.box<String>(boxName);
      } catch (e) {
        // 类型不匹配？
        if (kDebugMode) {
          print("[HiveService] Box $boxName open but type mismatch? Error: $e");
        }
        // 尝试重新以正确类型打开
        await _safeCloseBox(boxName); // 先关闭
        return await Hive.openBox<String>(boxName);
      }
    }
    if (kDebugMode) {
      print(
          "[HiveService] Opening vocab box with safe name: $boxName (Original bookId: $bookId)");
    }
    try {
      return await Hive.openBox<String>(boxName);
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "[HiveService] CRITICAL Error opening vocab box $boxName: $e\n$s");
      }
      // 抛出更具体的异常
      throw Exception("Failed to open vocabulary box '$bookId': $e");
    }
  }

  /// 检查词库 Box 是否存在且不为空
  Future<bool> vocabBoxExistsAndIsNotEmpty(String bookId, String userId) async {
    final boxName = getSafeVocabBoxName(bookId, userId);
    // 首先检查 Box 文件是否存在
    bool boxExists = await Hive.boxExists(boxName);
    if (!boxExists) {
      return false; // 文件不存在，肯定为空
    }
    // 文件存在，尝试打开并检查是否为空
    Box<String>? box;
    try {
      box = await Hive.openBox<String>(boxName);
      final bool isNotEmpty = box.isNotEmpty;
      // 检查完后可以立即关闭，减少资源占用，但下次访问需要重新打开
      // await box.close();
      return isNotEmpty;
    } catch (e) {
      // 打开失败，可能文件损坏，视为无效或空
      if (kDebugMode) {
        print("[HiveService] Error checking emptiness of box $boxName: $e");
      }
      // 确保即使出错也关闭 Box
      await _safeCloseBox(boxName);
      return false;
    }
  }

  /// 存储单个单词的 JSON 字符串到对应的词库 Box
  Future<void> storeWordJson(
      String bookId, String userId, String wordId, String jsonString) async {
    // 确保 wordId 和 jsonString 不为空
    if (wordId.isEmpty || jsonString.isEmpty) {
      if (kDebugMode) {
        print(
            "[HiveService] Warning: Attempted to store empty wordId or jsonString for book $bookId.");
      }
      return;
    }
    try {
      final box = await openVocabBox(bookId, userId);
      await box.put(wordId, jsonString);
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error storing word $wordId in book $bookId: $e");
      }
      // 可以选择性地 rethrow 或处理错误
    }
  }

  /// 从指定的词库 Box 中获取并解析单个单词
  Future<WordEntry?> getWord(
      String bookId, String userId, String wordId) async {
    Box<String>? box;
    try {
      box = await openVocabBox(bookId, userId);
      final jsonString = box.get(wordId);
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          // 解析 JSON
          final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
          // 使用 WordEntry.fromJson 工厂方法创建对象
          return WordEntry.fromJson(jsonMap);
        } catch (e) {
          // JSON 解析失败
          if (kDebugMode) {
            print(
                "[HiveService] Error parsing JSON for word $wordId in book $bookId: $e\nJSON: $jsonString");
          }
          return null; // 返回 null 表示解析失败
        }
      }
      // Key 不存在或值为空
      return null;
    } catch (e) {
      // Box 操作失败
      if (kDebugMode) {
        print(
            "[HiveService] Error getting word $wordId from Hive box for book $bookId: $e");
      }
      return null;
    }
    // finally { // 不需要每次都关闭，除非内存敏感
    //   await _safeCloseBox(getSafeVocabBoxName(bookId, userId));
    // }
  }

  /// 获取用于学习新单词的列表
  Future<List<WordEntry>> getWordsForLearning(
      String bookId, String userId, int count) async {
    if (count <= 0) {
      return []; // 如果请求数量为0或负数，直接返回空列表
    }

    Box<Map>? progressBox;
    Box<String>? vocabBox;
    try {
      // 获取进度 Box (确保已打开)
      progressBox = getProgressBox(userId);
      // 打开当前词库 Box
      vocabBox = await openVocabBox(bookId, userId);
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error opening required boxes for learning: $e");
      }
      return []; // 无法打开必要的 Box，返回空列表
    }

    final List<String> wordsToLearnIds = [];
    // 获取当前词库的所有 wordId
    final List<String> allWordIdsInBook = vocabBox.keys.cast<String>().toList();

    // 打乱顺序，避免每次学习的单词顺序固定
    allWordIdsInBook.shuffle();

    if (kDebugMode) {
      print(
          "[HiveService][Learn] Total words in book $bookId: ${allWordIdsInBook.length}");
    }

    // 遍历词库中的单词 ID
    for (final wordId in allWordIdsInBook) {
      // 检查进度 Box 中是否存在该单词的记录
      final bool hasProgress = progressBox.containsKey(wordId);
      // 如果没有进度记录，说明是新单词
      if (!hasProgress) {
        wordsToLearnIds.add(wordId);
      }
      // 如果已找到足够数量的新单词，停止查找
      if (wordsToLearnIds.length >= count) {
        break;
      }
    }

    if (kDebugMode) {
      print(
          "[HiveService][Learn] Found ${wordsToLearnIds.length} potential new words.");
    }

    // 根据找到的 ID 列表，获取完整的 WordEntry 对象
    final List<WordEntry> wordsToLearn = [];
    for (String id in wordsToLearnIds) {
      // 使用 getWord 方法获取并解析单词数据
      final word = await getWord(bookId, userId, id);
      if (word != null) {
        wordsToLearn.add(word);
      } else {
        // 如果 getWord 返回 null，说明数据可能损坏或丢失
        if (kDebugMode) {
          print(
              "[HiveService] Warning: WordEntry ID $id in book $bookId not found/parsed during learning load.");
        }
      }
    }

    if (kDebugMode) {
      print(
          "[HiveService][Learn] Successfully loaded ${wordsToLearn.length} WordEntry objects for learning.");
    }
    return wordsToLearn;
  }

  /// 获取用于复习的单词列表
  Future<List<WordEntry>> getWordsForReview(
      String bookId, String userId, int count) async {
    if (count <= 0) {
      return [];
    }

    Box<String>? wrongWordsBox;
    Box<Map>? progressBox;
    try {
      // 获取错词本 Box 和进度 Box (确保已打开)
      wrongWordsBox = getWrongWordsBox(userId);
      progressBox = getProgressBox(userId);
      // 确保当前词库 Box 已打开，因为需要用 getWord 获取单词详情
      await openVocabBox(bookId, userId);
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error opening required boxes for review: $e");
      }
      return [];
    }

    final List<WordEntry> wordsToReview = [];
    final DateTime now = DateTime.now().toUtc().dateOnly; // 获取当前 UTC 日期

    // 1. 获取所有错词 ID
    List<String> wrongWordIds = wrongWordsBox.values.toList();
    wrongWordIds.shuffle(); // 打乱错词顺序

    // 2. 获取所有到期的单词 ID (排除已在错词本中的)
    List<String> dueWordIds = [];
    // 遍历进度 Box 中的所有条目
    final Map<dynamic, dynamic> progressMap = Map.from(progressBox.toMap());
    progressMap.forEach((key, value) {
      // 确保 key 是 String 类型
      if (key is String) {
        final String wordId = key;
        // 检查 value 是否是 Map 类型
        if (value is Map) {
          // 尝试获取 dueDate 字符串
          final dynamic dueDateValue = value['dueDate'];
          if (dueDateValue is String) {
            // 尝试解析 dueDate
            final DateTime? dueDate =
                DateTime.tryParse(dueDateValue)?.toUtc().dateOnly;
            // 如果 dueDate 有效且不晚于今天
            if (dueDate != null && !dueDate.isAfter(now)) {
              // 如果该单词不在错词本中，则加入到期列表
              if (!wrongWordIds.contains(wordId)) {
                dueWordIds.add(wordId);
              }
            }
          } else if (dueDateValue != null) {
            // 记录 dueDate 类型错误
            if (kDebugMode) {
              print(
                  "[HiveService][Review] dueDate for key '$wordId' not String: ${dueDateValue.runtimeType}");
            }
          }
        } else if (value != null) {
          // 记录 progress value 类型错误
          if (kDebugMode) {
            print(
                "[HiveService][Review] Progress data for key '$wordId' not Map: ${value.runtimeType}");
          }
        }
      } else if (key != null) {
        // 记录 progress key 类型错误
        if (kDebugMode) {
          print("[HiveService][Review] Progress box non-string key: $key");
        }
      }
    });
    dueWordIds.shuffle(); // 打乱到期单词顺序

    // 3. 合并错词和到期单词 ID，优先错词，去重
    // 使用 Set 去重，然后转回 List 以保持顺序（虽然 shuffle 了，但 Set 本身无序）
    List<String> finalReviewIds = [...wrongWordIds, ...dueWordIds];
    // 如果需要严格去重（一个单词可能既在错词本又到期），用 Set
    // List<String> finalReviewIds = {...wrongWordIds, ...dueWordIds}.toList();
    // 或者保持重复，让复习次数增加？当前实现是合并，可能有重复，取决于业务逻辑

    if (kDebugMode) {
      print(
          "[HiveService][Review] Found ${wrongWordIds.length} wrong words and ${dueWordIds.length} due words.");
    }

    // 4. 选取所需数量的单词 ID
    finalReviewIds = finalReviewIds.take(count).toList();
    if (kDebugMode) {
      print(
          "[HiveService][Review] Taking ${finalReviewIds.length} words for this session.");
    }

    // 5. 获取完整的 WordEntry 对象
    for (String id in finalReviewIds) {
      // 确保这个 ID 确实属于当前 bookId (虽然进度是全局的，但复习应该基于当前书)
      // （这一步可选，取决于是否允许跨书复习。当前假设只复习当前书的）
      // final bool belongsToCurrentBook = (await openVocabBox(bookId, userId)).containsKey(id);
      // if (!belongsToCurrentBook) continue; // 如果需要严格限制在当前书

      final word = await getWord(bookId, userId, id);
      if (word != null) {
        wordsToReview.add(word);
      } else {
        if (kDebugMode) {
          print(
              "[HiveService] Warning: WordEntry ID $id in book $bookId not found/parsed during review load.");
        }
        // 如果单词在进度或错词本里，但在词库 Box 里找不到，可能需要处理这种数据不一致
        // 可以考虑从进度/错词本中移除这个无效 ID
        // await progressBox.delete(id);
        // await wrongWordsBox.delete(id);
      }
    }

    if (kDebugMode) {
      print(
          "[HiveService][Review] Successfully loaded ${wordsToReview.length} WordEntry objects for review.");
    }
    return wordsToReview;
  }

  // --- 计划相关 ---

  /// 获取用户计划 Box (确保已打开)
  Box getPlanBox(String userId) {
    final boxName = _getPlanBoxName(userId);
    if (!Hive.isBoxOpen(boxName)) {
      // 通常 openUserBoxes 时已打开，这里作为后备
      if (kDebugMode)
        print(
            "[HiveService] Warning: Plan box $boxName was not open. Returning potentially closed box.");
      // 返回未打开的 Box 实例可能导致后续操作失败，更安全的做法是确保打开
      // await Hive.openBox(boxName);
      // return Hive.box(boxName);
      // 或者抛出异常
      throw Exception("Plan box $boxName is not open.");
    }
    return Hive.box(boxName);
  }

  /// 设置每日学习目标
  Future<void> setDailyLearnGoal(String userId, int goal) async {
    try {
      await getPlanBox(userId).put(HIVE_KEY_DAILY_LEARN_GOAL, goal);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error setting learn goal for $userId: $e");
    }
  }

  /// 获取每日学习目标
  int getDailyLearnGoal(String userId) {
    try {
      return getPlanBox(userId)
          .get(HIVE_KEY_DAILY_LEARN_GOAL, defaultValue: 10);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error getting learn goal for $userId: $e");
      return 10; // 返回默认值
    }
  }

  /// 设置每日复习目标
  Future<void> setDailyReviewGoal(String userId, int goal) async {
    try {
      await getPlanBox(userId).put(HIVE_KEY_DAILY_REVIEW_GOAL, goal);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error setting review goal for $userId: $e");
    }
  }

  /// 获取每日复习目标
  int getDailyReviewGoal(String userId) {
    try {
      return getPlanBox(userId)
          .get(HIVE_KEY_DAILY_REVIEW_GOAL, defaultValue: 20);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error getting review goal for $userId: $e");
      return 20; // 返回默认值
    }
  }

  // --- 进度相关 ---

  /// 获取用户进度 Box (确保已打开)
  Box<Map> getProgressBox(String userId) {
    final boxName = _getProgressBoxName(userId);
    if (!Hive.isBoxOpen(boxName)) {
      if (kDebugMode)
        print(
            "[HiveService] Warning: Progress box $boxName was not open. Returning potentially closed box.");
      throw Exception("Progress box $boxName is not open.");
    }
    // 返回时强制转换为正确的类型
    try {
      return Hive.box<Map>(boxName);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error casting progress box $boxName: $e");
      throw Exception("Progress box $boxName type mismatch or error: $e");
    }
  }

  /// 更新单词学习进度 (SM-2 简化逻辑)
  Future<void> updateWordProgress(
      String userId, String wordId, bool known) async {
    try {
      final box = getProgressBox(userId);
      // 获取现有进度，注意类型安全
      Map<String, dynamic> currentProgress = {};
      final dynamic existingData = box.get(wordId);

      // 检查现有数据是否是 Map 类型
      if (existingData is Map) {
        // 尝试将 Map<dynamic, dynamic> 转换为 Map<String, dynamic>
        try {
          existingData.forEach((key, value) {
            if (key is String) {
              currentProgress[key] = value;
            } else {
              if (kDebugMode)
                print(
                    "[HiveService][UpdateProgress] Non-string key found: $key for word $wordId");
            }
          });
        } catch (e) {
          // 转换失败，重置进度
          if (kDebugMode) {
            print(
                "[HiveService][UpdateProgress] Error converting existing map for '$wordId': $e. Resetting progress.");
          }
          currentProgress = {}; // 重置为空 Map
        }
      } else if (existingData != null) {
        // 如果不是 Map 但存在，说明数据格式有问题，重置
        if (kDebugMode) {
          print(
              "[HiveService][UpdateProgress] Existing progress data for '$wordId' is not a Map (${existingData.runtimeType}). Resetting progress.");
        }
        currentProgress = {};
      }

      // 计算新的连续正确次数
      int consecutiveCorrect =
          (currentProgress['consecutiveCorrect'] as int?) ?? 0;
      consecutiveCorrect = known ? consecutiveCorrect + 1 : 0;

      // 计算下一次复习日期
      DateTime nextDueDate = DateTime.now().toUtc(); // 基准时间
      if (known) {
        // 认识：使用指数间隔
        int intervalDays = 1; // 首次认识，1天后复习
        if (consecutiveCorrect > 1) {
          // 从第二次认识开始应用指数退避
          // 使用 pow 计算指数，注意结果是 double，需要转 int
          intervalDays = pow(2, consecutiveCorrect - 1).toInt();
        }
        // 设置最大间隔，例如半年 (180天)
        intervalDays = intervalDays.clamp(1, 180);
        nextDueDate = nextDueDate.add(Duration(days: intervalDays));
        if (kDebugMode) {
          print(
              "[HiveService] Word '$wordId' known (Streak: $consecutiveCorrect). Next due: ${nextDueDate.toIso8601String()} (in $intervalDays days)");
        }
      } else {
        // 不认识：通常第二天就需要复习
        nextDueDate = nextDueDate.add(const Duration(days: 1));
        if (kDebugMode) {
          print(
              "[HiveService] Word '$wordId' unknown. Next due: ${nextDueDate.toIso8601String()}");
        }
      }

      // 更新进度 Map
      currentProgress['consecutiveCorrect'] = consecutiveCorrect;
      currentProgress['lastReviewed'] =
          DateTime.now().toUtc().toIso8601String(); // 记录本次复习时间
      // 存储日期部分，确保比较时忽略时间
      currentProgress['dueDate'] =
          nextDueDate.toUtc().dateOnly.toIso8601String();

      // 将更新后的 Map 写回 Box
      await box.put(wordId, currentProgress);

      // 更新错词本
      final wrongBox = getWrongWordsBox(userId);
      if (!known) {
        // 不认识，加入错词本 (如果已存在则覆盖)
        await wrongBox.put(wordId, wordId);
      } else {
        // 认识，从错词本中移除 (如果存在)
        if (wrongBox.containsKey(wordId)) {
          await wrongBox.delete(wordId);
        }
      }
    } catch (e, s) {
      if (kDebugMode)
        print("[HiveService] Error updating progress for $wordId: $e\n$s");
    }
  }

  // --- 错词本相关 ---

  /// 获取用户错词本 Box (确保已打开)
  Box<String> getWrongWordsBox(String userId) {
    final boxName = _getWrongWordsBoxName(userId);
    if (!Hive.isBoxOpen(boxName)) {
      if (kDebugMode)
        print(
            "[HiveService] Warning: Wrong words box $boxName was not open. Returning potentially closed box.");
      throw Exception("Wrong words box $boxName is not open.");
    }
    try {
      return Hive.box<String>(boxName);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error casting wrong words box $boxName: $e");
      throw Exception("Wrong words box $boxName type mismatch or error: $e");
    }
  }

  /// 添加单词到错词本
  Future<void> addWrongWord(String userId, String wordId) async {
    try {
      await getWrongWordsBox(userId).put(wordId, wordId);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error adding wrong word $wordId for $userId: $e");
    }
  }

  /// 从错词本中移除单词
  Future<void> removeWrongWord(String userId, String wordId) async {
    try {
      await getWrongWordsBox(userId).delete(wordId);
    } catch (e) {
      if (kDebugMode)
        print(
            "[HiveService] Error removing wrong word $wordId for $userId: $e");
    }
  }

  /// 获取所有错词的 ID 列表
  List<String> getAllWrongWordIds(String userId) {
    try {
      // .values.toList() 因为我们存的是 wordId -> wordId
      return getWrongWordsBox(userId).values.toList();
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error getting all wrong words for $userId: $e");
      return [];
    }
  }

  // =============================================
  // ===== 统计数据相关方法 (查询与记录) =====
  // =============================================

  /// 获取每日统计 Box (确保已打开)
  Box<Map> _getDailyStatsBox(String userId) {
    final boxName = _getDailyStatsBoxName(userId);
    if (!Hive.isBoxOpen(boxName)) {
      if (kDebugMode)
        print(
            "[HiveService] Warning: Daily stats box $boxName was not open. Returning potentially closed box.");
      throw Exception("Daily stats box $boxName is not open.");
    }
    try {
      return Hive.box<Map>(boxName);
    } catch (e) {
      if (kDebugMode)
        print("[HiveService] Error casting daily stats box $boxName: $e");
      throw Exception("Daily stats box $boxName type mismatch or error: $e");
    }
  }

  /// 获取配置 Box (确保已打开)
  Box _getConfigBox(String userId) {
    final boxName = _getConfigBoxName(userId);
    if (!Hive.isBoxOpen(boxName)) {
      if (kDebugMode)
        print(
            "[HiveService] Warning: Config box $boxName was not open. Returning potentially closed box.");
      throw Exception("Config box $boxName is not open.");
    }
    return Hive.box(boxName);
  }

  /// 获取指定词库的总单词数
  Future<int> getTotalWordCount(String bookId, String userId) async {
    try {
      // 打开对应的词库 Box 并返回其长度
      final box = await openVocabBox(bookId, userId);
      return box.length;
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error getting total word count for $bookId: $e");
      }
      return 0; // 出错时返回 0
    }
  }

  /// **[已修复]** 获取指定词库中已学习的单词数
  Future<int> getLearnedWordCount(String bookId, String userId) async {
    int learnedCount = 0;
    try {
      // 获取进度 Box
      final progressBox = getProgressBox(userId);
      // 打开当前词库 Box 以获取其包含的 wordId
      final vocabBox = await openVocabBox(bookId, userId);
      final wordIdsInBook = vocabBox.keys;

      // 遍历当前词库的 wordId
      for (final wordId in wordIdsInBook) {
        // 检查该 wordId 是否在进度 Box 中有记录
        if (progressBox.containsKey(wordId)) {
          learnedCount++;
        }
      }
      if (kDebugMode) {
        print(
            "[HiveService] Found $learnedCount learned words for book $bookId for user $userId.");
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "[HiveService] Error getting learned word count for book $bookId, user $userId: $e\n$s");
      }
      learnedCount = 0; // 出错时返回 0
    }
    return learnedCount;
  }

  // 获取今日学习和复习的单词数 (目前是所有词库总和)
  Future<({int learned, int reviewed})> getTodayCounts(
      String bookId, String userId) async {
    int learned = 0; // 初始化为 0
    int reviewed = 0; // 初始化为 0
    try {
      final dailyStatsBox = _getDailyStatsBox(userId);
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // *** 添加日志：打印尝试读取的 Key ***
      if (kDebugMode)
        print("[HiveService][getTodayCounts] Reading data for key: $todayKey");
      final Map? todayData = dailyStatsBox.get(todayKey);
      // *** 添加日志：打印读取到的原始 Map 数据 ***
      if (kDebugMode)
        print(
            "[HiveService][getTodayCounts] Raw data read from box: $todayData");

      if (todayData != null) {
        // TODO: 按 bookId 过滤 (需要修改 daily_stats 结构)
        learned =
            (todayData[DAILY_STATS_KEY_LEARNED_COUNT] as num?)?.toInt() ?? 0;
        reviewed =
            (todayData[DAILY_STATS_KEY_REVIEWED_COUNT] as num?)?.toInt() ?? 0;
        // *** 添加日志：打印解析后的值 ***
        if (kDebugMode)
          print(
              "[HiveService][getTodayCounts] Parsed counts - Learned: $learned, Reviewed: $reviewed");
      } else {
        if (kDebugMode)
          print("[HiveService][getTodayCounts] No data found for today.");
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "[HiveService][getTodayCounts] Error getting today counts for $userId: $e\n$s");
      }
      // 出错时保持 learned 和 reviewed 为 0
    }
    // 返回结果
    return (learned: learned, reviewed: reviewed);
  }


  /// 获取今日学习总时长 (目前是所有词库总和)
  Future<Duration> getTodayDuration(String bookId, String userId) async {
    try {
      final dailyStatsBox = _getDailyStatsBox(userId);
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final Map? todayData = dailyStatsBox.get(todayKey);

      if (todayData != null) {
        // TODO: 按 bookId 过滤 (需要修改 daily_stats 结构)
        // 读取总时长
        final int durationMs =
            (todayData[DAILY_STATS_KEY_DURATION_MS] as num?)?.toInt() ?? 0;
        return Duration(milliseconds: durationMs);
      }
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error getting today duration for $userId: $e");
      }
    }
    // 默认返回 0
    return Duration.zero;
  }

  /// 获取累计学习总时长 (所有词库总和)
  Future<Duration> getTotalDuration(String userId) async {
    try {
      final configBox = _getConfigBox(userId);
      // 从 config Box 读取累计时长
      final int totalMs =
          configBox.get(CONFIG_KEY_TOTAL_DURATION_MS, defaultValue: 0);
      return Duration(milliseconds: totalMs);
    } catch (e) {
      if (kDebugMode) {
        print(
            "[HiveService] Error getting total duration from config for $userId: $e");
      }
      return Duration.zero; // 默认返回 0
    }
  }

  /// 内部辅助方法：更新每日统计 Map 中的某个 key
  Future<void> _updateDailyStat(
      String userId, String todayKey, String statKey, int increment,
      {String? bookId}) async {
    try {
      final dailyStatsBox = _getDailyStatsBox(userId);
      // 获取当天的统计 Map，如果不存在则创建一个新的空 Map
      // 使用 Map.from 确保我们得到的是可修改的副本
      final Map<dynamic, dynamic> todayDataDyn =
          Map.from(dailyStatsBox.get(todayKey) ?? {});

      // TODO: 实现按 bookId 存储的逻辑
      // if (bookId != null) {
      //   // 示例: 获取或创建 'by_book' 子 Map
      //   Map<dynamic, dynamic> byBook = Map.from(todayDataDyn['by_book'] ?? {});
      //   Map<dynamic, dynamic> bookStats = Map.from(byBook[bookId] ?? {});
      //   final int currentBookCount = (bookStats[statKey] as num?)?.toInt() ?? 0;
      //   bookStats[statKey] = currentBookCount + increment;
      //   byBook[bookId] = bookStats;
      //   todayDataDyn['by_book'] = byBook;
      // }

      // 更新全局统计 (目前总是更新全局)
      final int currentGlobalCount =
          (todayDataDyn[statKey] as num?)?.toInt() ?? 0;
      todayDataDyn[statKey] = currentGlobalCount + increment;

      // 将更新后的 Map 写回 Box
      await dailyStatsBox.put(todayKey, todayDataDyn);
    } catch (e) {
      if (kDebugMode) {
        print(
            "[HiveService] Error updating daily stat '$statKey' for $userId: $e");
      }
    }
  }

  /// 记录一次学习事件 (新学单词 +1)
  Future<void> logLearnEvent(String userId, String bookId) async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // 当前只更新全局统计
    await _updateDailyStat(userId, todayKey, DAILY_STATS_KEY_LEARNED_COUNT,
        1 /*, bookId: bookId*/);
  }

  /// 记录一次复习事件 (复习单词 +1)
  Future<void> logReviewEvent(String userId, String bookId) async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // 当前只更新全局统计
    await _updateDailyStat(userId, todayKey, DAILY_STATS_KEY_REVIEWED_COUNT,
        1 /*, bookId: bookId*/);
  }

  /// 记录一次学习/复习会话的时长
  Future<void> logSessionDuration(
      String userId, String bookId, Duration duration) async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final int durationMs = duration.inMilliseconds;

    // 忽略过短的时长记录 (例如小于5秒)
    if (durationMs <= 5000) return;

    try {
      // 1. 更新当日总时长
      final dailyStatsBox = _getDailyStatsBox(userId);
      final Map<dynamic, dynamic> todayDataDyn =
          Map.from(dailyStatsBox.get(todayKey) ?? {});

      // TODO: 更新特定 bookId 的时长
      // if (bookId != null) { ... }

      // 更新全局当日时长
      final int currentDurationMs =
          (todayDataDyn[DAILY_STATS_KEY_DURATION_MS] as num?)?.toInt() ?? 0;
      todayDataDyn[DAILY_STATS_KEY_DURATION_MS] =
          currentDurationMs + durationMs;
      await dailyStatsBox.put(todayKey, todayDataDyn);

      // 2. 更新全局累计总时长
      final configBox = _getConfigBox(userId);
      final int totalMs =
          configBox.get(CONFIG_KEY_TOTAL_DURATION_MS, defaultValue: 0);
      await configBox.put(CONFIG_KEY_TOTAL_DURATION_MS, totalMs + durationMs);

      if (kDebugMode) {
        print(
            "[HiveService] Logged session duration ${duration.inSeconds}s for user $userId, book $bookId");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error logging session duration for $userId: $e");
      }
    }
  }

  // --- 图表数据查询 (目前返回全局数据) ---

  /// 获取单词学习/复习数量图表数据
  Future<List<StatsChartDataPoint>> getWordChartData(
      String bookId, String userId, StatsTimeRange range) async {
    if (kDebugMode) {
      print("[HiveService] Getting Word Chart Data for range: $range");
    }
    List<StatsChartDataPoint> chartData = [];
    try {
      final dailyStatsBox = _getDailyStatsBox(userId);
      final today = DateTime.now().dateOnly;
      // 根据范围确定要获取的天数
      final daysToFetch = range == StatsTimeRange.week ? 7 : 30;

      for (int i = 0; i < daysToFetch; i++) {
        // 从今天开始往前推算日期
        final date = today.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        // 获取当天的统计数据 Map
        final Map? dayData = dailyStatsBox.get(dateKey);

        // TODO: 按 bookId 过滤 (需要读取 daily_stats['by_book'][bookId])
        // 当前读取全局数据
        final int learned =
            (dayData?[DAILY_STATS_KEY_LEARNED_COUNT] as num?)?.toInt() ?? 0;
        final int reviewed =
            (dayData?[DAILY_STATS_KEY_REVIEWED_COUNT] as num?)?.toInt() ?? 0;

        // 将数据点添加到列表开头，使日期从左到右递增
        chartData.insert(0,
            StatsChartDataPoint(date, learned.toDouble(), reviewed.toDouble()));
      }
      if (kDebugMode) {
        print(
            "[HiveService] Word Chart Data points fetched: ${chartData.length}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error getting word chart data: $e");
      }
      chartData = []; // 出错时返回空列表
    }
    return chartData;
  }

  /// 获取学习时长图表数据 (分钟)
  Future<List<StatsChartDataPoint>> getDurationChartData(
      String bookId, String userId, StatsTimeRange range) async {
    if (kDebugMode) {
      print("[HiveService] Getting Duration Chart Data for range: $range");
    }
    List<StatsChartDataPoint> chartData = [];
    try {
      final dailyStatsBox = _getDailyStatsBox(userId);
      final today = DateTime.now().dateOnly;
      final daysToFetch = range == StatsTimeRange.week ? 7 : 30;

      for (int i = 0; i < daysToFetch; i++) {
        final date = today.subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final Map? dayData = dailyStatsBox.get(dateKey);

        // TODO: 按 bookId 过滤
        // 读取全局时长 (毫秒)
        final int durationMs =
            (dayData?[DAILY_STATS_KEY_DURATION_MS] as num?)?.toInt() ?? 0;
        // 转换为分钟
        final double durationMinutes = durationMs / 60000.0;

        // 添加到列表开头
        chartData.insert(0, StatsChartDataPoint(date, durationMinutes));
      }
      if (kDebugMode) {
        print(
            "[HiveService] Duration Chart Data points fetched: ${chartData.length}");
      }
      // 月视图的数据聚合可以在 UI 层处理，或者如果需要在这里聚合：
      // if (range == StatsTimeRange.month && chartData.length > 7) {
      //    chartData = _aggregateDailyDataToWeekly(chartData);
      // }
    } catch (e) {
      if (kDebugMode) {
        print("[HiveService] Error getting duration chart data: $e");
      }
      chartData = [];
    }
    // 返回每日数据点列表
    return chartData;
  }

  // // 可选：按周聚合数据的辅助方法
  // List<StatsChartDataPoint> _aggregateDailyDataToWeekly(List<StatsChartDataPoint> dailyData) {
  //   if (dailyData.isEmpty) return [];
  //   Map<DateTime, List<double>> weeklyMap = {};
  //   // 确保按日期排序
  //   dailyData.sort((a, b) => a.date.compareTo(b.date));
  //
  //   for (var point in dailyData) {
  //     // 计算该日期所属周的周一
  //     DateTime weekStartDate = point.date.subtract(Duration(days: point.date.weekday - 1));
  //     // 将数据添加到对应周的列表中
  //     weeklyMap.putIfAbsent(weekStartDate, () => []).add(point.value1);
  //     // 如果有 value2 也要聚合
  //   }
  //
  //   // 计算每周的总和或平均值等
  //   List<StatsChartDataPoint> weeklyDataAggregated = [];
  //   weeklyMap.forEach((weekStart, values) {
  //     double weeklyValue = values.fold(0.0, (sum, v) => sum + v); // 计算总和
  //     // 或者计算平均值: double weeklyValue = values.fold(0.0, (sum, v) => sum + v) / values.length;
  //     weeklyDataAggregated.add(StatsChartDataPoint(weekStart, weeklyValue));
  //   });
  //
  //   // 确保结果按周排序
  //   weeklyDataAggregated.sort((a, b) => a.date.compareTo(b.date));
  //    if (kDebugMode) {
  //       print("[HiveService] Aggregated ${dailyData.length} daily points into ${weeklyDataAggregated.length} weekly points.");
  //    }
  //   return weeklyDataAggregated;
  // }
} // End of HiveService class

/// DateTime 扩展方法，用于获取日期部分 (忽略时间)
extension DateTimeDateOnly on DateTime {
  DateTime get dateOnly => DateTime.utc(year, month, day);
}
