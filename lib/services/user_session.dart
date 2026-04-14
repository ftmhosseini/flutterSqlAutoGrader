import '../models/user_model.dart';

class UserSession {
  static UserModel? _user;

  static void set(UserModel? user) => _user = user;
  static UserModel? get() => _user;
  static void clear() => _user = null;

  static String? get uid => _user?.uid;
  static String? get email => _user?.email;
  static String? get fullName => _user?.fullName;
  static String? get role => _user?.role;
}
