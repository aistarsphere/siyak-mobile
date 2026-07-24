import 'package:context_game/features/game/data/models/game_snapshot.dart';
import 'package:context_game/features/game/data/models/guess_response.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/languages_info.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanguagesInfo', () {
    test('parses /languages', () {
      final l = LanguagesInfo.fromJson(const {
        'languages': [
          {
            'code': 'ar',
            'name': 'Arabic',
            'native_name': 'العربية',
            'dir': 'rtl',
            'ready': true,
          },
          {
            'code': 'en',
            'name': 'English',
            'native_name': 'English',
            'dir': 'ltr',
            'ready': true,
          },
        ],
      });
      expect(l.languages, hasLength(2));
      expect(l.languages.first.code, 'ar');
      expect(l.languages.first.nativeName, 'العربية');
      expect(l.languages.first.dir, 'rtl');
    });
  });

  group('ModesInfo', () {
    test('parses /modes and keeps localized labels + playable filter', () {
      final m = ModesInfo.fromJson(const {
        'language': 'ar',
        'modes': [
          {
            'code': 'general',
            'label': 'General',
            'label_ar': 'عام',
            'word_count': 22433,
            'playable': true,
          },
          {
            'code': 'animals',
            'label': 'Animals',
            'label_ar': 'الحيوانات',
            'word_count': 159,
            'playable': true,
          },
          {
            'code': 'locked',
            'label': 'Locked',
            'label_ar': 'مقفل',
            'word_count': 0,
            'playable': false,
          },
        ],
      });
      expect(m.language, 'ar');
      expect(m.categories, hasLength(3));
      expect(m.playable, hasLength(2));
      final general = m.categories.first;
      expect(general.labelFor('ar'), 'عام');
      expect(general.labelFor('en'), 'General');
      expect(general.wordCount, 22433);
    });
  });

  group('GameSnapshot', () {
    test('parses /new-game and hides the secret word', () {
      final s = GameSnapshot.fromJson(const {
        'game_id': 'abc123',
        'language': 'ar',
        'dir': 'rtl',
        'category': 'general',
        'mode': 'random',
        'total_words': 22548,
        'guess_count': 0,
        'solved': false,
        'best_rank': null,
        'secret_word': null,
        'previous_guesses': [],
        'hints_used': 0,
        'hints_remaining': 5,
        'max_hints': 5,
        'hints': [],
      });
      expect(s.gameId, 'abc123');
      expect(s.dir, 'rtl');
      expect(s.totalWords, 22548);
      expect(s.solved, isFalse);
      expect(s.secretWord, isNull);
      expect(s.hintsRemaining, 5);
      expect(s.guesses, isEmpty);
    });

    test('parses previous_guesses into scored Guess entities', () {
      final s = GameSnapshot.fromJson(const {
        'game_id': 'g',
        'language': 'ar',
        'total_words': 22548,
        'guess_count': 1,
        'solved': false,
        'best_rank': 18607,
        'previous_guesses': [
          {
            'attempt': 1,
            'guess': 'بيت',
            'word': 'بيت',
            'rank': 18607,
            'proximity': 17.5,
            'heat_level': 'freezing',
            'solved': false,
          },
        ],
        'hints': [],
      });
      expect(s.guesses.single.word, 'بيت');
      expect(s.guesses.single.rank, 18607);
      expect(s.guesses.single.proximity, 17.5);
    });
  });

  group('GuessResponse', () {
    test('parses an accepted scored guess', () {
      final g = GuessResponse.fromJson(const {
        'accepted': true,
        'duplicate': false,
        'already_guessed': false,
        'solved': false,
        'total_words': 22548,
        'guess_number': 1,
        'original_guess': 'بيت',
        'canonical_word': 'بيت',
        'rank': 18607,
        'proximity': 17.5,
        'heat_level': 'freezing',
        'previous_guesses': [],
        'hints': [],
      });
      expect(g.accepted, isTrue);
      expect(g.unknownWord, isFalse);
      expect(g.guess!.word, 'بيت');
      expect(g.guess!.rank, 18607);
      expect(g.guess!.proximity, 17.5);
    });

    test('flags a duplicate canonical guess', () {
      final g = GuessResponse.fromJson(const {
        'accepted': true,
        'duplicate': true,
        'already_guessed': true,
        'reason': 'duplicate_canonical_guess',
        'solved': false,
        'total_words': 22548,
        'guess_number': 1,
        'canonical_word': 'بيت',
        'rank': 18607,
        'proximity': 17.5,
        'heat_level': 'freezing',
        'previous_guesses': [],
        'hints': [],
      });
      expect(g.duplicate, isTrue);
      expect(g.alreadyGuessed, isTrue);
    });

    test('parses an unknown word with suggestions', () {
      final g = GuessResponse.fromJson(const {
        'accepted': false,
        'duplicate': false,
        'already_guessed': false,
        'reason': 'not_in_vocabulary',
        'message': 'not in dictionary',
        'original_guess': 'زقزقتيبل',
        'solved': false,
        'total_words': 22548,
        'guess_number': 0,
        'suggestions': [
          {'word': 'قتيل'},
          {'word': 'قتيلا'},
        ],
        'previous_guesses': [],
        'hints': [],
      });
      expect(g.unknownWord, isTrue);
      expect(g.guess, isNull);
      expect(g.suggestions, ['قتيل', 'قتيلا']);
    });

    test('parses a solved guess with secret word', () {
      final g = GuessResponse.fromJson(const {
        'accepted': true,
        'duplicate': false,
        'already_guessed': false,
        'solved': true,
        'total_words': 22548,
        'guess_number': 5,
        'canonical_word': 'برمجة',
        'rank': 1,
        'proximity': 100,
        'heat_level': 'boiling',
        'secret_word': 'برمجة',
        'previous_guesses': [],
        'hints': [],
      });
      expect(g.solved, isTrue);
      expect(g.secretWord, 'برمجة');
      expect(g.guess!.isSecret, isTrue);
    });
  });

  group('HintResult', () {
    test('parses structured hint fields — no text parsing', () {
      final h = HintResult.fromJson(const {
        'ok': true,
        'hint_number': 1,
        'difficulty': 'medium',
        'revealed_word': 'بطيئة',
        'semantic_rank': 31,
        'similarity_score': 0.6447,
        'hints_used': 1,
        'hints_remaining': 4,
        'max_hints': 5,
      });
      expect(h.number, 1);
      expect(h.word, 'بطيئة');
      expect(h.rank, 31);
      expect(h.hintsRemaining, 4);
    });
  });

  group('WordSuggestions', () {
    test('parses /suggest', () {
      final s = WordSuggestions.fromJson(const {
        'language': 'ar',
        'query': 'سيا',
        'suggestions': [
          {'word': 'سيارة'},
          {'word': 'سياج'},
        ],
      });
      expect(s.words, ['سيارة', 'سياج']);
    });

    test('tolerates missing suggestions', () {
      expect(WordSuggestions.fromJson(const {}).words, isEmpty);
    });
  });
}
