import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'student';
  String _error = '';
  bool _waitingForVerify = false;

  Future<void> _handleSubmit() async {
    setState(() => _error = '');
    try {
      final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await res.user!.sendEmailVerification();
      await createUser(
        res.user!.uid,
        UserModel(
          uid: res.user!.uid,
          email: _emailCtrl.text.trim(),
          fullName: _nameCtrl.text.trim(),
          role: _role,
        ),
      );
      setState(() => _waitingForVerify = true);
    } catch (_) {
      setState(() => _error = 'This email already exists. Try logging in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingForVerify) {
      return Scaffold(
        body: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✉️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text('Check your email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("We've sent a verification link to ${_emailCtrl.text}. Please check your inbox.",
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Verified already? '),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Go to Login', style: TextStyle(color: Color(0xFF4e73df), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Join the SQL Practice Platform', style: TextStyle(color: Colors.black54), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                const Text('Full Name'),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 16),
                const Text('Email'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'name@example.com', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('I am registering as:'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                ),
                const SizedBox(height: 16),
                const Text('Password'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '••••••••', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4e73df),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Login', style: TextStyle(color: Color(0xFF4e73df), fontWeight: FontWeight.bold)),
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
