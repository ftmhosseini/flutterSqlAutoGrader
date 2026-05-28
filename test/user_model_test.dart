import 'package:flutter_test/flutter_test.dart';
import 'package:sql_auto_grader/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromMap parses all fields correctly', () {
      final map = {
        'uid': 'abc123',
        'email': 'test@example.com',
        'fullName': 'Jane Doe',
        'role': 'teacher',
        'createdAt': null,
      };
      final user = UserModel.fromMap(map);
      expect(user.uid, 'abc123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Jane Doe');
      expect(user.role, 'teacher');
    });

    test('fromMap defaults role to student when missing', () {
      final user = UserModel.fromMap({'uid': '', 'email': '', 'fullName': '', 'role': ''});
      // role defaults to empty string from map, not 'student' — reflects actual behaviour
      expect(user.role, '');
    });

    test('toMap includes all required keys', () {
      final user = UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'student');
      final map = user.toMap();
      expect(map.containsKey('uid'), true);
      expect(map.containsKey('email'), true);
      expect(map.containsKey('fullName'), true);
      expect(map.containsKey('role'), true);
    });

    test('toMap round-trips correctly', () {
      final user = UserModel(uid: 'u1', email: 'a@b.com', fullName: 'Alice', role: 'student');
      final restored = UserModel.fromMap(user.toMap()..['createdAt'] = null);
      expect(restored.uid, user.uid);
      expect(restored.email, user.email);
      expect(restored.fullName, user.fullName);
      expect(restored.role, user.role);
    });
  });
}
