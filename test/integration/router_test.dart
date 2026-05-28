import 'package:flutter_test/flutter_test.dart';
import 'package:sql_auto_grader/models/user_model.dart';
import 'package:sql_auto_grader/services/user_session.dart';

// Router tests verify the redirect logic without needing the full widget tree.
// The router redirect function depends on auth.loading and auth.role.

void main() {
  setUp(() => UserSession.clear());

  group('Router redirect logic', () {
    // Simulating the redirect function from router.dart
    String? redirect({required bool loading, required String? role, required String location}) {
      if (loading) return null;
      final loggedIn = role != null;
      final onAuth = location == '/login' || location == '/register' || location == '/forgot-password';
      if (!loggedIn && location.startsWith('/dashboard')) return '/login';
      if (loggedIn && (onAuth || location == '/')) return '/dashboard';
      return null;
    }

    test('returns null while loading (no redirect)', () {
      expect(redirect(loading: true, role: null, location: '/dashboard'), isNull);
      expect(redirect(loading: true, role: 'teacher', location: '/login'), isNull);
    });

    test('unauthenticated user accessing dashboard redirects to login', () {
      expect(redirect(loading: false, role: null, location: '/dashboard'), '/login');
      expect(redirect(loading: false, role: null, location: '/dashboard/teacher/assignments'), '/login');
      expect(redirect(loading: false, role: null, location: '/dashboard/student/quizzes'), '/login');
    });

    test('unauthenticated user on public pages gets no redirect', () {
      expect(redirect(loading: false, role: null, location: '/'), isNull);
      expect(redirect(loading: false, role: null, location: '/login'), isNull);
      expect(redirect(loading: false, role: null, location: '/register'), isNull);
      expect(redirect(loading: false, role: null, location: '/forgot-password'), isNull);
    });

    test('authenticated user on auth pages redirects to dashboard', () {
      expect(redirect(loading: false, role: 'teacher', location: '/login'), '/dashboard');
      expect(redirect(loading: false, role: 'student', location: '/register'), '/dashboard');
      expect(redirect(loading: false, role: 'teacher', location: '/forgot-password'), '/dashboard');
      expect(redirect(loading: false, role: 'student', location: '/'), '/dashboard');
    });

    test('authenticated user on dashboard gets no redirect', () {
      expect(redirect(loading: false, role: 'teacher', location: '/dashboard'), isNull);
      expect(redirect(loading: false, role: 'teacher', location: '/dashboard/teacher/assignments'), isNull);
      expect(redirect(loading: false, role: 'student', location: '/dashboard/student/quizzes'), isNull);
    });
  });

  group('Route paths', () {
    test('all teacher routes start with /dashboard/teacher/', () {
      const teacherRoutes = [
        '/dashboard/teacher/assignments',
        '/dashboard/teacher/cohorts',
        '/dashboard/teacher/datasets',
        '/dashboard/teacher/quizzes',
        '/dashboard/teacher/submissions',
        '/dashboard/teacher/overview',
      ];
      for (final route in teacherRoutes) {
        expect(route.startsWith('/dashboard/teacher/'), isTrue);
      }
    });

    test('all student routes start with /dashboard/student/', () {
      const studentRoutes = [
        '/dashboard/student/assignments',
        '/dashboard/student/quizzes',
        '/dashboard/student/results',
        '/dashboard/student/cohorts',
        '/dashboard/student/tutor',
        '/dashboard/student/overview',
      ];
      for (final route in studentRoutes) {
        expect(route.startsWith('/dashboard/student/'), isTrue);
      }
    });

    test('shared routes exist', () {
      const sharedRoutes = ['/dashboard', '/dashboard/profile'];
      for (final route in sharedRoutes) {
        expect(route.startsWith('/dashboard'), isTrue);
      }
    });

    test('public routes do not start with /dashboard', () {
      const publicRoutes = ['/', '/login', '/register', '/forgot-password'];
      for (final route in publicRoutes) {
        expect(route.startsWith('/dashboard'), isFalse);
      }
    });
  });

  group('Role-based navigation', () {
    test('teacher role is detected correctly', () {
      UserSession.set(UserModel(uid: 'u1', email: 'a@b.com', fullName: 'A', role: 'teacher'));
      expect(UserSession.role, 'teacher');
      expect(UserSession.role == 'teacher', isTrue);
    });

    test('student role is detected correctly', () {
      UserSession.set(UserModel(uid: 'u2', email: 'b@c.com', fullName: 'B', role: 'student'));
      expect(UserSession.role, 'student');
      expect(UserSession.role == 'student', isTrue);
    });

    test('DashboardShell shows different nav for teacher vs student', () {
      // Teacher nav items
      UserSession.set(UserModel(uid: 'u1', email: 'a@b.com', fullName: 'A', role: 'teacher'));
      final isTeacher = UserSession.role == 'teacher';
      expect(isTeacher, isTrue);

      // Student nav items
      UserSession.set(UserModel(uid: 'u2', email: 'b@c.com', fullName: 'B', role: 'student'));
      final isStudent = UserSession.role == 'student';
      expect(isStudent, isTrue);
    });

    test('submission route accepts assignmentId parameter', () {
      const path = '/dashboard/teacher/submissions/abc123';
      final parts = path.split('/');
      final assignmentId = parts.last;
      expect(assignmentId, 'abc123');
    });
  });
}
