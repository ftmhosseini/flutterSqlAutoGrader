import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../services/user_session.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _submitted = [];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _fetchData() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('student_assignments')
        .where('student_user_id', isEqualTo: UserSession.uid).get();

    final studentDocs = snap.docs.map((d) => d.data()).toList();
    if (studentDocs.isEmpty) { if (mounted) setState(() => _loading = false); return; }

    final results = await Future.wait(studentDocs.map((sd) async {
      final id = sd['assignment_id'] as String? ?? '';
      final byId = await db.collection('assignments').doc(id).get();
      if (byId.exists) return {...byId.data()!, 'assignment_id': id, 'status': sd['status'], 'earned_point': sd['earned_point']};
      final q = await db.collection('assignments').where('assignment_id', isEqualTo: id).limit(1).get();
      if (q.docs.isEmpty) return null;
      return {...q.docs.first.data(), 'status': sd['status'], 'earned_point': sd['earned_point']};
    }));

    final all = results.whereType<Map<String, dynamic>>().toList();
    if (!mounted) return;
    setState(() {
      _pending = all.where((a) => a['status'] == 'assigned').toList()
        ..sort((a, b) => (a['due_date'] ?? '').compareTo(b['due_date'] ?? ''));
      _submitted = all.where((a) => a['status'] == 'submitted' || a['status'] == 'completed').toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Assignments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF4e73df),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4e73df),
          tabs: const [Tab(text: 'Active'), Tab(text: 'Submitted')],
        ),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _buildList(_pending, submitted: false),
          _buildList(_submitted, submitted: true),
        ])),
      ]),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool submitted}) {
    if (items.isEmpty) return Center(child: Text(submitted ? 'No submitted assignments.' : 'No active assignments.'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        final id = a['assignment_id'] as String;
        final due = a['due_date'] ?? a['dueDate'] ?? '—';
        final isExpanded = _expandedId == id;
        final isOverdue = due != '—' && DateTime.tryParse(due)?.isBefore(DateTime.now()) == true;
        final questions = List<Map<String, dynamic>>.from(a['questions'] ?? []);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: (isOverdue ? Colors.orange : const Color(0xFF4e73df)).withOpacity(0.4)),
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
                    Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4e73df))),
                    const SizedBox(height: 4),
                    Text('Due: $due', style: TextStyle(fontSize: 12, color: isOverdue ? Colors.orange : Colors.grey)),
                  ])),
                  if (!submitted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isOverdue ? Colors.orange : const Color(0xFF4e73df), borderRadius: BorderRadius.circular(10)),
                      child: Text(isOverdue ? 'Overdue' : 'Assigned', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    )
                  else
                    Text('${a['earned_point'] ?? 0} / ${a['total_marks'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ]),
              ),
            ),

            // Expanded detail
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if ((a['description'] as String? ?? '').isNotEmpty) ...[
                    Text(a['description'] as String, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 12),
                  ],
                  Text('${questions.length} question${questions.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (!submitted)
                    ElevatedButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                        builder: (_) => _QuestionListPage(assignment: a),
                      )).then((_) => _fetchData()),
                      style: ElevatedButton.styleFrom(backgroundColor: isOverdue ? Colors.red : const Color(0xFF4e73df), foregroundColor: Colors.white),
                      child: Text(isOverdue ? 'Mark Finished' : 'Continue →'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                        builder: (_) => _QuestionListPage(assignment: a, readOnly: true),
                      )),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                      child: const Text('View Submissions'),
                    ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

