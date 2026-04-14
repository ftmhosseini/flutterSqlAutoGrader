import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 600,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About SQL Auto Grader',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'SQL Auto Grader is an advanced educational framework designed to automate the evaluation of relational database queries.',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Text('Our Mission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'We believe that database management is a core pillar of modern software engineering.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ContactItem(
                      label: 'General Inquiries',
                      email: 'info@sql-grader.com',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ContactItem(
                      label: 'Technical Support',
                      email: 'support@sql-grader.com',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final String label;
  final String email;
  const _ContactItem({required this.label, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        GestureDetector(
          // onTap: () => launchUrl(Uri.parse('mailto:$email')),
          child: Text(email, style: const TextStyle(color: Color(0xFF4e73df))),
        ),
      ],
    );
  }
}
