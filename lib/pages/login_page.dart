import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/user_service.dart';
import '../services/user_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _error = '';

  Future<void> _handleLogin() async {
    setState(() => _error = '');
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final user = cred.user!;
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        setState(() => _error = "Email not verified. We've sent a NEW verification link to your inbox.");
        return;
      }
      final userData = await getUser(user.uid);
      if (userData != null) {
        await markUserVerified(user.uid);
        UserSession.set(userData);
        if (mounted) context.go('/dashboard');
      }
    } catch (_) {
      setState(() => _error = 'Wrong email or password. Or user does not exist.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/logo.png', height: 72),
                const SizedBox(height: 12),
                const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Log in to your account', style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                const Text('Email'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'name@example.com', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Password'),
                    GestureDetector(
                      onTap: () => context.go('/forgot-password'),
                      child: const Text('Forgot?', style: TextStyle(color: Color(0xFF4e73df), fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4e73df),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Login', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text('Sign Up', style: TextStyle(color: Color(0xFF4e73df), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
