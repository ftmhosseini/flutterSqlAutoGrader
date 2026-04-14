import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/user_session.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _NavBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
              color: const Color(0xFF1a2b4b),
              child: Column(
                children: [
                  const Text('SQL Practice Platform',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  const Text('Learn SQL interactively in your browser using real datasets.',
                      style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => UserSession.role != null
                        ? context.go('/dashboard')
                        : context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4e73df),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Start Practicing', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
            // Features section
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text('Explore Features',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: const [
                      _FeatureCard(icon: '📄', title: 'Real Datasets',
                          desc: 'Instant access to datasets: Employees, Customers, Movies.'),
                      _FeatureCard(icon: '⌨️', title: 'Instant Query Execution',
                          desc: 'Real Database deploys right in your browser.'),
                      _FeatureCard(icon: '🤖', title: 'Automatic Grading',
                          desc: 'Get instant feedback on your SQL queries.'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // final user = UserSession.get();
    return AppBar(
      backgroundColor: const Color(0xFF1a2b4b),
      title: GestureDetector(
        onTap: () => context.go('/'),
        child: const Text('🌐 SQL Practice Platform',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      // actions: [
      //   TextButton(onPressed: () => context.go('/'), child: const Text('Home', style: TextStyle(color: Colors.white))),
      //   TextButton(onPressed: () => context.go('/about'), child: const Text('About', style: TextStyle(color: Colors.white))),
      //   if (user != null)
      //     TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Dashboard', style: TextStyle(color: Colors.white))),
      //   if (user == null)
      //     TextButton(
      //       onPressed: () => context.go('/login'),
      //       child: const Text('Login', style: TextStyle(color: Colors.white)),
      //     )
      //   else
      //     Padding(
      //       padding: const EdgeInsets.only(right: 12),
      //       child: CircleAvatar(
      //         backgroundColor: const Color(0xFF4e73df),
      //         child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
      //             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      //       ),
      //     ),
      // ],
    );
  }
}