// ── Question List Page ─────────────────────────────────────────────────────────
class _QuestionListPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final bool readOnly;
  const _QuestionListPage({required this.assignment, this.readOnly = false});

  @override
  State<_QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<_QuestionListPage> {
  Map<String, Map<String, dynamic>> _submissions = {}; // question_id -> attempt
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    if (widget.readOnly) _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final snap = await FirebaseFirestore.instance
        .collection('question_attempts')
        .where('assignment_id', isEqualTo: widget.assignment['assignment_id'])
        .where('student_user_id', isEqualTo: UserSession.uid)
        .get();
    setState(() {
      _submissions = {for (final d in snap.docs) d.data()['question_id'] as String: d.data()};
    });
  }

  Future<void> _markFinished(BuildContext context) async {
    final snap = await FirebaseFirestore.instance
        .collection('student_assignments')
        .where('assignment_id', isEqualTo: widget.assignment['assignment_id'])
        .where('student_user_id', isEqualTo: UserSession.uid)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'status': 'completed', 'submissionDate': DateTime.now().toIso8601String().substring(0, 10)});
    }
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = List<Map<String, dynamic>>.from(widget.assignment['questions'] ?? []);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment['title'] ?? 'Questions'),
        backgroundColor: const Color(0xFF4e73df),
        foregroundColor: Colors.white,
        actions: widget.readOnly ? null : [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () => _markFinished(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Mark Finished'),
            ),
          ),
        ],
      ),
      body: questions.isEmpty
          ? const Center(child: Text('No questions found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (_, i) {
                final q = questions[i];
                final qid = q['question_id'] as String? ?? '$i';
                final sub = _submissions[qid];
                final isExpanded = _expandedId == qid;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: sub != null ? (sub['is_correct'] == true ? Colors.green : Colors.orange) : const Color(0xFF4e73df),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      title: Text(q['question'] ?? '', style: const TextStyle(fontSize: 14)),
                      subtitle: Wrap(spacing: 6, children: [
                        if (q['mark'] != null) _chip('${q['mark']} pts'),
                        if (q['orderMatters'] == true) _chip('Order Matters'),
                        if (q['aliasStrict'] == true) _chip('Alias Strict'),
                        if (sub != null) _chip(sub['is_correct'] == true ? '✅ Correct' : '❌ Incorrect', color: sub['is_correct'] == true ? Colors.green : Colors.orange),
                      ]),
                      trailing: widget.readOnly
                          ? IconButton(icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more), onPressed: () => setState(() => _expandedId = isExpanded ? null : qid))
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF4e73df)),
                      onTap: widget.readOnly
                          ? () => setState(() => _expandedId = isExpanded ? null : qid)
                          : () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => _QuestionDetailPage(question: q, assignment: widget.assignment))),
                    ),
                    if (isExpanded && sub != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Your submitted answer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text(sub['submitted_sql'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                );
              },
            ),
    );
  }

  Widget _chip(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: (color ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.grey)),
  );
}

// ── Question Detail Page ───────────────────────────────────────────────────────
class _QuestionDetailPage extends StatefulWidget {
  final Map<String, dynamic> question;
  final Map<String, dynamic> assignment;
  const _QuestionDetailPage({required this.question, required this.assignment});

  @override
  State<_QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<_QuestionDetailPage> {
  final _ctrl = TextEditingController();
  List<String> _columns = [];
  List<List<dynamic>> _rows = [];
  List<String> _expectedColumns = [];
  List<List<dynamic>> _expectedRows = [];
  String _error = '';
  bool _isCorrect = false;
  bool _showResults = false;
  bool _submitted = false;
  Database? _db;

  // table schema for sidebar
  List<Map<String, dynamic>> _schemas = []; // [{name, cols:[{name,type}]}]

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initDb();
  }

  @override
  void dispose() { _ctrl.dispose(); _db?.close(); super.dispose(); }

