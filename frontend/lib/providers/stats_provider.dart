// frontend/lib/providers/stats_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexilearn/providers/auth_provider.dart'; // *** 导入 AuthProvider ***
import 'package:lexilearn/providers/vocab_provider.dart';
import 'package:lexilearn/services/hive_service.dart';

// 时间范围枚举
enum StatsTimeRange { week, month }

// 概览统计数据类 (保持不变)
class OverviewStats {
  final int learnedCount;
  final int totalCount;
  final int learnedToday;
  final int reviewedToday;
  final Duration timeToday;
  final Duration timeTotal;
  const OverviewStats({
    this.learnedCount = 0,
    this.totalCount = 1,
    this.learnedToday = 0,
    this.reviewedToday = 0,
    this.timeToday = Duration.zero,
    this.timeTotal = Duration.zero,
  });
  static const empty = OverviewStats();
}

// 图表数据点类 (保持不变)
class StatsChartDataPoint {
  final DateTime date;
  final double value1;
  final double value2;
  const StatsChartDataPoint(this.date, this.value1, [this.value2 = 0]);
}

class StatsProvider with ChangeNotifier {
  final HiveService _hiveService = HiveService();
  // *** 修改：现在持有 AuthProvider 和 VocabProvider 的引用 ***
  final AuthProvider _authProvider;
  final VocabProvider _vocabProvider;

  // 内部状态，用于跟踪依赖项的变化
  String? _currentUserIdInternal;
  String? _currentBookIdInternal;
  // *** 新增：跟踪 AuthProvider 的 UserDataStatus ***
  UserDataStatus _currentUserDataStatusInternal = UserDataStatus.initializing;

  // *** 新增：首次加载标志位 ***
  bool _isDataLoadedOnce = false;

  // 暴露给 UI 的状态 (保持不变)
  List<dynamic> _availableBooks = [];
  StatsTimeRange _wordChartTimeRange = StatsTimeRange.week;
  StatsTimeRange _durationChartTimeRange = StatsTimeRange.week;
  bool _isLoading = true;
  String? _error;
  OverviewStats _overviewData = OverviewStats.empty;
  List<StatsChartDataPoint> _wordChartData = [];
  List<StatsChartDataPoint> _durationChartData = [];

  // *** 修改：构造函数接收两个 Provider ***
  StatsProvider(this._authProvider, this._vocabProvider) {
    // *** 日志：构造函数执行 ***
    if (kDebugMode) {
      print("[StatsProvider] Constructor executed.");
    }
    _availableBooks = List.from(_vocabProvider.availableVocabs);
    _currentUserIdInternal = _vocabProvider.currentUserId;
    _currentBookIdInternal = _vocabProvider.selectedBookId;
    _currentUserDataStatusInternal = _authProvider.userDataStatus;
    if (kDebugMode) {
      print(
          "[StatsProvider] Initial state from constructor: User='$_currentUserIdInternal', Book='$_currentBookIdInternal', DataStatus='$_currentUserDataStatusInternal'");
    }
  }

  // *** 移除 _handleVocabChange 监听器 ***

  // 清理监听器 (现在不需要了)
  // @override
  // void dispose() {
  //   if (kDebugMode) {
  //     print("[StatsProvider] Disposing...");
  //   }
  //   _vocabProvider.removeListener(_handleVocabChange);
  //   super.dispose();
  // }

  // --- Getters (新增一个给 ProxyProvider 判断) ---
  String? get selectedBookId => _currentBookIdInternal; // 使用内部状态
  List<dynamic> get availableBooks => _availableBooks;
  StatsTimeRange get wordChartTimeRange => _wordChartTimeRange;
  StatsTimeRange get durationChartTimeRange => _durationChartTimeRange;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OverviewStats get overviewData => _overviewData;
  List<StatsChartDataPoint> get wordChartData => _wordChartData;
  List<StatsChartDataPoint> get durationChartData => _durationChartData;
  // Getters for internal state (用于 ProxyProvider 比较)
  String? get currentUserIdInternal => _currentUserIdInternal;
  String? get currentBookIdInternal => _currentBookIdInternal;
  UserDataStatus get currentUserDataStatusInternal =>
      _currentUserDataStatusInternal;
  // *** Getter for the loaded flag (for ProxyProvider check) ***
  bool get isDataLoadedOnce => _isDataLoadedOnce;

  // --- Setters for UI Actions (保持不变) ---
  void setWordChartTimeRange(StatsTimeRange range) {
    if (range != _wordChartTimeRange) {
      _wordChartTimeRange = range;
      notifyListeners();
      loadStatsData(); // 切换范围时重新加载数据
    }
  }

