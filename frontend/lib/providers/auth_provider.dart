// frontend/lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // 需要 WidgetsBinding
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/services/api_service.dart';
import 'package:lexilearn/services/hive_service.dart';

// 认证状态枚举
enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

// *** 新增：用户数据状态枚举 ***
enum UserDataStatus { initializing, ready, error }

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  final HiveService _hiveService = HiveService();

  AuthStatus _status = AuthStatus.unknown;
  // *** 新增：用户数据状态变量 ***
  UserDataStatus _userDataStatus = UserDataStatus.initializing;
  String? _token;
  String? _userId;
  String? _email;
  String? _errorMessage;
  bool _isBusy = false;

  AuthStatus get status => _status;
  // *** 新增：用户数据状态 Getter ***
  UserDataStatus get userDataStatus => _userDataStatus;
  String? get token => _token;
  String? get userId => _userId;
  String? get email => _email;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    if (kDebugMode) {
      print("[Auth] AuthProvider Initialized.");
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      performInitialAuthCheck();
    });
  }

  Future<void> _setBusy(bool busy) async {
    if (_isBusy == busy) return;
    _isBusy = busy;
  }

  // 初始检查
  Future<void> performInitialAuthCheck() async {
    if (_status != AuthStatus.unknown || _isBusy) {
      if (kDebugMode) {
        print(
            "[Auth][InitialCheck] Skipping check, status=$_status, busy=$_isBusy");
      }
      return;
    }
    await _setBusy(true);
    if (kDebugMode) {
      print("[Auth][InitialCheck] Starting...");
    }
    _status = AuthStatus.loading;
    _userDataStatus = UserDataStatus.initializing; // 重置用户数据状态
    _errorMessage = null;
    notifyListeners(); // 通知状态改变

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      _token = await _storage.read(key: SECURE_STORAGE_TOKEN_KEY);
      _userId = await _storage.read(key: SECURE_STORAGE_USER_ID_KEY);
      _email = await _storage.read(key: SECURE_STORAGE_EMAIL_KEY);
      if (kDebugMode) {
        print("[Auth][InitialCheck] Read storage: userId=$_userId");
      }

      if (_token != null && _userId != null) {
        if (kDebugMode) {
          print(
              "[Auth][InitialCheck] Credentials found for $_userId. Opening Hive boxes...");
        }
        // *** 修改：调用 _openHiveBoxes 并检查其状态 ***
        bool boxesOpened = await _openHiveBoxes(
            _userId!); // openHiveBoxes 内部会设置 _userDataStatus
        if (boxesOpened && _userDataStatus == UserDataStatus.ready) {
          // 必须成功打开且状态为 ready
          _status = AuthStatus.authenticated; // 设置认证状态
          if (kDebugMode) {
            print(
                "[Auth][InitialCheck] Boxes opened and ready. Status: Authenticated.");
          }
        } else {
          // Box 打开失败或状态未就绪
          _status = AuthStatus.error;
          _errorMessage =
              _errorMessage ?? "无法初始化用户数据存储"; // 保留 _openHiveBoxes 可能设置的错误信息
          await _performLogoutCleanup(null);
          if (kDebugMode) {
            print(
                "[Auth][InitialCheck] Boxes opening failed or status not ready. Status: Error.");
          }
        }
      } else {
        if (kDebugMode) {
          print(
              "[Auth][InitialCheck] No token/userId. Status: Unauthenticated.");
        }
        _status = AuthStatus.unauthenticated;
        _userDataStatus = UserDataStatus.initializing; // 非登录状态，数据状态无意义，设为初始
        await _performLogoutCleanup(null);
      }
    } catch (e, s) {
      if (kDebugMode) {
        print("[Auth][InitialCheck] Error: $e\n$s");
      }
      _status = AuthStatus.error;
      _errorMessage = "检查登录状态时出错: $e";
      _userDataStatus = UserDataStatus.error; // 标记数据状态错误
      await _performLogoutCleanup(null);
    } finally {
      if (kDebugMode) {
        print(
            "[Auth][InitialCheck] Complete. Final status: $_status, UserDataStatus: $_userDataStatus. Notifying.");
      }
      notifyListeners(); // **通知最终的 status 和 userDataStatus**
      await _setBusy(false);
    }
  }

  // *** 修改：打开 Hive boxes 并更新用户数据状态 ***
  Future<bool> _openHiveBoxes(String userIdToOpen) async {
    _userDataStatus = UserDataStatus.initializing; // 开始打开，标记为初始化中
    // 不需要 notifyListeners()，因为调用者会在完成后通知
    try {
      // 确保 openUserBoxes 会打开所有需要的标准 boxes (config, plan, progress, daily_stats, wrongWords)
      await _hiveService.openUserBoxes(userIdToOpen);
      // *** 成功打开所有 boxes 后，设置状态为 ready ***
      _userDataStatus = UserDataStatus.ready;
      if (kDebugMode)
        print("[Auth][_openHiveBoxes] User boxes for $userIdToOpen are ready.");
      _errorMessage = null; // 清除之前的错误信息（如果有的话）
      return true;
      
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "[Auth][_openHiveBoxes] Error opening Hive boxes for $userIdToOpen: $e\n$s");
      }
      _errorMessage = "打开用户数据时出错: $e";
      // *** 打开失败，设置状态为 error ***
      _userDataStatus = UserDataStatus.error;
      return false;
    }
  }

  // 登录
  Future<bool> login(String email, String password) async {
    if (_isBusy) return false;
    await _setBusy(true);
    if (kDebugMode) print("[Auth][Login] Attempting login for: $email");
    _status = AuthStatus.loading;
    _userDataStatus = UserDataStatus.initializing; // 重置用户数据状态
    _errorMessage = null;
    notifyListeners(); // 通知状态改变

    bool success = false;
    String? loggedInUserId;

    try {
      final result = await _apiService.login(email, password);
      if (result['success']) {
        final String? newToken = result['token'];
        final String? newUserId = result['user']?['id']?.toString();
        final String? newEmail = result['user']?['email'];

        if (newToken != null && newUserId != null && newEmail != null) {
          loggedInUserId = newUserId;
          if (kDebugMode)
            print("[Auth][Login] API success. Storing credentials.");
          _token = newToken;
          _userId = newUserId; // 这个改变会触发 ProxyProvider
          _email = newEmail;
          await _storage.write(key: SECURE_STORAGE_TOKEN_KEY, value: _token);
          await _storage.write(key: SECURE_STORAGE_USER_ID_KEY, value: _userId);
          await _storage.write(key: SECURE_STORAGE_EMAIL_KEY, value: _email);
          if (kDebugMode) print("[Auth][Login] Credentials stored.");

          if (kDebugMode)
            print("[Auth][Login] Opening Hive boxes for user $_userId");
          // *** 修改：调用 _openHiveBoxes 并检查状态 ***
          bool boxesOpened = await _openHiveBoxes(_userId!);
          if (boxesOpened && _userDataStatus == UserDataStatus.ready) {
            _status = AuthStatus.authenticated; // 设置认证状态
            success = true;
            if (kDebugMode)
              print(
                  "[Auth][Login] Login complete. Status: Authenticated, UserDataStatus: Ready.");
          } else {
            _status = AuthStatus.error; // Box 打开失败或状态不对
            _errorMessage = _errorMessage ?? "登录后初始化用户数据失败";
            if (kDebugMode)
              print(
                  "[Auth][Login] Login failed: Open boxes error or status not ready.");
            await _performLogoutCleanup(loggedInUserId);
            success = false;
          }
        } else {
          _errorMessage = "登录响应无效";
          _status = AuthStatus.unauthenticated;
          _userDataStatus = UserDataStatus.initializing; // 重置
          if (kDebugMode)
            print("[Auth][Login] Login failed: Invalid response.");
          success = false;
        }
      } else {
        _errorMessage = result['error'] ?? '用户名或密码错误';
        _status = AuthStatus.unauthenticated;
        _userDataStatus = UserDataStatus.initializing; // 重置
        if (kDebugMode)
          print("[Auth][Login] Login failed: API error - $_errorMessage");
        success = false;
      }
    } catch (e, s) {
      if (kDebugMode) print("[Auth][Login] Unexpected error: $e\n$s");
      _errorMessage = "登录过程中发生未知错误";
      _status = AuthStatus.error;
      _userDataStatus = UserDataStatus.error; // 标记数据错误
      await _performLogoutCleanup(loggedInUserId);
      success = false;
    } finally {
      if (kDebugMode)
        print(
            "[Auth][Login] Finally block. Final status: $_status, UserDataStatus: $_userDataStatus. Notifying.");
      notifyListeners(); // **通知最终的 status 和 userDataStatus**
      await _setBusy(false);
    }
    return success;
  }

  // 清理逻辑
  Future<void> _performLogoutCleanup(String? userIdToClean) async {
    if (kDebugMode)
      print(
          "[Auth][Cleanup] Starting cleanup for user: ${userIdToClean ?? 'N/A'}.");
    if (userIdToClean != null) {
      try {
        await _hiveService.closeUserBoxes(userIdToClean);
        if (kDebugMode)
          print("[Auth][Cleanup] Closed Hive boxes for user $userIdToClean.");
      } catch (e) {
        if (kDebugMode)
          print("[Auth][Cleanup] Ignored error closing boxes: $e");
      }
    }
    try {
      await _storage.deleteAll();
      if (kDebugMode) print("[Auth][Cleanup] Cleared secure storage.");
    } catch (e) {
      if (kDebugMode)
        print("[Auth][Cleanup] Error clearing secure storage: $e");
    }
    _token = null;
    _userId = null;
    _email = null;
    // *** 重置用户数据状态 ***
    _userDataStatus = UserDataStatus.initializing;
    if (kDebugMode)
      print(
          "[Auth][Cleanup] Cleared internal auth state. UserDataStatus reset to initializing.");
  }

  // 登出
  Future<void> logout() async {
    final userIdToLogout = _userId;
    if (kDebugMode)
      print("[Auth][Logout] Initiated for user ${userIdToLogout ?? 'N/A'}.");
    if (_isBusy) return;
    await _setBusy(true);
    _status = AuthStatus.loading;
    _userDataStatus = UserDataStatus.initializing; // 登出时重置
    notifyListeners(); // 通知登出开始

    await _performLogoutCleanup(userIdToLogout); // 执行清理

    _status = AuthStatus.unauthenticated; // 设置最终状态
    if (kDebugMode)
      print(
          "[Auth][Logout] Logout complete. Status: Unauthenticated, UserDataStatus: Initializing.");
    notifyListeners(); // **通知最终的 status 和 userDataStatus**
    await _setBusy(false);
  }
}
