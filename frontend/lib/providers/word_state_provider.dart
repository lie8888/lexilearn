import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lexilearn/models/word_entry.dart';
import 'package:lexilearn/services/hive_service.dart';

enum WordDisplayStage {
  judgement,
  definition,
  sentence,
  phrase,
  synonym,
  related
}

enum SessionType { learn, review }

enum SessionStatus { initial, loading, active, completed, error }

class WordStateProvider with ChangeNotifier {
  final HiveService _hiveService = HiveService();
  String? _userId;
  String? _bookId;
  SessionType _sessionType = SessionType.learn;
  SessionStatus _status = SessionStatus.initial;
  List<WordEntry> _sessionWords = [];
  int _currentIndex = 0;
  String? _errorMessage;
  WordDisplayStage _selectedDetailTab = WordDisplayStage.definition;
  bool _showDetails = false;

  SessionStatus get status => _status;
  WordEntry? get currentWord =>
      _sessionWords.isNotEmpty && _currentIndex < _sessionWords.length
          ? _sessionWords[_currentIndex]
          : null;
  int get currentIndex => _currentIndex;
  int get totalWordsInSession => _sessionWords.length;
  bool get isSessionComplete => _status == SessionStatus.completed;
  String? get errorMessage => _errorMessage;
  bool get hasWords => _sessionWords.isNotEmpty;
  WordDisplayStage get selectedDetailTab => _selectedDetailTab;
  bool get showDetails => _showDetails;

  Future<void> loadWordsForSession({
    required String userId,
    required String bookId,
    required SessionType type,
    required int goal,
  }) async {
    if (_status == SessionStatus.loading) return;
    _userId = userId;
    _bookId = bookId;
    _sessionType = type;
    _status = SessionStatus.loading;
    _errorMessage = null;
    _sessionWords.clear();
    _currentIndex = 0;
    _selectedDetailTab = WordDisplayStage.definition;
    _showDetails = false;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (type == SessionType.learn) {
        _sessionWords =
            await _hiveService.getWordsForLearning(bookId, userId, goal);
      } else {
        _sessionWords =
            await _hiveService.getWordsForReview(bookId, userId, goal);
      }
      _status = _sessionWords.isEmpty
          ? SessionStatus.completed
          : SessionStatus.active;
      if (kDebugMode) {
        print("Loaded ${_sessionWords.length} words for $type session.");
      }
    } catch (e) {
      _errorMessage = "加载单词时出错: $e";
      _status = SessionStatus.error;
      if (kDebugMode) {
        print("Error loading words: $e");
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> markWord(bool known) async {
    if (currentWord == null || _userId == null || _showDetails) return;
    if (kDebugMode) {
      print(
          "Marking word '${currentWord!.headWord}' as ${known ? 'Known' : 'Unknown'}");
    }
    await _hiveService.updateWordProgress(
        _userId!, currentWord!.content.word.wordId, known);
    _selectedDetailTab = WordDisplayStage.definition;
    _showDetails = true;
    notifyListeners();
  }

  void selectDetailTab(WordDisplayStage tab) {
    if (tab != WordDisplayStage.judgement && tab != _selectedDetailTab) {
      _selectedDetailTab = tab;
      if (kDebugMode) {
        print("Selected detail tab: $tab");
      }
      notifyListeners();
    }
  }

  void nextWord() {
    if (_status != SessionStatus.active) return;
    if (_currentIndex < _sessionWords.length - 1) {
      _currentIndex++;
      _showDetails = false;
      _selectedDetailTab = WordDisplayStage.definition;
      if (kDebugMode) {
        print("Moving to next word, index: $_currentIndex");
      }
      notifyListeners();
    } else {
      _status = SessionStatus.completed;
      if (kDebugMode) {
        print("Session completed!");
      }
      notifyListeners();
    }
  }

  void resetSession() {
    _status = SessionStatus.initial;
    _sessionWords.clear();
    _currentIndex = 0;
    _errorMessage = null;
    _selectedDetailTab = WordDisplayStage.definition;
    _showDetails = false;
  }
}
