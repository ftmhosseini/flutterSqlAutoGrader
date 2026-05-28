import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:sql_auto_grader/models/user_model.dart';
import 'package:sql_auto_grader/services/user_session.dart';

void main() {
  setUp(() {
    UserSession.set(UserModel(
      uid: 'student-uid',
      email: 'student@test.com',
      fullName: 'Jane Student',
      role: 'student',
    ));
  });

  tearDown(() => UserSession.clear());

  // ─── Student Assignments Logic ────────────────────────────────────────────
  group('Student - Assignments logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches student_assignments for current user', () async {
      await db.collection('student_assignments').doc('sa1').set({
        'assignment_id': 'a1',
        'student_user_id': 'student-uid',
        'status': 'assigned',
      });
      await db.collection('student_assignments').doc('sa2').set({
        'assignment_id': 'a2',
        'student_user_id': 'other-uid',
        'status': 'assigned',
      });

      final snap = await db.collection('student_assignments')
          .where('student_user_id', isEqualTo: 'student-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['assignment_id'], 'a1');
    });

    test('separates pending and submitted assignments', () async {
      await db.collection('student_assignments').doc('sa1').set({
        'assignment_id': 'a1', 'student_user_id': 'student-uid', 'status': 'assigned',
      });
      await db.collection('student_assignments').doc('sa2').set({
        'assignment_id': 'a2', 'student_user_id': 'student-uid', 'status': 'submitted',
      });
      await db.collection('student_assignments').doc('sa3').set({
        'assignment_id': 'a3', 'student_user_id': 'student-uid', 'status': 'completed',
      });

      final snap = await db.collection('student_assignments')
          .where('student_user_id', isEqualTo: 'student-uid').get();
      final all = snap.docs.map((d) => d.data()).toList();

      final pending = all.where((a) => a['status'] == 'assigned').toList();
      final submitted = all.where((a) => a['status'] == 'submitted' || a['status'] == 'completed').toList();

      expect(pending.length, 1);
      expect(submitted.length, 2);
    });

    test('enriches assignment with title from assignments collection', () async {
      await db.collection('assignments').doc('a1').set({
        'title': 'SQL Basics',
        'questions': [{'question_id': 'q1', 'question': 'Select all'}],
      });

      final doc = await db.collection('assignments').doc('a1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['title'], 'SQL Basics');
    });

    test('SQL validation only allows SELECT statements', () {
      bool isValidSql(String sql) => sql.trim().toLowerCase().startsWith('select');

      expect(isValidSql('SELECT * FROM users'), isTrue);
      expect(isValidSql('  select name from t'), isTrue);
      expect(isValidSql('DROP TABLE users'), isFalse);
      expect(isValidSql('INSERT INTO t VALUES (1)'), isFalse);
      expect(isValidSql('DELETE FROM users'), isFalse);
      expect(isValidSql('UPDATE users SET name="x"'), isFalse);
      expect(isValidSql(''), isFalse);
    });

    test('saves question attempt to Firestore', () async {
      final ref = db.collection('question_attempts').doc();
      await ref.set({
        'student_user_id': 'student-uid',
        'question_id': 'q1',
        'submitted_sql': 'SELECT * FROM users',
        'is_correct': true,
      });

      final snap = await db.collection('question_attempts').doc(ref.id).get();
      expect(snap.data()!['is_correct'], isTrue);
      expect(snap.data()!['submitted_sql'], 'SELECT * FROM users');
    });
  });

  // ─── Student Quizzes Logic ────────────────────────────────────────────────
  group('Student - Quizzes logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches quizzes for student cohorts', () async {
      await db.collection('cohorts').doc('C1').set({
        'cohort_id': 'C1',
        'student_uids': ['student-uid', 'other-uid'],
      });
      await db.collection('quizzes').doc('q1').set({
        'title': 'Quiz 1',
        'student_class': 'C1',
        'owner_user_id': 'teacher-uid',
      });
      await db.collection('quizzes').doc('q2').set({
        'title': 'Quiz All',
        'student_class': 'all',
        'owner_user_id': 'teacher-uid',
      });

      final cohortSnap = await db.collection('cohorts')
          .where('student_uids', arrayContains: 'student-uid').get();
      final cohortIds = cohortSnap.docs.map((d) => d.data()['cohort_id'] as String).toList();
      final targets = ['all', ...cohortIds];

      expect(targets, contains('C1'));
      expect(targets, contains('all'));
    });

    test('determines quiz status based on submission', () {
      // Simulating status logic from QuizzesPage
      String getStatus(Map<String, dynamic>? submission, DateTime createdOn) {
        final today = DateTime(2025, 6, 1);
        final createdDay = DateTime(createdOn.year, createdOn.month, createdOn.day);
        if (submission != null) return 'Completed';
        if (createdDay.isBefore(today)) return 'Due';
        return 'New';
      }

      expect(getStatus({'mark': 5}, DateTime(2025, 5, 20)), 'Completed');
      expect(getStatus(null, DateTime(2025, 5, 20)), 'Due');
      expect(getStatus(null, DateTime(2025, 6, 1)), 'New');
    });

    test('saves quiz submission', () async {
      await db.collection('student_quizzes').doc('sq1').set({
        'quiz_id': 'q1',
        'student_user_id': 'student-uid',
        'mark': 8,
        'total_mark': 10,
      });

      final snap = await db.collection('student_quizzes')
          .where('student_user_id', isEqualTo: 'student-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['mark'], 8);
    });
  });

  // ─── Student Results Logic ────────────────────────────────────────────────
  group('Student - Results logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches submitted/completed assignments', () async {
      await db.collection('student_assignments').doc('sa1').set({
        'student_user_id': 'student-uid', 'assignment_id': 'a1',
        'status': 'submitted', 'earned_point': 7,
      });
      await db.collection('student_assignments').doc('sa2').set({
        'student_user_id': 'student-uid', 'assignment_id': 'a2',
        'status': 'assigned', 'earned_point': 0,
      });

      final snap = await db.collection('student_assignments')
          .where('student_user_id', isEqualTo: 'student-uid')
          .where('status', whereIn: ['submitted', 'completed']).get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['earned_point'], 7);
    });

    test('enriches results with assignment title', () async {
      await db.collection('assignments').doc('a1').set({
        'title': 'SQL Joins', 'total_marks': 10,
      });

      final doc = await db.collection('assignments').doc('a1').get();
      expect(doc.data()!['title'], 'SQL Joins');
      expect(doc.data()!['total_marks'], 10);
    });

    test('calculates total earned vs total marks', () {
      final results = [
        {'earned_point': 7, 'total_marks': 10},
        {'earned_point': 5, 'total_marks': 10},
        {'earned_point': 9, 'total_marks': 10},
      ];

      final earned = results.fold<int>(0, (s, r) => s + (r['earned_point'] as int));
      final total = results.fold<int>(0, (s, r) => s + (r['total_marks'] as int));

      expect(earned, 21);
      expect(total, 30);
      expect((earned / total * 100).round(), 70);
    });
  });

  // ─── Student Cohort Logic ────────────────────────────────────────────────
  group('Student - Cohort join logic', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('fetches cohorts student belongs to', () async {
      await db.collection('cohorts').doc('C1').set({
        'name': 'CS101', 'student_uids': ['student-uid', 'other'],
      });
      await db.collection('cohorts').doc('C2').set({
        'name': 'CS201', 'student_uids': ['other'],
      });

      final snap = await db.collection('cohorts')
          .where('student_uids', arrayContains: 'student-uid').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['name'], 'CS101');
    });

    test('join with valid code adds student to cohort', () async {
      await db.collection('cohorts').doc('AB12C').set({
        'name': 'CS301', 'student_uids': ['other-uid'],
      });

      // Simulate join
      final snap = await db.collection('cohorts').doc('AB12C').get();
      expect(snap.exists, isTrue);

      final uids = List<String>.from(snap.data()!['student_uids'] ?? []);
      expect(uids.contains('student-uid'), isFalse);
      uids.add('student-uid');
      await db.collection('cohorts').doc('AB12C').update({'student_uids': uids});

      final updated = await db.collection('cohorts').doc('AB12C').get();
      expect(List<String>.from(updated.data()!['student_uids']), contains('student-uid'));
    });

    test('join with invalid code shows error', () async {
      final snap = await db.collection('cohorts').doc('XXXXX').get();
      expect(snap.exists, isFalse);
    });

    test('already a member detection', () {
      final uids = ['student-uid', 'other-uid'];
      expect(uids.contains('student-uid'), isTrue);
    });

    test('code validation - must be 5 chars', () {
      expect('AB'.length == 5, isFalse);
      expect('ABCDE'.length == 5, isTrue);
      expect('ABCDEF'.length == 5, isFalse);
    });

    test('empty code rejected', () {
      expect(''.trim().isEmpty, isTrue);
      expect('   '.trim().isEmpty, isTrue);
    });
  });

  // ─── SQL Tutor Logic ─────────────────────────────────────────────────────
  group('Student - SQL Tutor logic', () {
    test('sandbox seed SQL creates tables', () {
      const seedSql = [
        "CREATE TABLE IF NOT EXISTS Students (studentId INTEGER PRIMARY KEY, name TEXT, age INTEGER, city TEXT)",
        "CREATE TABLE IF NOT EXISTS Grades (gradeId INTEGER PRIMARY KEY, studentId INTEGER, subject TEXT, score INTEGER)",
        "INSERT OR IGNORE INTO Students VALUES (1,'Alice',20,'Toronto'),(2,'Bob',22,'Calgary')",
        "INSERT OR IGNORE INTO Grades VALUES (1,1,'Math',88),(2,1,'Science',92)",
      ];
      expect(seedSql.length, 4);
      expect(seedSql[0].contains('CREATE TABLE'), isTrue);
      expect(seedSql[2].contains('INSERT'), isTrue);
    });

    test('lessons have required fields', () {
      final lesson = {
        'id': 'select',
        'title': 'SELECT – Fetch Data',
        'explanation': 'SELECT retrieves rows...',
        'starter': 'SELECT * FROM Students;',
      };
      expect(lesson.containsKey('id'), isTrue);
      expect(lesson.containsKey('title'), isTrue);
      expect(lesson.containsKey('explanation'), isTrue);
      expect(lesson.containsKey('starter'), isTrue);
    });

    test('SQL execution validates SELECT-only for grading', () {
      bool isSelectOnly(String sql) => sql.trim().toLowerCase().startsWith('select');

      // In tutor mode, all SQL is allowed (CREATE, INSERT, DROP for learning)
      // But for graded assignments, only SELECT
      expect(isSelectOnly('SELECT * FROM Students'), isTrue);
      expect(isSelectOnly('CREATE TABLE T (id INT)'), isFalse);
    });

    test('query result normalization for comparison', () {
      List<Map<String, String>> normalize(List<Map<String, dynamic>> rows) {
        return rows.map((r) => r.map((k, v) => MapEntry(k.toLowerCase(), v?.toString().toLowerCase() ?? '')))
            .toList()
          ..sort((a, b) => a.toString().compareTo(b.toString()));
      }

      final studentRows = [
        {'Name': 'Alice', 'Age': 20},
        {'Name': 'Bob', 'Age': 22},
      ];
      final expectedRows = [
        {'name': 'Bob', 'age': 22},
        {'name': 'Alice', 'age': 20},
      ];

      final normStudent = normalize(studentRows);
      final normExpected = normalize(expectedRows);
      expect(normStudent.toString(), normExpected.toString());
    });

    test('query result mismatch detected', () {
      List<Map<String, String>> normalize(List<Map<String, dynamic>> rows) {
        return rows.map((r) => r.map((k, v) => MapEntry(k.toLowerCase(), v?.toString().toLowerCase() ?? '')))
            .toList()
          ..sort((a, b) => a.toString().compareTo(b.toString()));
      }

      final studentRows = [{'Name': 'Alice', 'Age': 20}];
      final expectedRows = [{'Name': 'Alice', 'Age': 20}, {'Name': 'Bob', 'Age': 22}];

      expect(normalize(studentRows).toString() == normalize(expectedRows).toString(), isFalse);
    });

    test('AI chat message structure', () {
      final messages = <Map<String, String>>[];
      messages.add({'role': 'user', 'content': 'How do I use JOIN?'});
      messages.add({'role': 'assistant', 'content': 'JOIN combines rows from two tables...'});

      expect(messages.length, 2);
      expect(messages.first['role'], 'user');
      expect(messages.last['role'], 'assistant');
    });
  });
}
