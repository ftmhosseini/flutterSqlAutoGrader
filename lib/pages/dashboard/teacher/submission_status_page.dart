import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_session.dart';

class SubmissionStatusPage extends StatefulWidget {
  final String? assignmentId;
  const SubmissionStatusPage({super.key, this.assignmentId});

  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> {
  List<Map<String, dynamic>> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final db = FirebaseFirestore.instance;

    final assignSnap = await db.collection('assignments')
        .where('owner_user_id', isEqualTo: UserSession.uid).get();
    final assignments = assignSnap.docs.map((d) => {...d.data() as Map, 'assignment_id': d.id}).toList();

    // 2. For each assignment, get student_assignments rows — skip unpublished (no rows)
    final enriched = (await Future.wait(assignments.map((a) async {
      final saSnap = await db.collection('student_assignments')
          .where('assignment_id', isEqualTo: a['assignment_id']).get();
      if (saSnap.docs.isEmpty) return null; // not published
      final students = saSnap.docs.map((d) => {...d.data() as Map, 'doc_id': d.id}).toList();

      // 3. Fetch student names
      final uids = students.map((s) => s['student_user_id'] as String).toSet();
      final names = <String, String>{};
      await Future.wait(uids.map((uid) async {
        final u = await db.collection('users').doc(uid).get();
        names[uid] = u.data()?['fullName'] ?? u.data()?['email'] ?? uid;
      }));

      return <String, dynamic>{...a, 'students': students, 'studentNames': names};
    }))).whereType<Map<String, dynamic>>().toList();

    setState(() {
      _assignments = enriched;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Submissions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_assignments.isEmpty)
          const Center(child: Text('No published assignments found.', style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _assignments.length,
              itemBuilder: (_, i) => _AssignmentCard(
                assignment: _assignments[i],
                autoExpand: _assignments[i]['assignment_id'] == widget.assignmentId,
                onScoreUpdated: _fetch,
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Assignment Card ────────────────────────────────────────────────────────────
class _AssignmentCard extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final bool autoExpand;
  final VoidCallback onScoreUpdated;
  const _AssignmentCard({required this.assignment, required this.onScoreUpdated, this.autoExpand = false});

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.autoExpand;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final students = (a['students'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final names = Map<String, String>.from(a['studentNames'] ?? {});
    final submitted = students.where((s) => s['status'] == 'submitted' || s['status'] == 'completed').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFF4e73df).withOpacity(0.3)),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4e73df))),
                const SizedBox(height: 4),
                Text('$submitted / ${students.length} submitted', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            ]),
          ),
        ),

        // Student rows
        if (_expanded) ...[
          const Divider(height: 1),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No students assigned.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...students.map((s) => _StudentRow(
              studentAssignment: s,
              studentName: names[s['student_user_id']] ?? s['student_user_id'] ?? '',
              assignment: a,
              onScoreUpdated: widget.onScoreUpdated,
            )),
        ],
      ]),
    );
  }
}

