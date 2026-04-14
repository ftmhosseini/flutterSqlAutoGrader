# SQL Auto Grader — Flutter App

A mobile/desktop app where **teachers** create SQL assignments and quizzes, and **students** solve them with instant automated feedback. Built with Flutter and Firebase.

---

## Table of Contents

1. [What This App Does](#what-this-app-does)
2. [Concepts You Need to Know First](#concepts-you-need-to-know-first)
3. [Project Structure](#project-structure)
4. [How the App Starts — `main.dart`](#how-the-app-starts--maindart)
5. [Authentication Flow](#authentication-flow)
6. [Routing — How Pages Connect](#routing--how-pages-connect)
7. [State Management — Provider](#state-management--provider)
8. [Data Layer — Firebase Firestore](#data-layer--firebase-firestore)
9. [In-Memory SQLite — How SQL Grading Works](#in-memory-sqlite--how-sql-grading-works)
10. [AI Integration — Groq API](#ai-integration--groq-api)
11. [Dashboard Architecture](#dashboard-architecture)
12. [Key Flutter Patterns Used](#key-flutter-patterns-used)
13. [Setup & Running](#setup--running)
14. [First-Time Walkthrough](#first-time-walkthrough)

---

## What This App Does

- **Teachers** create datasets (tables + data), assignments (SQL questions), and quizzes, then assign them to student cohorts.
- **Students** write SQL answers in an editor, run them against a live in-memory database, and get instant correct/incorrect feedback.
- An **AI tutor** (powered by Groq) helps students learn SQL through structured lessons and generated questions.

---

## Concepts You Need to Know First

If you're new to Flutter or the technologies used here, read this section before diving into the code.

### What is Flutter?
Flutter is a framework for building apps from a single codebase that runs on iOS, Android, macOS, Windows, Linux, and web. You write in **Dart**, a language similar to Java/JavaScript.

In Flutter, everything on screen is a **Widget** — a button, a text label, a whole page. Widgets are composed (nested inside each other) to build UIs.

```dart
// A simple widget example
Text('Hello')                          // shows text
Icon(Icons.person)                     // shows an icon
Column(children: [Text('A'), Text('B')]) // stacks widgets vertically
```

### What is a StatelessWidget vs StatefulWidget?
- **StatelessWidget** — the UI never changes after it's built. Use for static content.
- **StatefulWidget** — has a `State` object that can call `setState()` to rebuild the UI when data changes (e.g., after loading from a database).

```dart
// StatefulWidget pattern used throughout this app
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _loading = true;       // local state variable
  List<Map> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();              // called once when page opens
  }

  Future<void> _loadData() async {
    // fetch from Firestore...
    setState(() {             // triggers UI rebuild
      _loading = false;
      _items = [...];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return CircularProgressIndicator();
    return ListView(...);     // show data
  }
}
```

### What is Firebase?
Firebase is Google's backend-as-a-service. This app uses two Firebase products:

- **Firebase Auth** — handles user registration and login (email + password). You never store passwords yourself.
- **Cloud Firestore** — a NoSQL cloud database. Data is stored as **documents** inside **collections**. Think of a collection like a table, and a document like a row — except each document is a JSON object and can have different fields.

```
Firestore structure used in this app:
  users/              ← collection
    {uid}/            ← document (one per user)
      fullName, email, role

  assignments/        ← collection
    {id}/             ← document
      title, questions, due_date, owner_user_id

  student_assignments/ ← collection
    {id}/
      student_user_id, assignment_id, status, earned_point

  cohorts/
    {id}/
      name, student_uids[]

  sqliteConfigs/
    mainConfig/       ← single document
      datasets: { datasetName: { tables: { tableName: [sql...] } } }
```

### What is go_router?
`go_router` is a Flutter package for navigation. Instead of pushing/popping pages manually, you define URL-like paths and navigate with `context.go('/some/path')`. This makes deep linking and role-based routing clean and predictable.

### What is Provider?
`provider` is a Flutter package for sharing state across the widget tree. Instead of passing data down through every widget constructor, you put it in a `ChangeNotifier` and any widget can read it with `context.read<MyProvider>()` or `context.watch<MyProvider>()`.

---

## Project Structure

```
lib/
├── main.dart                  ← App entry point
├── router.dart                ← All routes defined here
├── firebase_options.dart      ← Auto-generated Firebase config
│
├── models/
│   └── user_model.dart        ← UserModel data class
│
├── services/
│   ├── user_service.dart      ← Firestore: fetch user by uid
│   └── user_session.dart      ← In-memory current user (like a global variable)
│
├── providers/
│   └── auth_provider.dart     ← Listens to Firebase auth state changes
│
└── pages/
    ├── home_page.dart         ← Landing page (not logged in)
    ├── login_page.dart        ← Login form
    ├── register_page.dart     ← Register form
    └── dashboard/
        ├── dashboard_shell.dart   ← Scaffold with bottom nav bar (wraps all dashboard pages)
        ├── dashboard_home.dart    ← Services grid + Overview pages for both roles
        ├── profile_page.dart      ← User profile
        ├── teacher/
        │   ├── assignment_list_page.dart    ← Create/publish assignments
        │   ├── assignment_form_page.dart    ← 3-step assignment wizard
        │   ├── cohort_manager_page.dart     ← Create cohorts, view students
        │   ├── database_manager_page.dart   ← Create datasets and tables
        │   ├── quiz_manager_page.dart       ← Create quizzes
        │   └── submission_status_page.dart  ← View student submissions
        └── student/
            ├── assignments_page.dart        ← View + solve assignments
            ├── quizzes_page.dart            ← View + solve quizzes
            ├── results_page.dart            ← View grades
            ├── cohort_page.dart             ← Join cohorts
            └── sql_tutor_page.dart          ← AI-powered SQL lessons + chat
```

---

## How the App Starts — `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();          // required before any async work
  await Firebase.initializeApp(                        // connect to Firebase
    options: DefaultFirebaseOptions.currentPlatform,  // picks iOS/Android/macOS config
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),   // makes AuthProvider available to all widgets
      child: const SqlAutoGraderApp(),
    ),
  );
}
```

**Why `WidgetsFlutterBinding.ensureInitialized()`?**
Flutter needs its engine running before you can call platform code (like Firebase). This line ensures that.

**Why `ChangeNotifierProvider` wraps everything?**
`AuthProvider` tracks whether the user is logged in. By wrapping the whole app, every page can check the auth state without passing it manually.

---

## Authentication Flow

### `AuthProvider` (`providers/auth_provider.dart`)

```dart
class AuthProvider extends ChangeNotifier {
  String? _role;
  bool _loading = true;

  AuthProvider() {
    // Firebase fires this stream every time auth state changes
    // (app open, login, logout, token refresh)
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.emailVerified) {
        final userData = await getUser(user.uid);  // fetch role from Firestore
        if (userData != null) UserSession.set(userData);
        _role = UserSession.role;
      } else {
        UserSession.clear();
        _role = null;
      }
      _loading = false;
      notifyListeners();  // tells all listening widgets to rebuild
    });
  }
}
```

**Key concept:** Firebase Auth persists the session automatically. When the app reopens, `authStateChanges()` fires immediately with the saved user — so the user stays logged in without re-entering credentials.

### `UserSession` (`services/user_session.dart`)

A simple static class that holds the current user in memory:

```dart
class UserSession {
  static UserModel? _user;
  static void set(UserModel? user) => _user = user;
  static String? get uid => _user?.uid;
  static String? get role => _user?.role;  // 'teacher' or 'student'
}
```

**Why static?** So any file in the app can call `UserSession.uid` without needing a reference passed in. It's essentially a global variable, but scoped to the class.

---

## Routing — How Pages Connect

All routes are defined in `router.dart`. The router uses `go_router`'s `redirect` feature to enforce authentication:

```dart
redirect: (ctx, state) {
  if (auth.loading) return null;                          // wait for auth check
  final loggedIn = auth.role != null;
  final loc = state.matchedLocation;
  if (!loggedIn && loc.startsWith('/dashboard')) return '/login';  // protect dashboard
  if (loggedIn && loc == '/') return '/dashboard';                 // skip landing if logged in
  return null;  // no redirect needed
},
```

**ShellRoute** is used for the dashboard — it wraps all dashboard pages in `DashboardShell` (which provides the app bar and bottom nav bar) without rebuilding the shell on every navigation:

```dart
ShellRoute(
  builder: (_, _, child) => DashboardShell(child: child),
  routes: [
    GoRoute(path: '/dashboard', builder: ...),
    GoRoute(path: '/dashboard/student/assignments', builder: ...),
    // ...
  ],
),
```

**How to navigate:**
```dart
context.go('/dashboard/student/assignments');  // replace current page
context.push('/some/page');                    // push onto stack (back button works)
```

---

## State Management — Provider

The app uses `provider` for auth state only. All other state is local to each page's `State` class.

**Reading the provider:**
```dart
// In a widget's build method:
final auth = Provider.of<AuthProvider>(context);  // rebuilds widget when auth changes
// or
final auth = context.read<AuthProvider>();         // read once, no rebuild
```

**Pattern used in router:**
```dart
final auth = Provider.of<AuthProvider>(context, listen: false);
// listen: false because the router itself doesn't need to rebuild,
// it just reads the current value for redirect logic
```

---

## Data Layer — Firebase Firestore

Every page that needs data follows the same pattern:

```dart
Future<void> _fetchData() async {
  // 1. Get a reference to the collection
  final snap = await FirebaseFirestore.instance
      .collection('student_assignments')
      .where('student_user_id', isEqualTo: UserSession.uid)  // filter
      .get();

  // 2. Convert documents to Dart maps
  final items = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  //                                   ^ document fields  ^ document ID

  // 3. Update state to trigger UI rebuild
  setState(() {
    _items = items;
    _loading = false;
  });
}
```

**Writing data:**
```dart
// Add a new document with auto-generated ID
final ref = FirebaseFirestore.instance.collection('cohorts').doc();
await ref.set({
  'cohort_id': ref.id,
  'name': 'My Cohort',
  'student_uids': [],
});

// Update an existing document
await ref.update({'student_uids': FieldValue.arrayUnion([uid])});
```

**Why `{...d.data(), 'id': d.id}`?**
Firestore documents don't include their own ID in `d.data()`. Spreading the data map and adding `'id': d.id` gives you a single map with all fields plus the ID.

---

## In-Memory SQLite — How SQL Grading Works

This is the core technical feature. SQL grading happens **on-device** using `sqflite_common_ffi`, which runs SQLite in memory (no file on disk).

**The flow:**

1. Teacher creates a dataset → schema stored as SQL strings in Firestore (`sqliteConfigs/mainConfig`)
2. Student submits an SQL answer
3. App fetches the dataset config from Firestore
4. App builds an in-memory SQLite database by running the stored `CREATE TABLE` and `INSERT INTO` statements
5. App runs both the **student's SQL** and the **expected SQL** against the same in-memory DB
6. App compares the result tables row-by-row

```dart
// Simplified grading logic
final db = await openDatabase(inMemoryDatabasePath);

// Replay the dataset
for (final sql in datasetSqlStatements) {
  await db.execute(sql);
}

// Run both queries
final studentResult = await db.rawQuery(studentSql);
final expectedResult = await db.rawQuery(expectedSql);

// Compare
final correct = _resultsMatch(studentResult, expectedResult);
```

**Why in-memory?** No server needed for grading. The app is fully offline-capable for SQL execution — only Firestore reads/writes need internet.

---

## AI Integration — Groq API

The app calls the Groq API (OpenAI-compatible) to:
- Generate SQL quiz/assignment questions from a dataset schema
- Power the SQL Tutor chat

The API key is injected at build time (never hardcoded):

```dart
// Reading the key
const apiKey = String.fromEnvironment('GROQ_API_KEY');

// Making a request (standard HTTP POST)
final response = await http.post(
  Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
  headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
  body: jsonEncode({
    'model': 'llama-3.3-70b-versatile',
    'messages': [{'role': 'user', 'content': prompt}],
  }),
);
```

**Why `String.fromEnvironment`?** Hardcoding API keys in source code is a security risk. `--dart-define` injects the value at compile time so it's never in your git history.

---

## Dashboard Architecture

The dashboard uses a **shell + child** pattern. `DashboardShell` is the persistent frame (app bar + bottom nav). The `child` is whatever page the router matched.

```
DashboardShell (persistent)
├── AppBar (title + logout button)
├── child (changes on navigation)
│   ├── /dashboard              → Services grid
│   ├── /dashboard/*/overview   → Overview stats page
│   ├── /dashboard/*/assignments → Assignments page
│   └── ...
└── BottomNavigationBar (two-level for both roles)
    ├── Bottom row: Services | Overview
    └── Top sub-tab row: sub-pages (hidden on Overview)
```

**Role-based UI:** `DashboardShell` reads `UserSession.role` and renders different nav items for teachers vs students. The same shell file handles both roles.

```dart
final isTeacher = UserSession.role == 'teacher';

// Show different bottom nav based on role
if (isTeacher) {
  // Services + Overview + sub-tabs for teacher pages
} else {
  // Services + Overview + sub-tabs for student pages
}
```

---

## Key Flutter Patterns Used

### `initState` + `async` loading
Every data page loads in `initState`. Since `initState` can't be `async` itself, it calls a separate `Future` method:
```dart
@override
void initState() {
  super.initState();
  _load();  // fire and forget — setState inside will trigger rebuild
}
```

### Conditional rendering
```dart
if (_loading) return const Center(child: CircularProgressIndicator());
if (_items.isEmpty) return const Text('Nothing here yet.');
return ListView.builder(...);
```

### `Wrap` for responsive card grids
The Services page uses `Wrap` instead of `GridView` so cards flow naturally on any screen width:
```dart
Wrap(
  spacing: 16,
  runSpacing: 16,
  children: [
    _DashCard(label: 'Assignments', ...),
    _DashCard(label: 'Quizzes', ...),
  ],
)
```

### Named constructors and `const`
```dart
const Text('Hello')  // const = widget is immutable, Flutter can cache it
```
Use `const` wherever possible — it improves performance.

### `Future.wait` for parallel requests
When you need multiple Firestore reads at once:
```dart
final results = await Future.wait(
  items.map((item) async {
    final doc = await db.collection('assignments').doc(item['id']).get();
    return {...item, 'title': doc.data()?['title']};
  }),
);
// All requests fire in parallel, not one-by-one
```

---

## Setup & Running

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- A Firebase project with Auth (email/password) and Firestore enabled
- A free [Groq API key](https://console.groq.com)

### 1. Firebase Setup

Run FlutterFire CLI to generate platform config files:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=your-firebase-project-id
```

This generates `lib/firebase_options.dart` and platform-specific files (`GoogleService-Info.plist` for iOS, `google-services.json` for Android).

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run the app
```bash
flutter run --dart-define=GROQ_API_KEY=your_key_here
```

Run on a specific device:
```bash
flutter devices                                          # list connected devices
flutter run -d "iPhone 16 Pro" --dart-define=GROQ_API_KEY=your_key
```

---

## First-Time Walkthrough

1. **Register as teacher** → creates a user doc in Firestore with `role: 'teacher'`
2. **Datasets** → create a dataset, add a table, define columns, insert rows
3. **Cohorts** → create a cohort, note the 5-character join code
4. **Assignments** → create an assignment (pick dataset, AI generates questions, assign to cohort)
5. **Register as student** (different account) → join cohort with the code
6. **Student: Assignments** → open the assignment, write SQL, run it, submit
7. **Teacher: Submissions** → see the student's result and grade

---

## Notes

- Firestore security rules must be deployed from the companion React app's `firestore.rules`
- The Flutter app shares the same Firestore database as the React web app
- SQLite runs entirely in-memory — no files are written to disk
- Internet connection required for Firebase and Groq API calls
