// ignore_for_file: non_constant_identifier_names , avoid_dynamic_calls

// Helper to safely get values from JSON, providing default values
T _safeGet<T>(Map<String, dynamic> json, String key, T defaultValue) {
  try {
    final value = json[key];
    if (value is T) {
      return value;
    }
    // Add specific type conversions if needed (e.g., int from double)
    if (T == int && value is double) {
      return value.toInt() as T;
    }
    if (T == double && value is int) {
      return value.toDouble() as T;
    }
    if (T == String && value != null) {
      return value.toString() as T;
    }
    return defaultValue;
  } catch (e) {
    // print("Error getting key '$key': $e"); // Optional logging
    return defaultValue;
  }
}

List<T> _safeGetList<T>(Map<String, dynamic> json, String key,
    T Function(Map<String, dynamic>) fromJson) {
  try {
    final list = json[key];
    if (list is List) {
      return list
          .map((item) {
            if (item is Map<String, dynamic>) {
              return fromJson(item);
            }
            // Handle cases where list items might not be maps if needed
            return null; // Or throw an error, or return a default T
          })
          .whereType<T>()
          .toList(); // Filter out nulls if any step failed
    }
    return [];
  } catch (e) {
    // print("Error getting list for key '$key': $e"); // Optional logging
    return [];
  }
}

class WordEntry {
  final int wordRank;
  final String headWord;
  final WordContent content;
  final String bookId;

  WordEntry({
    required this.wordRank,
    required this.headWord,
    required this.content,
    required this.bookId,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    return WordEntry(
      wordRank: _safeGet(json, 'wordRank', 0),
      headWord: _safeGet(json, 'headWord', ''),
      content: WordContent.fromJson(_safeGet(json, 'content', {})),
      bookId: _safeGet(json, 'bookId', ''),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'wordRank': wordRank,
      'headWord': headWord,
      'content': content.toJson(),
      'bookId': bookId,
    };
  }
}

class WordContent {
  final Word word;

  WordContent({required this.word});

  factory WordContent.fromJson(Map<String, dynamic> json) {
    return WordContent(
      word: Word.fromJson(_safeGet(json, 'word', {})),
    );
  }
  Map<String, dynamic> toJson() {
    return {'word': word.toJson()};
  }
}

class Word {
  final String wordHead;
  final String wordId;
  final WordDetails content;

  Word({required this.wordHead, required this.wordId, required this.content});

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      wordHead: _safeGet(json, 'wordHead', ''),
      wordId: _safeGet(json, 'wordId', ''),
      content: WordDetails.fromJson(_safeGet(json, 'content', {})),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'wordHead': wordHead,
      'wordId': wordId,
      'content': content.toJson(),
    };
  }
}

class WordDetails {
  final List<Exam> exam;
  final SentenceData sentence;
  final String usphone;
  final String ukphone;
  final String usspeech; // Assuming URL params or path
  final String ukspeech; // Assuming URL params or path
  final Syno syno;
  final PhraseData phrase;
  final RelWordData relWord;
  final List<Tran> trans;

  WordDetails({
    required this.exam,
    required this.sentence,
    required this.usphone,
    required this.ukphone,
    required this.usspeech,
    required this.ukspeech,
    required this.syno,
    required this.phrase,
    required this.relWord,
    required this.trans,
  });

  factory WordDetails.fromJson(Map<String, dynamic> json) {
    return WordDetails(
      exam: _safeGetList(json, 'exam', Exam.fromJson),
      sentence: SentenceData.fromJson(_safeGet(json, 'sentence', {})),
      usphone: _safeGet(json, 'usphone', ''),
      ukphone: _safeGet(json, 'ukphone', ''),
      usspeech: _safeGet(json, 'usspeech', ''),
      ukspeech: _safeGet(json, 'ukspeech', ''),
      syno: Syno.fromJson(_safeGet(json, 'syno', {})),
      phrase: PhraseData.fromJson(_safeGet(json, 'phrase', {})),
      relWord: RelWordData.fromJson(_safeGet(json, 'relWord', {})),
      trans: _safeGetList(json, 'trans', Tran.fromJson),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'exam': exam.map((e) => e.toJson()).toList(),
      'sentence': sentence.toJson(),
      'usphone': usphone,
      'ukphone': ukphone,
      'usspeech': usspeech,
      'ukspeech': ukspeech,
      'syno': syno.toJson(),
      'phrase': phrase.toJson(),
      'relWord': relWord.toJson(),
      'trans': trans.map((t) => t.toJson()).toList(),
    };
  }
}

// --- Define Exam, Answer, Choice ---
class Exam {
  final String question;
  final Answer answer;
  final int examType;
  final List<Choice> choices;

  Exam(
      {required this.question,
      required this.answer,
      required this.examType,
      required this.choices});

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
        question: _safeGet(json, 'question', ''),
        answer: Answer.fromJson(_safeGet(json, 'answer', {})),
        examType: _safeGet(json, 'examType', 0),
        choices: _safeGetList(json, 'choices', Choice.fromJson));
  }
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer.toJson(),
      'examType': examType,
      'choices': choices.map((c) => c.toJson()).toList(),
    };
  }
}

class Answer {
  final String explain;
  final int rightIndex;
  Answer({required this.explain, required this.rightIndex});
  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
        explain: _safeGet(json, 'explain', ''),
        rightIndex: _safeGet(json, 'rightIndex', 0),
      );
  Map<String, dynamic> toJson() =>
      {'explain': explain, 'rightIndex': rightIndex};
}

