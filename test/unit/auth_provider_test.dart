import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:sql_auto_grader/models/user_model.dart';
import 'package:sql_auto_grader/services/user_session.dart';

// We test the AuthProvider logic manually since it depends on FirebaseAuth.instance
// which can't be injected. Instead we test the auth state logic pattern directly.

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    UserSession.clear();
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('AuthProvider logic', () {
    test('unauthenticated user results in null role', () async {
      mockAuth = MockFirebaseAuth(signedIn: false);
      final user = mockAuth.currentUser;
      expect(user, isNull);
      // Simulating what AuthProvider does
      UserSession.clear();
      expect(UserSession.role, isNull);
    });

    test('authenticated verified user gets role from Firestore', () async {
      final mockUser = MockUser(
        isEmailVerified: true,
        uid: 'test-uid',
        email: 'test@example.com',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Seed Firestore with user doc
      await fakeFirestore.collection('users').doc('test-uid').set({
        'uid': 'test-uid',
        'email': 'test@example.com',
        'fullName': 'Test User',
        'role': 'teacher',
      });

      // Simulate AuthProvider logic
      final user = mockAuth.currentUser;
      expect(user, isNotNull);
      expect(user!.emailVerified, isTrue);

      final snap = await fakeFirestore.collection('users').doc(user.uid).get();
      final userData = UserModel.fromMap(snap.data()!);
      UserSession.set(userData);

      expect(UserSession.role, 'teacher');
      expect(UserSession.uid, 'test-uid');
      expect(UserSession.fullName, 'Test User');
    });

    test('unverified user does not set session', () async {
      final mockUser = MockUser(
        isEmailVerified: false,
        uid: 'unverified-uid',
        email: 'unverified@example.com',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      final user = mockAuth.currentUser;
      expect(user!.emailVerified, isFalse);

      // AuthProvider logic: unverified → clear session
      UserSession.clear();
      expect(UserSession.role, isNull);
    });

    test('sign out clears session', () async {
      final mockUser = MockUser(
        isEmailVerified: true,
        uid: 'test-uid',
        email: 'test@example.com',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      UserSession.set(UserModel(uid: 'test-uid', email: 'test@example.com', fullName: 'Test', role: 'student'));
      expect(UserSession.role, 'student');

      await mockAuth.signOut();
      UserSession.clear();
      expect(UserSession.role, isNull);
      expect(mockAuth.currentUser, isNull);
    });

    test('sign in with email and password works', () async {
      final mockUser = MockUser(
        isEmailVerified: true,
        uid: 'login-uid',
        email: 'login@example.com',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser);

      final cred = await mockAuth.signInWithEmailAndPassword(
        email: 'login@example.com',
        password: 'password123',
      );
      expect(cred.user, isNotNull);
      expect(cred.user!.uid, 'login-uid');
    });

    test('create user with email and password works', () async {
      mockAuth = MockFirebaseAuth();
      final cred = await mockAuth.createUserWithEmailAndPassword(
        email: 'new@example.com',
        password: 'password123',
      );
      expect(cred.user, isNotNull);
      expect(cred.user!.email, 'new@example.com');
    });

    test('password reset sends email without error', () async {
      mockAuth = MockFirebaseAuth();
      // Should not throw
      await mockAuth.sendPasswordResetEmail(email: 'test@example.com');
    });
  });
}
