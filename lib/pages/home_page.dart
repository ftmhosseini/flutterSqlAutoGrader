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
        child: Column(children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            color: const Color(0xFF1a2b4b),
            child: Column(children: [
              const Text('SQL Practice Platform',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text('Learn SQL interactively using real datasets. Write queries, get instant feedback.',
                  style: TextStyle(fontSize: 18, color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => UserSession.role != null ? context.go('/dashboard') : context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4e73df),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Start Practicing', style: TextStyle(fontSize: 16)),
              ),
            ]),
          ),

          // Core features
          _Section(
            title: 'Explore Features',
            color: Colors.white,
            cards: const [
              _FeatureCard(icon: '📄', title: 'Real Datasets', desc: 'Instant access to datasets: Employees, Customers, Movies.'),
              _FeatureCard(icon: '⌨️', title: 'Instant Query Execution', desc: 'SQLite runs right on your device — no server needed.'),
              _FeatureCard(icon: '🤖', title: 'Automatic Grading', desc: 'Get instant correct/incorrect feedback on your SQL queries.'),
            ],
          ),

          // Teacher features
          // _Section(
          //   title: 'For Teachers',
          //   color: const Color(0xFFF8F9FC),
          //   cards: const [
          //     _FeatureCard(icon: '🗂️', title: 'Dataset Manager', desc: 'Create custom datasets with tables and seed data for your students.'),
          //     _FeatureCard(icon: '📝', title: 'Assignments & Quizzes', desc: 'Build multi-question assignments with AI-generated SQL questions. Publish when ready.'),
          //     _FeatureCard(icon: '👥', title: 'Cohort Management', desc: 'Organise students into cohorts and distribute assignments with a join code.'),
          //     _FeatureCard(icon: '📊', title: 'Submission Status', desc: 'Track every student\'s progress and override scores when needed.'),
          //   ],
          // ),

          // // Student features
          // _Section(
          //   title: 'For Students',
          //   color: Colors.white,
          //   cards: const [
          //     _FeatureCard(icon: '💻', title: 'SQL Editor', desc: 'Write and run SQL queries directly on your device — no setup required.'),
          //     _FeatureCard(icon: '✅', title: 'Instant Feedback', desc: 'Your query is graded automatically against the expected result set.'),
          //     _FeatureCard(icon: '🎓', title: 'SQL Tutor', desc: 'Structured lessons with a live sandbox and an AI chat assistant.'),
          //     _FeatureCard(icon: '🏆', title: 'Results & Progress', desc: 'View your scores across all assignments and track your improvement.'),
          //   ],
          // ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF1a2b4b),
            child: const Text('© 2026 SQL Practice Platform',
                style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<_FeatureCard> cards;
  const _Section({required this.title, required this.color, required this.cards});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color,
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(children: [
      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 32),
      Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: cards),
    ]),
  );
}

class _FeatureCard extends StatelessWidget {
  final String icon, title, desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
    ),
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 36)),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
    ]),
  );
}

class _NavBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final loggedIn = UserSession.role != null;
    return AppBar(
      backgroundColor: const Color(0xFF1a2b4b),
      title: GestureDetector(
        onTap: () => context.go('/'),
        child: const Text('🌐 SQL Practice Platform',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      actions: [
        // TextButton(onPressed: () => context.go('/'), child: const Text('Home', style: TextStyle(color: Colors.white))),
        // TextButton(onPressed: () => context.go('/about'), child: const Text('About', style: TextStyle(color: Colors.white))),
        // if (loggedIn) ...[
        //   TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Dashboard', style: TextStyle(color: Colors.white))),
        //   Padding(
        //     padding: const EdgeInsets.only(right: 12),
        //     child: CircleAvatar(
        //       backgroundColor: const Color(0xFF4e73df),
        //       radius: 16,
        //       child: Text(
        //         (UserSession.role?[0] ?? 'U').toUpperCase(),
        //         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        //       ),
        //     ),
        //   ),
        // ] else
        //   Padding(
        //     padding: const EdgeInsets.only(right: 8),
        //     child: TextButton(
        //       onPressed: () => context.go('/login'),
        //       child: const Text('Login', style: TextStyle(color: Colors.white)),
        //     ),
        //   ),
      ],
    );
  }
}
