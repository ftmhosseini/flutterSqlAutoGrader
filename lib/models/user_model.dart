import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final Timestamp? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) => UserModel(
        uid: data['uid'] ?? '',
        email: data['email'] ?? '',
        fullName: data['fullName'] ?? '',
        role: data['role'] ?? 'student',
        createdAt: data['createdAt'],
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'role': role,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };
}
