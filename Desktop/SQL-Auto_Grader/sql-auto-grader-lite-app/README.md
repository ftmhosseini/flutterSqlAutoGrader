# SQL Auto-Grader Lite

A web-based educational platform for learning SQL through hands-on practice. SQL runs entirely in the browser using SQLite WASM — no server-side database required. Students get instant automated feedback by comparing their query results against hidden reference solutions.

---

## Tech Stack

- **React 19** — UI framework
- **Firebase** — Authentication (email/password) + Firestore (user data, assignments, questions)
- **sql.js** — SQLite compiled to WebAssembly, runs SQL in the browser via Web Worker
- **react-router-dom v7** — Client-side routing
- **CRACO** — Create React App config override (for WASM support)
- **Font Awesome 5** — Icons

---

## Features

### Authentication
- Register as **student** or **teacher**
- Email verification required before login
- Firebase Auth + Firestore stores user profile (name, email, role)

### Student Dashboard
- **Assignments** — View and start SQL assignments with status tracking (New / In Progress / Completed)
- **Quizzes** — View quiz list with status
- **Results** — View grades, marks, percentage per assignment; graded by the assignment's grading policy
- **Anti-cheat system** — Disables copy/paste, right-click, text selection; detects tab switching and window blur; prompts fullscreen on assignment start

### Teacher Dashboard
- **Datasets** — Create and manage datasets and tables stored in Firestore
- **Cohorts** — Group students into cohorts (Beginner, Intermediate, Advanced)
- **Assignments** — Create multi-step assignments with:
  - Title, description, due date, grading policy (best / first / latest attempt)
  - Assign to a student cohort
  - Add questions from preset library or write custom ones
  - Per-question settings: difficulty, max attempts, marks, order matters, alias strict
  - Shared SQL code editor to test queries while building questions
- **Edit Questions** — Expand any assignment to edit its questions inline
- **Submission Status** — View per-student attempt results and override marks

---

## Grading System

### Query Execution
- Only `SELECT` statements are allowed; multi-statement queries are blocked
- Student queries are lower-cased before execution
- SQL runs in a **Web Worker** — long-running queries are terminated via `worker.terminate()` after 5 seconds without freezing the UI

### Result Comparison
- Grading compares result sets, not query text
- Rows compared as a **multiset** (order ignored unless *Order Matters* is enabled per question)
- Column names normalized to lowercase
- String values compared case-insensitively

### Grading Policy (per assignment)
| Policy | Behaviour |
|---|---|
| **Best** | Correct attempt wins; if tied, most recent |
| **First** | Earliest submitted attempt is used |
| **Latest** | Most recently submitted attempt is used |

---

## Database Architecture

Datasets are **not** stored as physical `.sqlite` files. Instead:
- Dataset schemas and seed data are defined as SQL statements in `src/data/db-config.json`
- On first run, this config is uploaded to Firestore (`sqliteConfigs/mainConfig`)
- On each app load, the config is fetched from Firestore and builds **in-memory SQLite databases** using `sql.js`
- Teachers can add new datasets/tables dynamically — changes are saved back to Firestore
- This is functionally equivalent to bundling `.sqlite` files and works better for a browser-first app

### Bundled Datasets
| Dataset | Tables | Use |
|---|---|---|
| **datasetA** | Employees, Departments | Joins, filters, aggregates, subqueries, window functions |
| **datasetB** | Customers, Orders | Subqueries, grouping, date filters, totals, window functions |

---

## Security

Firestore security rules (`firestore.rules`) enforce:
- Users can only read/write their own profile
- Students can only create attempts for themselves; `is_correct` must be `false` on create (grading is client-side)
- Teachers can override attempt marks
- Only teachers can write assignments, cohorts, questions, datasets, and preset questions
- All authenticated users can read assignments and datasets

---

## Project Structure

