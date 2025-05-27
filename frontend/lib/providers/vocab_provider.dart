import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/services/api_service.dart';
import 'package:lexilearn/services/hive_service.dart';
import 'package:lexilearn/services/vocab_service.dart';

enum VocabListStatus { initial, loading, loaded, error }
enum VocabLoadStatus { idle, loading, loaded } // Status for loading selected book ID
enum VocabDownloadStatus { idle, checking, downloading, success, error }

class VocabProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final VocabService _vocabService = VocabService();
  final HiveService _hiveService = HiveService();
  final _storage = const FlutterSecureStorage();

  VocabListStatus _listStatus = VocabListStatus.initial;
  List<dynamic> _availableVocabs = [];
  String? _listError;
  VocabListStatus get listStatus => _listStatus;
  List<dynamic> get availableVocabs => _availableVocabs;
  String? get listError => _listError;

  String? _selectedBookId;
  String? _currentUserId;
  String? _openedVocabBoxName;
  VocabLoadStatus _loadStatus = VocabLoadStatus.idle; // ** Track loading state **

  String? get selectedBookId => _selectedBookId;
  String? get currentUserId => _currentUserId;
  VocabLoadStatus get loadStatus => _loadStatus; // ** Expose loading state **

  Map<String, VocabDownloadStatus> _downloadStatusMap = {};
  Map<String, double> _downloadProgressMap = {};
  Map<String, String?> _downloadErrorMap = {};
  bool _isProcessingSelection = false;

  VocabDownloadStatus getDownloadStatus(String bookId) => _downloadStatusMap[bookId] ?? VocabDownloadStatus.idle;
  double getDownloadProgress(String bookId) => _downloadProgressMap[bookId] ?? 0.0;
  String? getDownloadError(String bookId) => _downloadErrorMap[bookId];
  bool get isProcessingSelection => _isProcessingSelection;

  VocabProvider() { }

  void updateUserId(String? userId) {
    if (_currentUserId != userId) {
       if (kDebugMode) print("[VocabProvider] updateUserId called. New userId: $userId");
       _currentUserId = userId;
       // If user logs out, clear selection state immediately
       if (userId == null) {
          _resetSelectionState(notify: true); // Notify after resetting
       }
    }
  }

  Future<void> loadSelectedBookId({String? userId}) async {
     if (userId == null || userId != _currentUserId) { return; }
     if (_loadStatus == VocabLoadStatus.loading) return;

     _loadStatus = VocabLoadStatus.loading;
     notifyListeners(); // Notify loading started

     String? storedBookId;
     try {
        storedBookId = await _storage.read(key: SECURE_STORAGE_SELECTED_BOOK_ID);
        if (storedBookId != _selectedBookId) {
           _selectedBookId = storedBookId;
           if (kDebugMode) { print("[VocabProvider] Loaded selected book ID: $_selectedBookId for user $_currentUserId"); }
           // Notify in finally block
        } else {
             if (kDebugMode) { print("[VocabProvider] Selected book ID unchanged: $_selectedBookId"); }
        }
     } catch (e) {
         if (kDebugMode) { print("[VocabProvider] Error reading selected book ID from storage: $e"); }
         _selectedBookId = null;
     } finally {
         _loadStatus = VocabLoadStatus.loaded;
         notifyListeners(); // Notify loading finished
     }
  }

  Future<void> fetchVocabList() async {
    if (_listStatus == VocabListStatus.loading) { return; }
    _listStatus = VocabListStatus.loading;
    _listError = null;
    notifyListeners();
    try {
      final result = await _apiService.getVocabList();
      if (result['success']) {
        _availableVocabs = result['data'] ?? []; _listStatus = VocabListStatus.loaded;
         if (kDebugMode) { print("[VocabProvider] Fetched ${_availableVocabs.length} vocabs."); }
      } else {
        _listError = result['error']; _listStatus = VocabListStatus.error;
         if (kDebugMode) { print("[VocabProvider] Error fetching vocab list: $_listError"); }
      }
    } catch (e) {
        _listError = "获取列表时发生网络错误: $e"; _listStatus = VocabListStatus.error;
        if (kDebugMode) { print("[VocabProvider] Network error fetching vocab list: $e"); }
    } finally { notifyListeners(); }
  }

   Future<bool> selectAndDownloadVocab(dynamic vocabItem, String userId) async {
      if (_currentUserId == null || _currentUserId != userId) { _currentUserId = userId; }
      final int? vocabId = vocabItem['id'];
      final String? bookId = vocabItem['bookId']?.toString() ?? vocabItem['name']?.toString();
      if (vocabId == null || bookId == null || bookId.isEmpty) { _setErrorState(bookId ?? 'unknown', "无效的词库信息"); return false; }
      if (_isProcessingSelection) { if (kDebugMode) print("[VocabProvider] Already processing."); return false; }

      _isProcessingSelection = true;
      _setDownloadState(bookId, VocabDownloadStatus.checking, 0.0, null);

      try {
          await _closeOpenedVocabBox();
          bool boxIsReady = await _hiveService.vocabBoxExistsAndIsNotEmpty(bookId, userId);
          bool needsDownload = !boxIsReady;
          if (kDebugMode) { print("[VocabProvider] Box '$bookId' ready: $boxIsReady. Needs download: $needsDownload"); }

          if (needsDownload) {
             _setDownloadState(bookId, VocabDownloadStatus.downloading, 0.0, null);
             if (kDebugMode) { print("[VocabProvider] Starting download: $bookId"); }
             final result = await _vocabService.fetchAndStoreVocab(vocabId, bookId, userId, (p) => _setDownloadState(bookId, VocabDownloadStatus.downloading, p, null));
             if (!result.success) { _setErrorState(bookId, result.error ?? "下载处理失败"); return false; }
          }
          await _storage.write(key: SECURE_STORAGE_SELECTED_BOOK_ID, value: bookId);
          _selectedBookId = bookId;
          _openedVocabBoxName = _hiveService.getSafeVocabBoxName(bookId, userId);
           _setDownloadState(bookId, VocabDownloadStatus.success, 1.0, null);
           if (kDebugMode) { print("[VocabProvider] Book '$bookId' selected."); }
          notifyListeners(); // Notify selectedBookId change
          return true;
      } catch (e, s) {
          if (kDebugMode) { print("[VocabProvider] Error selecting/downloading $bookId: $e\n$s"); }
          _setErrorState(bookId, "选择出错: $e"); return false;
      } finally { _isProcessingSelection = false; }
   }

   Future<void> _closeOpenedVocabBox() async {
       if (_openedVocabBoxName != null && Hive.isBoxOpen(_openedVocabBoxName!)) {
         try {
            await Hive.box(_openedVocabBoxName!).close();
             if (kDebugMode) { print("[VocabProvider] Closed previous vocab box: $_openedVocabBoxName"); }
         } catch (e) {
              if (kDebugMode) { print("[VocabProvider] Error closing previous vocab box $_openedVocabBoxName: $e"); }
         } finally { _openedVocabBoxName = null; }
      }
   }

   void _setDownloadState(String bookId, VocabDownloadStatus status, double progress, String? error) {
      _downloadStatusMap[bookId] = status; _downloadProgressMap[bookId] = progress; _downloadErrorMap[bookId] = error;
      notifyListeners();
   }
   void _setErrorState(String bookId, String error) {
       _downloadStatusMap[bookId] = VocabDownloadStatus.error; _downloadErrorMap[bookId] = error;
        notifyListeners();
   }

  // 由 ProxyProvider 或 logout 调用
  Future<void> clearSelection() async {
      if (_selectedBookId == null && _currentUserId == null && _openedVocabBoxName == null) { return; }
      if (kDebugMode) { print("[VocabProvider] Clearing selection."); }
      _resetSelectionState(notify: false); // Reset internal state first
      await _storage.delete(key: SECURE_STORAGE_SELECTED_BOOK_ID);
      await _closeOpenedVocabBox();
      notifyListeners(); // Notify after cleanup
   }

   void _resetSelectionState({bool notify = false}) {
      bool changed = _selectedBookId != null || _currentUserId != null || _downloadStatusMap.isNotEmpty;
      _selectedBookId = null;
      _currentUserId = null;
      _downloadStatusMap.clear();
      _downloadProgressMap.clear();
      _downloadErrorMap.clear();
      _isProcessingSelection = false;
      _loadStatus = VocabLoadStatus.idle;
      _openedVocabBoxName = null; // Also clear tracked opened box name
      if (changed && notify) { notifyListeners(); }
   }
}