import 'package:context_game/features/game/data/models/game_meta.dart';
import 'package:context_game/features/game/data/models/guess_result.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/reveal_result.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModesInfo', () {
    test('parses the real /api/modes shape', () {
      final info = ModesInfo.fromJson({
        'lang': 'ar',
        'dir': 'rtl',
        'languages': [
          {'id': 'ar', 'label': 'العربية', 'dir': 'rtl'},
          {'id': 'en', 'label': 'English', 'dir': 'ltr'},
        ],
        'groups': [
          {
            'id': 'general',
            'label': 'عام',
            'categories': [
              {'id': 'general', 'label': 'متنوّع'},
              {'id': 'animals', 'label': 'حيوانات'},
            ],
          },
        ],
        'default': 'general',
        'difficulties': [
          {'id': 'easy', 'label': 'سهل'},
          {'id': 'medium', 'label': 'متوسط'},
        ],
        'defaultDifficulty': 'medium',
      });
      expect(info.lang, 'ar');
      expect(info.dir, 'rtl');
      expect(info.languages, hasLength(2));
      expect(info.groups.single.categories, hasLength(2));
      expect(info.defaultMode, 'general');
      expect(info.defaultDifficulty, 'medium');
      expect(info.allCategories.map((c) => c.id), ['general', 'animals']);
    });
  });

  group('GameMeta', () {
    test('parses /api/new response and round-trips toJson', () {
      final meta = GameMeta.fromJson({
        'mode': 'general',
        'label': 'متنوّع',
        'lang': 'ar',
        'difficulty': 'medium',
        'gameId': 17,
        'poolSize': 40,
        'totalWords': 8000,
      });
      expect(meta.gameId, 17);
      expect(meta.totalWords, 8000);
      expect(GameMeta.fromJson(meta.toJson()).gameId, 17);
    });
  });

  group('GuessResult', () {
    test('parses an in-vocab guess', () {
      final g = GuessResult.fromJson({
        'word': 'بيت',
        'rank': 42,
        'totalWords': 8000,
        'isSecret': false,
        'inVocab': true,
      });
      expect(g.word, 'بيت');
      expect(g.rank, 42);
      expect(g.isSecret, isFalse);
      expect(g.inVocab, isTrue);
      expect(g.answerWord, 'بيت');
    });

    test('parses an out-of-vocab guess (inVocab=false)', () {
      final g = GuessResult.fromJson({
        'word': 'مركبة',
        'rank': 84,
        'totalWords': 8000,
        'isSecret': false,
        'inVocab': false,
      });
      expect(g.inVocab, isFalse);
    });

    test('parses a solved guess with explanation', () {
      final g = GuessResult.fromJson({
        'word': 'برمجة',
        'rank': 1,
        'totalWords': 8000,
        'isSecret': true,
        'inVocab': true,
        'explanation': 'شرح',
      });
      expect(g.isSecret, isTrue);
      expect(g.rank, 1);
      expect(g.explanation, 'شرح');
    });

    test('root-match win reveals the real secret via answerWord', () {
      final g = GuessResult.fromJson({
        'word': 'مبرمج',
        'rank': 1,
        'totalWords': 8000,
        'isSecret': true,
        'inVocab': true,
        'rootMatch': true,
        'secret': 'برمجة',
      });
      expect(g.rootMatch, isTrue);
      expect(g.answerWord, 'برمجة');
    });
  });

  group('HintResult', () {
    test('parses Arabic hint text into word + rank', () {
      final h = HintResult.fromJson({
        'mode': 'general',
        'gameId': 3,
        'level': 1,
        'maxLevel': 5,
        'text': 'كلمة قريبة من الكلمة السرية (ترتيبها 152): «حرب»',
      });
      expect(h.word, 'حرب');
      expect(h.rank, 152);
      expect(h.level, 1);
      expect(h.maxLevel, 5);
    });

    test('parses English hint text into word + rank', () {
      final h = HintResult.fromJson({
        'level': 2,
        'maxLevel': 5,
        'text': 'A word close to the secret (rank 89): “peace”',
      });
      expect(h.word, 'peace');
      expect(h.rank, 89);
    });

    test('unparseable text keeps word/rank null but keeps raw text', () {
      final h = HintResult.fromJson({
        'level': 1,
        'maxLevel': 5,
        'text': 'تلميح غامض بلا صيغة',
      });
      expect(h.word, isNull);
      expect(h.rank, isNull);
      expect(h.text, isNotEmpty);
    });
  });

  group('WordSuggestions', () {
    test('parses /api/datastore/words items', () {
      final s = WordSuggestions.fromJson({
        'total': 2,
        'limit': 8,
        'offset': 0,
        'items': [
          {'word': 'سيارة', 'idx': 5, 'modes': ['general']},
          {'word': 'سيارات', 'idx': 9, 'modes': []},
        ],
      });
      expect(s.total, 2);
      expect(s.words, ['سيارة', 'سيارات']);
    });

    test('tolerates missing items', () {
      expect(WordSuggestions.fromJson(const {'total': 0}).words, isEmpty);
    });
  });

  group('RevealResult', () {
    test('parses /api/giveup', () {
      final r = RevealResult.fromJson(
          const {'secret': 'برمجة', 'explanation': null});
      expect(r.secret, 'برمجة');
      expect(r.explanation, isNull);
    });
  });
}
