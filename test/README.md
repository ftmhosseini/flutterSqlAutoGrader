# Testing the SQL Auto Grader Flutter App

This guide explains how to run the tests for this app and understand what they do — no prior Flutter or testing experience needed.

---

## What is a test?

A test is a small piece of code that automatically checks whether your app works correctly. Instead of opening the app and clicking around manually every time you make a change, tests do that checking for you in seconds.

There are two types of tests in this project:

- **Unit tests** — check that a single piece of logic (like a data model) works correctly, with no UI involved.
- **Widget tests** — check that a screen looks right and behaves correctly when a user interacts with it (e.g. tapping a button, entering text).

---

## Test files

| File | What it tests |
|------|--------------|
| `user_model_test.dart` | The `UserModel` class — how user data is created, read, and saved |
| `auth_pages_test.dart` | The Login and Forgot Password screens — layout, error messages, and navigation |

---

## How to run the tests

### 1. Make sure Flutter is installed

Open a terminal and run:
```bash
flutter --version
```
If you see a version number, you're good. If not, install Flutter from [flutter.dev](https://flutter.dev/docs/get-started/install).

### 2. Navigate to the project folder

```bash
cd /path/to/SQL-Auto-Grader/flutter/sql_auto_grader
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run all tests

```bash
flutter test
```

### 5. Run a specific test file

```bash
flutter test test/user_model_test.dart
flutter test test/auth_pages_test.dart
```

### 6. Run with detailed output

```bash
flutter test --reporter expanded
```

---

## Understanding the output

When tests pass, you'll see:
```
+11: All tests passed!
```

When a test fails, you'll see something like:
```
-1: LoginPage shows error when login attempted with empty fields [E]
  Expected: 'Wrong email or password'
  Actual: ''
```
This tells you exactly which test failed and why.

---

## What each test checks

### `user_model_test.dart`

| Test | What it checks |
|------|---------------|
| `fromMap parses all fields correctly` | When user data comes from the database, all fields (name, email, role) are read correctly |
| `fromMap defaults role to student when missing` | If the role field is empty, it stays empty (no silent default) |
| `toMap includes all required keys` | When saving a user, all required fields are included |
| `toMap round-trips correctly` | A user saved to a map and loaded back is identical to the original |

### `auth_pages_test.dart`

| Test | What it checks |
|------|---------------|
| `renders email, password fields and login button` | The Login screen shows the expected fields |
| `shows error when login attempted with empty fields` | Tapping Login with no input shows an error message |
| `navigates to forgot password on Forgot? tap` | Tapping "Forgot?" opens the Forgot Password screen |
| `navigates to register on Sign Up tap` | Tapping "Sign Up" opens the Register screen |
| `renders email field and send button` | The Forgot Password screen shows the expected fields |
| `shows error for unknown email` | Submitting an unknown email shows an error message |
| `navigates back to login on Login tap` | Tapping "Login" on the Forgot Password screen goes back to Login |

---

## How to write your own test

Here is the simplest possible test:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1 + 1 equals 2', () {
    expect(1 + 1, equals(2));
  });
}
```

- `test(...)` defines a single test case with a description and a function.
- `expect(actual, matcher)` checks that the actual value matches what you expect.
- If they don't match, the test fails and tells you what went wrong.

For widget tests, you use `testWidgets` instead:

```dart
testWidgets('Login button exists', (tester) async {
  await tester.pumpWidget(/* your widget here */);
  expect(find.text('Login'), findsOneWidget);
});
```

- `tester.pumpWidget(...)` renders a widget in a virtual screen.
- `find.text('Login')` searches for a widget that displays the text "Login".
- `findsOneWidget` means exactly one such widget should exist.

---

## Common matchers

| Matcher | Meaning |
|---------|---------|
| `findsOneWidget` | Exactly one widget found |
| `findsNothing` | No widget found |
| `findsWidgets` | One or more widgets found |
| `equals(value)` | Value is equal to expected |
| `isTrue` / `isFalse` | Boolean check |
| `contains('text')` | String contains substring |

---

## Tips

- Run tests after every change to catch bugs early.
- A failing test is not a problem — it's useful information telling you something broke.
- Tests are code too: keep them simple and readable.
