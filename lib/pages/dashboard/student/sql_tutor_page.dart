import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Constants ──────────────────────────────────────────────────────────────────
const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama-3.3-70b-versatile';

const _sandboxSeed = [
  "CREATE TABLE IF NOT EXISTS Students (studentId INTEGER PRIMARY KEY, name TEXT, age INTEGER, city TEXT)",
  "CREATE TABLE IF NOT EXISTS Grades (gradeId INTEGER PRIMARY KEY, studentId INTEGER, subject TEXT, score INTEGER, FOREIGN KEY(studentId) REFERENCES Students(studentId))",
  "INSERT OR IGNORE INTO Students VALUES (1,'Alice',20,'Toronto'),(2,'Bob',22,'Calgary'),(3,'Carol',21,'Vancouver'),(4,'Dan',23,'Ottawa')",
  "INSERT OR IGNORE INTO Grades VALUES (1,1,'Math',88),(2,1,'Science',92),(3,2,'Math',75),(4,2,'Science',68),(5,3,'Math',95),(6,3,'Science',80),(7,4,'Math',60),(8,4,'Science',72)",
];

const _lessons = [
  {
    'id': 'select',
    'title': 'SELECT – Fetch Data',
    'explanation': 'SELECT retrieves rows from a table.\n\nSyntax:\n  SELECT column1, column2 FROM table;\n  SELECT * FROM table;  -- all columns\n\nExample: Get all students.',
    'starter': 'SELECT * FROM Students;',
  },
  {
    'id': 'where',
    'title': 'WHERE – Filter Rows',
    'explanation': 'WHERE filters rows by a condition.\n\nSyntax:\n  SELECT * FROM table WHERE condition;\n\nExample: Students older than 21.',
    'starter': 'SELECT * FROM Students WHERE age > 21;',
  },
  {
    'id': 'create',
    'title': 'CREATE TABLE',
    'explanation': 'CREATE TABLE defines a new table.\n\nSyntax:\n  CREATE TABLE name (col type, ...);\n\nExample: Create a Courses table.',
    'starter': 'CREATE TABLE Courses (courseId INTEGER PRIMARY KEY, title TEXT);',
  },
  {
    'id': 'insert',
    'title': 'INSERT – Add Rows',
    'explanation': 'INSERT adds new rows to a table.\n\nSyntax:\n  INSERT INTO table (cols) VALUES (vals);\n\nExample: Add a student.',
    'starter': "INSERT INTO Students (studentId, name, age, city) VALUES (5, 'Eve', 19, 'Halifax');",
  },
  {
    'id': 'drop',
    'title': 'DROP TABLE',
    'explanation': 'DROP TABLE removes a table entirely.\n\nSyntax:\n  DROP TABLE table_name;\n\nExample: Drop a temp table.',
    'starter': 'CREATE TABLE Temp (id INTEGER);\nDROP TABLE Temp;',
  },
  {
    'id': 'aggregate',
    'title': 'Aggregate Functions',
    'explanation': 'Aggregate functions compute a value over many rows.\n\nFunctions: COUNT, SUM, AVG, MIN, MAX\n\nExample: Average score per subject.',
    'starter': 'SELECT subject, AVG(score) AS avg_score FROM Grades GROUP BY subject;',
  },
  {
    'id': 'join',
    'title': 'JOIN – Combine Tables',
    'explanation': 'JOIN links rows from two tables on a matching column.\n\nSyntax:\n  SELECT ... FROM A JOIN B ON A.col = B.col;\n\nExample: Student names with their scores.',
    'starter': 'SELECT s.name, g.subject, g.score\nFROM Students s\nJOIN Grades g ON s.studentId = g.studentId;',
  },
];

// ── DB helper ──────────────────────────────────────────────────────────────────
Future<Database> _buildSandboxDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(inMemoryDatabasePath, version: 1);
  for (final q in _sandboxSeed) {
    await db.execute(q);
  }
  return db;
}

