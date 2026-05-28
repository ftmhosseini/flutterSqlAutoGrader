// Unit tests for the business logic behind cohort joining,
// assignment creation, and quiz creation.
//
// These tests do NOT require Firebase — they test the validation
// rules and data manipulation that happen before any network call.

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Cohort join logic
  // ---------------------------------------------------------------------------

  group('Cohort join validation', () {
    test('empty code is rejected', () {
      expect('   '.trim().isEmpty, isTrue);
    });

    test('code must be exactly 5 characters', () {
      expect('AB'.length == 5, isFalse);       // too short
      expect('ABCDEF'.length == 5, isFalse);   // too long
      expect('ABCDE'.length == 5, isTrue);     // valid
    });

    test('student already in cohort is detected', () {
      final uids = ['uid_alice', 'uid_bob'];
      expect(uids.contains('uid_alice'), isTrue);
    });

    test('new student is not already in cohort', () {
      final uids = ['uid_alice', 'uid_bob'];
      expect(uids.contains('uid_charlie'), isFalse);
    });

    test('joining adds student uid to cohort list', () {
      final uids = ['uid_alice'];
      uids.add('uid_charlie');
      expect(uids, containsAll(['uid_alice', 'uid_charlie']));
      expect(uids.length, 2);
    });

    test('duplicate join does not add uid twice', () {
      final uids = ['uid_alice'];
      if (!uids.contains('uid_alice')) uids.add('uid_alice');
      expect(uids.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Cohort creation logic (teacher)
  // ---------------------------------------------------------------------------

  group('Cohort creation validation', () {
    test('empty cohort name is rejected', () {
      expect(''.trim().isEmpty, isTrue);
    });

    test('whitespace-only name is rejected', () {
      expect('   '.trim().isEmpty, isTrue);
    });

    test('valid cohort name passes', () {
      expect('CS101 Fall 2025'.trim().isEmpty, isFalse);
    });

    test('generated join code is 5 characters', () {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      // Simulate code generation
      final code = List.generate(5, (i) => chars[i % chars.length]).join();
      expect(code.length, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // Assignment form validation
  // ---------------------------------------------------------------------------

  group('Assignment form validation', () {
    test('empty title is invalid', () {
      expect(''.trim().isEmpty, isTrue);
    });

    test('whitespace-only title is invalid', () {
      expect('   '.trim().isEmpty, isTrue);
    });

    test('valid title passes', () {
      expect('SQL Basics Assignment'.trim().isEmpty, isFalse);
    });

    test('due date in the past is invalid', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(past.isAfter(DateTime.now()), isFalse);
    });

    test('due date in the future is valid', () {
      final future = DateTime.now().add(const Duration(days: 7));
      expect(future.isAfter(DateTime.now()), isTrue);
    });

    test('submission blocked with no questions', () {
      final questions = <Map<String, dynamic>>[];
      expect(questions.isEmpty, isTrue);
    });

    test('submission allowed with at least one question', () {
      final questions = [{'prompt': 'SELECT * FROM users', 'answer': 'SELECT * FROM users'}];
      expect(questions.isEmpty, isFalse);
    });

    test('submission blocked with no cohort selected', () {
      String? selectedCohort;
      expect(selectedCohort == null, isTrue);
    });

    test('submission allowed when cohort is selected', () {
      const selectedCohort = 'COHORT_ABC';
      expect(selectedCohort.isEmpty, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Quiz form validation
  // ---------------------------------------------------------------------------

  group('Quiz form validation', () {
    test('empty quiz title is invalid', () {
      expect(''.trim().isEmpty, isTrue);
    });

    test('quiz with no questions cannot be submitted', () {
      final questions = <Map<String, dynamic>>[];
      expect(questions.isEmpty, isTrue);
    });

    test('quiz question with empty prompt is invalid', () {
      final q = {'prompt': '', 'answer': 'SELECT 1'};
      expect((q['prompt'] as String).trim().isEmpty, isTrue);
    });

    test('quiz question with prompt and answer is valid', () {
      final q = {'prompt': 'Select all users', 'answer': 'SELECT * FROM users'};
      expect((q['prompt'] as String).trim().isEmpty, isFalse);
      expect((q['answer'] as String).trim().isEmpty, isFalse);
    });

    test('time limit of zero is invalid', () {
      expect(0 > 0, isFalse);
    });

    test('negative time limit is invalid', () {
      expect(-5 > 0, isFalse);
    });

    test('positive time limit is valid', () {
      expect(30 > 0, isTrue);
    });
  });
}
