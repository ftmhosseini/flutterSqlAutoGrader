import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_session.dart';

class StudentCohortPage extends StatefulWidget {
  const StudentCohortPage({super.key});

  @override
  State<StudentCohortPage> createState() => _StudentCohortPageState();
}

class _StudentCohortPageState extends State<StudentCohortPage> {
  List<Map<String, dynamic>> _cohorts = [];
  bool _loading = true;
  final _codeCtrl = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance
        .collection('cohorts')
        .where('student_uids', arrayContains: UserSession.uid)
        .get();
    setState(() {
      _cohorts = snap.docs.map((d) => {...d.data(), 'cohort_id': d.id}).toList();
      _loading = false;
    });
  }

  Future<void> _join(String code) async {
    setState(() => _error = '');
    final snap = await FirebaseFirestore.instance
        .collection('cohorts')
        .where(FieldPath.documentId, isEqualTo: code.trim())
        .get();
    if (snap.docs.isEmpty) {
      setState(() => _error = 'Cohort not found. Check the code and try again.');
      return;
    }
    final doc = snap.docs.first;
    final uids = List<String>.from(doc.data()['student_uids'] ?? []);
    if (uids.contains(UserSession.uid)) {
      setState(() => _error = 'You are already a member of this cohort.');
      return;
    }
    uids.add(UserSession.uid!);
    await doc.reference.update({'student_uids': uids});
    _codeCtrl.clear();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Cohorts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Join form
          TextField(
            controller: _codeCtrl,
            decoration: InputDecoration(
              labelText: 'Enter cohort code',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.login),
                onPressed: () => _join(_codeCtrl.text),
              ),
            ),
            onSubmitted: _join,
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          // Empty state with Q7ZOB suggestion
          if (_cohorts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(children: [
                  const Text("You haven't joined any cohorts yet.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Use code Q7ZOB to join the SQL test', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _codeCtrl.text = 'Q7ZOB'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                    child: const Text('Join Test Cohort'),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _cohorts.length,
                itemBuilder: (_, i) {
                  final c = _cohorts[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.group, color: Color(0xFF4e73df)),
                      title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Code: ${c['cohort_id']}'),
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
