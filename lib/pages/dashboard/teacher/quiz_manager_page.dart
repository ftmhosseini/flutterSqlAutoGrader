import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/user_session.dart';

const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');

class QuizManagerPage extends StatefulWidget {
  const QuizManagerPage({super.key});

  @override
  State<QuizManagerPage> createState() => _QuizManagerPageState();
}

class _QuizManagerPageState extends State<QuizManagerPage> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  bool _showForm = false;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final snap = await FirebaseFirestore.instance.collection('quizzes')
        .where('owner_user_id', isEqualTo: UserSession.uid).get();
    final quizzes = snap.docs.map((d) => {...d.data(), 'quiz_id': d.id}).toList();
    quizzes.sort((a, b) {
      final at = (a['created_on'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bt = (b['created_on'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
    setState(() { _quizzes = quizzes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_showForm) return _QuizFormPage(onDone: () { setState(() => _showForm = false); _fetch(); });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Quizzes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showForm = true),
            icon: const Icon(Icons.add),
            label: const Text('New Quiz'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 16),
        if (_quizzes.isEmpty)
          const Center(child: Text('No quizzes found. Create your first one!', style: TextStyle(color: Colors.grey)))
        else
          Expanded(child: ListView.builder(
            itemCount: _quizzes.length,
            itemBuilder: (_, i) {
              final q = _quizzes[i];
              final id = q['quiz_id'] as String;
              final isExpanded = _expandedId == id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: const Color(0xFF4e73df).withOpacity(0.3))),
                child: Column(children: [
                  InkWell(
                    onTap: () => setState(() => _expandedId = isExpanded ? null : id),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Expanded(child: Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4e73df)))),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                      ]),
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('QUESTION TEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4e73df))),
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                              child: Text(q['questionText'] ?? '', style: const TextStyle(fontSize: 13))),
                          ])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('SQL ANSWER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
                              child: Text(q['answer'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF4e73df)))),
                          ])),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          _badge('Difficulty: ${q['difficulty'] ?? 'easy'}', Colors.blue),
                          _badge('Mark: ${q['mark'] ?? 1}', Colors.orange),
                          _badge('Attempts: ${q['max_attempts'] ?? 1}', Colors.grey),
                          if (q['orderMatters'] == true) _badge('Order Matters', Colors.purple),
                          if (q['aliasStrict'] == true) _badge('Alias Strict', Colors.teal),
                        ]),
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

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── Quiz Form ──────────────────────────────────────────────────────────────────
class _QuizFormPage extends StatefulWidget {
  final VoidCallback onDone;
  const _QuizFormPage({required this.onDone});

  @override
  State<_QuizFormPage> createState() => _QuizFormPageState();
}

class _QuizFormPageState extends State<_QuizFormPage> {
  Map<String, dynamic> _config = {};
  List<String> _datasets = [];
  List<String> _tables = [];
  List<Map<String, dynamic>> _presets = [];
  List<Map<String, dynamic>> _cohorts = [];
  List<String> _selectedTables = [];
  bool _loading = true;
  String _error = '';

