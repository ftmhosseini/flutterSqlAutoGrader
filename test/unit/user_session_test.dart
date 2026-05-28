import 'package:flutter_test/flutter_test.dart';
import 'package:sql_auto_grader/models/user_model.dart';
import 'package:sql_auto_grader/services/user_session.dart';

void main() {
  setUp(() => UserSession.clear());

  group('UserSession', () {
    test('initially returns null for all fields', () {
      expect(UserSession.uid, isNull);
      expect(UserSession.email, isNull);
      expect(UserSession.fullName, isNull);
      expect(UserSession.role, isNull);
      expect(UserSession.get(), isNull);
    });

    test('set stores user and exposes fields', () {
      final user = UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'teacher');
      UserSession.set(user);
      expect(UserSession.uid, 'u1');
      expect(UserSession.email, 'a@b.com');
      expect(UserSession.fullName, 'Alice');
      expect(UserSession.role, 'teacher');
      expect(UserSession.get(), user);
    });

    test('clear resets all fields to null', () {
      UserSession.set(UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'student'));
      UserSession.clear();
      expect(UserSession.uid, isNull);
      expect(UserSession.role, isNull);
    });

    test('set with null clears session', () {
      UserSession.set(UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'student'));
      UserSession.set(null);
      expect(UserSession.uid, isNull);
    });

    test('overwriting session replaces previous user', () {
      UserSession.set(UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'student'));
      UserSession.set(UserModel(uid: 'u2', email: 'b@c.com', fullName: 'Bob', role: 'teacher'));
      expect(UserSession.uid, 'u2');
      expect(UserSession.role, 'teacher');
    });
  });
}
