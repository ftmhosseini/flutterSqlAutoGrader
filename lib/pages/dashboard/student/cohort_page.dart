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
          // Empty state with SIM77 suggestion
          if (_cohorts.isEmpty)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("You haven't joined any cohorts yet.",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Use code '),
                    GestureDetector(
                      onTap: () {
                        _codeCtrl.text = 'SIM77';
                        _join('SIM77');
                      },
                      child: const Text('SIM77',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              decoration: TextDecoration.underline)),
                    ),
                    const Text(' to join the Test Cohort.'),
                  ],
                ),
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
