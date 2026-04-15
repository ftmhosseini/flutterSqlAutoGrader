import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../services/user_session.dart';

class QuizzesPage extends StatefulWidget {
  const QuizzesPage({super.key});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();

    final cohortSnap = await db.collection('cohorts')
        .where('student_uids', arrayContains: UserSession.uid).get();
    final cohortIds = cohortSnap.docs.map((d) => d.data()['cohort_id'] as String? ?? d.id).toList();
    final targets = ['all', ...cohortIds];

    final subSnap = await db.collection('student_quizzes')
        .where('student_user_id', isEqualTo: UserSession.uid).get();
    final submissionMap = {for (final d in subSnap.docs) d.data()['quiz_id'] as String: d.data()};

    final quizMap = <String, Map<String, dynamic>>{};
    for (int i = 0; i < targets.length; i += 10) {
      final chunk = targets.sublist(i, (i + 10).clamp(0, targets.length));
      final snap = await db.collection('quizzes').where('student_class', whereIn: chunk).get();
      for (final d in snap.docs) { quizMap[d.id] = {...d.data(), 'quiz_id': d.id}; }
    }

    final quizzes = quizMap.values.map((q) {
      final sub = submissionMap[q['quiz_id']];
      final createdOn = q['created_on'] is Timestamp ? (q['created_on'] as Timestamp).toDate() : today;
      final createdDay = DateTime(createdOn.year, createdOn.month, createdOn.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      String status;
      if (sub != null) { status = 'Completed'; }
      else if (createdDay.isBefore(todayDay)) { status = 'Due'; }
      else { status = 'New'; }
      return {...q, 'status': status, 'achievedMark': sub?['mark'], 'isLate': createdDay.isBefore(todayDay)};
    }).toList();

    quizzes.sort((a, b) => (a['due_date'] ?? '').compareTo(b['due_date'] ?? ''));
    setState(() { _quizzes = quizzes; _loading = false; });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'Due': return Colors.red;
      default: return const Color(0xFF4e73df);
    }
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_quizzes.isEmpty)
          const Center(child: Text('No quizzes assigned.', style: TextStyle(color: Colors.grey)))
        else
          Expanded(child: ListView.builder(
            itemCount: _quizzes.length,
            itemBuilder: (_, i) {
              final q = _quizzes[i];
              final id = q['quiz_id'] as String;
              final status = q['status'] as String;
              final isExpanded = _expandedId == id;
              final isOverdue = status == 'Due';
              final mark = q['achievedMark'];
              final totalMark = q['mark'];
              final totalMarkNum = totalMark != null ? num.tryParse(totalMark.toString()) : null;
              final pct = (mark != null && totalMarkNum != null && totalMarkNum > 0)
                  ? '${((mark / totalMarkNum) * 100).round()}%' : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: _statusColor(status).withOpacity(0.4)),
                ),
                child: Column(children: [
                  InkWell(
                    onTap: () => setState(() => _expandedId = isExpanded ? null : id),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4e73df))),
                          const SizedBox(height: 4),
                          Text('Mark: ${q['mark'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(10)),
                          child: Text(status == 'Completed' && pct != null ? '$pct' : status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                      ]),
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(q['questionText'] ?? '', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          if (q['difficulty'] != null) _chip('${q['difficulty']}', Colors.blue),
                          if (q['orderMatters'] == true) _chip('Order Matters', Colors.purple),
                          if (q['aliasStrict'] == true) _chip('Alias Strict', Colors.teal),
                          if (status == 'Completed' && mark != null) _chip('$mark / $totalMark pts${pct != null ? ' ($pct)' : ''}', Colors.green),
                        ]),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context, rootNavigator: true)
                              .push(MaterialPageRoute(builder: (_) => _QuizDetailPage(quiz: q)))
                              .then((_) => _fetch()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'Completed' ? Colors.grey : (isOverdue ? Colors.orange : const Color(0xFF4e73df)),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(status == 'Completed' ? 'View' : 'Start →'),
                        ),
                      ]),
                    ),
                  ],
                ]),
              );
            },
          )),
      ]),
    );
  }
}

// ── Quiz Detail Page ───────────────────────────────────────────────────────────
class _QuizDetailPage extends StatefulWidget {
  final Map<String, dynamic> quiz;
  const _QuizDetailPage({required this.quiz});

