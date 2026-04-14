import 'package:flutter/material.dart';
import '../../services/user_session.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = UserSession.get();
    final initial = (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U';
    final joinDate = user?.createdAt?.toDate().toLocal().toString().split(' ')[0] ?? 'Recently';

    return Center(
      child: Container(
        width: 400,
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF4e73df),
              child: Text(initial, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(user?.fullName ?? 'User Name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text((user?.role ?? '').toUpperCase(), style: const TextStyle(color: Colors.black54, letterSpacing: 1.2)),
            const SizedBox(height: 24),
            const Divider(),
            _InfoRow(label: 'Email Address:', value: ''),
            _InfoRow(label: '', value: user?.email ?? ''),
            const SizedBox(height: 12),
            _InfoRow(label: 'Member Since:', value: joinDate),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
