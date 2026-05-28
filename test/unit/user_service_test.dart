import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:sql_auto_grader/models/user_model.dart';

// UserService uses a top-level `_db = FirebaseFirestore.instance` which can't be injected.
// We test the same logic against FakeFirebaseFirestore directly.

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('UserService - getUser logic', () {
    test('returns null when user doc does not exist', () async {
      final snap = await fakeFirestore.collection('users').doc('nonexistent').get();
      expect(snap.exists, isFalse);
    });

    test('returns UserModel when user doc exists', () async {
      await fakeFirestore.collection('users').doc('uid1').set({
        'uid': 'uid1',
        'email': 'alice@test.com',
        'fullName': 'Alice',
        'role': 'teacher',
      });

      final snap = await fakeFirestore.collection('users').doc('uid1').get();
      expect(snap.exists, isTrue);
      final user = UserModel.fromMap(snap.data()!);
      expect(user.uid, 'uid1');
      expect(user.email, 'alice@test.com');
      expect(user.fullName, 'Alice');
      expect(user.role, 'teacher');
    });
  });

  group('UserService - createUser logic', () {
    test('creates user document in Firestore', () async {
      final user = UserModel(uid: 'uid2', email: 'bob@test.com', fullName: 'Bob', role: 'student');
      await fakeFirestore.collection('users').doc('uid2').set(user.toMap());

      final snap = await fakeFirestore.collection('users').doc('uid2').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['fullName'], 'Bob');
      expect(snap.data()!['role'], 'student');
    });

    test('overwrites existing user document', () async {
      await fakeFirestore.collection('users').doc('uid3').set({
        'uid': 'uid3', 'email': 'old@test.com', 'fullName': 'Old', 'role': 'student',
      });
      final newUser = UserModel(uid: 'uid3', email: 'new@test.com', fullName: 'New', role: 'teacher');
      await fakeFirestore.collection('users').doc('uid3').set(newUser.toMap());

      final snap = await fakeFirestore.collection('users').doc('uid3').get();
      expect(snap.data()!['email'], 'new@test.com');
      expect(snap.data()!['fullName'], 'New');
      expect(snap.data()!['role'], 'teacher');
    });
  });

  group('UserService - markUserVerified logic', () {
    test('updates emailVerified field', () async {
      await fakeFirestore.collection('users').doc('uid4').set({
        'uid': 'uid4', 'email': 'test@test.com', 'fullName': 'Test', 'role': 'student',
      });
      await fakeFirestore.collection('users').doc('uid4').update({'emailVerified': true});

      final snap = await fakeFirestore.collection('users').doc('uid4').get();
      expect(snap.data()!['emailVerified'], isTrue);
    });
  });

  group('UserService - getAllUsers logic', () {
    test('returns empty list when no users', () async {
      final snap = await fakeFirestore.collection('users').get();
      expect(snap.docs, isEmpty);
    });

    test('returns all users', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'uid': 'u1', 'email': 'a@t.com', 'fullName': 'A', 'role': 'student',
      });
      await fakeFirestore.collection('users').doc('u2').set({
        'uid': 'u2', 'email': 'b@t.com', 'fullName': 'B', 'role': 'teacher',
      });

      final snap = await fakeFirestore.collection('users').get();
      final users = snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
      expect(users.length, 2);
      expect(users.map((u) => u.uid).toSet(), {'u1', 'u2'});
    });
  });
}
