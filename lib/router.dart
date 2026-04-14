import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/dashboard/dashboard_shell.dart';
import '../pages/dashboard/dashboard_home.dart';
import '../pages/dashboard/profile_page.dart';
import '../pages/dashboard/student/assignments_page.dart';
import '../pages/dashboard/student/results_page.dart';
import '../pages/dashboard/student/quizzes_page.dart';
import '../pages/dashboard/student/cohort_page.dart';
import '../pages/dashboard/student/sql_tutor_page.dart';
import '../pages/dashboard/teacher/quiz_manager_page.dart';
import '../pages/dashboard/teacher/database_manager_page.dart';
import '../pages/dashboard/teacher/cohort_manager_page.dart';
import '../pages/dashboard/teacher/submission_status_page.dart';
import '../pages/dashboard/teacher/assignment_list_page.dart';

GoRouter buildRouter(BuildContext context) {
  final auth = Provider.of<AuthProvider>(context, listen: false);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (ctx, state) {
      if (auth.loading) return null;
      final loggedIn = auth.role != null;
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/register';
      if (!loggedIn && loc.startsWith('/dashboard')) return '/login';
      if (loggedIn && (onAuth || loc == '/')) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      ShellRoute(
        builder: (_, _, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardHome()),
          GoRoute(path: '/dashboard/teacher/overview', builder: (_, _) => const TeacherOverviewPage()),
          GoRoute(path: '/dashboard/profile', builder: (_, _) => const ProfilePage()),

          // Student
          GoRoute(path: '/dashboard/student/overview', builder: (_, _) => const StudentOverviewPage()),
          GoRoute(path: '/dashboard/student/assignments', builder: (_, _) => const AssignmentsPage()),
          GoRoute(path: '/dashboard/student/results', builder: (_, _) => const ResultsPage()),
          GoRoute(path: '/dashboard/student/quizzes', builder: (_, _) => const QuizzesPage()),
          GoRoute(path: '/dashboard/student/cohorts', builder: (_, _) => const StudentCohortPage()),
          GoRoute(path: '/dashboard/student/tutor', builder: (_, _) => const SqlTutorPage()),

          // Teacher
          GoRoute(path: '/dashboard/teacher/assignments', builder: (_, _) => const AssignmentListPage()),
          GoRoute(path: '/dashboard/teacher/cohorts', builder: (_, _) => const CohortManagerPage()),
          GoRoute(path: '/dashboard/teacher/datasets', builder: (_, _) => const DatabaseManagerPage()),
          GoRoute(path: '/dashboard/teacher/quizzes', builder: (_, _) => const QuizManagerPage()),
          GoRoute(path: '/dashboard/teacher/submissions', builder: (_, _) => const SubmissionStatusPage()),
          GoRoute(path: '/dashboard/teacher/submissions/:assignmentId', builder: (_, state) => SubmissionStatusPage(assignmentId: state.pathParameters['assignmentId'])),
        ],
      ),
    ],
  );
}
