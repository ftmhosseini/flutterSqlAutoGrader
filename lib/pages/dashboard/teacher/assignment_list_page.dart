import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_session.dart';
import 'assignment_form_page.dart';

class AssignmentListPage extends StatefulWidget {
  const AssignmentListPage({super.key});

  @override
  State<AssignmentListPage> createState() => _AssignmentListPageState();
}

class _AssignmentListPageState extends State<AssignmentListPage> {
  List<Map<String, dynamic>> _assignments = [];
  Map<String, String> _cohortNames = {};
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (UserSession.uid == null) { setState(() => _loading = false); return; }
    final snap = await FirebaseFirestore.instance
        .collection('assignments')
        .where('owner_user_id', isEqualTo: UserSession.uid)
        .get();
    final cohortSnap = await FirebaseFirestore.instance.collection('cohorts').get();

    // Check which assignments are published
    final assignments = snap.docs.map((d) => {...d.data(), 'assignment_id': d.id}).toList();
    final publishedChecks = await Future.wait(assignments.map((a) async {
      final s = await FirebaseFirestore.instance.collection('student_assignments')
          .where('assignment_id', isEqualTo: a['assignment_id']).limit(1).get();
      return s.docs.isNotEmpty;
    }));

    setState(() {
      for (int i = 0; i < assignments.length; i++) {
        assignments[i]['published'] = publishedChecks[i];
      }
      _assignments = assignments..sort((a, b) => (a['due_date'] ?? '').compareTo(b['due_date'] ?? ''));
      _cohortNames = {for (final d in cohortSnap.docs) d.id: (d.data()['name'] ?? d.id) as String};
      _loading = false;
    });
  }

  Future<void> _publish(Map<String, dynamic> a) async {
    final cohortId = a['student_class'] as String?;
    if (cohortId == null || cohortId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No cohort assigned to this assignment.')));
      return;
    }
    final cohortSnap = await FirebaseFirestore.instance.collection('cohorts').where('cohort_id', isEqualTo: cohortId).get();
    if (cohortSnap.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cohort not found.'))); return; }
    final studentUids = List<String>.from(cohortSnap.docs.first.data()['student_uids'] ?? []);
    if (studentUids.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students in this cohort.'))); return; }

    final assignmentId = a['assignment_id'] as String;
    final db = FirebaseFirestore.instance;
    for (final uid in studentUids) {
      final existing = await db.collection('student_assignments').where('assignment_id', isEqualTo: assignmentId).where('student_user_id', isEqualTo: uid).get();
      if (existing.docs.isNotEmpty) continue;
      final ref = db.collection('student_assignments').doc();
      await ref.set({'student_assignment_id': ref.id, 'assignment_id': assignmentId, 'student_user_id': uid, 'status': 'assigned', 'assigned_on': FieldValue.serverTimestamp(), 'due_on': a['due_date']});
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment published!')));
  }

  Future<void> _deleteAssignment(String id) async {
    final confirm = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Delete Assignment'),
      content: const Text('Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('assignments').doc(id).delete();
    if (mounted) setState(() => _assignments.removeWhere((a) => a['assignment_id'] == id));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Assignments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AssignmentFormPage(onDone: () { Navigator.pop(context); _fetch(); }),
            )),
            icon: const Icon(Icons.add),
            label: const Text('New Assignment'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
          ),
        ]),

        const SizedBox(height: 16),

        if (_assignments.isEmpty)
          const Center(child: Text('No active assignments found.', style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _assignments.length,
              itemBuilder: (_, i) {
                final a = _assignments[i];
                final id = a['assignment_id'] as String;
                final isExpanded = _expandedId == id;
                final cohortName = _cohortNames[a['student_class']] ?? a['student_class'] ?? '';
                final questions = List<Map<String, dynamic>>.from(a['questions'] ?? []);
                final due = a['due_date'] ?? a['dueDate'] ?? '—';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFF4e73df).withOpacity(0.4), width: 1),
                  ),
                  child: Column(children: [
                    // Header
                    InkWell(
                      onTap: () => setState(() => _expandedId = isExpanded ? null : id),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4e73df), fontSize: 15)),
                            if (cohortName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                                child: Text(cohortName, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              ),
                            ],
                          ])),
                          if (a['reminder_interval'] == true)
                            ElevatedButton(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder sent!'))),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Text('🔔 Remind', style: TextStyle(fontSize: 12)),
                            ),
                          const SizedBox(width: 4),
                          if (a['published'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(6)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 14, color: Colors.green), SizedBox(width: 4), Text('Published', style: TextStyle(fontSize: 12, color: Colors.green))]),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _publish(a).then((_) => _fetch()),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Text('Publish', style: TextStyle(fontSize: 12)),
                            ),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteAssignment(id)),
                          Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                        ]),
                      ),
                    ),

                    // Expanded body
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Due: $due', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 12),
                          if ((a['description'] as String? ?? '').isNotEmpty) ...[
                            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(6)),
                              child: Text(a['description'] as String, style: const TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Questions
                          if (questions.isNotEmpty) ...[
                            const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            ...questions.asMap().entries.map((e) {
                              final qi = e.key;
                              final q = e.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Colors.grey.shade50,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Q${qi + 1}: ${q['questionText'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                                      child: Text(q['answer'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF4e73df))),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(spacing: 6, children: [
                                      _badge('Points: ${q['mark'] ?? '-'}'),
                                      if (q['orderMatters'] == true) _badge('Order Matters'),
                                      if (q['aliasStrict'] == true) _badge('Alias Strict'),
                                    ]),
                                  ]),
                                ),
                              );
                            }),
                          ] else
                            const Text('No questions added yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(fontSize: 11)),
  );
}
