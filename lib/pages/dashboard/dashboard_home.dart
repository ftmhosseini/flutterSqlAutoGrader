import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_session.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final role = UserSession.role;
    return role == 'teacher' ? const _TeacherDashboard() : const _StudentDashboard();
  }
}

// ── Student Dashboard (Services grid) ─────────────────────────────────────────
class _StudentDashboard extends StatelessWidget {
  const _StudentDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _DashCard(label: 'Assignments', icon: Icons.book, color: Colors.blue, onTap: () => context.go('/dashboard/student/assignments')),
          _DashCard(label: 'Quizzes', icon: Icons.quiz, color: Colors.orange, onTap: () => context.go('/dashboard/student/quizzes')),
          _DashCard(label: 'Results', icon: Icons.bar_chart, color: Colors.green, onTap: () => context.go('/dashboard/student/results')),
          _DashCard(label: 'Cohorts', icon: Icons.group, color: Colors.purple, onTap: () => context.go('/dashboard/student/cohorts')),
          _DashCard(label: 'SQL Tutor', icon: Icons.smart_toy, color: const Color(0xFF4e73df), onTap: () => context.go('/dashboard/student/tutor')),
          _DashCard(label: 'Profile', icon: Icons.person, color: Colors.teal, onTap: () => context.go('/dashboard/profile')),
        ]),
      ]),
    );
  }
}

// ── Teacher Dashboard ──────────────────────────────────────────────────────────
class _TeacherDashboard extends StatefulWidget {
  const _TeacherDashboard();