  final _titleCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  String? _selectedDataset;
  String? _selectedCohort;
  String _difficulty = 'easy';
  int _maxAttempts = 1;
  int _mark = 1;
  bool _orderMatters = false;
  bool _aliasStrict = false;

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _loadData();
  }

  Future<void> _loadData() async {
    final configSnap = await FirebaseFirestore.instance.doc('sqliteConfigs/mainConfig').get();
    final cohortSnap = await FirebaseFirestore.instance.collection('cohorts')
        .where('owner_user_id', isEqualTo: UserSession.uid).get();
    final config = configSnap.exists ? configSnap.data()!.map((k, v) {
      if (v is Map) { final inner = Map<String, dynamic>.from(v); if (inner['queries'] != null) inner['queries'] = List<String>.from(inner['queries']); return MapEntry(k, inner); }
      return MapEntry(k, v);
    }) : <String, dynamic>{};
    final dbQueries = List<String>.from(config['db']?['queries'] ?? []);
    final datasets = dbQueries.where((q) => q.toUpperCase().startsWith('INSERT INTO DATASETS'))
        .map((q) => RegExp(r"VALUES \('(.+?)'\)", caseSensitive: false).firstMatch(q)?.group(1) ?? '').where((s) => s.isNotEmpty).toList();

    // Auto title
    final today = DateTime.now();
    final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final todayStr = '${months[today.month - 1]}${today.day}';
    final quizSnap = await FirebaseFirestore.instance.collection('quizzes').where('owner_user_id', isEqualTo: UserSession.uid).get();
    final todayCount = quizSnap.docs.where((d) {
      final ts = d.data()['created_on'] as Timestamp?;
      if (ts == null) return false;
      final d2 = ts.toDate();
      return d2.year == today.year && d2.month == today.month && d2.day == today.day;
    }).length;
    _titleCtrl.text = '$todayStr-${todayCount + 1}';

    setState(() { _config = config; _datasets = datasets; _cohorts = cohortSnap.docs.map((d) => {...d.data(), 'cohort_id': d.id}).toList(); _loading = false; });
  }

  bool _loadingPresets = false;
  Map<String, List<Map<String, dynamic>>> _schemaMap = {};
  int? _selectedPreset;

  Future<void> _onDatasetChanged(String dataset) async {
    setState(() { _selectedDataset = dataset; _tables = []; _presets = []; _selectedTables = []; _selectedPreset = null; _loadingPresets = true; });
    final db = await _buildDb('db');
    final rows = await db.rawQuery('SELECT DISTINCT tableName FROM Tables WHERE datasetName = ?', [dataset]);
    await db.close();
    final tables = rows.map((r) => r['tableName'] as String).toList();
    setState(() => _tables = tables);

    if (tables.isEmpty) { setState(() => _loadingPresets = false); return; }
    final datasetDb = await _buildDb(dataset);
    final schemaMap = <String, List<Map<String, dynamic>>>{};
    final schemaText = (await Future.wait(tables.map((t) async {
      final cols = await datasetDb.rawQuery("SELECT name, type, pk FROM pragma_table_info(?)", [t]);
      final fkRows = await datasetDb.rawQuery("SELECT [from] FROM pragma_foreign_key_list(?)", [t]);
      final fkCols = fkRows.map((r) => r['from'] as String).toSet();
      schemaMap[t] = cols.map((c) => {
        'name': c['name'], 'type': c['type'],
        'pk': (c['pk'] as int? ?? 0) > 0,
        'fk': fkCols.contains(c['name']),
      }).toList();
      return 'Table: $t\n${cols.map((c) => '  ${c['name']} ${c['type']}').join('\n')}';
    }))).join('\n\n');
    await datasetDb.close();
    setState(() => _schemaMap = schemaMap);

    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $_groqApiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({'model': 'llama-3.3-70b-versatile', 'messages': [{'role': 'user',
          'content': 'SQL instructor. Generate 5 SQL practice questions for this schema.\n\n$schemaText\n\nReturn ONLY valid JSON array. Each: {"id":1,"question":"...","answer":"SELECT ...","mark":2,"difficulty":"easy","max_attempts":3,"orderMatters":false,"aliasStrict":false}'}],
          'max_tokens': 2048, 'temperature': 1.0}),
      );
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
        final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
        setState(() => _presets = List<Map<String, dynamic>>.from(jsonDecode(cleaned)));
      }
    } catch (_) {}
    setState(() => _loadingPresets = false);
  }

  Future<Database> _buildDb(String dbname) async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1);
    for (final q in List<String>.from(_config[dbname]?['queries'] ?? [])) { try { await db.execute(q); } catch (_) {} }
    return db;
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_titleCtrl.text.trim().isEmpty) { setState(() => _error = 'Title is required.'); return; }
    if (_questionCtrl.text.trim().isEmpty) { setState(() => _error = 'Question text is required.'); return; }
    if (_answerCtrl.text.trim().isEmpty) { setState(() => _error = 'SQL answer is required.'); return; }
    if (_selectedCohort == null) { setState(() => _error = 'Please select a cohort.'); return; }

    // Validate SQL returns results
    if (_selectedDataset != null) {
      try {
        final db = await _buildDb(_selectedDataset!);
        final result = await db.rawQuery(_answerCtrl.text.trim());
        await db.close();
        if (result.isEmpty) { setState(() => _error = 'SQL query returns no rows. Use a query that returns data.'); return; }
      } catch (e) {
        setState(() => _error = 'Invalid SQL: $e'); return;
      }
    }

    final ref = FirebaseFirestore.instance.collection('quizzes').doc();
    await ref.set({
      'quiz_id': ref.id,
      'title': _titleCtrl.text.trim(),
      'dataset': _selectedDataset,
      'questionText': _questionCtrl.text.trim(),
      'answer': _answerCtrl.text.trim(),
      'difficulty': _difficulty,
      'max_attempts': _maxAttempts,
      'mark': _mark,
      'orderMatters': _orderMatters,
      'aliasStrict': _aliasStrict,
      'student_class': _selectedCohort,
      'owner_user_id': UserSession.uid,
      'created_on': FieldValue.serverTimestamp(),
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quiz'),
        backgroundColor: const Color(0xFF4e73df),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onDone),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Settings card
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Quiz Title', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedDataset,
              decoration: const InputDecoration(labelText: 'Dataset', border: OutlineInputBorder()),
              items: _datasets.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) { if (v != null) _onDatasetChanged(v); },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCohort,
              decoration: const InputDecoration(labelText: 'Assign to Cohort', border: OutlineInputBorder()),
              items: _cohorts.map((c) => DropdownMenuItem(value: c['cohort_id'] as String, child: Text(c['name'] as String? ?? ''))).toList(),
              onChanged: (v) => setState(() => _selectedCohort = v),
            ),
          ]))),
          const SizedBox(height: 16),

          // Question designer
          if (_selectedDataset != null) ...[
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Question Designer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              if (_schemaMap.isNotEmpty) ...[
                _schemaWidget(_schemaMap),
                const SizedBox(height: 10),
              ],
              
              if (_loadingPresets) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('⏳ Generating AI questions...', style: TextStyle(fontSize: 12, color: Colors.grey))])),
              ] else if (_presets.isNotEmpty) ...[
                if (_tables.isNotEmpty) ...[
                const Text('Filter by tables:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Wrap(spacing: 8, children: _tables.map((t) => FilterChip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  selected: _selectedTables.contains(t),
                  onSelected: (v) => setState(() { v ? _selectedTables.add(t) : _selectedTables.remove(t); _selectedPreset = null; }),
                )).toList()),
                const SizedBox(height: 10),
              ],
                Builder(builder: (ctx) {
                  final filteredEntries = _presets.asMap().entries.where((e) {
                    if (_selectedTables.isEmpty) return true;
                    final ans = (e.value['answer'] as String? ?? '').toLowerCase();
                    return _selectedTables.every((t) => ans.contains(t.toLowerCase()));
                  }).toList();
                  // If current selection is not in filtered list, reset to null
                  final validValue = filteredEntries.any((e) => e.key == _selectedPreset) ? _selectedPreset : null;
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Use Preset', border: OutlineInputBorder(), isDense: true),
                    isExpanded: true,
                    value: validValue,
                    items: filteredEntries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['question'] as String? ?? '', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final p = _presets[v];
                      setState(() {
                        _selectedPreset = v;
                        _questionCtrl.text = p['question'] ?? '';
                        _answerCtrl.text = p['answer'] ?? '';
                        _difficulty = p['difficulty'] ?? 'easy';
                        _maxAttempts = (p['max_attempts'] as num?)?.toInt() ?? 1;
                        _mark = (p['mark'] as num?)?.toInt() ?? 1;
                        _orderMatters = p['orderMatters'] ?? false;
                        _aliasStrict = p['aliasStrict'] ?? false;
                      });
                    },
                  );
                }),
                const SizedBox(height: 10),
              ],
              TextField(controller: _questionCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Question Prompt', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _answerCtrl, maxLines: 3, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4e73df)), decoration: const InputDecoration(labelText: 'Expected SQL Answer', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder(), isDense: true),
                  items: ['easy', 'medium', 'hard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _difficulty = v!),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 90, child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Attempts', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: '$_maxAttempts'),
                  onChanged: (v) => _maxAttempts = int.tryParse(v) ?? 1,
                )),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mark', border: OutlineInputBorder(), isDense: true),
                  controller: TextEditingController(text: '$_mark'),
                  onChanged: (v) => _mark = int.tryParse(v) ?? 1,
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                FilterChip(label: const Text('Order Matters', style: TextStyle(fontSize: 11)), selected: _orderMatters, onSelected: (v) => setState(() => _orderMatters = v)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('Alias Strict', style: TextStyle(fontSize: 11)), selected: _aliasStrict, onSelected: (v) => setState(() => _aliasStrict = v)),
              ]),
            ]))),
            const SizedBox(height: 16),
          ],

          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error, style: const TextStyle(color: Colors.red))),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Create & Distribute Quiz', style: TextStyle(fontSize: 15)),
          )),
        ]),
      ),
    );
  }

  Widget _schemaWidget(Map<String, List<Map<String, dynamic>>> schema) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📋 Schema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 6),
      Wrap(spacing: 16, runSpacing: 8, children: schema.entries.map((e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4e73df), fontSize: 12)),
          ...e.value.map((c) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${c['name']}  ', style: const TextStyle(fontSize: 11)),
              Text(c['type'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (c['pk'] == true) ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFe67e22).withOpacity(0.15), borderRadius: BorderRadius.circular(3)), child: const Text('PK', style: TextStyle(fontSize: 9, color: Color(0xFFe67e22), fontWeight: FontWeight.bold)))],
              if (c['fk'] == true) ...[const SizedBox(width: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF8e44ad).withOpacity(0.15), borderRadius: BorderRadius.circular(3)), child: const Text('FK', style: TextStyle(fontSize: 9, color: Color(0xFF8e44ad), fontWeight: FontWeight.bold)))],
            ]),
          )),
        ],
      )).toList()),
    ]),
  );
}