// ── Student Row ────────────────────────────────────────────────────────────────
class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> studentAssignment;
  final String studentName;
  final Map<String, dynamic> assignment;
  final VoidCallback onScoreUpdated;

  const _StudentRow({
    required this.studentAssignment,
    required this.studentName,
    required this.assignment,
    required this.onScoreUpdated,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted': return Colors.orange;
      case 'completed': return Colors.green;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = studentAssignment['status'] ?? 'assigned';
    final earned = studentAssignment['earned_point'];
    final total = assignment['total_marks'];
    final isDone = status == 'submitted' || status == 'completed';

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: ListTile(
        dense: true,
        title: Text(studentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: isDone && earned != null
            ? Text('Score: $earned / ${total ?? '?'}', style: const TextStyle(fontSize: 12))
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _statusColor(status)),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.bold)),
          ),
          if (isDone) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4e73df)),
              tooltip: 'View attempts',
              onPressed: () => _viewAttempts(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
              tooltip: 'Edit score',
              onPressed: () => _editScore(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _viewAttempts(BuildContext context) async {
    final questions = List<Map<String, dynamic>>.from(assignment['questions'] ?? []);
    final questionIds = questions.map((q) => q['question_id'] as String).toSet();

    final snap = await FirebaseFirestore.instance
        .collection('question_attempts')
        .where('student_user_id', isEqualTo: studentAssignment['student_user_id'])
        .get();

    // Keep only attempts for this assignment's questions, pick best per question
    final attempts = <String, Map<String, dynamic>>{};
    for (final d in snap.docs) {
      final data = d.data();
      final qid = data['question_id'] as String? ?? '';
      if (!questionIds.contains(qid)) continue;
      final existing = attempts[qid];
      if (existing == null ||
          (data['is_correct'] == true && existing['is_correct'] != true) ||
          (data['is_correct'] == existing['is_correct'] &&
              (data['submitted_on']?.toString() ?? '').compareTo(existing['submitted_on']?.toString() ?? '') > 0)) {
        attempts[qid] = data;
      }
    }
    
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$studentName — Attempts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: questions.length,
                itemBuilder: (_, i) {
                  final q = Map<String, dynamic>.from(questions[i]);
                  final qid = q['question_id'] as String? ?? '$i';
                  final attempt = attempts[qid];
                  final correct = attempt?['is_correct'] == true;
                  final mark = (q['mark'] ?? 0) as num;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: attempt != null ? (correct ? Colors.green.shade50 : Colors.red.shade50) : Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('Q${i + 1}: ${q['question'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          if (attempt != null)
                            Icon(correct ? Icons.check_circle : Icons.cancel, color: correct ? Colors.green : Colors.red, size: 18),
                        ]),
                        if (attempt != null) ...[
                          const SizedBox(height: 8),
                          const Text('Student answer:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200)),
                            child: Text(attempt['submitted_sql'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ),
                          const SizedBox(height: 4),
                          Text('Points: ${correct ? mark : 0} / $mark', style: const TextStyle(fontSize: 12)),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('Not attempted', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _editScore(BuildContext context) async {
    final earned = studentAssignment['earned_point'];
    final total = assignment['total_marks'];
    final ctrl = TextEditingController(text: earned?.toString() ?? '');

    // Fetch attempts to show what the student got per question
    final snap = await FirebaseFirestore.instance
        .collection('question_attempts')
        .where('student_user_id', isEqualTo: studentAssignment['student_user_id'])
        .get();
    final questions = List<Map<String, dynamic>>.from(assignment['questions'] ?? []);
    final questionIds = questions.map((q) => q['question_id'] as String).toSet();
    final attempts = <String, Map<String, dynamic>>{};
    for (final d in snap.docs) {
      final data = d.data();
      final qid = data['question_id'] as String? ?? '';
      if (!questionIds.contains(qid)) continue;
      final existing = attempts[qid];
      if (existing == null ||
          (data['is_correct'] == true && existing['is_correct'] != true) ||
          (data['is_correct'] == existing['is_correct'] &&
              (data['submitted_on']?.toString() ?? '').compareTo(existing['submitted_on']?.toString() ?? '') > 0)) {
        attempts[qid] = data;
      }
    }

    if (!context.mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Score — $studentName'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Assignment: ${assignment['title'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            if (questions.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: questions.length,
                  itemBuilder: (_, i) {
                    final q = questions[i];
                    final qid = q['question_id'] as String? ?? '$i';
                    final attempt = attempts[qid];
                    final correct = attempt?['is_correct'] == true;
                    final mark = (q['mark'] ?? 0) as num;
                    final questionText = q['question'] as String? ?? '';
                    final preview = questionText.length > 40 ? '${questionText.substring(0, 40)}…' : questionText;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(
                          attempt == null ? Icons.remove_circle_outline : correct ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: attempt == null ? Colors.grey : correct ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Q${i + 1}: $preview', style: const TextStyle(fontSize: 12))),
                        Text(
                          attempt == null ? '— / $mark' : '${correct ? mark : 0} / $mark',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: attempt == null ? Colors.grey : correct ? Colors.green : Colors.red),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Override Score',
                suffixText: '/ ${total ?? '?'}',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    final newScore = num.tryParse(result);
    if (newScore == null) return;

    await FirebaseFirestore.instance
        .collection('student_assignments')
        .doc(studentAssignment['doc_id'])
        .update({'earned_point': newScore});

    onScoreUpdated();
  }
}