  void setDurationChartTimeRange(StatsTimeRange range) {
    if (range != _durationChartTimeRange) {
      _durationChartTimeRange = range;
      notifyListeners();
      loadStatsData(); // 切换范围时重新加载数据
    }
  }

  // --- 辅助方法：用于 ProxyProvider 更新内部状态 ---
  void updateDependencies(
      String? userId, String? bookId, UserDataStatus dataStatus) {
    _currentUserIdInternal = userId;
    _currentBookIdInternal = bookId;
    _currentUserDataStatusInternal = dataStatus;
    // 这里不需要 notifyListeners，因为 ProxyProvider 会处理重建
  }

    // *** 新增：重置加载标志的方法 ***
  void resetLoadedFlag() {
    if (_isDataLoadedOnce) {
      if (kDebugMode)
        print("[StatsProvider] Resetting _isDataLoadedOnce flag to false.");
      _isDataLoadedOnce = false;
      // 注意：这里通常不需要 notifyListeners()，因为调用它的地方（ProxyProvider 或 resetState）会处理通知
    }
  }



  // --- 数据加载逻辑 (*** 简化版 - 移除了 isLoading 检查 ***) ---
  // Future<void> loadStatsData() async {
  //   final userId = _currentUserIdInternal; // 仍然保留这些变量用于日志
  //   final bookId = _currentBookIdInternal;
  //   final userDataStatus = _currentUserDataStatusInternal;

  //   // *** 日志：函数开始 ***
  //   if (kDebugMode) {
  //     print(
  //         "[StatsProvider][loadStatsData][Simplified] Load Started. User: $userId, Book: $bookId, DataStatus: $userDataStatus, LoadedOnce: $_isDataLoadedOnce");
  //   }

  //   // --- 移除防止并发的检查 ---
  //   // if (_isLoading) {
  //   //    if (kDebugMode) print("[StatsProvider][loadStatsData] Already loading for User: $userId, Book: $bookId. Skipping.");
  //   //   return;
  //   // }

  //   // 设置加载状态（即使很短暂）并通知UI
  //   _isLoading = true;
  //   _error = null;
  //   // notifyListeners(); // 可以在这里通知一次“开始加载”，也可以省略，等最后一起通知

  //   // --- 立刻模拟完成 ---
  //   // 确保函数是异步的，即使内部没有 await，以便与 Future<void> 签名匹配
  //   await Future.delayed(Duration.zero); // 使用 Duration.zero

  //   // 直接设置状态为非加载，并提供一些不同的虚拟数据以确认更新
  //   _isLoading = false;
  //   _overviewData = const OverviewStats(
  //       learnedCount: 999, // 使用不同的虚拟数据
  //       totalCount: 2000,
  //       learnedToday: 9,
  //       reviewedToday: 19,
  //       timeToday: Duration(minutes: 55),
  //       timeTotal: Duration(hours: 12));
  //   _wordChartData = [
  //     StatsChartDataPoint(
  //         DateTime.now().subtract(const Duration(days: 1)), 9, 19),
  //     StatsChartDataPoint(DateTime.now(), 11, 14),
  //   ];
  //   _durationChartData = [
  //     StatsChartDataPoint(DateTime.now().subtract(const Duration(days: 1)), 33),
  //     StatsChartDataPoint(DateTime.now(), 55),
  //   ];
  //   _isDataLoadedOnce = true; // 标记已加载过一次
  //   _error = null; // 清除错误

  //   // *** 日志：函数结束 ***
  //   if (kDebugMode) {
  //     print(
  //         "[StatsProvider][loadStatsData][Simplified] Load Finished. Setting isLoading=false, isDataLoadedOnce=true, providing dummy data and notifying.");
  //   }
  //   notifyListeners(); // 通知 UI 最终状态
  // }







  // --- Data Loading Logic原始版 ---
  // --- 数据加载逻辑 (*** 修改 finally 块 ***) ---
  // --- 数据加载逻辑 (*** 恢复 isLoading 检查, 恢复真实调用, 修正日志 ***) ---
  Future<void> loadStatsData() async {
    final userId = _currentUserIdInternal;
    final bookId = _currentBookIdInternal;
    final userDataStatus = _currentUserDataStatusInternal;

    if (kDebugMode)
      print(
          "[StatsProvider][loadStatsData] Attempting load. User: $userId, Book: $bookId, DataStatus: $userDataStatus, Current isLoading: $_isLoading, LoadedOnce: $isDataLoadedOnce");

    // --- *** 恢复并发检查 *** ---
    // if (_isLoading) {
    //   if (kDebugMode)
    //     print(
    //         "[StatsProvider][loadStatsData] Already loading for User: $userId, Book: $bookId. Skipping.");
    //   return; // 如果正在加载，则直接返回，防止并发
    // }
    // --- 结束恢复 ---

    // 依赖项检查 (保持)
    if (userDataStatus != UserDataStatus.ready ||
        userId == null ||
        bookId == null) {
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] Dependencies not ready. Aborting.");
      _isLoading = false;
      _error = "依赖项未就绪";
      if (!_isLoading || _error != "依赖项未就绪") notifyListeners();
      return;
    }

