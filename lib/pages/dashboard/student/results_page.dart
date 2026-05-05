import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_session.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('student_assignments')
        .where('student_user_id', isEqualTo: UserSession.uid)
        .where('status', whereIn: ['submitted', 'completed'])
        .get();

    final results = await Future.wait(snap.docs.map((d) async {
      final sd = d.data();
      final assignDoc = await FirebaseFirestore.instance
          .collection('assignments')
          .doc(sd['assignment_id'] as String? ?? '')
          .get();
      return {...sd, if (assignDoc.exists) ...assignDoc.data()!, 'id': d.id};
    }));

    setState(() {
      _results = results.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Submitted Assignments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results yet.'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final earned = num.tryParse(r['earned_point']?.toString() ?? '') ?? 0;
                      final total = num.tryParse(r['total_marks']?.toString() ?? '') ?? 0;
                      final pct = total > 0 ? ((earned / total) * 100).round() : 0;
                      return ListTile(
                        title: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$earned / $total marks'),
                        trailing: Chip(
                          label: Text('$pct%'),
                          backgroundColor: pct >= 60 ? Colors.green : Colors.red,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
