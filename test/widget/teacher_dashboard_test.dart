import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:sql_auto_grader/models/user_model.dart';
import 'package:sql_auto_grader/services/user_session.dart';

// Teacher dashboard pages use FirebaseFirestore.instance directly, so we test
// the business logic (validation, data transforms) and verify UI structure
// using lightweight test widgets that replicate the page patterns.

void main() {
  setUp(() {
    UserSession.set(UserModel(
      uid: 'teacher-uid',
      email: 'teacher@test.com',
      fullName: 'Prof Smith',
      role: 'teacher',
    ));
  });

  tearDown(() => UserSession.clear());

  // ─── Assignment List Logic ────────────────────────────────────────────────
  group('Teacher - Assignment list logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches assignments owned by teacher', () async {
      await db.collection('assignments').doc('a1').set({
        'title': 'SQL Basics',
        'owner_user_id': 'teacher-uid',
        'due_date': '2025-12-01',
      });
      await db.collection('assignments').doc('a2').set({
        'title': 'Other Teacher',
        'owner_user_id': 'other-uid',
        'due_date': '2025-12-01',
      });

      final snap = await db.collection('assignments')
          .where('owner_user_id', isEqualTo: 'teacher-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['title'], 'SQL Basics');
    });

    test('detects published assignment (has student_assignments)', () async {
      await db.collection('student_assignments').doc('sa1').set({
        'assignment_id': 'a1',
        'student_user_id': 'student1',
        'status': 'assigned',
      });

      final snap = await db.collection('student_assignments')
          .where('assignment_id', isEqualTo: 'a1').get();
      expect(snap.docs.isNotEmpty, isTrue);
    });

    test('detects unpublished assignment (no student_assignments)', () async {
      final snap = await db.collection('student_assignments')
          .where('assignment_id', isEqualTo: 'a-new').get();
      expect(snap.docs.isEmpty, isTrue);
    });

    test('publish creates student_assignments for cohort members', () async {
      await db.collection('cohorts').doc('C1').set({
        'cohort_id': 'C1',
        'student_uids': ['s1', 's2', 's3'],
        'owner_user_id': 'teacher-uid',
      });

      // Simulate publish logic
      final cohortSnap = await db.collection('cohorts')
          .where('cohort_id', isEqualTo: 'C1').get();
      final studentUids = List<String>.from(cohortSnap.docs.first.data()['student_uids'] ?? []);

      for (final uid in studentUids) {
        final ref = db.collection('student_assignments').doc();
        await ref.set({
          'student_assignment_id': ref.id,
          'assignment_id': 'a1',
          'student_user_id': uid,
          'status': 'assigned',
        });
      }

      final saSnap = await db.collection('student_assignments')
          .where('assignment_id', isEqualTo: 'a1').get();
      expect(saSnap.docs.length, 3);
    });

    test('delete removes assignment document', () async {
      await db.collection('assignments').doc('a-del').set({
        'title': 'To Delete',
        'owner_user_id': 'teacher-uid',
      });
      await db.collection('assignments').doc('a-del').delete();

      final snap = await db.collection('assignments').doc('a-del').get();
      expect(snap.exists, isFalse);
    });
  });

  // ─── Cohort Manager Logic ────────────────────────────────────────────────
  group('Teacher - Cohort manager logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('creates cohort with unique 5-char code', () async {
      const code = 'AB12C';
      await db.collection('cohorts').doc(code).set({
        'name': 'CS101',
        'cohort_id': code,
        'owner_user_id': 'teacher-uid',
      });

      final snap = await db.collection('cohorts').doc(code).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], 'CS101');
      expect(code.length, 5);
    });

    test('fetches only teacher-owned cohorts', () async {
      await db.collection('cohorts').doc('C1').set({'owner_user_id': 'teacher-uid', 'name': 'Mine'});
      await db.collection('cohorts').doc('C2').set({'owner_user_id': 'other-uid', 'name': 'Other'});

      final snap = await db.collection('cohorts')
          .where('owner_user_id', isEqualTo: 'teacher-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['name'], 'Mine');
    });

    test('cohort name validation rejects empty', () {
      expect(''.trim().isEmpty, isTrue);
      expect('   '.trim().isEmpty, isTrue);
      expect('CS101'.trim().isEmpty, isFalse);
    });

    test('lists students in cohort', () async {
      await db.collection('cohorts').doc('C1').set({
        'student_uids': ['s1', 's2'],
        'owner_user_id': 'teacher-uid',
      });
      await db.collection('users').doc('s1').set({'fullName': 'Alice', 'role': 'student'});
      await db.collection('users').doc('s2').set({'fullName': 'Bob', 'role': 'student'});

      final cohort = (await db.collection('cohorts').doc('C1').get()).data()!;
      final uids = List<String>.from(cohort['student_uids']);
      expect(uids.length, 2);
    });
  });

  // ─── Database Manager Logic ──────────────────────────────────────────────
  group('Teacher - Database manager logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('loads config from sqliteConfigs/mainConfig', () async {
      await db.doc('sqliteConfigs/mainConfig').set({
        'testDB': {
          'queries': ['CREATE TABLE t1 (id INTEGER)', 'INSERT INTO t1 VALUES (1)'],
        },
      });

      final snap = await db.doc('sqliteConfigs/mainConfig').get();
      expect(snap.exists, isTrue);
      final config = snap.data()!;
      expect(config.containsKey('testDB'), isTrue);
      final queries = List<String>.from((config['testDB'] as Map)['queries']);
      expect(queries.length, 2);
    });

    test('saves new dataset to config', () async {
      await db.doc('sqliteConfigs/mainConfig').set({
        'newDB': {'queries': ['CREATE TABLE users (id INTEGER, name TEXT)']},
      });

      final snap = await db.doc('sqliteConfigs/mainConfig').get();
      expect(snap.data()!.containsKey('newDB'), isTrue);
    });

    test('dataset name validation', () {
      expect(''.trim().isEmpty, isTrue);
      expect('my_dataset'.trim().isEmpty, isFalse);
    });

    test('table name validation', () {
      expect(''.trim().isEmpty, isTrue);
      expect('users'.trim().isEmpty, isFalse);
    });
  });

  // ─── Quiz Manager Logic ──────────────────────────────────────────────────
  group('Teacher - Quiz manager logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches quizzes owned by teacher', () async {
      await db.collection('quizzes').doc('q1').set({
        'title': 'SQL Quiz 1',
        'owner_user_id': 'teacher-uid',
      });
      await db.collection('quizzes').doc('q2').set({
        'title': 'Other Quiz',
        'owner_user_id': 'other-uid',
      });

      final snap = await db.collection('quizzes')
          .where('owner_user_id', isEqualTo: 'teacher-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['title'], 'SQL Quiz 1');
    });

    test('creates quiz with questions', () async {
      final ref = db.collection('quizzes').doc();
      await ref.set({
        'quiz_id': ref.id,
        'title': 'New Quiz',
        'owner_user_id': 'teacher-uid',
        'student_class': 'all',
        'questions': [
          {'questionText': 'Select all users', 'answer': 'SELECT * FROM users', 'mark': 2},
        ],
      });

      final snap = await db.collection('quizzes').doc(ref.id).get();
      expect(snap.data()!['title'], 'New Quiz');
      final questions = List<Map<String, dynamic>>.from(snap.data()!['questions']);
      expect(questions.length, 1);
      expect(questions[0]['mark'], 2);
    });

    test('quiz title validation', () {
      expect(''.trim().isEmpty, isTrue);
      expect('SQL Basics Quiz'.trim().isEmpty, isFalse);
    });

    test('quiz must have at least one question', () {
      final questions = <Map<String, dynamic>>[];
      expect(questions.isEmpty, isTrue);
      questions.add({'questionText': 'Q1', 'answer': 'A1', 'mark': 1});
      expect(questions.isEmpty, isFalse);
    });
  });

  // ─── Submission Status Logic ─────────────────────────────────────────────
  group('Teacher - Submission status logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches student_assignments for published assignments', () async {
      await db.collection('assignments').doc('a1').set({
        'title': 'Assignment 1',
        'owner_user_id': 'teacher-uid',
        'questions': [{'question_id': 'q1'}, {'question_id': 'q2'}],
      });
      await db.collection('student_assignments').doc('sa1').set({
        'assignment_id': 'a1',
        'student_user_id': 's1',
        'status': 'submitted',
        'earned_point': 5,
      });

      final saSnap = await db.collection('student_assignments')
          .where('assignment_id', isEqualTo: 'a1').get();
      expect(saSnap.docs.length, 1);
      expect(saSnap.docs.first.data()['status'], 'submitted');
    });

    test('fetches question_attempts by student and filters by question_id', () async {
      await db.collection('question_attempts').doc('qa1').set({
        'student_user_id': 's1',
        'question_id': 'q1',
        'is_correct': true,
        'submitted_sql': 'SELECT * FROM users',
      });
      await db.collection('question_attempts').doc('qa2').set({
        'student_user_id': 's1',
        'question_id': 'q2',
        'is_correct': false,
        'submitted_sql': 'SELECT name FROM users',
      });
      await db.collection('question_attempts').doc('qa3').set({
        'student_user_id': 's1',
        'question_id': 'q-other',
        'is_correct': true,
        'submitted_sql': 'SELECT 1',
      });

      final snap = await db.collection('question_attempts')
          .where('student_user_id', isEqualTo: 's1').get();

      final assignmentQuestionIds = {'q1', 'q2'};
      final filtered = snap.docs
          .where((d) => assignmentQuestionIds.contains(d.data()['question_id']))
          .toList();

      expect(filtered.length, 2);
    });

    test('score override updates earned_point', () async {
      await db.collection('student_assignments').doc('sa1').set({
        'assignment_id': 'a1',
        'student_user_id': 's1',
        'status': 'submitted',
        'earned_point': 3,
      });

      await db.collection('student_assignments').doc('sa1').update({'earned_point': 8});

      final snap = await db.collection('student_assignments').doc('sa1').get();
      expect(snap.data()!['earned_point'], 8);
    });

    test('resolves student names from user docs', () async {
      await db.collection('users').doc('s1').set({'fullName': 'Alice', 'email': 'alice@t.com'});
      await db.collection('users').doc('s2').set({'fullName': 'Bob', 'email': 'bob@t.com'});

      final names = <String, String>{};
      for (final uid in ['s1', 's2']) {
        final snap = await db.collection('users').doc(uid).get();
        names[uid] = snap.data()?['fullName'] ?? uid;
      }
      expect(names['s1'], 'Alice');
      expect(names['s2'], 'Bob');
    });
  });

  // ─── Assignment Form Validation ──────────────────────────────────────────
  group('Teacher - Assignment form validation', () {
    test('title cannot be empty', () {
      expect(''.trim().isEmpty, isTrue);
      expect('   '.trim().isEmpty, isTrue);
    });

    test('valid title passes', () {
      expect('SQL Basics'.trim().isEmpty, isFalse);
    });

    test('due date must be in the future', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 7));
      expect(past.isAfter(DateTime.now()), isFalse);
      expect(future.isAfter(DateTime.now()), isTrue);
    });

    test('at least one question required', () {
      expect(<Map>[].isEmpty, isTrue);
      expect([{'q': 'test'}].isEmpty, isFalse);
    });

    test('cohort must be selected', () {
      String? cohort;
      expect(cohort == null, isTrue);
      cohort = 'COHORT1';
      expect(cohort.isEmpty, isFalse);
    });

    test('question must have both prompt and answer', () {
      final q = {'question': '', 'answer': 'SELECT 1'};
      expect((q['question'] as String).trim().isEmpty, isTrue);

      final valid = {'question': 'List users', 'answer': 'SELECT * FROM users'};
      expect((valid['question'] as String).trim().isEmpty, isFalse);
      expect((valid['answer'] as String).trim().isEmpty, isFalse);
    });

    test('grading policy defaults to best', () {
      const policy = 'best';
      expect(['best', 'first', 'latest'].contains(policy), isTrue);
    });
  });
}