  @override
  State<_QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<_QuizDetailPage> {
  final _ctrl = TextEditingController();
  Database? _db;
  List<String> _expCols = []; List<List<dynamic>> _expRows = [];
  List<String> _studCols = []; List<List<dynamic>> _studRows = [];
  List<Map<String, dynamic>> _schemas = [];
  String _error = '';
  bool _isCorrect = false;
  bool _showResults = false;
  bool _submitted = false;
  int _attemptsLeft = 1;
  int _earnedMark = 0;

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _attemptsLeft = widget.quiz['max_attempts'] is int ? widget.quiz['max_attempts'] : int.tryParse('${widget.quiz['max_attempts']}') ?? 1;
    _initDb();
  }

  @override
  void dispose() { _ctrl.dispose(); _db?.close(); super.dispose(); }

  Future<void> _initDb() async {
    final snap = await FirebaseFirestore.instance.doc('sqliteConfigs/mainConfig').get();
    if (!snap.exists) return;
    final config = snap.data()!;
    final dataset = widget.quiz['dataset'] as String? ?? '';
    if (dataset.isEmpty) return;

    final db = await openDatabase(inMemoryDatabasePath, version: 1);
    for (final q in List<String>.from((config[dataset] as Map?)?['queries'] ?? [])) {
      try { await db.execute(q); } catch (_) {}
    }

    // Expected result
    final answer = widget.quiz['answer'] as String? ?? '';
    List<String> expCols = []; List<List<dynamic>> expRows = [];
    if (answer.isNotEmpty) {
      try {
        final res = await db.rawQuery(answer);
        if (res.isNotEmpty) { expCols = res.first.keys.toList(); expRows = res.map((r) => expCols.map((c) => r[c]).toList()).toList(); }
      } catch (_) {}
    }

    // Table schemas
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

    // Check existing submission
    final sub = await FirebaseFirestore.instance.collection('student_quizzes')
        .where('quiz_id', isEqualTo: widget.quiz['quiz_id'])
        .where('student_user_id', isEqualTo: UserSession.uid)
        .limit(1).get();

    setState(() { _db = db; _expCols = expCols; _expRows = expRows; _schemas = schemas; });

    if (sub.docs.isNotEmpty) {
      final data = sub.docs.first.data();
      _ctrl.text = data['submitted_sql'] ?? '';
      setState(() { _submitted = true; _earnedMark = data['mark'] ?? 0; });
      if (_ctrl.text.isNotEmpty) await _run(submit: false);
      setState(() => _showResults = true);
    }
  }

  bool _compare(List<String> cols, List<List<dynamic>> rows) {
    if (cols.length != _expCols.length) return false;
    final norm = (List<List<dynamic>> r) => r.map((row) => row.map((v) => v?.toString().toLowerCase() ?? '').toList()).toList();
    final s = norm(rows); final e = norm(_expRows);
    if (widget.quiz['orderMatters'] == true) return s.toString() == e.toString();
    s.sort((a, b) => a.toString().compareTo(b.toString()));
    e.sort((a, b) => a.toString().compareTo(b.toString()));
    return s.toString() == e.toString();
  }

  Future<bool> _run({bool submit = false}) async {
    if (_db == null) return false;
    final sql = _ctrl.text.trim();
    if (!sql.toUpperCase().startsWith('SELECT')) {
      setState(() { _error = 'Only SELECT queries are allowed.'; _showResults = true; }); return false;
    }
    try {
      final res = await _db!.rawQuery(sql);
      final cols = res.isEmpty ? <String>[] : res.first.keys.toList();
      final rows = res.map((r) => cols.map((c) => r[c]).toList()).toList();
      final correct = _compare(cols, rows);
      setState(() { _studCols = cols; _studRows = rows; _isCorrect = correct; _error = ''; if (submit) _showResults = true; });
      return correct;
    } catch (e) {
      setState(() { _error = e.toString(); if (submit) _showResults = true; }); return false;
    }
  }

  Future<void> _runQuery() async {
    await _run(submit: false);
    if (!_isCorrect && !_submitted) setState(() => _attemptsLeft = (_attemptsLeft - 1).clamp(0, 99));
    setState(() => _showResults = true);
  }