  Future<void> _initDb() async {
    // Load config from Firestore and build in-memory DB
    final snap = await FirebaseFirestore.instance.doc('sqliteConfigs/mainConfig').get();
    if (!snap.exists) return;
    final config = snap.data()!;
    final dataset = widget.assignment['dataset'] as String? ?? '';
    if (dataset.isEmpty) return;

    final db = await openDatabase(inMemoryDatabasePath, version: 1);
    final queries = List<String>.from((config[dataset] as Map?)?['queries'] ?? []);
    for (final q in queries) { try { await db.execute(q); } catch (_) {} }

    // Get expected result
    final answer = widget.question['answer'] as String? ?? '';
    List<String> expCols = []; List<List<dynamic>> expRows = [];
    if (answer.isNotEmpty) {
      try {
        final res = await db.rawQuery(answer);
        if (res.isNotEmpty) { expCols = res.first.keys.toList(); expRows = res.map((r) => expCols.map((c) => r[c]).toList()).toList(); }
      } catch (_) {}
    }

    // Get table schemas
    final tableRes = await db.rawQuery("SELECT name, sql FROM sqlite_master WHERE type='table'");
    final schemas = <Map<String, dynamic>>[];
    for (final t in tableRes) {
      final ddl = t['sql'] as String? ?? '';
      final match = RegExp(r'\((.+)\)$', dotAll: true).firstMatch(ddl);
      if (match == null) continue;
      final cols = match.group(1)!.split(',').map((c) => c.trim())
          .where((c) => !RegExp(r'^(FOREIGN|PRIMARY)\s+KEY', caseSensitive: false).hasMatch(c))
          .map((c) { final p = c.split(RegExp(r'\s+')); return {'name': p[0], 'type': p.length > 1 ? p[1] : ''}; }).toList();
      schemas.add({'name': t['name'], 'cols': cols});
    }

    setState(() { _db = db; _expectedColumns = expCols; _expectedRows = expRows; _schemas = schemas; });

    // Check if already submitted
    final existing = await FirebaseFirestore.instance.collection('question_attempts')
        .where('question_id', isEqualTo: widget.question['question_id'])
        .where('student_user_id', isEqualTo: UserSession.uid)
        .where('assignment_id', isEqualTo: widget.assignment['assignment_id'])
        .limit(1).get();
    if (existing.docs.isNotEmpty) {
      final prev = existing.docs.first.data();
      _ctrl.text = prev['submitted_sql'] ?? '';
      setState(() { _submitted = true; _isCorrect = prev['is_correct'] == true; _showResults = true; });
      if (_ctrl.text.isNotEmpty) await _run();
    }
  }

  Future<void> _run() async {
    if (_db == null) return;
    final sql = _ctrl.text.trim();
    if (!sql.toUpperCase().startsWith('SELECT')) {
      setState(() { _error = 'Only SELECT queries are allowed.'; _showResults = true; }); return;
    }
    try {
      final res = await _db!.rawQuery(sql);
      final cols = res.isEmpty ? <String>[] : res.first.keys.toList();
      final rows = res.map((r) => cols.map((c) => r[c]).toList()).toList();
      final correct = _compare(cols, rows);
      setState(() { _columns = cols; _rows = rows; _isCorrect = correct; _error = ''; _showResults = true; });
    } catch (e) {
      setState(() { _error = e.toString(); _showResults = true; });
    }
  }

  bool _compare(List<String> cols, List<List<dynamic>> rows) {
    if (cols.length != _expectedColumns.length) return false;
    final orderMatters = widget.question['orderMatters'] == true;
    final normalize = (List<List<dynamic>> r) => r.map((row) => row.map((v) => v?.toString().toLowerCase() ?? '').toList()).toList();
    final s = normalize(rows); final e = normalize(_expectedRows);
    if (orderMatters) return s.toString() == e.toString();
    s.sort((a, b) => a.toString().compareTo(b.toString()));
    e.sort((a, b) => a.toString().compareTo(b.toString()));
    return s.toString() == e.toString();
  }