```
src/
├── data/                       # DEV ONLY seed files (remove before production push)
│   ├── devSeed.js              # All seed functions — delete this before pushing to GitHub
│   ├── seedData.json           # Sample cohorts, assignments, questions
│   ├── questions.json          # Preset SQL questions (A1–A9, B1–B9) with difficulty, marks, grading flags
│   └── db-config.json          # SQLite schema + seed data for in-browser databases
│
├── components/
│   ├── bars/                   # Navbar, Footer
│   ├── comparison/             # SQL result comparison logic (multiset + ordered)
│   ├── db/
│   │   ├── sqlTest.js          # SQL Tester component
│   │   ├── queryValidation.js  # SELECT-only enforcement + query normalization
│   │   ├── service/            # AppContext (global DB state), setupDatabases (Web Worker calls)
│   │   └── setup/              # Firebase DB setup
│   ├── hooks/                  # useAntiCheat hook (fullscreen, copy/paste, tab detection)
│   └── model/                  # Firestore data models (assignments, questions, cohorts, attempts)
│
├── pages/
│   ├── home/
│   ├── about/
│   ├── login/
│   ├── register/
│   ├── profile/
│   └── dashboard/
│       ├── layout/             # Dashboard shell (sidebar + topbar + outlet)
│       ├── leftmenu/           # Sidebar navigation
│       ├── Dashboard.js        # Dashboard home (seed buttons for dev, role-aware cards)
│       ├── student/
│       │   ├── assignments/    # Assignments list + anti-cheat question detail
│       │   ├── quizzes/
│       │   └── results/
│       └── teacher/
│           ├── assignmentform/ # AssignmentForm (multi-step) + AssignmentList
│           ├── cohorts/        # CohortManager
│           ├── createquestionset/ # CreateQuestionSet with fixed code editor
│           ├── datasets/       # DatabaseManager
│           └── submissionstatus/ # Per-student attempt viewer + mark override
│
public/
├── sql-wasm.wasm               # SQLite WASM binary
├── sql-wasm.js                 # sql.js loader (used by Web Worker)
└── sqlWorker.js                # Web Worker — builds DB from Firestore config, runs queries
│
firestore.rules                 # Firestore security rules
```

---

## Getting Started

### Prerequisites
- Node.js 18+
- A Firebase project with Authentication and Firestore enabled

### Install
```bash
npm install
```

### Configure Firebase
Create a `.env` file in the project root:
```
REACT_APP_FIREBASE_API_KEY=your_api_key
REACT_APP_FIREBASE_AUTH_DOMAIN=your_auth_domain
REACT_APP_FIREBASE_PROJECT_ID=your_project_id
REACT_APP_FIREBASE_STORAGE_BUCKET=your_storage_bucket
REACT_APP_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
REACT_APP_FIREBASE_APP_ID=your_app_id
```

### Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Run
```bash
npm start
```

### First-Time Setup (Dev Only)
Log in as a teacher and use the buttons on the Dashboard:
1. **Seed Sample Data** — loads cohorts, assignments, and preset questions into Firestore
2. **Upload Dataset Config** — uploads the SQLite schema to Firestore so databases load in-browser

> Before pushing to GitHub: delete `src/data/devSeed.js` and remove the 2 marked `DEV ONLY` lines in `Dashboard.js`

---

## Routes

| Path | Access | Component |
|---|---|---|
| `/` | Public | Home |
| `/about` | Public | About |
| `/register` | Public | Register |
| `/login` | Public | Login |
| `/dashboard` | Protected | Dashboard (role-aware) |
| `/dashboard/assignments` | Student | Assignments list |
| `/dashboard/assignments/:id` | Student | Assignment detail (anti-cheat) |
| `/dashboard/quizzes` | Student | Quizzes list |
| `/dashboard/results` | Student | Results |
| `/dashboard/assignments` | Teacher | Assignment list + create form |
| `/dashboard/cohorts` | Teacher | Cohort manager |
| `/dashboard/datasets` | Teacher | Dataset manager |
| `/dashboard/profile` | Both | Profile |

---

## Anti-Cheat System

During assignments, `useAntiCheat` hook:
- Prompts fullscreen on question load; logs `exited_fullscreen` if student exits
- Disables text selection, copy, and paste
- Detects tab switching (`visibilitychange`) and window blur
- Disables right-click context menu
- Logs each violation with a timestamp
