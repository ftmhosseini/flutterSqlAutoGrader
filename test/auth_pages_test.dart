import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sql_auto_grader/pages/login_page.dart';
import 'package:sql_auto_grader/pages/forgot_password_page.dart';

GoRouter _router(Widget page) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => page),
        GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Center(child: Text('Register')))),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold()),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router(page)));
}

void main() {
  group('LoginPage', () {
    testWidgets('renders email, password fields and login button', (tester) async {
      await _pump(tester, const LoginPage());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('shows error when login attempted with empty fields', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong email or password'), findsOneWidget);
    });

    testWidgets('navigates to forgot password on Forgot? tap', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.text('Forgot?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password'), findsOneWidget);
    });

    testWidgets('navigates to register on Sign Up tap', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });
  });

  group('ForgotPasswordPage', () {
    testWidgets('renders email field and send button', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('shows error for unknown email', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      await tester.enterText(find.byType(TextField), 'unknown@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No account found'), findsOneWidget);
    });

    testWidgets('navigates back to login on Login tap', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