Future<({List<String> columns, List<List<dynamic>> rows})?>
    _runQuery(Database db, String sql) async {
  final stmts = sql.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  dynamic last;
  for (final s in stmts) {
    if (RegExp(r'^SELECT', caseSensitive: false).hasMatch(s)) {
      last = await db.rawQuery(s);
    } else {
      await db.execute(s);
      last = null;
    }
  }
  if (last == null || (last as List).isEmpty) return null;
  final rows = last as List<Map<String, dynamic>>;
  final cols = rows.first.keys.toList();
  return (columns: cols, rows: rows.map((r) => cols.map((c) => r[c]).toList()).toList());
}

Future<List<Map<String, dynamic>>> _getLiveSchema(Database db) async {
  final res = await db.rawQuery("SELECT name, sql FROM sqlite_master WHERE type='table'");
  final tables = <Map<String, dynamic>>[];
  for (final row in res) {
    final name = row['name'] as String;
    final ddl = row['sql'] as String? ?? '';
    final match = RegExp(r'\((.+)\)$', dotAll: true).firstMatch(ddl);
    if (match == null) continue;
    final body = match.group(1)!;
    final fkCols = RegExp(r'FOREIGN KEY\s*\((\w+)\)', caseSensitive: false)
        .allMatches(body)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    final cols = body.split(',').map((c) => c.trim()).where((c) => !RegExp(r'^(FOREIGN|PRIMARY)\s+KEY', caseSensitive: false).hasMatch(c)).map((c) {
      final parts = c.split(RegExp(r'\s+'));
      return {
        'name': parts[0],
        'type': parts.length > 1 ? parts[1] : '',
        'pk': RegExp(r'PRIMARY KEY', caseSensitive: false).hasMatch(c),
        'fk': fkCols.contains(parts[0].toLowerCase()),
      };
    }).toList();
    tables.add({'name': name, 'cols': cols});
  }
  return tables;
}

// ── Result Table Widget ────────────────────────────────────────────────────────
class _ResultTable extends StatelessWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  const _ResultTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 28,
        columnSpacing: 16,
        columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        rows: rows.map((r) => DataRow(cells: r.map((v) => DataCell(Text('${v ?? ''}', style: const TextStyle(fontSize: 12)))).toList())).toList(),
      ),
    );
  }
}

// ── Schema Sidebar ─────────────────────────────────────────────────────────────
class _SchemaSidebar extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final bool mobile;
  const _SchemaSidebar({required this.tables, this.mobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: mobile ? double.infinity : 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Live Schema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          mobile
              ? GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2,
                  children: tables.map((t) => _tableWidget(t)).toList(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tables.map((t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _tableWidget(t))).toList(),
                ),
        ],
      ),
    );
  }

  Widget _tableWidget(Map<String, dynamic> t) {
    final cols = t['cols'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4e73df), fontSize: 12)),
        ...cols.map((c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(children: [
                Text('${c['name']} ', style: const TextStyle(fontSize: 11)),
                Text(c['type'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (c['pk'] == true) const Text(' PK', style: TextStyle(fontSize: 10, color: Color(0xFFe67e22))),
                if (c['fk'] == true) const Text(' FK', style: TextStyle(fontSize: 10, color: Color(0xFF8e44ad))),
              ]),
            )),
      ],
    );
  }
}

// ── Lesson Tab ─────────────────────────────────────────────────────────────────
class _LessonTab extends StatefulWidget {
  final Database db;
  final VoidCallback onRun;
  const _LessonTab({required this.db, required this.onRun});

  @override
  State<_LessonTab> createState() => _LessonTabState();
}

