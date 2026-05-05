import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

final _db = FirebaseFirestore.instance;

Future<UserModel?> getUser(String uid) async {
  final snap = await _db.collection('users').doc(uid).get();
  if (!snap.exists) return null;
  return UserModel.fromMap(snap.data()!);
}

Future<void> createUser(String uid, UserModel user) async {
  await _db.collection('users').doc(uid).set(user.toMap());
}

Future<void> markUserVerified(String uid) async {
  await _db.collection('users').doc(uid).update({'emailVerified': true});
}

Future<List<UserModel>> getAllUsers() async {
  final snap = await _db.collection('users').get();
  return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
}
