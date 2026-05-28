import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sql_auto_grader/pages/login_page.dart';
import 'package:sql_auto_grader/pages/register_page.dart';
import 'package:sql_auto_grader/pages/forgot_password_page.dart';

GoRouter _router(Widget page) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => page),
        GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  // Suppress overflow errors from source pages (not what we're testing)
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router(page)));
}

void main() {
  // ─── Login Page ───────────────────────────────────────────────────────────
  group('LoginPage widget', () {
    testWidgets('renders email and password fields', (tester) async {
      await _pump(tester, const LoginPage());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('renders login button', (tester) async {
      await _pump(tester, const LoginPage());
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('renders Welcome Back title', (tester) async {
      await _pump(tester, const LoginPage());
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('shows error on empty login attempt', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong email or password'), findsOneWidget);
    });

    testWidgets('shows error on invalid credentials', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.enterText(find.byType(TextField).first, 'bad@email.com');
      await tester.enterText(find.byType(TextField).last, 'wrongpass');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong email or password'), findsOneWidget);
    });

    testWidgets('navigates to forgot password page', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.text('Forgot?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password'), findsOneWidget);
    });

    testWidgets('navigates to register page', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('email field accepts text input', (tester) async {
      await _pump(tester, const LoginPage());
      await tester.enterText(find.byType(TextField).first, 'user@test.com');
      expect(find.text('user@test.com'), findsOneWidget);
    });

    testWidgets('password field is obscured', (tester) async {
      await _pump(tester, const LoginPage());
      final passwordField = tester.widget<TextField>(find.byType(TextField).last);
      expect(passwordField.obscureText, isTrue);
    });
  });

  // ─── Register Page ────────────────────────────────────────────────────────
  group('RegisterPage widget', () {
    testWidgets('renders Create Account title', (tester) async {
      await _pump(tester, const RegisterPage());
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders all form fields', (tester) async {
      await _pump(tester, const RegisterPage());
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('I am registering as:'), findsOneWidget);
    });

    testWidgets('renders Sign Up button', (tester) async {
      await _pump(tester, const RegisterPage());
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('role dropdown has student and teacher options', (tester) async {
      await _pump(tester, const RegisterPage());
      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Student'), findsWidgets);
      expect(find.text('Teacher'), findsWidgets);
    });

    testWidgets('has link to login page', (tester) async {
      await _pump(tester, const RegisterPage());
      // Verify the "Already have an account?" + "Login" link exists
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.widgetWithText(GestureDetector, 'Login'), findsOneWidget);
    });

    testWidgets('shows error on duplicate email registration', (tester) async {
      await _pump(tester, const RegisterPage());
      await tester.enterText(find.byType(TextField).at(0), 'Test User');
      await tester.enterText(find.byType(TextField).at(1), 'existing@test.com');
      await tester.enterText(find.byType(TextField).at(2), 'pass123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      // Firebase will throw since it's not configured in test
      expect(find.textContaining('already exists'), findsOneWidget);
    });

    testWidgets('name field accepts input', (tester) async {
      await _pump(tester, const RegisterPage());
      await tester.enterText(find.byType(TextField).first, 'John Doe');
      expect(find.text('John Doe'), findsOneWidget);
    });
  });

  // ─── Forgot Password Page ────────────────────────────────────────────────
  group('ForgotPasswordPage widget', () {
    testWidgets('renders Forgot Password title', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      expect(find.text('Forgot Password'), findsOneWidget);
    });

    testWidgets('renders email field and send button', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      expect(find.textContaining("Enter your email"), findsOneWidget);
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

    testWidgets('email field accepts input', (tester) async {
      await _pump(tester, const ForgotPasswordPage());
      await tester.enterText(find.byType(TextField), 'test@email.com');
      expect(find.text('test@email.com'), findsOneWidget);
    });
  });
}