class _LessonTabState extends State<_LessonTab> {
  int _idx = 0;
  late TextEditingController _ctrl;
  List<String>? _columns;
  List<List<dynamic>>? _rows;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _lessons[0]['starter']);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _selectLesson(int i) {
    setState(() {
      _idx = i;
      _ctrl.text = _lessons[i]['starter']!;
      _columns = null;
      _rows = null;
      _error = '';
    });
  }

  Future<void> _run() async {
    try {
      final result = await _runQuery(widget.db, _ctrl.text);
      setState(() {
        _error = '';
        _columns = result?.columns;
        _rows = result?.rows;
      });
      widget.onRun();
    } catch (e) {
      setState(() { _error = e.toString(); _columns = null; _rows = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lessons[_idx];
    return LayoutBuilder(builder: (context, constraints) {
      final mobile = constraints.maxWidth < 600;
      final lessonList = mobile
          ? Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_lessons.length, (i) => _lessonChip(i)),
            )
          : SizedBox(
              width: 160,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _lessons.length,
                itemBuilder: (_, i) => _lessonChip(i),
              ),
            );

      final content = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(6)),
              child: Text(lesson['explanation']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _run,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
              child: const Text('▶ Run'),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('❌ $_error', style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_columns != null) ...[
              const SizedBox(height: 8),
              _ResultTable(columns: _columns!, rows: _rows ?? []),
            ],
          ],
        ),
      );

      if (mobile) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          lessonList,
          const SizedBox(height: 12),
          content,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lessonList,
        const SizedBox(width: 16),
        Expanded(child: content),
      ]);
    });
  }

  Widget _lessonChip(int i) {
    final selected = i == _idx;
    return GestureDetector(
      onTap: () => _selectLesson(i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4e73df) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(_lessons[i]['title']!, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
      ),
    );
  }
}