  Future<void> _submit() async {
    if (_submitted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already submitted.'))); return; }
    await _run();
    await FirebaseFirestore.instance.collection('question_attempts').add({
      'question_id': widget.question['question_id'],
      'student_user_id': UserSession.uid,
      'assignment_id': widget.assignment['assignment_id'],
      'submitted_sql': _ctrl.text.trim(),
      'is_correct': _isCorrect,
      'submitted_on': DateTime.now().toIso8601String().substring(0, 10),
    });
    setState(() => _submitted = true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isCorrect ? '✅ Correct! +${widget.question['mark']} pts' : '❌ Incorrect. Try again next time.')));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment['title'] ?? 'Question'),
        backgroundColor: const Color(0xFF4e73df),
        foregroundColor: Colors.white,
      ),
      body: _db == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final mobile = constraints.maxWidth < 700;
              final left = _leftPanel(q);
              final right = _rightPanel();
              return mobile
                  ? SingleChildScrollView(child: Column(children: [left, right]))
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 280, child: SingleChildScrollView(child: left)),
                      Expanded(child: SingleChildScrollView(child: right)),
                    ]);
            }),
    );
  }

  Widget _leftPanel(Map<String, dynamic> q) => Container(
    color: const Color(0xFFF8F8F8),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, children: [
        if (q['orderMatters'] == true) _badge('Order Matters', Colors.blue),
        if (q['aliasStrict'] == true) _badge('Alias Strict', Colors.purple),
        _badge('${q['mark'] ?? 1} pts', const Color(0xFF4e73df)),
      ]),
      const SizedBox(height: 12),
      Text(q['question'] ?? '', style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 16),
      ..._schemas.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Table: ${t['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Table(border: TableBorder.all(color: Colors.grey.shade300), children: [
            TableRow(decoration: BoxDecoration(color: Colors.grey.shade100), children: const [
              Padding(padding: EdgeInsets.all(6), child: Text('Field', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(6), child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            ...(t['cols'] as List).map((c) => TableRow(children: [
              Padding(padding: const EdgeInsets.all(6), child: Text(c['name'] as String, style: const TextStyle(fontSize: 12))),
              Padding(padding: const EdgeInsets.all(6), child: Text(c['type'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey))),
            ])),
          ]),
        ]),
      )),
    ]),
  );

  Widget _rightPanel() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SQL Query Editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      TextField(
        controller: _ctrl,
        maxLines: 6,
        enabled: !_submitted,
        style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: _submitted ? Colors.grey : Colors.black),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: 'SELECT ...',
          contentPadding: const EdgeInsets.all(10),
          filled: _submitted,
          fillColor: Colors.grey.shade100,
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        if (!_submitted) ...[
          ElevatedButton(onPressed: _run, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white), child: const Text('▶ Run')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white), child: const Text('Submit')),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.lock, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text('Submitted — locked', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ),
      ]),
      if (_showResults) ...[
        const SizedBox(height: 16),
        if (_error.isNotEmpty)
          Container(padding: const EdgeInsets.all(10), color: Colors.red.shade50, child: Text('❌ $_error', style: const TextStyle(color: Colors.red, fontSize: 13)))
        else
          Container(
            padding: const EdgeInsets.all(10),
            color: _isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
            child: Text(_isCorrect ? '✅ Correct!' : '❌ Wrong Answer', style: TextStyle(color: _isCorrect ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
          ),
        if (_error.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('Your Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          _resultTable(_columns, _rows),
          const SizedBox(height: 12),
          const Text('Expected Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          _resultTable(_expectedColumns, _expectedRows),
        ],
      ],
    ]),
  );

  Widget _resultTable(List<String> cols, List<List<dynamic>> rows) {
    if (cols.isEmpty) return const Text('No results.', style: TextStyle(color: Colors.grey, fontSize: 12));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32, dataRowMinHeight: 28, dataRowMaxHeight: 28, columnSpacing: 16,
        columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        rows: rows.map((r) => DataRow(cells: r.map((v) => DataCell(Text('${v ?? ''}', style: const TextStyle(fontSize: 12)))).toList())).toList(),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}
