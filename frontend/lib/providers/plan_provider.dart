import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/services/hive_service.dart';

class PlanProvider with ChangeNotifier {
  final HiveService _hiveService = HiveService();
  String? _currentUserId;
  bool _isLoading = true; // ** 添加加载状态 **

  int _dailyLearnGoal = 10;
  int _dailyReviewGoal = 20;

  int get dailyLearnGoal => _dailyLearnGoal;
  int get dailyReviewGoal => _dailyReviewGoal;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading; // ** 暴露加载状态 **

  void loadPlan(String userId) {
    if (_currentUserId == userId && !_isLoading) { return; }
    if (kDebugMode) { print("[PlanProvider] Loading plan for user $userId"); }
    _currentUserId = userId;
    _isLoading = true;
    // ** 考虑是否需要在开始加载时通知？ ProxyProvider update 本身会触发重建 **
    // notifyListeners();

    try {
      final box = _hiveService.getPlanBox(userId);
      _dailyLearnGoal = box.get(HIVE_KEY_DAILY_LEARN_GOAL, defaultValue: 10);
      _dailyReviewGoal = box.get(HIVE_KEY_DAILY_REVIEW_GOAL, defaultValue: 20);
      if (kDebugMode) { print("[PlanProvider] Plan loaded: Learn=$_dailyLearnGoal, Review=$_dailyReviewGoal"); }
    } catch (e) {
      if (kDebugMode) { print("[PlanProvider] Error loading plan from Hive for user $userId: $e"); }
      _dailyLearnGoal = 10; _dailyReviewGoal = 20;
    } finally {
      _isLoading = false;
      if (kDebugMode)
        print(
            "[PlanProvider] loadPlan finished for $_currentUserId. isLoading set to false. Notifying."); // Add Log
      notifyListeners(); // ** 加载完成后通知 **
    }
  }

  Future<void> savePlan({required String userId, int? newLearnGoal, int? newReviewGoal,}) async {
    bool changed = false;
    try {
       final box = _hiveService.getPlanBox(userId);
       if (newLearnGoal != null && newLearnGoal != _dailyLearnGoal) {
         _dailyLearnGoal = newLearnGoal;
         await box.put(HIVE_KEY_DAILY_LEARN_GOAL, _dailyLearnGoal);
         changed = true;
       }
       if (newReviewGoal != null && newReviewGoal != _dailyReviewGoal) {
         _dailyReviewGoal = newReviewGoal;
         await box.put(HIVE_KEY_DAILY_REVIEW_GOAL, _dailyReviewGoal);
         changed = true;
       }
       if (changed) {
         if (kDebugMode) { print("[PlanProvider] Plan saved for user $userId. Notifying."); }
         notifyListeners();
       }
    } catch (e) {
        if (kDebugMode) { print("[PlanProvider] Error saving plan for user $userId: $e"); }
    }
  }

  void resetPlan() {
    if (_currentUserId == null && !_isLoading) return;
    if (kDebugMode) { print("[PlanProvider] Resetting plan state."); }
    _currentUserId = null;
    _dailyLearnGoal = 10;
    _dailyReviewGoal = 20;
    _isLoading = false; // 重置时也标记为非加载状态
    notifyListeners();
  }
}