// ── Quiz Tab ───────────────────────────────────────────────────────────────────
class _QuizTab extends StatefulWidget {
  final Database db;
  const _QuizTab({required this.db});

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  List<Map<String, dynamic>> _questions = [];
  int _current = 0;
  int _score = 0;
  bool _loading = false;
  bool _done = false;
  bool _answered = false;
  Map<String, dynamic>? _feedback;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _questions = []; _score = 0; _current = 0; _done = false; _feedback = null; _answered = false; });
    _ctrl.clear();
    try {
      final schema = await _getLiveSchema(widget.db);
      final schemaText = schema.map((t) {
        final cols = (t['cols'] as List).map((c) => '  ${c['name']} ${c['type']}').join('\n');
        return 'Table: ${t['name']}\n$cols';
      }).join('\n\n');

      final res = await http.post(
        Uri.parse(_groqUrl),
        headers: {'Authorization': 'Bearer $_groqApiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'messages': [{'role': 'user', 'content': 'You are a SQL instructor. Given this schema, generate 5 SQL practice questions.\n\n$schemaText\n\nReturn ONLY a valid JSON array. Each item: {"id":1,"question":"...","answer":"SELECT ..."}'}],
          'max_tokens': 2048,
          'temperature': 1.0,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = data['choices'][0]['message']['content'] as String;
        final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
        final qs = List<Map<String, dynamic>>.from(jsonDecode(cleaned));
        setState(() => _questions = qs.take(8).toList());
      } else {
        throw Exception('API error ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_answered) return;
    final q = _questions[_current];
    try {
      final studentResult = await _runQuery(widget.db, _ctrl.text);
      final expectedResult = await _runQuery(widget.db, q['answer'] as String);

      final normalize = (r) => r == null ? '[]' : jsonEncode((r.rows..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)))));
      final correct = normalize(studentResult) == normalize(expectedResult);
      if (correct) setState(() => _score++);
      setState(() {
        _feedback = {'correct': correct, 'studentResult': studentResult, 'expectedResult': expectedResult, 'correctSql': q['answer']};
        _answered = true;
      });
    } catch (e) {
      setState(() {
        _feedback = {'correct': false, 'error': e.toString()};
        _answered = true;
      });
    }
  }

  void _next() {
    if (_current + 1 >= _questions.length) { setState(() => _done = true); return; }
    setState(() { _current++; _feedback = null; _answered = false; });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('⏳ Generating quiz questions...')]));

    if (_questions.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('AI will generate questions based on the live schema.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _generate,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
            child: const Text('🎯 Generate Quiz'),
          ),
        ]),
      );
    }

    if (_done) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Quiz Complete! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Score: $_score / ${_questions.length}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _generate, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white), child: const Text('Try Again')),
        ]),
      );
    }

    final q = _questions[_current];
    final fb = _feedback;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Question ${_current + 1} of ${_questions.length}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Score: $_score', style: const TextStyle(fontSize: 13, color: Color(0xFF4e73df))),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
            child: Text(q['question'] as String, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            enabled: !_answered,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(hintText: 'Write your SQL query here...', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (!_answered)
              ElevatedButton(
                onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
                child: const Text('Submit'),
              ),
            if (_answered)
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1cc88a), foregroundColor: Colors.white),
                child: Text(_current + 1 >= _questions.length ? 'See Results' : 'Next →'),
              ),
          ]),
          if (fb != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fb['correct'] == true ? const Color(0xFFe8f8f0) : const Color(0xFFfff0f0),
                border: Border.all(color: fb['correct'] == true ? const Color(0xFF1cc88a) : const Color(0xFFe74c3c)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fb['correct'] == true ? '✅ Correct!' : '❌ Incorrect',
                    style: TextStyle(fontWeight: FontWeight.bold, color: fb['correct'] == true ? const Color(0xFF1cc88a) : const Color(0xFFe74c3c))),
                if (fb['error'] != null) Text('Error: ${fb['error']}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                if (fb['correct'] != true && fb['error'] == null) ...[
                  const SizedBox(height: 8),
                  const Text('Correct answer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
                    child: Text(fb['correctSql'] as String, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                  if (fb['studentResult'] != null) ...[
                    const Text('Your output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    _ResultTable(columns: (fb['studentResult'] as dynamic).columns, rows: (fb['studentResult'] as dynamic).rows),
                  ],
                  if (fb['expectedResult'] != null) ...[
                    const SizedBox(height: 8),
                    const Text('Expected output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    _ResultTable(columns: (fb['expectedResult'] as dynamic).columns, rows: (fb['expectedResult'] as dynamic).rows),
                  ],
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Main Page ──────────────────────────────────────────────────────────────────
class SqlTutorPage extends StatefulWidget {
  const SqlTutorPage({super.key});

  @override
  State<SqlTutorPage> createState() => _SqlTutorPageState();
}

class _SqlTutorPageState extends State<SqlTutorPage> with SingleTickerProviderStateMixin {
  Database? _db;
  List<Map<String, dynamic>> _schema = [];
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _buildSandboxDb().then((db) async {
      final schema = await _getLiveSchema(db);
      setState(() { _db = db; _schema = schema; });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _refreshSchema() async {
    if (_db == null) return;
    final schema = await _getLiveSchema(_db!);
    setState(() => _schema = schema);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('📚 SQL Tutor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF4e73df),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4e73df),
          tabs: const [Tab(text: '📖 Lessons'), Tab(text: '🎯 Quiz')],
        ),
        Expanded(
          child: _db == null
              ? const Center(child: CircularProgressIndicator())
              : AnimatedBuilder(
                  animation: _tabCtrl,
                  builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
                    final mobile = constraints.maxWidth < 600;
                    final sidebar = _SchemaSidebar(tables: _schema, mobile: mobile);
                    final tabContent = IndexedStack(
                      index: _tabCtrl.index,
                      children: [
                        _LessonTab(db: _db!, onRun: _refreshSchema),
                        _QuizTab(db: _db!),
                      ],
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: mobile
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [sidebar, const SizedBox(height: 12), tabContent])
                          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              sidebar,
                              const SizedBox(width: 16),
                              Expanded(child: tabContent),
                            ]),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}
