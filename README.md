# SQL Auto-Grader — Flutter App

A mobile/desktop companion to the React web app. **Teachers** create SQL assignments and quizzes; **students** solve them with instant automated feedback. Shares the same Firebase backend as the React app.

---

## Table of Contents

1. [What This App Does](#what-this-app-does)
2. [Concepts You Need to Know First](#concepts-you-need-to-know-first)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [How the App Starts](#how-the-app-starts)
6. [Authentication Flow](#authentication-flow)
7. [Routing — How Pages Connect](#routing--how-pages-connect)
8. [State Management — Provider](#state-management--provider)
9. [Data Layer — Firestore](#data-layer--firestore)
10. [In-Memory SQLite — How SQL Grading Works](#in-memory-sqlite--how-sql-grading-works)
11. [AI Integration — Groq API](#ai-integration--groq-api)
12. [Dashboard Architecture](#dashboard-architecture)
13. [Assignment Flow — Create → Publish → Grade](#assignment-flow--create--publish--grade)
14. [Key Flutter Patterns Used](#key-flutter-patterns-used)
15. [Setup & Running](#setup--running)
16. [First-Time Walkthrough](#first-time-walkthrough)
17. [Shared Database Notes](#shared-database-notes)

---

## What This App Does

- **Teachers** create datasets (tables + seed data), multi-question assignments, and quizzes, then assign them to student cohorts. Assignments are saved as drafts and published separately.
- **Students** write SQL answers, run them against a live in-memory SQLite database on-device, and get instant correct/incorrect feedback.
- An **AI tutor** (Groq / llama-3.3-70b) generates SQL questions from dataset schemas and powers a chat assistant.
- Teachers view per-student submission results and can override scores.

---

## Concepts You Need to Know First

### What is Flutter?

Flutter is a UI framework for building apps from a single Dart codebase that runs on iOS, Android, macOS, Windows, Linux, and web. Everything on screen is a **Widget** — a button, a text label, a whole page. Widgets are composed (nested) to build UIs.

```dart
// Widgets are just classes. You compose them by nesting.
Column(
  children: [
    Text('Hello'),           // text widget
    Icon(Icons.person),      // icon widget
    ElevatedButton(
      onPressed: () {},
      child: Text('Click me'),
    ),
  ],
)
```

### StatelessWidget vs StatefulWidget

- **StatelessWidget** — UI never changes after it's built. Use for static content.
- **StatefulWidget** — has a `State` object. Call `setState()` to rebuild the UI when data changes.

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();           // called once when the widget is inserted into the tree
  }

  Future<void> _load() async {
    final data = await fetchFromFirestore();
    setState(() {      // triggers a rebuild with new data
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator();
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) => Text(_items[i]['title']),
    );
  }
}
```

### What is Dart?

Dart is the language Flutter uses. Key things to know:

```dart
// Variables
String name = 'Alice';
int age = 25;
bool isTeacher = true;
List<String> names = ['Alice', 'Bob'];
Map<String, dynamic> user = {'name': 'Alice', 'age': 25};

// Null safety — variables can't be null unless you say so
String? maybeNull = null;   // ? means nullable
String notNull = 'hello';   // can never be null

// async/await — same concept as JavaScript
Future<void> fetchData() async {
  final result = await someAsyncOperation();  // waits for result
  print(result);
}

// Arrow functions
int double(int x) => x * 2;

// Spread operator
final combined = {...map1, 'extra': 'value'};
```

### What is Firebase?

Firebase is Google's backend-as-a-service. This app uses:

- **Firebase Auth** — email/password login. Firebase persists the session automatically — users stay logged in across app restarts.
- **Cloud Firestore** — a NoSQL cloud database. Data is stored as **documents** inside **collections**.

```
Firestore structure:
  users/{uid}                  ← fullName, email, role ('teacher' | 'student')
  assignments/{id}             ← title, questions[], due_date, grading_policy, owner_user_id
  student_assignments/{id}     ← student_user_id, assignment_id, status, earned_point
  question_attempts/{id}       ← student_user_id, question_id, submitted_sql, is_correct
  cohorts/{id}                 ← name, student_uids[], owner_user_id
  quizzes/{id}                 ← title, questionText, answer, student_class
  sqliteConfigs/mainConfig     ← all dataset SQL statements
```

**Important:** `question_attempts` documents do NOT have an `assignment_id` field. To find a student's attempts for a specific assignment, query by `student_user_id` and filter by `question_id` matching the assignment's questions.

### What is go_router?

`go_router` is a Flutter routing package. You define URL-like paths and navigate with `context.go('/path')`. It supports:
- **Redirects** — check auth state before allowing navigation
- **ShellRoute** — a persistent wrapper (like a nav bar) that doesn't rebuild on navigation

### What is Provider?

`provider` is a Flutter state management package. It lets you share data across the widget tree without passing it through every constructor.

```dart
// Define a provider
class AuthProvider extends ChangeNotifier {
  String? role;
  void setRole(String r) { role = r; notifyListeners(); }
}

// Wrap your app
ChangeNotifierProvider(create: (_) => AuthProvider(), child: MyApp())

// Read it anywhere
final auth = context.read<AuthProvider>();   // read once
final auth = context.watch<AuthProvider>();  // rebuild when it changes
```

---

## Tech Stack

| Package | Version | Purpose |
|---|---|---|
| Flutter | SDK ^3.12 | UI framework |
| firebase_core | ^3.6.0 | Firebase initialization |
| firebase_auth | ^5.3.1 | Email/password authentication |
| cloud_firestore | ^5.4.4 | Firestore database |
| go_router | ^14.3.0 | Navigation + deep linking |
| provider | ^6.1.2 | Auth state management |
| sqflite_common_ffi | ^2.3.3 | In-memory SQLite for grading |
| http | ^1.2.0 | Groq API calls |
| flutter_markdown | ^0.7.4 | Render AI tutor responses |
| url_launcher | ^6.3.0 | Open links |

---

## Project Structure

```
lib/
├── main.dart                  ← App entry point, Firebase init, Provider setup
├── router.dart                ← All routes + auth redirect logic
├── firebase_options.dart      ← Auto-generated Firebase config (do not edit)
│
├── models/
│   └── user_model.dart        ← UserModel: uid, email, fullName, role
│
├── services/
│   ├── user_service.dart      ← getUser(uid): fetches user doc from Firestore
│   └── user_session.dart      ← Static class holding current user in memory
│
├── providers/
│   └── auth_provider.dart     ← Listens to Firebase auth stream, sets UserSession
│
└── pages/
    ├── home_page.dart         ← Public landing page
    ├── login_page.dart        ← Login form
    ├── register_page.dart     ← Register form (student or teacher)
    ├── about_page.dart        ← About page
    └── dashboard/
        ├── dashboard_shell.dart         ← App bar + bottom nav (wraps all dashboard pages)
        ├── dashboard_home.dart          ← Services grid + stats overview (both roles)
        ├── profile_page.dart            ← User profile
        ├── teacher/
        │   ├── assignment_list_page.dart    ← List assignments, publish button, delete
        │   ├── assignment_form_page.dart    ← 3-step wizard: Details → Questions → Assign
        │   ├── cohort_manager_page.dart     ← Create cohorts, view members
        │   ├── database_manager_page.dart   ← Create datasets and tables
        │   ├── quiz_manager_page.dart       ← Create + list quizzes
        │   └── submission_status_page.dart  ← Per-student attempt viewer + score override
        └── student/
            ├── assignments_page.dart        ← View + solve assignments (SQL editor)
            ├── quizzes_page.dart            ← View + solve quizzes
            ├── results_page.dart            ← View grades
            ├── cohort_page.dart             ← Join cohorts by code
            └── sql_tutor_page.dart          ← AI-powered SQL lessons + chat
```

---

## How the App Starts

**`lib/main.dart`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();   // required before any async work
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),  // available to all widgets
      child: const SqlAutoGraderApp(),
    ),
  );
}
```

`SqlAutoGraderApp` is a `MaterialApp.router` that uses the `go_router` instance from `router.dart`.

---

## Authentication Flow

### `AuthProvider` (`providers/auth_provider.dart`)

```dart
class AuthProvider extends ChangeNotifier {
  String? _role;
  bool _loading = true;

  AuthProvider() {
    // Firebase fires this every time auth state changes:
    // app open (restores session), login, logout
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.emailVerified) {
        final userData = await getUser(user.uid);
        if (userData != null) UserSession.set(userData);
        _role = UserSession.role;
      } else {
        UserSession.clear();
        _role = null;
      }
      _loading = false;
      notifyListeners();  // router re-evaluates redirect
    });
  }
}
```

### `UserSession` (`services/user_session.dart`)

```dart
// Static class — accessible from anywhere without passing a reference
class UserSession {
  static UserModel? _user;
  static void set(UserModel? u) => _user = u;
  static void clear() => _user = null;
  static String? get uid => _user?.uid;
  static String? get role => _user?.role;  // 'teacher' or 'student'
}
```

### Registration flow

1. `FirebaseAuth.instance.createUserWithEmailAndPassword(email, password)`
2. `user.sendEmailVerification()`
3. Write `users/{uid}` doc to Firestore with `{ fullName, email, role }`
4. Navigate to login

### Login flow

1. `FirebaseAuth.instance.signInWithEmailAndPassword(email, password)`
2. Check `user.emailVerified` — show error if not verified
3. `AuthProvider` listener fires → fetches role → sets `UserSession` → router redirects to `/dashboard`

---

## Routing — How Pages Connect

All routes are in `router.dart`. The router uses `redirect` to enforce auth:

```dart
redirect: (context, state) {
  if (auth.loading) return null;                              // wait for auth check
  final loggedIn = auth.role != null;
  if (!loggedIn && state.matchedLocation.startsWith('/dashboard')) return '/login';
  if (loggedIn && state.matchedLocation == '/') return '/dashboard';
  return null;
},
```

**ShellRoute** wraps all dashboard pages in `DashboardShell` so the app bar and bottom nav persist across navigation:

```dart
ShellRoute(
  builder: (_, __, child) => DashboardShell(child: child),
  routes: [
    GoRoute(path: '/dashboard', builder: ...),
    GoRoute(path: '/dashboard/student/assignments', builder: ...),
    // ...
  ],
)
```

**Navigation:**
```dart
context.go('/dashboard/student/assignments');   // replace stack
context.push('/dashboard/student/assignments'); // push (back button works)
```

---

## State Management — Provider

Only auth state uses Provider. All other state is local to each page's `State` class using `setState`.

```dart
// In router.dart — read without rebuilding
final auth = Provider.of<AuthProvider>(context, listen: false);

// In a widget — rebuild when auth changes
final auth = context.watch<AuthProvider>();
```

---

## Data Layer — Firestore

Every page that loads data follows this pattern:

```dart
Future<void> _fetch() async {
  // 1. Query Firestore
  final snap = await FirebaseFirestore.instance
      .collection('assignments')
      .where('owner_user_id', isEqualTo: UserSession.uid)
      .get();

  // 2. Convert to Dart maps (spread data + add document ID)
  final items = snap.docs
      .map((d) => {...d.data(), 'assignment_id': d.id})
      .toList();

  // 3. Update state
  setState(() { _items = items; _loading = false; });
}
```

**Writing a new document:**
```dart
final ref = FirebaseFirestore.instance.collection('assignments').doc();
await ref.set({
  'assignment_id': ref.id,   // store the ID inside the document too
  'title': 'My Assignment',
  'created_on': FieldValue.serverTimestamp(),
});
```

**Updating a field:**
```dart
await FirebaseFirestore.instance
    .collection('student_assignments')
    .doc(docId)
    .update({'earned_point': 8});
```

**Parallel reads with `Future.wait`:**
```dart
// Fires all requests at the same time instead of one-by-one
final results = await Future.wait(
  assignments.map((a) async {
    final s = await db.collection('student_assignments')
        .where('assignment_id', isEqualTo: a['assignment_id'])
        .limit(1).get();
    return {...a, 'published': s.docs.isNotEmpty};
  }),
);
```

---

## In-Memory SQLite — How SQL Grading Works

SQL grading runs entirely on-device using `sqflite_common_ffi` with an in-memory database.

### Flow

```
Firestore (sqliteConfigs/mainConfig)
    ↓  fetch SQL strings
sqflite_common_ffi
    ↓  openDatabase(inMemoryDatabasePath)
    ↓  execute CREATE TABLE + INSERT INTO statements
In-memory SQLite DB
    ↓  run student SQL + expected SQL
Compare result rows
    ↓
is_correct: true/false → saved to question_attempts
```

### Building the in-memory DB

```dart
Future<Database> _buildDb(String datasetName) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await openDatabase(inMemoryDatabasePath, version: 1);
  final queries = List<String>.from(_config[datasetName]?['queries'] ?? []);
  for (final sql in queries) {
    try { await db.execute(sql); } catch (_) {}  // ignore errors (e.g. table already exists)
  }
  return db;
}
```

### Running and comparing queries

```dart
final studentRows = await db.rawQuery(studentSql);
final expectedRows = await db.rawQuery(expectedSql);

// Normalize: lowercase keys, sort rows (for multiset comparison)
List<Map<String, dynamic>> normalize(List<Map<String, dynamic>> rows) {
  return rows.map((r) => {
    for (final e in r.entries) e.key.toLowerCase(): e.value?.toString().toLowerCase()
  }).toList()
    ..sort((a, b) => a.toString().compareTo(b.toString()));
}

final correct = normalize(studentRows).toString() == normalize(expectedRows).toString();
```

### SQL validation

Before running student SQL, only `SELECT` statements are allowed:

```dart
final sql = studentInput.trim().toLowerCase();
if (!sql.startsWith('select')) {
  // show error: only SELECT allowed
}
```

---

## AI Integration — Groq API

The Groq API key is injected at build time using `--dart-define`:

```dart
const apiKey = String.fromEnvironment('GROQ_API_KEY');
```

**Generating questions from a schema:**

```dart
final schemaText = schemaMap.entries.map((e) =>
  'Table: ${e.key}\n${e.value.map((c) => '  ${c['name']} ${c['type']}').join('\n')}'
).join('\n\n');

final res = await http.post(
  Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
  headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
  body: jsonEncode({
    'model': 'llama-3.3-70b-versatile',
    'messages': [{'role': 'user', 'content': 'Generate 5 SQL questions...\n$schemaText\nReturn JSON array only.'}],
    'max_tokens': 2048,
  }),
);

// Parse the JSON array from the response
final raw = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
final presets = List<Map<String, dynamic>>.from(jsonDecode(cleaned));
```

The AI returns questions in this shape:
```json
[
  { "id": 1, "question": "List all employees", "answer": "SELECT * FROM Employees",
    "mark": 2, "difficulty": "easy", "orderMatters": false, "aliasStrict": false }
]
```

---

## Dashboard Architecture

`DashboardShell` is the persistent frame. The `child` parameter is whatever page `go_router` matched.

```
DashboardShell (persistent across navigation)
├── AppBar (title + logout)
├── child  ← changes on navigation
│   ├── /dashboard              → Services grid
│   ├── /dashboard/*/overview   → Stats overview
│   └── /dashboard/*/...        → Feature pages
└── BottomNavigationBar (role-aware)
    ├── Services tab
    └── Overview tab
        └── Sub-tab row (feature pages)
```

Role-based nav: `DashboardShell` reads `UserSession.role` and shows different bottom nav items for teachers vs students.

---

## Assignment Flow — Create → Publish → Grade

This is the most important flow to understand. It mirrors the React app exactly.

### Step 1 — Create (AssignmentFormPage)

3-step wizard:
1. **Details** — title, description, due date
2. **Questions** — select dataset → AI generates preset questions → teacher adds/edits questions with table filter chips
3. **Assign** — select cohort, notification toggles

On submit, the assignment is saved to `assignments` collection with `grading_policy: 'best'`. **No `student_assignments` records are created yet** — the assignment is a draft.

```dart
await FirebaseFirestore.instance.collection('assignments').doc().set({
  'assignment_id': ref.id,
  'title': ...,
  'questions': questions,   // _filterTables stripped before saving
  'grading_policy': 'best',
  ...
});
```

### Step 2 — Publish (AssignmentListPage)

The assignment list shows a **Publish** button for unpublished assignments (those with no `student_assignments` records). Tapping it calls `_publish()`:

```dart
Future<void> _publish(Map<String, dynamic> assignment) async {
  // Get cohort members
  final cohortSnap = await db.collection('cohorts')
      .where('cohort_id', isEqualTo: assignment['student_class']).get();
  final studentUids = List<String>.from(cohortSnap.docs.first.data()['student_uids'] ?? []);

  // Create one student_assignments record per student
  for (final uid in studentUids) {
    final ref = db.collection('student_assignments').doc();
    await ref.set({
      'student_assignment_id': ref.id,
      'assignment_id': assignment['assignment_id'],
      'student_user_id': uid,
      'status': 'assigned',
      'assigned_on': FieldValue.serverTimestamp(),
      'due_on': assignment['due_date'],
    });
  }
}
```

**Why this two-step flow?** Teachers may want to prepare assignments in advance and publish at a specific time. Students only see assignments once a `student_assignments` record exists for them.

### Step 3 — Grade (SubmissionStatusPage)

The teacher sees each student's status. The edit (pen) icon opens a dialog that:
1. Fetches `question_attempts` by `student_user_id` (no `assignment_id` field exists on attempts)
2. Filters attempts to only those whose `question_id` matches this assignment's questions
3. Shows per-question result (✅/❌/—) with earned points
4. Lets the teacher override the total score

```dart
// Correct way to fetch attempts for a specific assignment
final snap = await db.collection('question_attempts')
    .where('student_user_id', isEqualTo: studentUid)
    .get();

final questionIds = assignment['questions']
    .map((q) => q['question_id'] as String).toSet();

final attempts = <String, Map>{};
for (final d in snap.docs) {
  final qid = d.data()['question_id'] as String;
  if (!questionIds.contains(qid)) continue;
  // Keep best attempt per question
  attempts[qid] = _pickBetter(attempts[qid], d.data());
}
```

---

## Key Flutter Patterns Used

### `initState` + async loading

`initState` cannot be `async`. Call a separate method:

```dart
@override
void initState() {
  super.initState();
  _fetch();  // fire and forget — setState inside triggers rebuild
}
```

### Conditional rendering

```dart
@override
Widget build(BuildContext context) {
  if (_loading) return const Center(child: CircularProgressIndicator());
  if (_items.isEmpty) return const Center(child: Text('Nothing here yet.'));
  return ListView.builder(
    itemCount: _items.length,
    itemBuilder: (_, i) => _ItemCard(_items[i]),
  );
}
```

### `Builder` widget for local context

Used when you need to compute a value inside `build` that depends on the current state, without extracting a full method:

```dart
Builder(builder: (ctx) {
  final filtered = items.where((e) => e['active'] == true).toList();
  return DropdownButtonFormField<int>(
    value: filtered.any((e) => e['id'] == _selected) ? _selected : null,
    items: filtered.map(...).toList(),
    ...
  );
})
```

This pattern is used in the quiz preset dropdown to safely handle the case where the selected value is filtered out.

### Spread operator for Firestore maps

```dart
// Firestore document data doesn't include the document ID
// Spread the data and add the ID manually
final item = {...doc.data(), 'id': doc.id};
```

### `ConstrainedBox` for scrollable dialogs

When showing a list inside an `AlertDialog`, constrain its height so it doesn't overflow:

```dart
AlertDialog(
  content: SizedBox(
    width: double.maxFinite,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.builder(...),
      ),
      TextField(...),  // always visible below the list
    ]),
  ),
)
```

### `FilterChip` for multi-select

```dart
Wrap(
  spacing: 8,
  children: _tables.map((t) => FilterChip(
    label: Text(t),
    selected: _selectedTables.contains(t),
    onSelected: (v) => setState(() {
      v ? _selectedTables.add(t) : _selectedTables.remove(t);
    }),
  )).toList(),
)
```

---

## Setup & Running

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (SDK ^3.12)
- A Firebase project with Auth (email/password) and Firestore enabled — **same project as the React app**
- A free [Groq API key](https://console.groq.com)

### 1. Firebase setup

Run FlutterFire CLI to generate platform config files:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=your-firebase-project-id
```

This generates `lib/firebase_options.dart` and platform files (`GoogleService-Info.plist` for iOS, `google-services.json` for Android).

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run

```bash
flutter run --dart-define=GROQ_API_KEY=your_groq_key_here
```

Run on a specific device:

```bash
flutter devices                                    # list connected devices
flutter run -d macos --dart-define=GROQ_API_KEY=…  # macOS desktop
flutter run -d chrome --dart-define=GROQ_API_KEY=… # web
```

### 4. Build for release

```bash
# iOS
flutter build ios --dart-define=GROQ_API_KEY=…

# Android
flutter build apk --dart-define=GROQ_API_KEY=…

# macOS
flutter build macos --dart-define=GROQ_API_KEY=…
```

---

## First-Time Walkthrough

1. **Register as teacher** → creates `users/{uid}` in Firestore with `role: 'teacher'`
2. **Datasets** → create a dataset, add tables, define columns, insert rows
3. **Cohorts** → create a cohort; the document ID is the join code
4. **Assignments** → create an assignment (3-step wizard: details → questions with AI presets → assign to cohort) → tap **Publish** in the assignment list to distribute to students
5. **Register as student** (different account) → verify email → join cohort with the code
6. **Student: Assignments** → open assignment, write SQL, run it, submit
7. **Teacher: Submissions** → see each student's result, tap the pen icon to view per-question breakdown and override the score

---

## Shared Database Notes

This Flutter app shares the same Firestore database as the React web app. Key compatibility rules:

- `question_attempts` has no `assignment_id` field — always query by `student_user_id` and filter by `question_id` in memory
- `assignments` must include `grading_policy: 'best'` (or `'first'`/`'latest'`) — the React app requires this field
- `student_assignments` records are what make an assignment visible to a student — always create these when publishing
- Firestore security rules are deployed from the React app's `firestore.rules` file
- The cohort join code is the Firestore document ID of the cohort (e.g. `Q7ZOB`)