  @override
  State<_TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<_TeacherDashboard> {
  int _tab = 0;
  bool _loading = true;
  int _studentsCount = 0;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _studentAssignments = [];
  List<Map<String, dynamic>> _needsGrading = [];
  Map<String, String> _userNames = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final assignSnap = await db.collection('assignments').where('owner_user_id', isEqualTo: UserSession.uid).get();
    final assignments = assignSnap.docs.map((d) => {...d.data(), 'assignment_id': d.id}).toList();
    List<Map<String, dynamic>> studentAssignments = [];
    if (assignments.isNotEmpty) {
      final ids = assignments.map((a) => a['assignment_id'] as String).toList();
      for (int i = 0; i < ids.length; i += 10) {
        final snap = await db.collection('student_assignments').where('assignment_id', whereIn: ids.sublist(i, (i+10).clamp(0, ids.length))).get();
        studentAssignments.addAll(snap.docs.map((d) => d.data()));
      }
    }
    final needsGrading = studentAssignments.where((s) => s['status'] == 'submitted').toList();
    final userNames = <String, String>{};
    for (final sid in needsGrading.map((s) => s['student_user_id'] as String).toSet()) {
      final snap = await db.collection('users').doc(sid).get();
      if (snap.exists) userNames[sid] = snap.data()?['fullName'] ?? snap.data()?['email'] ?? sid;
    }
    setState(() {
      _assignments = assignments; _studentAssignments = studentAssignments;
      _studentsCount = studentAssignments.map((s) => s['student_user_id']).toSet().length;
      _needsGrading = needsGrading; _userNames = userNames; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => _servicesTab();

  Widget _servicesTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _DashCard(label: 'Cohorts', icon: Icons.group, color: Colors.blue, onTap: () => context.go('/dashboard/teacher/cohorts')),
        _DashCard(label: 'Assignments', icon: Icons.book, color: Colors.green, onTap: () => context.go('/dashboard/teacher/assignments')),
        _DashCard(label: 'Datasets', icon: Icons.storage, color: Colors.orange, onTap: () => context.go('/dashboard/teacher/datasets')),
        _DashCard(label: 'Quizzes', icon: Icons.quiz, color: Colors.purple, onTap: () => context.go('/dashboard/teacher/quizzes')),
        _DashCard(label: 'Submissions', icon: Icons.check_circle, color: Colors.cyan, onTap: () => context.go('/dashboard/teacher/submissions')),
        _DashCard(label: 'Profile', icon: Icons.person, color: Colors.teal, onTap: () => context.go('/dashboard/profile')),
      ]),
    ]),
  );

  Widget _dashboardTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard(label: 'Students', value: '$_studentsCount', color: const Color(0xFF4e73df), onTap: () => context.go('/dashboard/teacher/cohorts')),
          const SizedBox(width: 12),
          _StatCard(label: 'Assignments', value: '${_assignments.length}', color: Colors.green, onTap: () => context.go('/dashboard/teacher/assignments')),
          const SizedBox(width: 12),
          _StatCard(label: 'Needs Grading', value: '${_needsGrading.length}', color: Colors.cyan, onTap: () => context.go('/dashboard/teacher/submissions')),
        ]),
        const SizedBox(height: 24),
        Text('Needs Grading (${_needsGrading.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_needsGrading.isEmpty)
          const Text('No assignments waiting for grading.', style: TextStyle(color: Colors.grey))
        else ..._needsGrading.map((sa) {
          final name = _userNames[sa['student_user_id']] ?? 'Unknown';
          final a = _assignments.firstWhere((a) => a['assignment_id'] == sa['assignment_id'], orElse: () => {});
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('$name — ${a['title'] ?? ''}', style: const TextStyle(fontSize: 14)),
              trailing: ElevatedButton(
                onPressed: () => context.go('/dashboard/teacher/submissions'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Grade', style: TextStyle(fontSize: 12)),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        const Text('Recent Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Card(child: Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
          children: [
            TableRow(decoration: BoxDecoration(color: Colors.grey.shade100), children: const [
              Padding(padding: EdgeInsets.all(10), child: Text('Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Padding(padding: EdgeInsets.all(10), child: Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ]),
            ..._assignments.map((a) {
              final all = _studentAssignments.where((sa) => sa['assignment_id'] == a['assignment_id']).toList();
              if (all.isEmpty) return null;
              final submitted = all.where((sa) => sa['status'] == 'submitted' || sa['status'] == 'completed').length;
              final pct = ((submitted / all.length) * 100).round();
              return TableRow(children: [
                Padding(padding: const EdgeInsets.all(10), child: Text(a['title'] ?? '', style: const TextStyle(fontSize: 13))),
                Padding(padding: const EdgeInsets.all(10), child: Text('$submitted/${all.length} ($pct%)', style: const TextStyle(fontSize: 13))),
              ]);
            }).whereType<TableRow>().toList(),
          ],
        )),
      ]),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: Border(left: BorderSide(color: color, width: 4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    ),
  ));
}

class _DashCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DashCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        border: Border(left: BorderSide(color: color, width: 4))),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Teacher Overview Page (Dashboard tab) ─────────────────────────────────────
class TeacherOverviewPage extends StatefulWidget {
  const TeacherOverviewPage({super.key});
  @override
  State<TeacherOverviewPage> createState() => _TeacherOverviewPageState();
}

class _TeacherOverviewPageState extends State<TeacherOverviewPage> {
  bool _loading = true;
  int _studentsCount = 0;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _studentAssignments = [];
  List<Map<String, dynamic>> _needsGrading = [];
  Map<String, String> _userNames = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final assignSnap = await db.collection('assignments').where('owner_user_id', isEqualTo: UserSession.uid).get();
    final assignments = assignSnap.docs.map((d) => {...d.data(), 'assignment_id': d.id}).toList();
    List<Map<String, dynamic>> studentAssignments = [];
    if (assignments.isNotEmpty) {
      final ids = assignments.map((a) => a['assignment_id'] as String).toList();
      for (int i = 0; i < ids.length; i += 10) {
        final snap = await db.collection('student_assignments').where('assignment_id', whereIn: ids.sublist(i, (i+10).clamp(0, ids.length))).get();
        studentAssignments.addAll(snap.docs.map((d) => d.data()));
      }
    }
    final needsGrading = studentAssignments.where((s) => s['status'] == 'submitted').toList();
    final userNames = <String, String>{};
    for (final sid in needsGrading.map((s) => s['student_user_id'] as String).toSet()) {
      final snap = await db.collection('users').doc(sid).get();
      if (snap.exists) userNames[sid] = snap.data()?['fullName'] ?? snap.data()?['email'] ?? sid;
    }
    setState(() {
      _assignments = assignments; _studentAssignments = studentAssignments;
      _studentsCount = studentAssignments.map((s) => s['student_user_id']).toSet().length;
      _needsGrading = needsGrading; _userNames = userNames; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard(label: 'Students', value: '$_studentsCount', color: const Color(0xFF4e73df), onTap: () => context.go('/dashboard/teacher/cohorts')),
          const SizedBox(width: 12),
          _StatCard(label: 'Assignments', value: '${_assignments.length}', color: Colors.green, onTap: () => context.go('/dashboard/teacher/assignments')),
          const SizedBox(width: 12),
          _StatCard(label: 'Needs Grading', value: '${_needsGrading.length}', color: Colors.cyan, onTap: () => context.go('/dashboard/teacher/submissions')),
        ]),
        const SizedBox(height: 24),
        Text('Needs Grading (${_needsGrading.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_needsGrading.isEmpty)
          const Text('No assignments waiting for grading.', style: TextStyle(color: Colors.grey))
        else ..._needsGrading.map((sa) {
          final name = _userNames[sa['student_user_id']] ?? 'Unknown';
          final a = _assignments.firstWhere((x) => x['assignment_id'] == sa['assignment_id'], orElse: () => {});
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('$name — ${a['title'] ?? ''}', style: const TextStyle(fontSize: 14)),
              trailing: ElevatedButton(
                onPressed: () => context.go('/dashboard/teacher/submissions'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Grade', style: TextStyle(fontSize: 12)),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        const Text('Recent Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Card(child: Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
          children: [
            TableRow(decoration: BoxDecoration(color: Colors.grey.shade100), children: const [
              Padding(padding: EdgeInsets.all(10), child: Text('Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Padding(padding: EdgeInsets.all(10), child: Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ]),
            ..._assignments.map((a) {
              final all = _studentAssignments.where((sa) => sa['assignment_id'] == a['assignment_id']).toList();
              if (all.isEmpty) return null;
              final submitted = all.where((sa) => sa['status'] == 'submitted' || sa['status'] == 'completed').length;
              final pct = ((submitted / all.length) * 100).round();
              final assignmentId = a['assignment_id'] as String;
              return TableRow(children: [
                InkWell(
                  onTap: () => context.go('/dashboard/teacher/submissions/$assignmentId'),
                  child: Padding(padding: const EdgeInsets.all(10), child: Text(a['title'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF4e73df), decoration: TextDecoration.underline))),
                ),
                InkWell(
                  onTap: () => context.go('/dashboard/teacher/submissions/$assignmentId'),
                  child: Padding(padding: const EdgeInsets.all(10), child: Text('$submitted/${all.length} ($pct%)', style: const TextStyle(fontSize: 13))),
                ),
              ]);
            }).whereType<TableRow>().toList(),
          ],
        )),
      ]),
    );
  }
}

// ── Student Overview Page ──────────────────────────────────────────────────────
class StudentOverviewPage extends StatefulWidget {
  const StudentOverviewPage({super.key});
  @override
  State<StudentOverviewPage> createState() => _StudentOverviewPageState();
}

class _StudentOverviewPageState extends State<StudentOverviewPage> {
  bool _loading = true;
  int _totalAssignments = 0;
  int _totalQuizzes = 0;
  int _earnedMarks = 0;
  int _totalMarks = 0;
  List<Map<String, dynamic>> _recentCompleted = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final uid = UserSession.uid;

    final assignSnap = await db.collection('student_assignments')
        .where('student_user_id', isEqualTo: uid).get();
    final all = assignSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

    final done = all.where((a) =>
        a['status'] == 'submitted' || a['status'] == 'completed').toList();

    // Join with assignments collection to get title and total_marks
    final enriched = await Future.wait(done.map((sa) async {
      final id = sa['assignment_id'] as String? ?? '';
      final doc = await db.collection('assignments').doc(id).get();
      if (!doc.exists) return sa;
      return {...sa, 'title': doc.data()?['title'], 'total_marks': doc.data()?['total_marks']};
    }));

    final quizSnap = await db.collection('student_quizzes')
        .where('student_user_id', isEqualTo: uid).get();

    final earned = enriched.fold<int>(0, (s, a) =>
        s + ((a['earned_point'] ?? 0) as num).toInt());
    final total = enriched.fold<int>(0, (s, a) =>
        s + ((a['total_marks'] ?? 0) as num).toInt());

    setState(() {
      _totalAssignments = all.length;
      _totalQuizzes = quizSnap.docs.length;
      _earnedMarks = earned;
      _totalMarks = total;
      _recentCompleted = enriched.take(5).toList();
      _loading = false;
    });
  }

  Color _barColor(int pct) {
    if (pct < 30) return Colors.red;
    if (pct < 60) return Colors.orange;
    if (pct < 90) return Colors.blue;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final marksLabel = _totalMarks > 0
        ? '$_earnedMarks / $_totalMarks (${(_earnedMarks / _totalMarks * 100).toStringAsFixed(1)}%)'
        : '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Student Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard(label: 'Assignments', value: '$_totalAssignments', color: const Color(0xFF4e73df), onTap: () => context.go('/dashboard/student/assignments')),
          const SizedBox(width: 12),
          _StatCard(label: 'Result (Marks)', value: marksLabel, color: Colors.green, onTap: () => context.go('/dashboard/student/results')),
          const SizedBox(width: 12),
          _StatCard(label: 'Quizzes', value: '$_totalQuizzes', color: Colors.orange, onTap: () => context.go('/dashboard/student/quizzes')),
        ]),
        const SizedBox(height: 24),
        const Text('Recent Assignment Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_recentCompleted.isEmpty)
          const Text('No completed assignments yet.', style: TextStyle(color: Colors.grey))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: _recentCompleted.map((item) {
                final earned = ((item['earned_point'] ?? 0) as num).toInt();
                final total = ((item['total_marks'] ?? 0) as num).toInt();
                final pct = total > 0 ? (earned / total * 100).round() : 0;
                final assignmentId = item['assignment_id'] as String? ?? '';
                return GestureDetector(
                  onTap: () => context.go('/dashboard/student/results/$assignmentId'),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(item['title'] ?? 'Assignment', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Text(pct == 100 ? '$earned/$total — Complete!' : '$earned/$total ($pct%)', style: const TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(_barColor(pct)),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList()),
            ),
          ),
      ]),
    );
  }
}