    _isLoading = true; // 标记开始加载
    _error = null;
    // _isDataLoadedOnce = false; // 不在这里重置
    notifyListeners(); // 通知 UI 加载开始
    if (kDebugMode)
      print(
          "[StatsProvider][loadStatsData] Starting REAL data fetch (isLoading set to true)...");

    try {
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] Awaiting REAL HiveService calls...");

      // *** 恢复所有真实的 HiveService 调用 ***
      final results = await Future.wait([
        _hiveService.getTotalWordCount(bookId, userId), // 0
        _hiveService.getLearnedWordCount(bookId, userId), // 1
        _hiveService.getTodayCounts(bookId, userId), // 2
        _hiveService.getTodayDuration(bookId, userId), // 3
        _hiveService.getTotalDuration(userId), // 4
        _hiveService.getWordChartData(bookId, userId, _wordChartTimeRange), // 5
        _hiveService.getDurationChartData(
            bookId, userId, _durationChartTimeRange) // 6
      ]);
      // *** 修正日志 ***
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] REAL HiveService calls completed.");

      // --- 处理真实结果 ---
      // *** 修正日志 ***
      if (kDebugMode)
        print("[StatsProvider][loadStatsData] Processing REAL results...");
      final totalCount = (results[0] as int?) ?? 0;
      final learnedCount = (results[1] as int?) ?? 0;
      final todayCounts = results[2] as ({int learned, int reviewed})?;
      final timeToday = (results[3] as Duration?) ?? Duration.zero;
      final timeTotal = (results[4] as Duration?) ?? Duration.zero;
      final wordData = (results[5] as List<StatsChartDataPoint>?) ?? [];
      final durationData = (results[6] as List<StatsChartDataPoint>?) ?? [];

      // *** 添加日志：打印获取到的 TodayCounts ***
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] Fetched TodayCounts: Learned=${todayCounts?.learned}, Reviewed=${todayCounts?.reviewed}");

      // 更新状态
      _overviewData = OverviewStats(
        learnedCount: learnedCount,
        totalCount: totalCount > 0 ? totalCount : 1,
        learnedToday: todayCounts?.learned ?? 0,
        reviewedToday: todayCounts?.reviewed ?? 0, // 使用获取到的值
        timeToday: timeToday,
        timeTotal: timeTotal,
      );
      _wordChartData = wordData;
      _durationChartData = durationData;
      _error = null;

      // *** 修正日志 ***
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] Data updated successfully with REAL data.");
    } catch (e, s) {
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] Error during REAL data load: $e\n$s");
      _error = "加载统计数据失败: $e";
      _overviewData = OverviewStats.empty;
      _wordChartData = [];
      _durationChartData = [];
      _isDataLoadedOnce = false;
    } finally {
      if (kDebugMode)
        print(
            "[StatsProvider][loadStatsData] REAL Load finished. Setting isLoading=false.");
      _isLoading = false;
      if (_error == null &&
          userId == _currentUserIdInternal &&
          bookId == _currentBookIdInternal) {
        if (!_isDataLoadedOnce) {
          // 只有在首次成功加载时打印设置 true 的日志
          if (kDebugMode)
            print(
                "[StatsProvider][loadStatsData] Setting _isDataLoadedOnce = true");
          _isDataLoadedOnce = true;
        }
      } else {
        // 如果加载出错或依赖变化，重置加载成功标志
        if (_isDataLoadedOnce) {
          if (kDebugMode)
            print(
                "[StatsProvider][loadStatsData] Load finished with error or outdated dependencies. Resetting _isDataLoadedOnce to false.");
          _isDataLoadedOnce = false;
        }
      }
      notifyListeners(); // 通知最终状态
    }
  }


  // 重置状态方法
  void resetState() {
    if (kDebugMode) print("[StatsProvider] Resetting state.");
    _availableBooks = [];
    _wordChartTimeRange = StatsTimeRange.week;
    _durationChartTimeRange = StatsTimeRange.week;
    _isLoading = true; // 重置后需要重新加载
    _error = null;
    _overviewData = OverviewStats.empty;
    _wordChartData = [];
    _durationChartData = [];
    _isDataLoadedOnce = false; // *** 重置状态时，加载标志也必须重置 ***
    // 内部跟踪状态会被 ProxyProvider 更新，这里不需要手动重置
    notifyListeners();
  }
}
