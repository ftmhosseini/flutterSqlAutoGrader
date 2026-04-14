import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_session.dart';

class SubmissionStatusPage extends StatefulWidget {
  final String? assignmentId;
  const SubmissionStatusPage({super.key, this.assignmentId});

  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetch();
  }

  Future<void> _fetch() async {
    var query = FirebaseFirestore.instance
        .collection('student_assignments')
        .where('owner_user_id', isEqualTo: UserSession.uid);

    if (widget.assignmentId != null) {
      query = query.where('assignment_id', isEqualTo: widget.assignmentId);
    }

    final assignSnap = await query.get();

    final quizSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .where('owner_user_id', isEqualTo: UserSession.uid)
        .get();

    setState(() {
      _assignments = assignSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _quizzes = quizSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final isFiltered = widget.assignmentId != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFiltered)
            Text('Submissions for Assignment', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
          else
            const Text('Submission Status', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (isFiltered)
            Expanded(child: _SubmissionList(items: _assignments))
          else ...[
            TabBar(
              controller: _tabCtrl,
              tabs: const [Tab(text: 'Assignments'), Tab(text: 'Quizzes')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SubmissionList(items: _assignments),
                  _SubmissionList(items: _quizzes),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmissionList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _SubmissionList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('No submissions found.'));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = items[i];
        final status = item['status'] ?? 'assigned';
        final statusColor = status == 'submitted'
            ? Colors.orange
            : status == 'completed'
                ? Colors.green
                : Colors.blue;
        return ListTile(
          title: Text(item['title'] ?? item['id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Student: ${item['student_user_id'] ?? 'N/A'}'),
          trailing: Chip(
            label: Text(status),
            backgroundColor: statusColor,
            labelStyle: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}
