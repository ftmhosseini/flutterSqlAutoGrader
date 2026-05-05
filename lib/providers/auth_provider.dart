import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/user_session.dart';

class AuthProvider extends ChangeNotifier {
  String? _role;
  bool _loading = true;

  String? get role => _role;
  bool get loading => _loading;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.emailVerified) {
        if (UserSession.role == null) {
          final userData = await getUser(user.uid);
          if (userData != null) UserSession.set(userData);
        }
        _role = UserSession.role;
      } else {
        UserSession.clear();
        _role = null;
      }
      _loading = false;
      notifyListeners();
    });
  }
}
