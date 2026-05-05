import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../services/user_session.dart';

class CohortManagerPage extends StatefulWidget {
  const CohortManagerPage({super.key});

  @override
  State<CohortManagerPage> createState() => _CohortManagerPageState();
}

class _CohortManagerPageState extends State<CohortManagerPage> {
  List<Map<String, dynamic>> _cohorts = [];
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final cohortSnap = await FirebaseFirestore.instance
        .collection('cohorts')
        .where('owner_user_id', isEqualTo: UserSession.uid)
        .get();
    final studentSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    setState(() {
      _cohorts = cohortSnap.docs.map((d) => {...d.data(), 'cohort_id': d.id}).toList();
      _students = studentSnap.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
      _loading = false;
    });
  }

  Future<void> _createCohort() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    String code;
    DocumentSnapshot snap;
    do {
      code = List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
      snap = await FirebaseFirestore.instance.collection('cohorts').doc(code).get();
    } while (snap.exists);

    await FirebaseFirestore.instance.collection('cohorts').doc(code).set({
      'name': _nameCtrl.text.trim(),
      'cohort_id': code,
      'owner_user_id': UserSession.uid,
      'created_on': FieldValue.serverTimestamp(),
    });
    setState(() {
      _cohorts.add({'cohort_id': code, 'name': _nameCtrl.text.trim()});
      _nameCtrl.clear();
      _creating = false;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cohorts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => setState(() => _creating = !_creating),
                icon: Icon(_creating ? Icons.close : Icons.add),
                label: Text(_creating ? 'Cancel' : 'New Cohort'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
          if (_creating) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Cohort Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createCohort,
              child: const Text('Create Cohort'),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _cohorts.length,
              itemBuilder: (_, i) {
                final c = _cohorts[i];
                final memberUids = List<String>.from(c['student_uids'] ?? []);
                final members = _students.where((s) => memberUids.contains(s['uid'])).toList();
                final isExpanded = _expandedId == c['cohort_id'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code: ${c['cohort_id']}  •  ${memberUids.length} students enrolled'),
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (v) => setState(() => _expandedId = v ? c['cohort_id'] : null),
                    children: members.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text('No students have joined yet.'))]
                        : members.map((s) => ListTile(
                              title: Text(s['fullName'] ?? ''),
                              subtitle: Text(s['email'] ?? ''),
                              leading: const Icon(Icons.person),
                            )).toList(),
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