  Future<void> _submit() async {
    if (_submitted || _attemptsLeft <= 0) return;
    final correct = await _run(submit: true);

    // Late penalty: 50% if quiz created before today
    final createdOn = widget.quiz['created_on'] is Timestamp
        ? (widget.quiz['created_on'] as Timestamp).toDate() : DateTime.now();
    final isLate = DateTime(createdOn.year, createdOn.month, createdOn.day)
        .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final totalMark = widget.quiz['mark'] is int ? widget.quiz['mark'] as int : int.tryParse('${widget.quiz['mark']}') ?? 1;
    final earned = correct ? (isLate ? (totalMark * 0.5).floor() : totalMark) : 0;

    await FirebaseFirestore.instance.collection('student_quizzes').add({
      'quiz_id': widget.quiz['quiz_id'],
      'student_user_id': UserSession.uid,
      'submitted_sql': _ctrl.text.trim(),
      'is_correct': correct,
      'mark': earned,
      'status': 'submitted',
      'submissionDate': DateTime.now().toIso8601String().substring(0, 10),
    });
    setState(() { _submitted = true; _earnedMark = earned; _showResults = true; });
  }

  @override
  Widget build(BuildContext context) {
    final lost = _attemptsLeft <= 0 && !_submitted;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz['title'] ?? 'Quiz'),
        backgroundColor: const Color(0xFF4e73df),
        foregroundColor: Colors.white,
      ),
      body: _db == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (_, constraints) {
              final mobile = constraints.maxWidth < 700;
              final left = _leftPanel();
              final right = _rightPanel(lost);
              return mobile
                  ? SingleChildScrollView(child: Column(children: [left, right]))
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 260, child: SingleChildScrollView(child: left)),
                      Expanded(child: SingleChildScrollView(child: right)),
                    ]);
            }),
    );
  }

  Widget _leftPanel() => Container(
    color: const Color(0xFFF8F8F8),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.quiz['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4e73df))),
      const SizedBox(height: 8),
      Text(widget.quiz['questionText'] ?? '', style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        _chip('Difficulty: ${widget.quiz['difficulty'] ?? 'easy'}', Colors.blue),
        _chip('Mark: ${widget.quiz['mark']}', Colors.orange),
        if (widget.quiz['orderMatters'] == true) _chip('Order Matters', Colors.purple),
        if (widget.quiz['aliasStrict'] == true) _chip('Alias Strict', Colors.teal),
        if (!_submitted) _chip('Attempts left: $_attemptsLeft / ${widget.quiz['max_attempts']}', _attemptsLeft > 0 ? Colors.green : Colors.red),
      ]),
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

  Widget _rightPanel(bool lost) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SQL Query Editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      TextField(
        controller: _ctrl,
        maxLines: 6,
        enabled: !_submitted && !lost,
        style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: (_submitted || lost) ? Colors.grey : Colors.black),
        decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'SELECT ...', contentPadding: const EdgeInsets.all(10), filled: _submitted || lost, fillColor: Colors.grey.shade100),
      ),
      const SizedBox(height: 8),
      if (_submitted)
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 14, color: Colors.grey), const SizedBox(width: 6),
            Text(_earnedMark > 0 ? '✅ Submitted — earned $_earnedMark / ${widget.quiz['mark']} pts (${((_earnedMark / (widget.quiz['mark'] is int ? widget.quiz['mark'] as int : 1)) * 100).round()}%)' : '❌ Submitted — 0 pts', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]))
      else if (lost)
        const Text('❌ No attempts left — you cannot submit.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
      else
        Row(children: [
          ElevatedButton(onPressed: _runQuery, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white), child: const Text('▶ Run')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white), child: const Text('Submit')),
        ]),
      if (_showResults) ...[
        const SizedBox(height: 16),
        if (_error.isNotEmpty)
          Container(padding: const EdgeInsets.all(10), color: Colors.red.shade50, child: Text('❌ $_error', style: const TextStyle(color: Colors.red, fontSize: 13)))
        else
          Container(padding: const EdgeInsets.all(10), color: _isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
            child: Text(_isCorrect ? '✅ Correct!' : '❌ Wrong Answer', style: TextStyle(color: _isCorrect ? Colors.green : Colors.orange, fontWeight: FontWeight.bold))),
        if (_error.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('Your Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          _resultTable(_studCols, _studRows),
          const SizedBox(height: 12),
          const Text('Expected Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          _resultTable(_expCols, _expRows),
        ],
      ],
    ]),
  );

  Widget _resultTable(List<String> cols, List<List<dynamic>> rows) {
    if (cols.isEmpty) return const Text('No results.', style: TextStyle(color: Colors.grey, fontSize: 12));
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowHeight: 32, dataRowMinHeight: 28, dataRowMaxHeight: 28, columnSpacing: 16,
      columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
      rows: rows.map((r) => DataRow(cells: r.map((v) => DataCell(Text('${v ?? ''}', style: const TextStyle(fontSize: 12)))).toList())).toList(),
    ));
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}