class Choice {
  final int choiceIndex;
  final String choice;
  Choice({required this.choiceIndex, required this.choice});
  factory Choice.fromJson(Map<String, dynamic> json) => Choice(
        choiceIndex: _safeGet(json, 'choiceIndex', 0),
        choice: _safeGet(json, 'choice', ''),
      );
  Map<String, dynamic> toJson() =>
      {'choiceIndex': choiceIndex, 'choice': choice};
}

// --- Define SentenceData, Sentence ---
class SentenceData {
  final List<Sentence> sentences;
  final String desc;
  SentenceData({required this.sentences, required this.desc});
  factory SentenceData.fromJson(Map<String, dynamic> json) => SentenceData(
        sentences: _safeGetList(json, 'sentences', Sentence.fromJson),
        desc: _safeGet(json, 'desc', ''),
      );
  Map<String, dynamic> toJson() =>
      {'sentences': sentences.map((s) => s.toJson()).toList(), 'desc': desc};
}

class Sentence {
  final String sContent;
  final String sCn;
  Sentence({required this.sContent, required this.sCn});
  factory Sentence.fromJson(Map<String, dynamic> json) => Sentence(
        sContent: _safeGet(json, 'sContent', ''),
        sCn: _safeGet(json, 'sCn', ''),
      );
  Map<String, dynamic> toJson() => {'sContent': sContent, 'sCn': sCn};
}

// --- Define Syno, Synonym, Hwd ---
class Syno {
  final List<Synonym> synos;
  final String desc;
  Syno({required this.synos, required this.desc});
  factory Syno.fromJson(Map<String, dynamic> json) => Syno(
        synos: _safeGetList(json, 'synos', Synonym.fromJson),
        desc: _safeGet(json, 'desc', ''),
      );
  Map<String, dynamic> toJson() =>
      {'synos': synos.map((s) => s.toJson()).toList(), 'desc': desc};
}

class Synonym {
  final String pos;
  final String tran;
  final List<Hwd> hwds;
  Synonym({required this.pos, required this.tran, required this.hwds});
  factory Synonym.fromJson(Map<String, dynamic> json) => Synonym(
        pos: _safeGet(json, 'pos', ''),
        tran: _safeGet(json, 'tran', ''),
        hwds: _safeGetList(json, 'hwds', Hwd.fromJson),
      );
  Map<String, dynamic> toJson() =>
      {'pos': pos, 'tran': tran, 'hwds': hwds.map((h) => h.toJson()).toList()};
}

class Hwd {
  final String w;
  Hwd({required this.w});
  factory Hwd.fromJson(Map<String, dynamic> json) =>
      Hwd(w: _safeGet(json, 'w', ''));
  Map<String, dynamic> toJson() => {'w': w};
}

// --- Define PhraseData, Phrase ---
class PhraseData {
  final List<Phrase> phrases;
  final String desc;
  PhraseData({required this.phrases, required this.desc});
  factory PhraseData.fromJson(Map<String, dynamic> json) => PhraseData(
        phrases: _safeGetList(json, 'phrases', Phrase.fromJson),
        desc: _safeGet(json, 'desc', ''),
      );
  Map<String, dynamic> toJson() =>
      {'phrases': phrases.map((p) => p.toJson()).toList(), 'desc': desc};
}

class Phrase {
  final String pContent;
  final String pCn;
  Phrase({required this.pContent, required this.pCn});
  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        pContent: _safeGet(json, 'pContent', ''),
        pCn: _safeGet(json, 'pCn', ''),
      );
  Map<String, dynamic> toJson() => {'pContent': pContent, 'pCn': pCn};
}

// --- Define RelWordData, RelWord, WordInfo ---
class RelWordData {
  final List<RelWord> rels;
  final String desc;
  RelWordData({required this.rels, required this.desc});
  factory RelWordData.fromJson(Map<String, dynamic> json) => RelWordData(
        rels: _safeGetList(json, 'rels', RelWord.fromJson),
        desc: _safeGet(json, 'desc', ''),
      );
  Map<String, dynamic> toJson() =>
      {'rels': rels.map((r) => r.toJson()).toList(), 'desc': desc};
}

class RelWord {
  final String pos;
  final List<WordInfo> words;
  RelWord({required this.pos, required this.words});
  factory RelWord.fromJson(Map<String, dynamic> json) => RelWord(
        pos: _safeGet(json, 'pos', ''),
        words: _safeGetList(json, 'words', WordInfo.fromJson),
      );
  Map<String, dynamic> toJson() =>
      {'pos': pos, 'words': words.map((w) => w.toJson()).toList()};
}

class WordInfo {
  final String hwd;
  final String tran;
  WordInfo({required this.hwd, required this.tran});
  factory WordInfo.fromJson(Map<String, dynamic> json) => WordInfo(
        hwd: _safeGet(json, 'hwd', ''),
        tran: _safeGet(json, 'tran', ''),
      );
  Map<String, dynamic> toJson() => {'hwd': hwd, 'tran': tran};
}

// --- Define Tran ---
class Tran {
  final String tranCn;
  final String descOther;
  final String pos;
  final String descCn;
  final String tranOther;
  Tran(
      {required this.tranCn,
      required this.descOther,
      required this.pos,
      required this.descCn,
      required this.tranOther});
  factory Tran.fromJson(Map<String, dynamic> json) => Tran(
        tranCn: _safeGet(json, 'tranCn', ''),
        descOther: _safeGet(json, 'descOther', ''),
        pos: _safeGet(json, 'pos', ''),
        descCn: _safeGet(json, 'descCn', ''),
        tranOther: _safeGet(json, 'tranOther', ''),
      );
  Map<String, dynamic> toJson() => {
        'tranCn': tranCn,
        'descOther': descOther,
        'pos': pos,
        'descCn': descCn,
        'tranOther': tranOther,
      };
}
